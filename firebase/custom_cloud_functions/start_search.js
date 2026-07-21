const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { evaluateTutorAvailabilityWindow } = require("./availability");
const { sendApnsVoip } = require("./apns_voip");
const { hasActiveAcceptLockForResponder } = require("./accept_lock_policy");
const {
  cancelProtocolV2NotificationsInTransaction,
  createIncomingCallNotificationInTransaction,
} = require("./call_notifications");
const {
  usageDocRef,
} = require("./subscription_usage_shared");
const {
  buildReadOnlyVoipTokenState,
  getReadOnlyUserVoipTokenState,
  getUserVoipTokens,
} = require("./voip_tokens");
const {
  buildStudentCallAccessDecision,
} = require("./call_access");
const {
  buildMatchProfile,
  buildInitialSessionPolicyState,
  isSupportedSessionRole,
  normalizeRole,
  readCountryCode,
  readLevelValue,
  resolveActiveConversationLanguage,
  supportsConversationLanguage,
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  SEARCH_REQUEST_ACTIVE_STATUSES,
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_FIELD,
  SEARCH_REQUEST_STATUS,
  SEARCH_REQUEST_TIMING,
  buildInitialSearchRequestData,
  normalizeAppState,
  normalizeSearchRequestFilters,
} = require("./search_requests");
const {
  MATCH_CANDIDATE_SOURCE,
  collectMatchCandidatePool,
} = require("./match_candidate_pool");
const {
  releaseSessionPairLocksInTransaction,
  reserveMatchPair,
} = require("./match_pair_lock");
const {
  MATCH_DECISION,
  MATCH_DELIVERY,
  MATCH_PROTOCOL_VERSION,
  MATCH_STAGE,
  normalizeParticipantState,
  supportsMatchProtocolV2,
} = require("./match_protocol_v2");
const {
  advanceProtocolV2MatchStage,
  cancelProtocolV2NativeSurfaces,
  classifyProtocolV2RouteResult,
  routeProtocolV2Participant,
  waitForForegroundMatchClaim,
} = require("./match_delivery_v2");
const {
  reconcileProtocolV2TerminalSideEffects,
} = require("./match_recovery_v2");
const {
  isSearchCancellationIntentActive,
  normalizeSearchLifecycleRequestId,
  searchCancellationIntentRef,
} = require("./search_cancellation_intents");

const STUDENT_REVIEW_FLAG_FIELD = "studentHasReviewed";
const TUTOR_REVIEW_FLAG_FIELD = "tutorHasReviewed";
const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const BACKGROUND_STUDENT_RESPONDER_PUSH_TIMEOUT_MS = 3 * 1000;
const BACKGROUND_STUDENT_RESPONDER_APNS_TIMEOUT_MS = 2 * 1000;

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

function classifyApnsDeliveryFailure(error) {
  const message = readErrorMessage(error, "").toLowerCase();
  return [
    "baddevicetoken",
    "unregistered",
    "devicetokennotfortopic",
  ].some((reason) => message.includes(reason)) ?
    "definitive" :
    "unknown";
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

function throwIfAborted(signal) {
  if (!signal?.aborted) {
    return;
  }
  if (signal.reason instanceof Error) {
    throw signal.reason;
  }
  throw new Error("push_aborted");
}

function waitForAbortable(promise, signal) {
  if (!signal) {
    return promise;
  }
  throwIfAborted(signal);
  return new Promise((resolve, reject) => {
    const abort = () => {
      reject(signal.reason instanceof Error ?
        signal.reason :
        new Error("push_aborted"));
    };
    signal.addEventListener?.("abort", abort, {once: true});
    Promise.resolve(promise).then(
      (value) => {
        signal.removeEventListener?.("abort", abort);
        resolve(value);
      },
      (error) => {
        signal.removeEventListener?.("abort", abort);
        reject(error);
      },
    );
  });
}

function buildChildAbortController({
  parentSignal = null,
  timeoutMs = 0,
  timeoutError = new Error("operation_timeout"),
} = {}) {
  const controller = new AbortController();
  let timeout = null;
  const abortFromParent = () => {
    controller.abort(parentSignal?.reason instanceof Error ?
      parentSignal.reason :
      new Error("push_aborted"));
  };
  if (parentSignal?.aborted) {
    abortFromParent();
  } else {
    parentSignal?.addEventListener?.("abort", abortFromParent, {once: true});
  }
  if (Number.isFinite(timeoutMs) && timeoutMs > 0) {
    timeout = setTimeout(() => {
      controller.abort(timeoutError);
    }, timeoutMs);
  }
  return {
    signal: controller.signal,
    cleanup: () => {
      if (timeout) {
        clearTimeout(timeout);
      }
      parentSignal?.removeEventListener?.("abort", abortFromParent);
    },
  };
}

function calculateApnsFallbackTimeoutMs(totalTimeoutMs) {
  if (!Number.isFinite(totalTimeoutMs) || totalTimeoutMs <= 1) {
    return BACKGROUND_STUDENT_RESPONDER_APNS_TIMEOUT_MS;
  }
  return Math.max(
    1,
    Math.min(
      BACKGROUND_STUDENT_RESPONDER_APNS_TIMEOUT_MS,
      Math.floor(totalTimeoutMs * 0.7),
    ),
  );
}

function waitForForegroundStudentResponderResolution(options = {}) {
  return waitForForegroundMatchClaim(options);
}

function readCallableData(data) {
  return data && typeof data === "object" && !Array.isArray(data) ? data : {};
}

function readNestedObject(value) {
  return value && typeof value === "object" && !Array.isArray(value) ?
    value :
    {};
}

function readCityKey(value) {
  if (!value) {
    return "";
  }

  if (typeof value === "string") {
    return normalizeString(value);
  }

  if (typeof value === "object") {
    return normalizeString(value.key || value.cityKey || value.value || "");
  }

  return "";
}

function hasDirectCallTarget(payload = {}) {
  return [
    payload.directTutorId,
    payload.directUserId,
    payload.targetUserId,
    payload.targetTutorId,
    payload.teacherId,
    payload.tutorId,
  ].some((value) => normalizeString(value));
}

function normalizeStartSearchInput(data) {
  const payload = readCallableData(data);
  if (hasDirectCallTarget(payload)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Direct calls must use direct-call endpoints",
      {reason: "direct_call_not_supported"},
    );
  }

  const filters = readNestedObject(payload.filters);
  const rawRequestId = payload.requestId;
  const requestId = rawRequestId == null ?
    "" :
    normalizeSearchLifecycleRequestId(rawRequestId);
  if (rawRequestId != null && !requestId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "requestId is invalid",
    );
  }
  return {
    requestId,
    language: normalizeString(payload.language || payload.languageCode),
    preferredPartnerLevel: normalizeString(
      payload.preferredPartnerLevel ||
        payload.preferredLevel ||
        filters.preferredLevel ||
        filters.level,
    ),
    preferredCountry: normalizeString(
      payload.preferredCountry ||
        payload.countryCode ||
        filters.countryCode,
    ),
    cityKey: normalizeString(payload.cityKey || filters.cityKey),
    appState: normalizeAppState(payload.appState),
    platform: normalizeString(payload.platform),
    matchProtocolVersion: supportsMatchProtocolV2(
      payload.matchProtocolVersion,
    ) ? MATCH_PROTOCOL_VERSION : 1,
  };
}

function buildStartSearchAccessDecision({
  requesterRole,
  requesterData = {},
  usageData = null,
  nowMillis = Date.now(),
}) {
  return buildStudentCallAccessDecision({
    userRole: requesterRole,
    userData: requesterData,
    usageData,
    nowMillis,
  });
}

function throwAccessDecision(decision) {
  if (decision.allowed) {
    return;
  }

  throw new functions.https.HttpsError(
    decision.code,
    decision.message,
    {reason: decision.reason},
  );
}

function buildStartSearchFilters({
  input = {},
}) {
  return normalizeSearchRequestFilters({
    preferredLevel: input.preferredPartnerLevel,
    countryCode: input.preferredCountry,
    cityKey: input.cityKey,
  });
}

function timestampToMillis(value) {
  if (!value) {
    return null;
  }
  if (typeof value.toMillis === "function") {
    const millis = Number(value.toMillis());
    return Number.isFinite(millis) ? millis : null;
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  const millis = Number(value);
  return Number.isFinite(millis) ? millis : null;
}

function timestampToIsoString(value) {
  const millis = timestampToMillis(value);
  return millis === null ? null : new Date(millis).toISOString();
}

function readReferenceId(value) {
  return value && typeof value.id === "string" ? value.id.trim() : "";
}

function searchRequestBelongsToUser(requestData = {}, userId) {
  const normalizedUserId = normalizeString(userId);
  const explicitUserIds = [
    requestData.userId,
    requestData.studentId,
    requestData.requesterId,
  ].map(normalizeString).filter(Boolean);
  const referencedUserIds = [
    requestData.userRef,
    requestData.studentRef,
    requestData.requesterRef,
  ].map(readReferenceId).filter(Boolean);
  const ownerIds = [...explicitUserIds, ...referencedUserIds];

  return ownerIds.length === 0 ||
    ownerIds.every((ownerId) => ownerId === normalizedUserId);
}

function isReusableSearchRequest(requestData = {}, nowMillis = Date.now()) {
  const status = normalizeString(requestData.status);
  if (!SEARCH_REQUEST_ACTIVE_STATUSES.includes(status)) {
    return false;
  }

  const expiresAtMillis = timestampToMillis(requestData.expiresAt);
  if (expiresAtMillis === null || expiresAtMillis <= nowMillis) {
    return false;
  }

  if (status === SEARCH_REQUEST_STATUS.MATCHED) {
    return true;
  }

  const heartbeatAtMillis = timestampToMillis(requestData.heartbeatAt);
  const staleCutoffMillis =
    nowMillis - SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS * 1000;
  if (heartbeatAtMillis === null || heartbeatAtMillis < staleCutoffMillis) {
    return false;
  }

  const isBackgroundSearch =
    normalizeAppState(requestData.appState) ===
      SEARCH_REQUEST_APP_STATE.BACKGROUND;
  const backgroundExpiresAtMillis = timestampToMillis(
    requestData.backgroundExpiresAt,
  );
  if (
    isBackgroundSearch &&
    backgroundExpiresAtMillis !== null &&
    backgroundExpiresAtMillis <= nowMillis
  ) {
    return false;
  }
  if (
    isBackgroundSearch &&
    backgroundExpiresAtMillis !== null &&
    backgroundExpiresAtMillis > nowMillis
  ) {
    return true;
  }

  return true;
}

function canReuseSearchRequestForUser({
  requestData = {},
  userId,
  nowMillis = Date.now(),
}) {
  return searchRequestBelongsToUser(requestData, userId) &&
    isReusableSearchRequest(requestData, nowMillis);
}

function buildStartSearchResponse({
  userId,
  requestData = {},
  reused = false,
}) {
  return {
    status: normalizeString(requestData.status) || "active",
    searchRequestId: userId,
    requestId: normalizeString(requestData.requestId) || null,
    sessionId:
      normalizeString(requestData.currentSessionId) ||
      normalizeString(requestData.activeSessionId) ||
      normalizeString(requestData.matchedSessionId) ||
      null,
    pairAttemptId: normalizeString(requestData.pairAttemptId) || null,
    expiresAt: timestampToIsoString(requestData.expiresAt),
    errorCode: null,
    reused,
    ...(Number(requestData.matchProtocolVersion) >= MATCH_PROTOCOL_VERSION ? {
      matchProtocolVersion: MATCH_PROTOCOL_VERSION,
    } : {}),
  };
}

function canAttemptStudentPairForSearchRequest(requestData = {}) {
  return [
    SEARCH_REQUEST_STATUS.ACTIVE,
  ].includes(normalizeString(requestData.status));
}

function buildMatchedStartSearchResponse({
  userId,
  requestData = {},
  matchResult = {},
  reused = false,
}) {
  const matchedRole = normalizeRole(matchResult.responderRole);
  const scenario = matchedRole === "student" ?
    "student_student" :
    (matchedRole === "native_speaker" ? "student_teacher" : null);
  return {
    ...buildStartSearchResponse({
      userId,
      requestData: {
        ...requestData,
        status: SEARCH_REQUEST_STATUS.MATCHED,
        currentSessionId: matchResult.sessionId,
        matchedSessionId: matchResult.sessionId,
        pairAttemptId: matchResult.pairAttemptId,
      },
      reused,
    }),
    matchedUserId: normalizeString(matchResult.responderId) || null,
    matchedRole: matchedRole || null,
    scenario,
  };
}

function buildCurrentMatchedStartSearchResponse({
  userId,
  requestData = {},
  reused = false,
}) {
  const matchedRole = normalizeRole(requestData.matchedRole);
  const scenario = matchedRole === "student" ?
    "student_student" :
    (matchedRole === "native_speaker" ?
      "student_teacher" :
      null);
  return {
    ...buildStartSearchResponse({
      userId,
      requestData,
      reused,
    }),
    matchedUserId:
      normalizeString(requestData.matchedUserId) ||
      normalizeString(requestData.matchedResponderId) ||
      null,
    matchedRole: matchedRole || null,
    scenario,
  };
}

function hasCurrentMatchedSession(requestData = {}) {
  return normalizeString(requestData.status) ===
      SEARCH_REQUEST_STATUS.MATCHED &&
    Boolean(
      normalizeString(requestData.currentSessionId) ||
      normalizeString(requestData.matchedSessionId) ||
      normalizeString(requestData.activeSessionId),
    );
}

function hasSearchRequestSessionBinding(requestData = {}) {
  return Boolean(
    normalizeString(requestData.currentSessionId) ||
    normalizeString(requestData.activeSessionId) ||
    normalizeString(requestData.matchedSessionId),
  );
}

function buildStartSearchFailureUpdate({
  error,
  serverTimestamp,
  fieldDelete,
}) {
  const message = readErrorMessage(error, "start_search_failed");
  return {
    status: SEARCH_REQUEST_STATUS.ERROR,
    stopReason: "start_search_failed",
    stoppedAt: serverTimestamp,
    updatedAt: serverTimestamp,
    currentSessionId: null,
    matchedUserId: null,
    matchedRole: null,
    pairAttemptId: null,
    attemptExcludedCandidateIds: [],
    lockOwner: null,
    lockExpiresAt: null,
    lastError: {
      code: "start_search_failed",
      message,
    },
    errorCode: "start_search_failed",
    errorMessage: message,
    activeSessionId: fieldDelete,
    matchedSessionId: fieldDelete,
    matchedResponderId: fieldDelete,
  };
}

function shouldFailUnboundStartSearchRequest({
  requestData = {},
  userId,
  requestId,
}) {
  if (!searchRequestBelongsToUser(requestData, userId)) {
    return false;
  }
  if (normalizeString(requestData.requestId) !== normalizeString(requestId)) {
    return false;
  }
  if (hasSearchRequestSessionBinding(requestData)) {
    return false;
  }
  return [
    SEARCH_REQUEST_STATUS.ACTIVE,
    SEARCH_REQUEST_STATUS.MATCHING,
    SEARCH_REQUEST_STATUS.LEGACY_SEARCHING,
  ].includes(normalizeString(requestData.status));
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

async function tryReadCurrentMatchedStartSearchResponse({
  db,
  userId,
  reused = false,
}) {
  const searchRequestSnapshot = await db
    .collection(SEARCH_REQUEST_COLLECTION)
    .doc(userId)
    .get();
  const requestData = searchRequestSnapshot.exists ?
    searchRequestSnapshot.data() || {} :
    {};

  if (
    !searchRequestSnapshot.exists ||
    !searchRequestBelongsToUser(requestData, userId) ||
    !hasCurrentMatchedSession(requestData)
  ) {
    return null;
  }

  return buildCurrentMatchedStartSearchResponse({
    userId,
    requestData,
    reused,
  });
}

function buildStudentPairSessionData({
  requesterId = "",
  requestData = {},
  selectedCandidate = {},
  studentCandidates = [],
  matchCandidates = studentCandidates,
  candidateStats = {},
  nowMillis = Date.now(),
  timestampFromDate = admin.firestore.Timestamp.fromDate,
}) {
  const candidateIds = matchCandidates
    .map((candidate) => normalizeString(candidate.userId))
    .filter(Boolean);
  const selectedResponderId = normalizeString(selectedCandidate.userId);
  const selectedResponderRole =
    normalizeRole(selectedCandidate.role) || "student";
  const sessionPolicyState = buildInitialSessionPolicyState(nowMillis);
  return {
    matchProtocolVersion:
      Number(requestData.matchProtocolVersion) >= MATCH_PROTOCOL_VERSION ?
        MATCH_PROTOCOL_VERSION :
        1,
    language: normalizeString(requestData.language),
    expiresAt: timestampFromDate(sessionPolicyState.expiresAt),
    sessionPolicy: sessionPolicyState.sessionPolicy,
    [STUDENT_REVIEW_FLAG_FIELD]: false,
    [TUTOR_REVIEW_FLAG_FIELD]: false,
    availableTutors: candidateIds,
    triedTutors: selectedResponderId ? [selectedResponderId] : [],
    matchContext: {
      requesterId,
      requesterRole: "student",
      requestedLanguage: normalizeString(requestData.language),
      filters: readNestedObject(requestData.filters),
      matcher: "startSearch",
      candidatePoolSize: candidateIds.length,
      candidateIds,
      candidateStats,
      selectedResponderId,
      selectedResponderRole,
      selectedResponderSource:
        normalizeString(selectedCandidate.source) || null,
      selectedResponderSearchRequestId:
        normalizeString(selectedCandidate.searchRequestId) || null,
    },
  };
}

function buildStudentPairResponderCallData({
  sessionId = "",
  pushPayload = {},
} = {}) {
  return {
    sessionId: normalizeString(sessionId),
    callerName: normalizeString(pushPayload.studentName) || "Student",
    callerId: normalizeString(pushPayload.studentId),
    callerPhoto: normalizeString(pushPayload.studentPhoto),
    language: normalizeString(pushPayload.language),
    scenario: normalizeString(pushPayload.scenario),
    recipientId:
      normalizeString(pushPayload.recipientId) ||
      normalizeString(pushPayload.responderId),
    requesterId: normalizeString(pushPayload.requesterId),
    responderId: normalizeString(pushPayload.responderId),
    requesterRole: normalizeString(pushPayload.requesterRole),
    responderRole: normalizeString(pushPayload.responderRole),
    navRole: normalizeString(pushPayload.navRole) || "student",
    acceptMode:
      normalizeString(pushPayload.acceptMode) || "responder_accepts",
    callKitId: normalizeString(pushPayload.callKitId),
    notificationId: normalizeString(pushPayload.notificationId),
    searchRequestId: normalizeString(pushPayload.searchRequestId),
    expiresAt: normalizeString(pushPayload.expiresAt),
    roomUrl: "",
    roomName: normalizeString(pushPayload.roomName),
    tokenStrategy: normalizeString(pushPayload.tokenStrategy) || "accept_call",
    ...(normalizeString(pushPayload.matchProtocolVersion) === "2" ? {
      matchProtocolVersion: "2",
      pairAttemptId: normalizeString(pushPayload.pairAttemptId),
      surface: normalizeString(pushPayload.surface) || "callkit",
    } : {}),
  };
}

function buildStudentPairResponderPushPayload(callData = {}) {
  return {
    type: "incoming_call",
    sessionId: normalizeString(callData.sessionId),
    callerName: normalizeString(callData.callerName) || "Student",
    callerId: normalizeString(callData.callerId),
    callerPhoto: normalizeString(callData.callerPhoto),
    language: normalizeString(callData.language),
    scenario: normalizeString(callData.scenario),
    recipientId:
      normalizeString(callData.recipientId) ||
      normalizeString(callData.responderId),
    requesterId: normalizeString(callData.requesterId),
    responderId: normalizeString(callData.responderId),
    requesterRole: normalizeString(callData.requesterRole),
    responderRole: normalizeString(callData.responderRole),
    navRole: normalizeString(callData.navRole) || "student",
    acceptMode:
      normalizeString(callData.acceptMode) || "responder_accepts",
    callKitId: normalizeString(callData.callKitId),
    notificationId: normalizeString(callData.notificationId),
    searchRequestId: normalizeString(callData.searchRequestId),
    expiresAt: normalizeString(callData.expiresAt),
    roomUrl: "",
    roomName: normalizeString(callData.roomName),
    tokenStrategy: normalizeString(callData.tokenStrategy) || "accept_call",
    ...(normalizeString(callData.matchProtocolVersion) === "2" ? {
      matchProtocolVersion: "2",
      pairAttemptId: normalizeString(callData.pairAttemptId),
      surface: normalizeString(callData.surface) || "callkit",
    } : {}),
  };
}

function buildStudentPairResponderFcmMessage({
  fcmToken = "",
  payload = {},
  bundleId = "com.appwave.smalltalk",
} = {}) {
  return {
    token: normalizeString(fcmToken),
    data: payload,
    android: {
      priority: "high",
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
            body: `${payload.callerName} хочет попрактиковать ${payload.language}`,
          },
          sound: "default",
          badge: 1,
        },
      },
    },
  };
}

function isFreshBackgroundSearchRequest(
  requestData = {},
  nowMillis = Date.now(),
) {
  if (
    normalizeString(requestData[SEARCH_REQUEST_FIELD.STATUS]) !==
    SEARCH_REQUEST_STATUS.MATCHED
  ) {
    return false;
  }
  if (
    normalizeAppState(requestData[SEARCH_REQUEST_FIELD.APP_STATE]) !==
    SEARCH_REQUEST_APP_STATE.BACKGROUND
  ) {
    return false;
  }
  const backgroundExpiresAtMillis = timestampToMillis(
    requestData[SEARCH_REQUEST_FIELD.BACKGROUND_EXPIRES_AT],
  );
  return backgroundExpiresAtMillis !== null &&
    backgroundExpiresAtMillis > nowMillis;
}

function readSessionResponseDeadlineMillis(sessionData = {}) {
  const deadlines = [
    timestampToMillis(sessionData.responseExpiresAt),
    timestampToMillis(sessionData.confirmationExpiresAt),
  ].filter((deadline) => deadline !== null);
  return deadlines.length ? Math.min(...deadlines) : null;
}

function isSessionResponseWindowOpen(
  sessionData = {},
  nowMillis = Date.now(),
) {
  const responseDeadlineMillis = readSessionResponseDeadlineMillis(sessionData);
  return responseDeadlineMillis !== null &&
    responseDeadlineMillis > nowMillis;
}

function searchRequestMatchesSession(requestData = {}, sessionId = "") {
  const normalizedSessionId = normalizeString(sessionId);
  if (!normalizedSessionId) {
    return false;
  }
  const linkedSessionIds = [
    requestData[SEARCH_REQUEST_FIELD.CURRENT_SESSION_ID],
    requestData[SEARCH_REQUEST_FIELD.MATCHED_SESSION_ID],
    requestData[SEARCH_REQUEST_FIELD.ACTIVE_SESSION_ID],
  ].map(normalizeString).filter(Boolean);
  return linkedSessionIds.includes(normalizedSessionId);
}

function searchRequestBelongsToResponder(requestData = {}, responderId = "") {
  const normalizedResponderId = normalizeString(responderId);
  if (!normalizedResponderId) {
    return false;
  }
  const ownerIds = [
    requestData[SEARCH_REQUEST_FIELD.USER_ID],
    readReferenceId(requestData[SEARCH_REQUEST_FIELD.USER_REF]),
  ].map(normalizeString).filter(Boolean);
  return ownerIds.length > 0 &&
    ownerIds.every((ownerId) => ownerId === normalizedResponderId);
}

function isStudentResponderSession(sessionData = {}, responderId = "") {
  const normalizedResponderId = normalizeString(responderId);
  const participantRoles = readNestedObject(sessionData.participantRoles);
  const responderRoles = [
    sessionData.currentResponderRole,
    sessionData.responderRole,
    participantRoles[normalizedResponderId],
  ].map(normalizeRole);
  const scenario = normalizeString(sessionData.scenario);
  return responderRoles.every((role) => role === "student") &&
    scenario === "student_student";
}

function isTeacherResponderSession(sessionData = {}, responderId = "") {
  const normalizedResponderId = normalizeString(responderId);
  const participantRoles = readNestedObject(sessionData.participantRoles);
  const responderRoles = [
    sessionData.currentResponderRole,
    sessionData.responderRole,
    participantRoles[normalizedResponderId],
  ].map(normalizeRole);
  const scenario = normalizeString(sessionData.scenario);
  return responderRoles.every((role) => role === "native_speaker") &&
    scenario === "student_teacher";
}

function shouldCreateBackgroundStudentResponderIncomingCall({
  sessionData = {},
  sessionId = "",
  responderId = "",
  responderSearchRequestData = {},
  nowMillis = Date.now(),
}) {
  const normalizedResponderId = normalizeString(responderId);
  if (!normalizedResponderId) {
    return {shouldNotify: false, reason: "missing_responder"};
  }
  const sessionStatus = normalizeString(sessionData.status);
  if (
    sessionStatus === VIDEO_SESSION_STATUS.CONNECTING ||
    sessionStatus === VIDEO_SESSION_STATUS.ACTIVE
  ) {
    return {shouldNotify: false, reason: `session_${sessionStatus}`};
  }
  if (
    sessionStatus !== VIDEO_SESSION_STATUS.PENDING_CONFIRMATION
  ) {
    return {shouldNotify: false, reason: "session_not_pending"};
  }
  if (
    normalizeString(sessionData.currentResponderId) !==
      normalizedResponderId ||
    normalizeString(sessionData.currentTutorId) !== normalizedResponderId
  ) {
    return {shouldNotify: false, reason: "responder_mismatch"};
  }
  if (!isStudentResponderSession(sessionData, normalizedResponderId)) {
    return {shouldNotify: false, reason: "responder_not_student"};
  }
  if (!isSessionResponseWindowOpen(sessionData, nowMillis)) {
    return {shouldNotify: false, reason: "response_window_closed"};
  }
  if (
    hasActiveAcceptLockForResponder({
      sessionData,
      responderId: normalizedResponderId,
      nowMillis,
    })
  ) {
    return {shouldNotify: false, reason: "accept_in_progress"};
  }
  if (!isFreshBackgroundSearchRequest(responderSearchRequestData, nowMillis)) {
    return {shouldNotify: false, reason: "responder_not_background"};
  }
  if (
    !searchRequestBelongsToResponder(
      responderSearchRequestData,
      normalizedResponderId,
    )
  ) {
    return {shouldNotify: false, reason: "search_request_owner_mismatch"};
  }
  if (!searchRequestMatchesSession(responderSearchRequestData, sessionId)) {
    return {shouldNotify: false, reason: "search_request_session_mismatch"};
  }
  return {shouldNotify: true, reason: "background_responder"};
}

function shouldCreateTeacherResponderIncomingCall({
  sessionData = {},
  responderId = "",
  nowMillis = Date.now(),
}) {
  const normalizedResponderId = normalizeString(responderId);
  if (!normalizedResponderId) {
    return {shouldNotify: false, reason: "missing_responder"};
  }
  const sessionStatus = normalizeString(sessionData.status);
  if (
    sessionStatus === VIDEO_SESSION_STATUS.CONNECTING ||
    sessionStatus === VIDEO_SESSION_STATUS.ACTIVE
  ) {
    return {shouldNotify: false, reason: `session_${sessionStatus}`};
  }
  if (
    sessionStatus !== VIDEO_SESSION_STATUS.PENDING_CONFIRMATION
  ) {
    return {shouldNotify: false, reason: "session_not_pending"};
  }
  if (
    normalizeString(sessionData.currentResponderId) !==
      normalizedResponderId ||
    normalizeString(sessionData.currentTutorId) !== normalizedResponderId
  ) {
    return {shouldNotify: false, reason: "responder_mismatch"};
  }
  if (!isTeacherResponderSession(sessionData, normalizedResponderId)) {
    return {shouldNotify: false, reason: "responder_not_teacher"};
  }
  if (!isSessionResponseWindowOpen(sessionData, nowMillis)) {
    return {shouldNotify: false, reason: "response_window_closed"};
  }
  if (
    hasActiveAcceptLockForResponder({
      sessionData,
      responderId: normalizedResponderId,
      nowMillis,
    })
  ) {
    return {shouldNotify: false, reason: "accept_in_progress"};
  }
  return {shouldNotify: true, reason: "teacher_responder"};
}

function shouldLeaveBackgroundNotificationForAccept({
  decision = {},
  sessionData = {},
} = {}) {
  const status = normalizeString(sessionData.status);
  return decision.reason === "accept_in_progress" ||
    status === VIDEO_SESSION_STATUS.CONNECTING ||
    status === VIDEO_SESSION_STATUS.ACTIVE;
}

function isAvailableAfterInFuture(userData = {}, now = new Date()) {
  const availableAfter = userData.availableAfter;
  return Boolean(
    availableAfter &&
      typeof availableAfter.toDate === "function" &&
      availableAfter.toDate() > now,
  );
}

function shouldUseTeacherResponderForIncomingCall({
  teacherData = {},
  responderId = "",
  sessionId = "",
  sessionData = {},
  tokenState = {},
  now = new Date(),
}) {
  const normalizedResponderId = normalizeString(responderId);
  const normalizedSessionId =
    normalizeString(sessionId) || normalizeString(sessionData.sessionId);
  if (!normalizedResponderId) {
    return {valid: false, reason: "missing_responder"};
  }
  if (normalizeRole(teacherData.role) !== "native_speaker") {
    return {valid: false, reason: "teacher_role_mismatch"};
  }
  const currentSessionId = normalizeString(teacherData.currentSessionId);
  if (
    !normalizedSessionId ||
    currentSessionId !== normalizedSessionId
  ) {
    return {valid: false, reason: "teacher_session_mismatch"};
  }
  if (teacherData.isInCall === true) {
    return {valid: false, reason: "teacher_in_call"};
  }
  if (
    !buildMatchProfile(
      normalizedResponderId,
      teacherData,
      sessionData.language,
    ).approvedTeacher
  ) {
    return {valid: false, reason: "teacher_not_approved"};
  }
  if (!supportsConversationLanguage(teacherData, sessionData.language)) {
    return {valid: false, reason: "teacher_language_mismatch"};
  }
  if (isAvailableAfterInFuture(teacherData, now)) {
    return {valid: false, reason: "teacher_available_later"};
  }
  const availability = evaluateTutorAvailabilityWindow(teacherData, now);
  if (!availability.isAvailable) {
    return {
      valid: false,
      reason: `teacher_${availability.reason || "unavailable"}`,
    };
  }
  if (tokenState.hasUsableToken !== true) {
    return {valid: false, reason: "teacher_missing_tokens"};
  }
  return {valid: true, reason: "teacher_current"};
}

function buildStudentPairRequesterInfo(requesterData = {}) {
  return {
    name:
      normalizeString(requesterData.display_name) ||
      normalizeString(requesterData.displayName) ||
      "Student",
    photo:
      normalizeString(requesterData.photo_url) ||
      normalizeString(requesterData.photoUrl),
  };
}

async function createBackgroundStudentResponderIncomingCall({
  db,
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  requesterData = {},
  nowMillis = Date.now(),
}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const searchDocId =
    normalizeString(responderSearchRequestDocId) || normalizedResponderId;
  if (!normalizedSessionId || !normalizedResponderId || !searchDocId) {
    return {shouldNotify: false, reason: "missing_ids"};
  }

  return db.runTransaction(async (transaction) => {
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const responderSearchRef = db
      .collection(SEARCH_REQUEST_COLLECTION)
      .doc(searchDocId);
    const [sessionSnap, responderSearchSnap] = await Promise.all([
      transaction.get(sessionRef),
      transaction.get(responderSearchRef),
    ]);
    if (!sessionSnap.exists) {
      return {shouldNotify: false, reason: "session_missing"};
    }
    if (!responderSearchSnap.exists) {
      return {shouldNotify: false, reason: "responder_search_missing"};
    }

    const sessionData = sessionSnap.data() || {};
    const responderSearchRequestData = responderSearchSnap.data() || {};
    const decision = shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData,
      sessionId: normalizedSessionId,
      responderId: normalizedResponderId,
      responderSearchRequestData,
      nowMillis,
    });
    if (!decision.shouldNotify) {
      return decision;
    }

    const notification = createIncomingCallNotificationInTransaction({
      db,
      transaction,
      sessionId: normalizedSessionId,
      recipientId: normalizedResponderId,
      sessionData,
      studentInfo: buildStudentPairRequesterInfo(requesterData),
      studentNameFallback: "Student",
      now: new Date(nowMillis),
    });

    return {
      shouldNotify: true,
      reason: decision.reason,
      notificationId: notification.notificationId,
      pushPayload: notification.pushPayload,
    };
  });
}

async function createTeacherResponderIncomingCall({
  db,
  sessionId = "",
  responderId = "",
  requesterData = {},
  nowMillis = Date.now(),
}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  if (!normalizedSessionId || !normalizedResponderId) {
    return {shouldNotify: false, reason: "missing_ids"};
  }

  return db.runTransaction(async (transaction) => {
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const sessionSnap = await transaction.get(sessionRef);
    if (!sessionSnap.exists) {
      return {shouldNotify: false, reason: "session_missing"};
    }

    const sessionData = sessionSnap.data() || {};
    const assignedResponderId =
      normalizeString(sessionData.currentResponderId) ||
      normalizeString(sessionData.currentTutorId);
    if (
      assignedResponderId &&
      assignedResponderId !== normalizedResponderId
    ) {
      return {shouldNotify: false, reason: "responder_mismatch"};
    }
    const decision = shouldCreateTeacherResponderIncomingCall({
      sessionData,
      responderId: normalizedResponderId,
      nowMillis,
    });
    if (!decision.shouldNotify) {
      return decision;
    }

    const notification = createIncomingCallNotificationInTransaction({
      db,
      transaction,
      sessionId: normalizedSessionId,
      recipientId: normalizedResponderId,
      sessionData,
      studentInfo: buildStudentPairRequesterInfo(requesterData),
      studentNameFallback: "Student",
      now: new Date(nowMillis),
    });

    return {
      shouldNotify: true,
      reason: decision.reason,
      notificationId: notification.notificationId,
      pushPayload: notification.pushPayload,
    };
  });
}

async function backgroundStudentResponderPushStillCurrent({
  db,
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  notificationId = "",
  nowMillis = Date.now(),
}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const searchDocId =
    normalizeString(responderSearchRequestDocId) || normalizedResponderId;
  if (!normalizedSessionId || !normalizedResponderId || !searchDocId) {
    return {stillCurrent: false, reason: "missing_ids", leaveForAccept: false};
  }

  const reads = [
    db.collection("videoSessions").doc(normalizedSessionId).get(),
    db.collection(SEARCH_REQUEST_COLLECTION).doc(searchDocId).get(),
  ];
  if (notificationId) {
    reads.push(db.collection("notifications").doc(notificationId).get());
  }
  const [sessionSnap, responderSearchSnap, notificationSnap] =
    await Promise.all(reads);
  if (!sessionSnap.exists || !responderSearchSnap.exists) {
    return {
      stillCurrent: false,
      reason: "session_or_search_missing",
      leaveForAccept: false,
    };
  }
  const sessionData = sessionSnap.data() || {};

  const decision = shouldCreateBackgroundStudentResponderIncomingCall({
    sessionData,
    sessionId: normalizedSessionId,
    responderId: normalizedResponderId,
    responderSearchRequestData: responderSearchSnap.data() || {},
    nowMillis,
  });
  if (!decision.shouldNotify) {
    return {
      stillCurrent: false,
      reason: decision.reason,
      leaveForAccept: shouldLeaveBackgroundNotificationForAccept({
        decision,
        sessionData,
      }),
    };
  }

  if (notificationId) {
    const notificationData = notificationSnap?.data?.() || {};
    if (
      !notificationSnap?.exists ||
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        stillCurrent: false,
        reason: "notification_not_current",
        leaveForAccept: false,
      };
    }
  }

  return {
    stillCurrent: true,
    reason: decision.reason,
    leaveForAccept: false,
  };
}

async function teacherResponderPushStillCurrent({
  db,
  sessionId = "",
  responderId = "",
  notificationId = "",
  nowMillis = Date.now(),
  tokenReader = getReadOnlyUserVoipTokenState,
}) {
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const normalizedNotificationId = normalizeString(notificationId);
  if (
    !normalizedSessionId ||
    !normalizedResponderId ||
    !normalizedNotificationId
  ) {
    return {stillCurrent: false, reason: "missing_ids", leaveForAccept: false};
  }

  const [sessionSnap, notificationSnap, teacherSnap] = await Promise.all([
    db.collection("videoSessions").doc(normalizedSessionId).get(),
    db.collection("notifications").doc(normalizedNotificationId).get(),
    db.collection("users").doc(normalizedResponderId).get(),
  ]);
  if (!sessionSnap.exists) {
    return {stillCurrent: false, reason: "session_missing", leaveForAccept: false};
  }
  if (!notificationSnap.exists) {
    return {
      stillCurrent: false,
      reason: "notification_missing",
      leaveForAccept: false,
    };
  }
  if (!teacherSnap.exists) {
    return {stillCurrent: false, reason: "teacher_missing", leaveForAccept: false};
  }

  const sessionData = sessionSnap.data() || {};
  const decision = shouldCreateTeacherResponderIncomingCall({
    sessionData,
    responderId: normalizedResponderId,
    nowMillis,
  });
  if (!decision.shouldNotify) {
    return {
      stillCurrent: false,
      reason: decision.reason,
      leaveForAccept: shouldLeaveBackgroundNotificationForAccept({
        decision,
        sessionData,
      }),
    };
  }

  const notificationData = notificationSnap.data() || {};
  if (
    notificationData.status !== "sent" ||
    notificationData.sessionId !== normalizedSessionId ||
    notificationData.recipientId !== normalizedResponderId
  ) {
    return {
      stillCurrent: false,
      reason: "notification_not_current",
      leaveForAccept: false,
    };
  }

  const teacherData = teacherSnap.data() || {};
  const tokenState = await tokenReader(
    normalizedResponderId,
    teacherData,
    db,
  );
  const teacherDecision = shouldUseTeacherResponderForIncomingCall({
    teacherData,
    responderId: normalizedResponderId,
    sessionId: normalizedSessionId,
    sessionData,
    tokenState,
    now: new Date(nowMillis),
  });
  if (!teacherDecision.valid) {
    return {
      stillCurrent: false,
      reason: teacherDecision.reason,
      leaveForAccept: false,
    };
  }

  return {
    stillCurrent: true,
    reason: teacherDecision.reason,
    leaveForAccept: false,
  };
}

async function cancelBackgroundStudentResponderNotification({
  db,
  notificationId = "",
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  reason = "stale_before_push",
  pushResult = null,
  nowMillis = Date.now(),
}) {
  const normalizedNotificationId = normalizeString(notificationId);
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const searchDocId =
    normalizeString(responderSearchRequestDocId) || normalizedResponderId;
  if (
    !normalizedNotificationId ||
    !normalizedSessionId ||
    !normalizedResponderId ||
    !searchDocId
  ) {
    return {cancelled: false, reason: "missing_ids", leaveForAccept: false};
  }

  return db.runTransaction(async (transaction) => {
    const notificationRef = db
      .collection("notifications")
      .doc(normalizedNotificationId);
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const responderSearchRef = db
      .collection(SEARCH_REQUEST_COLLECTION)
      .doc(searchDocId);
    const [sessionSnap, responderSearchSnap, notificationSnap] =
      await Promise.all([
        transaction.get(sessionRef),
        transaction.get(responderSearchRef),
        transaction.get(notificationRef),
      ]);
    if (!notificationSnap.exists) {
      return {
        cancelled: false,
        reason: "notification_missing",
        leaveForAccept: false,
      };
    }

    const notificationData = notificationSnap.data() || {};
    if (
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        cancelled: false,
        reason: "notification_not_current",
        leaveForAccept: false,
      };
    }

    const sessionData = sessionSnap.exists ? sessionSnap.data() || {} : {};
    const decision = sessionSnap.exists && responderSearchSnap.exists ?
      shouldCreateBackgroundStudentResponderIncomingCall({
        sessionData,
        sessionId: normalizedSessionId,
        responderId: normalizedResponderId,
        responderSearchRequestData: responderSearchSnap.data() || {},
        nowMillis,
      }) :
      {shouldNotify: false, reason: "session_or_search_missing"};
    if (
      shouldLeaveBackgroundNotificationForAccept({
        decision,
        sessionData,
      })
    ) {
      return {
        cancelled: false,
        reason: "accept_finalization_in_progress",
        staleReason: decision.reason,
        leaveForAccept: true,
      };
    }

    const update = {
      status: "cancelled",
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelReason: normalizeString(reason) || "stale_before_push",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (pushResult && pushResult.sent === true) {
      update.pushSentAt = admin.firestore.FieldValue.serverTimestamp();
      update.pushChannel = normalizeString(pushResult.channel) || "unknown";
    }
    transaction.update(notificationRef, update);
    return {
      cancelled: true,
      reason: normalizeString(reason) || "stale_before_push",
      staleReason: decision.reason,
      leaveForAccept: false,
    };
  });
}

async function cancelTeacherResponderNotification({
  db,
  notificationId = "",
  sessionId = "",
  responderId = "",
  reason = "stale_before_push",
  staleReason = "",
  nowMillis = Date.now(),
}) {
  const normalizedNotificationId = normalizeString(notificationId);
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  if (
    !normalizedNotificationId ||
    !normalizedSessionId ||
    !normalizedResponderId
  ) {
    return {cancelled: false, reason: "missing_ids", leaveForAccept: false};
  }

  return db.runTransaction(async (transaction) => {
    const notificationRef = db
      .collection("notifications")
      .doc(normalizedNotificationId);
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const [sessionSnap, notificationSnap] = await Promise.all([
      transaction.get(sessionRef),
      transaction.get(notificationRef),
    ]);
    if (!notificationSnap.exists) {
      return {
        cancelled: false,
        reason: "notification_missing",
        leaveForAccept: false,
      };
    }

    const notificationData = notificationSnap.data() || {};
    if (
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        cancelled: false,
        reason: "notification_not_current",
        leaveForAccept: false,
      };
    }

    const sessionData = sessionSnap.exists ? sessionSnap.data() || {} : {};
    const decision = sessionSnap.exists ?
      shouldCreateTeacherResponderIncomingCall({
        sessionData,
        responderId: normalizedResponderId,
        nowMillis,
      }) :
      {shouldNotify: false, reason: "session_missing"};
    if (shouldLeaveBackgroundNotificationForAccept({decision, sessionData})) {
      return {
        cancelled: false,
        reason: "accept_finalization_in_progress",
        staleReason: decision.reason,
        leaveForAccept: true,
      };
    }

    transaction.update(notificationRef, {
      status: "cancelled",
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelReason: normalizeString(reason) || "stale_before_push",
      staleReason:
        normalizeString(staleReason) ||
        normalizeString(decision.reason) ||
        "stale_before_push",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
      cancelled: true,
      reason: normalizeString(reason) || "stale_before_push",
      staleReason:
        normalizeString(staleReason) ||
        normalizeString(decision.reason) ||
        "stale_before_push",
      leaveForAccept: false,
    };
  });
}

function shouldRetryTeacherMatchAfterNotifyResult(result = {}) {
  if (!result || typeof result !== "object") {
    return true;
  }
  if (result.reason === "accept_finalization_in_progress") {
    return false;
  }
  if (result.shouldNotify === false) {
    return true;
  }
  return result.pushResult?.sent !== true;
}

function shouldRetryBackgroundStudentMatchAfterNotifyResult(result = {}) {
  if (!result || typeof result !== "object") {
    return true;
  }
  const reason = normalizeString(result.reason);
  const staleReason = normalizeString(result.staleReason);
  const noRetryReasons = new Set([
    "accept_finalization_in_progress",
    "accept_in_progress",
    "responder_not_background",
    "session_active",
    "session_connecting",
  ]);
  if (noRetryReasons.has(reason) || noRetryReasons.has(staleReason)) {
    return false;
  }
  if (result.shouldNotify === false) {
    return true;
  }
  return result.pushResult?.sent !== true;
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

async function recordBackgroundStudentResponderPushFailure({
  db,
  notificationId = "",
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  error,
  nowMillis = Date.now(),
}) {
  const normalizedNotificationId = normalizeString(notificationId);
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const searchDocId =
    normalizeString(responderSearchRequestDocId) || normalizedResponderId;
  if (
    !normalizedNotificationId ||
    !normalizedSessionId ||
    !normalizedResponderId ||
    !searchDocId
  ) {
    return {stillCurrent: false, reason: "missing_ids", updated: false};
  }

  return db.runTransaction(async (transaction) => {
    const notificationRef = db
      .collection("notifications")
      .doc(normalizedNotificationId);
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const responderSearchRef = db
      .collection(SEARCH_REQUEST_COLLECTION)
      .doc(searchDocId);
    const [sessionSnap, responderSearchSnap, notificationSnap] =
      await Promise.all([
        transaction.get(sessionRef),
        transaction.get(responderSearchRef),
        transaction.get(notificationRef),
      ]);
    if (!notificationSnap.exists) {
      return {
        stillCurrent: false,
        reason: "notification_missing",
        updated: false,
      };
    }

    const notificationData = notificationSnap.data() || {};
    if (
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        stillCurrent: false,
        reason: "notification_not_current",
        updated: false,
      };
    }

    const sessionData = sessionSnap.exists ? sessionSnap.data() || {} : {};
    const decision = sessionSnap.exists && responderSearchSnap.exists ?
      shouldCreateBackgroundStudentResponderIncomingCall({
        sessionData,
        sessionId: normalizedSessionId,
        responderId: normalizedResponderId,
        responderSearchRequestData: responderSearchSnap.data() || {},
        nowMillis,
      }) :
      {shouldNotify: false, reason: "session_or_search_missing"};

    if (!decision.shouldNotify) {
      if (shouldLeaveBackgroundNotificationForAccept({decision, sessionData})) {
        return {
          stillCurrent: false,
          reason: "accept_finalization_in_progress",
          staleReason: decision.reason,
          updated: false,
        };
      }
      transaction.update(notificationRef, {
        status: "cancelled",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelReason: "stale_after_push",
        staleReason: decision.reason,
        lastPushError: readErrorMessage(error, "push_failed"),
        lastPushFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return {
        stillCurrent: false,
        reason: "stale_after_push",
        staleReason: decision.reason,
        updated: true,
      };
    }

    transaction.update(notificationRef, {
      lastPushError: readErrorMessage(error, "push_failed"),
      lastPushFailedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
      stillCurrent: true,
      reason: decision.reason,
      updated: true,
    };
  });
}

async function recordBackgroundStudentResponderPushSuccess({
  db,
  notificationId = "",
  sessionId = "",
  responderId = "",
  responderSearchRequestDocId = "",
  pushResult = {},
  nowMillis = Date.now(),
}) {
  const normalizedNotificationId = normalizeString(notificationId);
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  const searchDocId =
    normalizeString(responderSearchRequestDocId) || normalizedResponderId;
  if (
    !normalizedNotificationId ||
    !normalizedSessionId ||
    !normalizedResponderId ||
    !searchDocId
  ) {
    return {stillCurrent: false, reason: "missing_ids", updated: false};
  }

  return db.runTransaction(async (transaction) => {
    const notificationRef = db
      .collection("notifications")
      .doc(normalizedNotificationId);
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const responderSearchRef = db
      .collection(SEARCH_REQUEST_COLLECTION)
      .doc(searchDocId);
    const [sessionSnap, responderSearchSnap, notificationSnap] =
      await Promise.all([
        transaction.get(sessionRef),
        transaction.get(responderSearchRef),
        transaction.get(notificationRef),
      ]);
    if (!notificationSnap.exists) {
      return {
        stillCurrent: false,
        reason: "notification_missing",
        updated: false,
      };
    }

    const notificationData = notificationSnap.data() || {};
    if (
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        stillCurrent: false,
        reason: "notification_not_current",
        updated: false,
      };
    }

    const sessionData = sessionSnap.exists ? sessionSnap.data() || {} : {};
    const decision = sessionSnap.exists && responderSearchSnap.exists ?
      shouldCreateBackgroundStudentResponderIncomingCall({
        sessionData,
        sessionId: normalizedSessionId,
        responderId: normalizedResponderId,
        responderSearchRequestData: responderSearchSnap.data() || {},
        nowMillis,
      }) :
      {shouldNotify: false, reason: "session_or_search_missing"};

    if (!decision.shouldNotify) {
      if (shouldLeaveBackgroundNotificationForAccept({decision, sessionData})) {
        return {
          stillCurrent: false,
          reason: "accept_finalization_in_progress",
          staleReason: decision.reason,
          updated: false,
        };
      }
      transaction.update(notificationRef, {
        status: "cancelled",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelReason: "stale_after_push",
        staleReason: decision.reason,
        pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
        pushChannel: normalizeString(pushResult.channel) || "unknown",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return {
        stillCurrent: false,
        reason: "stale_after_push",
        staleReason: decision.reason,
        updated: true,
      };
    }

    transaction.update(notificationRef, {
      pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
      pushChannel: normalizeString(pushResult.channel) || "unknown",
      lastPushError: admin.firestore.FieldValue.delete(),
      lastPushFailedAt: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
      stillCurrent: true,
      reason: decision.reason,
      updated: true,
    };
  });
}

async function recordTeacherResponderPushResult({
  db,
  notificationId = "",
  sessionId = "",
  responderId = "",
  pushResult = {},
  nowMillis = Date.now(),
}) {
  const normalizedNotificationId = normalizeString(notificationId);
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedResponderId = normalizeString(responderId);
  if (
    !normalizedNotificationId ||
    !normalizedSessionId ||
    !normalizedResponderId
  ) {
    return {stillCurrent: false, reason: "missing_ids", updated: false};
  }

  return db.runTransaction(async (transaction) => {
    const notificationRef = db
      .collection("notifications")
      .doc(normalizedNotificationId);
    const sessionRef = db.collection("videoSessions").doc(normalizedSessionId);
    const teacherRef = db.collection("users").doc(normalizedResponderId);
    const privateTokenRef = db
      .collection("userPrivateTokens")
      .doc(normalizedResponderId);
    const [sessionSnap, notificationSnap, teacherSnap, privateTokenSnap] =
      await Promise.all([
      transaction.get(sessionRef),
      transaction.get(notificationRef),
      transaction.get(teacherRef),
      transaction.get(privateTokenRef),
    ]);
    if (!notificationSnap.exists) {
      return {
        stillCurrent: false,
        reason: "notification_missing",
        updated: false,
      };
    }

    const notificationData = notificationSnap.data() || {};
    if (
      notificationData.status !== "sent" ||
      notificationData.sessionId !== normalizedSessionId ||
      notificationData.recipientId !== normalizedResponderId
    ) {
      return {
        stillCurrent: false,
        reason: "notification_not_current",
        updated: false,
      };
    }

    const sessionData = sessionSnap.exists ? sessionSnap.data() || {} : {};
    const decision = sessionSnap.exists ?
      shouldCreateTeacherResponderIncomingCall({
        sessionData,
        responderId: normalizedResponderId,
        nowMillis,
      }) :
      {shouldNotify: false, reason: "session_missing"};
    const teacherData = teacherSnap.exists ? teacherSnap.data() || {} : {};
    const tokenState = buildReadOnlyVoipTokenState({
      privateData: privateTokenSnap.exists ?
        privateTokenSnap.data() || {} :
        {},
      legacyUserData: teacherData,
    });
    const teacherDecision = decision.shouldNotify ?
      shouldUseTeacherResponderForIncomingCall({
        teacherData,
        responderId: normalizedResponderId,
        sessionId: normalizedSessionId,
        sessionData,
        tokenState,
        now: new Date(nowMillis),
      }) :
      {valid: false, reason: decision.reason};
    const finalDecision = teacherDecision.valid ?
      decision :
      {shouldNotify: false, reason: teacherDecision.reason};
    const pushSent = pushResult?.sent === true;
    const pushErrorMessage =
      normalizeString(pushResult?.error) ||
      normalizeString(pushResult?.reason) ||
      "push_failed";

    if (!finalDecision.shouldNotify) {
      if (
        shouldLeaveBackgroundNotificationForAccept({
          decision: finalDecision,
          sessionData,
        })
      ) {
        return {
          stillCurrent: false,
          reason: "accept_finalization_in_progress",
          staleReason: finalDecision.reason,
          updated: false,
        };
      }
      const staleUpdate = {
        status: "cancelled",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelReason: "stale_after_push",
        staleReason: finalDecision.reason,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (pushSent) {
        staleUpdate.pushSentAt =
          admin.firestore.FieldValue.serverTimestamp();
        staleUpdate.pushChannel =
          normalizeString(pushResult.channel) || "unknown";
      } else {
        staleUpdate.lastPushError = pushErrorMessage;
        staleUpdate.lastPushFailedAt =
          admin.firestore.FieldValue.serverTimestamp();
      }
      transaction.update(notificationRef, staleUpdate);
      return {
        stillCurrent: false,
        reason: "stale_after_push",
        staleReason: finalDecision.reason,
        updated: true,
      };
    }

    if (pushSent) {
      transaction.update(notificationRef, {
        pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
        pushChannel: normalizeString(pushResult.channel) || "unknown",
        lastPushError: admin.firestore.FieldValue.delete(),
        lastPushFailedAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      transaction.update(notificationRef, {
        lastPushError: pushErrorMessage,
        lastPushFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return {
      stillCurrent: true,
      reason: teacherDecision.reason,
      updated: true,
    };
  });
}

async function sendVoipPushToStudentResponder(
  responderId,
  callData = {},
  dependencies = {},
) {
  const normalizedResponderId = normalizeString(responderId);
  if (!normalizedResponderId) {
    return {sent: false, reason: "missing_responder"};
  }

  const firestore = dependencies.firestore || admin.firestore();
  const getTokens = dependencies.getUserVoipTokens || getUserVoipTokens;
  const sendApns = dependencies.sendApnsVoip || sendApnsVoip;
  const messaging = dependencies.messaging || admin.messaging();
  const logger = dependencies.logger || console;
  const signal = dependencies.signal || null;
  const apnsTimeoutMs = Number.isFinite(dependencies.apnsTimeoutMs) &&
    dependencies.apnsTimeoutMs > 0 ?
    dependencies.apnsTimeoutMs :
    BACKGROUND_STUDENT_RESPONDER_APNS_TIMEOUT_MS;
  throwIfAborted(signal);
  const responderDoc = await firestore
    .collection("users")
    .doc(normalizedResponderId)
    .get();
  throwIfAborted(signal);
  if (!responderDoc.exists) {
    return {sent: false, reason: "responder_missing"};
  }

  const responderData = responderDoc.data() || {};
  const callExpiresAtMillis = Date.parse(normalizeString(callData.expiresAt));
  if (
    Number.isFinite(callExpiresAtMillis) &&
    callExpiresAtMillis <= Date.now()
  ) {
    return {sent: false, reason: "response_window_closed"};
  }
  const apnsExpiration = Number.isFinite(callExpiresAtMillis) ?
    Math.floor(callExpiresAtMillis / 1000) :
    null;
  const bundleId = process.env.IOS_BUNDLE_ID || "com.appwave.smalltalk";
  const voipTopic =
    process.env.IOS_VOIP_TOPIC ||
    (bundleId.endsWith(".voip") ? bundleId : `${bundleId}.voip`);
  const {voipPushToken, voipToken: fcmToken} =
    await getTokens(normalizedResponderId, responderData);
  throwIfAborted(signal);
  if (!voipPushToken && !fcmToken) {
    return {sent: false, reason: "missing_tokens"};
  }

  const payload = buildStudentPairResponderPushPayload(callData);
  let apnsErrorMessage = "";
  let apnsFailureKind = null;

  if (voipPushToken) {
    const apnsAbort = buildChildAbortController({
      parentSignal: signal,
      timeoutMs: apnsTimeoutMs,
      timeoutError: new Error("apns_voip_timeout"),
    });
    try {
      await sendApns({
        deviceToken: voipPushToken,
        topic: voipTopic,
        expiration: apnsExpiration,
        collapseId: normalizeString(callData.callKitId),
        signal: apnsAbort.signal,
        payload: {
          aps: {"content-available": 1},
          ...payload,
        },
      });
      return {sent: true, channel: "apns_voip"};
    } catch (error) {
      apnsErrorMessage =
        readErrorMessage(error, "apns_voip_failed");
      apnsFailureKind = classifyApnsDeliveryFailure(error);
      logger.error(
        "Failed to send APNs VoIP push to background student:",
        readErrorMessage(error, "apns_voip_failed"),
      );
    } finally {
      apnsAbort.cleanup();
    }
  }

  if (!fcmToken) {
    return {
      sent: false,
      reason: "missing_fcm_token",
      error: apnsErrorMessage || "missing_fcm_token",
      attemptedChannels: ["apns_voip"],
      apnsFailureKind: apnsFailureKind || "unknown",
    };
  }

  try {
    throwIfAborted(signal);
    await waitForAbortable(
      messaging.send(buildStudentPairResponderFcmMessage({
        fcmToken,
        payload,
        bundleId,
      })),
      signal,
    );
  } catch (error) {
    const fcmErrorMessage =
      readErrorMessage(error, "fcm_failed");
    return {
      sent: false,
      reason: "fcm_failed",
      error: apnsErrorMessage ?
        `apns: ${apnsErrorMessage}; fcm: ${fcmErrorMessage}` :
        fcmErrorMessage,
    };
  }
  const requiresApnsVoipDelivery =
    normalizeString(responderData.matchProtocolPlatform) === "ios" ||
    Boolean(voipPushToken);
  if (requiresApnsVoipDelivery) {
    return {
      sent: false,
      reason: voipPushToken ?
        "ios_fcm_wake_not_native" :
        "missing_voip_push_token",
      error: apnsErrorMessage || "ios_fcm_wake_not_native",
      fcmWakeSent: true,
      attemptedChannels: voipPushToken ? ["apns_voip", "fcm"] : ["fcm"],
      apnsFailureKind: voipPushToken ?
        (apnsFailureKind || "unknown") :
        "definitive",
    };
  }
  return {sent: true, channel: "fcm"};
}

async function runBackgroundStudentResponderPushSender({
  pushSender,
  responderId = "",
  callData = {},
  timeoutMs = BACKGROUND_STUDENT_RESPONDER_PUSH_TIMEOUT_MS,
}) {
  const controller = new AbortController();
  const normalizedTimeoutMs = Number.isFinite(timeoutMs) && timeoutMs > 0 ?
    timeoutMs :
    BACKGROUND_STUDENT_RESPONDER_PUSH_TIMEOUT_MS;
  const timeoutError = new Error("push_timeout");
  let timeout = null;
  const pushPromise = Promise.resolve()
    .then(() => pushSender(responderId, callData, {
      apnsTimeoutMs: calculateApnsFallbackTimeoutMs(normalizedTimeoutMs),
      signal: controller.signal,
    }));
  const timeoutPromise = new Promise((resolve, reject) => {
    timeout = setTimeout(() => {
      controller.abort(timeoutError);
      reject(timeoutError);
    }, normalizedTimeoutMs);
  });

  try {
    return await Promise.race([pushPromise, timeoutPromise]);
  } finally {
    clearTimeout(timeout);
    pushPromise.catch(() => {});
  }
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

async function tryCreateStudentPairForSearchRequest({
  db,
  userId,
  requesterData = {},
  requestData = {},
  reused = false,
  backgroundStudentResponderPushSender = sendVoipPushToStudentResponder,
  backgroundStudentResponderPrePushWait =
    waitForForegroundStudentResponderResolution,
  teacherResponderPushSender = sendVoipPushToStudentResponder,
  teacherResponderTokenReader = getReadOnlyUserVoipTokenState,
}) {
  if (!canAttemptStudentPairForSearchRequest(requestData)) {
    return {
      matched: false,
      response: null,
    };
  }

  const candidatePool = await collectMatchCandidatePool({
    db,
    requesterId: userId,
    requesterEmail: normalizeString(requesterData.email),
    language: requestData.language,
    requesterFilters: requestData.filters || {},
    requesterLevel: readLevelValue(requesterData.level),
    now: new Date(),
    nowMillis: Date.now(),
  });
  const normalizedRequesterId = normalizeString(userId);
  const matchCandidates = candidatePool.candidates.filter((candidate) => {
    const candidateUserId = normalizeString(candidate.userId);
    const candidateRole = normalizeRole(candidate.role);
    const candidateSource = normalizeString(candidate.source);
    if (!candidateUserId || candidateUserId === normalizedRequesterId) {
      return false;
    }
    return (
      candidateSource === MATCH_CANDIDATE_SOURCE.ACTIVE_STUDENT_QUEUE &&
        candidateRole === "student"
    ) || (
      candidateSource === MATCH_CANDIDATE_SOURCE.TEACHER_AVAILABILITY &&
        candidateRole === "native_speaker"
    );
  });

  const retryExcludedResponderIds = new Set();
  for (const candidate of matchCandidates) {
    if (retryExcludedResponderIds.has(normalizeString(candidate.userId))) {
      continue;
    }
    const currentMatchCandidates = matchCandidates.filter((matchCandidate) =>
      !retryExcludedResponderIds.has(normalizeString(matchCandidate.userId)),
    );
    const responderRole = normalizeRole(candidate.role);
    const isStudentQueueResponder =
      responderRole === "student" &&
      normalizeString(candidate.source) ===
        MATCH_CANDIDATE_SOURCE.ACTIVE_STUDENT_QUEUE;
    const isTeacherResponder =
      responderRole === "native_speaker" &&
      normalizeString(candidate.source) ===
        MATCH_CANDIDATE_SOURCE.TEACHER_AVAILABILITY;
    const lockNowMillis = Date.now();
    const lockResult = await reserveMatchPair({
      db,
      requesterId: userId,
      responderId: candidate.userId,
      responderRole,
      requesterSearchRequestId: requestData.requestId,
      responderSearchRequestId:
        isStudentQueueResponder ? candidate.searchRequestId : "",
      expectedLanguage: requestData.language,
      sessionData: buildStudentPairSessionData({
        requesterId: userId,
        requestData,
        selectedCandidate: candidate,
        matchCandidates: currentMatchCandidates,
        candidateStats: candidatePool.stats,
        nowMillis: lockNowMillis,
      }),
      nowMillis: lockNowMillis,
    });

    if (lockResult.locked) {
      if (
        Number(lockResult.matchProtocolVersion) === MATCH_PROTOCOL_VERSION
      ) {
        let protocolV2RouteResult;
        try {
          protocolV2RouteResult = await routeProtocolV2InitialMatch({
            db,
            lockResult,
            requesterId: userId,
            responderRole,
            studentPushSender: backgroundStudentResponderPushSender,
            teacherPushSender: teacherResponderPushSender,
            studentPreDispatchWait:
              backgroundStudentResponderPrePushWait,
          });
        } catch (error) {
          protocolV2RouteResult = {
            results: [],
            failedResult: null,
            retryPending: true,
            error: readErrorMessage(error, "route_failed"),
          };
        }

        if (protocolV2RouteResult.failedResult) {
          const failure = protocolV2RouteResult.failedResult;
          const failedParticipantId = normalizeString(
            failure.participantId,
          ) || normalizeString(lockResult.responderId);
          const failureState = failure.participantState || {};
          const failureOutcome = classifyProtocolV2RouteResult(failure);
          const releaseResult =
            await releaseProtocolV2MatchAfterRouteFailure({
              db,
              sessionId: lockResult.sessionId,
              pairAttemptId: lockResult.pairAttemptId,
              failedParticipantId,
              expectedDispatchId: failureState.dispatchId,
              expectedDelivery: failureState.delivery,
              expectedDeliveryFailureKind:
                failureState.deliveryFailureKind,
              requireResponseWindowClosed:
                failureOutcome === "response_window_closed",
              stopReason: failureOutcome === "response_window_closed" ?
                "protocol_v2_response_timeout" :
                "protocol_v2_push_failed",
          });
          if (releaseResult.released) {
            await reconcileReleasedProtocolV2Match({
              db,
              sessionId: lockResult.sessionId,
              pairAttemptId: lockResult.pairAttemptId,
              options: {
                participantPushSender:
                  backgroundStudentResponderPushSender,
                studentPreDispatchWait:
                  backgroundStudentResponderPrePushWait,
              },
            }).catch((error) => {
              console.warn("Protocol v2 terminal recovery deferred", {
                sessionId: lockResult.sessionId,
                pairAttemptId: lockResult.pairAttemptId,
                error: readErrorMessage(error, "recovery_deferred"),
              });
            });
            if (failedParticipantId === normalizeString(userId)) {
              return {
                matched: false,
                response: buildStartSearchResponse({
                  userId,
                  requestData: {
                    ...requestData,
                    status: SEARCH_REQUEST_STATUS.CANCELLED,
                    currentSessionId: null,
                    matchedSessionId: null,
                    pairAttemptId: null,
                  },
                  reused,
                }),
              };
            }
            retryExcludedResponderIds.add(normalizeString(candidate.userId));
            continue;
          }
        }
        const postRouteOutcome = await readProtocolV2PostRouteOutcome({
          db,
          sessionId: lockResult.sessionId,
          pairAttemptId: lockResult.pairAttemptId,
        });
        if (postRouteOutcome.terminal) {
          const requesterSearchSnap = await db
            .collection(SEARCH_REQUEST_COLLECTION)
            .doc(userId)
            .get();
          const latestRequestData = requesterSearchSnap.exists ?
            requesterSearchSnap.data() || {} :
            {};
          if (
            latestRequestData.status === SEARCH_REQUEST_STATUS.ACTIVE &&
            !hasSearchRequestSessionBinding(latestRequestData)
          ) {
            retryExcludedResponderIds.add(normalizeString(candidate.userId));
            continue;
          }
          return {
            matched: false,
            response: buildStartSearchResponse({
              userId,
              requestData: latestRequestData,
              reused,
            }),
          };
        }
      } else if (isStudentQueueResponder) {
        let backgroundStudentNotifyResult = null;
        try {
          backgroundStudentNotifyResult =
            await maybeNotifyBackgroundStudentResponder({
              db,
              sessionId: lockResult.sessionId,
              responderId: lockResult.responderId,
              responderSearchRequestDocId: candidate.searchRequestDocId,
              requesterData,
              pushSender: backgroundStudentResponderPushSender,
              prePushWait: backgroundStudentResponderPrePushWait,
            });
        } catch (error) {
          console.error(
            "Failed to notify background student responder",
            {
              sessionId: lockResult.sessionId,
              responderId: lockResult.responderId,
              error: readErrorMessage(error, "notify_failed"),
            },
          );
          backgroundStudentNotifyResult = {
            shouldNotify: false,
            reason: "notify_failed",
            error: readErrorMessage(error, "notify_failed"),
          };
        }

        if (
          shouldRetryBackgroundStudentMatchAfterNotifyResult(
            backgroundStudentNotifyResult,
          )
        ) {
          const releaseResult =
            await releaseBackgroundStudentResponderMatchForRetry({
              db,
              sessionId: lockResult.sessionId,
              responderId: lockResult.responderId,
              requesterId: userId,
              notificationId: backgroundStudentNotifyResult?.notificationId,
              pairAttemptId: lockResult.pairAttemptId,
              stopReason:
                backgroundStudentNotifyResult?.pushResult?.sent === false ?
                  "background_student_push_failed" :
                  normalizeString(
                    backgroundStudentNotifyResult?.staleReason,
                  ) ||
                    normalizeString(backgroundStudentNotifyResult?.reason) ||
                    "background_student_notification_failed",
            });
          if (releaseResult.released) {
            retryExcludedResponderIds.add(normalizeString(candidate.userId));
            continue;
          }
          if (releaseResult.reason !== "accept_finalization_in_progress") {
            const currentMatchedResponse =
              await tryReadCurrentMatchedStartSearchResponse({
                db,
                userId,
                reused,
              });
            if (currentMatchedResponse) {
              return {
                matched: true,
                response: currentMatchedResponse,
                lockResult,
              };
            }
            retryExcludedResponderIds.add(normalizeString(candidate.userId));
            continue;
          }
        }
      } else if (isTeacherResponder) {
        let teacherNotifyResult = null;
        try {
          teacherNotifyResult = await maybeNotifyTeacherResponder({
            db,
            sessionId: lockResult.sessionId,
            responderId: lockResult.responderId,
            requesterData,
            pushSender: teacherResponderPushSender,
            tokenReader: teacherResponderTokenReader,
          });
        } catch (error) {
          console.error(
            "Failed to notify teacher responder",
            {
              sessionId: lockResult.sessionId,
              responderId: lockResult.responderId,
              error: readErrorMessage(error, "notify_failed"),
            },
          );
          teacherNotifyResult = {
            shouldNotify: false,
            reason: "notify_failed",
            error: readErrorMessage(error, "notify_failed"),
          };
        }

        if (shouldRetryTeacherMatchAfterNotifyResult(teacherNotifyResult)) {
          const releaseResult = await releaseTeacherResponderMatchForRetry({
            db,
            sessionId: lockResult.sessionId,
            responderId: lockResult.responderId,
            requesterId: userId,
            notificationId: teacherNotifyResult?.notificationId,
            pairAttemptId: lockResult.pairAttemptId,
            stopReason:
              teacherNotifyResult?.pushResult?.sent === false ?
                "teacher_push_failed" :
                normalizeString(teacherNotifyResult?.staleReason) ||
                  normalizeString(teacherNotifyResult?.reason) ||
                  "teacher_notification_failed",
          });
          if (releaseResult.released) {
            retryExcludedResponderIds.add(normalizeString(candidate.userId));
            continue;
          }
          if (releaseResult.reason !== "accept_finalization_in_progress") {
            const currentMatchedResponse =
              await tryReadCurrentMatchedStartSearchResponse({
                db,
                userId,
                reused,
              });
            if (currentMatchedResponse) {
              return {
                matched: true,
                response: currentMatchedResponse,
                lockResult,
              };
            }
            retryExcludedResponderIds.add(normalizeString(candidate.userId));
            continue;
          }
        }
      }

      return {
        matched: true,
        response: buildMatchedStartSearchResponse({
          userId,
          requestData,
          matchResult: lockResult,
          reused,
        }),
        lockResult,
      };
    }

    if (String(lockResult.reason || "").startsWith("requester_")) {
      const currentMatchedResponse =
        await tryReadCurrentMatchedStartSearchResponse({
          db,
          userId,
          reused,
        });
      if (currentMatchedResponse) {
        return {
          matched: true,
          response: currentMatchedResponse,
          lockResult,
        };
      }
      break;
    }
  }

  return {
    matched: false,
    response: null,
  };
}

function buildStartSearchRequestData({
  userId,
  userRef,
  requestId,
  requesterData = {},
  input = {},
  nowMillis = Date.now(),
  serverTimestamp,
  timestampFromMillis = admin.firestore.Timestamp.fromMillis,
}) {
  const resolvedLanguage = resolveActiveConversationLanguage(
    requesterData,
    input.language,
  );
  if (!resolvedLanguage.code) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Language is required",
      {reason: "language_required"},
    );
  }

  const expiresAt = timestampFromMillis(
    nowMillis + SEARCH_REQUEST_TIMING.MAX_SEARCH_SECONDS * 1000,
  );
  const backgroundExpiresAt =
    input.appState === SEARCH_REQUEST_APP_STATE.BACKGROUND ?
      timestampFromMillis(
        nowMillis +
          SEARCH_REQUEST_TIMING.BACKGROUND_MAX_SEARCH_SECONDS * 1000,
      ) :
      null;

  return buildInitialSearchRequestData({
    userId,
    userRef,
    requestId,
    role: "student",
    language: resolvedLanguage.code,
    filters: buildStartSearchFilters({input, requesterData}),
    appState: input.appState,
    platform: input.platform,
    serverTimestamp,
    expiresAt,
    backgroundExpiresAt,
    matchProtocolVersion: input.matchProtocolVersion,
  });
}

function buildReusedSearchRequestRefresh({
  requestData = {},
  input = {},
  nowMillis = Date.now(),
  serverTimestamp,
  timestampFromMillis = admin.firestore.Timestamp.fromMillis,
  preserveMatchBinding = false,
}) {
  const expiresAt = timestampFromMillis(
    nowMillis + SEARCH_REQUEST_TIMING.MAX_SEARCH_SECONDS * 1000,
  );
  const backgroundExpiresAt =
    input.appState === SEARCH_REQUEST_APP_STATE.BACKGROUND ?
      timestampFromMillis(
        nowMillis +
          SEARCH_REQUEST_TIMING.BACKGROUND_MAX_SEARCH_SECONDS * 1000,
      ) :
      null;
  const refresh = {
    ...requestData,
    [SEARCH_REQUEST_FIELD.APP_STATE]: input.appState,
    [SEARCH_REQUEST_FIELD.APP_STATE_UPDATED_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.PLATFORM]: input.platform,
    [SEARCH_REQUEST_FIELD.UPDATED_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.HEARTBEAT_AT]: serverTimestamp,
  };
  if (!preserveMatchBinding) {
    refresh[SEARCH_REQUEST_FIELD.MATCH_PROTOCOL_VERSION] =
      input.matchProtocolVersion;
    refresh[SEARCH_REQUEST_FIELD.EXPIRES_AT] = expiresAt;
    refresh[SEARCH_REQUEST_FIELD.BACKGROUND_EXPIRES_AT] = backgroundExpiresAt;
  }
  return refresh;
}

async function resumeRestoredStudentSearch({
  db,
  participantId,
  sessionId,
  pairAttemptId,
  options = {},
}) {
  const normalizedParticipantId = normalizeString(participantId);
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedPairAttemptId = normalizeString(pairAttemptId);
  if (
    !normalizedParticipantId ||
    !normalizedSessionId ||
    !normalizedPairAttemptId
  ) {
    return {resumed: false, settled: false, reason: "resume_ids_missing"};
  }
  const [searchSnap, userSnap] = await Promise.all([
    db.collection(SEARCH_REQUEST_COLLECTION).doc(normalizedParticipantId).get(),
    db.collection("users").doc(normalizedParticipantId).get(),
  ]);
  if (!searchSnap.exists) {
    return {resumed: false, settled: true, reason: "search_missing"};
  }
  const requestData = searchSnap.data() || {};
  if (
    normalizeString(requestData.restoredFromSessionId) !==
      normalizedSessionId ||
    normalizeString(requestData.restoredFromPairAttemptId) !==
      normalizedPairAttemptId
  ) {
    return {resumed: false, settled: true, reason: "search_moved_on"};
  }
  if (
    requestData.status !== SEARCH_REQUEST_STATUS.ACTIVE ||
    hasSearchRequestSessionBinding(requestData)
  ) {
    return {resumed: false, settled: true, reason: "search_already_done"};
  }
  if (!userSnap.exists) {
    return {resumed: false, settled: false, reason: "user_missing"};
  }

  await tryCreateStudentPairForSearchRequest({
    db,
    userId: normalizedParticipantId,
    requesterData: userSnap.data() || {},
    requestData,
    reused: true,
    backgroundStudentResponderPushSender:
      options.participantPushSender || sendVoipPushToStudentResponder,
    teacherResponderPushSender:
      options.participantPushSender || sendVoipPushToStudentResponder,
    backgroundStudentResponderPrePushWait:
      options.studentPreDispatchWait ||
      waitForForegroundStudentResponderResolution,
  });
  return {resumed: true, settled: true, reason: "matching_restarted"};
}

async function reconcileReleasedProtocolV2Match({
  db,
  sessionId,
  pairAttemptId,
  options = {},
  cancelSurfaces = cancelProtocolV2NativeSurfaces,
  resumeSearch = resumeRestoredStudentSearch,
  ownerId,
  nowMillis,
}) {
  return reconcileProtocolV2TerminalSideEffects({
    db,
    sessionId,
    pairAttemptId,
    cancelSurfaces,
    resumeSearch: ({participantId}) => resumeSearch({
      db,
      participantId,
      sessionId,
      pairAttemptId,
      options,
    }),
    ownerId,
    nowMillis,
  });
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
  const requestId = input.requestId ||
    db.collection(SEARCH_REQUEST_COLLECTION).doc().id;
  const cancellationIntentRef = searchCancellationIntentRef(
    db,
    userId,
    requestId,
  );
  const nowMillis = Date.now();
  const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();

  const startResult = await db.runTransaction(async (transaction) => {
    const [requesterSnapshot, cancellationIntentSnap] = await Promise.all([
      transaction.get(userRef),
      cancellationIntentRef ? transaction.get(cancellationIntentRef) : null,
    ]);
    if (!requesterSnapshot.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Requester not found",
      );
    }

    const usageSnapshot = await transaction.get(usageRef);
    const searchRequestSnapshot = await transaction.get(searchRequestRef);
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
    const accessDecision = buildStartSearchAccessDecision({
      requesterRole,
      requesterData,
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
        console.warn("startSearch matching skipped while index is unavailable", {
          userId,
          requestId: requestIdForFailure,
          error: readErrorMessage(error, "index_unavailable"),
        });
        return startResult.response;
      }

      console.error("startSearch matching failed", {
        userId,
        requestId: requestIdForFailure,
        error: readErrorMessage(error, "start_search_failed"),
      });
      try {
        await failUnboundStartSearchRequestForError({
          db,
          userId,
          requestId: requestIdForFailure,
          error,
        });
      } catch (cleanupError) {
        console.error("startSearch failure cleanup failed", {
          userId,
          requestId: requestIdForFailure,
          error: readErrorMessage(cleanupError, "cleanup_failed"),
        });
      }
      throw error;
    }
    if (matchResult.matched) {
      return matchResult.response;
    }
    if (matchResult.response) {
      return matchResult.response;
    }
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
  timestampToMillis,
  tryReadCurrentMatchedStartSearchResponse,
  tryCreateStudentPairForSearchRequest,
  waitForForegroundStudentResponderResolution,
};
