const functions = require("firebase-functions");
const admin = require("firebase-admin");

/*
НОВАЯ ФУНКЦИЯ: endSession
Завершает активную видео сессию и освобождает участников
*/

exports.endSession = functions.https.onCall(async (data, context) => {
  console.log("🔚 Ending video session...");

  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
      );
    }

    const userId = context.auth.uid;
    const { sessionId, endReason } = data;

    console.log("👤 User ID:", userId);
    console.log("📺 Session ID:", sessionId);
    console.log("📝 End reason:", endReason || "not_specified");

    if (!sessionId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Session ID is required",
      );
    }

    // Получаем данные сессии
    const sessionDoc = await admin
      .firestore()
      .collection("videoSessions")
      .doc(sessionId)
      .get();

    if (!sessionDoc.exists) {
      console.log("❌ Video session not found:", sessionId);
      throw new functions.https.HttpsError(
        "not-found",
        "Video session not found",
      );
    }

    const sessionData = sessionDoc.data();
    console.log("📋 Current session status:", sessionData.status);

    // Проверяем права доступа
    if (sessionData.studentId !== userId && sessionData.tutorId !== userId) {
      console.log("❌ Permission denied - user is not a participant");
      throw new functions.https.HttpsError(
        "permission-denied",
        "You are not a participant of this session",
      );
    }

    // Проверяем, что сессия может быть завершена
    if (!["connecting", "active"].includes(sessionData.status)) {
      console.log(
        "❌ Session cannot be ended, current status:",
        sessionData.status,
      );

      if (sessionData.status === "ended") {
        return {
          status: "already_ended",
          message: "Session was already ended",
          endedAt: sessionData.endedAt?.toMillis() || null,
        };
      }

      throw new functions.https.HttpsError(
        "invalid-argument",
        `Session cannot be ended. Current status: ${sessionData.status}`,
      );
    }

    // Определяем, кто завершил сессию
    const endedBy = userId;
    const endedByRole = sessionData.studentId === userId ? "student" : "tutor";
    const now = Date.now();

    // Вычисляем длительность сессии
    const startTime =
      sessionData.startedAt?.toMillis() ||
      sessionData.createdAt?.toMillis() ||
      now;
    const duration = Math.max(0, Math.floor((now - startTime) / 1000)); // в секундах

    console.log("⏱️ Session duration:", duration, "seconds");
    console.log("👤 Ended by:", endedByRole, endedBy);

    // Обновляем сессию в транзакции
    await admin.firestore().runTransaction(async (transaction) => {
      // Обновляем статус сессии
      transaction.update(
        admin.firestore().collection("videoSessions").doc(sessionId),
        {
          status: "ended",
          endedAt: admin.firestore.FieldValue.serverTimestamp(),
          duration: duration,
          tutorNavigationTriggered: false,
          studentNavigationTriggered: false,
          sessionMetadata: {
            ...sessionData.sessionMetadata,
            endedBy: endedBy,
            endedByRole: endedByRole,
            endReason: endReason || "manual",
            endedAtTimestamp: now,
            finalDuration: duration,
          },
        },
      );

      // Освобождаем преподавателя, если он участвовал
      if (sessionData.tutorId) {
        console.log("👨‍🏫 Releasing tutor:", sessionData.tutorId);
        transaction.update(
          admin.firestore().collection("users").doc(sessionData.tutorId),
          {
            isInCall: false,
            isAvailable: true,
            currentSessionId: admin.firestore.FieldValue.delete(),
            lastCallEndedAt: admin.firestore.FieldValue.serverTimestamp(),
            // Убираем временную недоступность
            availableAfter: admin.firestore.FieldValue.delete(),
          },
        );
      }

      console.log(
        "✅ Transaction completed - session ended and participants released",
      );
    });

    // Логируем завершение + отменяем уведомления параллельно
    console.log("📊 Logging session end + canceling notifications in parallel...");
    await Promise.all([
      logSessionEndEvent(sessionId, sessionData, {
        endedBy: endedBy,
        endedByRole: endedByRole,
        endReason: endReason || "manual",
        duration: duration,
        endedAt: now,
      }),
      cancelAllSessionNotifications(sessionId),
    ]);

    console.log("🎉 Session ended successfully");

    return {
      status: "ended",
      message: "Session ended successfully",
      sessionId: sessionId,
      duration: duration,
      endedBy: endedByRole,
      endedAt: now,
    };
  } catch (error) {
    console.error("❌ Error ending session:", error);

    if (error.code) {
      throw error;
    }

    throw new functions.https.HttpsError("internal", error.message);
  }
});

// ЛОГИРОВАНИЕ ЗАВЕРШЕНИЯ СЕССИИ
async function logSessionEndEvent(sessionId, sessionData, endEventData) {
  try {
    const analyticsData = {
      event: "session_ended",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      sessionId: sessionId,
      studentId: sessionData.studentId,
      tutorId: sessionData.tutorId,
      language: sessionData.language,
      duration: endEventData.duration,
      endReason: endEventData.endReason,
      endedBy: endEventData.endedBy,
      endedByRole: endEventData.endedByRole,
      sessionStartedAt: sessionData.startedAt?.toMillis() || null,
      sessionAcceptedAt: sessionData.acceptedAt?.toMillis() || null,
      version: "2.0",
    };

    await admin.firestore().collection("analytics").add(analyticsData);

    console.log("✅ Session end event logged successfully");
  } catch (error) {
    console.error("❌ Error logging session end event:", error);
  }
}

// ОТМЕНА ВСЕХ УВЕДОМЛЕНИЙ ДЛЯ СЕССИИ
async function cancelAllSessionNotifications(sessionId) {
  try {
    console.log("🚫 Canceling all notifications for session:", sessionId);

    const activeNotificationsQuery = await admin
      .firestore()
      .collection("notifications")
      .where("sessionId", "==", sessionId)
      .where("status", "==", "sent")
      .get();

    if (!activeNotificationsQuery.empty) {
      const batch = admin.firestore().batch();

      activeNotificationsQuery.forEach((doc) => {
        batch.update(doc.ref, {
          status: "cancelled",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelReason: "session_ended",
        });
      });

      await batch.commit();
      console.log(
        `✅ Canceled ${activeNotificationsQuery.size} notification(s)`,
      );
    }
  } catch (error) {
    console.error("❌ Error canceling session notifications:", error);
  }
}
