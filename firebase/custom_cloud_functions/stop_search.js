const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  resolveDailyRoomName,
} = require("./daily_room");
const {
  deleteDailyRoomForSession,
} = require("./daily_room_cleanup");
const {
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_TERMINAL_STATUSES,
} = require("./search_requests");

const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];

const TERMINAL_SEARCH_REQUEST_STATUSES = new Set([
  ...SEARCH_REQUEST_TERMINAL_STATUSES,
  "cancelled_by_user",
]);

const STOPPABLE_SESSION_STATUSES = new Set([
  "searching",
  "pending_confirmation",
]);

const TERMINAL_SESSION_STATUSES = new Set([
  "cancelled",
  "ended",
  "expired",
  "completed",
  "no_tutors_available",
]);

function normalizeNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0 ?
    value.trim() :
    "";
}

function normalizeDocumentId(value) {
  const documentId = normalizeNonEmptyString(value);
  if (!documentId ||
      documentId.includes("/") ||
      documentId === "." ||
      documentId === ".." ||
      /^__.*__$/.test(documentId)) {
    return "";
  }

  return documentId;
}

function normalizeSessionId(value) {
  return normalizeDocumentId(value);
}

function normalizeRequestId(value) {
  return normalizeDocumentId(value);
}

function readReferenceId(value) {
  return value && typeof value.id === "string" ? value.id.trim() : "";
}

function requestBelongsToUser(requestData = {}, userId) {
  const explicitUserIds = [
    requestData.userId,
    requestData.studentId,
    requestData.requesterId,
  ].map(normalizeNonEmptyString).filter(Boolean);
  const referencedUserIds = [
    requestData.userRef,
    requestData.studentRef,
    requestData.requesterRef,
  ].map(readReferenceId).filter(Boolean);
  const ownerIds = [...explicitUserIds, ...referencedUserIds];

  return ownerIds.length === 0 || ownerIds.includes(userId);
}

function readRequestSessionIds(requestData = {}) {
  return [
    requestData.sessionId,
    requestData.activeSessionId,
    requestData.currentSessionId,
    requestData.matchedSessionId,
    requestData.videoSessionId,
  ].map(normalizeNonEmptyString).filter(Boolean);
}

function resolveStopSessionId({
  explicitSessionId = "",
  requestData = {},
  requesterCurrentSessionId = "",
}) {
  if (explicitSessionId) {
    return explicitSessionId;
  }

  const requestSessionId = readRequestSessionIds(requestData)[0];
  if (requestSessionId) {
    return normalizeSessionId(requestSessionId);
  }

  return normalizeSessionId(requesterCurrentSessionId);
}

function requestMatchesSession(requestData = {}, sessionId) {
  if (!sessionId) {
    return true;
  }

  return readRequestSessionIds(requestData).includes(sessionId);
}

function readRequestIds(requestData = {}) {
  return [
    requestData.requestId,
    requestData.clientSearchId,
    requestData.activeSearchRequestId,
  ].map(normalizeNonEmptyString).filter(Boolean);
}

function requestMatchesSearchRequestId(requestData = {}, requestId) {
  if (!requestId) {
    return true;
  }

  return readRequestIds(requestData).includes(requestId);
}

function getSessionRequesterId(sessionData = {}) {
  return normalizeNonEmptyString(sessionData.studentId) ||
    normalizeNonEmptyString(sessionData.requesterId) ||
    normalizeNonEmptyString(sessionData.matchContext?.requesterId);
}

function getAssignedResponderId(sessionData = {}) {
  return normalizeNonEmptyString(sessionData.currentTutorId) ||
    normalizeNonEmptyString(sessionData.tutorId) ||
    normalizeNonEmptyString(sessionData.currentResponderId) ||
    normalizeNonEmptyString(sessionData.responderId) ||
    normalizeNonEmptyString(sessionData.matchContext?.acceptedResponderId);
}

function timestampToMillis(value) {
  if (!value) {
    return null;
  }
  if (typeof value.toMillis === "function") {
    const millis = Number(value.toMillis());
    return Number.isFinite(millis) ? millis : null;
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  const millis = Number(value);
  return Number.isFinite(millis) ? millis : null;
}

function timestampToIsoString(value) {
  const millis = timestampToMillis(value);
  return millis === null ? null : new Date(millis).toISOString();
}

function buildStopSearchDecision({
  requestExists,
  requestData = {},
  userId,
  sessionId = "",
  requestId = "",
  serverTimestamp,
  fieldDelete,
}) {
  if (!requestExists) {
    return {
      ok: true,
      update: null,
      response: {
        status: "noop",
        stopped: false,
        reason: "not_found",
      },
    };
  }

  if (!requestBelongsToUser(requestData, userId)) {
    return {
      ok: false,
      code: "permission-denied",
      message: "You can only stop your own search request",
    };
  }

  if (!requestMatchesSession(requestData, sessionId)) {
    return {
      ok: true,
      update: null,
      response: {
        status: "noop",
        stopped: false,
        reason: "session_mismatch",
      },
    };
  }

  if (!requestMatchesSearchRequestId(requestData, requestId)) {
    return {
      ok: true,
      update: null,
      response: {
        status: "noop",
        stopped: false,
        reason: "request_mismatch",
      },
    };
  }

  const currentStatus = normalizeNonEmptyString(requestData.status);
  if (TERMINAL_SEARCH_REQUEST_STATUSES.has(currentStatus)) {
    return {
      ok: true,
      update: null,
      response: {
        status: "noop",
        stopped: false,
        reason: "already_inactive",
      },
    };
  }

  return {
    ok: true,
    update: {
      status: "stopped",
      stopReason: "manual",
      stoppedAt: serverTimestamp,
      stoppedBy: userId,
      updatedAt: serverTimestamp,
      activeSessionId: fieldDelete,
      currentSessionId: null,
      matchedSessionId: fieldDelete,
      matchedStudentId: fieldDelete,
      matchedTeacherId: fieldDelete,
      matchedUserId: null,
      matchedResponderId: fieldDelete,
      matchedRole: null,
      pairAttemptId: null,
      excludedCandidateIds: [],
      attemptExcludedCandidateIds: [],
      candidateLockOwner: fieldDelete,
      candidateLockExpiresAt: fieldDelete,
      lockOwner: null,
      lockExpiresAt: null,
      lastError: null,
      errorCode: fieldDelete,
      errorMessage: fieldDelete,
    },
    response: {
      status: "stopped",
      stopped: true,
      reason: "manual",
      pairAttemptId: null,
      expiresAt: null,
      errorCode: null,
    },
  };
}

function buildStopSessionDecision({
  sessionExists,
  sessionData = {},
  userId,
  sessionId = "",
  requesterCurrentSessionId = "",
  responderCurrentSessionId = "",
  serverTimestamp,
  fieldDelete,
}) {
  if (!sessionId) {
    return {
      ok: true,
      sessionUpdate: null,
      requesterUpdate: null,
      responderUserId: "",
      responderUpdate: null,
      response: {
        status: "noop",
        stopped: false,
        reason: "session_not_provided",
      },
    };
  }

  if (!sessionExists) {
    return {
      ok: true,
      sessionUpdate: null,
      requesterUpdate: null,
      responderUserId: "",
      responderUpdate: null,
      response: {
        status: "noop",
        stopped: false,
        reason: "session_not_found",
      },
    };
  }

  const requesterId = getSessionRequesterId(sessionData);
  if (requesterId !== userId) {
    return {
      ok: false,
      code: "permission-denied",
      message: "You can only stop your own search session",
    };
  }

  const currentStatus = normalizeNonEmptyString(sessionData.status);
  if (TERMINAL_SESSION_STATUSES.has(currentStatus)) {
    return {
      ok: true,
      sessionUpdate: null,
      requesterUpdate: null,
      responderUserId: "",
      responderUpdate: null,
      response: {
        status: "noop",
        stopped: false,
        reason: "session_already_inactive",
      },
    };
  }

  if (!STOPPABLE_SESSION_STATUSES.has(currentStatus)) {
    return {
      ok: true,
      sessionUpdate: null,
      requesterUpdate: null,
      responderUserId: "",
      responderUpdate: null,
      response: {
        status: "noop",
        stopped: false,
        reason: "session_not_searching",
      },
    };
  }

  const responderUserId = getAssignedResponderId(sessionData);
  return {
    ok: true,
    sessionUpdate: {
      status: "cancelled",
      endedAt: serverTimestamp,
      cancelledAt: serverTimestamp,
      cancelledBy: userId,
      cancelReason: "manual_stop_search",
      currentTutorId: fieldDelete,
      acceptingTutorId: fieldDelete,
      acceptingAt: fieldDelete,
      tutorNavigationTriggered: false,
      studentNavigationTriggered: false,
    },
    requesterUpdate: requesterCurrentSessionId === sessionId ?
      {currentSessionId: fieldDelete} :
      null,
    responderUserId,
    responderUpdate:
      responderUserId && responderCurrentSessionId === sessionId ?
        {currentSessionId: fieldDelete} :
        null,
    response: {
      status: "cancelled",
      stopped: true,
      reason: "manual",
      dailyRoomName: resolveDailyRoomName(sessionData),
      responderUserId,
    },
  };
}

function buildResponse({
  userId,
  sessionId,
  requestId,
  searchDecision,
  sessionDecision,
}) {
  const sessionStopped = sessionDecision.response.stopped === true;
  const searchStopped = searchDecision.response.stopped === true;
  const stopped = sessionStopped || searchStopped;
  const primaryResponse = sessionStopped ?
    sessionDecision.response :
    searchDecision.response;

  return {
    status: stopped ?
      (sessionStopped ? "cancelled" : "stopped") :
      "noop",
    stopped,
    reason: primaryResponse.reason,
    searchRequestId: userId,
    requestId: requestId || null,
    sessionId: sessionId || null,
    cancelledSessionId: sessionStopped ? sessionId : null,
    pairAttemptId: primaryResponse.pairAttemptId || null,
    expiresAt: primaryResponse.expiresAt || null,
    errorCode: null,
    dailyRoomName: sessionStopped ?
      sessionDecision.response.dailyRoomName || "" :
      "",
    searchRequest: searchDecision.response,
    videoSession: sessionDecision.response,
  };
}

function canStopSessionAfterSearchDecision({
  explicitSessionId = "",
  searchDecision,
}) {
  const mismatchReason = [
    "session_mismatch",
    "request_mismatch",
  ].includes(searchDecision?.response?.reason);

  return Boolean(explicitSessionId) || !mismatchReason;
}

function throwCallableError(decision) {
  throw new functions.https.HttpsError(decision.code, decision.message);
}

async function cancelSentNotificationsForSession({
  db = admin.firestore(),
  sessionId,
}) {
  if (!sessionId) {
    return 0;
  }

  const activeNotificationsQuery = await db
    .collection("notifications")
    .where("sessionId", "==", sessionId)
    .where("status", "==", "sent")
    .get();

  if (activeNotificationsQuery.empty) {
    return 0;
  }

  const batch = db.batch();
  activeNotificationsQuery.forEach((doc) => {
    batch.update(doc.ref, {
      status: "cancelled",
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelReason: "manual_stop_search",
    });
  });
  await batch.commit();

  return activeNotificationsQuery.size;
}

exports.stopSearch = functions
  .runWith({secrets: dailySecrets})
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
      );
    }

    const rawSessionId = data?.sessionId;
    const sessionId =
      rawSessionId == null ? "" : normalizeSessionId(rawSessionId);
    if (rawSessionId != null && !sessionId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "sessionId is invalid",
      );
    }

    const rawRequestId = data?.requestId;
    const requestId =
      rawRequestId == null ? "" : normalizeRequestId(rawRequestId);
    if (rawRequestId != null && !requestId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "requestId is invalid",
      );
    }

    const db = admin.firestore();
    const userId = context.auth.uid;
    const searchRequestRef = db
      .collection(SEARCH_REQUEST_COLLECTION)
      .doc(userId);
    const requesterRef = db.collection("users").doc(userId);
    const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
    const fieldDelete = admin.firestore.FieldValue.delete();

    const txResult = await db.runTransaction(async (transaction) => {
      const searchSnapshot = await transaction.get(searchRequestRef);
      const requestData = searchSnapshot.exists ?
        searchSnapshot.data() || {} :
        {};
      const requesterSnapshot = await transaction.get(requesterRef);
      const requesterCurrentSessionId = normalizeNonEmptyString(
        requesterSnapshot.data()?.currentSessionId,
      );
      const effectiveSessionId = resolveStopSessionId({
        explicitSessionId: sessionId,
        requestData,
        requesterCurrentSessionId,
      });
      const sessionRef = effectiveSessionId ?
        db.collection("videoSessions").doc(effectiveSessionId) :
        null;
      const sessionSnapshot = sessionRef ?
        await transaction.get(sessionRef) :
        null;
      const sessionData = sessionSnapshot?.exists ?
        sessionSnapshot.data() || {} :
        {};
      const responderUserId = getAssignedResponderId(sessionData);
      const responderRef = responderUserId ?
        db.collection("users").doc(responderUserId) :
        null;
      const responderSnapshot = responderRef ?
        await transaction.get(responderRef) :
        null;

      const searchDecision = buildStopSearchDecision({
        requestExists: searchSnapshot.exists,
        requestData,
        userId,
        sessionId: effectiveSessionId,
        requestId,
        serverTimestamp,
        fieldDelete,
      });
      if (!searchDecision.ok) {
        throwCallableError(searchDecision);
      }
      const canStopDerivedSession = canStopSessionAfterSearchDecision({
        explicitSessionId: sessionId,
        searchDecision,
      });
      const sessionIdForStop = canStopDerivedSession ? effectiveSessionId : "";

      const sessionDecision = buildStopSessionDecision({
        sessionExists: canStopDerivedSession &&
          sessionSnapshot?.exists === true,
        sessionData: canStopDerivedSession ? sessionData : {},
        userId,
        sessionId: sessionIdForStop,
        requesterCurrentSessionId,
        responderCurrentSessionId: normalizeNonEmptyString(
          responderSnapshot?.data()?.currentSessionId,
        ),
        serverTimestamp,
        fieldDelete,
      });
      if (!sessionDecision.ok) {
        throwCallableError(sessionDecision);
      }

      if (searchDecision.update) {
        transaction.update(searchRequestRef, searchDecision.update);
      }
      if (sessionDecision.sessionUpdate && sessionRef) {
        transaction.update(sessionRef, sessionDecision.sessionUpdate);
      }
      if (sessionDecision.requesterUpdate) {
        transaction.update(requesterRef, sessionDecision.requesterUpdate);
      }
      if (sessionDecision.responderUpdate && responderRef) {
        transaction.update(responderRef, sessionDecision.responderUpdate);
      }

      return buildResponse({
        userId,
        sessionId: sessionIdForStop,
        requestId,
        searchDecision,
        sessionDecision,
      });
    });

    if (txResult.cancelledSessionId) {
      try {
        txResult.cancelledNotifications =
          await cancelSentNotificationsForSession({
            db,
            sessionId: txResult.cancelledSessionId,
          });
        txResult.notificationCleanupStatus = "completed";
      } catch (error) {
        console.error("⚠️ stopSearch notification cleanup failed:", {
          sessionId: txResult.cancelledSessionId,
          error: error.message,
        });
        txResult.cancelledNotifications = 0;
        txResult.notificationCleanupStatus = "failed";
      }
    } else {
      txResult.cancelledNotifications = 0;
      txResult.notificationCleanupStatus = "skipped";
    }

    if (txResult.cancelledSessionId && txResult.dailyRoomName) {
      try {
        await deleteDailyRoomForSession({
          db,
          sessionId: txResult.cancelledSessionId,
          roomName: txResult.dailyRoomName,
          source: "stopSearch",
        });
        txResult.dailyRoomCleanupStatus = "completed";
      } catch (error) {
        console.error("⚠️ stopSearch Daily room cleanup failed:", {
          sessionId: txResult.cancelledSessionId,
          roomName: txResult.dailyRoomName,
          error: error.message,
        });
        txResult.dailyRoomCleanupStatus = "failed";
      }
    } else {
      txResult.dailyRoomCleanupStatus = "skipped";
    }

    return txResult;
  });

exports.__private__ = {
  STOPPABLE_SESSION_STATUSES,
  TERMINAL_SEARCH_REQUEST_STATUSES,
  TERMINAL_SESSION_STATUSES,
  buildResponse,
  buildStopSearchDecision,
  buildStopSessionDecision,
  canStopSessionAfterSearchDecision,
  cancelSentNotificationsForSession,
  getAssignedResponderId,
  normalizeRequestId,
  normalizeSessionId,
  requestBelongsToUser,
  requestMatchesSearchRequestId,
  requestMatchesSession,
  resolveStopSessionId,
  timestampToMillis,
};
