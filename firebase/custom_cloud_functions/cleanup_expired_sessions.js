const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  resolveDailyRoomName,
} = require("./daily_room");
const {
  deleteDailyRoomForSession,
} = require("./daily_room_cleanup");
const {
  ensureConversationCallEventForSession,
} = require("./chats_shared");
const {
  incomingCallNotificationRef,
} = require("./call_notifications");
const {
  buildCompletedPairHistoryWrite,
} = require("./match_repeat_prevention");
const {
  SEARCH_REQUEST_STATUS,
} = require("./search_requests");
const {
  releaseSessionPairLocksInTransaction,
} = require("./match_pair_lock");
const {
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const PENDING_RESPONSE_TIMEOUT_SESSION_STATUSES = new Set([
  VIDEO_SESSION_STATUS.SEARCHING,
  VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
]);
const PENDING_RESPONSE_NOTIFICATION_BACKSTOP_GRACE_MS = 2 * 60 * 1000;
/*
АВТОМАТИЧЕСКАЯ ФУНКЦИЯ: cleanupExpiredSessions
Завершает истекшие активные сессии (запускается по расписанию)
*/

function normalizeParticipantId(value) {
  if (typeof value !== "string") {
    return "";
  }

  const normalized = value.trim();
  if (
    !normalized ||
    normalized.includes("/") ||
    normalized === "." ||
    normalized === ".." ||
    /^__.*__$/.test(normalized)
  ) {
    return "";
  }
  return normalized;
}

function readSessionParticipantIds(sessionData = {}) {
  return Array.from(new Set([
    ...(Array.isArray(sessionData.participantIds) ?
      sessionData.participantIds :
      []),
    sessionData.studentId,
    sessionData.requesterId,
    sessionData.currentTutorId,
    sessionData.currentResponderId,
    sessionData.responderId,
    sessionData.tutorId,
    sessionData.matchContext?.requesterId,
    sessionData.matchContext?.acceptedResponderId,
  ].map(normalizeParticipantId).filter(Boolean))).sort();
}

function readConnectedSignalParticipantIds(sessionData = {}) {
  const metadata = sessionData.sessionMetadata || {};
  const signalMaps = [
    metadata.roomJoinParticipantSignals,
    metadata.connectedParticipantSignals,
    metadata.dailyWebhookParticipantSignals,
  ].filter((signals) =>
    signals && typeof signals === "object" && !Array.isArray(signals),
  );
  const participantIds = new Set(readSessionParticipantIds(sessionData));
  return Array.from(new Set(signalMaps.flatMap((signals) =>
    Object.keys(signals),
  )))
    .map(normalizeParticipantId)
    .filter((participantId) =>
      participantId && participantIds.has(participantId),
    )
    .sort();
}

function hasConnectedCallEvidence(sessionData = {}) {
  return Boolean(
    sessionData.sessionMetadata?.callConnectedAt ||
    sessionData.sessionMetadata?.callConnectedAtTimestamp ||
    sessionData.sessionMetadata?.dailyWebhookConnectedAt,
  );
}

function timestampToMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") {
    const millis = Number(value.toMillis());
    return Number.isFinite(millis) ? millis : 0;
  }
  if (value instanceof Date) {
    const millis = value.getTime();
    return Number.isFinite(millis) ? millis : 0;
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : 0;
  }
  return 0;
}

function getSessionCleanupDeadlineMillis(sessionData = {}) {
  if (sessionData.status === VIDEO_SESSION_STATUS.CONNECTING) {
    return timestampToMillis(sessionData.joinDeadlineAt) ||
      timestampToMillis(sessionData.expiresAt);
  }
  if (sessionData.status === VIDEO_SESSION_STATUS.ACTIVE) {
    return timestampToMillis(sessionData.expiresAt);
  }
  return 0;
}

function getPendingResponseCleanupDeadlineMillis(sessionData = {}) {
  if (!PENDING_RESPONSE_TIMEOUT_SESSION_STATUSES.has(sessionData.status)) {
    return 0;
  }
  return timestampToMillis(sessionData.responseExpiresAt);
}

function resolvePendingResponderId(sessionData = {}) {
  return normalizeParticipantId(sessionData.currentResponderId) ||
    normalizeParticipantId(sessionData.currentTutorId);
}

function buildPendingResponseTimeoutSessionUpdate({
  sessionData = {},
  endedAtMillis = Date.now(),
}) {
  return {
    status: VIDEO_SESSION_STATUS.EXPIRED,
    endedAt: admin.firestore.FieldValue.serverTimestamp(),
    expiredAt: admin.firestore.FieldValue.serverTimestamp(),
    expireReason: "pending_response_timeout",
    currentTutorId: admin.firestore.FieldValue.delete(),
    currentResponderId: admin.firestore.FieldValue.delete(),
    currentResponderRole: admin.firestore.FieldValue.delete(),
    acceptingTutorId: admin.firestore.FieldValue.delete(),
    acceptingAt: admin.firestore.FieldValue.delete(),
    acceptAttemptId: admin.firestore.FieldValue.delete(),
    tutorNavigationTriggered: false,
    studentNavigationTriggered: false,
    sessionMetadata: {
      ...(sessionData.sessionMetadata || {}),
      endReason: "pending_response_timeout",
      endedAtTimestamp: endedAtMillis,
      finalDuration: 0,
    },
  };
}

function buildPendingResponseTimeoutSessionProjection({
  sessionData = {},
  endedAtMillis = Date.now(),
}) {
  return {
    ...sessionData,
    status: VIDEO_SESSION_STATUS.EXPIRED,
    currentTutorId: null,
    currentResponderId: null,
    currentResponderRole: null,
    acceptingTutorId: null,
    acceptingAt: null,
    acceptAttemptId: null,
    tutorNavigationTriggered: false,
    studentNavigationTriggered: false,
    sessionMetadata: {
      ...(sessionData.sessionMetadata || {}),
      endReason: "pending_response_timeout",
      endedAtTimestamp: endedAtMillis,
      finalDuration: 0,
    },
  };
}

function buildJoinTimeoutParticipantState(sessionData = {}) {
  const participantIds = readSessionParticipantIds(sessionData);
  const joinedParticipantIds = readConnectedSignalParticipantIds(sessionData);
  const joinedParticipantIdSet = new Set(joinedParticipantIds);
  return {
    participantIds,
    joinedParticipantIds,
    missingParticipantIds: participantIds.filter(
      (participantId) => !joinedParticipantIdSet.has(participantId),
    ),
  };
}

function buildExpiredSessionCleanupPayload({
  db,
  sessionId,
  sessionRef,
  sessionData = {},
  endedAtMillis = Date.now(),
}) {
  const wasConnected = hasConnectedCallEvidence(sessionData);
  const terminalStatus =
    sessionData.status === VIDEO_SESSION_STATUS.CONNECTING && !wasConnected ?
      VIDEO_SESSION_STATUS.EXPIRED :
      VIDEO_SESSION_STATUS.ENDED;
  const joinTimeoutParticipantState =
    terminalStatus === VIDEO_SESSION_STATUS.EXPIRED ?
      buildJoinTimeoutParticipantState(sessionData) :
      null;
  const startTime =
    sessionData.startedAt?.toMillis?.() ||
    sessionData.createdAt?.toMillis?.() ||
    endedAtMillis;
  const duration = Math.max(
    0,
    Math.floor((endedAtMillis - startTime) / 1000),
  );
  const pairHistoryWrite = buildCompletedPairHistoryWrite({
    db,
    sessionId,
    sessionRef,
    sessionData,
    completedAtMillis: endedAtMillis,
  });
  const sessionUpdate = {
    status: terminalStatus,
    endedAt: admin.firestore.FieldValue.serverTimestamp(),
    duration: duration,
    tutorNavigationTriggered: false,
    studentNavigationTriggered: false,
    acceptingTutorId: admin.firestore.FieldValue.delete(),
    acceptingAt: admin.firestore.FieldValue.delete(),
    acceptAttemptId: admin.firestore.FieldValue.delete(),
    sessionMetadata: {
      ...(sessionData.sessionMetadata || {}),
      endReason: terminalStatus === VIDEO_SESSION_STATUS.EXPIRED ?
        "join_timeout" :
        "expired",
      endedAtTimestamp: endedAtMillis,
      finalDuration: duration,
    },
  };

  if (terminalStatus === VIDEO_SESSION_STATUS.EXPIRED) {
    sessionUpdate.expiredAt = admin.firestore.FieldValue.serverTimestamp();
    sessionUpdate.expireReason = "join_timeout";
    sessionUpdate.sessionMetadata.joinTimeoutParticipantIds =
      joinTimeoutParticipantState.participantIds;
    sessionUpdate.sessionMetadata.joinTimeoutJoinedParticipantIds =
      joinTimeoutParticipantState.joinedParticipantIds;
    sessionUpdate.sessionMetadata.joinTimeoutMissingParticipantIds =
      joinTimeoutParticipantState.missingParticipantIds;
  }

  if (pairHistoryWrite) {
    sessionUpdate["matchContext.completedPairId"] = pairHistoryWrite.pairId;
    sessionUpdate["matchContext.completedDayKey"] = pairHistoryWrite.dayKey;
    sessionUpdate["matchContext.completedPairHistoryRef"] =
      pairHistoryWrite.ref;
  }

  return {
    duration,
    pairHistoryWrite,
    sessionUpdate,
    tutorId: sessionData.tutorId || null,
  };
}

function buildExpiredSessionReleaseOptions({
  sessionId,
  sessionData = {},
  serverTimestamp,
  fieldDelete,
}) {
  return {
    sessionId,
    sessionData,
    serverTimestamp,
    fieldDelete,
    searchRequestStatus: SEARCH_REQUEST_STATUS.EXPIRED,
    stopReason: "session_expired",
    releaseCallState: true,
    restoreLegacyAvailability: true,
  };
}

function buildPendingResponseTimeoutReleaseOptions({
  sessionId,
  sessionData = {},
  serverTimestamp,
  fieldDelete,
}) {
  return {
    sessionId,
    sessionData,
    serverTimestamp,
    fieldDelete,
    searchRequestStatus: SEARCH_REQUEST_STATUS.EXPIRED,
    stopReason: "pending_response_timeout",
    releaseCallState: true,
    restoreLegacyAvailability: true,
  };
}

function queueExpiredSessionCleanup({
  writer,
  db,
  doc,
  endedAtMillis = Date.now(),
  skipLegacyUserRelease = false,
}) {
  const sessionData = doc.data();
  const sessionId = doc.id;
  const cleanupPayload = buildExpiredSessionCleanupPayload({
    db,
    sessionId,
    sessionRef: doc.ref,
    sessionData,
    endedAtMillis,
  });

  writer.update(doc.ref, cleanupPayload.sessionUpdate);
  if (cleanupPayload.pairHistoryWrite) {
    writer.set(
      cleanupPayload.pairHistoryWrite.ref,
      cleanupPayload.pairHistoryWrite.data,
      { merge: true },
    );
  }

  if (cleanupPayload.tutorId && !skipLegacyUserRelease) {
    writer.update(db.collection("users").doc(cleanupPayload.tutorId), {
      isInCall: false,
      isAvailable: true,
      currentSessionId: admin.firestore.FieldValue.delete(),
      lastCallEndedAt: admin.firestore.FieldValue.serverTimestamp(),
      availableAfter: admin.firestore.FieldValue.delete(),
    });
  }

  return cleanupPayload;
}

function queuePendingResponseTimeoutCleanup({
  writer,
  doc,
  endedAtMillis = Date.now(),
}) {
  const sessionData = doc.data();
  const sessionUpdate = buildPendingResponseTimeoutSessionUpdate({
    sessionData,
    endedAtMillis,
  });

  writer.update(doc.ref, sessionUpdate);

  return {
    sessionUpdate,
  };
}

async function hasSentIncomingCallNotification({
  db,
  transaction,
  sessionId,
  sessionData = {},
  nowMillis = Date.now(),
}) {
  const responderId = resolvePendingResponderId(sessionData);
  if (!responderId) {
    return false;
  }

  const notificationSnap = await transaction.get(
    incomingCallNotificationRef(db, sessionId, responderId),
  );
  if (!notificationSnap.exists) {
    return false;
  }

  const notificationData = notificationSnap.data() || {};
  if (
    notificationData.type !== "incoming_call" ||
    notificationData.sessionId !== sessionId ||
    notificationData.recipientId !== responderId ||
    notificationData.status !== "sent"
  ) {
    return false;
  }

  const notificationExpiresAtMillis = timestampToMillis(notificationData.expiresAt);
  if (!notificationExpiresAtMillis) {
    return false;
  }

  return notificationExpiresAtMillis +
    PENDING_RESPONSE_NOTIFICATION_BACKSTOP_GRACE_MS >= nowMillis;
}

exports.cleanupExpiredSessions = functions
  .runWith({ secrets: dailySecrets })
  .pubsub
  .schedule("every 1 minutes")
  .onRun(async () => {
    console.log("🧹 Cleaning up expired sessions...");

    try {
      const now = admin.firestore.Timestamp.now();
      const db = admin.firestore();
      const videoSessions = db.collection("videoSessions");
      const [
        expiredActiveSessionsQuery,
        expiredConnectingSessionsQuery,
        expiredLegacyConnectingSessionsQuery,
        expiredPendingConfirmationSessionsQuery,
        expiredSearchingSessionsQuery,
      ] = await Promise.all([
        videoSessions
          .where("status", "==", VIDEO_SESSION_STATUS.ACTIVE)
          .where("expiresAt", "<=", now)
          .get(),
        videoSessions
          .where("status", "==", VIDEO_SESSION_STATUS.CONNECTING)
          .where("joinDeadlineAt", "<=", now)
          .get(),
        videoSessions
          .where("status", "==", VIDEO_SESSION_STATUS.CONNECTING)
          .where("expiresAt", "<=", now)
          .get(),
        videoSessions
          .where("status", "==", VIDEO_SESSION_STATUS.PENDING_CONFIRMATION)
          .where("responseExpiresAt", "<=", now)
          .get(),
        videoSessions
          .where("status", "==", VIDEO_SESSION_STATUS.SEARCHING)
          .where("responseExpiresAt", "<=", now)
          .get(),
      ]);
      const expiredSessionDocsById = new Map();
      [
        ...expiredActiveSessionsQuery.docs,
        ...expiredConnectingSessionsQuery.docs,
        ...expiredLegacyConnectingSessionsQuery.docs,
        ...expiredPendingConfirmationSessionsQuery.docs,
        ...expiredSearchingSessionsQuery.docs,
      ].forEach((doc) => {
        expiredSessionDocsById.set(doc.id, doc);
      });
      const expiredSessionDocs = Array.from(expiredSessionDocsById.values());

      if (expiredSessionDocs.length === 0) {
        console.log("📭 No expired sessions found");
        return null;
      }

      console.log(`⏰ Found ${expiredSessionDocs.length} expired sessions`);
      let cleanedCount = 0;

      for (const doc of expiredSessionDocs) {
        const cleanupResult = await db.runTransaction(async (transaction) => {
          const freshSnap = await transaction.get(doc.ref);
          if (!freshSnap.exists) {
            return { cleaned: false, dailyRoomName: null, sessionData: null };
          }

          const freshData = freshSnap.data() || {};
          if (![
            VIDEO_SESSION_STATUS.ACTIVE,
            VIDEO_SESSION_STATUS.CONNECTING,
            VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
            VIDEO_SESSION_STATUS.SEARCHING,
          ].includes(freshData.status)) {
            return { cleaned: false, dailyRoomName: null, sessionData: null };
          }

          const pendingResponseCleanupDeadlineMillis =
            getPendingResponseCleanupDeadlineMillis(freshData);
          if (pendingResponseCleanupDeadlineMillis) {
            if (pendingResponseCleanupDeadlineMillis > now.toMillis()) {
              return { cleaned: false, dailyRoomName: null, sessionData: null };
            }
            if (await hasSentIncomingCallNotification({
              db,
              transaction,
              sessionId: doc.id,
              sessionData: freshData,
              nowMillis: now.toMillis(),
            })) {
              return { cleaned: false, dailyRoomName: null, sessionData: null };
            }

            console.log(`🔚 Expiring orphaned pending session: ${doc.id}`);
            await releaseSessionPairLocksInTransaction({
              db,
              transaction,
              ...buildPendingResponseTimeoutReleaseOptions({
                sessionId: doc.id,
                sessionData: freshData,
                serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
                fieldDelete: admin.firestore.FieldValue.delete(),
              }),
            });
            queuePendingResponseTimeoutCleanup({
              writer: transaction,
              doc: {
                id: doc.id,
                ref: doc.ref,
                data: () => freshData,
              },
              endedAtMillis: pendingResponseCleanupDeadlineMillis,
            });

            return {
              cleaned: true,
              dailyRoomName: resolveDailyRoomName(freshData),
              partnerId: resolvePendingResponderId(freshData),
              sessionData: buildPendingResponseTimeoutSessionProjection({
                sessionData: freshData,
                endedAtMillis: pendingResponseCleanupDeadlineMillis,
              }),
              endedAtMillis: pendingResponseCleanupDeadlineMillis,
            };
          }

          const cleanupDeadlineMillis =
            getSessionCleanupDeadlineMillis(freshData);
          if (!cleanupDeadlineMillis || cleanupDeadlineMillis > now.toMillis()) {
            return { cleaned: false, dailyRoomName: null, sessionData: null };
          }

          console.log(`🔚 Auto-ending expired session: ${doc.id}`);
          await releaseSessionPairLocksInTransaction({
            db,
            transaction,
            ...buildExpiredSessionReleaseOptions({
              sessionId: doc.id,
              sessionData: freshData,
              serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
              fieldDelete: admin.firestore.FieldValue.delete(),
            }),
          });
          const cleanupPayload = queueExpiredSessionCleanup({
            writer: transaction,
            db,
            doc: {
              id: doc.id,
              ref: doc.ref,
              data: () => freshData,
            },
            endedAtMillis: cleanupDeadlineMillis || now.toMillis(),
            skipLegacyUserRelease: true,
          });

          return {
            cleaned: true,
            dailyRoomName: resolveDailyRoomName(freshData),
            sessionData: {
              ...freshData,
              ...cleanupPayload.sessionUpdate,
            },
            endedAtMillis: cleanupDeadlineMillis || now.toMillis(),
          };
        });

        if (!cleanupResult.cleaned) {
          continue;
        }

        cleanedCount += 1;
        try {
          await ensureConversationCallEventForSession({
            db,
            sessionId: doc.id,
            sessionRef: doc.ref,
            sessionData: cleanupResult.sessionData || {},
            eventMillis: cleanupResult.endedAtMillis || now.toMillis(),
            partnerId: cleanupResult.partnerId,
          });
        } catch (error) {
          console.error("⚠️ Failed to create expired call event:", error);
        }
        if (cleanupResult.dailyRoomName) {
          await deleteDailyRoomForSession({
            db,
            sessionId: doc.id,
            roomName: cleanupResult.dailyRoomName,
            source: "cleanupExpiredSessions",
          });
        }
      }

      console.log(`✅ Expired sessions marked as ended: ${cleanedCount}`);

      console.log("🧹 Expired sessions cleanup completed");
      return null;
    } catch (error) {
      console.error("❌ Error cleaning up expired sessions:", error);
      return null;
    }
  });

exports.__private__ = {
  buildExpiredSessionReleaseOptions,
  buildJoinTimeoutParticipantState,
  buildPendingResponseTimeoutReleaseOptions,
  buildPendingResponseTimeoutSessionProjection,
  buildPendingResponseTimeoutSessionUpdate,
  buildExpiredSessionCleanupPayload,
  getSessionCleanupDeadlineMillis,
  getPendingResponseCleanupDeadlineMillis,
  hasConnectedCallEvidence,
  hasSentIncomingCallNotification,
  queuePendingResponseTimeoutCleanup,
  queueExpiredSessionCleanup,
  readConnectedSignalParticipantIds,
  resolvePendingResponderId,
  timestampToMillis,
};
