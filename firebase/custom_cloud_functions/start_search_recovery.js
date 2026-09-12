const admin = require("firebase-admin");
const {
  cancelProtocolV2NotificationsInTransaction,
} = require("./call_notifications");
const {
  reconcileSessionTrialCallsInTransaction,
} = require("./trial_access");
const {
  releaseSessionPairLocksInTransaction,
} = require("./match_pair_lock");
const {
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_STATUS,
} = require("./search_requests");
const {
  MATCH_DECISION,
  MATCH_DELIVERY,
  MATCH_PROTOCOL_VERSION,
  normalizeParticipantState,
} = require("./match_protocol_v2");
const {
  buildStartSearchFailureUpdate,
  shouldFailUnboundStartSearchRequest,
  timestampToMillis,
} = require("./start_search_request_policy");
const {
  shouldCreateBackgroundStudentResponderIncomingCall,
  shouldCreateTeacherResponderIncomingCall,
  shouldLeaveBackgroundNotificationForAccept,
} = require("./start_search_responder_policy");

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

async function failUnboundStartSearchRequestForError({
  db,
  userId,
  requestId,
  error,
}) {
  const normalizedUserId = normalizeString(userId);
  const normalizedRequestId = normalizeString(requestId);
  if (!normalizedUserId || !normalizedRequestId) {
    return {failed: false, reason: "missing_ids"};
  }

  const searchRequestRef = db
    .collection(SEARCH_REQUEST_COLLECTION)
    .doc(normalizedUserId);
  const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
  const fieldDelete = admin.firestore.FieldValue.delete();

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(searchRequestRef);
    if (!snapshot.exists) {
      return {failed: false, reason: "not_found"};
    }
    const requestData = snapshot.data() || {};
    if (!shouldFailUnboundStartSearchRequest({
      requestData,
      userId: normalizedUserId,
      requestId: normalizedRequestId,
    })) {
      return {failed: false, reason: "not_active_unbound"};
    }

    transaction.update(searchRequestRef, buildStartSearchFailureUpdate({
      error,
      serverTimestamp,
      fieldDelete,
    }));
    return {failed: true, reason: "start_search_failed"};
  });
}

async function releaseTeacherResponderMatchForRetry({
  db,
  sessionId = "",
  responderId = "",
  requesterId = "",
  notificationId = "",
  pairAttemptId = "",
  stopReason = "teacher_notification_failed",
}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const normalizedRequesterId = normalizeString(requesterId);
  const normalizedNotificationId = normalizeString(notificationId);
  if (
    !normalizedSessionId ||
    !normalizedResponderId ||
    !normalizedRequesterId
  ) {
    return {released: false, reason: "missing_ids"};
  }
  const normalizedPairAttemptId = normalizeString(pairAttemptId);
  if (!normalizedPairAttemptId) {
    return {released: false, reason: "missing_pair_attempt"};
  }

  return db.runTransaction(async (transaction) => {
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const notificationRef = normalizedNotificationId ?
      db.collection("notifications").doc(normalizedNotificationId) :
      null;
    const [sessionSnap, notificationSnap] = await Promise.all([
      transaction.get(sessionRef),
      notificationRef ? transaction.get(notificationRef) : null,
    ]);
    if (!sessionSnap.exists) {
      return {released: false, reason: "session_missing"};
    }

    const sessionData = sessionSnap.data() || {};
    if (
      normalizeString(sessionData.pairAttemptId) !== normalizedPairAttemptId
    ) {
      return {released: false, reason: "pair_attempt_mismatch"};
    }
    if (
      normalizeString(sessionData.currentResponderRole) !== "native_speaker"
    ) {
      return {released: false, reason: "responder_role_mismatch"};
    }
    if (
      normalizeString(sessionData.currentResponderId) !==
        normalizedResponderId ||
      normalizeString(sessionData.currentTutorId) !== normalizedResponderId
    ) {
      return {released: false, reason: "responder_mismatch"};
    }
    const decision = shouldCreateTeacherResponderIncomingCall({
      sessionData,
      responderId: normalizedResponderId,
      nowMillis: Date.now(),
    });
    if (shouldLeaveBackgroundNotificationForAccept({decision, sessionData})) {
      return {
        released: false,
        reason: "accept_finalization_in_progress",
        staleReason: decision.reason,
      };
    }

    const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
    const fieldDelete = admin.firestore.FieldValue.delete();
    await reconcileSessionTrialCallsInTransaction({
      db,
      transaction,
      sessionId: normalizedSessionId,
      sessionData,
      durationSeconds: 0,
      technicalFailure: true,
      nowMillis: Date.now(),
    });
    await releaseSessionPairLocksInTransaction({
      db,
      transaction,
      sessionId: normalizedSessionId,
      sessionData,
      participantIds: [normalizedRequesterId, normalizedResponderId],
      serverTimestamp,
      fieldDelete,
      searchRequestStatus: SEARCH_REQUEST_STATUS.CANCELLED,
      stopReason: normalizeString(stopReason) || "teacher_notification_failed",
      restoreSearchParticipantIds: [normalizedRequesterId],
      restoreSearchExcludedCandidateIdsByParticipantId: {
        [normalizedRequesterId]: [normalizedResponderId],
      },
    });
    transaction.update(sessionRef, {
      status: VIDEO_SESSION_STATUS.CANCELLED,
      pairStatus: VIDEO_SESSION_STATUS.CANCELLED,
      cancelReason:
        normalizeString(stopReason) || "teacher_notification_failed",
      cancelledAt: serverTimestamp,
      currentResponderId: fieldDelete,
      currentResponderRole: fieldDelete,
      currentTutorId: fieldDelete,
      acceptingTutorId: fieldDelete,
      acceptingAt: fieldDelete,
      acceptAttemptId: fieldDelete,
      updatedAt: serverTimestamp,
    });

    if (notificationRef && notificationSnap?.exists) {
      const notificationData = notificationSnap.data() || {};
      if (
        notificationData.sessionId === normalizedSessionId &&
        notificationData.recipientId === normalizedResponderId &&
        notificationData.status === "sent"
      ) {
        transaction.update(notificationRef, {
          status: "cancelled",
          cancelledAt: serverTimestamp,
          cancelReason:
            normalizeString(stopReason) || "teacher_notification_failed",
          updatedAt: serverTimestamp,
        });
      }
    }

    return {
      released: true,
      reason: "released",
    };
  });
}

async function releaseBackgroundStudentResponderMatchForRetry({
  db,
  sessionId = "",
  responderId = "",
  requesterId = "",
  notificationId = "",
  pairAttemptId = "",
  stopReason = "background_student_notification_failed",
}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const normalizedRequesterId = normalizeString(requesterId);
  const normalizedNotificationId = normalizeString(notificationId);
  if (
    !normalizedSessionId ||
    !normalizedResponderId ||
    !normalizedRequesterId
  ) {
    return {released: false, reason: "missing_ids"};
  }
  const normalizedPairAttemptId = normalizeString(pairAttemptId);
  if (!normalizedPairAttemptId) {
    return {released: false, reason: "missing_pair_attempt"};
  }

  return db.runTransaction(async (transaction) => {
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const notificationRef = normalizedNotificationId ?
      db.collection("notifications").doc(normalizedNotificationId) :
      null;
    const [sessionSnap, notificationSnap] = await Promise.all([
      transaction.get(sessionRef),
      notificationRef ? transaction.get(notificationRef) : null,
    ]);
    if (!sessionSnap.exists) {
      return {released: false, reason: "session_missing"};
    }

    const sessionData = sessionSnap.data() || {};
    if (
      normalizeString(sessionData.pairAttemptId) !== normalizedPairAttemptId
    ) {
      return {released: false, reason: "pair_attempt_mismatch"};
    }
    if (normalizeString(sessionData.currentResponderRole) !== "student") {
      return {released: false, reason: "responder_role_mismatch"};
    }
    if (
      normalizeString(sessionData.currentResponderId) !==
        normalizedResponderId ||
      normalizeString(sessionData.currentTutorId) !== normalizedResponderId
    ) {
      return {released: false, reason: "responder_mismatch"};
    }
    const decision = shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData,
      sessionId: normalizedSessionId,
      responderId: normalizedResponderId,
      nowMillis: Date.now(),
    });
    if (shouldLeaveBackgroundNotificationForAccept({decision, sessionData})) {
      return {
        released: false,
        reason: "accept_finalization_in_progress",
        staleReason: decision.reason,
      };
    }

    const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
    const fieldDelete = admin.firestore.FieldValue.delete();
    await reconcileSessionTrialCallsInTransaction({
      db,
      transaction,
      sessionId: normalizedSessionId,
      sessionData,
      durationSeconds: 0,
      technicalFailure: true,
      nowMillis: Date.now(),
    });
    await releaseSessionPairLocksInTransaction({
      db,
      transaction,
      sessionId: normalizedSessionId,
      sessionData,
      participantIds: [normalizedRequesterId, normalizedResponderId],
      serverTimestamp,
      fieldDelete,
      searchRequestStatus: SEARCH_REQUEST_STATUS.CANCELLED,
      stopReason:
        normalizeString(stopReason) ||
        "background_student_notification_failed",
      restoreSearchParticipantIds: [normalizedRequesterId],
      restoreSearchExcludedCandidateIdsByParticipantId: {
        [normalizedRequesterId]: [normalizedResponderId],
      },
    });
    transaction.update(sessionRef, {
      status: VIDEO_SESSION_STATUS.CANCELLED,
      pairStatus: VIDEO_SESSION_STATUS.CANCELLED,
      cancelReason:
        normalizeString(stopReason) ||
        "background_student_notification_failed",
      cancelledAt: serverTimestamp,
      currentResponderId: fieldDelete,
      currentResponderRole: fieldDelete,
      currentTutorId: fieldDelete,
      acceptingTutorId: fieldDelete,
      acceptingAt: fieldDelete,
      acceptAttemptId: fieldDelete,
      updatedAt: serverTimestamp,
    });

    if (notificationRef && notificationSnap?.exists) {
      const notificationData = notificationSnap.data() || {};
      if (
        notificationData.sessionId === normalizedSessionId &&
        notificationData.recipientId === normalizedResponderId &&
        notificationData.status === "sent"
      ) {
        transaction.update(notificationRef, {
          status: "cancelled",
          cancelledAt: serverTimestamp,
          cancelReason:
            normalizeString(stopReason) ||
            "background_student_notification_failed",
          updatedAt: serverTimestamp,
        });
      }
    }

    return {
      released: true,
      reason: "released",
    };
  });
}

async function releaseProtocolV2MatchAfterRouteFailure({
  db,
  sessionId = "",
  pairAttemptId = "",
  failedParticipantId = "",
  expectedDispatchId = "",
  expectedDelivery = MATCH_DELIVERY.FAILED,
  expectedDeliveryFailureKind = "definitive",
  requireResponseWindowClosed = false,
  nowMillis = Date.now(),
  stopReason = "protocol_v2_push_failed",
}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedPairAttemptId = normalizeString(pairAttemptId);
  const normalizedFailedParticipantId = normalizeString(failedParticipantId);
  const normalizedExpectedDispatchId = normalizeString(expectedDispatchId);
  if (
    !normalizedSessionId ||
    !normalizedPairAttemptId ||
    !normalizedFailedParticipantId ||
    !normalizedExpectedDispatchId
  ) {
    return {released: false, reason: "missing_failure_identity"};
  }

  return db.runTransaction(async (transaction) => {
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const sessionSnap = await transaction.get(sessionRef);
    if (!sessionSnap.exists) {
      return {released: false, reason: "session_missing"};
    }
    const sessionData = sessionSnap.data() || {};
    if (
      Number(sessionData.matchProtocolVersion) !== MATCH_PROTOCOL_VERSION ||
      normalizeString(sessionData.pairAttemptId) !== normalizedPairAttemptId
    ) {
      return {released: false, reason: "pair_attempt_mismatch"};
    }
    if (![
      VIDEO_SESSION_STATUS.SEARCHING,
      VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
    ].includes(sessionData.status)) {
      return {released: false, reason: "session_not_pending"};
    }
    const participantIds = Array.from(new Set(
      (sessionData.participantIds || []).map(normalizeString).filter(Boolean),
    ));
    if (!participantIds.includes(normalizedFailedParticipantId)) {
      return {released: false, reason: "participant_missing"};
    }
    const failedState = normalizeParticipantState(
      sessionData.participantStates?.[normalizedFailedParticipantId],
      sessionData.participantRoles?.[normalizedFailedParticipantId],
    );
    if (failedState.decision === MATCH_DECISION.ACCEPTED) {
      return {released: false, reason: "delivery_recovered"};
    }
    if (
      failedState.dispatchId !== normalizedExpectedDispatchId ||
      failedState.delivery !== expectedDelivery
    ) {
      return {released: false, reason: "route_failure_superseded"};
    }
    if (requireResponseWindowClosed) {
      const responseDeadlineMillis = timestampToMillis(
        sessionData.responseExpiresAt || sessionData.confirmationExpiresAt,
      );
      if (
        responseDeadlineMillis === null ||
        responseDeadlineMillis > nowMillis
      ) {
        return {released: false, reason: "response_window_open"};
      }
    } else if (
      failedState.deliveryFailureKind !== expectedDeliveryFailureKind ||
      expectedDeliveryFailureKind !== "definitive"
    ) {
      return {released: false, reason: "delivery_failure_not_definitive"};
    }

    const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
    const fieldDelete = admin.firestore.FieldValue.delete();
    const participantStates = {
      ...sessionData.participantStates,
      [normalizedFailedParticipantId]: {
        ...failedState,
        decision: MATCH_DECISION.DECLINED,
        actionId: `delivery-failed-${normalizedPairAttemptId}`,
        updatedAt: serverTimestamp,
      },
    };
    const restoreParticipantIds = participantIds.filter((participantId) =>
      participantId !== normalizedFailedParticipantId &&
      sessionData.participantRoles?.[participantId] === "student" &&
      participantStates[participantId]?.decision !== MATCH_DECISION.DECLINED,
    );
    await reconcileSessionTrialCallsInTransaction({
      db,
      transaction,
      sessionId: normalizedSessionId,
      sessionData,
      durationSeconds: 0,
      technicalFailure: true,
      nowMillis,
    });
    await releaseSessionPairLocksInTransaction({
      db,
      transaction,
      sessionId: normalizedSessionId,
      sessionData: {...sessionData, participantStates},
      participantIds,
      serverTimestamp,
      fieldDelete,
      searchRequestStatus: SEARCH_REQUEST_STATUS.CANCELLED,
      stopReason: normalizeString(stopReason) || "protocol_v2_push_failed",
      releaseCallState: true,
      restoreSearchParticipantIds: restoreParticipantIds,
      restoreSearchExcludedCandidateIdsByParticipantId: Object.fromEntries(
        restoreParticipantIds.map((participantId) => [
          participantId,
          [normalizedFailedParticipantId],
        ]),
      ),
    });
    cancelProtocolV2NotificationsInTransaction({
      db,
      transaction,
      sessionId: normalizedSessionId,
      pairAttemptId: normalizedPairAttemptId,
      participantStates,
      cancelReason: normalizeString(stopReason) || "protocol_v2_push_failed",
      serverTimestamp,
    });
    transaction.update(sessionRef, {
      status: VIDEO_SESSION_STATUS.CANCELLED,
      pairStatus: VIDEO_SESSION_STATUS.CANCELLED,
      participantStates,
      cancelReason: normalizeString(stopReason) || "protocol_v2_push_failed",
      cancelledBy: normalizedFailedParticipantId,
      cancelledAt: serverTimestamp,
      matchRecovery: {
        status: "pending",
        attempts: 0,
        pairAttemptId: normalizedPairAttemptId,
        reason: normalizeString(stopReason) || "protocol_v2_push_failed",
        restoreParticipantIds,
        requestedAt: serverTimestamp,
      },
      currentResponderId: fieldDelete,
      currentResponderRole: fieldDelete,
      currentTutorId: fieldDelete,
      acceptingTutorId: fieldDelete,
      acceptingAt: fieldDelete,
      acceptAttemptId: fieldDelete,
      updatedAt: serverTimestamp,
    });
    return {
      released: true,
      reason: "released",
      participantStates,
      restoreParticipantIds,
      failedParticipantId: normalizedFailedParticipantId,
    };
  });
}

async function completeProtocolV2MatchRecovery({
  db,
  sessionId,
  pairAttemptId,
}) {
  return db.runTransaction(async (transaction) => {
    const sessionRef = db.collection("videoSessions").doc(sessionId);
    const sessionSnap = await transaction.get(sessionRef);
    if (!sessionSnap.exists) {
      return {completed: false, reason: "session_missing"};
    }
    const sessionData = sessionSnap.data() || {};
    if (
      normalizeString(sessionData.pairAttemptId) !== pairAttemptId ||
      normalizeString(sessionData.matchRecovery?.pairAttemptId) !==
        pairAttemptId ||
      normalizeString(sessionData.matchRecovery?.status) !== "pending"
    ) {
      return {completed: false, reason: "recovery_not_pending"};
    }
    const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
    transaction.update(sessionRef, {
      matchRecovery: {
        ...(sessionData.matchRecovery || {}),
        status: "completed",
        completedAt: serverTimestamp,
      },
      updatedAt: serverTimestamp,
    });
    return {completed: true, reason: "completed"};
  });
}

module.exports = {
  failUnboundStartSearchRequestForError,
  releaseTeacherResponderMatchForRetry,
  releaseBackgroundStudentResponderMatchForRetry,
  releaseProtocolV2MatchAfterRouteFailure,
  completeProtocolV2MatchRecovery,
};
