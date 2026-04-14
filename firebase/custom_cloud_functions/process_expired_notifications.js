const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { sendApnsVoip } = require("./apns_voip");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];

exports.processExpiredNotifications = functions
  .runWith({ secrets: apnsSecrets })
  .pubsub.schedule("every 1 minutes")
  .onRun(async () => {
    console.log("⏰ Processing expired notifications (updated version)...");
    const now = admin.firestore.Timestamp.now();

    try {
      // Находим истекшие уведомления о звонках
      const expiredQuery = await admin
        .firestore()
        .collection("notifications")
        .where("type", "==", "incoming_call")
        .where("status", "==", "sent")
        .where("expiresAt", "<=", now)
        .get();

      if (expiredQuery.empty) {
        console.log("📭 No expired notifications found");
        return null;
      }

      console.log(`⏰ Found ${expiredQuery.size} expired notifications`);

      // Обрабатываем каждое истекшее уведомление
      const batch = admin.firestore().batch();
      const sessionsToProcess = new Set();

      expiredQuery.docs.forEach((doc) => {
        const notificationData = doc.data();

        console.log(
          `📝 Marking notification ${doc.id} as expired for tutor: ${notificationData.recipientId}`,
        );

        // Отмечаем уведомление как истекшее
        batch.update(doc.ref, {
          status: "expired",
          expiredAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Добавляем sessionId для дальнейшей обработки
        if (notificationData.sessionId) {
          sessionsToProcess.add(notificationData.sessionId);
        }
      });

      // Применяем изменения к уведомлениям
      await batch.commit();
      console.log("✅ All expired notifications marked");

      // Обрабатываем каждую уникальную сессию
      console.log(`🔄 Processing ${sessionsToProcess.size} video sessions...`);

      for (const sessionId of sessionsToProcess) {
        try {
          await processExpiredSession(sessionId);
        } catch (error) {
          console.error(
            `❌ Error processing session ${sessionId}:`,
            error.message,
          );
        }
      }

      console.log("✅ Expired notifications processing completed");
      return null;
    } catch (error) {
      console.error("❌ Error processing expired notifications:", error);
      return null;
    }
  });

// ОБРАБОТКА ИСТЕКШЕЙ СЕССИИ
async function processExpiredSession(sessionId) {
  try {
    console.log(`📺 Processing expired session: ${sessionId}`);
    const sessionRef = admin
      .firestore()
      .collection("videoSessions")
      .doc(sessionId);

    const transition = await admin.firestore().runTransaction(
      async (transaction) => {
        const freshSessionSnap = await transaction.get(sessionRef);
        if (!freshSessionSnap.exists) {
          return {
            shouldNotify: false,
            skipReason: "session_not_found",
          };
        }

        const freshSessionData = freshSessionSnap.data() || {};
        const status = freshSessionData.status || "unknown";
        if (status !== "searching") {
          return {
            shouldNotify: false,
            skipReason: `status_${status}`,
          };
        }

        const currentTutorId = freshSessionData.currentTutorId;
        if (!currentTutorId) {
          return {
            shouldNotify: false,
            skipReason: "missing_current_tutor",
          };
        }

        const triedTutors = [...(freshSessionData.triedTutors || [])];
        if (!triedTutors.includes(currentTutorId)) {
          triedTutors.push(currentTutorId);
        }

        transaction.update(sessionRef, {
          triedTutors: triedTutors,
          currentTutorId: admin.firestore.FieldValue.delete(),
        });

        return {
          shouldNotify: true,
          timedOutTutorId: currentTutorId,
          sessionData: {
            ...freshSessionData,
            triedTutors: triedTutors,
            currentTutorId: null,
          },
        };
      },
    );

    if (!transition || !transition.shouldNotify) {
      console.log(
        "⏭️ Skipping expired session processing for",
        sessionId,
        "reason:",
        transition?.skipReason || "unknown",
      );
      return;
    }

    console.log(
      `👨‍🏫 Current tutor ${transition.timedOutTutorId} did not respond - searching next`,
    );
    await sendNotificationToNextTutor(sessionId, transition.sessionData || {});
    console.log(`✅ Session ${sessionId} processed successfully`);
  } catch (error) {
    console.error(`❌ Error processing session ${sessionId}:`, error);
    throw error;
  }
}

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
async function sendNotificationToNextTutor(sessionId, fallbackSessionData = {}) {
  try {
    const sessionRef = admin
      .firestore()
      .collection("videoSessions")
      .doc(sessionId);

    const assignment = await admin.firestore().runTransaction(
      async (transaction) => {
        const freshSessionSnap = await transaction.get(sessionRef);
        if (!freshSessionSnap.exists) {
          return {
            shouldNotify: false,
            skipReason: "session_not_found",
          };
        }

        const freshSessionData = freshSessionSnap.data() || {};
        const status = freshSessionData.status || "unknown";
        if (status !== "searching") {
          return {
            shouldNotify: false,
            skipReason: `status_${status}`,
          };
        }

        if (freshSessionData.currentTutorId) {
          return {
            shouldNotify: false,
            skipReason: `tutor_already_assigned_${freshSessionData.currentTutorId}`,
          };
        }

        const availableTutors = freshSessionData.availableTutors || [];
        const triedTutors = freshSessionData.triedTutors || [];

        console.log("🎯 Available tutors:", availableTutors);
        console.log("❌ Tried tutors:", triedTutors);

        const nextTutor = availableTutors.find(
          (tutorId) => !triedTutors.includes(tutorId),
        );

        if (!nextTutor) {
          transaction.update(sessionRef, {
            status: "no_tutors_available",
          });
          return {
            shouldNotify: false,
            skipReason: "no_available_tutors",
          };
        }

        transaction.update(sessionRef, {
          currentTutorId: nextTutor,
        });

        return {
          shouldNotify: true,
          nextTutor,
          sessionData: freshSessionData,
        };
      },
    );

    if (!assignment || !assignment.shouldNotify) {
      console.log(
        "⏭️ Skipping next tutor notification for session",
        sessionId,
        "reason:",
        assignment?.skipReason || "unknown",
      );
      return;
    }

    const nextTutor = assignment.nextTutor;
    const sessionData = assignment.sessionData || fallbackSessionData || {};
    const studentInfo = sessionData.studentInfo || fallbackSessionData.studentInfo || {};
    const studentName = studentInfo.name || "Student";
    const studentPhoto = studentInfo.photo || null;
    const studentId = sessionData.studentId || fallbackSessionData.studentId || "";
    const language = sessionData.language || fallbackSessionData.language || "";

    const freshValidationSnap = await sessionRef.get();
    if (!freshValidationSnap.exists) {
      console.log(
        "⏭️ Skipping next tutor notification. Session disappeared:",
        sessionId,
      );
      return;
    }

    const freshValidation = freshValidationSnap.data() || {};
    if (
      freshValidation.status !== "searching" ||
      freshValidation.currentTutorId !== nextTutor
    ) {
      console.log(
        "⏭️ Skipping next tutor notification after validation. reason:",
        `status_${freshValidation.status || "unknown"}`,
        `currentTutor_${freshValidation.currentTutorId || "none"}`,
      );
      return;
    }

    console.log("📨 Sending notification to next tutor:", nextTutor);

    // Создаем уведомление в Firestore
    const expiresAt = new Date();
    expiresAt.setSeconds(expiresAt.getSeconds() + 45);

    const notificationData = {
      recipientId: nextTutor,
      sessionId: sessionId,
      type: "incoming_call",
      status: "sent",
      title: "Входящий звонок",
      message: `${studentName} хочет попрактиковать ${language}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      studentInfo: studentInfo,
    };

    await admin.firestore().collection("notifications").add(notificationData);
    console.log("✅ Firestore notification created for tutor:", nextTutor);

    // 🔔 Отправляем VoIP push преподавателю
    console.log("📲 Sending VoIP push to next tutor...");
    try {
      await sendVoipPushToTutor(nextTutor, {
        sessionId: sessionId,
        studentName: studentName,
        studentId: studentId,
        studentPhoto: studentPhoto,
        language: language,
      });
      console.log("✅ VoIP push sent to next tutor");
    } catch (pushError) {
      console.error(
        "⚠️ Failed to send VoIP push (non-critical):",
        pushError.message,
      );
    }
  } catch (error) {
    console.error("❌ Error sending notification to next tutor:", error);
  }
}
