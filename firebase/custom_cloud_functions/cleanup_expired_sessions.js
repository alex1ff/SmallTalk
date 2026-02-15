const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { deleteDailyRoom } = require("./daily_room");
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
/*
АВТОМАТИЧЕСКАЯ ФУНКЦИЯ: cleanupExpiredSessions
Завершает истекшие активные сессии (запускается по расписанию)
*/

exports.cleanupExpiredSessions = functions
  .runWith({ secrets: dailySecrets })
  .pubsub
  .schedule("every 5 minutes")
  .onRun(async (context) => {
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

      // Завершаем каждую истекшую сессию
      const batch = admin.firestore().batch();
      const tutorsToRelease = new Set();

      expiredSessionsQuery.docs.forEach((doc) => {
        const sessionData = doc.data();
        const sessionId = doc.id;

        console.log(`🔚 Auto-ending expired session: ${sessionId}`);

        // Вычисляем длительность
        const startTime =
          sessionData.startedAt?.toMillis() ||
          sessionData.createdAt?.toMillis() ||
          Date.now();
        const duration = Math.max(
          0,
          Math.floor((Date.now() - startTime) / 1000),
        );

        // Обновляем сессию
        batch.update(doc.ref, {
          status: "ended",
          endedAt: admin.firestore.FieldValue.serverTimestamp(),
          duration: duration,
          tutorNavigationTriggered: false,
          studentNavigationTriggered: false,
          sessionMetadata: {
            ...sessionData.sessionMetadata,
            endReason: "expired",
            autoEnded: true,
            endedAtTimestamp: Date.now(),
            finalDuration: duration,
          },
        });

        // Добавляем преподавателя для освобождения
        if (sessionData.tutorId) {
          tutorsToRelease.add(sessionData.tutorId);
        }

        if (sessionData.dailyRoomName) {
          deleteDailyRoom(sessionData.dailyRoomName);
        }
      });

      // Применяем изменения к сессиям
      await batch.commit();
      console.log("✅ All expired sessions marked as ended");

      // Освобождаем преподавателей
      if (tutorsToRelease.size > 0) {
        console.log(`👨‍🏫 Releasing ${tutorsToRelease.size} tutors...`);

        const tutorBatch = admin.firestore().batch();
        tutorsToRelease.forEach((tutorId) => {
          tutorBatch.update(
            admin.firestore().collection("users").doc(tutorId),
            {
              isInCall: false,
              isAvailable: true,
              currentSessionId: admin.firestore.FieldValue.delete(),
              lastCallEndedAt: admin.firestore.FieldValue.serverTimestamp(),
              availableAfter: admin.firestore.FieldValue.delete(),
            },
          );
        });

        await tutorBatch.commit();
        console.log("✅ All tutors released");
      }

      console.log("🧹 Expired sessions cleanup completed");
      return null;
    } catch (error) {
      console.error("❌ Error cleaning up expired sessions:", error);
      return null;
    }
  });

