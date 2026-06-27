const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { sendApnsVoip } = require("./apns_voip");
const { getUserVoipTokens } = require("./voip_tokens");
const {
  CALL_EVENT_OUTCOME_MISSED,
  ensureConversationCallEventForSession,
} = require("./chats_shared");
const {
  assertNoActiveAcceptLockForResponderOrThrow,
  hasActiveAcceptLockForResponder,
} = require("./accept_lock_policy");
const {
  resolveDailyRoomName,
} = require("./daily_room");
const {
  deleteDailyRoomForSession,
} = require("./daily_room_cleanup");
const {
  isSupportedSessionRole,
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  buildTeacherIncomingCallApnsPayload,
  buildTeacherIncomingCallFcmMessage,
  createIncomingCallNotificationInTransaction,
} = require("./call_notifications");
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
  buildResponderFailurePoolFingerprint,
  collectAvailableRespondersAfterFailure,
  isDirectMatchSession,
  readAvailableRespondersAfterFailure,
  responderFailurePoolFingerprintMatches,
  resolveResponderFailureStopReason,
} = require("./responder_failure_policy");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const DECLINABLE_SESSION_STATUSES = new Set([
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
  return Boolean(assignedResponderId) &&
    assignedResponderId === normalizeSessionId(responderId);
}

function readRequesterIdForResponderFailure(sessionData = {}) {
  return sessionData.requesterId ||
    sessionData.studentId ||
    sessionData.matchContext?.requesterId ||
    "";
}

function buildDeclineResponderFailureRouting({
  sessionData = {},
  responderId = "",
  availableTutors = null,
}) {
  if (isDirectMatchSession(sessionData)) {
    return {
      availableTutors: [],
      requesterId: readRequesterIdForResponderFailure(sessionData),
      restoreSearchParticipantIds: [],
      restoreSearchExcludedCandidateIdsByParticipantId: {},
      terminalStopReason: "direct_call_declined",
    };
  }

  const requesterId = readRequesterIdForResponderFailure(sessionData);
  const restoreSearchParticipantIds = requesterId ? [requesterId] : [];
  return {
    availableTutors: Array.isArray(availableTutors) ?
      availableTutors :
      readAvailableRespondersAfterFailure({
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
      fallbackStopReason: "no_available_responder_after_decline",
      studentPairStopReason: "student_pair_declined",
    }),
  };
}

function buildDeclineNextResponderPairLockInput({
  db,
  transaction,
  sessionId = "",
  sessionData = {},
  responderId = "",
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
    currentResponderId: responderId,
    responderId: nextCandidate.candidateId,
    responderRole: nextCandidate.role,
    expectedLanguage: sessionData.language,
    triedTutors: nextCandidate.triedCandidateIds,
    serverTimestamp,
    lockExpiresAt,
    fieldDelete,
    currentResponderSearchRequestStatus: SEARCH_REQUEST_STATUS.CANCELLED,
    currentResponderStopReason: "declined",
    requesterExcludedCandidateIds: responderId ? [responderId] : [],
  };
}

async function collectFreshDeclineFailureResponderIds({
  db,
  sessionRef,
  responderId = "",
  nowMillis = Date.now(),
  failureResponderCollector = collectAvailableRespondersAfterFailure,
}) {
  if (!sessionRef || typeof sessionRef.get !== "function") {
    return null;
  }

  const preflightSessionDoc = await sessionRef.get();
  if (!preflightSessionDoc.exists) {
    return null;
  }

  const preflightSessionData = preflightSessionDoc.data() || {};
  if (
    !DECLINABLE_SESSION_STATUSES.has(preflightSessionData.status) ||
    !isPendingSessionAssignedToResponder(
      preflightSessionData,
      responderId,
    ) ||
    hasActiveAcceptLockForResponder({
      sessionData: preflightSessionData,
      responderId,
      nowMillis,
    })
  ) {
    return null;
  }

  const preflightRequesterId =
    readRequesterIdForResponderFailure(preflightSessionData);
  const freshFailureRouting =
    await failureResponderCollector({
      db,
      sessionData: preflightSessionData,
      responderId,
      requesterId: preflightRequesterId,
      now: new Date(nowMillis),
      nowMillis,
    });
  if (!Array.isArray(freshFailureRouting?.availableTutors)) {
    return null;
  }
  return {
    availableTutors: freshFailureRouting.availableTutors,
    fingerprint: freshFailureRouting.fingerprint ||
      buildResponderFailurePoolFingerprint({
        sessionData: preflightSessionData,
        responderId,
        requesterId: preflightRequesterId,
      }),
  };
}

/*
ОБНОВЛЕННАЯ ФУНКЦИЯ: declineCall
Теперь работает с sessionId и обновляет videoSessions
*/

exports.declineCall = functions
  .runWith({ secrets: [...apnsSecrets, ...dailySecrets] })
  .https.onCall(async (data, context) => {
    console.log("❌ Responder declining call...");

    try {
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated",
        );
      }

      const responderId = context.auth.uid;
      const { sessionId } = data;

      console.log("👤 Responder ID:", responderId);
      console.log("📺 Session ID:", sessionId);

      if (!sessionId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Session ID is required",
        );
      }

      // Получаем данные responder (для валидации роли)
      const tutorDoc = await admin
        .firestore()
        .collection("users")
        .doc(responderId)
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
      let freshFailureResponderRouting = null;
      try {
        freshFailureResponderRouting =
          await collectFreshDeclineFailureResponderIds({
            db,
            sessionRef,
            responderId,
            nowMillis: Date.now(),
          });
      } catch (error) {
        console.error(
          "⚠️ Failed to collect fresh responder pool after decline:",
          error.message,
        );
      }
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
        console.log(
          "👤 Current responder ID:",
          getPendingAssignedResponderId(sessionData),
        );

        // Проверяем, что сессия в статусе поиска
        if (!DECLINABLE_SESSION_STATUSES.has(sessionData.status)) {
          console.log(
            "❌ Session is not in a declinable status:",
            sessionData.status,
          );
          throw new functions.https.HttpsError(
            "invalid-argument",
            "Session is not available for declining",
          );
        }

        // Проверяем, что звонок адресован этому responder.
        if (!isPendingSessionAssignedToResponder(sessionData, responderId)) {
          console.log(
            "❌ Session is not for this responder. Expected:",
            getPendingAssignedResponderId(sessionData),
            "Got:",
            responderId,
          );
          throw new functions.https.HttpsError(
            "permission-denied",
            "This session is not assigned to you",
          );
        }
        assertNoActiveAcceptLockForResponderOrThrow({
          sessionData,
          responderId,
        });

        // Добавляем responder в список попыток
        const triedTutors = Array.from(new Set([
          ...(sessionData.triedTutors || []),
          responderId,
        ]));

        console.log("📝 Updating tried tutors list:", triedTutors);

        const failureRouting = buildDeclineResponderFailureRouting({
          sessionData,
          responderId,
          availableTutors: responderFailurePoolFingerprintMatches(
            freshFailureResponderRouting?.fingerprint,
            buildResponderFailurePoolFingerprint({sessionData, responderId}),
          ) ?
            freshFailureResponderRouting.availableTutors :
            null,
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
            language: sessionData.language,
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
              ...buildDeclineNextResponderPairLockInput({
                db,
                transaction,
                sessionId,
                sessionData,
                responderId,
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
        const sessionUpdate = {
          triedTutors: nextTriedTutors,
          currentTutorId: nextTutor || admin.firestore.FieldValue.delete(),
          currentResponderId: nextTutor || admin.firestore.FieldValue.delete(),
          currentResponderRole: admin.firestore.FieldValue.delete(),
          acceptingTutorId: admin.firestore.FieldValue.delete(),
          acceptingAt: admin.firestore.FieldValue.delete(),
          acceptAttemptId: admin.firestore.FieldValue.delete(),
        };
        if (!nextTutor) {
          sessionUpdate.status = VIDEO_SESSION_STATUS.CANCELLED;
          sessionUpdate.pairStatus = VIDEO_SESSION_STATUS.CANCELLED;
          sessionUpdate.endedAt =
            admin.firestore.FieldValue.serverTimestamp();
          sessionUpdate.cancelledAt =
            admin.firestore.FieldValue.serverTimestamp();
          sessionUpdate.cancelledBy = responderId;
          sessionUpdate.cancelReason = terminalStopReason;
        }

        const preparedSessionUpdate =
          preparedPairLock?.writes?.sessionUpdate || {};
        const notification = nextTutor
          ? createIncomingCallNotificationInTransaction({
            db,
            transaction,
            sessionId,
            recipientId: nextTutor,
            sessionData: {
              ...sessionData,
              ...preparedSessionUpdate,
              triedTutors: nextTriedTutors,
              currentTutorId: nextTutor,
              currentResponderId: nextTutor,
            },
            studentNameFallback: "Студент",
          })
          : null;

        if (preparedPairLock) {
          applyPreparedPairLockWrites(transaction, preparedPairLock);
        } else {
          await releaseSessionPairLocksInTransaction({
            db,
            transaction,
            sessionId,
            sessionData,
            serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
            fieldDelete: admin.firestore.FieldValue.delete(),
            searchRequestStatus: SEARCH_REQUEST_STATUS.CANCELLED,
            stopReason: terminalStopReason,
            restoreSearchParticipantIds:
              failureRouting.restoreSearchParticipantIds,
            restoreSearchExcludedCandidateIdsByParticipantId:
              failureRouting.restoreSearchExcludedCandidateIdsByParticipantId,
          });
          transaction.update(sessionRef, sessionUpdate);
        }

        return {
          dailyRoomName: nextTutor ? null : resolveDailyRoomName(sessionData),
          nextSessionData: {
            ...sessionData,
            triedTutors: nextTriedTutors,
            currentTutorId: nextTutor || null,
            currentResponderId: nextTutor || null,
            currentResponderRole:
              preparedSessionUpdate.currentResponderRole || null,
            status: nextTutor ?
              VIDEO_SESSION_STATUS.PENDING_CONFIRMATION :
              VIDEO_SESSION_STATUS.CANCELLED,
            pairStatus: nextTutor ?
              VIDEO_SESSION_STATUS.PENDING_CONFIRMATION :
              VIDEO_SESSION_STATUS.CANCELLED,
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
        .where("recipientId", "==", responderId)
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
            currentTutorId: responderId,
            currentResponderId: responderId,
          },
          callOutcome: CALL_EVENT_OUTCOME_MISSED,
          eventMillis: Date.now(),
          partnerId: responderId,
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
            notificationId: declineResult.notificationId,
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
      const apnsPayload = buildTeacherIncomingCallApnsPayload(callData);

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

    const message = buildTeacherIncomingCallFcmMessage({
      token: fcmToken,
      callData,
      bundleId,
    });

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
    const freshSessionData = sessionData || {};
    const nextTutor = getPendingAssignedResponderId(freshSessionData);
    if (!nextTutor) {
      console.log(
        "⏭️ Skipping next tutor notification for session",
        sessionId,
        "reason:",
        "no_assigned_tutor",
      );
      return;
    }

    const db = admin.firestore();
    const validationReads = [
      db.collection("videoSessions").doc(sessionId).get(),
    ];
    const notificationId = freshSessionData.notificationId || null;
    if (notificationId) {
      validationReads.push(
        db.collection("notifications").doc(notificationId).get(),
      );
    }

    const [sessionSnap, notificationSnap] = await Promise.all(validationReads);
    if (!sessionSnap.exists) {
      console.log(
        "⏭️ Skipping push because session disappeared after assignment",
      );
      return;
    }

    const validationSessionData = sessionSnap.data() || {};
    if (
      !DECLINABLE_SESSION_STATUSES.has(validationSessionData.status) ||
      getPendingAssignedResponderId(validationSessionData) !== nextTutor
    ) {
      console.log(
        "⏭️ Skipping push because tutor assignment changed after transaction",
      );
      return;
    }
    if (
      hasActiveAcceptLockForResponder({
        sessionData: validationSessionData,
        responderId: nextTutor,
      })
    ) {
      console.log(
        "⏭️ Skipping push because tutor is already accepting the session",
      );
      return;
    }

    if (notificationId) {
      const notificationData = notificationSnap?.data?.() || {};
      if (
        !notificationSnap.exists ||
        notificationData.status !== "sent" ||
        notificationData.sessionId !== sessionId ||
        notificationData.recipientId !== nextTutor
      ) {
        console.log(
          "⏭️ Skipping push because notification changed after assignment",
        );
        return;
      }
    }

    const studentInfo = freshSessionData.studentInfo || {};
    const pushPayload = freshSessionData.pushPayload || {
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
        ...pushPayload,
        sessionId: pushPayload.sessionId || sessionId,
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

exports.__private__ = {
  buildDeclineNextResponderPairLockInput,
  buildDeclineResponderFailureRouting,
  collectFreshDeclineFailureResponderIds,
  getPendingAssignedResponderId,
  isPendingSessionAssignedToResponder,
  readRequesterIdForResponderFailure,
};
