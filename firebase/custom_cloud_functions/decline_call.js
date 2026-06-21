const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { sendApnsVoip } = require("./apns_voip");
const { getUserVoipTokens } = require("./voip_tokens");
const {
  CALL_EVENT_OUTCOME_MISSED,
  ensureConversationCallEventForSession,
} = require("./chats_shared");
const {
  resolveDailyRoomName,
} = require("./daily_room");
const {
  deleteDailyRoomForSession,
} = require("./daily_room_cleanup");
const { isSupportedSessionRole } = require("./video_sessions_shared");
const {
  createIncomingCallNotificationInTransaction,
} = require("./call_notifications");
const {
  findNextCallableCandidateInTransaction,
} = require("./call_candidate_tokens");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];

/*
ОБНОВЛЕННАЯ ФУНКЦИЯ: declineCall
Теперь работает с sessionId и обновляет videoSessions
*/

exports.declineCall = functions
  .runWith({ secrets: [...apnsSecrets, ...dailySecrets] })
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

      // Получаем данные преподавателя (для валидации роли)
      const tutorDoc = await admin
        .firestore()
        .collection("users")
        .doc(tutorId)
        .get();
      if (!tutorDoc.exists || !isSupportedSessionRole(tutorDoc.data().role)) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "This user role cannot decline calls",
        );
      }

      console.log("🔄 Processing session decline...");

      const db = admin.firestore();
      const sessionRef = db.collection("videoSessions").doc(sessionId);
      const declineResult = await db.runTransaction(async (transaction) => {
        const sessionDoc = await transaction.get(sessionRef);
        if (!sessionDoc.exists) {
          console.log("❌ Video session not found:", sessionId);
          throw new functions.https.HttpsError(
            "not-found",
            "Video session not found",
          );
        }

        const sessionData = sessionDoc.data() || {};
        console.log("📋 Session data status:", sessionData.status);
        console.log("👤 Current tutor ID:", sessionData.currentTutorId);

        // Проверяем, что сессия в статусе поиска
        if (sessionData.status !== "searching") {
          console.log(
            "❌ Session is not in searching status:",
            sessionData.status,
          );
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

        // Добавляем преподавателя в список попыток
        const triedTutors = Array.from(new Set([
          ...(sessionData.triedTutors || []),
          tutorId,
        ]));

        console.log("📝 Updating tried tutors list:", triedTutors);

        const availableTutors = sessionData.availableTutors || [];
        const nextCandidate = await findNextCallableCandidateInTransaction({
          db,
          transaction,
          candidateIds: availableTutors,
          triedCandidateIds: triedTutors,
        });
        const nextTutor = nextCandidate.candidateId;
        const nextTriedTutors = nextCandidate.triedCandidateIds;
        if (nextCandidate.skippedCandidateIds.length > 0) {
          console.log(
            "⏭️ Skipped non-callable candidates:",
            nextCandidate.skippedCandidateIds,
          );
        }
        const sessionUpdate = {
          triedTutors: nextTriedTutors,
          currentTutorId: nextTutor || admin.firestore.FieldValue.delete(),
        };
        if (!nextTutor) {
          sessionUpdate.status = "no_tutors_available";
        }

        const notification = nextTutor
          ? createIncomingCallNotificationInTransaction({
            db,
            transaction,
            sessionId,
            recipientId: nextTutor,
            sessionData: {
              ...sessionData,
              triedTutors: nextTriedTutors,
              currentTutorId: nextTutor,
            },
            studentNameFallback: "Студент",
          })
          : null;

        transaction.update(sessionRef, sessionUpdate);

        return {
          dailyRoomName: nextTutor ? null : resolveDailyRoomName(sessionData),
          nextSessionData: {
            ...sessionData,
            triedTutors: nextTriedTutors,
            currentTutorId: nextTutor || null,
            status: nextTutor ? sessionData.status : "no_tutors_available",
          },
          nextTutor: nextTutor || null,
          sessionData,
          triedTutors: nextTriedTutors,
          notificationId: notification?.notificationId || null,
          pushPayload: notification?.pushPayload || null,
        };
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

      try {
        await ensureConversationCallEventForSession({
          db,
          sessionId,
          sessionRef,
          sessionData: {
            ...declineResult.sessionData,
            triedTutors: declineResult.triedTutors,
            currentTutorId: tutorId,
          },
          callOutcome: CALL_EVENT_OUTCOME_MISSED,
          eventMillis: Date.now(),
          partnerId: tutorId,
        });
      } catch (error) {
        console.error("⚠️ Failed to create declined call event:", error);
      }

      if (declineResult.dailyRoomName) {
        await deleteDailyRoomForSession({
          db,
          sessionId,
          roomName: declineResult.dailyRoomName,
          source: "declineCall_no_tutors",
        });
      } else if (declineResult.nextTutor) {
        // Отправляем уведомление следующему преподавателю
        console.log("📨 Sending notification to next tutor...");
        await sendNotificationToNextTutor(
          sessionId,
          {
            ...declineResult.nextSessionData,
            pushPayload: declineResult.pushPayload,
          },
        );
      }

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
    const { voipPushToken, voipToken: fcmToken } =
      await getUserVoipTokens(tutorId, tutorData);

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

    console.log("📱 FCM token found");
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
    const nextTutor = sessionData.currentTutorId;
    if (!nextTutor) {
      console.log(
        "⏭️ Skipping next tutor notification for session",
        sessionId,
        "reason:",
        "no_assigned_tutor",
      );
      return;
    }

    const freshSessionData = sessionData || {};
    const studentInfo = freshSessionData.studentInfo || {};
    const pushPayload = sessionData.pushPayload || {
      sessionId,
      studentName: studentInfo.name || "Студент",
      studentId: freshSessionData.studentId,
      studentPhoto: studentInfo.photo,
      language: freshSessionData.language,
    };
    console.log("📨 Sending notification to tutor:", nextTutor);
    console.log("✅ Firestore notification created for tutor:", nextTutor);

    // 🔔 Отправляем VoIP push преподавателю
    console.log("📲 Sending VoIP push to next tutor...");
    try {
      await sendVoipPushToTutor(nextTutor, {
        sessionId,
        studentName: pushPayload.studentName || "Студент",
        studentId: pushPayload.studentId,
        studentPhoto: pushPayload.studentPhoto,
        language: pushPayload.language,
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
