const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  acceptCallCallable,
} = require("./accept_call").__private__;
const {
  releaseSessionPairLocksInTransaction,
} = require("./match_pair_lock");
const {
  MATCH_ACTION,
  MATCH_DECISION,
  MATCH_DELIVERY,
  MATCH_PROTOCOL_VERSION,
  MATCH_STAGE,
  MATCH_SURFACE,
  allParticipantsAccepted,
  allParticipantsReadyForFinalization,
  normalizeParticipantState,
  transitionParticipantState,
} = require("./match_protocol_v2");
const {
  SEARCH_REQUEST_STATUS,
} = require("./search_requests");
const {
  advanceProtocolV2MatchStage,
  cancelProtocolV2NativeSurfaces,
  buildCallKitLifecycleEscalation,
  classifyProtocolV2RouteResult,
  findInAppParticipantsNeedingCallKitEscalation,
  isFreshForegroundSearchRequest,
  routeProtocolV2Participant,
  searchRequestMatchesProtocolV2Attempt,
} = require("./match_delivery_v2");
const {
  runBackgroundStudentResponderPushSender,
  reconcileReleasedProtocolV2Match,
  resumeRestoredStudentSearch,
  releaseProtocolV2MatchAfterRouteFailure,
  sendVoipPushToStudentResponder,
  waitForForegroundStudentResponderResolution,
} = require("./start_search").__private__;
const {
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  cancelProtocolV2NotificationsInTransaction,
  incomingCallNotificationRef,
} = require("./call_notifications");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const RESPONDABLE_STATUSES = new Set([
  VIDEO_SESSION_STATUS.SEARCHING,
  VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
]);
const CALLKIT_RESPONSE_WINDOW_MS = 45 * 1000;
const FINALIZATION_GUARD_WINDOW_MS = 90 * 1000;
const TIMEOUT_CLOCK_SKEW_MS = 2 * 1000;

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function timestampToMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") {
    const millis = Number(value.toMillis());
    return Number.isFinite(millis) ? millis : null;
  }
  if (typeof value.toDate === "function") {
    const millis = value.toDate().getTime();
    return Number.isFinite(millis) ? millis : null;
  }
  const millis = Number(value);
  return Number.isFinite(millis) ? millis : null;
}

function normalizeRespondToMatchInput(data = {}) {
  const sessionId = normalizeString(data.sessionId);
  const pairAttemptId = normalizeString(data.pairAttemptId);
  const action = normalizeString(data.action);
  const actionId = normalizeString(data.actionId);
  if (
    !sessionId ||
    !pairAttemptId ||
    !actionId ||
    sessionId.length > 256 ||
    pairAttemptId.length > 256 ||
    actionId.length > 128 ||
    sessionId.includes("/") ||
    pairAttemptId.includes("/")
  ) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "sessionId, pairAttemptId and actionId are required",
    );
  }
  if (!Object.values(MATCH_ACTION).includes(action)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Unsupported match response action",
    );
  }
  return {sessionId, pairAttemptId, action, actionId};
}

function buildRespondToMatchResponse({
  status = VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
  pairAttemptId = "",
  participantState = {},
  stale = false,
  reason = "updated",
  ok = true,
} = {}) {
  const state = normalizeParticipantState(participantState);
  return {
    ok,
    status,
    pairAttemptId,
    surface: state.surface,
    decision: state.decision,
    stale,
    reason,
  };
}

function readResponseDeadlineMillis(sessionData = {}) {
  return timestampToMillis(sessionData.responseExpiresAt) ??
    timestampToMillis(sessionData.confirmationExpiresAt);
}

function isMatchTimeoutReached({
  deadlineMillis,
  nowMillis = Date.now(),
  clockSkewMillis = TIMEOUT_CLOCK_SKEW_MS,
} = {}) {
  return Number.isFinite(deadlineMillis) &&
    deadlineMillis - nowMillis <= clockSkewMillis;
}

function readAssignedResponderId(sessionData = {}) {
  return normalizeString(sessionData.currentResponderId) ||
    normalizeString(sessionData.currentTutorId) ||
    normalizeString(sessionData.responderId) ||
    normalizeString(sessionData.tutorId);
}

function buildLateTerminalSearchSuppression({
  searchData = {},
  sessionId,
  pairAttemptId,
  participantId,
  action,
  serverTimestamp,
  fieldDelete,
} = {}) {
  const isUnbound = ![
    searchData.activeSessionId,
    searchData.currentSessionId,
    searchData.matchedSessionId,
  ].some((value) => normalizeString(value));
  if (
    searchData.status !== SEARCH_REQUEST_STATUS.ACTIVE ||
    !isUnbound ||
    normalizeString(searchData.restoredFromSessionId) !== sessionId ||
    normalizeString(searchData.restoredFromPairAttemptId) !== pairAttemptId
  ) {
    return null;
  }
  const stopReason = action === MATCH_ACTION.TIMEOUT ?
    "match_timeout" :
    (action === MATCH_ACTION.DECLINE ? "match_declined" : "match_cancelled");
  return {
    status: SEARCH_REQUEST_STATUS.CANCELLED,
    stopReason,
    stoppedAt: serverTimestamp,
    stoppedBy: participantId,
    updatedAt: serverTimestamp,
    restoredFromSessionId: fieldDelete,
    restoredFromPairAttemptId: fieldDelete,
  };
}

function buildDeclineReleaseOptions({
  db,
  transaction,
  sessionId,
  sessionData = {},
  participantId,
  participantIds = [],
  serverTimestamp,
  fieldDelete,
}) {
  const restoreParticipantIds = participantIds.filter(
    (candidateId) => candidateId !== participantId,
  );
  const exclusions = Object.fromEntries(restoreParticipantIds.map(
    (candidateId) => [candidateId, [participantId]],
  ));
  return {
    db,
    transaction,
    sessionId,
    sessionData,
    serverTimestamp,
    fieldDelete,
    searchRequestStatus: SEARCH_REQUEST_STATUS.CANCELLED,
    stopReason: "match_declined",
    releaseCallState: true,
    restoreSearchParticipantIds: restoreParticipantIds,
    restoreSearchExcludedCandidateIdsByParticipantId: exclusions,
  };
}

async function cancelNativeMatchSurfaces({
  db,
  sessionId,
  pairAttemptId,
  participantStates = {},
} = {}) {
  return cancelProtocolV2NativeSurfaces({
    db,
    sessionId,
    pairAttemptId,
    participantStates,
    reason: "match_cancelled",
  });
}

async function respondToMatchCallable(data, context, options = {}) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }
  const input = normalizeRespondToMatchInput(data);
  const participantId = context.auth.uid;
  const db = options.db || admin.firestore();
  const sessionRef = db.collection("videoSessions").doc(input.sessionId);
  const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
  const fieldDelete = admin.firestore.FieldValue.delete();

  const result = await db.runTransaction(async (transaction) => {
    const notificationRef = incomingCallNotificationRef(
      db,
      input.sessionId,
      participantId,
      input.pairAttemptId,
    );
    const participantSearchRef = db.collection("searchRequests")
      .doc(participantId);
    const [sessionSnap, notificationSnap, participantSearchSnap] =
      await Promise.all([
      transaction.get(sessionRef),
      transaction.get(notificationRef),
      transaction.get(participantSearchRef),
    ]);
    if (!sessionSnap.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Video session not found",
      );
    }
    const sessionData = sessionSnap.data() || {};
    const participantIds = Array.from(new Set(
      (sessionData.participantIds || []).map(normalizeString).filter(Boolean),
    ));
    if (!participantIds.includes(participantId)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "You are not a participant of this match",
      );
    }
    const otherSearchEntries = await Promise.all(participantIds
      .filter((candidateId) => candidateId !== participantId)
      .map(async (candidateId) => [
        candidateId,
        await transaction.get(
          db.collection("searchRequests").doc(candidateId),
        ),
      ]));
    const searchDataByParticipantId = Object.fromEntries([
      [participantId, participantSearchSnap.exists ?
        participantSearchSnap.data() || {} : {}],
      ...otherSearchEntries.map(([candidateId, snapshot]) => [
        candidateId,
        snapshot.exists ? snapshot.data() || {} : {},
      ]),
    ]);
    const currentState = normalizeParticipantState(
      sessionData.participantStates?.[participantId],
      sessionData.participantRoles?.[participantId],
    );
    if (
      Number(sessionData.matchProtocolVersion) !== MATCH_PROTOCOL_VERSION ||
      !sessionData.participantStates
    ) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "This session does not use match protocol v2",
      );
    }
    if (normalizeString(sessionData.pairAttemptId) !== input.pairAttemptId) {
      return {
        response: buildRespondToMatchResponse({
          status: sessionData.status,
          pairAttemptId: normalizeString(sessionData.pairAttemptId),
          participantState: currentState,
          stale: true,
          reason: "pair_attempt_mismatch",
          ok: false,
        }),
      };
    }
    const terminalAction = [
      MATCH_ACTION.DECLINE,
      MATCH_ACTION.CANCEL,
      MATCH_ACTION.TIMEOUT,
    ].includes(input.action);
    if (!RESPONDABLE_STATUSES.has(sessionData.status)) {
      const lateTerminalSearchUpdate = terminalAction &&
        participantSearchSnap.exists ?
        buildLateTerminalSearchSuppression({
          searchData: participantSearchSnap.data() || {},
          sessionId: input.sessionId,
          pairAttemptId: input.pairAttemptId,
          participantId,
          action: input.action,
          serverTimestamp,
          fieldDelete,
        }) :
        null;
      if (lateTerminalSearchUpdate) {
        transaction.update(participantSearchRef, lateTerminalSearchUpdate);
        return {
          response: buildRespondToMatchResponse({
            status: sessionData.status,
            pairAttemptId: input.pairAttemptId,
            participantState: currentState,
            stale: true,
            reason: "late_terminal_search_stopped",
          }),
        };
      }
      return {
        response: buildRespondToMatchResponse({
          status: sessionData.status,
          pairAttemptId: input.pairAttemptId,
          participantState: currentState,
          stale: true,
          reason: "session_not_pending",
        }),
      };
    }
    const deadlineMillis = readResponseDeadlineMillis(sessionData);
    const nowMillis = Number.isFinite(options.nowMillis) ?
      options.nowMillis :
      Date.now();
    if (
      [MATCH_ACTION.CLAIM_IN_APP, MATCH_ACTION.ACCEPT].includes(input.action) &&
      deadlineMillis !== null &&
      deadlineMillis <= nowMillis
    ) {
      return {
        response: buildRespondToMatchResponse({
          status: sessionData.status,
          pairAttemptId: input.pairAttemptId,
          participantState: currentState,
          stale: true,
          reason: "response_window_closed",
          ok: false,
        }),
      };
    }
    if (
      input.action === MATCH_ACTION.CLAIM_IN_APP &&
      normalizeString(sessionData.scenario) === "student_teacher" &&
      currentState.role === "student" &&
      ![
        MATCH_STAGE.AWAITING_STUDENT_DISPATCH,
        MATCH_STAGE.AWAITING_ACCEPTANCE,
      ].includes(normalizeString(sessionData.matchStage))
    ) {
      return {
        response: buildRespondToMatchResponse({
          status: sessionData.status,
          pairAttemptId: input.pairAttemptId,
          participantState: currentState,
          stale: false,
          reason: "student_stage_not_ready",
          ok: false,
        }),
      };
    }
    const participantSearchData = searchDataByParticipantId[participantId] || {};
    if (
      input.action === MATCH_ACTION.CLAIM_IN_APP &&
      currentState.role === "student" &&
      (
        participantSearchData.status !== SEARCH_REQUEST_STATUS.MATCHED ||
        !searchRequestMatchesProtocolV2Attempt({
          requestData: participantSearchData,
          sessionId: input.sessionId,
          pairAttemptId: input.pairAttemptId,
        }) ||
        !isFreshForegroundSearchRequest({
          requestData: participantSearchData,
          nowMillis,
        })
      )
    ) {
      return {
        response: buildRespondToMatchResponse({
          status: sessionData.status,
          pairAttemptId: input.pairAttemptId,
          participantState: currentState,
          stale: true,
          reason: "claim_requires_fresh_foreground",
          ok: false,
        }),
      };
    }
    if (
      input.action === MATCH_ACTION.TIMEOUT &&
      !isMatchTimeoutReached({deadlineMillis, nowMillis})
    ) {
      return {
        response: buildRespondToMatchResponse({
          status: sessionData.status,
          pairAttemptId: input.pairAttemptId,
          participantState: currentState,
          stale: false,
          reason: "timeout_not_reached",
          ok: false,
        }),
      };
    }

    const transition = transitionParticipantState({
      state: currentState,
      role: currentState.role,
      action: input.action,
      actionId: input.actionId,
      updatedAt: serverTimestamp,
    });
    let nextStates = {
      ...sessionData.participantStates,
      [participantId]: transition.state,
    };
    const initiallyAllAccepted = allParticipantsAccepted(
      nextStates,
      participantIds,
    );
    const lifecycleEscalationParticipantIds = initiallyAllAccepted ?
      findInAppParticipantsNeedingCallKitEscalation({
        sessionData: {
          ...sessionData,
          sessionId: input.sessionId,
          participantStates: nextStates,
        },
        searchDataByParticipantId,
        nowMillis,
      }) :
      [];
    if (lifecycleEscalationParticipantIds.length > 0) {
      nextStates = buildCallKitLifecycleEscalation({
        sessionData: {
          ...sessionData,
          sessionId: input.sessionId,
          participantStates: nextStates,
        },
        participantIds: lifecycleEscalationParticipantIds,
        updatedAt: serverTimestamp,
      });
    }
    if (transition.changed && !terminalAction) {
      transaction.update(sessionRef, {
        participantStates: nextStates,
        updatedAt: serverTimestamp,
      });
    }
    const notificationData = notificationSnap.exists ?
      notificationSnap.data() || {} :
      {};
    if (
      !terminalAction &&
      transition.state.decision === MATCH_DECISION.ACCEPTED &&
      notificationSnap.exists &&
      normalizeString(notificationData.pairAttemptId) === input.pairAttemptId &&
      normalizeString(notificationData.recipientId) === participantId &&
      ["preparing", "sent", "failed"].includes(notificationData.status)
    ) {
      transaction.update(notificationRef, {
        status: "accepted",
        acceptedAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });
    }

    if (
      terminalAction &&
      transition.state.decision === MATCH_DECISION.DECLINED
    ) {
      const cancelReason = input.action === MATCH_ACTION.TIMEOUT ?
        "match_timeout" :
        (input.action === MATCH_ACTION.CANCEL ?
          "match_cancelled" :
          "match_declined");
      const releaseOptions = buildDeclineReleaseOptions({
        db,
        transaction,
        sessionId: input.sessionId,
        sessionData: {
          ...sessionData,
          participantStates: nextStates,
        },
        participantId,
        participantIds,
        serverTimestamp,
        fieldDelete,
      });
      await releaseSessionPairLocksInTransaction(releaseOptions);
      cancelProtocolV2NotificationsInTransaction({
        db,
        transaction,
        sessionId: input.sessionId,
        pairAttemptId: input.pairAttemptId,
        participantStates: nextStates,
        cancelReason,
        serverTimestamp,
      });
      transaction.update(sessionRef, {
        status: VIDEO_SESSION_STATUS.CANCELLED,
        pairStatus: VIDEO_SESSION_STATUS.CANCELLED,
        participantStates: nextStates,
        cancelledAt: serverTimestamp,
        cancelledBy: participantId,
        cancelReason,
        matchRecovery: {
          status: "pending",
          attempts: 0,
          pairAttemptId: input.pairAttemptId,
          reason: cancelReason,
          restoreParticipantIds:
            releaseOptions.restoreSearchParticipantIds,
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
        cancelled: true,
        restoreParticipantIds: releaseOptions.restoreSearchParticipantIds,
        participantStates: nextStates,
        response: buildRespondToMatchResponse({
          status: VIDEO_SESSION_STATUS.CANCELLED,
          pairAttemptId: input.pairAttemptId,
          participantState: transition.state,
          reason: transition.reason,
        }),
      };
    }

    const counterpartId = participantIds.find(
      (candidateId) => candidateId !== participantId,
    );
    const counterpartState = counterpartId ? normalizeParticipantState(
      nextStates[counterpartId],
      sessionData.participantRoles?.[counterpartId],
    ) : null;
    const shouldRouteStudentAfterTeacherAccept =
      options.skipStagedRouting !== true &&
      ["native_speaker", "teacher"].includes(currentState.role) &&
      transition.state.decision === MATCH_DECISION.ACCEPTED &&
      counterpartState?.role === "student" &&
      counterpartState.surface === MATCH_SURFACE.PENDING &&
      counterpartState.decision === MATCH_DECISION.PENDING;
    const shouldFinalize =
      lifecycleEscalationParticipantIds.length === 0 &&
      allParticipantsReadyForFinalization(nextStates, participantIds);
    if (shouldRouteStudentAfterTeacherAccept) {
      const stagedResponseExpiresAt = admin.firestore.Timestamp.fromMillis(
        nowMillis + CALLKIT_RESPONSE_WINDOW_MS,
      );
      transaction.update(sessionRef, {
        responseExpiresAt: stagedResponseExpiresAt,
        confirmationExpiresAt: stagedResponseExpiresAt,
        "matchLock.expiresAt": stagedResponseExpiresAt,
        matchStage: MATCH_STAGE.AWAITING_STUDENT_DISPATCH,
        updatedAt: serverTimestamp,
      });
    }
    if (lifecycleEscalationParticipantIds.length > 0) {
      const escalationResponseExpiresAt = admin.firestore.Timestamp.fromMillis(
        nowMillis + CALLKIT_RESPONSE_WINDOW_MS,
      );
      transaction.update(sessionRef, {
        participantStates: nextStates,
        responseExpiresAt: escalationResponseExpiresAt,
        confirmationExpiresAt: escalationResponseExpiresAt,
        "matchLock.expiresAt": escalationResponseExpiresAt,
        matchStage: MATCH_STAGE.AWAITING_INITIAL_DISPATCH,
        lifecycleEscalation: {
          revision:
            Math.max(0, Number(sessionData.lifecycleEscalation?.revision) || 0) +
              1,
          participantIds: lifecycleEscalationParticipantIds,
          requestedAt: serverTimestamp,
        },
        updatedAt: serverTimestamp,
      });
    }
    if (shouldFinalize) {
      const finalizationExpiresAt = admin.firestore.Timestamp.fromMillis(
        nowMillis + FINALIZATION_GUARD_WINDOW_MS,
      );
      transaction.update(sessionRef, {
        responseExpiresAt: finalizationExpiresAt,
        confirmationExpiresAt: finalizationExpiresAt,
        "matchLock.expiresAt": finalizationExpiresAt,
        matchStage: MATCH_STAGE.FINALIZATION_REQUESTED,
        matchFinalization: {
          status: "requested",
          pairAttemptId: input.pairAttemptId,
          requestedBy: participantId,
          actionId: input.actionId,
          requestedAt: serverTimestamp,
          expiresAt: finalizationExpiresAt,
        },
        updatedAt: serverTimestamp,
      });
    }

    return {
      cancelled: false,
      shouldFinalize,
      lifecycleEscalated: lifecycleEscalationParticipantIds.length > 0,
      responderId: readAssignedResponderId(sessionData),
      routeParticipantId: shouldRouteStudentAfterTeacherAccept ?
        counterpartId :
        "",
      participantStates: nextStates,
      response: buildRespondToMatchResponse({
        status: sessionData.status,
        pairAttemptId: input.pairAttemptId,
        participantState: transition.state,
        reason: transition.reason,
      }),
    };
  });

  if (result.cancelled) {
    await reconcileReleasedProtocolV2Match({
      db,
      sessionId: input.sessionId,
      pairAttemptId: input.pairAttemptId,
      options,
      cancelSurfaces: cancelNativeMatchSurfaces,
    }).catch((error) => {
      console.warn("Protocol v2 terminal recovery deferred", {
        sessionId: input.sessionId,
        pairAttemptId: input.pairAttemptId,
        error: normalizeString(error?.message) || "recovery_deferred",
      });
    });
    return result.response;
  }
  if (result.lifecycleEscalated) {
    return {
      ...result.response,
      reason: "lifecycle_escalation_pending",
    };
  }
  if (result.routeParticipantId) {
    const participantPushSender =
      options.participantPushSender || sendVoipPushToStudentResponder;
    let routeResult;
    try {
      routeResult = await routeProtocolV2Participant({
        db,
        sessionId: input.sessionId,
        pairAttemptId: input.pairAttemptId,
        participantId: result.routeParticipantId,
        preDispatchWait:
          options.studentPreDispatchWait ||
          waitForForegroundStudentResponderResolution,
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
        participantId: result.routeParticipantId,
        pushResult: {sent: false, reason: "route_failed"},
        error: normalizeString(error?.message) || "route_failed",
      };
    }
    const routeOutcome = classifyProtocolV2RouteResult(routeResult);
    if ([
      "definitive_failure",
      "response_window_closed",
    ].includes(routeOutcome)) {
      const failureState = routeResult.participantState || {};
      const releaseResult = await releaseProtocolV2MatchAfterRouteFailure({
        db,
        sessionId: input.sessionId,
        pairAttemptId: input.pairAttemptId,
        failedParticipantId: result.routeParticipantId,
        expectedDispatchId: failureState.dispatchId,
        expectedDelivery: failureState.delivery,
        expectedDeliveryFailureKind: failureState.deliveryFailureKind,
        requireResponseWindowClosed:
          routeOutcome === "response_window_closed",
        stopReason: routeOutcome === "response_window_closed" ?
          "protocol_v2_response_timeout" :
          "protocol_v2_staged_push_failed",
      });
      if (releaseResult.released) {
        await reconcileReleasedProtocolV2Match({
          db,
          sessionId: input.sessionId,
          pairAttemptId: input.pairAttemptId,
          options,
          cancelSurfaces: cancelNativeMatchSurfaces,
        }).catch(() => {});
        return {
          ...result.response,
          status: VIDEO_SESSION_STATUS.CANCELLED,
          reason: "student_delivery_failed",
        };
      }
    } else if (routeOutcome !== "in_progress") {
      await advanceProtocolV2MatchStage({
        db,
        sessionId: input.sessionId,
        pairAttemptId: input.pairAttemptId,
        expectedStages: [MATCH_STAGE.AWAITING_STUDENT_DISPATCH],
        nextStage: MATCH_STAGE.AWAITING_ACCEPTANCE,
      });
    }
  }
  if (!result.shouldFinalize) return result.response;

  try {
    await acceptCallCallable({
      sessionId: input.sessionId,
      pairAttemptId: input.pairAttemptId,
    }, context, {
      responderId: result.responderId,
      protocolV2Finalization: true,
    });
    return {
      ...result.response,
      status: VIDEO_SESSION_STATUS.CONNECTING,
      reason: "all_participants_accepted",
    };
  } catch (error) {
    console.warn("Protocol v2 finalization deferred", {
      sessionId: input.sessionId,
      pairAttemptId: input.pairAttemptId,
      error: normalizeString(error?.message) || "finalization_deferred",
    });
    return {
      ...result.response,
      reason: "finalization_in_progress",
    };
  }
}

exports.respondToMatch = functions
  .runWith({secrets: [...apnsSecrets, ...dailySecrets]})
  .https.onCall(respondToMatchCallable);

exports.__private__ = {
  RESPONDABLE_STATUSES,
  buildDeclineReleaseOptions,
  buildLateTerminalSearchSuppression,
  buildRespondToMatchResponse,
  cancelNativeMatchSurfaces,
  normalizeRespondToMatchInput,
  isMatchTimeoutReached,
  readAssignedResponderId,
  readResponseDeadlineMillis,
  resumeRestoredStudentSearch,
  respondToMatchCallable,
};
