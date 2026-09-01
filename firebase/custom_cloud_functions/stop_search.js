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
  SEARCH_REQUEST_STATUS,
  SEARCH_REQUEST_TERMINAL_STATUSES,
} = require("./search_requests");
const {
  releaseSessionPairLocksInTransaction,
} = require("./match_pair_lock");
const {sendApnsVoip} = require("./apns_voip");
const {getUserVoipTokens} = require("./voip_tokens");
const {
  buildCallKitIdForSession,
  cancelProtocolV2NotificationsInTransaction,
} = require("./call_notifications");
const {
  buildSearchCancellationIntentData,
  searchCancellationIntentRef,
} = require("./search_cancellation_intents");
const {
  getConnectedCallStartMillis,
} = require("./chats_shared");
const {
  reconcileSessionTrialCallsInTransaction,
} = require("./trial_access");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const CALL_CANCELLATION_DELIVERY_TIMEOUT_MS = 2 * 1000;
const CALL_CANCELLATION_APNS_BUDGET_RATIO = 0.6;

async function runBoundedCancellationDelivery({
  operation,
  timeoutMs,
  controller = null,
}) {
  const timeoutError = new Error("call_cancellation_delivery_timeout");
  let timeout = null;
  const operationPromise = Promise.resolve().then(() => operation(
    controller?.signal || null,
  ));
  const timeoutPromise = new Promise((resolve, reject) => {
    timeout = setTimeout(() => {
      controller?.abort(timeoutError);
      reject(timeoutError);
    }, Math.max(1, timeoutMs));
  });
  try {
    return await Promise.race([operationPromise, timeoutPromise]);
  } finally {
    clearTimeout(timeout);
    operationPromise.catch(() => {});
  }
}

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
  const normalizedUserId = normalizeNonEmptyString(userId);
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

  return ownerIds.length === 0 ||
    ownerIds.every((ownerId) => ownerId === normalizedUserId);
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

function buildStopSearchDecision({
  requestExists,
  requestData = {},
  userId,
  sessionId = "",
  explicitSessionId = "",
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

  if (
    !explicitSessionId &&
    !requestId &&
    readRequestIds(requestData).length > 0
  ) {
    return {
      ok: true,
      update: null,
      response: {
        status: "noop",
        stopped: false,
        reason: "request_id_required",
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
  explicitSessionIdProvided = false,
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
  const protocolV2ParticipantCanStop =
    Number(sessionData.matchProtocolVersion) >= 2 &&
    (sessionData.participantIds || []).includes(userId);
  if (requesterId !== userId && !protocolV2ParticipantCanStop) {
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

  const isExplicitProtocolV2PreActiveConnecting =
    explicitSessionIdProvided === true &&
    Number(sessionData.matchProtocolVersion) >= 2 &&
    currentStatus === "connecting" &&
    getConnectedCallStartMillis(sessionData) <= 0;
  if (
    !STOPPABLE_SESSION_STATUSES.has(currentStatus) &&
    !isExplicitProtocolV2PreActiveConnecting
  ) {
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
  const protocolV2RestoreParticipantIds =
    Number(sessionData.matchProtocolVersion) >= 2 ?
      (sessionData.participantIds || []).filter(
        (participantId) =>
          participantId !== userId &&
          sessionData.participantRoles?.[participantId] === "student",
      ) :
      [];
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
      acceptAttemptId: fieldDelete,
      tutorNavigationTriggered: false,
      studentNavigationTriggered: false,
      ...(Number(sessionData.matchProtocolVersion) >= 2 ? {
        matchRecovery: {
          status: "pending",
          attempts: 0,
          pairAttemptId: normalizeNonEmptyString(sessionData.pairAttemptId),
          reason: "manual_stop_search",
          restoreParticipantIds: protocolV2RestoreParticipantIds,
          requestedAt: serverTimestamp,
        },
      } : {}),
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
      ...(Number(sessionData.matchProtocolVersion) >= 2 ? {
        matchProtocolVersion: 2,
        pairAttemptId: normalizeNonEmptyString(sessionData.pairAttemptId),
        participantStates: sessionData.participantStates || {},
        restoreParticipantIds: protocolV2RestoreParticipantIds,
      } : {}),
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
    ...(Number(sessionDecision.response.matchProtocolVersion) >= 2 ? {
      matchProtocolVersion: 2,
      participantStates: sessionDecision.response.participantStates || {},
      restoreParticipantIds:
        sessionDecision.response.restoreParticipantIds || [],
    } : {}),
  };
}

function canStopSessionAfterSearchDecision({
  explicitSessionId = "",
  searchDecision,
}) {
  const mismatchReason = [
    "session_mismatch",
    "request_mismatch",
    "request_id_required",
  ].includes(searchDecision?.response?.reason);

  return Boolean(explicitSessionId) || !mismatchReason;
}

function buildManualStopPairLockReleaseOptions({
  db,
  transaction,
  sessionId,
  sessionData = {},
  serverTimestamp,
  fieldDelete,
  stoppedBy = "",
}) {
  const participantIds = Array.isArray(sessionData.participantIds) ?
    sessionData.participantIds :
    [];
  const restoreParticipantIds =
    Number(sessionData.matchProtocolVersion) >= 2 ?
      participantIds.filter((participantId) =>
        participantId !== stoppedBy &&
        sessionData.participantRoles?.[participantId] === "student",
      ) :
      [];
  return {
    db,
    transaction,
    sessionId,
    sessionData,
    serverTimestamp,
    fieldDelete,
    searchRequestStatus: SEARCH_REQUEST_STATUS.STOPPED,
    stopReason: "manual_stop_search",
    releaseCallState: true,
    ...(restoreParticipantIds.length > 0 ? {
      restoreSearchParticipantIds: restoreParticipantIds,
      restoreSearchExcludedCandidateIdsByParticipantId: Object.fromEntries(
        restoreParticipantIds.map((participantId) => [
          participantId,
          stoppedBy ? [stoppedBy] : [],
        ]),
      ),
    } : {}),
  };
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

function buildCallCancellationPayload({
  sessionId = "",
  responderUserId = "",
  pairAttemptId = "",
  callKitId = "",
} = {}) {
  const normalizedSessionId = normalizeSessionId(sessionId);
  return {
    type: "call_cancelled",
    sessionId: normalizedSessionId,
    recipientId: normalizeNonEmptyString(responderUserId),
    callKitId:
      normalizeNonEmptyString(callKitId) ||
      buildCallKitIdForSession(normalizedSessionId),
    pairAttemptId: normalizeNonEmptyString(pairAttemptId),
    matchProtocolVersion: normalizeNonEmptyString(pairAttemptId) ? "2" : "1",
  };
}

async function sendCallCancellationToResponder({
  db = admin.firestore(),
  sessionId = "",
  responderUserId = "",
  tokenReader = getUserVoipTokens,
  apnsSender = sendApnsVoip,
  messaging = admin.messaging(),
  pairAttemptId = "",
  callKitId = "",
  deliveryTimeoutMs = CALL_CANCELLATION_DELIVERY_TIMEOUT_MS,
} = {}) {
  const normalizedSessionId = normalizeSessionId(sessionId);
  const normalizedResponderId = normalizeNonEmptyString(responderUserId);
  if (!normalizedSessionId || !normalizedResponderId) {
    return {sent: false, reason: "missing_ids"};
  }

  const responderSnapshot = await db
    .collection("users")
    .doc(normalizedResponderId)
    .get();
  if (!responderSnapshot.exists) {
    return {sent: false, reason: "responder_not_found"};
  }

  const responderData = responderSnapshot.data() || {};
  const {voipPushToken, voipToken: fcmToken} = await tokenReader(
    normalizedResponderId,
    responderData,
  );
  const payload = buildCallCancellationPayload({
    sessionId: normalizedSessionId,
    responderUserId: normalizedResponderId,
    pairAttemptId,
    callKitId,
  });
  const bundleId = process.env.IOS_BUNDLE_ID || "com.appwave.expatlio";
  const voipTopic = process.env.IOS_VOIP_TOPIC ||
    (bundleId.endsWith(".voip") ? bundleId : `${bundleId}.voip`);
  let apnsError = "";
  const deliveryStartedAtMillis = Date.now();
  const normalizedDeliveryTimeoutMs =
    Number.isFinite(deliveryTimeoutMs) && deliveryTimeoutMs > 0 ?
      deliveryTimeoutMs :
      CALL_CANCELLATION_DELIVERY_TIMEOUT_MS;

  if (voipPushToken) {
    const controller = new AbortController();
    try {
      await runBoundedCancellationDelivery({
        controller,
        timeoutMs: Math.max(
          1,
          Math.floor(
            normalizedDeliveryTimeoutMs *
              CALL_CANCELLATION_APNS_BUDGET_RATIO,
          ),
        ),
        operation: (signal) => apnsSender({
          deviceToken: voipPushToken,
          topic: voipTopic,
          expiration: 0,
          collapseId: payload.callKitId,
          signal,
          payload: {
            aps: {"content-available": 1},
            ...payload,
          },
        }),
      });
      return {sent: true, channel: "apns_voip"};
    } catch (error) {
      apnsError = normalizeNonEmptyString(error?.message) || "apns_failed";
      console.error("⚠️ stopSearch CallKit cancellation APNs failed:", {
        sessionId: normalizedSessionId,
        responderUserId: normalizedResponderId,
        error: apnsError,
      });
    }
  }

  if (!fcmToken) {
    return {
      sent: false,
      reason: "missing_fcm_token",
      error: apnsError || null,
    };
  }

  try {
    const remainingTimeoutMs = Math.max(
      1,
      normalizedDeliveryTimeoutMs -
        (Date.now() - deliveryStartedAtMillis),
    );
    await runBoundedCancellationDelivery({
      timeoutMs: remainingTimeoutMs,
      operation: () => messaging.send({
        token: fcmToken,
        data: payload,
        android: {priority: "high"},
        apns: {
          headers: {
            "apns-priority": "5",
            "apns-push-type": "background",
            "apns-topic": bundleId,
          },
          payload: {
            aps: {"content-available": 1},
          },
        },
      }),
    });
    return {sent: true, channel: "fcm"};
  } catch (error) {
    return {
      sent: false,
      reason: "fcm_failed",
      error: normalizeNonEmptyString(error?.message) || "fcm_failed",
    };
  }
}

exports.stopSearch = functions
  .runWith({secrets: [...apnsSecrets, ...dailySecrets]})
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
    const cancellationIntentRef = requestId ?
      searchCancellationIntentRef(db, userId, requestId) :
      null;
    const cancellationIntentData = requestId ?
      buildSearchCancellationIntentData({
        userId,
        requestId,
        serverTimestamp,
      }) :
      null;

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
        explicitSessionId: sessionId,
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
        explicitSessionIdProvided: Boolean(sessionId),
        serverTimestamp,
        fieldDelete,
      });
      if (!sessionDecision.ok) {
        throwCallableError(sessionDecision);
      }

      if (sessionDecision.sessionUpdate && sessionRef) {
        await reconcileSessionTrialCallsInTransaction({
          db,
          transaction,
          sessionId: sessionIdForStop,
          sessionData,
          durationSeconds: 0,
          technicalFailure: true,
          nowMillis: Date.now(),
        });
        await releaseSessionPairLocksInTransaction(
          buildManualStopPairLockReleaseOptions({
            db,
            transaction,
            sessionId: sessionIdForStop,
            sessionData,
            serverTimestamp,
            fieldDelete,
            stoppedBy: userId,
          }),
        );
        if (Number(sessionData.matchProtocolVersion) >= 2) {
          cancelProtocolV2NotificationsInTransaction({
            db,
            transaction,
            sessionId: sessionIdForStop,
            pairAttemptId: sessionData.pairAttemptId,
            participantStates: sessionData.participantStates || {},
            cancelReason: "manual_stop_search",
            serverTimestamp,
          });
        }
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
      if (cancellationIntentRef && cancellationIntentData) {
        transaction.set(
          cancellationIntentRef,
          cancellationIntentData,
          {merge: true},
        );
      }

      const response = buildResponse({
        userId,
        sessionId: sessionIdForStop,
        requestId,
        searchDecision,
        sessionDecision,
      });
      return cancellationIntentRef && response.stopped !== true ? {
        ...response,
        status: "stopped",
        stopped: true,
        reason: "cancellation_intent_recorded",
      } : response;
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

    const cancelledResponderUserId = normalizeNonEmptyString(
      txResult.videoSession?.responderUserId,
    );
    if (
      txResult.cancelledSessionId &&
      Number(txResult.matchProtocolVersion) >= 2
    ) {
      txResult.callCancellationDelivery = {
        sent: false,
        reason: "protocol_v2_recovery_owned",
      };
    } else if (txResult.cancelledSessionId && cancelledResponderUserId) {
      try {
        txResult.callCancellationDelivery =
          await sendCallCancellationToResponder({
            db,
            sessionId: txResult.cancelledSessionId,
            responderUserId: cancelledResponderUserId,
          });
      } catch (error) {
        console.error("⚠️ stopSearch CallKit cancellation failed:", {
          sessionId: txResult.cancelledSessionId,
          responderUserId: cancelledResponderUserId,
          error: error.message,
        });
        txResult.callCancellationDelivery = {
          sent: false,
          reason: "delivery_failed",
        };
      }
    } else {
      txResult.callCancellationDelivery = {
        sent: false,
        reason: "skipped",
      };
    }

    if (
      txResult.cancelledSessionId &&
      Number(txResult.matchProtocolVersion) >= 2
    ) {
      const {
        reconcileReleasedProtocolV2Match,
      } = require("./start_search").__private__;
      await reconcileReleasedProtocolV2Match({
        db,
        sessionId: txResult.cancelledSessionId,
        pairAttemptId: txResult.pairAttemptId,
      }).catch(() => {});
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
  CALL_CANCELLATION_DELIVERY_TIMEOUT_MS,
  STOPPABLE_SESSION_STATUSES,
  TERMINAL_SEARCH_REQUEST_STATUSES,
  TERMINAL_SESSION_STATUSES,
  buildManualStopPairLockReleaseOptions,
  buildResponse,
  buildStopSearchDecision,
  buildStopSessionDecision,
  canStopSessionAfterSearchDecision,
  cancelSentNotificationsForSession,
  buildCallCancellationPayload,
  sendCallCancellationToResponder,
  runBoundedCancellationDelivery,
  getAssignedResponderId,
  normalizeRequestId,
  normalizeSessionId,
  requestBelongsToUser,
  requestMatchesSearchRequestId,
  requestMatchesSession,
  resolveStopSessionId,
  timestampToMillis,
};
