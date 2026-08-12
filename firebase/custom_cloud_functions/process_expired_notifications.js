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
  buildTeacherIncomingCallApnsPayload,
  buildTeacherIncomingCallFcmMessage,
  cancelProtocolV2NotificationsInTransaction,
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
  buildResponderFailurePoolFingerprint,
  collectAvailableRespondersAfterFailure,
  isDirectMatchSession,
  readAvailableRespondersAfterFailure,
  responderFailurePoolFingerprintMatches,
  resolveResponderFailureStopReason,
} = require("./responder_failure_policy");
const {
  logCallLifecycleError,
  logCallLifecycleEvent,
} = require("./call_lifecycle_logs");
const {
  reconcileReleasedProtocolV2Match,
} = require("./start_search").__private__;

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
    pairStatus: VIDEO_SESSION_STATUS.EXPIRED,
  };
}

function readRequesterIdForResponderFailure(sessionData = {}) {
  return sessionData.requesterId ||
    sessionData.studentId ||
    sessionData.matchContext?.requesterId ||
    "";
}

function buildProtocolV2NotificationTimeoutRouting({
  sessionData = {},
  timedOutParticipantId = "",
} = {}) {
  const participantIds = Array.from(new Set(
    (sessionData.participantIds || [])
      .map(normalizeSessionId)
      .filter(Boolean),
  ));
  const restoreParticipantIds = participantIds.filter((participantId) =>
    participantId !== timedOutParticipantId &&
    sessionData.participantRoles?.[participantId] === "student" &&
    sessionData.participantStates?.[participantId]?.decision !== "declined",
  );
  return {
    participantIds,
    restoreParticipantIds,
    restoreExcludedCandidateIdsByParticipantId: Object.fromEntries(
      restoreParticipantIds.map((participantId) => [
        participantId,
        timedOutParticipantId ? [timedOutParticipantId] : [],
      ]),
    ),
  };
}

function buildProtocolV2NotificationTimeoutDecision({
  sessionData = {},
  notificationData = {},
} = {}) {
  const pairAttemptId = normalizeSessionId(sessionData.pairAttemptId);
  const notificationPairAttemptId = normalizeSessionId(
    notificationData.pairAttemptId,
  );
  const participantId = normalizeSessionId(notificationData.recipientId);
  if (
    Number(sessionData.matchProtocolVersion) < 2 ||
    Number(notificationData.matchProtocolVersion) < 2 ||
    !pairAttemptId ||
    pairAttemptId !== notificationPairAttemptId ||
    !(sessionData.participantIds || []).includes(participantId)
  ) {
    return {
      shouldProcess: false,
      reason: "protocol_v2_attempt_stale",
      pairAttemptId,
      participantId,
    };
  }
  const participantState = sessionData.participantStates?.[participantId] || {};
  if (participantState.decision !== "pending") {
    return {
      shouldProcess: false,
      reason: `participant_${participantState.decision || "unknown"}`,
      pairAttemptId,
      participantId,
    };
  }
  if (
    participantState.surface !== "callkit" ||
    !["dispatching", "sent", "failed"].includes(participantState.delivery)
  ) {
    return {
      shouldProcess: false,
      reason: "callkit_surface_not_active",
      pairAttemptId,
      participantId,
    };
  }
  return {
    shouldProcess: true,
    reason: "callkit_timeout",
    pairAttemptId,
    participantId,
  };
}

function buildTimeoutResponderFailureRouting({
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
      terminalStopReason: "direct_call_timeout",
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

function normalizePushResultString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function buildTimeoutPushLifecycleDecision({pushResult = {}} = {}) {
  if (pushResult.sent === true) {
    return {
      event: "timeout_push_sent",
      result: "sent",
      isError: false,
    };
  }

  const reason =
    normalizePushResultString(pushResult.reason) || "push_not_sent";
  const errorCode =
    normalizePushResultString(pushResult.errorCode) || reason;
  const errorMessage =
    normalizePushResultString(pushResult.errorMessage) || reason;
  const nonErrorSkipReasons = new Set([
    "tutor_not_found",
    "no_push_tokens",
    "no_fcm_token",
  ]);

  if (nonErrorSkipReasons.has(reason)) {
    return {
      event: "timeout_push_skipped",
      result: "skipped",
      skipReason: reason,
      isError: false,
    };
  }

  return {
    event: "timeout_push_failed",
    result: "error",
    reason: errorMessage,
    errorCode,
    isError: true,
  };
}

async function collectFreshTimeoutFailureResponderIds({
  db,
  sessionRef,
  notificationData = {},
  nowMillis = Date.now(),
  failureResponderCollector = collectAvailableRespondersAfterFailure,
}) {
  if (!sessionRef || typeof sessionRef.get !== "function") {
    return null;
  }

  const preflightSessionSnap = await sessionRef.get();
  if (!preflightSessionSnap.exists) {
    return null;
  }

  const preflightSessionData = preflightSessionSnap.data() || {};
  const preflightTimeout = resolveTimedOutResponderForNotification({
    sessionData: preflightSessionData,
    notificationData,
  });
  const preflightTimeoutDecision = buildTimeoutResponderDecision({
    sessionData: preflightSessionData,
    notificationData,
    nowMillis,
  });
  if (
    !preflightTimeout.ok ||
    !preflightTimeoutDecision.shouldProcess ||
    !PENDING_RESPONSE_SESSION_STATUSES.has(preflightSessionData.status)
  ) {
    return null;
  }

  const preflightRequesterId =
    readRequesterIdForResponderFailure(preflightSessionData);
  const freshFailureRouting =
    await failureResponderCollector({
      db,
      sessionData: preflightSessionData,
      responderId: preflightTimeout.timedOutResponderId,
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
        responderId: preflightTimeout.timedOutResponderId,
        requesterId: preflightRequesterId,
      }),
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
    logCallLifecycleEvent({
      event: "timeout_processing_started",
      source: "processExpiredNotifications",
      sessionId,
      notificationId,
      responderId: initialNotificationData.recipientId,
    });
    const db = admin.firestore();
    const sessionRef = sessionId
      ? db.collection("videoSessions").doc(sessionId)
      : null;
    let freshFailureResponderRouting = null;
    if (Number(initialNotificationData.matchProtocolVersion) < 2) {
      try {
        freshFailureResponderRouting =
          await collectFreshTimeoutFailureResponderIds({
            db,
            sessionRef,
            notificationData: initialNotificationData,
            nowMillis: Date.now(),
          });
      } catch (error) {
        console.error(
          "⚠️ Failed to collect fresh responder pool after timeout:",
          error.message,
        );
      }
    }

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

        const isProtocolV2 =
          Number(freshSessionData.matchProtocolVersion) >= 2 ||
          Number(freshNotificationData.matchProtocolVersion) >= 2;
        if (isProtocolV2) {
          const protocolV2TimeoutDecision =
            buildProtocolV2NotificationTimeoutDecision({
              sessionData: freshSessionData,
              notificationData: freshNotificationData,
            });
          if (!protocolV2TimeoutDecision.shouldProcess) {
            transaction.update(notificationDoc.ref, expireNotificationUpdate);
            return {
              shouldNotify: false,
              skipReason: protocolV2TimeoutDecision.reason,
            };
          }
          const pairAttemptId = protocolV2TimeoutDecision.pairAttemptId;
          const timedOutParticipantId =
            protocolV2TimeoutDecision.participantId;
          const routing = buildProtocolV2NotificationTimeoutRouting({
            sessionData: freshSessionData,
            timedOutParticipantId,
          });
          const serverTimestamp =
            admin.firestore.FieldValue.serverTimestamp();
          const fieldDelete = admin.firestore.FieldValue.delete();
          await releaseSessionPairLocksInTransaction({
            db,
            transaction,
            sessionId,
            sessionData: freshSessionData,
            participantIds: routing.participantIds,
            serverTimestamp,
            fieldDelete,
            searchRequestStatus: SEARCH_REQUEST_STATUS.EXPIRED,
            stopReason: "match_timeout",
            releaseCallState: true,
            restoreSearchParticipantIds: routing.restoreParticipantIds,
            restoreSearchExcludedCandidateIdsByParticipantId:
              routing.restoreExcludedCandidateIdsByParticipantId,
          });
          const participantStates = {
            ...(freshSessionData.participantStates || {}),
            [timedOutParticipantId]: {
              ...(freshSessionData.participantStates?.[
                timedOutParticipantId
              ] || {}),
              decision: "declined",
              actionId: `notification-timeout-${notificationId}`,
              updatedAt: serverTimestamp,
            },
          };
          cancelProtocolV2NotificationsInTransaction({
            db,
            transaction,
            sessionId,
            pairAttemptId,
            participantStates,
            cancelReason: "match_timeout",
            serverTimestamp,
          });
          transaction.update(notificationDoc.ref, expireNotificationUpdate);
          transaction.update(sessionRef, {
            status: VIDEO_SESSION_STATUS.EXPIRED,
            pairStatus: VIDEO_SESSION_STATUS.EXPIRED,
            participantStates,
            currentTutorId: fieldDelete,
            currentResponderId: fieldDelete,
            currentResponderRole: fieldDelete,
            acceptingTutorId: fieldDelete,
            acceptingAt: fieldDelete,
            acceptAttemptId: fieldDelete,
            endedAt: serverTimestamp,
            expiredAt: serverTimestamp,
            expireReason: "match_timeout",
            matchRecovery: {
              status: "pending",
              attempts: 0,
              pairAttemptId,
              reason: "match_timeout",
              restoreParticipantIds: routing.restoreParticipantIds,
              requestedAt: serverTimestamp,
            },
          });
          return {
            protocolV2: true,
            pairAttemptId,
            participantStates,
            restoreParticipantIds: routing.restoreParticipantIds,
            shouldNotify: false,
            shouldRecordMissed: true,
            timedOutResponderId: timedOutParticipantId,
            statusBefore: freshSessionData.status,
            statusAfter: VIDEO_SESSION_STATUS.EXPIRED,
            terminalStopReason: "match_timeout",
            sessionData: buildTerminalTimeoutSessionProjection({
              sessionData: freshSessionData,
            }),
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
          availableTutors: responderFailurePoolFingerprintMatches(
            freshFailureResponderRouting?.fingerprint,
            buildResponderFailurePoolFingerprint({
              sessionData: freshSessionData,
              responderId: timedOutResponderId,
            }),
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
            pairStatus: VIDEO_SESSION_STATUS.EXPIRED,
            endedAt: admin.firestore.FieldValue.serverTimestamp(),
            expiredAt: admin.firestore.FieldValue.serverTimestamp(),
            expireReason: terminalStopReason,
          });
          return {
            shouldNotify: false,
            shouldRecordMissed: true,
            skipReason: "no_available_tutors",
            timedOutResponderId,
            statusBefore: freshSessionData.status,
            statusAfter: VIDEO_SESSION_STATUS.EXPIRED,
            terminalStopReason,
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
          statusBefore: freshSessionData.status,
          statusAfter: VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
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
      logCallLifecycleEvent({
        event: "timeout_skipped",
        source: "processExpiredNotifications",
        sessionId,
        notificationId,
        responderId: initialNotificationData.recipientId,
        skipReason: transition?.skipReason || "unknown",
        result: "skipped",
      });
      return;
    }

    const logTimeoutCompleted = () => {
      logCallLifecycleEvent({
        event: "timeout_completed",
        source: "processExpiredNotifications",
        sessionId,
        notificationId,
        responderId: transition.timedOutResponderId,
        nextResponderId: transition.nextTutor,
        statusBefore: transition.statusBefore,
        statusAfter: transition.statusAfter,
        reason: transition.terminalStopReason,
        result: transition.shouldNotify ? "handoff" : "terminal",
      });
    };

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

    if (transition.protocolV2) {
      await reconcileReleasedProtocolV2Match({
        db,
        sessionId,
        pairAttemptId: transition.pairAttemptId,
      }).catch(() => {});
      logTimeoutCompleted();
      return;
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
        logCallLifecycleEvent({
          event: "timeout_push_skipped",
          source: "processExpiredNotifications",
          sessionId,
          notificationId: transition.notificationId,
          responderId: transition.nextTutor,
          skipReason: "session_missing_after_assignment",
          result: "skipped",
        });
        logTimeoutCompleted();
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
        logCallLifecycleEvent({
          event: "timeout_push_skipped",
          source: "processExpiredNotifications",
          sessionId,
          notificationId: transition.notificationId,
          responderId: transition.nextTutor,
          statusBefore: transition.statusAfter,
          statusAfter: freshValidationData.status,
          skipReason: "assignment_changed_after_transaction",
          result: "skipped",
        });
        logTimeoutCompleted();
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
        logCallLifecycleEvent({
          event: "timeout_push_skipped",
          source: "processExpiredNotifications",
          sessionId,
          notificationId: transition.notificationId,
          responderId: transition.nextTutor,
          skipReason: "accept_lock_active",
          result: "skipped",
        });
        logTimeoutCompleted();
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
          logCallLifecycleEvent({
            event: "timeout_push_skipped",
            source: "processExpiredNotifications",
            sessionId,
            notificationId: transition.notificationId,
            responderId: transition.nextTutor,
            skipReason: "notification_changed_after_assignment",
            result: "skipped",
          });
          logTimeoutCompleted();
          return;
        }
      }

      try {
        const pushResult = await sendVoipPushToTutor(transition.nextTutor, {
          ...pushPayload,
          sessionId: pushPayload.sessionId || sessionId,
          studentName: pushPayload.studentName || "Student",
          studentId: pushPayload.studentId || "",
          studentPhoto: pushPayload.studentPhoto,
          language: pushPayload.language || "",
        });
        const pushLogDecision = buildTimeoutPushLifecycleDecision({
          pushResult,
        });
        if (pushLogDecision.isError) {
          console.error(
            "⚠️ Failed to send VoIP push (non-critical):",
            pushLogDecision.reason,
          );
          logCallLifecycleError({
            event: pushLogDecision.event,
            source: "processExpiredNotifications",
            sessionId,
            notificationId: transition.notificationId,
            responderId: transition.nextTutor,
            errorCode: pushLogDecision.errorCode,
            reason: pushLogDecision.reason,
          });
        } else {
          if (pushLogDecision.result === "sent") {
            console.log("✅ VoIP push sent to next tutor");
          } else {
            console.log(
              "⏭️ VoIP push not sent:",
              pushLogDecision.skipReason || "unknown",
            );
          }
          logCallLifecycleEvent({
            event: pushLogDecision.event,
            source: "processExpiredNotifications",
            sessionId,
            notificationId: transition.notificationId,
            responderId: transition.nextTutor,
            skipReason: pushLogDecision.skipReason,
            result: pushLogDecision.result,
          });
        }
      } catch (pushError) {
        console.error(
          "⚠️ Failed to send VoIP push (non-critical):",
          pushError.message,
        );
        logCallLifecycleError({
          event: "timeout_push_failed",
          source: "processExpiredNotifications",
          sessionId,
          notificationId: transition.notificationId,
          responderId: transition.nextTutor,
          errorCode: pushError.code || pushError.name,
          reason: pushError.message,
        });
      }
    }

    logTimeoutCompleted();
    console.log(`✅ Notification ${notificationId} processed successfully`);
  } catch (error) {
    console.error(`❌ Error processing notification ${notificationId}:`, error);
    logCallLifecycleError({
      event: "timeout_failed",
      source: "processExpiredNotifications",
      sessionId,
      notificationId,
      responderId: initialNotificationData.recipientId,
      errorCode: error.code || error.name,
      reason: error.message,
    });
    throw error;
  }
}

exports.__private__ = {
  buildProtocolV2NotificationTimeoutDecision,
  buildProtocolV2NotificationTimeoutRouting,
  buildTerminalTimeoutSessionProjection,
  buildTimeoutNextResponderPairLockInput,
  buildTimeoutPushLifecycleDecision,
  buildTimeoutResponderDecision,
  buildTimeoutResponderFailureRouting,
  collectFreshTimeoutFailureResponderIds,
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
      return {
        sent: false,
        reason: "tutor_not_found",
      };
    }

    const tutorData = tutorDoc.data();
    const bundleId = process.env.IOS_BUNDLE_ID || "com.appwave.expatlio";
    const voipTopic =
      process.env.IOS_VOIP_TOPIC ||
      (bundleId.endsWith(".voip") ? bundleId : `${bundleId}.voip`);
    const { voipPushToken, voipToken: fcmToken } =
      await getUserVoipTokens(tutorId, tutorData);

    if (!voipPushToken && !fcmToken) {
      console.log("⚠️ Tutor has no push tokens saved");
      return {
        sent: false,
        reason: "no_push_tokens",
      };
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
        return {
          sent: true,
          channel: "apns",
        };
      } catch (error) {
        console.error("❌ Error sending APNs VoIP push:", error.message);
        if (!fcmToken) {
          return {
            sent: false,
            reason: "apns_failed_no_fcm",
            errorCode: error.code || error.name,
            errorMessage: error.message,
          };
        }
      }
    }

    if (!fcmToken) {
      console.log("⚠️ No FCM token available for fallback");
      return {
        sent: false,
        reason: "no_fcm_token",
      };
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

    return {
      sent: true,
      channel: "fcm",
      messageId: response,
    };
  } catch (error) {
    console.error("❌ Error sending VoIP push to tutor:", error);
    return {
      sent: false,
      reason: "push_send_failed",
      errorCode: error.code || error.name,
      errorMessage: error.message,
    };
  }
}
