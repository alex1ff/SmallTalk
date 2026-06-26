const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  getAcceptedSessionCredentialParticipantIds,
  isAcceptedSessionCredentialParticipant,
  isCredentialSessionJoinable,
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  getDailyRoomPresence,
  resolveDailyRoomName,
  __private__: {
    dailyPresenceHasAcceptedParticipants,
  },
} = require("./daily_room");
const {
  stopSessionSearchRequestsInTransaction,
} = require("./match_pair_lock");
const {
  buildRoomJoinParticipantMetadata,
  readRoomJoinSignals,
} = require("./room_join_signals");

const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const MAX_SESSION_ID_LENGTH = 128;

function normalizeSessionId(value) {
  if (typeof value !== "string") {
    return "";
  }

  const normalized = value.trim();
  if (
    normalized.length === 0 ||
    normalized.length > MAX_SESSION_ID_LENGTH ||
    normalized.includes("/") ||
    normalized === "." ||
    normalized === ".." ||
    /^__.*__$/.test(normalized)
  ) {
    return "";
  }

  return normalized;
}

function readSessionMetadata(sessionData = {}) {
  const metadata = sessionData.sessionMetadata;
  if (!metadata || typeof metadata !== "object" || Array.isArray(metadata)) {
    return {};
  }
  return metadata;
}

function readConnectedSignals(sessionMetadata = {}) {
  const signals = sessionMetadata.connectedParticipantSignals;
  if (!signals || typeof signals !== "object" || Array.isArray(signals)) {
    return {};
  }
  return signals;
}

function hasRoomJoinSignalForParticipant(sessionMetadata = {}, userId) {
  const normalizedUserId = typeof userId === "string" ? userId.trim() : "";
  if (!normalizedUserId) {
    return false;
  }

  const roomJoinSignals = readRoomJoinSignals(sessionMetadata);
  const roomJoinedParticipantIds =
    Array.isArray(sessionMetadata.roomJoinedParticipantIds) ?
      sessionMetadata.roomJoinedParticipantIds :
      [];
  return Boolean(roomJoinSignals[normalizedUserId]) &&
    roomJoinedParticipantIds.includes(normalizedUserId);
}

function buildRejectedDecision(code, message) {
  return {
    ok: false,
    code,
    message,
  };
}

function buildMarkSessionConnectedDecision({
  sessionData = {},
  userId,
  nowMillis = Date.now(),
  serverTimestamp = admin.firestore.FieldValue.serverTimestamp(),
}) {
  if (!isAcceptedSessionCredentialParticipant(sessionData, userId)) {
    return buildRejectedDecision(
      "permission-denied",
      "Not allowed to mark this session connected",
    );
  }

  if (!isCredentialSessionJoinable(sessionData, nowMillis)) {
    return buildRejectedDecision(
      "failed-precondition",
      `Session is not joinable (status: ${sessionData.status || "unknown"})`,
    );
  }

  const sessionMetadata = readSessionMetadata(sessionData);
  const participantIds =
    getAcceptedSessionCredentialParticipantIds(sessionData);
  if (sessionMetadata.callConnectedAt) {
    const update = {};
    if (sessionData.status !== VIDEO_SESSION_STATUS.ACTIVE) {
      update.status = VIDEO_SESSION_STATUS.ACTIVE;
    }
    if (!hasRoomJoinSignalForParticipant(sessionMetadata, userId)) {
      update.sessionMetadata = {
        ...sessionMetadata,
        ...buildRoomJoinParticipantMetadata({
          sessionMetadata,
          participantIds,
          userId,
          signal: {
            joinedAt: serverTimestamp,
            lastSeenAt: serverTimestamp,
            source: "markSessionConnected",
          },
        }),
      };
    }
    const hasUpdate = Object.keys(update).length > 0;
    return {
      ok: true,
      update: hasUpdate ? update : null,
      response: {
        status: "already_marked",
        updated: hasUpdate,
      },
    };
  }

  if (participantIds.length < 2) {
    return buildRejectedDecision(
      "failed-precondition",
      "Session accepted participants are incomplete",
    );
  }

  const connectedSignals = readConnectedSignals(sessionMetadata);
  const nextConnectedSignals = {
    ...connectedSignals,
    [userId]: {
      markedAt: serverTimestamp,
      source: "markSessionConnected",
    },
  };
  const hasAllParticipantSignals = participantIds.every((participantId) =>
    Boolean(nextConnectedSignals[participantId]),
  );
  const roomJoinMetadata = buildRoomJoinParticipantMetadata({
    sessionMetadata,
    participantIds,
    userId,
    signal: {
      joinedAt: serverTimestamp,
      lastSeenAt: serverTimestamp,
      source: "markSessionConnected",
    },
  });
  const update = {
    sessionMetadata: {
      ...sessionMetadata,
      ...roomJoinMetadata,
      connectedParticipantSignals: nextConnectedSignals,
      callConnectedSignalParticipantIds: participantIds,
      connectedParticipantSignalsComplete: hasAllParticipantSignals,
    },
  };

  return {
    ok: true,
    update,
    response: {
      status: "signal_recorded",
      updated: true,
      connectedMarked: false,
      dailyPresenceVerificationRequired: hasAllParticipantSignals,
    },
    shouldVerifyDailyPresence: hasAllParticipantSignals,
    dailyRoomName: resolveDailyRoomName(sessionData),
    participantIds,
  };
}

function buildDailyPresenceConnectedDecision({
  sessionData = {},
  presenceData = {},
  userId,
  nowMillis = Date.now(),
  serverTimestamp = admin.firestore.FieldValue.serverTimestamp(),
}) {
  if (!isAcceptedSessionCredentialParticipant(sessionData, userId)) {
    return buildRejectedDecision(
      "permission-denied",
      "Not allowed to mark this session connected",
    );
  }

  if (!isCredentialSessionJoinable(sessionData, nowMillis)) {
    return buildRejectedDecision(
      "failed-precondition",
      `Session is not joinable (status: ${sessionData.status || "unknown"})`,
    );
  }

  const sessionMetadata = readSessionMetadata(sessionData);
  if (sessionMetadata.callConnectedAt) {
    const update = sessionData.status === VIDEO_SESSION_STATUS.ACTIVE ?
      null :
      {status: VIDEO_SESSION_STATUS.ACTIVE};
    return {
      ok: true,
      update,
      response: {
        status: "already_marked",
        updated: Boolean(update),
      },
    };
  }

  const participantIds =
    getAcceptedSessionCredentialParticipantIds(sessionData);
  if (!dailyPresenceHasAcceptedParticipants({
    presenceData,
    roomName: resolveDailyRoomName(sessionData),
    participantIds,
  })) {
    return {
      ok: true,
      update: null,
      response: {
        status: "daily_presence_not_verified",
        updated: false,
        connectedMarked: false,
      },
    };
  }

  const update = {
    status: VIDEO_SESSION_STATUS.ACTIVE,
    sessionMetadata: {
      ...sessionMetadata,
      callConnectedAt: serverTimestamp,
      callConnectedAtSource: "dailyPresenceTwoParty",
      callConnectedBy: userId,
      callConnectedSignalParticipantIds: participantIds,
      dailyPresenceVerifiedAt: serverTimestamp,
      dailyPresenceConnectedParticipantIds: participantIds,
      dailyPresenceRoomName: resolveDailyRoomName(sessionData),
    },
  };

  if (!sessionData.startedAt) {
    update.startedAt = serverTimestamp;
  }

  return {
    ok: true,
    update,
    response: {
      status: "marked",
      updated: true,
      connectedMarked: true,
      startedAtMarked: !sessionData.startedAt,
    },
  };
}

function throwCallableError(decision) {
  throw new functions.https.HttpsError(decision.code, decision.message);
}

async function applyVerifiedConnectedSessionWritesInTransaction({
  db,
  transaction,
  sessionRef,
  sessionId,
  sessionData = {},
  decision = {},
  serverTimestamp = admin.firestore.FieldValue.serverTimestamp(),
  fieldDelete = admin.firestore.FieldValue.delete(),
  stopSearchRequests = stopSessionSearchRequestsInTransaction,
}) {
  const shouldStopSearchRequests =
    decision.update?.status === VIDEO_SESSION_STATUS.ACTIVE ||
    decision.response?.status === "already_marked";
  if (shouldStopSearchRequests) {
    await stopSearchRequests({
      db,
      transaction,
      sessionId,
      sessionData,
      serverTimestamp,
      fieldDelete,
      stopReason: "call_started",
    });
  }

  if (decision.update) {
    transaction.update(sessionRef, decision.update);
  }

  return {
    stoppedSearchRequests: shouldStopSearchRequests,
    updatedSession: Boolean(decision.update),
  };
}

exports.markSessionConnected = functions
  .runWith({ secrets: dailySecrets })
  .https
  .onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
      );
    }

    const sessionId = normalizeSessionId(data?.sessionId);
    if (!sessionId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "sessionId is required",
      );
    }

    const db = admin.firestore();
    const userId = context.auth.uid;
    const sessionRef = db.collection("videoSessions").doc(sessionId);

    const signalResult = await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(sessionRef);
      if (!snapshot.exists) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Not allowed to mark this session connected",
        );
      }

      const sessionData = snapshot.data() || {};
      const decision = buildMarkSessionConnectedDecision({
        sessionData,
        userId,
      });
      if (!decision.ok) {
        throwCallableError(decision);
      }

      await applyVerifiedConnectedSessionWritesInTransaction({
        db,
        transaction,
        sessionRef,
        sessionId,
        sessionData,
        decision,
      });

      return {
        sessionId,
        ...decision.response,
        shouldVerifyDailyPresence:
          decision.shouldVerifyDailyPresence === true,
        dailyRoomName: decision.dailyRoomName || "",
      };
    });

    if (
      !signalResult.shouldVerifyDailyPresence ||
      !signalResult.dailyRoomName
    ) {
      const {shouldVerifyDailyPresence, dailyRoomName, ...response} =
        signalResult;
      return response;
    }

    let presenceData = null;
    try {
      presenceData = await getDailyRoomPresence(signalResult.dailyRoomName);
    } catch (error) {
      console.error("⚠️ Daily presence verification failed:", {
        sessionId,
        error: error?.message || error,
      });
      const {shouldVerifyDailyPresence, dailyRoomName, ...response} =
        signalResult;
      return {
        ...response,
        dailyPresenceVerificationStatus: "presence_unavailable",
      };
    }

    const verifiedResult = await db.runTransaction(async (transaction) => {
      const freshSnapshot = await transaction.get(sessionRef);
      if (!freshSnapshot.exists) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Not allowed to mark this session connected",
        );
      }

      const decision = buildDailyPresenceConnectedDecision({
        sessionData: freshSnapshot.data() || {},
        presenceData,
        userId,
      });
      if (!decision.ok) {
        throwCallableError(decision);
      }

      const freshData = freshSnapshot.data() || {};
      await applyVerifiedConnectedSessionWritesInTransaction({
        db,
        transaction,
        sessionRef,
        sessionId,
        sessionData: freshData,
        decision,
      });

      return {
        sessionId,
        ...decision.response,
      };
    });

    return verifiedResult;
  });

exports.__private__ = {
  applyVerifiedConnectedSessionWritesInTransaction,
  buildDailyPresenceConnectedDecision,
  buildMarkSessionConnectedDecision,
  dailyPresenceHasAcceptedParticipants,
  hasRoomJoinSignalForParticipant,
  normalizeSessionId,
  readConnectedSignals,
  readRoomJoinSignals,
  readSessionMetadata,
};
