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
const {
  createIncomingCallNotificationInTransaction,
} = require("./call_notifications");
const {
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  findNextCallableCandidateInTransaction,
} = require("./call_candidate_tokens");
const {
  SEARCH_REQUEST_STATUS,
} = require("./search_requests");
const {
  applyPreparedPairLockWrites,
  prepareExistingSessionNextResponderPairLockInTransaction,
  releaseSessionPairLocksInTransaction,
} = require("./match_pair_lock");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const PENDING_RESPONSE_SESSION_STATUSES = new Set([
  VIDEO_SESSION_STATUS.SEARCHING,
  VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
]);

exports.processExpiredNotifications = functions
  .runWith({ secrets: [...apnsSecrets, ...dailySecrets] })
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

      for (const doc of expiredQuery.docs) {
        try {
          await processExpiredNotification(doc);
        } catch (error) {
          console.error(
            `❌ Error processing notification ${doc.id}:`,
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

// ОБРАБОТКА ИСТЕКШЕГО УВЕДОМЛЕНИЯ
async function processExpiredNotification(notificationDoc) {
  const notificationId = notificationDoc.id;
  const initialNotificationData = notificationDoc.data() || {};
  const sessionId = initialNotificationData.sessionId;
  try {
    console.log(`📺 Processing expired notification: ${notificationId}`);
    const db = admin.firestore();
    const sessionRef = sessionId
      ? db.collection("videoSessions").doc(sessionId)
      : null;

    const transition = await db.runTransaction(
      async (transaction) => {
        const freshNotificationSnap = await transaction.get(notificationDoc.ref);
        if (!freshNotificationSnap.exists) {
          return {
            shouldNotify: false,
            skipReason: "notification_not_found",
          };
        }

        const freshNotificationData = freshNotificationSnap.data() || {};
        if (
          freshNotificationData.type !== "incoming_call" ||
          freshNotificationData.status !== "sent"
        ) {
          return {
            shouldNotify: false,
            skipReason: `notification_status_${freshNotificationData.status || "unknown"}`,
          };
        }

        const expireNotificationUpdate = {
          status: "expired",
          expiredAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (!sessionRef) {
          transaction.update(notificationDoc.ref, expireNotificationUpdate);
          return {
            shouldNotify: false,
            skipReason: "missing_session_id",
          };
        }

        const freshSessionSnap = await transaction.get(sessionRef);
        if (!freshSessionSnap.exists) {
          transaction.update(notificationDoc.ref, expireNotificationUpdate);
          return {
            shouldNotify: false,
            skipReason: "session_not_found",
          };
        }

        const freshSessionData = freshSessionSnap.data() || {};
        const status = freshSessionData.status || "unknown";
        if (!PENDING_RESPONSE_SESSION_STATUSES.has(status)) {
          transaction.update(notificationDoc.ref, expireNotificationUpdate);
          return {
            shouldNotify: false,
            skipReason: `status_${status}`,
          };
        }

        const currentTutorId = freshSessionData.currentTutorId;
        const expiredTutorId = freshNotificationData.recipientId;
        if (
          currentTutorId &&
          expiredTutorId &&
          currentTutorId !== expiredTutorId
        ) {
          transaction.update(notificationDoc.ref, expireNotificationUpdate);
          return {
            shouldNotify: false,
            skipReason: `current_tutor_changed_${currentTutorId}`,
          };
        }

        const timedOutTutorId = currentTutorId || expiredTutorId;
        if (!timedOutTutorId) {
          transaction.update(notificationDoc.ref, expireNotificationUpdate);
          return {
            shouldNotify: false,
            skipReason: "missing_timed_out_tutor",
          };
        }
        const triedTutors = [...(freshSessionData.triedTutors || [])];
        if (!triedTutors.includes(timedOutTutorId)) {
          triedTutors.push(timedOutTutorId);
        }

        const availableTutors = freshSessionData.availableTutors || [];
        let nextTutor = null;
        let nextTriedTutors = triedTutors;
        let preparedPairLock = null;
        const skippedCandidateIds = [];
        const skippedLockCandidateIds = [];
        while (true) {
          const nextCandidate = await findNextCallableCandidateInTransaction({
            db,
            transaction,
            candidateIds: availableTutors,
            triedCandidateIds: nextTriedTutors,
            language: freshSessionData.language,
          });
          skippedCandidateIds.push(...nextCandidate.skippedCandidateIds);
          if (!nextCandidate.candidateId) {
            nextTriedTutors = nextCandidate.triedCandidateIds;
            break;
          }

          const lockExpiresAt = admin.firestore.Timestamp.fromMillis(
            Date.now() + 45 * 1000,
          );
          const candidatePairLock =
            await prepareExistingSessionNextResponderPairLockInTransaction({
              db,
              transaction,
              sessionId,
              sessionData: freshSessionData,
              currentResponderId: timedOutTutorId,
              responderId: nextCandidate.candidateId,
              responderRole: nextCandidate.role,
              expectedLanguage: freshSessionData.language,
              triedTutors: nextCandidate.triedCandidateIds,
              serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
              lockExpiresAt,
              fieldDelete: admin.firestore.FieldValue.delete(),
              currentResponderSearchRequestStatus:
                SEARCH_REQUEST_STATUS.EXPIRED,
              currentResponderStopReason: "response_timeout",
            });
          if (candidatePairLock.locked) {
            nextTutor = nextCandidate.candidateId;
            nextTriedTutors = nextCandidate.triedCandidateIds;
            preparedPairLock = candidatePairLock;
            break;
          }

          skippedLockCandidateIds.push({
            candidateId: nextCandidate.candidateId,
            reason: candidatePairLock.reason,
          });
          nextTriedTutors = Array.from(new Set([
            ...nextCandidate.triedCandidateIds,
            nextCandidate.candidateId,
          ]));
        }
        if (skippedCandidateIds.length > 0) {
          console.log("⏭️ Skipped non-callable candidates:", skippedCandidateIds);
        }
        if (skippedLockCandidateIds.length > 0) {
          console.log("⏭️ Skipped locked candidates:", skippedLockCandidateIds);
        }

        if (!nextTutor) {
          await releaseSessionPairLocksInTransaction({
            db,
            transaction,
            sessionId,
            sessionData: freshSessionData,
            serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
            fieldDelete: admin.firestore.FieldValue.delete(),
            searchRequestStatus: SEARCH_REQUEST_STATUS.EXPIRED,
            stopReason: "no_available_responder_after_timeout",
          });
          transaction.update(notificationDoc.ref, expireNotificationUpdate);
          transaction.update(sessionRef, {
            triedTutors: nextTriedTutors,
            currentTutorId: admin.firestore.FieldValue.delete(),
            status: VIDEO_SESSION_STATUS.EXPIRED,
            endedAt: admin.firestore.FieldValue.serverTimestamp(),
            expiredAt: admin.firestore.FieldValue.serverTimestamp(),
            expireReason: "response_timeout",
          });
          return {
            shouldNotify: false,
            shouldRecordMissed: true,
            skipReason: "no_available_tutors",
            timedOutTutorId,
            dailyRoomName: resolveDailyRoomName(freshSessionData),
            sessionData: {
              ...freshSessionData,
              triedTutors: nextTriedTutors,
              currentTutorId: null,
              status: VIDEO_SESSION_STATUS.EXPIRED,
            },
          };
        }

        transaction.update(notificationDoc.ref, expireNotificationUpdate);
        const nextSessionData = {
          ...freshSessionData,
          ...(preparedPairLock?.writes?.sessionUpdate || {}),
          triedTutors: nextTriedTutors,
          currentTutorId: nextTutor,
        };
        const notification = createIncomingCallNotificationInTransaction({
          db,
          transaction,
          sessionId,
          recipientId: nextTutor,
          sessionData: nextSessionData,
          studentNameFallback: "Student",
        });

        applyPreparedPairLockWrites(transaction, preparedPairLock);

        return {
          shouldNotify: true,
          shouldRecordMissed: true,
          timedOutTutorId,
          nextTutor,
          sessionData: nextSessionData,
          notificationId: notification.notificationId,
          pushPayload: notification.pushPayload,
        };
      },
    );

    if (!transition || (!transition.shouldNotify && !transition.shouldRecordMissed)) {
      console.log(
        "⏭️ Skipping expired notification processing for",
        notificationId,
        "reason:",
        transition?.skipReason || "unknown",
      );
      return;
    }

    if (transition.shouldRecordMissed) {
      console.log(
        `👨‍🏫 Current tutor ${transition.timedOutTutorId} did not respond - searching next`,
      );
      try {
        await ensureConversationCallEventForSession({
          db: admin.firestore(),
          sessionId,
          sessionRef,
          sessionData: {
            ...(transition.sessionData || {}),
            currentTutorId: transition.timedOutTutorId,
          },
          callOutcome: CALL_EVENT_OUTCOME_MISSED,
          eventMillis: Date.now(),
          partnerId: transition.timedOutTutorId,
        });
      } catch (error) {
        console.error("⚠️ Failed to create missed call event:", error);
      }
    }

    if (transition.dailyRoomName) {
      await deleteDailyRoomForSession({
        sessionId,
        roomName: transition.dailyRoomName,
        source: "processExpiredNotifications",
      });
    }

    if (transition.shouldNotify) {
      const pushPayload = transition.pushPayload || {};
      console.log("📨 Sending notification to next tutor:", transition.nextTutor);
      console.log(
        "✅ Firestore notification created for tutor:",
        transition.nextTutor,
      );

      const freshValidationSnap = await sessionRef.get();
      if (!freshValidationSnap.exists) {
        console.log(
          "⏭️ Skipping push because session disappeared after assignment",
        );
        return;
      }

      const freshValidationData = freshValidationSnap.data() || {};
      if (
        !PENDING_RESPONSE_SESSION_STATUSES.has(freshValidationData.status) ||
        freshValidationData.currentTutorId !== transition.nextTutor
      ) {
        console.log(
          "⏭️ Skipping push because tutor assignment changed after transaction",
        );
        return;
      }

      try {
        await sendVoipPushToTutor(transition.nextTutor, {
          sessionId,
          studentName: pushPayload.studentName || "Student",
          studentId: pushPayload.studentId || "",
          studentPhoto: pushPayload.studentPhoto,
          language: pushPayload.language || "",
        });
        console.log("✅ VoIP push sent to next tutor");
      } catch (pushError) {
        console.error(
          "⚠️ Failed to send VoIP push (non-critical):",
          pushError.message,
        );
      }
    }

    console.log(`✅ Notification ${notificationId} processed successfully`);
  } catch (error) {
    console.error(`❌ Error processing notification ${notificationId}:`, error);
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
