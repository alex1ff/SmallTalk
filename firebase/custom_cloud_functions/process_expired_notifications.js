const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.processExpiredNotifications = functions.pubsub
  .schedule('every 30 seconds')
  .onRun(async (context) => {
    console.log('⏰ Processing expired notifications (updated version)...');
    const now = admin.firestore.Timestamp.now();
    
    try {
      // Находим истекшие уведомления о звонках
      const expiredQuery = await admin.firestore()
        .collection('notifications')
        .where('type', '==', 'incoming_call')
        .where('status', '==', 'sent')
        .where('expiresAt', '<=', now)
        .get();

      if (expiredQuery.empty) {
        console.log('📭 No expired notifications found');
        return null;
      }

      console.log(`⏰ Found ${expiredQuery.size} expired notifications`);

      // Обрабатываем каждое истекшее уведомление
      const batch = admin.firestore().batch();
      const sessionsToProcess = new Set();

      expiredQuery.docs.forEach(doc => {
        const notificationData = doc.data();
        
        console.log(`📝 Marking notification ${doc.id} as expired for tutor: ${notificationData.recipientId}`);
        
        // Отмечаем уведомление как истекшее
        batch.update(doc.ref, { 
          status: 'expired',
          expiredAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Добавляем sessionId для дальнейшей обработки
        if (notificationData.sessionId) {
          sessionsToProcess.add(notificationData.sessionId);
        }
      });

      // Применяем изменения к уведомлениям
      await batch.commit();
      console.log('✅ All expired notifications marked');

      // Обрабатываем каждую уникальную сессию
      console.log(`🔄 Processing ${sessionsToProcess.size} video sessions...`);
      
      for (const sessionId of sessionsToProcess) {
        try {
          await processExpiredSession(sessionId);
        } catch (error) {
          console.error(`❌ Error processing session ${sessionId}:`, error.message);
        }
      }

      console.log('✅ Expired notifications processing completed');
      return null;

    } catch (error) {
      console.error('❌ Error processing expired notifications:', error);
      return null;
    }
  });

// ОБРАБОТКА ИСТЕКШЕЙ СЕССИИ
async function processExpiredSession(sessionId) {
  try {
    console.log(`📺 Processing expired session: ${sessionId}`);
    
    const sessionDoc = await admin.firestore()
      .collection('videoSessions')
      .doc(sessionId)
      .get();

    if (!sessionDoc.exists) {
      console.log(`❌ Video session ${sessionId} not found`);
      return;
    }

    const sessionData = sessionDoc.data();
    console.log(`📋 Session status: ${sessionData.status}`);

    // Обрабатываем только сессии в статусе поиска
    if (sessionData.status !== 'searching') {
      console.log(`⏭️ Skipping session ${sessionId} - status is not searching`);
      return;
    }

    const currentTutorId = sessionData.currentTutorId;
    if (!currentTutorId) {
      console.log(`⚠️ No current tutor for session ${sessionId}`);
      return;
    }

    console.log(`👨‍🏫 Current tutor ${currentTutorId} did not respond - adding to tried list`);

    // Добавляем преподавателя в список попыток
    const triedTutors = [...(sessionData.triedTutors || []), currentTutorId];
    
    // Обновляем сессию
    await admin.firestore()
      .collection('videoSessions')
      .doc(sessionId)
      .update({
        triedTutors: triedTutors,
        currentTutorId: null,
        sessionMetadata: {
          ...sessionData.sessionMetadata,
          lastTimeoutBy: currentTutorId,
          lastTimeoutAt: Date.now()
        }
      });

    console.log(`📨 Searching for next tutor for session ${sessionId}...`);
    
    // Отправляем уведомление следующему преподавателю
    await sendNotificationToNextTutor(sessionId, {
      ...sessionData,
      triedTutors: triedTutors
    });

    console.log(`✅ Session ${sessionId} processed successfully`);

  } catch (error) {
    console.error(`❌ Error processing session ${sessionId}:`, error);
    throw error;
  }
}

// 🔔 ОТПРАВКА VOIP PUSH ПРЕПОДАВАТЕЛЮ
async function sendVoipPushToTutor(tutorId, callData) {
  try {
    console.log('📲 Preparing VoIP push for tutor:', tutorId);

    const tutorDoc = await admin.firestore()
      .collection('users')
      .doc(tutorId)
      .get();

    if (!tutorDoc.exists) {
      console.log('⚠️ Tutor document not found:', tutorId);
      return;
    }

    const tutorData = tutorDoc.data();
    const voipToken = tutorData.voipToken;

    if (!voipToken) {
      console.log('⚠️ Tutor has no VoIP token saved');
      return;
    }

    console.log('📱 VoIP token found:', voipToken.substring(0, 20) + '...');

    const message = {
      token: voipToken,
      data: {
        type: 'incoming_call',
        sessionId: callData.sessionId,
        callerName: callData.studentName,
        callerId: callData.studentId,
        callerPhoto: callData.studentPhoto || '',
        language: callData.language || '',
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'voip',
        },
        payload: {
          aps: {
            'content-available': 1,
            alert: {
              title: 'Входящий звонок',
              body: `${callData.studentName} хочет попрактиковать ${callData.language}`,
            },
            sound: 'default',
          },
        },
      },
      android: {
        priority: 'high',
        notification: {
          title: 'Входящий звонок',
          body: `${callData.studentName} хочет попрактиковать ${callData.language}`,
          channelId: 'incoming_calls',
          priority: 'max',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log('✅ VoIP push sent successfully. Message ID:', response);

    return response;
  } catch (error) {
    console.error('❌ Error sending VoIP push to tutor:', error);
    return null;
  }
}

// ОТПРАВКА УВЕДОМЛЕНИЯ СЛЕДУЮЩЕМУ ПРЕПОДАВАТЕЛЮ
async function sendNotificationToNextTutor(sessionId, sessionData) {
  try {
    const availableTutors = sessionData.availableTutors || [];
    const triedTutors = sessionData.triedTutors || [];
    
    console.log('🎯 Available tutors:', availableTutors);
    console.log('❌ Tried tutors:', triedTutors);
    
    // Находим следующего преподавателя
    const nextTutor = availableTutors.find(tutorId => !triedTutors.includes(tutorId));
    
    if (!nextTutor) {
      console.log(`❌ No more tutors available for session ${sessionId}`);
      await admin.firestore().collection('videoSessions').doc(sessionId).update({
        status: 'no_tutors_available',
        sessionMetadata: {
          ...sessionData.sessionMetadata,
          noTutorsReason: 'All tutors tried without response',
          finalizedAt: Date.now()
        }
      });
      return;
    }

    console.log('📨 Sending notification to next tutor:', nextTutor);

    // Обновляем текущего преподавателя в сессии
    await admin.firestore().collection('videoSessions').doc(sessionId).update({
      currentTutorId: nextTutor
    });

    // Создаем уведомление в Firestore
    const expiresAt = new Date();
    expiresAt.setSeconds(expiresAt.getSeconds() + 45);

    const notificationData = {
      recipientId: nextTutor,
      sessionId: sessionId,
      type: 'incoming_call',
      status: 'sent',
      title: 'Входящий звонок',
      message: `${sessionData.studentInfo.name} хочет попрактиковать ${sessionData.language}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      studentInfo: sessionData.studentInfo
    };

    await admin.firestore().collection('notifications').add(notificationData);
    console.log('✅ Firestore notification created for tutor:', nextTutor);

    // 🔔 Отправляем VoIP push преподавателю
    console.log('📲 Sending VoIP push to next tutor...');
    try {
      await sendVoipPushToTutor(nextTutor, {
        sessionId: sessionId,
        studentName: sessionData.studentInfo.name,
        studentId: sessionData.studentId,
        studentPhoto: sessionData.studentInfo.photo,
        language: sessionData.language,
      });
      console.log('✅ VoIP push sent to next tutor');
    } catch (pushError) {
      console.error('⚠️ Failed to send VoIP push (non-critical):', pushError.message);
    }

  } catch (error) {
    console.error('❌ Error sending notification to next tutor:', error);
  }
}