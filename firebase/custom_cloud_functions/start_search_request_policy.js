const {activeSearchDeadlineMillis} = require("./active_search_deadline");
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  normalizeRole,
  resolveActiveConversationLanguage,
} = require("./video_sessions_shared");
const {
  SEARCH_REQUEST_ACTIVE_STATUSES,
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_FIELD,
  SEARCH_REQUEST_STATUS,
  SEARCH_REQUEST_TIMING,
  buildInitialSearchRequestData,
  normalizeSearchRequestFilters,
} = require("./search_requests");
const {
  MATCH_PROTOCOL_VERSION,
} = require("./match_protocol_v2");

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

function buildStartSearchFilters({input = {}} = {}) {
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

  const expiresAtMillis = activeSearchDeadlineMillis(requestData);
  if (expiresAtMillis === null || expiresAtMillis <= nowMillis) {
    return false;
  }

  if (status === SEARCH_REQUEST_STATUS.MATCHED) {
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
    expiresAt: timestampToIsoString(activeSearchDeadlineMillis(requestData)),
    errorCode: null,
    reused,
    ...(Number(requestData.matchProtocolVersion) >= MATCH_PROTOCOL_VERSION ? {
      matchProtocolVersion: MATCH_PROTOCOL_VERSION,
    } : {}),
  };
}

function canAttemptStudentPairForSearchRequest(requestData = {}) {
  return normalizeString(requestData.status) === SEARCH_REQUEST_STATUS.ACTIVE;
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
    (matchedRole === "native_speaker" ? "student_teacher" : null);
  return {
    ...buildStartSearchResponse({userId, requestData, reused}),
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
    lastError: {code: "start_search_failed", message},
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
    filters: buildStartSearchFilters({input}),
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
      activeSearchDeadlineMillis(requestData),
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

module.exports = {
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
  readReferenceId,
  searchRequestBelongsToUser,
  shouldFailUnboundStartSearchRequest,
  timestampToMillis,
};
