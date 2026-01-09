const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { sendApnsVoip } = require("./apns_voip");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];

/*
ОБНОВЛЕННАЯ ФУНКЦИЯ: declineCall
Теперь работает с sessionId и обновляет videoSessions
*/

exports.declineCall = functions
  .runWith({ secrets: apnsSecrets })
  .https.onCall(async (data, context) => {
  console.log("❌ Tutor declining call (updated version)...");

  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
      );
    }

    const tutorId = context.auth.uid;
    const { sessionId } = data;

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
    const allowedRoles = ["tutor", "native_speaker"];
    if (!tutorDoc.exists || !allowedRoles.includes(tutorDoc.data().role)) {
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
        currentTutorId: null,
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
      .where("sessionId", "==", sessionId)
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

// 🔔 ОТПРАВКА VOIP PUSH ПРЕПОДАВАТЕЛЮ
async function sendVoipPushToTutor(tutorId, callData) {
  try {
    console.log("📲 Preparing VoIP push for tutor:", tutorId);

    const tutorDoc = await admin
      .firestore()
      .collection("users")
      .doc(tutorId)
      .get();

    if (!tutorDoc.exists) {
      console.log("⚠️ Tutor document not found:", tutorId);
      return;
    }

    const tutorData = tutorDoc.data();
    const bundleId = process.env.IOS_BUNDLE_ID || "com.appwave.smalltalk";
    const voipTopic =
      process.env.IOS_VOIP_TOPIC ||
      (bundleId.endsWith(".voip") ? bundleId : `${bundleId}.voip`);
    const voipPushToken = tutorData.voipPushToken;
    const fcmToken = tutorData.voipToken;

    if (!voipPushToken && !fcmToken) {
      console.log("⚠️ Tutor has no push tokens saved");
      return;
    }

    if (voipPushToken) {
      const apnsPayload = {
        aps: { "content-available": 1 },
        type: "incoming_call",
        sessionId: callData.sessionId,
        callerName: callData.studentName,
        callerId: callData.studentId,
        callerPhoto: callData.studentPhoto || "",
        language: callData.language || "",
      };

      try {
        await sendApnsVoip({
          deviceToken: voipPushToken,
          topic: voipTopic,
          payload: apnsPayload,
        });
        console.log("✅ APNs VoIP push sent successfully");
        return;
      } catch (error) {
        console.error("❌ Error sending APNs VoIP push:", error.message);
      }
    }

    if (!fcmToken) {
      console.log("⚠️ No FCM token available for fallback");
      return;
    }

    console.log("📱 FCM token found:", fcmToken.substring(0, 20) + "...");
    console.log("📦 Using apns-topic for FCM fallback:", bundleId);

    const message = {
      token: fcmToken,
      data: {
        type: "incoming_call",
        sessionId: callData.sessionId,
        callerName: callData.studentName,
        callerId: callData.studentId,
        callerPhoto: callData.studentPhoto || "",
        language: callData.language || "",
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
          "apns-topic": bundleId,
        },
        payload: {
          aps: {
            "content-available": 1,
            alert: {
              title: "Входящий звонок",
              body: `${callData.studentName} хочет попрактиковать ${callData.language}`,
            },
            sound: "default",
          },
        },
      },
      android: {
        priority: "high",
      },
    };

    const response = await admin.messaging().send(message);
    console.log("✅ FCM push sent successfully. Message ID:", response);

    return response;
  } catch (error) {
    console.error("❌ Error sending VoIP push to tutor:", error);
    return null;
  }
}

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

    // Создаем уведомление в Firestore
    const expiresAt = new Date();
    expiresAt.setSeconds(expiresAt.getSeconds() + 45);

    const notificationData = {
      recipientId: nextTutor,
      sessionId: sessionId,
      type: "incoming_call",
      status: "sent",
      title: "Входящий звонок",
      message: `${sessionData.studentInfo.name} хочет попрактиковать ${sessionData.language}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      studentInfo: sessionData.studentInfo,
    };

    await admin.firestore().collection("notifications").add(notificationData);
    console.log("✅ Firestore notification created for tutor:", nextTutor);

    // 🔔 Отправляем VoIP push преподавателю
    console.log("📲 Sending VoIP push to next tutor...");
    try {
      await sendVoipPushToTutor(nextTutor, {
        sessionId: sessionId,
        studentName: sessionData.studentInfo.name,
        studentId: sessionData.studentId,
        studentPhoto: sessionData.studentInfo.photo,
        language: sessionData.language,
      });
      console.log("✅ VoIP push sent to next tutor");
    } catch (pushError) {
      console.error(
        "⚠️ Failed to send VoIP push (non-critical):",
        pushError.message,
      );
    }
  } catch (error) {
    console.error("❌ Error sending notification to tutor:", error);
  }
}
