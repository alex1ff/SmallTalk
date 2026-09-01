const crypto = require("node:crypto");
const admin = require("firebase-admin");
const {
  buildCallKitIdForMatchParticipant,
  createIncomingCallNotificationInTransaction,
} = require("./call_notifications");
const {
  MATCH_DECISION,
  MATCH_DELIVERY,
  MATCH_PROTOCOL_VERSION,
  MATCH_SURFACE,
  claimCallKitDispatch,
  finalizeCallKitDelivery,
  normalizeParticipantState,
} = require("./match_protocol_v2");
const {
  sendCallCancellationToResponder,
} = require("./stop_search").__private__;
const {
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_TIMING,
} = require("./search_requests");

const ROUTABLE_SESSION_STATUSES = new Set([
  VIDEO_SESSION_STATUS.SEARCHING,
  VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
]);
const CALLKIT_RESPONSE_WINDOW_MS = 45 * 1000;
const DEFINITIVE_FAILURE_RECOVERY_GRACE_MS = 1200;
const FOREGROUND_CLAIM_WINDOW_MS = 8000;
const FOREGROUND_CLAIM_POLL_MS = 400;
const CALLKIT_DISPATCH_LEASE_MS = 15 * 1000;
const IN_APP_FINALIZATION_FRESHNESS_MS = 40 * 1000;

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function readErrorMessage(error, fallback = "push_failed") {
  return normalizeString(error?.message) ||
    normalizeString(error?.reason) ||
    fallback;
}

function timestampToMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return Number(value.toMillis());
  if (typeof value.toDate === "function") return value.toDate().getTime();
  const millis = Number(value);
  return Number.isFinite(millis) ? millis : null;
}

function buildParticipantCallerInfo(sessionData = {}, participantId = "") {
  const otherParticipantId = (sessionData.participantIds || [])
    .map(normalizeString)
    .find((candidateId) => candidateId && candidateId !== participantId);
  const info = sessionData.participantInfos?.[otherParticipantId] || {};
  return {
    participantId: otherParticipantId || "",
    name:
      normalizeString(info.displayName) ||
      normalizeString(info.name) ||
      normalizeString(sessionData.studentInfo?.name) ||
      "Partner",
    photo:
      normalizeString(info.photoUrl) ||
      normalizeString(info.photo) ||
      normalizeString(sessionData.studentInfo?.photo),
  };
}

function buildProtocolV2CallData({sessionId = "", pushPayload = {}} = {}) {
  return {
    sessionId: normalizeString(sessionId),
    callerName: normalizeString(pushPayload.studentName) || "Partner",
    callerId: normalizeString(pushPayload.studentId) ||
      (normalizeString(pushPayload.recipientId) ===
        normalizeString(pushPayload.requesterId) ?
        normalizeString(pushPayload.responderId) :
        normalizeString(pushPayload.requesterId)),
    callerPhoto: normalizeString(pushPayload.studentPhoto),
    language: normalizeString(pushPayload.language),
    scenario: normalizeString(pushPayload.scenario),
    recipientId: normalizeString(pushPayload.recipientId),
    requesterId: normalizeString(pushPayload.requesterId),
    responderId: normalizeString(pushPayload.responderId),
    requesterRole: normalizeString(pushPayload.requesterRole),
    responderRole: normalizeString(pushPayload.responderRole),
    navRole: normalizeString(pushPayload.navRole) || "student",
    acceptMode: "respond_to_match",
    callKitId: normalizeString(pushPayload.callKitId),
    notificationId: normalizeString(pushPayload.notificationId),
    searchRequestId: normalizeString(pushPayload.searchRequestId),
    expiresAt: normalizeString(pushPayload.expiresAt),
    roomUrl: "",
    roomName: normalizeString(pushPayload.roomName),
    tokenStrategy: "accept_call",
    matchProtocolVersion: "2",
    pairAttemptId: normalizeString(pushPayload.pairAttemptId),
    surface: "callkit",
  };
}

function isDefinitiveDeliveryFailure(pushResult = {}) {
  const reason = normalizeString(pushResult.reason);
  if (
    ["missing_fcm_token", "ios_fcm_wake_not_native"].includes(reason) &&
    normalizeString(pushResult.apnsFailureKind) === "definitive"
  ) {
    return true;
  }
  return [
    "missing_responder",
    "responder_missing",
    "missing_tokens",
    "missing_voip_push_token",
    "invalid_voip_token",
    "invalid_fcm_token",
  ].includes(reason);
}

function classifyProtocolV2RouteResult(result = {}) {
  const participantState = result.participantState || {};
  if (
    normalizeString(result.reason) === "response_window_closed" ||
    normalizeString(result.pushResult?.reason) === "response_window_closed"
  ) {
    return "response_window_closed";
  }
  if (participantState.delivery === MATCH_DELIVERY.DISPATCHING) {
    return "in_progress";
  }
  if (
    result.shouldNotify === true &&
    result.pushResult?.sent !== true &&
    result.recoveredAfterDeliveryFailure !== true
  ) {
    if (
      participantState.delivery === MATCH_DELIVERY.FAILED &&
      participantState.deliveryFailureKind === "definitive"
    ) {
      return "definitive_failure";
    }
    if (
      participantState.delivery === MATCH_DELIVERY.FAILED &&
      participantState.deliveryFailureKind === "unknown"
    ) {
      return "ambiguous_delivery";
    }
    return "in_progress";
  }
  return "resolved";
}

function isFreshForegroundSearchRequest({
  requestData = {},
  nowMillis = Date.now(),
} = {}) {
  if (normalizeString(requestData.appState) !==
    SEARCH_REQUEST_APP_STATE.FOREGROUND) {
    return false;
  }
  const freshnessMillis = Math.max(
    timestampToMillis(requestData.appStateUpdatedAt) || 0,
    timestampToMillis(requestData.heartbeatAt) || 0,
  );
  return freshnessMillis > 0 &&
    nowMillis - freshnessMillis <=
      SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS * 1000;
}

function searchRequestMatchesProtocolV2Attempt({
  requestData = {},
  sessionId,
  pairAttemptId,
} = {}) {
  const boundSessionIds = [
    requestData.activeSessionId,
    requestData.currentSessionId,
    requestData.matchedSessionId,
  ].map(normalizeString).filter(Boolean);
  return normalizeString(requestData.pairAttemptId) === pairAttemptId &&
    boundSessionIds.includes(sessionId);
}

function findInAppParticipantsNeedingCallKitEscalation({
  sessionData = {},
  searchDataByParticipantId = {},
  freshParticipantIds = [],
  nowMillis = Date.now(),
  freshnessMillis = IN_APP_FINALIZATION_FRESHNESS_MS,
} = {}) {
  const freshIds = new Set(freshParticipantIds.map(normalizeString));
  const sessionId = normalizeString(sessionData.sessionId);
  const pairAttemptId = normalizeString(sessionData.pairAttemptId);
  return (sessionData.participantIds || []).map(normalizeString)
    .filter(Boolean)
    .filter((participantId) => {
      const state = normalizeParticipantState(
        sessionData.participantStates?.[participantId],
        sessionData.participantRoles?.[participantId],
      );
      if (
        state.role !== "student" ||
        state.surface !== MATCH_SURFACE.IN_APP ||
        state.decision !== MATCH_DECISION.ACCEPTED ||
        freshIds.has(participantId)
      ) {
        return false;
      }
      const requestData = searchDataByParticipantId[participantId] || {};
      if (!searchRequestMatchesProtocolV2Attempt({
        requestData,
        sessionId,
        pairAttemptId,
      })) {
        return true;
      }
      if (
        normalizeString(requestData.appState) ===
          SEARCH_REQUEST_APP_STATE.BACKGROUND
      ) {
        return true;
      }
      const lifecycleMillis = Math.max(
        timestampToMillis(requestData.appStateUpdatedAt) || 0,
        timestampToMillis(requestData.heartbeatAt) || 0,
      );
      return lifecycleMillis <= 0 ||
        nowMillis - lifecycleMillis > freshnessMillis;
    });
}

function buildCallKitLifecycleEscalation({
  sessionData = {},
  participantIds = [],
  updatedAt = null,
} = {}) {
  const escalatedIds = new Set(participantIds.map(normalizeString));
  const participantStates = {...(sessionData.participantStates || {})};
  escalatedIds.forEach((participantId) => {
    const current = normalizeParticipantState(
      participantStates[participantId],
      sessionData.participantRoles?.[participantId],
    );
    if (
      current.surface !== MATCH_SURFACE.IN_APP ||
      current.decision !== MATCH_DECISION.ACCEPTED
    ) {
      return;
    }
    participantStates[participantId] = {
      ...current,
      surface: MATCH_SURFACE.CALLKIT,
      decision: MATCH_DECISION.PENDING,
      delivery: MATCH_DELIVERY.PENDING,
      callKitId: current.callKitId || buildCallKitIdForMatchParticipant({
        sessionId: sessionData.sessionId,
        pairAttemptId: sessionData.pairAttemptId,
        participantId,
      }),
      actionId: null,
      dispatchId: null,
      dispatchExpiresAt: null,
      deliveryFailureKind: null,
      surfaceRevision: current.surfaceRevision + 1,
      updatedAt,
    };
  });
  return participantStates;
}

async function waitForForegroundMatchClaim({
  db,
  sessionId,
  pairAttemptId,
  participantId,
  clock = Date.now,
  sleep = (waitMillis) => new Promise((resolve) => {
    setTimeout(resolve, waitMillis);
  }),
  maxWaitMillis = FOREGROUND_CLAIM_WINDOW_MS,
  pollMillis = FOREGROUND_CLAIM_POLL_MS,
} = {}) {
  const startedAtMillis = clock();
  const requestSnap = await db.collection("searchRequests")
    .doc(participantId)
    .get();
  if (!requestSnap.exists || !isFreshForegroundSearchRequest({
    requestData: requestSnap.data() || {},
    nowMillis: startedAtMillis,
  })) {
    return {waited: false, reason: "participant_not_foreground"};
  }

  const deadlineMillis = startedAtMillis + maxWaitMillis;
  while (true) {
    const [sessionSnap, latestRequestSnap] = await Promise.all([
      db.collection("videoSessions").doc(sessionId).get(),
      db.collection("searchRequests").doc(participantId).get(),
    ]);
    const sessionData = sessionSnap.exists ? sessionSnap.data() || {} : {};
    const participantState = normalizeParticipantState(
      sessionData.participantStates?.[participantId],
      sessionData.participantRoles?.[participantId],
    );
    const currentAttempt = sessionSnap.exists &&
      Number(sessionData.matchProtocolVersion) === MATCH_PROTOCOL_VERSION &&
      normalizeString(sessionData.pairAttemptId) === pairAttemptId &&
      ROUTABLE_SESSION_STATUSES.has(sessionData.status);
    if (!currentAttempt) {
      return {waited: true, reason: "match_no_longer_pending"};
    }
    if (!latestRequestSnap.exists || !isFreshForegroundSearchRequest({
      requestData: latestRequestSnap.data() || {},
      nowMillis: clock(),
    })) {
      return {waited: true, reason: "participant_left_foreground"};
    }
    if (
      participantState.surface !== MATCH_SURFACE.PENDING ||
      participantState.decision !== MATCH_DECISION.PENDING
    ) {
      return {waited: true, reason: "participant_resolved"};
    }

    const nowMillis = clock();
    if (nowMillis >= deadlineMillis) {
      return {waited: true, reason: "foreground_claim_timeout"};
    }
    await sleep(Math.min(pollMillis, deadlineMillis - nowMillis));
  }
}

async function claimProtocolV2CallKitDispatch({
  db,
  sessionId,
  pairAttemptId,
  participantId,
  nowMillis = Date.now(),
  dispatchId = crypto.randomUUID(),
}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedPairAttemptId = normalizeString(pairAttemptId);
  const normalizedParticipantId = normalizeString(participantId);
  if (!normalizedSessionId || !normalizedPairAttemptId || !normalizedParticipantId) {
    return {shouldNotify: false, reason: "missing_ids"};
  }

  return db.runTransaction(async (transaction) => {
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const sessionSnap = await transaction.get(sessionRef);
    if (!sessionSnap.exists) {
      return {shouldNotify: false, reason: "session_missing"};
    }
    const sessionData = sessionSnap.data() || {};
    if (Number(sessionData.matchProtocolVersion) !== MATCH_PROTOCOL_VERSION) {
      return {shouldNotify: false, reason: "protocol_mismatch"};
    }
    if (normalizeString(sessionData.pairAttemptId) !== normalizedPairAttemptId) {
      return {shouldNotify: false, reason: "pair_attempt_mismatch"};
    }
    if (!ROUTABLE_SESSION_STATUSES.has(sessionData.status)) {
      return {shouldNotify: false, reason: "session_not_pending"};
    }
    if (!(sessionData.participantIds || []).includes(normalizedParticipantId)) {
      return {shouldNotify: false, reason: "participant_missing"};
    }

    const currentState = normalizeParticipantState(
      sessionData.participantStates?.[normalizedParticipantId],
      sessionData.participantRoles?.[normalizedParticipantId],
    );
    const responseExpiresAtMillis = timestampToMillis(
      sessionData.responseExpiresAt || sessionData.confirmationExpiresAt,
    );
    if (
      responseExpiresAtMillis !== null &&
      responseExpiresAtMillis <= nowMillis
    ) {
      return {
        shouldNotify: false,
        reason: "response_window_closed",
        participantState: currentState,
      };
    }
    const dispatchLeaseExpired =
      currentState.delivery === MATCH_DELIVERY.DISPATCHING &&
      (timestampToMillis(currentState.dispatchExpiresAt) || 0) <= nowMillis;
    const claimableState = dispatchLeaseExpired ? {
      ...currentState,
      delivery: MATCH_DELIVERY.FAILED,
      dispatchId: null,
      dispatchExpiresAt: null,
      deliveryFailureKind: "unknown",
    } : currentState;
    const callKitId = currentState.callKitId ||
      buildCallKitIdForMatchParticipant({
        sessionId: normalizedSessionId,
        pairAttemptId: normalizedPairAttemptId,
        participantId: normalizedParticipantId,
      });
    const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
    const currentResponseExpiresAtMillis = timestampToMillis(
      sessionData.responseExpiresAt || sessionData.confirmationExpiresAt,
    ) || 0;
    const responseExpiresAt = admin.firestore.Timestamp.fromMillis(Math.max(
      currentResponseExpiresAtMillis,
      nowMillis + CALLKIT_RESPONSE_WINDOW_MS,
    ));
    const transition = claimCallKitDispatch({
      state: claimableState,
      role: claimableState.role,
      dispatchId,
      callKitId,
      dispatchExpiresAt: admin.firestore.Timestamp.fromMillis(
        nowMillis + CALLKIT_DISPATCH_LEASE_MS,
      ),
      updatedAt: serverTimestamp,
    });
    if (!transition.changed) {
      return {
        shouldNotify: false,
        reason: transition.reason,
        participantState: transition.state,
      };
    }

    const participantStates = {
      ...sessionData.participantStates,
      [normalizedParticipantId]: transition.state,
    };
    const callerInfo = buildParticipantCallerInfo(
      sessionData,
      normalizedParticipantId,
    );
    const routedSessionData = {
      ...sessionData,
      participantStates,
      responseExpiresAt,
      confirmationExpiresAt: responseExpiresAt,
      studentId: callerInfo.participantId,
      studentInfo: callerInfo,
    };
    const notification = createIncomingCallNotificationInTransaction({
      db,
      transaction,
      sessionId: normalizedSessionId,
      recipientId: normalizedParticipantId,
      sessionData: routedSessionData,
      studentInfo: callerInfo,
      studentNameFallback: "Partner",
      status: "preparing",
      now: new Date(nowMillis),
    });
    transaction.update(sessionRef, {
      participantStates,
      responseExpiresAt,
      confirmationExpiresAt: responseExpiresAt,
      "matchLock.expiresAt": responseExpiresAt,
      updatedAt: serverTimestamp,
    });
    Object.entries(sessionData.participantRoles || {}).forEach(
      ([candidateId, role]) => {
        if (normalizeString(role) !== "student") return;
        transaction.update(
          db.collection("searchRequests").doc(candidateId),
          {lockExpiresAt: responseExpiresAt, updatedAt: serverTimestamp},
        );
      },
    );
    return {
      shouldNotify: true,
      reason: transition.reason,
      dispatchId,
      callKitId,
      notificationId: notification.notificationId,
      pushPayload: notification.pushPayload,
    };
  });
}

async function advanceProtocolV2MatchStage({
  db,
  sessionId,
  pairAttemptId,
  expectedStages = [],
  nextStage,
}) {
  const allowedStages = new Set(expectedStages.map(normalizeString));
  const normalizedNextStage = normalizeString(nextStage);
  if (!normalizedNextStage) {
    return {updated: false, reason: "missing_next_stage"};
  }
  return db.runTransaction(async (transaction) => {
    const sessionRef = db.collection("videoSessions").doc(sessionId);
    const sessionSnap = await transaction.get(sessionRef);
    if (!sessionSnap.exists) {
      return {updated: false, reason: "session_missing"};
    }
    const sessionData = sessionSnap.data() || {};
    if (
      Number(sessionData.matchProtocolVersion) !== MATCH_PROTOCOL_VERSION ||
      normalizeString(sessionData.pairAttemptId) !== pairAttemptId
    ) {
      return {updated: false, reason: "pair_attempt_mismatch"};
    }
    if (!ROUTABLE_SESSION_STATUSES.has(sessionData.status)) {
      return {updated: false, reason: "session_not_pending"};
    }
    const currentStage = normalizeString(sessionData.matchStage);
    if (currentStage === normalizedNextStage) {
      return {updated: false, reason: "already_advanced"};
    }
    if (allowedStages.size > 0 && !allowedStages.has(currentStage)) {
      return {updated: false, reason: "stage_mismatch"};
    }
    transaction.update(sessionRef, {
      matchStage: normalizedNextStage,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {updated: true, reason: "advanced", nextStage: normalizedNextStage};
  });
}

async function finalizeProtocolV2CallKitDispatch({
  db,
  sessionId,
  pairAttemptId,
  participantId,
  notificationId,
  dispatchId,
  pushResult = {},
}) {
  return db.runTransaction(async (transaction) => {
    const sessionRef = db.collection("videoSessions").doc(sessionId);
    const notificationRef = db.collection("notifications").doc(notificationId);
    const [sessionSnap, notificationSnap] = await Promise.all([
      transaction.get(sessionRef),
      transaction.get(notificationRef),
    ]);
    if (!sessionSnap.exists || !notificationSnap.exists) {
      return {updated: false, reason: "session_or_notification_missing"};
    }
    const sessionData = sessionSnap.data() || {};
    const notificationData = notificationSnap.data() || {};
    if (
      Number(sessionData.matchProtocolVersion) !== MATCH_PROTOCOL_VERSION ||
      normalizeString(sessionData.pairAttemptId) !== pairAttemptId ||
      normalizeString(notificationData.pairAttemptId) !== pairAttemptId ||
      normalizeString(notificationData.recipientId) !== participantId
    ) {
      return {
        updated: false,
        reason: "dispatch_stale",
        needsCancellation: pushResult?.sent === true,
      };
    }

    const sent = pushResult?.sent === true;
    const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
    const currentState = normalizeParticipantState(
      sessionData.participantStates?.[participantId],
    );
    const acceptedBeforeFinalization =
      notificationData.status === "accepted" &&
      currentState.decision === MATCH_DECISION.ACCEPTED;
    if (!ROUTABLE_SESSION_STATUSES.has(sessionData.status)) {
      if (
        acceptedBeforeFinalization &&
        [
          VIDEO_SESSION_STATUS.CONNECTING,
          VIDEO_SESSION_STATUS.ACTIVE,
        ].includes(sessionData.status)
      ) {
        const acceptedTransition = finalizeCallKitDelivery({
          state: currentState,
          dispatchId,
          sent: true,
          updatedAt: serverTimestamp,
        });
        if (acceptedTransition.changed) {
          transaction.update(sessionRef, {
            participantStates: {
              ...sessionData.participantStates,
              [participantId]: acceptedTransition.state,
            },
            updatedAt: serverTimestamp,
          });
        }
        return {
          updated: acceptedTransition.changed,
          reason: "accepted_before_finalization",
          participantState: acceptedTransition.state,
          needsCancellation: false,
        };
      }
      if (notificationData.status === "preparing") {
        transaction.update(notificationRef, {
          status: "cancelled",
          cancelledAt: serverTimestamp,
          cancelReason: "session_not_pending",
          updatedAt: serverTimestamp,
        });
      }
      return {
        updated: false,
        reason: "session_not_pending",
        needsCancellation: sent,
      };
    }
    if (
      notificationData.status !== "preparing" &&
      !acceptedBeforeFinalization
    ) {
      return {
        updated: false,
        reason: "notification_not_preparing",
        needsCancellation: sent,
      };
    }
    const transition = finalizeCallKitDelivery({
      state: currentState,
      dispatchId,
      sent: acceptedBeforeFinalization || sent,
      failureKind: isDefinitiveDeliveryFailure(pushResult) ?
        "definitive" :
        "unknown",
      updatedAt: serverTimestamp,
    });
    if (!transition.changed) {
      return {updated: false, reason: transition.reason};
    }
    const participantStates = {
      ...sessionData.participantStates,
      [participantId]: transition.state,
    };
    transaction.update(sessionRef, {participantStates, updatedAt: serverTimestamp});
    if (!acceptedBeforeFinalization) {
      transaction.update(notificationRef, sent ? {
        status: "sent",
        pushSentAt: serverTimestamp,
        pushChannel: normalizeString(pushResult.channel) || "unknown",
        updatedAt: serverTimestamp,
      } : {
        status: "failed",
        lastPushError: readErrorMessage(pushResult),
        lastPushFailedAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });
    }
    return {
      updated: true,
      reason: transition.reason,
      participantState: transition.state,
    };
  });
}

async function routeProtocolV2Participant({
  db,
  sessionId,
  pairAttemptId,
  participantId,
  pushSender,
  preDispatchWait = null,
  cancellationSender = sendCallCancellationToResponder,
  definitiveRecoveryWait = () => new Promise((resolve) => {
    setTimeout(resolve, DEFINITIVE_FAILURE_RECOVERY_GRACE_MS);
  }),
}) {
  if (typeof preDispatchWait === "function") {
    await preDispatchWait({
      db,
      sessionId,
      pairAttemptId,
      participantId,
    });
  }
  const claim = await claimProtocolV2CallKitDispatch({
    db,
    sessionId,
    pairAttemptId,
    participantId,
  });
  if (!claim.shouldNotify) return {...claim, participantId};

  const callData = buildProtocolV2CallData({
    sessionId,
    pushPayload: claim.pushPayload,
  });
  let pushResult;
  try {
    pushResult = await pushSender(participantId, callData);
  } catch (error) {
    pushResult = {
      sent: false,
      reason: "push_failed",
      error: readErrorMessage(error),
    };
  }
  if (!pushResult || pushResult.sent !== true) {
    pushResult = {
      ...(pushResult && typeof pushResult === "object" ? pushResult : {}),
      sent: false,
      reason: normalizeString(pushResult?.reason) || "push_failed",
      error: readErrorMessage(pushResult),
    };
  }
  const finalization = await finalizeProtocolV2CallKitDispatch({
    db,
    sessionId,
    pairAttemptId,
    participantId,
    notificationId: claim.notificationId,
    dispatchId: claim.dispatchId,
    pushResult,
  });
  if (finalization.needsCancellation === true && pushResult.sent === true) {
    await cancellationSender({
      db,
      sessionId,
      responderUserId: participantId,
      pairAttemptId,
      callKitId: claim.callKitId,
    }).catch(() => {});
  }
  let recoveredAfterDeliveryFailure =
    finalization.participantState?.decision === MATCH_DECISION.ACCEPTED;
  if (
    pushResult.sent !== true &&
    finalization.participantState &&
    !recoveredAfterDeliveryFailure
  ) {
    await definitiveRecoveryWait();
    const latestSession = await db.collection("videoSessions")
      .doc(sessionId)
      .get();
    const latestData = latestSession.exists ? latestSession.data() || {} : {};
    const latestState = normalizeParticipantState(
      latestData.participantStates?.[participantId],
    );
    const samePendingAttempt =
      normalizeString(latestData.pairAttemptId) === pairAttemptId &&
      ROUTABLE_SESSION_STATUSES.has(latestData.status);
    recoveredAfterDeliveryFailure = samePendingAttempt &&
      latestState.decision === MATCH_DECISION.ACCEPTED && (
        latestState.surface === MATCH_SURFACE.IN_APP ||
        (latestState.surface === MATCH_SURFACE.CALLKIT &&
          latestState.deliveryFailureKind === "unknown")
      );
  }
  return {
    ...claim,
    participantId,
    callData,
    pushResult,
    finalization,
    recoveredAfterDeliveryFailure,
    participantState: finalization.participantState || null,
  };
}

async function cancelProtocolV2NativeSurfaces({
  db,
  sessionId,
  pairAttemptId,
  participantStates = null,
  reason = "match_cancelled",
  cancellationSender = sendCallCancellationToResponder,
}) {
  let states = participantStates;
  if (!states) {
    const sessionSnap = await db.collection("videoSessions").doc(sessionId).get();
    const sessionData = sessionSnap.exists ? sessionSnap.data() || {} : {};
    if (normalizeString(sessionData.pairAttemptId) !== pairAttemptId) {
      return {cancelledSurfaces: 0, reason: "pair_attempt_mismatch"};
    }
    states = sessionData.participantStates || {};
  }
  const targets = Object.entries(states || {}).filter(([, rawState]) => {
    const state = normalizeParticipantState(rawState);
    return state.surface === MATCH_SURFACE.CALLKIT &&
      [
        MATCH_DELIVERY.DISPATCHING,
        MATCH_DELIVERY.SENT,
        MATCH_DELIVERY.FAILED,
      ].includes(state.delivery) && Boolean(state.callKitId);
  });
  const deliveries = await Promise.all(targets.map(([participantId, rawState]) => {
    const state = normalizeParticipantState(rawState);
    return cancellationSender({
      db,
      sessionId,
      responderUserId: participantId,
      pairAttemptId,
      callKitId: state.callKitId,
    }).catch(() => ({sent: false, reason: "delivery_failed"}));
  }));

  const notifications = await db.collection("notifications")
    .where("sessionId", "==", sessionId)
    .get();
  const active = notifications.docs.filter((doc) => {
    const data = doc.data() || {};
    return normalizeString(data.pairAttemptId) === pairAttemptId &&
      ["preparing", "sent", "failed", "accepted"].includes(data.status);
  });
  if (active.length > 0) {
    const batch = db.batch();
    const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
    active.forEach((doc) => batch.update(doc.ref, {
      status: "cancelled",
      cancelledAt: serverTimestamp,
      cancelReason: reason,
      updatedAt: serverTimestamp,
    }));
    await batch.commit();
  }
  return {
    cancelledSurfaces: targets.length,
    deliveredCancellations: deliveries.filter(
      (delivery) => delivery?.sent === true,
    ).length,
    deliveryFailures: deliveries.filter(
      (delivery) => delivery?.sent !== true,
    ).length,
    deliveries,
    reason,
  };
}

module.exports = {
  ROUTABLE_SESSION_STATUSES,
  CALLKIT_RESPONSE_WINDOW_MS,
  CALLKIT_DISPATCH_LEASE_MS,
  DEFINITIVE_FAILURE_RECOVERY_GRACE_MS,
  FOREGROUND_CLAIM_POLL_MS,
  FOREGROUND_CLAIM_WINDOW_MS,
  IN_APP_FINALIZATION_FRESHNESS_MS,
  advanceProtocolV2MatchStage,
  buildParticipantCallerInfo,
  buildCallKitLifecycleEscalation,
  buildProtocolV2CallData,
  cancelProtocolV2NativeSurfaces,
  claimProtocolV2CallKitDispatch,
  finalizeProtocolV2CallKitDispatch,
  findInAppParticipantsNeedingCallKitEscalation,
  classifyProtocolV2RouteResult,
  isDefinitiveDeliveryFailure,
  isFreshForegroundSearchRequest,
  routeProtocolV2Participant,
  searchRequestMatchesProtocolV2Attempt,
  waitForForegroundMatchClaim,
};
