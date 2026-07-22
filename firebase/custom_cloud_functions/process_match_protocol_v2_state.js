const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  acceptCallCallable,
} = require("./accept_call").__private__;
const {
  MATCH_DECISION,
  MATCH_DELIVERY,
  MATCH_PROTOCOL_VERSION,
  MATCH_STAGE,
  allParticipantsAccepted,
  allParticipantsReadyForFinalization,
  normalizeParticipantState,
} = require("./match_protocol_v2");
const {
  advanceProtocolV2MatchStage,
  cancelProtocolV2NativeSurfaces,
  classifyProtocolV2RouteResult,
  routeProtocolV2Participant,
} = require("./match_delivery_v2");
const {
  releaseProtocolV2MatchAfterRouteFailure,
  reconcileReleasedProtocolV2Match,
  resumeRestoredStudentSearch,
  routeProtocolV2InitialMatch,
  runBackgroundStudentResponderPushSender,
  sendVoipPushToStudentResponder,
  waitForForegroundStudentResponderResolution,
} = require("./start_search").__private__;
const {
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const FIRESTORE_TRIGGER_REGION = "europe-west1";
const RECOVERABLE_STAGES = Object.freeze([
  MATCH_STAGE.AWAITING_INITIAL_DISPATCH,
  MATCH_STAGE.AWAITING_STUDENT_DISPATCH,
  MATCH_STAGE.AWAITING_ACCEPTANCE,
  MATCH_STAGE.FINALIZATION_REQUESTED,
]);
const PENDING_STATUSES = new Set([
  VIDEO_SESSION_STATUS.SEARCHING,
  VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
]);

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function readAssignedResponderId(sessionData = {}) {
  return normalizeString(sessionData.currentResponderId) ||
    normalizeString(sessionData.currentTutorId) ||
    normalizeString(sessionData.responderId) ||
    normalizeString(sessionData.tutorId);
}

function readPendingStudentId(sessionData = {}) {
  return (sessionData.participantIds || [])
    .map(normalizeString)
    .find((participantId) => {
      const state = normalizeParticipantState(
        sessionData.participantStates?.[participantId],
        sessionData.participantRoles?.[participantId],
      );
      return state.role === "student" &&
        state.decision === MATCH_DECISION.PENDING;
    }) || "";
}

async function finishRouteFailure({
  db,
  sessionId,
  pairAttemptId,
  failedParticipantId,
  routeResult = {},
  participantPushSender,
  studentPreDispatchWait,
  releaseMatch = releaseProtocolV2MatchAfterRouteFailure,
  cancelSurfaces = cancelProtocolV2NativeSurfaces,
  resumeSearch = resumeRestoredStudentSearch,
  reconcileRecovery = reconcileProtocolV2TerminalSideEffects,
}) {
  const failureState = routeResult.participantState || {};
  const routeOutcome = classifyProtocolV2RouteResult(routeResult);
  const releaseResult = await releaseMatch({
    db,
    sessionId,
    pairAttemptId,
    failedParticipantId,
    expectedDispatchId: failureState.dispatchId,
    expectedDelivery: failureState.delivery,
    expectedDeliveryFailureKind: failureState.deliveryFailureKind,
    requireResponseWindowClosed: routeOutcome === "response_window_closed",
    stopReason: routeOutcome === "response_window_closed" ?
      "protocol_v2_response_timeout" :
      "protocol_v2_recovery_delivery_failed",
  });
  if (!releaseResult.released) return releaseResult;

  await reconcileRecovery({
    db,
    sessionId,
    sessionData: {
      matchProtocolVersion: MATCH_PROTOCOL_VERSION,
      pairAttemptId,
      participantStates: releaseResult.participantStates,
      matchRecovery: {
        status: "pending",
        pairAttemptId,
        reason: "protocol_v2_recovery_delivery_failed",
        restoreParticipantIds: releaseResult.restoreParticipantIds || [],
      },
    },
    participantPushSender,
    studentPreDispatchWait,
    cancelSurfaces,
    resumeSearch,
  });
  return releaseResult;
}

async function reconcileProtocolV2TerminalSideEffects({
  db,
  sessionId,
  sessionData = {},
  participantPushSender = sendVoipPushToStudentResponder,
  studentPreDispatchWait = waitForForegroundStudentResponderResolution,
  cancelSurfaces = cancelProtocolV2NativeSurfaces,
  resumeSearch = resumeRestoredStudentSearch,
}) {
  const pairAttemptId = normalizeString(sessionData.pairAttemptId);
  return reconcileReleasedProtocolV2Match({
    db,
    sessionId,
    pairAttemptId,
    options: {
      participantPushSender,
      studentPreDispatchWait,
    },
    cancelSurfaces,
    resumeSearch,
  });
}

async function processProtocolV2SessionState({
  db = admin.firestore(),
  sessionId,
  sessionData = {},
  participantPushSender = sendVoipPushToStudentResponder,
  studentPreDispatchWait = waitForForegroundStudentResponderResolution,
  initialRouter = routeProtocolV2InitialMatch,
  participantRouter = routeProtocolV2Participant,
  stageAdvancer = advanceProtocolV2MatchStage,
  finalizer = acceptCallCallable,
  releaseMatch = releaseProtocolV2MatchAfterRouteFailure,
  cancelSurfaces = cancelProtocolV2NativeSurfaces,
  resumeSearch = resumeRestoredStudentSearch,
  terminalReconciler = reconcileProtocolV2TerminalSideEffects,
} = {}) {
  const pairAttemptId = normalizeString(sessionData.pairAttemptId);
  const matchStage = normalizeString(sessionData.matchStage);
  if (
    Number(sessionData.matchProtocolVersion) === MATCH_PROTOCOL_VERSION &&
    ["pending", "processing"].includes(
      normalizeString(sessionData.matchRecovery?.status),
    ) &&
    normalizeString(sessionData.matchRecovery?.pairAttemptId) === pairAttemptId
  ) {
    return terminalReconciler({
      db,
      sessionId,
      sessionData,
      participantPushSender,
      studentPreDispatchWait,
      cancelSurfaces,
      resumeSearch,
    });
  }
  if (
    Number(sessionData.matchProtocolVersion) !== MATCH_PROTOCOL_VERSION ||
    !pairAttemptId ||
    !PENDING_STATUSES.has(sessionData.status) ||
    !RECOVERABLE_STAGES.includes(matchStage)
  ) {
    return {processed: false, reason: "state_not_recoverable"};
  }

  if (matchStage === MATCH_STAGE.AWAITING_INITIAL_DISPATCH) {
    const routeResult = await initialRouter({
      db,
      lockResult: {
        sessionId,
        pairAttemptId,
        responderId: readAssignedResponderId(sessionData),
      },
      requesterId: normalizeString(sessionData.requesterId) ||
        normalizeString(sessionData.studentId),
      responderRole: normalizeString(sessionData.currentResponderRole) ||
        normalizeString(sessionData.responderRole),
      studentPushSender: participantPushSender,
      teacherPushSender: participantPushSender,
      studentPreDispatchWait: sessionData.lifecycleEscalation ?
        null :
        studentPreDispatchWait,
    });
    if (routeResult.failedResult) {
      const releaseResult = await finishRouteFailure({
        db,
        sessionId,
        pairAttemptId,
        failedParticipantId:
          normalizeString(routeResult.failedResult.participantId) ||
          readAssignedResponderId(sessionData),
        routeResult: routeResult.failedResult,
        participantPushSender,
        studentPreDispatchWait,
        releaseMatch,
        cancelSurfaces,
        resumeSearch,
        reconcileRecovery: terminalReconciler,
      });
      if (!releaseResult.released) {
        return {processed: false, reason: releaseResult.reason};
      }
      return {processed: true, reason: "initial_delivery_failed"};
    }
    if (routeResult.retryPending) {
      return {processed: false, reason: "initial_dispatch_in_progress"};
    }
    return {processed: true, reason: "initial_dispatch_reconciled"};
  }

  if (matchStage === MATCH_STAGE.AWAITING_STUDENT_DISPATCH) {
    const studentId = readPendingStudentId(sessionData);
    if (!studentId) {
      return {processed: false, reason: "pending_student_missing"};
    }
    let routeResult;
    try {
      routeResult = await participantRouter({
        db,
        sessionId,
        pairAttemptId,
        participantId: studentId,
        preDispatchWait: studentPreDispatchWait,
        pushSender: (participantId, callData) =>
          runBackgroundStudentResponderPushSender({
            pushSender: participantPushSender,
            responderId: participantId,
            callData,
          }),
      });
    } catch (error) {
      routeResult = {
        shouldNotify: true,
        participantId: studentId,
        pushResult: {sent: false, reason: "route_failed"},
      };
    }
    const routeOutcome = classifyProtocolV2RouteResult(routeResult);
    if ([
      "definitive_failure",
      "response_window_closed",
    ].includes(routeOutcome)) {
      const releaseResult = await finishRouteFailure({
        db,
        sessionId,
        pairAttemptId,
        failedParticipantId: studentId,
        routeResult,
        participantPushSender,
        studentPreDispatchWait,
        releaseMatch,
        cancelSurfaces,
        resumeSearch,
        reconcileRecovery: terminalReconciler,
      });
      if (!releaseResult.released) {
        return {processed: false, reason: releaseResult.reason};
      }
      return {processed: true, reason: "student_delivery_failed"};
    }
    if (routeOutcome === "in_progress") {
      return {processed: false, reason: "student_dispatch_in_progress"};
    }
    await stageAdvancer({
      db,
      sessionId,
      pairAttemptId,
      expectedStages: [MATCH_STAGE.AWAITING_STUDENT_DISPATCH],
      nextStage: MATCH_STAGE.AWAITING_ACCEPTANCE,
    });
    return {processed: true, reason: "student_dispatch_reconciled"};
  }

  if (matchStage === MATCH_STAGE.AWAITING_ACCEPTANCE) {
    if (!allParticipantsReadyForFinalization(
      sessionData.participantStates || {},
      sessionData.participantIds || [],
    )) {
      return {processed: false, reason: "acceptance_not_ready"};
    }
    await stageAdvancer({
      db,
      sessionId,
      pairAttemptId,
      expectedStages: [MATCH_STAGE.AWAITING_ACCEPTANCE],
      nextStage: MATCH_STAGE.FINALIZATION_REQUESTED,
    });
    return {processed: true, reason: "finalization_queued"};
  }

  if (!allParticipantsAccepted(
    sessionData.participantStates || {},
    sessionData.participantIds || [],
  )) {
    return {processed: false, reason: "finalization_not_ready"};
  }
  const freshSessionSnap = await db.collection("videoSessions")
    .doc(sessionId)
    .get();
  if (!freshSessionSnap.exists) {
    return {processed: false, reason: "session_missing"};
  }
  const freshSessionData = freshSessionSnap.data() || {};
  if (
    normalizeString(freshSessionData.pairAttemptId) !== pairAttemptId ||
    normalizeString(freshSessionData.matchStage) !==
      MATCH_STAGE.FINALIZATION_REQUESTED ||
    !PENDING_STATUSES.has(freshSessionData.status)
  ) {
    return {processed: false, reason: "finalization_superseded"};
  }
  if (!allParticipantsReadyForFinalization(
    freshSessionData.participantStates || {},
    freshSessionData.participantIds || [],
  )) {
    return {processed: false, reason: "finalization_not_ready"};
  }
  const responderId = readAssignedResponderId(freshSessionData);
  try {
    await finalizer({sessionId, pairAttemptId}, {
      auth: {uid: responderId},
    }, {
      responderId,
      protocolV2Finalization: true,
    });
    return {processed: true, reason: "finalized"};
  } catch (error) {
    const latestSnap = await db.collection("videoSessions").doc(sessionId).get();
    const latest = latestSnap.exists ? latestSnap.data() || {} : {};
    if (
      !latestSnap.exists ||
      normalizeString(latest.pairAttemptId) !== pairAttemptId ||
      normalizeString(latest.matchStage) !== MATCH_STAGE.FINALIZATION_REQUESTED ||
      !PENDING_STATUSES.has(latest.status)
    ) {
      return {processed: false, reason: "finalization_superseded"};
    }
    console.error("Protocol v2 finalization retry failed", {
      sessionId,
      pairAttemptId,
      error: normalizeString(error?.message) || "finalization_failed",
    });
    return {
      processed: false,
      reason: error?.code === "failed-precondition" ?
        "finalization_in_progress" :
        "finalization_deferred",
    };
  }
}

async function processMatchProtocolV2Write(change, context, options = {}) {
  if (!change.after.exists) {
    return {processed: false, reason: "session_deleted"};
  }
  return processProtocolV2SessionState({
    ...options,
    sessionId: context.params.sessionId,
    sessionData: change.after.data() || {},
  });
}

async function recoverPendingProtocolV2States(options = {}) {
  const db = options.db || admin.firestore();
  const stageQueries = RECOVERABLE_STAGES.flatMap((matchStage) =>
    Array.from(PENDING_STATUSES).map((status) =>
      db.collection("videoSessions")
        .where("matchStage", "==", matchStage)
        .where("status", "==", status)
        .limit(100)
        .get(),
    ));
  const snapshots = await Promise.all(stageQueries.concat([
    db.collection("videoSessions")
      .where("matchRecovery.status", "==", "pending")
      .limit(100)
      .get(),
    db.collection("videoSessions")
      .where("matchRecovery.status", "==", "processing")
      .limit(100)
      .get(),
  ]));
  const docs = new Map();
  snapshots.forEach((snapshot) => snapshot.docs.forEach((doc) => {
    docs.set(doc.id, doc);
  }));
  return Promise.all(Array.from(docs.values()).map((doc) =>
    processProtocolV2SessionState({
      ...options,
      db,
      sessionId: doc.id,
      sessionData: doc.data() || {},
    }),
  ));
}

exports.processMatchProtocolV2State = functions
  .runWith({
    failurePolicy: true,
    secrets: [...apnsSecrets, ...dailySecrets],
  })
  .region(FIRESTORE_TRIGGER_REGION)
  .firestore
  .document("videoSessions/{sessionId}")
  .onWrite(processMatchProtocolV2Write);

exports.recoverMatchProtocolV2State = functions
  .runWith({secrets: [...apnsSecrets, ...dailySecrets]})
  .pubsub
  .schedule("every 1 minutes")
  .onRun(() => recoverPendingProtocolV2States());

exports.__private__ = {
  FIRESTORE_TRIGGER_REGION,
  RECOVERABLE_STAGES,
  finishRouteFailure,
  processMatchProtocolV2Write,
  processProtocolV2SessionState,
  reconcileProtocolV2TerminalSideEffects,
  readAssignedResponderId,
  readPendingStudentId,
  recoverPendingProtocolV2States,
};
