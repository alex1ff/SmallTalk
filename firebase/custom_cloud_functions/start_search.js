const {operationId} = require("./passive_search_policy");
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "start_search"});
const {
  usageDocRef,
} = require("./subscription_usage_shared");
const {
  trialAccessRef,
} = require("./trial_access");
const {
  getReadOnlyUserVoipTokenState,
} = require("./voip_tokens");
const {
  buildStartSearchAccessDecision,
  normalizeStartSearchInput,
  throwAccessDecision,
} = require("./start_search_entry_policy");
const {
  buildStudentPairResponderCallData,
  buildStudentPairResponderFcmMessage,
  buildStudentPairResponderPushPayload,
  classifyApnsDeliveryFailure,
  runBackgroundStudentResponderPushSender,
  sendVoipPushToStudentResponder,
} = require("./start_search_push_transport");
const {
  isSupportedSessionRole,
  normalizeRole,
} = require("./video_sessions_shared");
const {
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_STATUS,
} = require("./search_requests");
const {
  buildCurrentMatchedStartSearchResponse,
  buildMatchedStartSearchResponse,
  buildReusedSearchRequestRefresh,
  buildStartSearchFailureUpdate,
  buildStartSearchFilters,
  buildStartSearchRequestData,
  buildStartSearchResponse,
  canAttemptStudentPairForSearchRequest,
  canReuseSearchRequestForUser,
  hasCurrentMatchedSession,
  hasSearchRequestSessionBinding,
  isReusableSearchRequest,
  searchRequestBelongsToUser,
  shouldFailUnboundStartSearchRequest,
  timestampToMillis,
} = require("./start_search_request_policy");
const {
  isFreshBackgroundSearchRequest,
  isSessionResponseWindowOpen,
  isStudentResponderSession,
  isTeacherResponderSession,
  readSessionResponseDeadlineMillis,
  searchRequestBelongsToResponder,
  searchRequestMatchesSession,
  shouldCreateBackgroundStudentResponderIncomingCall,
  shouldCreateTeacherResponderIncomingCall,
  shouldRetryBackgroundStudentMatchAfterNotifyResult,
  shouldRetryTeacherMatchAfterNotifyResult,
  shouldUseTeacherResponderForIncomingCall,
} = require("./start_search_responder_policy");
const {
  buildStudentPairRequesterInfo,
  cancelBackgroundStudentResponderNotification,
  cancelTeacherResponderNotification,
  createTeacherResponderIncomingCall,
  recordBackgroundStudentResponderPushFailure,
  recordBackgroundStudentResponderPushSuccess,
  recordTeacherResponderPushResult,
  teacherResponderPushStillCurrent,
} = require("./start_search_notification_store");
const {
  maybeNotifyBackgroundStudentResponder,
  maybeNotifyTeacherResponder,
  readProtocolV2PostRouteOutcome,
  routeProtocolV2InitialMatch,
  shouldRouteProtocolV2InitialMatch,
  waitForForegroundStudentResponderResolution,
} = require("./start_search_delivery");
const {
  completeProtocolV2MatchRecovery,
  failUnboundStartSearchRequestForError,
  releaseBackgroundStudentResponderMatchForRetry,
  releaseProtocolV2MatchAfterRouteFailure,
  releaseTeacherResponderMatchForRetry,
} = require("./start_search_recovery");
const {
  buildStudentPairSessionData,
  reconcileReleasedProtocolV2Match,
  resumeRestoredStudentSearch,
  tryCreateStudentPairForSearchRequest,
  tryReadCurrentMatchedStartSearchResponse,
} = require("./start_search_matcher");
const {
  isSearchCancellationIntentActive,
  searchCancellationIntentRef,
} = require("./search_cancellation_intents");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];

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

function isFirestoreIndexUnavailableError(error) {
  if (!error || typeof error !== "object") {
    return false;
  }

  const code = error.code;
  const normalizedCode = normalizeString(code);
  const message = readErrorMessage(error, "");
  const details = normalizeString(error.details);
  const combinedText = `${message} ${details}`.toLowerCase();
  const isFailedPrecondition =
    code === 9 ||
    normalizedCode === "9" ||
    normalizedCode === "failed-precondition";

  return isFailedPrecondition &&
    combinedText.includes("requires an index");
}


























async function startSearchCallable(data, context, options = {}) {
  const callableOptions =
    options && typeof options === "object" ? options : {};
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  const input = normalizeStartSearchInput(data);
  const db = callableOptions.db || admin.firestore();
  const userId = context.auth.uid;
  const userRef = db.collection("users").doc(userId);
  const searchRequestRef = db
    .collection(SEARCH_REQUEST_COLLECTION)
    .doc(userId);
  const usageRef = usageDocRef(db, userId);
  const trialRef = trialAccessRef(db, userId);
  const requestId = input.requestId ||
    db.collection(SEARCH_REQUEST_COLLECTION).doc().id;
  const cancellationIntentRef = searchCancellationIntentRef(
    db,
    userId,
    requestId,
  );
  const attemptRef = db.collection("activeSearchAttempts").doc(operationId(userId, requestId));
  const nowMillis = Date.now();
  const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();

  const startResult = await db.runTransaction(async (transaction) => {
    const [requesterSnapshot, cancellationIntentSnap, trialSnapshot] =
      await Promise.all([
      transaction.get(userRef),
      cancellationIntentRef ? transaction.get(cancellationIntentRef) : null,
      transaction.get(trialRef),
    ]);
    if (!requesterSnapshot.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Requester not found",
      );
    }

    const attemptSnapshot = await transaction.get(attemptRef);
    const usageSnapshot = await transaction.get(usageRef);
    const searchRequestSnapshot = await transaction.get(searchRequestRef);
    const passiveRef = db.collection("passiveSearches").doc(userId);
    const passiveSnapshot = await transaction.get(passiveRef);
    const requesterData = requesterSnapshot.data() || {};
    const requesterRole = normalizeRole(requesterData.role);
    if (!isSupportedSessionRole(requesterRole)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "This user role cannot start search",
        {reason: "unsupported_role"},
      );
    }

    const existingRequestData = searchRequestSnapshot.exists ?
      searchRequestSnapshot.data() || {} :
      null;
    if (attemptSnapshot.exists && existingRequestData?.requestId !== requestId) {
      const closedRequest = {...attemptSnapshot.data(), status: SEARCH_REQUEST_STATUS.EXPIRED};
      return {response: buildStartSearchResponse({userId, requestData: closedRequest, reused: true}),
        requestData: closedRequest, requesterData, reused: true, shouldTryStudentPair: false};
    }
    const cancellationIntentData = cancellationIntentSnap?.exists ?
      cancellationIntentSnap.data() || {} :
      {};
    if (isSearchCancellationIntentActive({
      intentData: cancellationIntentData,
      userId,
      requestId,
      nowMillis,
    })) {
      transaction.set(cancellationIntentRef, {
        ...cancellationIntentData,
        status: "consumed",
        consumedAt: serverTimestamp,
        updatedAt: serverTimestamp,
      }, {merge: true});
      const stoppedRequestData = {
        requestId,
        status: SEARCH_REQUEST_STATUS.STOPPED,
      };
      return {
        response: buildStartSearchResponse({
          userId,
          requestData: stoppedRequestData,
          reused: true,
        }),
        requestData: stoppedRequestData,
        requesterData,
        reused: true,
        shouldTryStudentPair: false,
      };
    }
    // Retrying the same completed operation cannot create a fresh deadline.
    if (existingRequestData && input.requestId === existingRequestData.requestId &&
        !canReuseSearchRequestForUser({requestData: existingRequestData, userId, nowMillis})) {
      return {response: buildStartSearchResponse({userId,
        requestData: existingRequestData, reused: true}),
      requestData: existingRequestData, requesterData, reused: true,
      shouldTryStudentPair: false};
    }
    const accessDecision = buildStartSearchAccessDecision({
      requesterRole,
      requesterData,
      trialData: trialSnapshot.exists ? trialSnapshot.data() || {} : null,
      usageData: usageSnapshot.exists ? usageSnapshot.data() : null,
      nowMillis,
    });

    if (
      existingRequestData &&
      canReuseSearchRequestForUser({
        requestData: existingRequestData,
        userId,
        nowMillis,
      })
    ) {
      if (
        input.requestId &&
        normalizeString(existingRequestData.requestId) !== input.requestId
      ) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Another search request is already active",
          {
            reason: "search_already_active",
            requestId: normalizeString(existingRequestData.requestId),
          },
        );
      }
      const preserveMatchBinding = hasCurrentMatchedSession(
        existingRequestData,
      );
      const refreshedRequestData = buildReusedSearchRequestRefresh({
        requestData: existingRequestData,
        input,
        nowMillis,
        serverTimestamp,
        preserveMatchBinding,
      });
      if (!preserveMatchBinding) refreshedRequestData.passiveBroadcastReady = false;
      transaction.update(searchRequestRef, refreshedRequestData);
      const response = preserveMatchBinding ?
        buildCurrentMatchedStartSearchResponse({
          userId,
          requestData: refreshedRequestData,
          reused: true,
        }) :
        buildStartSearchResponse({
          userId,
          requestData: refreshedRequestData,
          reused: true,
        });

      return {
        response,
        requestData: refreshedRequestData,
        requesterData,
        reused: true,
        shouldTryStudentPair:
          accessDecision.allowed &&
          canAttemptStudentPairForSearchRequest(refreshedRequestData),
      };
    }

    throwAccessDecision(accessDecision);

    const nextRequestData = buildStartSearchRequestData({
      userId,
      userRef,
      requestId,
      requesterData,
      input,
      nowMillis,
      serverTimestamp,
    });
    nextRequestData.passiveBroadcastReady = false;
    const passive = passiveSnapshot.data() || {};
    if (passive.status === "waiting") {
      const stopped = {status: "stopped", stopReason: "active_search_started",
        updatedAt: serverTimestamp};
      transaction.set(passiveRef, stopped, {merge: true});
      transaction.set(db.collection("passiveSearchOperations")
        .doc(operationId(userId, passive.requestId)), stopped, {merge: true});
    }
    transaction.set(attemptRef, {userId, requestId,
      createdAt: nextRequestData.createdAt, expiresAt: nextRequestData.expiresAt});
    transaction.set(searchRequestRef, nextRequestData);

    return {
      response: buildStartSearchResponse({
        userId,
        requestData: nextRequestData,
        reused: false,
      }),
      requestData: nextRequestData,
      requesterData,
      reused: false,
      shouldTryStudentPair: true,
    };
  });

  if (startResult.shouldTryStudentPair) {
    let matchResult;
    try {
      matchResult = await tryCreateStudentPairForSearchRequest({
        db,
        userId,
        requesterData: startResult.requesterData,
        requestData: startResult.requestData,
        reused: startResult.reused,
        teacherResponderPushSender:
          callableOptions.teacherResponderPushSender ||
            sendVoipPushToStudentResponder,
        backgroundStudentResponderPushSender:
          callableOptions.backgroundStudentResponderPushSender ||
            sendVoipPushToStudentResponder,
        teacherResponderTokenReader:
          callableOptions.teacherResponderTokenReader ||
            getReadOnlyUserVoipTokenState,
      });
    } catch (error) {
      const requestIdForFailure = normalizeString(
        startResult.requestData?.requestId,
      );
      if (isFirestoreIndexUnavailableError(error)) {
        safeLog.warn("start_search_index_unavailable", {
          userId,
          requestId: requestIdForFailure,
          error,
        });
        return startResult.response;
      }

      safeLog.error("start_search_matching_failed", {
        userId,
        requestId: requestIdForFailure,
        error,
      });
      try {
        await failUnboundStartSearchRequestForError({
          db,
          userId,
          requestId: requestIdForFailure,
          error,
        });
      } catch (cleanupError) {
        safeLog.error("start_search_failure_cleanup_failed", {
          userId,
          requestId: requestIdForFailure,
          error: cleanupError,
        });
      }
      throw error;
    }
    if (matchResult.matched) {
      return matchResult.response;
    }
    if (matchResult.response) {
      startResult.response = matchResult.response;
    }
  }

  if (startResult.requestData.status === SEARCH_REQUEST_STATUS.ACTIVE) {
    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(searchRequestRef);
      const request = current.data() || {};
      if (request.requestId === startResult.requestData.requestId &&
          request.status === SEARCH_REQUEST_STATUS.ACTIVE &&
          !hasCurrentMatchedSession(request)) {
        transaction.update(searchRequestRef, {passiveBroadcastReady: true});
      }
    });
  }
  return startResult.response;
}

exports.startSearch = functions
  .runWith({secrets: apnsSecrets})
  .https.onCall(startSearchCallable);

exports.__private__ = {
  buildStudentPairRequesterInfo,
  buildStudentPairResponderCallData,
  buildStudentPairResponderFcmMessage,
  buildStudentPairResponderPushPayload,
  buildStartSearchAccessDecision,
  buildStartSearchFailureUpdate,
  buildStartSearchFilters,
  buildReusedSearchRequestRefresh,
  buildCurrentMatchedStartSearchResponse,
  buildMatchedStartSearchResponse,
  buildStartSearchRequestData,
  buildStartSearchResponse,
  buildStudentPairSessionData,
  canAttemptStudentPairForSearchRequest,
  completeProtocolV2MatchRecovery,
  cancelBackgroundStudentResponderNotification,
  cancelTeacherResponderNotification,
  classifyApnsDeliveryFailure,
  createTeacherResponderIncomingCall,
  failUnboundStartSearchRequestForError,
  recordBackgroundStudentResponderPushFailure,
  recordBackgroundStudentResponderPushSuccess,
  reconcileReleasedProtocolV2Match,
  releaseBackgroundStudentResponderMatchForRetry,
  releaseProtocolV2MatchAfterRouteFailure,
  recordTeacherResponderPushResult,
  releaseTeacherResponderMatchForRetry,
  readErrorMessage,
  readSessionResponseDeadlineMillis,
  readProtocolV2PostRouteOutcome,
  runBackgroundStudentResponderPushSender,
  routeProtocolV2InitialMatch,
  resumeRestoredStudentSearch,
  sendVoipPushToStudentResponder,
  startSearchCallable,
  isFirestoreIndexUnavailableError,
  isFreshBackgroundSearchRequest,
  isSessionResponseWindowOpen,
  isStudentResponderSession,
  isTeacherResponderSession,
  hasCurrentMatchedSession,
  hasSearchRequestSessionBinding,
  maybeNotifyBackgroundStudentResponder,
  maybeNotifyTeacherResponder,
  searchRequestMatchesSession,
  searchRequestBelongsToResponder,
  shouldUseTeacherResponderForIncomingCall,
  teacherResponderPushStillCurrent,
  canReuseSearchRequestForUser,
  isReusableSearchRequest,
  normalizeStartSearchInput,
  searchRequestBelongsToUser,
  shouldCreateBackgroundStudentResponderIncomingCall,
  shouldCreateTeacherResponderIncomingCall,
  shouldFailUnboundStartSearchRequest,
  shouldRetryBackgroundStudentMatchAfterNotifyResult,
  shouldRetryTeacherMatchAfterNotifyResult,
  shouldRouteProtocolV2InitialMatch,
  timestampToMillis,
  tryReadCurrentMatchedStartSearchResponse,
  tryCreateStudentPairForSearchRequest,
  waitForForegroundStudentResponderResolution,
};
