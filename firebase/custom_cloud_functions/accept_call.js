const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { sendApnsVoip } = require("./apns_voip");
const {
  createDailyRoom,
  createMeetingToken,
  getDailyRoom,
  getRoomNameFromUrl,
} = require("./daily_room");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];

exports.acceptCall = functions
  .runWith({ secrets: [...apnsSecrets, ...dailySecrets] })
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
          let existingMeetingToken = null;

          if (existingRoomName) {
            try {
              existingMeetingToken = await createMeetingToken({
                roomName: existingRoomName,
                expSeconds: 3600,
                isOwner: false,
                userId: tutorId,
                userName:
                  sessionData.tutorInfo?.name ||
                  sessionData.tutorName ||
                  "Tutor",
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

      // === 2.5. БЛОКИРОВКА ACCEPT (защита от параллельных accept) ===
      const sessionRef = admin
        .firestore()
        .collection("videoSessions")
        .doc(sessionId);
      const acceptLockWindowMs = 30 * 1000;
      let lockAcquired = false;
      await admin.firestore().runTransaction(async (transaction) => {
        const freshSnap = await transaction.get(sessionRef);
        if (!freshSnap.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "Video session not found",
          );
        }
        const fresh = freshSnap.data();
        if (fresh.status !== "searching") {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Session is already active",
          );
        }
        if (fresh.currentTutorId !== tutorId) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "This session is not assigned to you",
          );
        }
        const acceptingTutorId = fresh.acceptingTutorId || null;
        const acceptingAtMs = fresh.acceptingAt?.toMillis?.() || 0;
        const nowMs = Date.now();
        if (
          !acceptingTutorId ||
          nowMs - acceptingAtMs > acceptLockWindowMs
        ) {
          transaction.update(sessionRef, {
            acceptingTutorId: tutorId,
            acceptingAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          lockAcquired = true;
          return;
        }
        if (acceptingTutorId === tutorId) {
          transaction.update(sessionRef, {
            acceptingAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          lockAcquired = true;
          return;
        }
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Session is already being accepted",
        );
      });

      // === 3. ПОЛУЧЕНИЕ ДАННЫХ ПРЕПОДАВАТЕЛЯ И СТУДЕНТА (ПАРАЛЛЕЛЬНО) ===
      console.log("👨‍🏫 Fetching tutor and student data in parallel...");
      const [tutorDoc, studentDoc] = await Promise.all([
        admin.firestore().collection("users").doc(tutorId).get(),
        admin.firestore().collection("users").doc(sessionData.studentId).get(),
      ]);

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
      if (roomUrl) {
        const derivedName = getRoomNameFromUrl(roomUrl);
        if (derivedName) {
          if (!roomName || roomName !== derivedName) {
            console.log("⚠️ Room name mismatch, using name from URL", {
              roomName,
              derivedName,
            });
            roomName = derivedName;
          }
        }
      }
      let meetingToken = null;
      let roomPrecreated = false;
      let roomCreatedAt = sessionData.sessionMetadata?.roomCreatedAt || null;

      if (roomUrl) {
        roomPrecreated = true;
        console.log("♻️ Using precreated Daily room:", {
          roomName,
          roomUrl,
          hasToken: !!meetingToken,
        });
        if (!roomName) {
          roomName = getRoomNameFromUrl(roomUrl);
        }
        if (roomName) {
          // Skip Daily API validation if room was created recently (< 60s)
          const roomAgeMs = roomCreatedAt ? Date.now() - roomCreatedAt : Infinity;
          if (roomAgeMs > 60000) {
            const existingRoom = await getDailyRoom(roomName);
            if (!existingRoom) {
              console.warn(
                "⚠️ Precreated room not found in Daily, recreating room",
              );
              roomUrl = null;
              roomName = null;
              roomPrecreated = false;
              roomCreatedAt = null;
            }
          } else {
            console.log("⚡ Skipping room validation - room is fresh (" + roomAgeMs + "ms old)");
          }
        } else {
          roomUrl = null;
          roomPrecreated = false;
          roomCreatedAt = null;
        }
      }

      let studentMeetingToken = null;

      if (roomUrl && roomName) {
        // Create tutor and student tokens in parallel
        try {
          const studentName = sessionData.studentInfo?.name || studentData.display_name || "Student";
          const [tutorToken, studentToken] = await Promise.all([
            createMeetingToken({
              roomName,
              expSeconds: 3600,
              isOwner: false,
              userId: tutorId,
              userName: tutorData.display_name || "Tutor",
            }),
            createMeetingToken({
              roomName,
              expSeconds: 3600,
              isOwner: true,
              userId: sessionData.studentId,
              userName: studentName,
            }),
          ]);
          meetingToken = tutorToken;
          studentMeetingToken = studentToken;
        } catch (tokenError) {
          console.error(
            "❌ Failed to create meeting tokens for precreated room:",
            tokenError.message,
          );
        }
        if (!meetingToken) {
          console.error(
            "⚠️ Precreated room has no valid meeting token, recreating room",
          );
          roomUrl = null;
          roomName = null;
          roomPrecreated = false;
          roomCreatedAt = null;
          studentMeetingToken = null;
        }
      }

      if (!roomUrl) {
        try {
          const studentName = sessionData.studentInfo?.name || studentData.display_name || "Student";
          const dailyRoom = await createDailyRoom({
            language: sessionData.language,
            studentId: sessionData.studentId,
            tutorId,
            studentName,
            tutorName: tutorData.display_name || "Tutor",
            expSeconds: 3600,
          });
          roomUrl = dailyRoom.url;
          roomName = dailyRoom.name;
          roomCreatedAt = Date.now();

          // Create tutor and student tokens in parallel
          const [tutorToken, studentToken] = await Promise.all([
            createMeetingToken({
              roomName,
              expSeconds: 3600,
              isOwner: false,
              userId: tutorId,
              userName: tutorData.display_name || "Tutor",
            }),
            createMeetingToken({
              roomName,
              expSeconds: 3600,
              isOwner: true,
              userId: sessionData.studentId,
              userName: studentName,
            }),
          ]);
          meetingToken = tutorToken;
          studentMeetingToken = studentToken;
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

      // === 6. ОБНОВЛЕНИЕ СЕССИИ В ТРАНЗАКЦИИ ===
      console.log("🔄 Updating session and user statuses in transaction...");
      const activeExpiresAt = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 60 * 60 * 1000),
      );
      const txnResult = await admin
        .firestore()
        .runTransaction(async (transaction) => {
          const freshSnap = await transaction.get(sessionRef);
          if (!freshSnap.exists) {
            throw new functions.https.HttpsError(
              "not-found",
              "Video session not found",
            );
          }
          const fresh = freshSnap.data();
          if (
            fresh.status !== "searching" ||
            fresh.currentTutorId !== tutorId
          ) {
            if (
              ["active", "connecting"].includes(fresh.status) &&
              fresh.tutorId === tutorId &&
              fresh.dailyRoomUrl
            ) {
              return { alreadyAccepted: true, session: fresh };
            }
            throw new functions.https.HttpsError(
              "invalid-argument",
              "Session is already active",
            );
          }

          // Обновляем сессию - добавляем данные для активной сессии
          const sessionUpdate = {
            // Обновляем основные поля
            tutorId: tutorId,
            status: "active",
            acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
            startedAt: admin.firestore.FieldValue.serverTimestamp(),

            // Добавляем данные Daily.co
            dailyRoomUrl: roomUrl,
            dailyRoomName: roomName,
            expiresAt: activeExpiresAt,
            acceptingTutorId: null,
            acceptingAt: null,

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
          };

          // Store student meeting token in session for faster student join
          if (studentMeetingToken) {
            sessionUpdate.studentMeetingToken = studentMeetingToken;
          }

          transaction.update(sessionRef, sessionUpdate);

          // Обновляем статус преподавателя
          transaction.update(
            admin.firestore().collection("users").doc(tutorId),
            {
              isInCall: true,
              currentSessionId: sessionId,
            },
          );

          console.log("✅ Transaction completed successfully");
          return { alreadyAccepted: false };
        });

      if (txnResult?.alreadyAccepted) {
        console.log(
          "ℹ️ Session already active for this tutor (txn), returning existing room",
        );
        const existing = txnResult.session || {};
        const existingRoomUrl = existing.dailyRoomUrl;
        const existingRoomName =
          existing.dailyRoomName || getRoomNameFromUrl(existingRoomUrl);
        let existingMeetingToken = null;
        if (existingRoomName) {
          try {
            existingMeetingToken = await createMeetingToken({
              roomName: existingRoomName,
              expSeconds: 3600,
              isOwner: false,
              userId: tutorId,
              userName: tutorData.display_name || "Tutor",
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
          roomUrl: existingRoomUrl,
          roomName: existingRoomName || null,
          meetingToken: existingMeetingToken || null,
          studentInfo: existing.studentInfo || null,
          sessionData: {
            language: existing.language,
            startedAt:
              existing.startedAt?.toMillis?.() || existing.startedAt || null,
            maxDuration: 3600000,
          },
        };
      }

      // 🔔 === ОТПРАВКА PUSH + ОБНОВЛЕНИЕ УВЕДОМЛЕНИЙ (ПАРАЛЛЕЛЬНО) ===
      console.log("📲 Sending push + updating notifications in parallel...");
      await Promise.all([
        sendVoipPushToStudent(sessionData.studentId, {
          sessionId: sessionId,
          callerName: tutorData.display_name || "Преподаватель",
          callerId: tutorId,
          callerPhoto: tutorData.photo_url || null,
          roomUrl: roomUrl,
          meetingToken: studentMeetingToken || "",
          roomName: roomName || "",
        }).catch((pushError) => {
          console.error(
            "⚠️ Failed to send VoIP push (non-critical):",
            pushError.message,
          );
        }),
        updateNotificationStatus(sessionId, tutorId, "accepted"),
        cancelOtherNotifications(sessionId, tutorId),
      ]);
      console.log("✅ Push + notifications completed");

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

      if (lockAcquired) {
        try {
          await admin.firestore().runTransaction(async (transaction) => {
            const snap = await transaction.get(sessionRef);
            if (!snap.exists) return;
            const data = snap.data();
            if (data.acceptingTutorId === tutorId) {
              transaction.update(sessionRef, {
                acceptingTutorId: null,
                acceptingAt: null,
              });
            }
          });
        } catch (lockError) {
          console.error("⚠️ Failed to release accept lock:", lockError.message);
        }
      }

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
        roomName: callData.roomName || "",
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
        roomName: callData.roomName || "",
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
