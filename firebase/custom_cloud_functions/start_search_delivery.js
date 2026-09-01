const {
  BACKGROUND_STUDENT_RESPONDER_PUSH_TIMEOUT_MS,
  buildStudentPairResponderCallData,
  runBackgroundStudentResponderPushSender,
  sendVoipPushToStudentResponder,
} = require("./start_search_push_transport");
const {
  normalizeRole,
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  getReadOnlyUserVoipTokenState,
} = require("./voip_tokens");
const {
  MATCH_PROTOCOL_VERSION,
  MATCH_STAGE,
} = require("./match_protocol_v2");
const {
  advanceProtocolV2MatchStage,
  classifyProtocolV2RouteResult,
  routeProtocolV2Participant,
  waitForForegroundMatchClaim,
} = require("./match_delivery_v2");
const {
  backgroundStudentResponderPushStillCurrent,
  cancelBackgroundStudentResponderNotification,
  cancelTeacherResponderNotification,
  createBackgroundStudentResponderIncomingCall,
  createTeacherResponderIncomingCall,
  recordBackgroundStudentResponderPushFailure,
  recordBackgroundStudentResponderPushSuccess,
  recordTeacherResponderPushResult,
  teacherResponderPushStillCurrent,
} = require("./start_search_notification_store");

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function readErrorMessage(error, fallback = "") {
  if (error && typeof error === "object") {
    try {
      return normalizeString(error.message) || fallback;
    } catch (readError) {
      return fallback;
    }
  }
  try {
    return normalizeString(String(error)) || fallback;
  } catch (stringifyError) {
    return fallback;
  }
}

function waitForForegroundStudentResponderResolution(options = {}) {
  return waitForForegroundMatchClaim(options);
}

async function routeProtocolV2InitialMatch({
  db,
  lockResult = {},
  requesterId = "",
  responderRole = "student",
  studentPushSender = sendVoipPushToStudentResponder,
  teacherPushSender = sendVoipPushToStudentResponder,
  studentPreDispatchWait = waitForForegroundStudentResponderResolution,
}) {
  const isTeacherMatch = normalizeRole(responderRole) === "native_speaker";
  const participantIds = isTeacherMatch ?
    [normalizeString(lockResult.responderId)] :
    [normalizeString(requesterId), normalizeString(lockResult.responderId)];
  const results = await Promise.all(participantIds.filter(Boolean).map(
    async (participantId) => {
      try {
        return await routeProtocolV2Participant({
          db,
          sessionId: lockResult.sessionId,
          pairAttemptId: lockResult.pairAttemptId,
          participantId,
          preDispatchWait: isTeacherMatch ? null : studentPreDispatchWait,
          pushSender: (recipientId, callData) =>
            runBackgroundStudentResponderPushSender({
              pushSender: isTeacherMatch ? teacherPushSender : studentPushSender,
              responderId: recipientId,
              callData,
            }),
        });
      } catch (error) {
        return {
          shouldNotify: true,
          participantId,
          pushResult: {sent: false, reason: "route_failed"},
          error: readErrorMessage(error, "route_failed"),
        };
      }
    },
  ));
  const failedResult = results.find((result) => [
    "definitive_failure",
    "response_window_closed",
  ].includes(classifyProtocolV2RouteResult(result))) || null;
  const retryPending = results.some((result) =>
    classifyProtocolV2RouteResult(result) === "in_progress",
  );
  if (!failedResult && !retryPending) {
    await advanceProtocolV2MatchStage({
      db,
      sessionId: lockResult.sessionId,
      pairAttemptId: lockResult.pairAttemptId,
      expectedStages: [MATCH_STAGE.AWAITING_INITIAL_DISPATCH],
      nextStage: isTeacherMatch ?
        MATCH_STAGE.AWAITING_TEACHER_RESPONSE :
        MATCH_STAGE.AWAITING_ACCEPTANCE,
    });
  }
  return {results, failedResult, retryPending};
}

function shouldRouteProtocolV2InitialMatch(lockResult = {}) {
  return Number(lockResult.matchProtocolVersion) === MATCH_PROTOCOL_VERSION &&
    lockResult.finalizationRequested !== true;
}

async function readProtocolV2PostRouteOutcome({
  db,
  sessionId,
  pairAttemptId,
}) {
  const sessionSnap = await db.collection("videoSessions").doc(sessionId).get();
  if (!sessionSnap.exists) {
    return {current: false, terminal: true, reason: "session_missing"};
  }
  const sessionData = sessionSnap.data() || {};
  if (
    Number(sessionData.matchProtocolVersion) !== MATCH_PROTOCOL_VERSION ||
    normalizeString(sessionData.pairAttemptId) !== pairAttemptId
  ) {
    return {
      current: false,
      terminal: true,
      reason: "pair_attempt_mismatch",
      sessionData,
    };
  }
  const current = [
    VIDEO_SESSION_STATUS.SEARCHING,
    VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
    VIDEO_SESSION_STATUS.CONNECTING,
    VIDEO_SESSION_STATUS.ACTIVE,
  ].includes(sessionData.status);
  return {
    current,
    terminal: !current,
    reason: current ? "current" : `session_${sessionData.status || "unknown"}`,
    sessionData,
  };
}

async function maybeNotifyBackgroundStudentResponder({
  db,
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  requesterData = {},
  pushSender = sendVoipPushToStudentResponder,
  pushTimeoutMs = BACKGROUND_STUDENT_RESPONDER_PUSH_TIMEOUT_MS,
  prePushWait = null,
}) {
  const nowMillis = Date.now();
  const notification = await createBackgroundStudentResponderIncomingCall({
    db,
    sessionId,
    responderId,
    responderSearchRequestDocId,
    requesterData,
    nowMillis,
  });
  if (!notification.shouldNotify) {
    return notification;
  }

  if (typeof prePushWait === "function") {
    await prePushWait();
  }

  const prePushState = await backgroundStudentResponderPushStillCurrent({
    db,
    sessionId,
    responderId,
    responderSearchRequestDocId,
    notificationId: notification.notificationId,
    nowMillis: Date.now(),
  });
  if (!prePushState.stillCurrent) {
    let cancelResult = null;
    if (!prePushState.leaveForAccept) {
      try {
        cancelResult = await cancelBackgroundStudentResponderNotification({
          db,
          notificationId: notification.notificationId,
          sessionId,
          responderId,
          responderSearchRequestDocId,
          reason: "stale_before_push",
          nowMillis: Date.now(),
        });
      } catch (error) {
        console.error(
          "Failed to cancel stale background student notification",
          {
            sessionId,
            responderId,
            notificationId: notification.notificationId,
            error: readErrorMessage(error, "cancel_failed"),
          },
        );
      }
    }
    return {
      ...notification,
      shouldNotify: false,
      reason: prePushState.leaveForAccept || cancelResult?.leaveForAccept ?
        "accept_finalization_in_progress" :
        "stale_before_push",
      staleReason: cancelResult?.staleReason ||
        cancelResult?.reason ||
        prePushState.reason,
    };
  }

  const callData = buildStudentPairResponderCallData({
    sessionId,
    pushPayload: notification.pushPayload,
  });
  let pushResult;
  try {
    pushResult = await runBackgroundStudentResponderPushSender({
      pushSender,
      responderId,
      callData,
      timeoutMs: pushTimeoutMs,
    });
  } catch (error) {
    pushResult = {
      sent: false,
      reason: "push_failed",
      error: readErrorMessage(error, "push_failed"),
    };
  }
  if (!pushResult || pushResult.sent !== true) {
    pushResult = {
      ...(pushResult && typeof pushResult === "object" ? pushResult : {}),
      sent: false,
      reason:
        normalizeString(pushResult?.reason) ||
        "push_failed",
      error:
        normalizeString(pushResult?.error) ||
        normalizeString(pushResult?.reason) ||
        "push_failed",
    };
  }
  if (pushResult && pushResult.sent === false) {
    let failureFinalization;
    try {
      failureFinalization = await recordBackgroundStudentResponderPushFailure({
        db,
        notificationId: notification.notificationId,
        sessionId,
        responderId,
        responderSearchRequestDocId,
        error: {
          message:
            normalizeString(pushResult.error) ||
            normalizeString(pushResult.reason) ||
            "push_failed",
        },
        nowMillis: Date.now(),
      });
    } catch (error) {
      console.error(
        "Failed to record background student responder push failure",
        {
          sessionId,
          responderId,
          notificationId: notification.notificationId,
          error: readErrorMessage(error, "push_finalization_failed"),
        },
      );
      return {
        ...notification,
        shouldNotify: false,
        reason: "push_finalization_failed",
        staleReason: readErrorMessage(error, "push_finalization_failed"),
        callData,
        pushResult,
      };
    }
    if (!failureFinalization.stillCurrent) {
      return {
        ...notification,
        shouldNotify: false,
        reason: failureFinalization.reason,
        staleReason: failureFinalization.staleReason ||
          failureFinalization.reason,
        callData,
        pushResult,
      };
    }
  } else if (pushResult && pushResult.sent === true) {
    let successFinalization;
    try {
      successFinalization = await recordBackgroundStudentResponderPushSuccess({
        db,
        notificationId: notification.notificationId,
        sessionId,
        responderId,
        responderSearchRequestDocId,
        pushResult,
        nowMillis: Date.now(),
      });
    } catch (error) {
      console.error(
        "Failed to record background student responder push success",
        {
          sessionId,
          responderId,
          notificationId: notification.notificationId,
          pushSent: true,
          error: readErrorMessage(error, "push_finalization_failed"),
        },
      );
      return {
        ...notification,
        shouldNotify: false,
        reason: "push_finalization_failed",
        staleReason: readErrorMessage(error, "push_finalization_failed"),
        callData,
        pushResult,
      };
    }
    if (!successFinalization.stillCurrent) {
      return {
        ...notification,
        shouldNotify: false,
        reason: successFinalization.reason,
        staleReason: successFinalization.staleReason ||
          successFinalization.reason,
        callData,
        pushResult,
      };
    }
  }
  return {
    ...notification,
    callData,
    pushResult,
  };
}

async function maybeNotifyTeacherResponder({
  db,
  sessionId = "",
  responderId = "",
  requesterData = {},
  pushSender = sendVoipPushToStudentResponder,
  pushTimeoutMs = BACKGROUND_STUDENT_RESPONDER_PUSH_TIMEOUT_MS,
  tokenReader = getReadOnlyUserVoipTokenState,
  nowMillis = Date.now(),
}) {
  const notification = await createTeacherResponderIncomingCall({
    db,
    sessionId,
    responderId,
    requesterData,
    nowMillis,
  });
  if (!notification.shouldNotify) {
    return notification;
  }

  let prePushState;
  try {
    prePushState = await teacherResponderPushStillCurrent({
      db,
      sessionId,
      responderId,
      notificationId: notification.notificationId,
      nowMillis: Date.now(),
      tokenReader,
    });
  } catch (error) {
    console.error(
      "Failed to validate teacher notification before push",
      {
        sessionId,
        responderId,
        notificationId: notification.notificationId,
        error: readErrorMessage(error, "pre_push_validation_failed"),
      },
    );
    return {
      ...notification,
      shouldNotify: false,
      reason: "pre_push_validation_failed",
      staleReason: readErrorMessage(error, "pre_push_validation_failed"),
    };
  }
  if (!prePushState.stillCurrent) {
    let cancelResult = null;
    if (!prePushState.leaveForAccept) {
      try {
        cancelResult = await cancelTeacherResponderNotification({
          db,
          notificationId: notification.notificationId,
          sessionId,
          responderId,
          reason: "stale_before_push",
          staleReason: prePushState.reason,
          nowMillis: Date.now(),
        });
      } catch (error) {
        console.error(
          "Failed to cancel stale teacher notification",
          {
            sessionId,
            responderId,
            notificationId: notification.notificationId,
            error: readErrorMessage(error, "cancel_failed"),
          },
        );
      }
    }
    return {
      ...notification,
      shouldNotify: false,
      reason: prePushState.leaveForAccept || cancelResult?.leaveForAccept ?
        "accept_finalization_in_progress" :
        "stale_before_push",
      staleReason:
        cancelResult?.staleReason ||
        cancelResult?.reason ||
        prePushState.reason,
    };
  }

  const callData = buildStudentPairResponderCallData({
    sessionId,
    pushPayload: notification.pushPayload,
  });
  let pushResult;
  try {
    pushResult = await runBackgroundStudentResponderPushSender({
      pushSender,
      responderId,
      callData,
      timeoutMs: pushTimeoutMs,
    });
  } catch (error) {
    pushResult = {
      sent: false,
      reason: "push_failed",
      error: readErrorMessage(error, "push_failed"),
    };
  }
  if (!pushResult || pushResult.sent !== true) {
    pushResult = {
      ...(pushResult && typeof pushResult === "object" ? pushResult : {}),
      sent: false,
      reason:
        normalizeString(pushResult?.reason) ||
        "push_failed",
      error:
        normalizeString(pushResult?.error) ||
        normalizeString(pushResult?.reason) ||
        "push_failed",
    };
  }

  let finalization;
  try {
    finalization = await recordTeacherResponderPushResult({
      db,
      notificationId: notification.notificationId,
      sessionId,
      responderId,
      pushResult,
      nowMillis: Date.now(),
    });
  } catch (error) {
    console.error(
      "Failed to record teacher responder push result",
      {
        sessionId,
        responderId,
        notificationId: notification.notificationId,
        pushSent: pushResult?.sent === true,
        error: readErrorMessage(error, "push_finalization_failed"),
      },
    );
    return {
      ...notification,
      shouldNotify: false,
      reason: "push_finalization_failed",
      staleReason: readErrorMessage(error, "push_finalization_failed"),
      callData,
      pushResult,
    };
  }
  if (!finalization.stillCurrent) {
    return {
      ...notification,
      shouldNotify: false,
      reason: finalization.reason,
      staleReason: finalization.staleReason || finalization.reason,
      callData,
      pushResult,
    };
  }

  return {
    ...notification,
    callData,
    pushResult,
  };
}

module.exports = {
  waitForForegroundStudentResponderResolution,
  routeProtocolV2InitialMatch,
  shouldRouteProtocolV2InitialMatch,
  readProtocolV2PostRouteOutcome,
  maybeNotifyBackgroundStudentResponder,
  maybeNotifyTeacherResponder,
};
