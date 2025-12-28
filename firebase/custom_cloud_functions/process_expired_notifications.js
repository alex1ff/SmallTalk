const functions = require("firebase-functions");
const admin = require("firebase-admin");

exports.processExpiredNotifications = functions.pubsub
  .schedule("every 30 seconds")
  .onRun(async (context) => {
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
      const sessionsToProcess = new Set(); // Избегаем дублирования обработки

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
          // Продолжаем обработку других сессий даже если одна упала
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

    // Получаем данные сессии
    const sessionDoc = await admin
      .firestore()
      .collection("videoSessions")
      .doc(sessionId)
      .get();

    if (!sessionDoc.exists) {
      console.log(`❌ Video session ${sessionId} not found`);
      return;
    }

    const sessionData = sessionDoc.data();
    console.log(`📋 Session status: ${sessionData.status}`);

    // Обрабатываем только сессии в статусе поиска
    if (sessionData.status !== "searching") {
      console.log(`⏭️ Skipping session ${sessionId} - status is not searching`);
      return;
    }

    // Получаем текущего преподавателя (который не ответил)
    const currentTutorId = sessionData.currentTutorId;
    if (!currentTutorId) {
      console.log(`⚠️ No current tutor for session ${sessionId}`);
      return;
    }

    console.log(
      `👨‍🏫 Current tutor ${currentTutorId} did not respond - adding to tried list`,
    );

    // Добавляем преподавателя в список попыток
    const triedTutors = [...(sessionData.triedTutors || []), currentTutorId];

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
          lastTimeoutBy: currentTutorId,
          lastTimeoutAt: Date.now(),
        },
      });

    console.log(`📨 Searching for next tutor for session ${sessionId}...`);

    // Отправляем уведомление следующему преподавателю
    await sendNotificationToNextTutor(sessionId, {
      ...sessionData,
      triedTutors: triedTutors,
    });

    console.log(`✅ Session ${sessionId} processed successfully`);
  } catch (error) {
    console.error(`❌ Error processing session ${sessionId}:`, error);
    throw error; // Перебрасываем для логирования на верхнем уровне
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
      console.log(`❌ No more tutors available for session ${sessionId}`);
      // Обновляем статус сессии
      await admin
        .firestore()
        .collection("videoSessions")
        .doc(sessionId)
        .update({
          status: "no_tutors_available",
          sessionMetadata: {
            ...sessionData.sessionMetadata,
            noTutorsReason: "All tutors tried without response",
            finalizedAt: Date.now(),
          },
        });
      return;
    }

    console.log("📨 Sending notification to next tutor:", nextTutor);

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
    console.error("❌ Error sending notification to next tutor:", error);
  }
}
