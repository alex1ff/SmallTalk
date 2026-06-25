const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { sendApnsVoip } = require("./apns_voip");
const { getUserVoipTokens } = require("./voip_tokens");
const {
  CALL_EVENT_OUTCOME_MISSED,
  ensureConversationCallEventForSession,
} = require("./chats_shared");
const {
  hasActiveAcceptLockForResponder,
} = require("./accept_lock_policy");
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
const {
  readAvailableRespondersAfterFailure,
  resolveResponderFailureStopReason,
} = require("./responder_failure_policy");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const PENDING_RESPONSE_SESSION_STATUSES = new Set([
  VIDEO_SESSION_STATUS.SEARCHING,
  VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
]);

function normalizeSessionId(value) {
  return typeof value === "string" ? value.trim() : "";
}

function getPendingAssignedResponderId(sessionData = {}) {
  return normalizeSessionId(sessionData.currentResponderId) ||
    normalizeSessionId(sessionData.currentTutorId);
}

function isPendingSessionAssignedToResponder(sessionData = {}, responderId = "") {
  const assignedResponderId = getPendingAssignedResponderId(sessionData);
  const normalizedResponderId = normalizeSessionId(responderId);
  return Boolean(
    assignedResponderId &&
      normalizedResponderId &&
      assignedResponderId === normalizedResponderId,
  );
}

function resolveTimedOutResponderForNotification({
  sessionData = {},
  notificationData = {},
} = {}) {
  const currentResponderId = getPendingAssignedResponderId(sessionData);
  const expiredResponderId = normalizeSessionId(notificationData.recipientId);
  if (!currentResponderId) {
    return {
      ok: false,
      skipReason: "missing_current_responder",
      currentResponderId,
      expiredResponderId,
      timedOutResponderId: "",
    };
  }
  if (
    currentResponderId &&
    expiredResponderId &&
    currentResponderId !== expiredResponderId
  ) {
    return {
      ok: false,
      skipReason: `current_responder_changed_${currentResponderId}`,
      currentResponderId,
      expiredResponderId,
      timedOutResponderId: "",
    };
  }

  return {
    ok: true,
    skipReason: "",
    currentResponderId,
    expiredResponderId,
    timedOutResponderId: currentResponderId,
  };
}

function buildTimeoutResponderDecision({
  sessionData = {},
  notificationData = {},
  nowMillis = Date.now(),
} = {}) {
  const responderTimeout = resolveTimedOutResponderForNotification({
    sessionData,
    notificationData,
  });
  if (!responderTimeout.ok) {
    return {
      ...responderTimeout,
      shouldProcess: false,
      shouldExpireNotification: true,
    };
  }
  if (
    hasActiveAcceptLockForResponder({
      sessionData,
      responderId: responderTimeout.timedOutResponderId,
      nowMillis,
    })
  ) {
    return {
      ...responderTimeout,
      ok: false,
      skipReason: "accept_lock_active",
      shouldProcess: false,
      shouldExpireNotification: false,
    };
  }
  return {
    ...responderTimeout,
    shouldProcess: true,
    shouldExpireNotification: true,
  };
}

function buildTerminalTimeoutSessionProjection({
  sessionData = {},
  triedTutors = [],
} = {}) {
  return {
    ...sessionData,
    triedTutors,
    currentTutorId: null,
    currentResponderId: null,
    currentResponderRole: null,
    status: VIDEO_SESSION_STATUS.EXPIRED,
  };
}

function readRequesterIdForResponderFailure(sessionData = {}) {
  return sessionData.requesterId ||
    sessionData.studentId ||
    sessionData.matchContext?.requesterId ||
    "";
}

function buildTimeoutResponderFailureRouting({
  sessionData = {},
  responderId = "",
}) {
  const requesterId = readRequesterIdForResponderFailure(sessionData);
  const restoreSearchParticipantIds = requesterId ? [requesterId] : [];
  return {
    availableTutors: readAvailableRespondersAfterFailure({
      sessionData,
      responderId,
    }),
    requesterId,
    restoreSearchParticipantIds,
    restoreSearchExcludedCandidateIdsByParticipantId: requesterId ?
      {[requesterId]: [responderId]} :
      {},
    terminalStopReason: resolveResponderFailureStopReason({
      sessionData,
      responderId,
      fallbackStopReason: "no_available_responder_after_timeout",
      studentPairStopReason: "student_pair_response_timeout",
    }),
  };
}

function buildTimeoutNextResponderPairLockInput({
  db,
  transaction,
  sessionId = "",
  sessionData = {},
  timedOutResponderId = "",
  nextCandidate = {},
  serverTimestamp,
  lockExpiresAt,
  fieldDelete,
}) {
  return {
    db,
    transaction,
    sessionId,
    sessionData,
    currentResponderId: timedOutResponderId,
    responderId: nextCandidate.candidateId,
    responderRole: nextCandidate.role,
    expectedLanguage: sessionData.language,
    triedTutors: nextCandidate.triedCandidateIds,
    serverTimestamp,
    lockExpiresAt,
    fieldDelete,
    currentResponderSearchRequestStatus: SEARCH_REQUEST_STATUS.EXPIRED,
    currentResponderStopReason: "response_timeout",
    requesterExcludedCandidateIds: timedOutResponderId ?
      [timedOutResponderId] :
      [],
  };
}

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

        const timeoutDecision = buildTimeoutResponderDecision({
          sessionData: freshSessionData,
          notificationData: freshNotificationData,
        });
        if (!timeoutDecision.shouldProcess) {
          if (timeoutDecision.shouldExpireNotification) {
            transaction.update(notificationDoc.ref, expireNotificationUpdate);
          }
          return {
            shouldNotify: false,
            skipReason: timeoutDecision.skipReason,
          };
        }
        const timedOutResponderId = timeoutDecision.timedOutResponderId;
        const triedTutors = [...(freshSessionData.triedTutors || [])];
        if (!triedTutors.includes(timedOutResponderId)) {
          triedTutors.push(timedOutResponderId);
        }

        const failureRouting = buildTimeoutResponderFailureRouting({
          sessionData: freshSessionData,
          responderId: timedOutResponderId,
        });
        const availableTutors = failureRouting.availableTutors;
        const terminalStopReason = failureRouting.terminalStopReason;
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
              ...buildTimeoutNextResponderPairLockInput({
                db,
                transaction,
                sessionId,
                sessionData: freshSessionData,
                timedOutResponderId,
                nextCandidate,
                serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
                lockExpiresAt,
                fieldDelete: admin.firestore.FieldValue.delete(),
              }),
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
            stopReason: terminalStopReason,
            restoreSearchParticipantIds:
              failureRouting.restoreSearchParticipantIds,
            restoreSearchExcludedCandidateIdsByParticipantId:
              failureRouting.restoreSearchExcludedCandidateIdsByParticipantId,
          });
          transaction.update(notificationDoc.ref, expireNotificationUpdate);
          transaction.update(sessionRef, {
            triedTutors: nextTriedTutors,
            currentTutorId: admin.firestore.FieldValue.delete(),
            currentResponderId: admin.firestore.FieldValue.delete(),
            currentResponderRole: admin.firestore.FieldValue.delete(),
            acceptingTutorId: admin.firestore.FieldValue.delete(),
            acceptingAt: admin.firestore.FieldValue.delete(),
            acceptAttemptId: admin.firestore.FieldValue.delete(),
            status: VIDEO_SESSION_STATUS.EXPIRED,
            endedAt: admin.firestore.FieldValue.serverTimestamp(),
            expiredAt: admin.firestore.FieldValue.serverTimestamp(),
            expireReason: terminalStopReason,
          });
          return {
            shouldNotify: false,
            shouldRecordMissed: true,
            skipReason: "no_available_tutors",
            timedOutResponderId,
            dailyRoomName: resolveDailyRoomName(freshSessionData),
            sessionData: buildTerminalTimeoutSessionProjection({
              sessionData: freshSessionData,
              triedTutors: nextTriedTutors,
            }),
          };
        }

        transaction.update(notificationDoc.ref, expireNotificationUpdate);
        const nextSessionData = {
          ...freshSessionData,
          ...(preparedPairLock?.writes?.sessionUpdate || {}),
          triedTutors: nextTriedTutors,
          currentTutorId: nextTutor,
          currentResponderId: nextTutor,
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
          timedOutResponderId,
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
        `👤 Current responder ${transition.timedOutResponderId} did not respond - searching next`,
      );
      try {
        await ensureConversationCallEventForSession({
          db: admin.firestore(),
          sessionId,
          sessionRef,
          sessionData: {
            ...(transition.sessionData || {}),
            currentTutorId: transition.timedOutResponderId,
            currentResponderId: transition.timedOutResponderId,
          },
          callOutcome: CALL_EVENT_OUTCOME_MISSED,
          eventMillis: Date.now(),
          partnerId: transition.timedOutResponderId,
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

      const validationReads = [sessionRef.get()];
      if (transition.notificationId) {
        validationReads.push(
          db.collection("notifications").doc(transition.notificationId).get(),
        );
      }

      const [freshValidationSnap, notificationValidationSnap] =
        await Promise.all(validationReads);
      if (!freshValidationSnap.exists) {
        console.log(
          "⏭️ Skipping push because session disappeared after assignment",
        );
        return;
      }

      const freshValidationData = freshValidationSnap.data() || {};
      if (
        !PENDING_RESPONSE_SESSION_STATUSES.has(freshValidationData.status) ||
        !isPendingSessionAssignedToResponder(
          freshValidationData,
          transition.nextTutor,
        )
      ) {
        console.log(
          "⏭️ Skipping push because tutor assignment changed after transaction",
        );
        return;
      }
      if (
        hasActiveAcceptLockForResponder({
          sessionData: freshValidationData,
          responderId: transition.nextTutor,
        })
      ) {
        console.log(
          "⏭️ Skipping push because tutor is already accepting the session",
        );
        return;
      }
      if (transition.notificationId) {
        const notificationData = notificationValidationSnap?.data?.() || {};
        if (
          !notificationValidationSnap.exists ||
          notificationData.status !== "sent" ||
          notificationData.sessionId !== sessionId ||
          notificationData.recipientId !== transition.nextTutor
        ) {
          console.log(
            "⏭️ Skipping push because notification changed after assignment",
          );
          return;
        }
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

exports.__private__ = {
  buildTerminalTimeoutSessionProjection,
  buildTimeoutNextResponderPairLockInput,
  buildTimeoutResponderDecision,
  buildTimeoutResponderFailureRouting,
  getPendingAssignedResponderId,
  isPendingSessionAssignedToResponder,
  readRequesterIdForResponderFailure,
  resolveTimedOutResponderForNotification,
};

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
