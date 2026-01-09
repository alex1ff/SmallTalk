const functions = require("firebase-functions");
const admin = require("firebase-admin");
exports.cancelCall = functions.https.onCall(async (data, context) => {
  console.log("❌ Cancelling video session (updated version)...");

  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
      );
    }

    const studentId = context.auth.uid;
    const { sessionId, callId } = data;
    const resolvedSessionId = sessionId || callId;

    console.log("👨‍🎓 Student ID:", studentId);
    console.log("📺 Session ID:", resolvedSessionId);

    if (!resolvedSessionId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Session ID is required",
      );
    }

    // Проверяем, что студент может отменить эту сессию
    const sessionDoc = await admin
      .firestore()
      .collection("videoSessions")
      .doc(resolvedSessionId)
      .get();

    if (!sessionDoc.exists) {
    console.log("❌ Video session not found:", resolvedSessionId);
    throw new functions.https.HttpsError(
      "not-found",
      "Video session not found",
    );
    }

    const sessionData = sessionDoc.data();
    console.log("📋 Session data status:", sessionData.status);
    console.log("👤 Session student ID:", sessionData.studentId);

    // Проверяем, что это сессия этого студента
    if (sessionData.studentId !== studentId) {
      console.log("❌ Permission denied - wrong student");
      throw new functions.https.HttpsError(
        "permission-denied",
        "You can only cancel your own sessions",
      );
    }

    // Проверяем, что сессию можно отменить
    if (!["searching", "connecting"].includes(sessionData.status)) {
      console.log(
        "❌ Session cannot be cancelled, current status:",
        sessionData.status,
      );
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Session cannot be cancelled. Current status: ${sessionData.status}`,
      );
    }

    console.log("🔄 Updating session status to cancelled...");

    // Обновляем статус сессии на отменен
    await admin
      .firestore()
      .collection("videoSessions")
      .doc(resolvedSessionId)
      .update({
        status: "cancelled",
        endedAt: admin.firestore.FieldValue.serverTimestamp(),
        sessionMetadata: {
          ...sessionData.sessionMetadata,
          cancelledBy: studentId,
          cancelledAt: Date.now(),
          cancelReason: "cancelled_by_student",
        },
      });

    console.log("🔔 Cancelling active notifications...");

    // Находим и отменяем все активные уведомления для этой сессии
    const activeNotificationsQuery = await admin
      .firestore()
      .collection("notifications")
      .where("sessionId", "==", resolvedSessionId) // Изменено с callRequestId
      .where("status", "==", "sent")
      .get();

    if (!activeNotificationsQuery.empty) {
      console.log(
        `📨 Found ${activeNotificationsQuery.size} active notifications to cancel`,
      );

      const batch = admin.firestore().batch();
      activeNotificationsQuery.forEach((doc) => {
        batch.update(doc.ref, {
          status: "cancelled",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();

      console.log("✅ Active notifications cancelled");
    } else {
      console.log("📭 No active notifications found");
    }

    // Если есть текущий преподаватель, освобождаем его
    if (sessionData.currentTutorId) {
      console.log("👨‍🏫 Releasing current tutor:", sessionData.currentTutorId);
      try {
        await admin
          .firestore()
          .collection("users")
          .doc(sessionData.currentTutorId)
          .update({
            currentSessionId: admin.firestore.FieldValue.delete(),
          });
      } catch (tutorUpdateError) {
        console.log(
          "⚠️ Could not update tutor status (non-critical):",
          tutorUpdateError.message,
        );
      }
    }

    console.log("✅ Video session successfully cancelled");

    return {
      status: "cancelled",
      message: "Video session cancelled successfully",
      sessionId: resolvedSessionId,
      callId: resolvedSessionId,
    };
  } catch (error) {
    console.error("❌ Error cancelling video session:", error);

    if (error.code) {
      throw error;
    }

    throw new functions.https.HttpsError("internal", error.message);
  }
});

// ОТПРАВКА УВЕДОМЛЕНИЯ СЛЕДУЮЩЕМУ ПРЕПОДАВАТЕЛЮ
async function sendNotificationToNextTutor(sessionId, sessionData) {
  try {
    const availableTutors = sessionData.availableTutors || [];
    const triedTutors = sessionData.triedTutors || [];

    console.log("🎯 Available tutors:", availableTutors);
    console.log("❌ Tried tutors:", triedTutors);

    // Находим следующего преподавателя
    const nextTutor = availableTutors.find(
      (tutorId) => !triedTutors.includes(tutorId),
    );

    if (!nextTutor) {
      console.log("❌ No more tutors available");
      // Обновляем статус сессии
      await admin
        .firestore()
        .collection("videoSessions")
        .doc(sessionId)
        .update({
          status: "no_tutors_available",
          sessionMetadata: {
            ...sessionData.sessionMetadata,
            noTutorsReason: "All available tutors have been tried",
          },
        });
      return;
    }

    console.log("📨 Sending notification to tutor:", nextTutor);

    // Обновляем текущего преподавателя в сессии
    await admin.firestore().collection("videoSessions").doc(sessionId).update({
      currentTutorId: nextTutor,
    });

    // Создаем уведомление
    const expiresAt = new Date();
    expiresAt.setSeconds(expiresAt.getSeconds() + 45); // 45 секунд на ответ

    const notificationData = {
      recipientId: nextTutor,
      sessionId: sessionId, // Изменено с callRequestId
      type: "incoming_call",
      status: "sent",
      title: "Входящий звонок",
      message: `${sessionData.studentInfo.name} хочет попрактиковать ${sessionData.language}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      studentInfo: sessionData.studentInfo,
    };

    await admin.firestore().collection("notifications").add(notificationData);
    console.log("✅ Notification sent to tutor:", nextTutor);
  } catch (error) {
    console.error("❌ Error sending notification to tutor:", error);
  }
}
