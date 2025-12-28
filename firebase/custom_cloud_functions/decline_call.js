const functions = require("firebase-functions");
const admin = require("firebase-admin");

/*
ОБНОВЛЕННАЯ ФУНКЦИЯ: declineCall
Теперь работает с sessionId и обновляет videoSessions
*/

exports.declineCall = functions.https.onCall(async (data, context) => {
  console.log("❌ Tutor declining call (updated version)...");

  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
      );
    }

    const tutorId = context.auth.uid;
    const { sessionId } = data; // Изменено с callRequestId на sessionId

    console.log("👨‍🏫 Tutor ID:", tutorId);
    console.log("📺 Session ID:", sessionId);

    if (!sessionId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Session ID is required",
      );
    }

    // Получаем данные видео сессии
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
    console.log("📋 Session data status:", sessionData.status);
    console.log("👤 Current tutor ID:", sessionData.currentTutorId);

    // Проверяем, что сессия в статусе поиска
    if (sessionData.status !== "searching") {
      console.log("❌ Session is not in searching status:", sessionData.status);
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Session is not available for declining",
      );
    }

    // Проверяем, что звонок адресован этому преподавателю
    if (sessionData.currentTutorId !== tutorId) {
      console.log(
        "❌ Session is not for this tutor. Expected:",
        sessionData.currentTutorId,
        "Got:",
        tutorId,
      );
      throw new functions.https.HttpsError(
        "permission-denied",
        "This session is not assigned to you",
      );
    }

    // Получаем данные преподавателя (для валидации роли)
    const tutorDoc = await admin
      .firestore()
      .collection("users")
      .doc(tutorId)
      .get();
    if (!tutorDoc.exists || tutorDoc.data().role !== "tutor") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only tutors can decline calls",
      );
    }

    console.log("🔄 Processing session decline...");

    // Добавляем преподавателя в список попыток
    const triedTutors = [...(sessionData.triedTutors || []), tutorId];

    console.log("📝 Updating tried tutors list:", triedTutors);

    // Обновляем сессию
    await admin
      .firestore()
      .collection("videoSessions")
      .doc(sessionId)
      .update({
        triedTutors: triedTutors,
        currentTutorId: null, // сбрасываем текущего преподавателя
        sessionMetadata: {
          ...sessionData.sessionMetadata,
          lastDeclinedBy: tutorId,
          lastDeclinedAt: Date.now(),
        },
      });

    console.log("🔔 Marking notification as declined...");

    // Отмечаем уведомление как отклоненное
    const notificationsQuery = await admin
      .firestore()
      .collection("notifications")
      .where("sessionId", "==", sessionId) // Изменено с callRequestId
      .where("recipientId", "==", tutorId)
      .where("status", "==", "sent")
      .get();

    if (!notificationsQuery.empty) {
      const batch = admin.firestore().batch();
      notificationsQuery.forEach((doc) => {
        batch.update(doc.ref, {
          status: "declined",
          declinedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();
      console.log("✅ Notification marked as declined");
    }

    // Отправляем уведомление следующему преподавателю
    console.log("📨 Sending notification to next tutor...");
    await sendNotificationToNextTutor(sessionId, {
      ...sessionData,
      triedTutors: triedTutors,
    });

    console.log("✅ Call declined successfully");

    return {
      status: "declined",
      message: "Call declined successfully",
    };
  } catch (error) {
    console.error("❌ Error declining call:", error);

    if (error.code) {
      throw error;
    }

    throw new functions.https.HttpsError("internal", error.message);
  }
});
