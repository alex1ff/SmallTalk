const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { deleteDailyRoom } = require("./daily_room");
const {
  buildCompletedPairHistoryWrite,
} = require("./match_repeat_prevention");
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
/*
АВТОМАТИЧЕСКАЯ ФУНКЦИЯ: cleanupExpiredSessions
Завершает истекшие активные сессии (запускается по расписанию)
*/

function buildExpiredSessionCleanupPayload({
  db,
  sessionId,
  sessionRef,
  sessionData = {},
  endedAtMillis = Date.now(),
}) {
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
    status: "ended",
    endedAt: admin.firestore.FieldValue.serverTimestamp(),
    duration: duration,
    tutorNavigationTriggered: false,
    studentNavigationTriggered: false,
    sessionMetadata: {
      ...(sessionData.sessionMetadata || {}),
      endReason: "expired",
      endedAtTimestamp: endedAtMillis,
      finalDuration: duration,
    },
  };

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

  if (cleanupPayload.tutorId) {
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
  .schedule("every 5 minutes")
  .onRun(async () => {
    console.log("🧹 Cleaning up expired sessions...");

    try {
      const now = admin.firestore.Timestamp.now();

      // Находим истекшие активные сессии
      const expiredSessionsQuery = await admin
        .firestore()
        .collection("videoSessions")
        .where("status", "in", ["active", "connecting"])
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
            return { cleaned: false, dailyRoomName: null };
          }

          const freshData = freshSnap.data() || {};
          if (!["active", "connecting"].includes(freshData.status)) {
            return { cleaned: false, dailyRoomName: null };
          }

          const expiresAtMillis =
            freshData.expiresAt?.toMillis?.() || 0;
          if (expiresAtMillis > now.toMillis()) {
            return { cleaned: false, dailyRoomName: null };
          }

          console.log(`🔚 Auto-ending expired session: ${doc.id}`);
          queueExpiredSessionCleanup({
            writer: transaction,
            db,
            doc: {
              id: doc.id,
              ref: doc.ref,
              data: () => freshData,
            },
            endedAtMillis: expiresAtMillis || now.toMillis(),
          });

          return {
            cleaned: true,
            dailyRoomName: freshData.dailyRoomName || null,
          };
        });

        if (!cleanupResult.cleaned) {
          continue;
        }

        cleanedCount += 1;
        if (cleanupResult.dailyRoomName) {
          deleteDailyRoom(cleanupResult.dailyRoomName);
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
  buildExpiredSessionCleanupPayload,
  queueExpiredSessionCleanup,
};
