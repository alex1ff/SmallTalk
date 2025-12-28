const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

exports.acceptCall = functions.https.onCall(async (data, context) => {
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
    const { sessionId } = data; // Изменено с callRequestId на sessionId

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
    if (sessionData.expiresAt && sessionData.expiresAt.toDate() < new Date()) {
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
    console.log("👨‍🏫 Tutor data:", {
      display_name: tutorData.display_name,
      role: tutorData.role,
      isAvailable: tutorData.isAvailable,
      isInCall: tutorData.isInCall,
    });

    if (tutorData.role !== "tutor") {
      console.log("❌ User is not a tutor, role:", tutorData.role);
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only tutors can accept calls",
      );
    }

    if (!tutorData.isAvailable) {
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

    // === 5. СОЗДАНИЕ КОМНАТЫ DAILY.CO ===
    console.log("🏠 Creating Daily.co room...");
    let dailyRoom;
    try {
      dailyRoom = await createDailyRoom(
        sessionData.language,
        sessionData.studentId,
        tutorId,
        sessionData.studentInfo?.name || studentData.display_name || "Student",
        tutorData.display_name || "Tutor",
      );
      console.log("✅ Daily room created successfully:", {
        name: dailyRoom.name,
        url: dailyRoom.url,
        hasToken: !!dailyRoom.token,
      });
    } catch (roomError) {
      console.error("❌ Failed to create Daily room:", roomError);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to create video room",
      );
    }

    // === 6. ОБНОВЛЕНИЕ СЕССИИ В ТРАНЗАКЦИИ ===
    console.log("🔄 Updating session and user statuses in transaction...");
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
          dailyRoomUrl: dailyRoom.url,
          dailyRoomName: dailyRoom.name,
          meetingToken: dailyRoom.token,

          // Добавляем информацию о преподавателе
          tutorInfo: {
            name: tutorData.display_name || "Tutor",
            photo: tutorData.photo_url || null,
          },

          // Очищаем поля поиска (уже не нужны)
          currentTutorId: null,

          // Обновляем метаданные
          sessionMetadata: {
            acceptedBy: tutorId,
            acceptedAt: Date.now(),
            roomProvider: "daily",
            roomCreatedAt: dailyRoom.created_at,
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
      roomUrl: dailyRoom.url,
      roomName: dailyRoom.name,
      meetingToken: dailyRoom.token,
      studentInfo: {
        name:
          sessionData.studentInfo?.name ||
          studentData.display_name ||
          "Student",
        photo: sessionData.studentInfo?.photo || studentData.photo_url || null,
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
// (createDailyRoom, createMeetingToken, updateNotificationStatus, cancelOtherNotifications, logAnalyticsEvent)
// Остаются теми же, что в предыдущей версии

// СОЗДАНИЕ КОМНАТЫ DAILY
async function createDailyRoom(
  language,
  studentId,
  tutorId,
  studentName,
  tutorName,
) {
  try {
    const apiKey = process.env.DAILY_API_KEY;
    const domain = process.env.DAILY_DOMAIN;

    if (!apiKey) {
      throw new Error("DAILY_API_KEY environment variable not set");
    }

    if (!domain) {
      throw new Error("DAILY_DOMAIN environment variable not set");
    }

    const timestamp = Date.now();
    const randomStr = Math.random().toString(36).substr(2, 9);
    const roomName = `session_${timestamp}_${randomStr}`;

    console.log("🏠 Creating Daily room with ADAPTIVE BITRATE:", {
      name: roomName,
      language: language,
      participants: [studentName, tutorName],
      adaptive_bitrate: "ENABLED (up to 2 Mbps @ 720p)",
      expected_quality: "720p @ 30 fps",
    });

    const roomConfig = {
      name: roomName,
      privacy: "private",
      properties: {
        max_participants: 2,
        enable_chat: false, // 🔴 Отключаем чат для производительности
        enable_screenshare: true,
        enable_recording: false,
        start_audio_off: false,
        start_video_off: false,
        exp: Math.floor(Date.now() / 1000) + 3600,
        enable_knocking: false,
        enable_prejoin_ui: false,
        enable_people_ui: false, // 🔴 Отключаем UI участников
        enable_pip_ui: false, // 🔴 Отключаем PiP для производительности
        enable_network_ui: false,
        enable_noise_cancellation_ui: true, // Оставляем для качества аудио
        lang: language,
        enable_dialin: false,
        enable_dialout: false,
        enable_terse_logging: false,
        signaling_impl: "ws",
        geo: "auto",

        // 🎬 Согласно документации, эти параметры влияют на качество:
        sfu_switchover: 0.5, // Переключение на SFU при 2 участниках

        // 🔥🔥🔥 Daily Adaptive Bitrate - КЛЮЧ К КАЧЕСТВУ!
        // По умолчанию: enable_adaptive_simulcast = true
        // Можно НЕ указывать, но явно включаем для ясности:
        enable_adaptive_simulcast: true, // ✅ Авто-адаптация до 2 Mbps @ 720p

        // Для звонков с 3+ участниками (по умолчанию false):
        enable_multiparty_adaptive_simulcast: false, // Оставляем false для 2 участников

        // ⚠️ Adaptive Bitrate работает только для камеры, не для демонстрации экрана
      },
    };

    console.log("🌐 Making request to Daily API...");
    const response = await axios.post(
      "https://api.daily.co/v1/rooms",
      roomConfig,
      {
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
          "User-Agent": "SmallTalk-App/1.0",
        },
        timeout: 10000,
      },
    );

    const room = response.data;
    console.log("✅ Daily room created successfully:", {
      name: room.name,
      url: room.url,
      privacy: room.privacy,
      created_at: room.created_at,
      config: room.config,
    });

    console.log("🎫 Creating meeting token...");
    const meetingToken = await createMeetingToken(
      room.name,
      studentId,
      tutorId,
    );

    return {
      name: room.name,
      url: room.url,
      token: meetingToken,
      config: room.config,
      created_at: room.created_at,
    };
  } catch (error) {
    console.error(
      "❌ Error creating Daily room:",
      error.response?.data || error.message,
    );

    if (error.response?.status === 401) {
      throw new Error("Invalid Daily API key");
    } else if (error.response?.status === 403) {
      throw new Error("Daily API access forbidden - check your plan limits");
    } else if (error.response?.status === 429) {
      throw new Error("Daily API rate limit exceeded");
    } else if (error.code === "ENOTFOUND" || error.code === "ECONNREFUSED") {
      throw new Error("Cannot connect to Daily API - network error");
    } else if (error.code === "ECONNABORTED") {
      throw new Error("Daily API request timeout");
    }

    throw new Error(
      `Failed to create Daily room: ${error.response?.data?.error || error.message}`,
    );
  }
}

// СОЗДАНИЕ ТОКЕНА ВСТРЕЧИ С ОПТИМИЗАЦИЕЙ КАЧЕСТВА
async function createMeetingToken(roomName, studentId, tutorId) {
  try {
    const apiKey = process.env.DAILY_API_KEY;

    const tokenConfig = {
      properties: {
        room_name: roomName,
        is_owner: false,
        exp: Math.floor(Date.now() / 1000) + 3600,
        enable_screenshare: true,
        enable_recording: false,
      },
    };

    const response = await axios.post(
      "https://api.daily.co/v1/meeting-tokens",
      tokenConfig,
      {
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        timeout: 5000,
      },
    );

    console.log("✅ Meeting token created successfully");
    return response.data.token;
  } catch (error) {
    console.error(
      "⚠️ Error creating meeting token (non-critical):",
      error.response?.data || error.message,
    );
    return null;
  }
}

// ОБНОВЛЕНИЕ СТАТУСА УВЕДОМЛЕНИЯ
async function updateNotificationStatus(sessionId, tutorId, status) {
  try {
    console.log(`🔔 Updating notification status to ${status}...`);

    const notificationsQuery = await admin
      .firestore()
      .collection("notifications")
      .where("sessionId", "==", sessionId) // Изменено с callRequestId на sessionId
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
      .where("sessionId", "==", sessionId) // Изменено с callRequestId на sessionId
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
