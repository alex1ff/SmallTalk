const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { sendApnsVoip } = require("./apns_voip");
const {
  createDailyRoom,
  createMeetingToken,
  getRoomNameFromUrl,
} = require("./daily_room");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];

exports.acceptCall = functions
  .runWith({ secrets: apnsSecrets })
  .https.onCall(async (data, context) => {
    console.log("✅ Tutor accepting call (updated version)...");

    try {
      // === 1. АУТЕНТИФИКАЦИЯ И ВАЛИДАЦИЯ ===
      if (!context.auth) {
        console.log("❌ User not authenticated");
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
        console.log("❌ Missing sessionId parameter");
        throw new functions.https.HttpsError(
          "invalid-argument",
          "sessionId is required",
        );
      }

      // === 2. ПОЛУЧЕНИЕ И ВАЛИДАЦИЯ ДАННЫХ СЕССИИ ===
      console.log("📋 Fetching video session data...");
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
      console.log("📋 Session data:", {
        status: sessionData.status,
        currentTutorId: sessionData.currentTutorId,
        studentId: sessionData.studentId,
        language: sessionData.language,
      });

      // Идемпотентность: если сессия уже активна для этого же преподавателя,
      // возвращаем существующие данные комнаты, не создавая новую.
      if (["active", "connecting"].includes(sessionData.status)) {
        if (sessionData.tutorId === tutorId && sessionData.dailyRoomUrl) {
          console.log(
            "ℹ️ Session already active for this tutor, returning existing room",
          );
          let existingRoomName =
            sessionData.dailyRoomName ||
            getRoomNameFromUrl(sessionData.dailyRoomUrl);
          let existingMeetingToken = sessionData.meetingToken || null;

          if (!existingMeetingToken && existingRoomName) {
            try {
              existingMeetingToken = await createMeetingToken({
                roomName: existingRoomName,
                expSeconds: 3600,
              });
            } catch (tokenError) {
              console.error(
                "⚠️ Failed to create meeting token for existing room:",
                tokenError.message,
              );
            }
          }

          return {
            status: "connected",
            sessionId: sessionId,
            roomUrl: sessionData.dailyRoomUrl,
            roomName: existingRoomName || null,
            meetingToken: existingMeetingToken || null,
            studentInfo: sessionData.studentInfo || null,
            sessionData: {
              language: sessionData.language,
              startedAt:
                sessionData.startedAt?.toMillis?.() ||
                sessionData.startedAt ||
                null,
              maxDuration: 3600000,
            },
          };
        }

        console.log(
          "❌ Session is already active with another tutor or missing room data",
          sessionData.status,
        );
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Session is already active",
        );
      }

      // Проверяем, что сессия в статусе поиска
      if (sessionData.status !== "searching") {
        console.log(
          "❌ Session is not in searching status, current status:",
          sessionData.status,
        );
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Session is not available for acceptance",
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

      // Проверяем, что сессия не истекла
      if (
        sessionData.expiresAt &&
        sessionData.expiresAt.toDate() < new Date()
      ) {
        console.log("❌ Session has expired");
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Session has expired",
        );
      }

      // === 3. ПОЛУЧЕНИЕ И ВАЛИДАЦИЯ ДАННЫХ ПРЕПОДАВАТЕЛЯ ===
      console.log("👨‍🏫 Fetching tutor data...");
      const tutorDoc = await admin
        .firestore()
        .collection("users")
        .doc(tutorId)
        .get();

      if (!tutorDoc.exists) {
        console.log("❌ Tutor not found:", tutorId);
        throw new functions.https.HttpsError("not-found", "Tutor not found");
      }

      const tutorData = tutorDoc.data();
      const availabilityToday = tutorData.availabilityToday;
      const isAvailable =
        tutorData.isAvailable !== undefined
          ? tutorData.isAvailable
          : (availabilityToday?.enabled ?? true);

      console.log("👨‍🏫 Tutor data:", {
        display_name: tutorData.display_name,
        role: tutorData.role,
        isAvailable: tutorData.isAvailable,
        availabilityTodayEnabled: availabilityToday?.enabled,
        isInCall: tutorData.isInCall,
      });

      const allowedRoles = ["tutor", "native_speaker"];
      if (!allowedRoles.includes(tutorData.role)) {
        console.log("❌ User is not a tutor, role:", tutorData.role);
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only tutors can accept calls",
        );
      }

      if (!isAvailable) {
        console.log("❌ Tutor is not available");
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Tutor is not available",
        );
      }

      if (tutorData.isInCall) {
        console.log("❌ Tutor is already in a call");
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Tutor is already in a call",
        );
      }

      // === 4. ПОЛУЧЕНИЕ ДАННЫХ СТУДЕНТА ===
      console.log("👨‍🎓 Fetching student data...");
      const studentDoc = await admin
        .firestore()
        .collection("users")
        .doc(sessionData.studentId)
        .get();

      if (!studentDoc.exists) {
        console.log("❌ Student not found:", sessionData.studentId);
        throw new functions.https.HttpsError("not-found", "Student not found");
      }

      const studentData = studentDoc.data();
      console.log("👨‍🎓 Student data:", {
        display_name: studentData.display_name,
        role: studentData.role,
      });

      // === 5. ПОЛУЧЕНИЕ ИЛИ СОЗДАНИЕ КОМНАТЫ DAILY.CO ===
      console.log("🏠 Resolving Daily.co room...");

      let roomUrl = sessionData.dailyRoomUrl || null;
      let roomName =
        sessionData.dailyRoomName || getRoomNameFromUrl(sessionData.dailyRoomUrl);
      let meetingToken = sessionData.meetingToken || null;
      let roomPrecreated = false;
      let roomCreatedAt = sessionData.sessionMetadata?.roomCreatedAt || null;

      if (roomUrl) {
        roomPrecreated = true;
        console.log("♻️ Using precreated Daily room:", {
          roomName,
          roomUrl,
          hasToken: !!meetingToken,
        });
        if (!meetingToken && roomName) {
          try {
            meetingToken = await createMeetingToken({
              roomName,
              expSeconds: 3600,
            });
          } catch (tokenError) {
            console.error(
              "❌ Failed to create meeting token for precreated room:",
              tokenError.message,
            );
          }
        }
        if (!meetingToken) {
          console.error(
            "⚠️ Precreated room has no valid meeting token, recreating room",
          );
          roomUrl = null;
          roomName = null;
          roomPrecreated = false;
          roomCreatedAt = null;
        }
      }

      if (!roomUrl) {
        try {
          const dailyRoom = await createDailyRoom({
            language: sessionData.language,
            studentId: sessionData.studentId,
            tutorId,
            studentName:
              sessionData.studentInfo?.name ||
              studentData.display_name ||
              "Student",
            tutorName: tutorData.display_name || "Tutor",
            expSeconds: 3600,
          });
          roomUrl = dailyRoom.url;
          roomName = dailyRoom.name;
          roomCreatedAt = Date.now();

          meetingToken = await createMeetingToken({
            roomName,
            expSeconds: 3600,
          });
        } catch (roomError) {
          console.error("❌ Failed to create Daily room:", roomError);
          throw new functions.https.HttpsError(
            "internal",
            "Failed to create video room",
          );
        }
      }

      if (!meetingToken) {
        console.error("❌ Daily meeting token creation failed");
        throw new functions.https.HttpsError(
          "internal",
          "Failed to create meeting token",
        );
      }

      // 🔔 === ОТПРАВКА VOIP PUSH СТУДЕНТУ (ДОБАВЛЕНО) ===
      console.log("📲 Sending VoIP push notification to student...");
      try {
        await sendVoipPushToStudent(sessionData.studentId, {
          sessionId: sessionId,
          callerName: tutorData.display_name || "Преподаватель",
          callerId: tutorId,
          callerPhoto: tutorData.photo_url || null,
          roomUrl: roomUrl,
          meetingToken: meetingToken,
        });
        console.log("✅ VoIP push notification sent to student");
      } catch (pushError) {
        console.error(
          "⚠️ Failed to send VoIP push (non-critical):",
          pushError.message,
        );
        // Продолжаем работу даже если push не отправился
      }

      // === 6. ОБНОВЛЕНИЕ СЕССИИ В ТРАНЗАКЦИИ ===
      console.log("🔄 Updating session and user statuses in transaction...");
      const activeExpiresAt = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 60 * 60 * 1000),
      );
      await admin.firestore().runTransaction(async (transaction) => {
        // Обновляем сессию - добавляем данные для активной сессии
        transaction.update(
          admin.firestore().collection("videoSessions").doc(sessionId),
          {
            // Обновляем основные поля
            tutorId: tutorId,
            status: "active",
            acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
            startedAt: admin.firestore.FieldValue.serverTimestamp(),

            // Добавляем данные Daily.co
            dailyRoomUrl: roomUrl,
            dailyRoomName: roomName,
            meetingToken: meetingToken,
            expiresAt: activeExpiresAt,

            // Добавляем информацию о преподавателе
            tutorInfo: {
              name: tutorData.display_name || "Tutor",
              photo: tutorData.photo_url || null,
            },

            // Очищаем поля поиска (уже не нужны)
            currentTutorId: null,
            tutorNavigationTriggered: false,
            studentNavigationTriggered: false,

            // Обновляем метаданные
            sessionMetadata: {
              acceptedBy: tutorId,
              acceptedAt: Date.now(),
              roomProvider: "daily",
              roomCreatedAt: roomCreatedAt || Date.now(),
              roomPrecreated: roomPrecreated,
            },
          },
        );

        // Обновляем статус преподавателя
        transaction.update(admin.firestore().collection("users").doc(tutorId), {
          isInCall: true,
          currentSessionId: sessionId,
        });

        console.log("✅ Transaction completed successfully");
      });

      // === 7. ОБНОВЛЕНИЕ УВЕДОМЛЕНИЙ ===
      console.log("🔔 Updating notifications...");
      await updateNotificationStatus(sessionId, tutorId, "accepted");
      await cancelOtherNotifications(sessionId, tutorId);

      // === 8. ПОДГОТОВКА ОТВЕТА ===
      console.log("🎉 Call accepted successfully, preparing response...");

      const response = {
        status: "connected",
        sessionId: sessionId,
        roomUrl: roomUrl,
        roomName: roomName,
        meetingToken: meetingToken,
        studentInfo: {
          name:
            sessionData.studentInfo?.name ||
            studentData.display_name ||
            "Student",
          photo:
            sessionData.studentInfo?.photo || studentData.photo_url || null,
        },
        sessionData: {
          language: sessionData.language,
          startedAt: Date.now(),
          maxDuration: 3600000, // 1 час в миллисекундах
        },
      };

      console.log("📤 Returning response:", {
        status: response.status,
        sessionId: response.sessionId,
        hasRoomUrl: !!response.roomUrl,
        hasToken: !!response.meetingToken,
        studentName: response.studentInfo.name,
      });

      return response;
    } catch (error) {
      console.error("❌ Error in acceptCall function:", error);

      if (error.code && error.message) {
        throw error;
      }

      console.error("❌ Unexpected error details:", {
        message: error.message,
        stack: error.stack,
        name: error.name,
      });

      throw new functions.https.HttpsError(
        "internal",
        `Internal server error: ${error.message}`,
      );
    }
  });

// === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===

// 🔔 ОТПРАВКА VOIP PUSH NOTIFICATION (НОВАЯ ФУНКЦИЯ)
async function sendVoipPushToStudent(studentId, callData) {
  try {
    console.log("📲 Preparing VoIP push for student:", studentId);

    // Получаем данные студента из Firestore
    const studentDoc = await admin
      .firestore()
      .collection("users")
      .doc(studentId)
      .get();

    if (!studentDoc.exists) {
      console.log("⚠️ Student document not found:", studentId);
      return;
    }

    const studentData = studentDoc.data();
    const bundleId = process.env.IOS_BUNDLE_ID || "com.appwave.smalltalk";
    const voipTopic =
      process.env.IOS_VOIP_TOPIC ||
      (bundleId.endsWith(".voip") ? bundleId : `${bundleId}.voip`);
    const voipPushToken = studentData.voipPushToken;
    const fcmToken = studentData.voipToken;

    if (!voipPushToken && !fcmToken) {
      console.log("⚠️ Student has no push tokens saved.");
      console.log("⚠️ Student data keys:", Object.keys(studentData));
      return;
    }

    if (voipPushToken) {
      const apnsPayload = {
        aps: { "content-available": 1 },
        type: "incoming_call",
        sessionId: callData.sessionId,
        callerName: callData.callerName,
        callerId: callData.callerId,
        callerPhoto: callData.callerPhoto || "",
        roomUrl: callData.roomUrl || "",
        meetingToken: callData.meetingToken || "",
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
        callerName: callData.callerName,
        callerId: callData.callerId,
        callerPhoto: callData.callerPhoto || "",
        roomUrl: callData.roomUrl || "",
        meetingToken: callData.meetingToken || "",
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
              body: `${callData.callerName} звонит вам`,
            },
            sound: "default",
          },
        },
      },
      android: {
        priority: "high",
      },
    };

    console.log("📤 Sending VoIP push via FCM...");

    const response = await admin.messaging().send(message);

    console.log("✅ FCM push sent successfully. Message ID:", response);

    return response;
  } catch (error) {
    console.error("❌ Error sending VoIP push:", error);

    // Логируем детали ошибки
    if (error.code) {
      console.error("❌ Error code:", error.code);
    }
    if (error.message) {
      console.error("❌ Error message:", error.message);
    }
    if (error.errorInfo) {
      console.error("❌ Error info:", JSON.stringify(error.errorInfo));
    }

    // Бросаем ошибку дальше, чтобы она была залогирована
    throw error;
  }
}

// Daily room helpers moved to daily_room.js

// ОБНОВЛЕНИЕ СТАТУСА УВЕДОМЛЕНИЯ
async function updateNotificationStatus(sessionId, tutorId, status) {
  try {
    console.log(`🔔 Updating notification status to ${status}...`);

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
          status: status,
          [`${status}At`]: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();
      console.log(
        `✅ Updated ${notificationsQuery.size} notification(s) to ${status}`,
      );
    } else {
      console.log("📭 No notifications found to update");
    }
  } catch (error) {
    console.error("❌ Error updating notification status:", error);
  }
}

// ОТМЕНА ДРУГИХ УВЕДОМЛЕНИЙ
async function cancelOtherNotifications(sessionId, acceptedTutorId) {
  try {
    console.log("🚫 Canceling other active notifications...");

    const otherNotificationsQuery = await admin
      .firestore()
      .collection("notifications")
      .where("sessionId", "==", sessionId)
      .where("status", "==", "sent")
      .get();

    if (!otherNotificationsQuery.empty) {
      const batch = admin.firestore().batch();
      let canceledCount = 0;

      otherNotificationsQuery.forEach((doc) => {
        const notificationData = doc.data();
        if (notificationData.recipientId !== acceptedTutorId) {
          batch.update(doc.ref, {
            status: "cancelled",
            cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
            cancelReason: "call_accepted_by_other_tutor",
          });
          canceledCount++;
        }
      });

      if (canceledCount > 0) {
        await batch.commit();
        console.log(`✅ Canceled ${canceledCount} other notification(s)`);
      }
    }
  } catch (error) {
    console.error("❌ Error canceling other notifications:", error);
  }
}
