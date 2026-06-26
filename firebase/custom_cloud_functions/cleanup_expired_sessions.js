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

function buildRestoreSearchExcludedCandidateIdsByParticipantId({
  sessionData = {},
  restoreParticipantIds = [],
}) {
  const sessionParticipantIds = readSessionParticipantIds(sessionData);
  return Object.fromEntries(
    restoreParticipantIds
      .map(normalizeParticipantId)
      .filter(Boolean)
      .map((participantId) => [
        participantId,
        sessionParticipantIds.filter((candidateId) =>
          candidateId !== participantId,
        ),
      ]),
  );
}

function hasConnectedCallEvidence(sessionData = {}) {
  return Boolean(
    sessionData.sessionMetadata?.callConnectedAt ||
    sessionData.sessionMetadata?.callConnectedAtTimestamp,
  );
}

function getCleanupRestoreSearchParticipantIds(sessionData = {}) {
  if (
    sessionData.status !== VIDEO_SESSION_STATUS.CONNECTING ||
    hasConnectedCallEvidence(sessionData)
  ) {
    return [];
  }

  return readConnectedSignalParticipantIds(sessionData);
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

exports.cleanupExpiredSessions = functions
  .runWith({ secrets: dailySecrets })
  .pubsub
  .schedule("every 1 minutes")
  .onRun(async () => {
    console.log("🧹 Cleaning up expired sessions...");

    try {
      const now = admin.firestore.Timestamp.now();

      // Находим истекшие активные сессии
      const expiredSessionsQuery = await admin
        .firestore()
        .collection("videoSessions")
        .where("status", "in", [
          VIDEO_SESSION_STATUS.ACTIVE,
          VIDEO_SESSION_STATUS.CONNECTING,
        ])
        .where("expiresAt", "<=", now)
        .get();

      if (expiredSessionsQuery.empty) {
        console.log("📭 No expired sessions found");
        return null;
      }

      console.log(`⏰ Found ${expiredSessionsQuery.size} expired sessions`);
      const db = admin.firestore();
      let cleanedCount = 0;

      for (const doc of expiredSessionsQuery.docs) {
        const cleanupResult = await db.runTransaction(async (transaction) => {
          const freshSnap = await transaction.get(doc.ref);
          if (!freshSnap.exists) {
            return { cleaned: false, dailyRoomName: null, sessionData: null };
          }

          const freshData = freshSnap.data() || {};
          if (![
            VIDEO_SESSION_STATUS.ACTIVE,
            VIDEO_SESSION_STATUS.CONNECTING,
          ].includes(freshData.status)) {
            return { cleaned: false, dailyRoomName: null, sessionData: null };
          }

          const expiresAtMillis =
            freshData.expiresAt?.toMillis?.() || 0;
          if (expiresAtMillis > now.toMillis()) {
            return { cleaned: false, dailyRoomName: null, sessionData: null };
          }

          console.log(`🔚 Auto-ending expired session: ${doc.id}`);
          const restoreSearchParticipantIds =
            getCleanupRestoreSearchParticipantIds(freshData);
          await releaseSessionPairLocksInTransaction({
            db,
            transaction,
            sessionId: doc.id,
            sessionData: freshData,
            serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
            fieldDelete: admin.firestore.FieldValue.delete(),
            searchRequestStatus: SEARCH_REQUEST_STATUS.EXPIRED,
            stopReason: "session_expired",
            releaseCallState: true,
            restoreLegacyAvailability: true,
            restoreSearchParticipantIds,
            restoreSearchExcludedCandidateIdsByParticipantId:
              buildRestoreSearchExcludedCandidateIdsByParticipantId({
                sessionData: freshData,
                restoreParticipantIds: restoreSearchParticipantIds,
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
            endedAtMillis: expiresAtMillis || now.toMillis(),
            skipLegacyUserRelease: true,
          });

          return {
            cleaned: true,
            dailyRoomName: resolveDailyRoomName(freshData),
            sessionData: {
              ...freshData,
              ...cleanupPayload.sessionUpdate,
            },
            endedAtMillis: expiresAtMillis || now.toMillis(),
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
  buildRestoreSearchExcludedCandidateIdsByParticipantId,
  buildExpiredSessionCleanupPayload,
  getCleanupRestoreSearchParticipantIds,
  hasConnectedCallEvidence,
  queueExpiredSessionCleanup,
  readConnectedSignalParticipantIds,
};
