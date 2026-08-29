const admin = require("firebase-admin");
const {
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_FIELD,
  SEARCH_REQUEST_STATUS,
  SEARCH_REQUEST_TIMING,
} = require("./search_requests");
const {
  buildMatchProfile,
  extractBlockedIds,
  readLanguageCode,
  normalizeRole,
  supportsConversationLanguage,
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  evaluateTutorAvailabilityWindow,
} = require("./availability");
const {
  hasUsableCallTokenState,
} = require("./call_candidate_tokens");
const {
  buildReadOnlyVoipTokenState,
  VOIP_TOKEN_FRESHNESS_MS,
} = require("./voip_tokens");
const {
  buildStudentCallAccessDecision,
} = require("./call_access");
const {
  reserveTrialCallInTransaction,
  trialAccessRef,
} = require("./trial_access");
const {
  usageDocRef,
} = require("./subscription_usage_shared");
const {
  buildCallKitIdForMatchParticipant,
} = require("./call_notifications");
const {
  MATCH_ACTION,
  MATCH_PROTOCOL_VERSION,
  MATCH_STAGE,
  buildInitialParticipantStates,
  supportsMatchProtocolV2,
  transitionParticipantState,
} = require("./match_protocol_v2");

const USER_COLLECTION = "users";
const PRIVATE_TOKEN_COLLECTION = "userPrivateTokens";
const VIDEO_SESSION_COLLECTION = "videoSessions";
const MATCH_PAIR_LOCK_TTL_SECONDS = 45;
const FOREGROUND_AUTO_ACCEPT_FRESHNESS_MS = 40 * 1000;
const MATCH_FINALIZATION_GUARD_MS = 90 * 1000;

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeDocumentId(value) {
  const documentId = normalizeString(value);
  if (!documentId ||
      documentId.includes("/") ||
      documentId === "." ||
      documentId === ".." ||
      /^__.*__$/.test(documentId)) {
    return "";
  }

  return documentId;
}

function timestampToMillis(value) {
  if (!value) {
    return null;
  }
  if (typeof value.toMillis === "function") {
    const millis = Number(value.toMillis());
    return Number.isFinite(millis) ? millis : null;
  }
  if (typeof value.toDate === "function") {
    const millis = value.toDate().getTime();
    return Number.isFinite(millis) ? millis : null;
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  const millis = Number(value);
  return Number.isFinite(millis) ? millis : null;
}

function isFreshForegroundSearchForAutoAccept({
  requestData = {},
  nowMillis = Date.now(),
} = {}) {
  if (
    requestData[SEARCH_REQUEST_FIELD.APP_STATE] !==
      SEARCH_REQUEST_APP_STATE.FOREGROUND
  ) {
    return false;
  }
  const lifecycleMillis = Math.max(
    timestampToMillis(
      requestData[SEARCH_REQUEST_FIELD.APP_STATE_UPDATED_AT],
    ) || 0,
    timestampToMillis(requestData[SEARCH_REQUEST_FIELD.HEARTBEAT_AT]) || 0,
  );
  return lifecycleMillis > 0 &&
    nowMillis - lifecycleMillis <= FOREGROUND_AUTO_ACCEPT_FRESHNESS_MS;
}

function readReferenceId(value) {
  return value && typeof value.id === "string" ? value.id.trim() : "";
}

function searchRequestBelongsToUser(requestData = {}, userId = "") {
  const normalizedUserId = normalizeDocumentId(userId);
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

function hasSearchRequestSessionState(requestData = {}) {
  return [
    requestData.activeSessionId,
    requestData.currentSessionId,
    requestData.matchedSessionId,
  ].some((value) => Boolean(normalizeString(value)));
}

function hasLiveSearchRequestLock(requestData = {}, nowMillis = Date.now()) {
  const lockOwner = normalizeString(requestData.lockOwner);
  if (!lockOwner) {
    return false;
  }

  const lockExpiresAtMillis = timestampToMillis(requestData.lockExpiresAt);
  return lockExpiresAtMillis !== null && lockExpiresAtMillis > nowMillis;
}

function isSearchRequestFreshForPairLock(
  requestData = {},
  nowMillis = Date.now(),
) {
  const heartbeatAtMillis = timestampToMillis(
    requestData[SEARCH_REQUEST_FIELD.HEARTBEAT_AT],
  );
  const staleCutoffMillis =
    nowMillis - SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS * 1000;
  if (heartbeatAtMillis === null || heartbeatAtMillis < staleCutoffMillis) {
    return false;
  }

  const expiresAtMillis = timestampToMillis(
    requestData[SEARCH_REQUEST_FIELD.EXPIRES_AT],
  );
  if (expiresAtMillis === null || expiresAtMillis <= nowMillis) {
    return false;
  }

  const appState = normalizeString(requestData[SEARCH_REQUEST_FIELD.APP_STATE]);
  const backgroundExpiresAtMillis = timestampToMillis(
    requestData[SEARCH_REQUEST_FIELD.BACKGROUND_EXPIRES_AT],
  );
  if (appState === SEARCH_REQUEST_APP_STATE.BACKGROUND) {
    if (
      backgroundExpiresAtMillis === null ||
      backgroundExpiresAtMillis <= nowMillis
    ) {
      return false;
    }
  }

  return true;
}

function validateSearchRequestForPairLock({
  requestExists = false,
  requestData = {},
  userId = "",
  requestId = "",
  expectedLanguage = "",
  requireRequestId = false,
  nowMillis = Date.now(),
  participantKey = "requester",
}) {
  if (!requestExists) {
    return {ok: false, reason: `${participantKey}_search_request_missing`};
  }
  if (!searchRequestBelongsToUser(requestData, userId)) {
    return {ok: false, reason: `${participantKey}_search_owner_mismatch`};
  }

  const rawRequestId = normalizeString(requestId);
  const normalizedRequestId = normalizeDocumentId(requestId);
  if (requireRequestId && !rawRequestId) {
    return {ok: false, reason: `${participantKey}_search_request_id_required`};
  }
  if (rawRequestId && !normalizedRequestId) {
    return {ok: false, reason: `${participantKey}_search_request_mismatch`};
  }
  if (
    normalizedRequestId &&
    normalizeString(requestData[SEARCH_REQUEST_FIELD.REQUEST_ID]) !==
      normalizedRequestId
  ) {
    return {ok: false, reason: `${participantKey}_search_request_mismatch`};
  }
  const normalizedExpectedLanguage = readLanguageCode(expectedLanguage);
  if (
    normalizedExpectedLanguage &&
    readLanguageCode(requestData[SEARCH_REQUEST_FIELD.LANGUAGE]) !==
      normalizedExpectedLanguage
  ) {
    return {ok: false, reason: `${participantKey}_search_language_mismatch`};
  }

  if (hasSearchRequestSessionState(requestData)) {
    return {ok: false, reason: `${participantKey}_search_in_session`};
  }
  if (hasLiveSearchRequestLock(requestData, nowMillis)) {
    return {ok: false, reason: `${participantKey}_search_locked`};
  }

  const status = normalizeString(requestData[SEARCH_REQUEST_FIELD.STATUS]);
  const canReserveStatus = [
    SEARCH_REQUEST_STATUS.ACTIVE,
    SEARCH_REQUEST_STATUS.LEGACY_SEARCHING,
  ].includes(status) ||
    (
      status === SEARCH_REQUEST_STATUS.MATCHING &&
      !hasLiveSearchRequestLock(requestData, nowMillis)
    );
  if (!canReserveStatus) {
    return {
      ok: false,
      reason: `${participantKey}_search_status_${status || "missing"}`,
    };
  }
  if (!isSearchRequestFreshForPairLock(requestData, nowMillis)) {
    return {ok: false, reason: `${participantKey}_search_stale`};
  }

  return {ok: true, reason: "ready"};
}

function validateUserForPairLock({
  userExists = false,
  userData = {},
  expectedRole = "",
  participantKey = "requester",
}) {
  if (!userExists) {
    return {ok: false, reason: `${participantKey}_user_missing`};
  }
  if (userData.isInCall === true) {
    return {ok: false, reason: `${participantKey}_in_call`};
  }
  if (normalizeString(userData.currentSessionId)) {
    return {ok: false, reason: `${participantKey}_in_session`};
  }

  const normalizedExpectedRole = normalizeRole(expectedRole);
  const normalizedUserRole = normalizeRole(userData.role);
  if (
    normalizedExpectedRole &&
    normalizedUserRole !== normalizedExpectedRole
  ) {
    return {ok: false, reason: `${participantKey}_role_mismatch`};
  }

  return {ok: true, reason: "ready"};
}

function isAvailableAfterInFutureForPairLock(userData = {}, nowMillis) {
  const availableAfterMillis = timestampToMillis(userData.availableAfter);
  return availableAfterMillis !== null && availableAfterMillis > nowMillis;
}

function validateDirectPairAccessForLock({
  requesterId,
  requesterData = {},
  requesterUsageData = null,
  requesterTrialData = null,
  responderId,
  responderData = {},
  language = "",
  nowMillis = Date.now(),
}) {
  const requesterRole = normalizeRole(requesterData.role);
  const accessDecision = buildStudentCallAccessDecision({
    userRole: requesterRole,
    userData: requesterData,
    trialData: requesterTrialData,
    usageData: requesterUsageData,
    nowMillis,
  });
  if (!accessDecision.allowed) {
    return {
      ok: false,
      reason: `requester_${accessDecision.reason}`,
    };
  }

  const requesterBlockedIds = extractBlockedIds(requesterData.blockedUsers);
  if (requesterBlockedIds.includes(responderId)) {
    return {ok: false, reason: "requester_blocked_responder"};
  }

  const responderBlockedIds = extractBlockedIds(responderData.blockedUsers);
  if (responderBlockedIds.includes(requesterId)) {
    return {ok: false, reason: "responder_blocked_requester"};
  }

  const normalizedLanguage = readLanguageCode(language);
  if (!normalizedLanguage) {
    return {ok: false, reason: "missing_language"};
  }

  if (!supportsConversationLanguage(responderData, normalizedLanguage)) {
    return {ok: false, reason: "responder_language_mismatch"};
  }

  const responderProfile = buildMatchProfile(
    responderId,
    responderData,
    normalizedLanguage,
  );
  if (!responderProfile.approvedTeacher) {
    return {ok: false, reason: "responder_unapproved_teacher"};
  }

  if (isAvailableAfterInFutureForPairLock(responderData, nowMillis)) {
    return {ok: false, reason: "responder_available_after_in_future"};
  }

  return {ok: true, reason: "ready", mode: accessDecision.mode};
}

function buildPairAttemptId({
  sessionId = "",
  requesterId = "",
  responderId = "",
}) {
  return [
    "pair",
    normalizeDocumentId(sessionId),
    normalizeDocumentId(requesterId),
    normalizeDocumentId(responderId),
  ].filter(Boolean).join("_");
}

function buildParticipantIds(requesterId, responderId) {
  return Array.from(new Set([
    normalizeDocumentId(requesterId),
    normalizeDocumentId(responderId),
  ].filter(Boolean))).sort();
}

function buildParticipantInfo(userData = {}) {
  return {
    displayName:
      normalizeString(userData.display_name) ||
      normalizeString(userData.displayName) ||
      null,
    photoUrl:
      normalizeString(userData.photo_url) ||
      normalizeString(userData.photoUrl) ||
      null,
  };
}

function resolveMatchProtocolVersion({
  requestedVersion = 1,
  requesterSearchData = {},
  responderSearchData = null,
  responderRole = "student",
  responderCapabilityVersion = 1,
  responderCallKitCapable = false,
  responderCapabilityExpiresAt = null,
  nowMillis = Date.now(),
} = {}) {
  if (
    !supportsMatchProtocolV2(requestedVersion) ||
    !supportsMatchProtocolV2(requesterSearchData.matchProtocolVersion)
  ) {
    return 1;
  }
  if (
    normalizeRole(responderRole) === "student" &&
    !supportsMatchProtocolV2(responderSearchData?.matchProtocolVersion)
  ) {
    return 1;
  }
  if (
    normalizeRole(responderRole) === "native_speaker" &&
    (
      !supportsMatchProtocolV2(responderCapabilityVersion) ||
      responderCallKitCapable !== true ||
      (timestampToMillis(responderCapabilityExpiresAt) || 0) <= nowMillis
    )
  ) {
    return 1;
  }
  return MATCH_PROTOCOL_VERSION;
}

function buildLegacySessionUserInfo(participantInfo = {}, fallbackName) {
  return {
    name: normalizeString(participantInfo.displayName) || fallbackName,
    photo: normalizeString(participantInfo.photoUrl) || null,
  };
}

function buildSearchRequestPairLockUpdate({
  sessionId,
  pairAttemptId,
  otherUserId,
  otherRole,
  matchedResponderId,
  serverTimestamp,
  lockExpiresAt,
  excludedCandidateIds,
}) {
  const update = {
    [SEARCH_REQUEST_FIELD.STATUS]: SEARCH_REQUEST_STATUS.MATCHED,
    [SEARCH_REQUEST_FIELD.UPDATED_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.CURRENT_SESSION_ID]: sessionId,
    [SEARCH_REQUEST_FIELD.MATCHED_SESSION_ID]: sessionId,
    [SEARCH_REQUEST_FIELD.MATCHED_USER_ID]: otherUserId,
    [SEARCH_REQUEST_FIELD.MATCHED_RESPONDER_ID]: matchedResponderId,
    [SEARCH_REQUEST_FIELD.MATCHED_ROLE]: otherRole,
    [SEARCH_REQUEST_FIELD.PAIR_ATTEMPT_ID]: pairAttemptId,
    [SEARCH_REQUEST_FIELD.RESTORED_FROM_SESSION_ID]: null,
    [SEARCH_REQUEST_FIELD.RESTORED_FROM_PAIR_ATTEMPT_ID]: null,
    [SEARCH_REQUEST_FIELD.LOCK_OWNER]: pairAttemptId,
    [SEARCH_REQUEST_FIELD.LOCK_EXPIRES_AT]: lockExpiresAt,
    [SEARCH_REQUEST_FIELD.LAST_ERROR]: null,
  };
  if (Array.isArray(excludedCandidateIds)) {
    update[SEARCH_REQUEST_FIELD.EXCLUDED_CANDIDATE_IDS] =
      readCandidateIdList(excludedCandidateIds);
  }
  return update;
}

function buildVideoSessionPairLockData({
  sessionData = {},
  requesterId,
  responderId,
  requesterRole = "student",
  responderRole,
  sessionId,
  pairAttemptId,
  requesterSearchRequestId = "",
  responderSearchRequestId = "",
  participantInfos = {},
  serverTimestamp,
  lockExpiresAt,
  finalizationExpiresAt = null,
  matchProtocolVersion = 1,
  autoAcceptForegroundStudents = false,
}) {
  const participantIds = buildParticipantIds(requesterId, responderId);
  const scenario = responderRole === "student" ?
    "student_student" :
    "student_teacher";
  const sessionStatus = VIDEO_SESSION_STATUS.PENDING_CONFIRMATION;
  const triedTutors = Array.isArray(sessionData.triedTutors) ?
    sessionData.triedTutors :
    [];
  const availableTutors = Array.isArray(sessionData.availableTutors) ?
    sessionData.availableTutors :
    [responderId];
  const requesterInfo =
    participantInfos[requesterId] || {};
  const responderInfo =
    participantInfos[responderId] || {};
  const protocolVersion = supportsMatchProtocolV2(matchProtocolVersion) ?
    MATCH_PROTOCOL_VERSION :
    1;
  const participantRoles = {
    [requesterId]: requesterRole,
    [responderId]: responderRole,
  };
  let participantStates = protocolVersion === MATCH_PROTOCOL_VERSION ?
    buildInitialParticipantStates({
      participantIds,
      participantRoles,
      callKitIds: Object.fromEntries(participantIds.map((participantId) => [
        participantId,
        buildCallKitIdForMatchParticipant({
          sessionId,
          pairAttemptId,
          participantId,
        }),
      ])),
    }) :
    null;
  const shouldAutoFinalize =
    protocolVersion === MATCH_PROTOCOL_VERSION &&
    scenario === "student_student" &&
    autoAcceptForegroundStudents === true;
  if (shouldAutoFinalize) {
    participantStates = Object.fromEntries(
      participantIds.map((participantId) => [
        participantId,
        transitionParticipantState({
          state: participantStates[participantId],
          role: participantRoles[participantId],
          action: MATCH_ACTION.CLAIM_IN_APP,
          actionId: `pair_lock:${pairAttemptId}:${participantId}`,
          updatedAt: serverTimestamp,
        }).state,
      ]),
    );
  }
  const sessionDeadline = shouldAutoFinalize ?
    finalizationExpiresAt || lockExpiresAt :
    lockExpiresAt;

  return {
    ...sessionData,
    matchProtocolVersion: protocolVersion,
    status: sessionStatus,
    pairStatus: VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
    sessionId,
    requesterId,
    responderId,
    currentResponderId: responderId,
    currentResponderRole: responderRole,
    currentTutorId: responderId,
    requesterRole,
    responderRole,
    participantIds,
    participantRoles,
    participantInfos,
    requesterInfo,
    responderInfo,
    studentId: requesterId,
    studentInfo:
      sessionData.studentInfo ||
      buildLegacySessionUserInfo(requesterInfo, "Student"),
    tutorId: responderRole === "native_speaker" ? responderId : null,
    tutorInfo:
      sessionData.tutorInfo ||
      buildLegacySessionUserInfo(responderInfo, "Partner"),
    scenario,
    pairAttemptId,
    responseExpiresAt: sessionDeadline,
    confirmationExpiresAt: sessionDeadline,
    searchRequestIds: {
      requester: normalizeString(requesterSearchRequestId) || null,
      responder: normalizeString(responderSearchRequestId) || null,
    },
    triedTutors,
    availableTutors,
    createdAt: serverTimestamp,
    updatedAt: serverTimestamp,
    matchLock: {
      owner: pairAttemptId,
      expiresAt: sessionDeadline,
      participantIds,
    },
    ...(protocolVersion === MATCH_PROTOCOL_VERSION ? {
      matchProtocolVersion: MATCH_PROTOCOL_VERSION,
      matchStage: shouldAutoFinalize ?
        MATCH_STAGE.FINALIZATION_REQUESTED :
        MATCH_STAGE.AWAITING_INITIAL_DISPATCH,
      participantStates,
      ...(shouldAutoFinalize ? {
        matchFinalization: {
          status: "requested",
          pairAttemptId,
          requestedBy: requesterId,
          actionId: `pair_lock:${pairAttemptId}`,
          requestedAt: serverTimestamp,
          expiresAt: sessionDeadline,
        },
      } : {}),
    } : {}),
  };
}

function buildPairLockFailure(reason) {
  return {
    locked: false,
    reason,
  };
}

function readSessionRequesterId(sessionData = {}) {
  return normalizeDocumentId(sessionData.requesterId) ||
    normalizeDocumentId(sessionData.studentId) ||
    normalizeDocumentId(sessionData.matchContext?.requesterId);
}

function readSessionSearchRequestId(sessionData = {}, participantKey = "") {
  return normalizeString(sessionData.searchRequestIds?.[participantKey]);
}

function getSessionParticipantIds(sessionData = {}) {
  return Array.from(new Set([
    ...(Array.isArray(sessionData.participantIds) ?
      sessionData.participantIds :
      []),
    sessionData.studentId,
    sessionData.requesterId,
    sessionData.currentTutorId,
    sessionData.currentResponderId,
    sessionData.responderId,
    sessionData.tutorId,
    sessionData.matchContext?.requesterId,
    sessionData.matchContext?.acceptedResponderId,
  ].map(normalizeDocumentId).filter(Boolean))).sort();
}

function searchRequestMatchesSession(requestData = {}, sessionId = "") {
  const normalizedSessionId = normalizeDocumentId(sessionId);
  return [
    requestData.activeSessionId,
    requestData.currentSessionId,
    requestData.matchedSessionId,
    requestData.sessionId,
    requestData.videoSessionId,
  ].map(normalizeString).includes(normalizedSessionId);
}

function validateRequesterSearchForExistingSessionPairLock({
  requestExists = false,
  requestData = {},
  userId = "",
  requestId = "",
  sessionId = "",
  expectedLanguage = "",
  nowMillis = Date.now(),
}) {
  if (!requestExists) {
    return {ok: false, reason: "requester_search_request_missing"};
  }
  if (!searchRequestBelongsToUser(requestData, userId)) {
    return {ok: false, reason: "requester_search_owner_mismatch"};
  }

  const rawRequestId = normalizeString(requestId);
  const normalizedRequestId = normalizeDocumentId(requestId);
  if (!rawRequestId) {
    return {ok: false, reason: "requester_search_request_id_required"};
  }
  if (!normalizedRequestId) {
    return {ok: false, reason: "requester_search_request_mismatch"};
  }
  if (
    normalizeString(requestData[SEARCH_REQUEST_FIELD.REQUEST_ID]) !==
      normalizedRequestId
  ) {
    return {ok: false, reason: "requester_search_request_mismatch"};
  }
  const normalizedExpectedLanguage = readLanguageCode(expectedLanguage);
  if (
    normalizedExpectedLanguage &&
    readLanguageCode(requestData[SEARCH_REQUEST_FIELD.LANGUAGE]) !==
      normalizedExpectedLanguage
  ) {
    return {ok: false, reason: "requester_search_language_mismatch"};
  }

  const sessionIds = [
    requestData.activeSessionId,
    requestData.currentSessionId,
    requestData.matchedSessionId,
  ].map(normalizeString).filter(Boolean);
  if (
    sessionIds.length > 0 &&
    !sessionIds.every((requestSessionId) => requestSessionId === sessionId)
  ) {
    return {ok: false, reason: "requester_search_in_other_session"};
  }

  const status = normalizeString(requestData[SEARCH_REQUEST_FIELD.STATUS]);
  const canReserveRequesterStatus = [
    SEARCH_REQUEST_STATUS.ACTIVE,
    SEARCH_REQUEST_STATUS.MATCHING,
    SEARCH_REQUEST_STATUS.LEGACY_SEARCHING,
  ].includes(status) ||
    (status === SEARCH_REQUEST_STATUS.MATCHED && sessionIds.length > 0);
  if (!canReserveRequesterStatus) {
    return {
      ok: false,
      reason: `requester_search_status_${status || "missing"}`,
    };
  }
  if (!isSearchRequestFreshForPairLock(requestData, nowMillis)) {
    return {ok: false, reason: "requester_search_stale"};
  }

  return {ok: true, reason: "ready"};
}

function validateRequesterUserForExistingSessionPairLock({
  userExists = false,
  userData = {},
  sessionId = "",
}) {
  if (!userExists) {
    return {ok: false, reason: "requester_user_missing"};
  }
  if (userData.isInCall === true) {
    return {ok: false, reason: "requester_in_call"};
  }

  const currentSessionId = normalizeString(userData.currentSessionId);
  if (currentSessionId && currentSessionId !== sessionId) {
    return {ok: false, reason: "requester_in_other_session"};
  }

  const normalizedUserRole = normalizeRole(userData.role);
  if (normalizedUserRole !== "student") {
    return {ok: false, reason: "requester_role_mismatch"};
  }

  return {ok: true, reason: "ready"};
}

function buildSearchRequestPairLockReleaseUpdate({
  status = SEARCH_REQUEST_STATUS.STOPPED,
  stopReason = "session_finished",
  serverTimestamp,
  fieldDelete,
}) {
  return {
    [SEARCH_REQUEST_FIELD.STATUS]: status,
    [SEARCH_REQUEST_FIELD.STOP_REASON]: stopReason,
    [SEARCH_REQUEST_FIELD.STOPPED_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.UPDATED_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.ACTIVE_SESSION_ID]: fieldDelete,
    [SEARCH_REQUEST_FIELD.CURRENT_SESSION_ID]: null,
    [SEARCH_REQUEST_FIELD.MATCHED_SESSION_ID]: fieldDelete,
    [SEARCH_REQUEST_FIELD.MATCHED_USER_ID]: null,
    [SEARCH_REQUEST_FIELD.MATCHED_RESPONDER_ID]: fieldDelete,
    [SEARCH_REQUEST_FIELD.MATCHED_ROLE]: null,
    [SEARCH_REQUEST_FIELD.PAIR_ATTEMPT_ID]: null,
    [SEARCH_REQUEST_FIELD.RESTORED_FROM_SESSION_ID]: fieldDelete,
    [SEARCH_REQUEST_FIELD.RESTORED_FROM_PAIR_ATTEMPT_ID]: fieldDelete,
    [SEARCH_REQUEST_FIELD.ATTEMPT_EXCLUDED_CANDIDATE_IDS]: [],
    [SEARCH_REQUEST_FIELD.LOCK_OWNER]: null,
    [SEARCH_REQUEST_FIELD.LOCK_EXPIRES_AT]: null,
    [SEARCH_REQUEST_FIELD.LAST_ERROR]: null,
    [SEARCH_REQUEST_FIELD.ERROR_CODE]: fieldDelete,
    [SEARCH_REQUEST_FIELD.ERROR_MESSAGE]: fieldDelete,
  };
}

function readCandidateIdList(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.map((entry) => {
    if (typeof entry === "string") {
      return normalizeDocumentId(entry);
    }
    if (entry && typeof entry.id === "string") {
      return normalizeDocumentId(entry.id);
    }
    if (entry && typeof entry.path === "string") {
      const pathParts = entry.path.split("/");
      return normalizeDocumentId(pathParts[pathParts.length - 1]);
    }
    return "";
  }).filter(Boolean);
}

function buildSearchRequestActiveRestoreUpdate({
  requestData = {},
  excludedCandidateIds = [],
  restoredFromSessionId = "",
  restoredFromPairAttemptId = "",
  serverTimestamp,
  fieldDelete,
}) {
  const nextExcludedCandidateIds = Array.from(new Set([
    ...readCandidateIdList(
      requestData[SEARCH_REQUEST_FIELD.EXCLUDED_CANDIDATE_IDS],
    ),
    ...readCandidateIdList(excludedCandidateIds),
  ])).sort();

  return {
    [SEARCH_REQUEST_FIELD.STATUS]: SEARCH_REQUEST_STATUS.ACTIVE,
    [SEARCH_REQUEST_FIELD.UPDATED_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.HEARTBEAT_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.ACTIVE_SESSION_ID]: fieldDelete,
    [SEARCH_REQUEST_FIELD.CURRENT_SESSION_ID]: null,
    [SEARCH_REQUEST_FIELD.MATCHED_SESSION_ID]: fieldDelete,
    [SEARCH_REQUEST_FIELD.MATCHED_USER_ID]: null,
    [SEARCH_REQUEST_FIELD.MATCHED_RESPONDER_ID]: fieldDelete,
    [SEARCH_REQUEST_FIELD.MATCHED_ROLE]: null,
    [SEARCH_REQUEST_FIELD.PAIR_ATTEMPT_ID]: null,
    [SEARCH_REQUEST_FIELD.RESTORED_FROM_SESSION_ID]:
      normalizeDocumentId(restoredFromSessionId) || null,
    [SEARCH_REQUEST_FIELD.RESTORED_FROM_PAIR_ATTEMPT_ID]:
      normalizeDocumentId(restoredFromPairAttemptId) || null,
    [SEARCH_REQUEST_FIELD.EXCLUDED_CANDIDATE_IDS]: nextExcludedCandidateIds,
    [SEARCH_REQUEST_FIELD.ATTEMPT_EXCLUDED_CANDIDATE_IDS]: [],
    [SEARCH_REQUEST_FIELD.LOCK_OWNER]: null,
    [SEARCH_REQUEST_FIELD.LOCK_EXPIRES_AT]: null,
    [SEARCH_REQUEST_FIELD.STOP_REASON]: null,
    [SEARCH_REQUEST_FIELD.STOPPED_AT]: null,
    [SEARCH_REQUEST_FIELD.STOPPED_BY]: fieldDelete,
    [SEARCH_REQUEST_FIELD.LAST_ERROR]: null,
    [SEARCH_REQUEST_FIELD.ERROR_CODE]: fieldDelete,
    [SEARCH_REQUEST_FIELD.ERROR_MESSAGE]: fieldDelete,
  };
}

function canRestoreSearchRequestToActive(requestData = {}) {
  return [
    SEARCH_REQUEST_STATUS.ACTIVE,
    SEARCH_REQUEST_STATUS.MATCHING,
    SEARCH_REQUEST_STATUS.MATCHED,
    SEARCH_REQUEST_STATUS.LEGACY_SEARCHING,
  ].includes(normalizeString(requestData[SEARCH_REQUEST_FIELD.STATUS]));
}

function buildUserPairLockReleaseUpdate({
  serverTimestamp,
  fieldDelete,
  releaseCallState = false,
  restoreLegacyAvailability = false,
}) {
  const update = {
    currentSessionId: fieldDelete,
    updatedAt: serverTimestamp,
  };
  if (releaseCallState) {
    update.isInCall = false;
    update.availableAfter = fieldDelete;
    update.lastCallEndedAt = serverTimestamp;
  }
  if (restoreLegacyAvailability) {
    update.isAvailable = true;
  }
  return update;
}

async function readPairLockReleaseTargetsInTransaction({
  db,
  transaction,
  sessionId,
  sessionData = {},
  participantIds = [],
}) {
  const ids = Array.from(new Set([
    ...getSessionParticipantIds(sessionData),
    ...participantIds.map(normalizeDocumentId).filter(Boolean),
  ])).sort();
  const refs = ids.map((participantId) => ({
    participantId,
    userRef: db.collection(USER_COLLECTION).doc(participantId),
    searchRef: db.collection(SEARCH_REQUEST_COLLECTION).doc(participantId),
  }));
  const snapshots = await Promise.all(refs.map(async (target) => ({
    ...target,
    userSnap: await transaction.get(target.userRef),
    searchSnap: await transaction.get(target.searchRef),
  })));

  return snapshots.map((target) => ({
    ...target,
    userData: target.userSnap.exists ? target.userSnap.data() || {} : {},
    searchData: target.searchSnap.exists ?
      target.searchSnap.data() || {} :
      {},
    sessionId,
  }));
}

async function readSearchRequestReleaseTargetsInTransaction({
  db,
  transaction,
  sessionData = {},
  participantIds = [],
}) {
  const ids = Array.from(new Set([
    ...getSessionParticipantIds(sessionData),
    ...participantIds.map(normalizeDocumentId).filter(Boolean),
  ])).sort();
  const refs = ids.map((participantId) => ({
    participantId,
    searchRef: db.collection(SEARCH_REQUEST_COLLECTION).doc(participantId),
  }));
  const snapshots = await Promise.all(refs.map(async (target) => ({
    ...target,
    searchSnap: await transaction.get(target.searchRef),
  })));

  return snapshots.map((target) => ({
    ...target,
    searchData: target.searchSnap.exists ?
      target.searchSnap.data() || {} :
      {},
  }));
}

function applyPairLockReleaseWrites({
  transaction,
  targets = [],
  sessionId,
  serverTimestamp,
  fieldDelete,
  searchRequestStatus = SEARCH_REQUEST_STATUS.STOPPED,
  stopReason = "session_finished",
  releaseCallState = false,
  restoreLegacyAvailability = false,
  restoreSearchParticipantIds = [],
  restoreSearchExcludedCandidateIdsByParticipantId = {},
  restoredFromPairAttemptId = "",
}) {
  const restoreParticipantIdSet = new Set(
    restoreSearchParticipantIds.map(normalizeDocumentId).filter(Boolean),
  );
  const restoreExcludedIdsByParticipantId = Object.fromEntries(
    Object.entries(restoreSearchExcludedCandidateIdsByParticipantId || {})
      .map(([participantId, excludedIds]) => [
        normalizeDocumentId(participantId),
        excludedIds,
      ])
      .filter(([participantId]) => Boolean(participantId)),
  );

  for (const target of targets) {
    if (
      target.userSnap.exists &&
      normalizeString(target.userData.currentSessionId) === sessionId
    ) {
      transaction.update(target.userRef, buildUserPairLockReleaseUpdate({
        serverTimestamp,
        fieldDelete,
        releaseCallState,
        restoreLegacyAvailability,
      }));
    }

    if (
      target.searchSnap.exists &&
      searchRequestMatchesSession(target.searchData, sessionId)
    ) {
      if (
        restoreParticipantIdSet.has(target.participantId) &&
        canRestoreSearchRequestToActive(target.searchData)
      ) {
        transaction.update(target.searchRef, buildSearchRequestActiveRestoreUpdate({
          requestData: target.searchData,
          excludedCandidateIds:
            restoreExcludedIdsByParticipantId[
              target.participantId
            ] || [],
          restoredFromSessionId: sessionId,
          restoredFromPairAttemptId,
          serverTimestamp,
          fieldDelete,
        }));
      } else {
        transaction.update(target.searchRef, buildSearchRequestPairLockReleaseUpdate({
          status: searchRequestStatus,
          stopReason,
          serverTimestamp,
          fieldDelete,
        }));
      }
    }
  }
}

async function stopSessionSearchRequestsInTransaction({
  db,
  transaction,
  sessionId,
  sessionData = {},
  participantIds = [],
  serverTimestamp,
  fieldDelete = admin.firestore.FieldValue.delete(),
  stopReason = "call_started",
}) {
  const normalizedSessionId = normalizeDocumentId(sessionId);
  if (!normalizedSessionId) {
    return {stopped: false, reason: "invalid_session_id"};
  }

  const targets = await readSearchRequestReleaseTargetsInTransaction({
    db,
    transaction,
    sessionData,
    participantIds,
  });
  const stoppedParticipantIds = [];
  for (const target of targets) {
    if (
      target.searchSnap.exists &&
      searchRequestMatchesSession(target.searchData, normalizedSessionId)
    ) {
      transaction.update(target.searchRef, buildSearchRequestPairLockReleaseUpdate({
        status: SEARCH_REQUEST_STATUS.STOPPED,
        stopReason,
        serverTimestamp,
        fieldDelete,
      }));
      stoppedParticipantIds.push(target.participantId);
    }
  }

  return {
    stopped: true,
    reason: "stopped",
    participantIds: targets.map((target) => target.participantId),
    stoppedParticipantIds,
  };
}

async function releaseSessionPairLocksInTransaction({
  db,
  transaction,
  sessionId,
  sessionData = {},
  participantIds = [],
  serverTimestamp,
  fieldDelete = admin.firestore.FieldValue.delete(),
  searchRequestStatus = SEARCH_REQUEST_STATUS.STOPPED,
  stopReason = "session_finished",
  releaseCallState = false,
  restoreLegacyAvailability = false,
  restoreSearchParticipantIds = [],
  restoreSearchExcludedCandidateIdsByParticipantId = {},
}) {
  const normalizedSessionId = normalizeDocumentId(sessionId);
  if (!normalizedSessionId) {
    return {released: false, reason: "invalid_session_id"};
  }

  const targets = await readPairLockReleaseTargetsInTransaction({
    db,
    transaction,
    sessionId: normalizedSessionId,
    sessionData,
    participantIds,
  });
  applyPairLockReleaseWrites({
    transaction,
    targets,
    sessionId: normalizedSessionId,
    serverTimestamp,
    fieldDelete,
    searchRequestStatus,
    stopReason,
    releaseCallState,
    restoreLegacyAvailability,
    restoreSearchParticipantIds,
    restoreSearchExcludedCandidateIdsByParticipantId,
    restoredFromPairAttemptId: sessionData.pairAttemptId,
  });
  return {
    released: true,
    reason: "released",
    participantIds: targets.map((target) => target.participantId),
  };
}

async function prepareExistingSessionNextResponderPairLockInTransaction({
  db,
  transaction,
  sessionId,
  sessionData = {},
  currentResponderId = "",
  responderId,
  responderRole,
  requesterSearchRequestId = "",
  responderSearchRequestId = "",
  expectedLanguage = "",
  triedTutors = [],
  nowMillis = Date.now(),
  serverTimestamp,
  lockExpiresAt,
  fieldDelete = admin.firestore.FieldValue.delete(),
  currentResponderSearchRequestStatus = SEARCH_REQUEST_STATUS.STOPPED,
  currentResponderStopReason = "responder_skipped",
  requesterExcludedCandidateIds = [],
  pairAttemptId = "",
}) {
  const normalizedSessionId = normalizeDocumentId(sessionId);
  const normalizedRequesterId = readSessionRequesterId(sessionData);
  const normalizedCurrentResponderId = normalizeDocumentId(currentResponderId);
  const normalizedResponderId = normalizeDocumentId(responderId);
  const normalizedResponderRole = normalizeRole(responderRole);
  const normalizedRequesterSearchRequestId =
    normalizeString(requesterSearchRequestId) ||
    readSessionSearchRequestId(sessionData, "requester");
  const normalizedExpectedLanguage =
    readLanguageCode(expectedLanguage) || readLanguageCode(sessionData.language);

  if (
    !normalizedSessionId ||
    !normalizedRequesterId ||
    !normalizedResponderId ||
    normalizedRequesterId === normalizedResponderId ||
    normalizedCurrentResponderId === normalizedResponderId ||
    !["student", "native_speaker"].includes(normalizedResponderRole)
  ) {
    return buildPairLockFailure("invalid_pair_lock_input");
  }
  if (normalizeString(pairAttemptId) && !normalizeDocumentId(pairAttemptId)) {
    return buildPairLockFailure("invalid_pair_lock_input");
  }
  if (Number(sessionData.matchProtocolVersion) >= MATCH_PROTOCOL_VERSION) {
    return buildPairLockFailure("v2_requires_new_session");
  }

  const requesterUserRef = db
    .collection(USER_COLLECTION)
    .doc(normalizedRequesterId);
  const responderUserRef = db
    .collection(USER_COLLECTION)
    .doc(normalizedResponderId);
  const requesterSearchRef = db
    .collection(SEARCH_REQUEST_COLLECTION)
    .doc(normalizedRequesterId);
  const responderSearchRef = normalizedResponderRole === "student" ?
    db.collection(SEARCH_REQUEST_COLLECTION).doc(normalizedResponderId) :
    null;
  const responderPrivateTokenRef =
    normalizedResponderRole === "native_speaker" ?
      db.collection(PRIVATE_TOKEN_COLLECTION).doc(normalizedResponderId) :
      null;
  const currentResponderReleaseTargets = normalizedCurrentResponderId ?
    await readPairLockReleaseTargetsInTransaction({
      db,
      transaction,
      sessionId: normalizedSessionId,
      sessionData: {},
      participantIds: [normalizedCurrentResponderId],
    }) :
    [];

  const [
    requesterUserSnapshot,
    responderUserSnapshot,
    requesterSearchSnapshot,
    responderSearchSnapshot,
    responderPrivateTokenSnapshot,
  ] = await Promise.all([
    transaction.get(requesterUserRef),
    transaction.get(responderUserRef),
    transaction.get(requesterSearchRef),
    responderSearchRef ? transaction.get(responderSearchRef) : null,
    responderPrivateTokenRef ?
      transaction.get(responderPrivateTokenRef) :
      null,
  ]);

  const requesterUserData = requesterUserSnapshot.exists ?
    requesterUserSnapshot.data() || {} :
    {};
  const responderUserData = responderUserSnapshot.exists ?
    responderUserSnapshot.data() || {} :
    {};
  const requesterUserValidation =
    validateRequesterUserForExistingSessionPairLock({
      userExists: requesterUserSnapshot.exists,
      userData: requesterUserData,
      sessionId: normalizedSessionId,
    });
  if (!requesterUserValidation.ok) {
    return buildPairLockFailure(requesterUserValidation.reason);
  }

  const responderUserValidation = validateUserForPairLock({
    userExists: responderUserSnapshot.exists,
    userData: responderUserData,
    expectedRole: normalizedResponderRole,
    participantKey: "responder",
  });
  if (!responderUserValidation.ok) {
    return buildPairLockFailure(responderUserValidation.reason);
  }

  const requesterSearchValidation =
    validateRequesterSearchForExistingSessionPairLock({
      requestExists: requesterSearchSnapshot.exists,
      requestData: requesterSearchSnapshot.exists ?
        requesterSearchSnapshot.data() || {} :
        {},
      userId: normalizedRequesterId,
      requestId: normalizedRequesterSearchRequestId,
      sessionId: normalizedSessionId,
      expectedLanguage: normalizedExpectedLanguage,
      nowMillis,
    });
  if (!requesterSearchValidation.ok) {
    return buildPairLockFailure(requesterSearchValidation.reason);
  }

  let finalResponderSearchRequestId = "";
  if (responderSearchRef) {
    finalResponderSearchRequestId = normalizeString(
      responderSearchRequestId ||
        responderSearchSnapshot?.data()?.[SEARCH_REQUEST_FIELD.REQUEST_ID],
    );
    const responderSearchValidation = validateSearchRequestForPairLock({
      requestExists: responderSearchSnapshot.exists,
      requestData: responderSearchSnapshot.exists ?
        responderSearchSnapshot.data() || {} :
        {},
      userId: normalizedResponderId,
      requestId: finalResponderSearchRequestId,
      expectedLanguage: normalizedExpectedLanguage,
      requireRequestId: true,
      nowMillis,
      participantKey: "responder",
    });
    if (!responderSearchValidation.ok) {
      return buildPairLockFailure(responderSearchValidation.reason);
    }
  }

  const finalPairAttemptId = normalizeDocumentId(pairAttemptId) ||
    buildPairAttemptId({
      sessionId: normalizedSessionId,
      requesterId: normalizedRequesterId,
      responderId: normalizedResponderId,
    });
  const participantIds = buildParticipantIds(
    normalizedRequesterId,
    normalizedResponderId,
  );
  const requesterInfo = buildParticipantInfo(requesterUserData);
  const responderInfo = buildParticipantInfo(responderUserData);
  const participantInfos = {
    [normalizedRequesterId]: requesterInfo,
    [normalizedResponderId]: responderInfo,
  };
  const participantRoles = {
    [normalizedRequesterId]: "student",
    [normalizedResponderId]: normalizedResponderRole,
  };
  const scenario = normalizedResponderRole === "student" ?
    "student_student" :
    "student_teacher";
  const sessionUpdate = {
    status: VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
    pairStatus: VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
    requesterId: normalizedRequesterId,
    requesterRole: "student",
    responderId: normalizedResponderId,
    responderRole: normalizedResponderRole,
    currentResponderId: normalizedResponderId,
    currentResponderRole: normalizedResponderRole,
    currentTutorId: normalizedResponderId,
    participantIds,
    participantRoles,
    participantInfos,
    requesterInfo,
    responderInfo,
    studentInfo: buildLegacySessionUserInfo(requesterInfo, "Student"),
    tutorInfo: buildLegacySessionUserInfo(responderInfo, "Partner"),
    tutorId: normalizedResponderRole === "native_speaker" ?
      normalizedResponderId :
      null,
    scenario,
    pairAttemptId: finalPairAttemptId,
    responseExpiresAt: lockExpiresAt,
    confirmationExpiresAt: lockExpiresAt,
    acceptingTutorId: fieldDelete,
    acceptingAt: fieldDelete,
    acceptAttemptId: fieldDelete,
    searchRequestIds: {
      requester: normalizedRequesterSearchRequestId,
      responder: finalResponderSearchRequestId || null,
    },
    triedTutors,
    updatedAt: serverTimestamp,
    matchLock: {
      owner: finalPairAttemptId,
      expiresAt: lockExpiresAt,
      participantIds,
    },
    "matchContext.selectedResponderId": normalizedResponderId,
    "matchContext.selectedResponderRole": normalizedResponderRole,
  };
  const requesterLockUpdate = buildSearchRequestPairLockUpdate({
    sessionId: normalizedSessionId,
    pairAttemptId: finalPairAttemptId,
    otherUserId: normalizedResponderId,
    otherRole: normalizedResponderRole,
    matchedResponderId: normalizedResponderId,
    serverTimestamp,
    lockExpiresAt,
    excludedCandidateIds: Array.from(new Set([
      ...readCandidateIdList(
        requesterSearchSnapshot.data()?.[
          SEARCH_REQUEST_FIELD.EXCLUDED_CANDIDATE_IDS
        ],
      ),
      ...readCandidateIdList(requesterExcludedCandidateIds),
    ])).sort(),
  });
  const responderLockUpdate = responderSearchRef ?
    buildSearchRequestPairLockUpdate({
      sessionId: normalizedSessionId,
      pairAttemptId: finalPairAttemptId,
      otherUserId: normalizedRequesterId,
      otherRole: "student",
      matchedResponderId: normalizedResponderId,
      serverTimestamp,
      lockExpiresAt,
    }) :
    null;

  return {
    locked: true,
    reason: "locked",
    sessionId: normalizedSessionId,
    pairAttemptId: finalPairAttemptId,
    requesterId: normalizedRequesterId,
    responderId: normalizedResponderId,
    responderRole: normalizedResponderRole,
    writes: {
      sessionRef: db
        .collection(VIDEO_SESSION_COLLECTION)
        .doc(normalizedSessionId),
      sessionUpdate,
      requesterSearchRef,
      requesterLockUpdate,
      requesterUserRef,
      requesterUserUpdate: {
        currentSessionId: normalizedSessionId,
        updatedAt: serverTimestamp,
      },
      responderUserRef,
      responderUserUpdate: {
        currentSessionId: normalizedSessionId,
        updatedAt: serverTimestamp,
      },
      responderSearchRef,
      responderLockUpdate,
      currentResponderReleaseTargets,
      currentResponderReleaseOptions: {
        sessionId: normalizedSessionId,
        serverTimestamp,
        fieldDelete,
        searchRequestStatus: currentResponderSearchRequestStatus,
        stopReason: currentResponderStopReason,
        releaseCallState: false,
      },
    },
  };
}

function applyPreparedPairLockWrites(transaction, preparedLock) {
  if (!preparedLock?.locked || !preparedLock.writes) {
    return;
  }

  const writes = preparedLock.writes;
  applyPairLockReleaseWrites({
    transaction,
    targets: writes.currentResponderReleaseTargets,
    ...writes.currentResponderReleaseOptions,
  });
  transaction.update(writes.sessionRef, writes.sessionUpdate);
  transaction.update(writes.requesterSearchRef, writes.requesterLockUpdate);
  transaction.update(writes.requesterUserRef, writes.requesterUserUpdate);
  transaction.update(writes.responderUserRef, writes.responderUserUpdate);
  if (writes.responderSearchRef && writes.responderLockUpdate) {
    transaction.update(writes.responderSearchRef, writes.responderLockUpdate);
  }
}

async function reserveMatchPairInTransaction({
  db,
  transaction,
  requesterId,
  responderId,
  responderRole,
  requesterSearchRequestId = "",
  responderSearchRequestId = "",
  expectedLanguage = "",
  sessionRef,
  sessionData = {},
  nowMillis = Date.now(),
  serverTimestamp,
  lockExpiresAt,
  finalizationExpiresAt,
  pairAttemptId = "",
}) {
  const normalizedRequesterId = normalizeDocumentId(requesterId);
  const normalizedResponderId = normalizeDocumentId(responderId);
  const normalizedResponderRole = normalizeRole(responderRole);
  const normalizedExpectedLanguage =
    readLanguageCode(expectedLanguage) || readLanguageCode(sessionData.language);

  if (
    !normalizedRequesterId ||
    !normalizedResponderId ||
    normalizedRequesterId === normalizedResponderId ||
    !["student", "native_speaker"].includes(normalizedResponderRole)
  ) {
    return buildPairLockFailure("invalid_pair_lock_input");
  }
  if (normalizeString(pairAttemptId) && !normalizeDocumentId(pairAttemptId)) {
    return buildPairLockFailure("invalid_pair_lock_input");
  }

  const requesterUserRef = db
    .collection(USER_COLLECTION)
    .doc(normalizedRequesterId);
  const responderUserRef = db
    .collection(USER_COLLECTION)
    .doc(normalizedResponderId);
  const requesterSearchRef = db
    .collection(SEARCH_REQUEST_COLLECTION)
    .doc(normalizedRequesterId);
  const responderSearchRef = normalizedResponderRole === "student" ?
    db.collection(SEARCH_REQUEST_COLLECTION).doc(normalizedResponderId) :
    null;
  const responderPrivateTokenRef =
    normalizedResponderRole === "native_speaker" ?
      db.collection(PRIVATE_TOKEN_COLLECTION).doc(normalizedResponderId) :
      null;
  const requesterTrialRef = trialAccessRef(db, normalizedRequesterId);
  const responderTrialRef = normalizedResponderRole === "student" ?
    trialAccessRef(db, normalizedResponderId) : null;

  const [
    sessionSnapshot,
    requesterUserSnapshot,
    responderUserSnapshot,
    requesterSearchSnapshot,
    responderSearchSnapshot,
    responderPrivateTokenSnapshot,
    requesterTrialSnapshot,
    responderTrialSnapshot,
  ] = await Promise.all([
    transaction.get(sessionRef),
    transaction.get(requesterUserRef),
    transaction.get(responderUserRef),
    transaction.get(requesterSearchRef),
    responderSearchRef ? transaction.get(responderSearchRef) : null,
    responderPrivateTokenRef ?
      transaction.get(responderPrivateTokenRef) :
      null,
    transaction.get(requesterTrialRef),
    responderTrialRef ? transaction.get(responderTrialRef) : null,
  ]);

  if (sessionSnapshot.exists) {
    return buildPairLockFailure("session_already_exists");
  }

  const requesterUserData = requesterUserSnapshot.exists ?
    requesterUserSnapshot.data() || {} :
    {};
  const responderUserData = responderUserSnapshot.exists ?
    responderUserSnapshot.data() || {} :
    {};
  const requesterUserValidation = validateUserForPairLock({
    userExists: requesterUserSnapshot.exists,
    userData: requesterUserData,
    expectedRole: "student",
    participantKey: "requester",
  });
  if (!requesterUserValidation.ok) {
    return buildPairLockFailure(requesterUserValidation.reason);
  }

  const responderUserValidation = validateUserForPairLock({
    userExists: responderUserSnapshot.exists,
    userData: responderUserData,
    expectedRole: normalizedResponderRole,
    participantKey: "responder",
  });
  if (!responderUserValidation.ok) {
    return buildPairLockFailure(responderUserValidation.reason);
  }

  const requesterAccessDecision = buildStudentCallAccessDecision({
    userRole: "student",
    userData: requesterUserData,
    trialData: requesterTrialSnapshot.exists ?
      requesterTrialSnapshot.data() || {} : null,
    nowMillis,
  });
  if (!requesterAccessDecision.allowed) {
    return buildPairLockFailure(
        `requester_${requesterAccessDecision.reason}`,
    );
  }
  let responderAccessDecision = null;
  if (normalizedResponderRole === "student") {
    responderAccessDecision = buildStudentCallAccessDecision({
      userRole: "student",
      userData: responderUserData,
      trialData: responderTrialSnapshot?.exists ?
        responderTrialSnapshot.data() || {} : null,
      nowMillis,
    });
    if (!responderAccessDecision.allowed) {
      return buildPairLockFailure(
          `responder_${responderAccessDecision.reason}`,
      );
    }
  }

  const requesterSearchValidation = validateSearchRequestForPairLock({
    requestExists: requesterSearchSnapshot.exists,
    requestData: requesterSearchSnapshot.exists ?
      requesterSearchSnapshot.data() || {} :
      {},
    userId: normalizedRequesterId,
    requestId: requesterSearchRequestId,
    expectedLanguage: normalizedExpectedLanguage,
    requireRequestId: true,
    nowMillis,
    participantKey: "requester",
  });
  if (!requesterSearchValidation.ok) {
    return buildPairLockFailure(requesterSearchValidation.reason);
  }

  if (responderSearchRef) {
    const responderSearchValidation = validateSearchRequestForPairLock({
      requestExists: responderSearchSnapshot.exists,
      requestData: responderSearchSnapshot.exists ?
        responderSearchSnapshot.data() || {} :
        {},
      userId: normalizedResponderId,
      requestId: responderSearchRequestId,
      expectedLanguage: normalizedExpectedLanguage,
      requireRequestId: true,
      nowMillis,
      participantKey: "responder",
    });
    if (!responderSearchValidation.ok) {
      return buildPairLockFailure(responderSearchValidation.reason);
    }
  }

  const responderTokenState = responderPrivateTokenSnapshot ?
    buildReadOnlyVoipTokenState({
      privateData: responderPrivateTokenSnapshot.exists ?
        responderPrivateTokenSnapshot.data() || {} :
        {},
      legacyUserData: responderUserData,
      nowMillis,
    }) :
    null;
  const freshPrivatePushKitCapability =
    responderTokenState?.hasFreshVoipPushToken === true;
  const matchProtocolVersion = resolveMatchProtocolVersion({
    requestedVersion: sessionData.matchProtocolVersion,
    requesterSearchData: requesterSearchSnapshot.data() || {},
    responderSearchData: responderSearchSnapshot?.data?.() || null,
    responderRole: normalizedResponderRole,
    responderCapabilityVersion: freshPrivatePushKitCapability ?
      MATCH_PROTOCOL_VERSION :
      responderUserData.matchProtocolVersion,
    responderCallKitCapable: freshPrivatePushKitCapability ||
      responderUserData.v2CallKitCapable === true,
    responderCapabilityExpiresAt:
      freshPrivatePushKitCapability ?
        responderPrivateTokenSnapshot.data()?.voipPushTokenUpdatedAt &&
          admin.firestore.Timestamp.fromMillis(
            timestampToMillis(
              responderPrivateTokenSnapshot.data()?.voipPushTokenUpdatedAt,
            ) + VOIP_TOKEN_FRESHNESS_MS,
          ) :
        responderUserData.v2CallKitCapabilityExpiresAt,
    nowMillis,
  });
  const requesterRequiresProtocolV2 =
    supportsMatchProtocolV2(sessionData.matchProtocolVersion) &&
    supportsMatchProtocolV2(
      requesterSearchSnapshot.data()?.matchProtocolVersion,
    );
  if (
    requesterRequiresProtocolV2 &&
    matchProtocolVersion !== MATCH_PROTOCOL_VERSION
  ) {
    return buildPairLockFailure("responder_protocol_incompatible");
  }

  const autoAcceptForegroundStudents =
    matchProtocolVersion === MATCH_PROTOCOL_VERSION &&
    normalizedResponderRole === "student" &&
    isFreshForegroundSearchForAutoAccept({
      requestData: requesterSearchSnapshot.data() || {},
      nowMillis,
    }) &&
    isFreshForegroundSearchForAutoAccept({
      requestData: responderSearchSnapshot?.data?.() || {},
      nowMillis,
    });

  const sessionId = sessionRef.id;
  const accessModesByUserId = {
    [normalizedRequesterId]: requesterAccessDecision.mode,
    ...(responderAccessDecision ? {
      [normalizedResponderId]: responderAccessDecision.mode,
    } : {}),
  };
  const trialCallIdsByUserId = {};
  if (requesterAccessDecision.mode === "trial") {
    const reservation = reserveTrialCallInTransaction({
      transaction,
      trialRef: requesterTrialRef,
      trialSnap: requesterTrialSnapshot,
      requestId: sessionId,
      nowMillis,
    });
    if (!reservation.allowed) {
      return buildPairLockFailure(`requester_${reservation.reason}`);
    }
    trialCallIdsByUserId[normalizedRequesterId] = reservation.trialCallId;
  }
  if (responderAccessDecision?.mode === "trial") {
    const reservation = reserveTrialCallInTransaction({
      transaction,
      trialRef: responderTrialRef,
      trialSnap: responderTrialSnapshot,
      requestId: sessionId,
      nowMillis,
    });
    if (!reservation.allowed) {
      return buildPairLockFailure(`responder_${reservation.reason}`);
    }
    trialCallIdsByUserId[normalizedResponderId] = reservation.trialCallId;
  }
  const sessionAccessData = {
    ...sessionData,
    accessMode: requesterAccessDecision.mode,
    accessModesByUserId,
    ...(trialCallIdsByUserId[normalizedRequesterId] ? {
      trialCallId: trialCallIdsByUserId[normalizedRequesterId],
    } : {}),
    ...(Object.keys(trialCallIdsByUserId).length > 0 ? {
      trialCallIdsByUserId,
    } : {}),
  };
  const finalPairAttemptId = normalizeDocumentId(pairAttemptId) ||
    buildPairAttemptId({
      sessionId,
      requesterId: normalizedRequesterId,
      responderId: normalizedResponderId,
    });
  const sessionLockData = buildVideoSessionPairLockData({
    sessionData: sessionAccessData,
    requesterId: normalizedRequesterId,
    responderId: normalizedResponderId,
    requesterRole: "student",
    responderRole: normalizedResponderRole,
    sessionId,
    pairAttemptId: finalPairAttemptId,
    requesterSearchRequestId: normalizeString(
      requesterSearchRequestId ||
        requesterSearchSnapshot.data()?.[SEARCH_REQUEST_FIELD.REQUEST_ID],
    ),
    responderSearchRequestId: responderSearchSnapshot ?
      normalizeString(
        responderSearchRequestId ||
          responderSearchSnapshot.data()?.[SEARCH_REQUEST_FIELD.REQUEST_ID],
      ) :
      "",
    participantInfos: {
      [normalizedRequesterId]: buildParticipantInfo(requesterUserData),
      [normalizedResponderId]: buildParticipantInfo(responderUserData),
    },
    serverTimestamp,
    lockExpiresAt,
    finalizationExpiresAt,
    matchProtocolVersion,
    autoAcceptForegroundStudents,
  });
  const requesterLockUpdate = buildSearchRequestPairLockUpdate({
    sessionId,
    pairAttemptId: finalPairAttemptId,
    otherUserId: normalizedResponderId,
    otherRole: normalizedResponderRole,
    matchedResponderId: normalizedResponderId,
    serverTimestamp,
    lockExpiresAt,
  });

  transaction.create(sessionRef, sessionLockData);
  transaction.update(requesterSearchRef, requesterLockUpdate);
  transaction.update(requesterUserRef, {
    currentSessionId: sessionId,
    updatedAt: serverTimestamp,
  });
  transaction.update(responderUserRef, {
    currentSessionId: sessionId,
    updatedAt: serverTimestamp,
  });

  if (responderSearchRef) {
    transaction.update(responderSearchRef, buildSearchRequestPairLockUpdate({
      sessionId,
      pairAttemptId: finalPairAttemptId,
      otherUserId: normalizedRequesterId,
      otherRole: "student",
      matchedResponderId: normalizedResponderId,
      serverTimestamp,
      lockExpiresAt,
    }));
  }

  return {
    locked: true,
    reason: "locked",
    sessionId,
    pairAttemptId: finalPairAttemptId,
    requesterId: normalizedRequesterId,
    responderId: normalizedResponderId,
    responderRole: normalizedResponderRole,
    matchProtocolVersion,
    finalizationRequested: autoAcceptForegroundStudents,
  };
}

async function reserveDirectPairInTransaction({
  db,
  transaction,
  requesterId,
  responderId,
  responderRole,
  sessionRef,
  sessionData = {},
  nowMillis = Date.now(),
  serverTimestamp,
  lockExpiresAt,
  pairAttemptId = "",
}) {
  const normalizedRequesterId = normalizeDocumentId(requesterId);
  const normalizedResponderId = normalizeDocumentId(responderId);
  const normalizedResponderRole = normalizeRole(responderRole);

  if (
    !normalizedRequesterId ||
    !normalizedResponderId ||
    normalizedRequesterId === normalizedResponderId ||
    normalizedResponderRole !== "native_speaker"
  ) {
    return buildPairLockFailure("invalid_pair_lock_input");
  }
  if (normalizeString(pairAttemptId) && !normalizeDocumentId(pairAttemptId)) {
    return buildPairLockFailure("invalid_pair_lock_input");
  }

  const requesterUserRef = db
    .collection(USER_COLLECTION)
    .doc(normalizedRequesterId);
  const responderUserRef = db
    .collection(USER_COLLECTION)
    .doc(normalizedResponderId);
  const requesterUsageRef = usageDocRef(db, normalizedRequesterId);
  const requesterTrialRef = trialAccessRef(db, normalizedRequesterId);
  const responderPrivateTokenRef = db
    .collection(PRIVATE_TOKEN_COLLECTION)
    .doc(normalizedResponderId);
  const [
    sessionSnapshot,
    requesterUserSnapshot,
    responderUserSnapshot,
    requesterUsageSnapshot,
    requesterTrialSnapshot,
    responderPrivateTokenSnapshot,
  ] = await Promise.all([
    transaction.get(sessionRef),
    transaction.get(requesterUserRef),
    transaction.get(responderUserRef),
    transaction.get(requesterUsageRef),
    transaction.get(requesterTrialRef),
    transaction.get(responderPrivateTokenRef),
  ]);

  if (sessionSnapshot.exists) {
    return buildPairLockFailure("session_already_exists");
  }

  const requesterUserData = requesterUserSnapshot.exists ?
    requesterUserSnapshot.data() || {} :
    {};
  const responderUserData = responderUserSnapshot.exists ?
    responderUserSnapshot.data() || {} :
    {};
  const requesterUserValidation = validateUserForPairLock({
    userExists: requesterUserSnapshot.exists,
    userData: requesterUserData,
    expectedRole: "student",
    participantKey: "requester",
  });
  if (!requesterUserValidation.ok) {
    return buildPairLockFailure(requesterUserValidation.reason);
  }

  const responderUserValidation = validateUserForPairLock({
    userExists: responderUserSnapshot.exists,
    userData: responderUserData,
    expectedRole: normalizedResponderRole,
    participantKey: "responder",
  });
  if (!responderUserValidation.ok) {
    return buildPairLockFailure(responderUserValidation.reason);
  }
  const requesterUsageData = requesterUsageSnapshot.exists ?
    requesterUsageSnapshot.data() || {} :
    null;
  const directAccessValidation = validateDirectPairAccessForLock({
    requesterId: normalizedRequesterId,
    requesterData: requesterUserData,
    requesterUsageData,
    requesterTrialData: requesterTrialSnapshot.exists ?
      requesterTrialSnapshot.data() || {} : null,
    responderId: normalizedResponderId,
    responderData: responderUserData,
    language: sessionData.language,
    nowMillis,
  });
  if (!directAccessValidation.ok) {
    return buildPairLockFailure(directAccessValidation.reason);
  }
  const responderAvailability =
    evaluateTutorAvailabilityWindow(
      responderUserData,
      new Date(nowMillis),
    );
  if (!responderAvailability.isAvailable) {
    return buildPairLockFailure("responder_schedule_unavailable");
  }
  const responderPrivateTokenData = responderPrivateTokenSnapshot.exists ?
    responderPrivateTokenSnapshot.data() || {} :
    {};
  const responderTokenState = buildReadOnlyVoipTokenState({
    privateData: responderPrivateTokenData,
    legacyUserData: responderUserData,
  });
  if (!hasUsableCallTokenState(responderTokenState)) {
    return buildPairLockFailure("responder_missing_call_token");
  }

  const sessionId = sessionRef.id;
  let accessSessionData = {
    ...sessionData,
    accessMode: directAccessValidation.mode,
    accessModesByUserId: {
      [normalizedRequesterId]: directAccessValidation.mode,
    },
  };
  if (directAccessValidation.mode === "trial") {
    const reservation = reserveTrialCallInTransaction({
      transaction,
      trialRef: requesterTrialRef,
      trialSnap: requesterTrialSnapshot,
      requestId: sessionId,
      nowMillis,
    });
    if (!reservation.allowed) {
      return buildPairLockFailure(`requester_${reservation.reason}`);
    }
    accessSessionData = {
      ...accessSessionData,
      trialCallId: reservation.trialCallId,
      trialCallIdsByUserId: {
        [normalizedRequesterId]: reservation.trialCallId,
      },
    };
  }
  const finalPairAttemptId = normalizeDocumentId(pairAttemptId) ||
    buildPairAttemptId({
      sessionId,
      requesterId: normalizedRequesterId,
      responderId: normalizedResponderId,
    });
  const sessionLockData = buildVideoSessionPairLockData({
    sessionData: accessSessionData,
    requesterId: normalizedRequesterId,
    responderId: normalizedResponderId,
    requesterRole: "student",
    responderRole: normalizedResponderRole,
    sessionId,
    pairAttemptId: finalPairAttemptId,
    participantInfos: {
      [normalizedRequesterId]: buildParticipantInfo(requesterUserData),
      [normalizedResponderId]: buildParticipantInfo(responderUserData),
    },
    serverTimestamp,
    lockExpiresAt,
  });

  transaction.create(sessionRef, sessionLockData);
  transaction.update(requesterUserRef, {
    currentSessionId: sessionId,
    updatedAt: serverTimestamp,
  });
  transaction.update(responderUserRef, {
    currentSessionId: sessionId,
    updatedAt: serverTimestamp,
  });

  return {
    locked: true,
    reason: "locked",
    sessionId,
    pairAttemptId: finalPairAttemptId,
    requesterId: normalizedRequesterId,
    responderId: normalizedResponderId,
    responderRole: normalizedResponderRole,
  };
}

async function reserveMatchPair({
  db = admin.firestore(),
  requesterId,
  responderId,
  responderRole,
  requesterSearchRequestId = "",
  responderSearchRequestId = "",
  expectedLanguage = "",
  sessionId = "",
  pairAttemptId = "",
  sessionData = {},
  nowMillis = Date.now(),
  lockTtlSeconds = MATCH_PAIR_LOCK_TTL_SECONDS,
  serverTimestamp = admin.firestore.FieldValue.serverTimestamp(),
  timestampFromMillis = admin.firestore.Timestamp.fromMillis,
}) {
  const rawSessionId = normalizeString(sessionId);
  const normalizedSessionId = normalizeDocumentId(sessionId);
  if (rawSessionId && !normalizedSessionId) {
    return buildPairLockFailure("invalid_pair_lock_input");
  }

  const sessionCollection = db.collection(VIDEO_SESSION_COLLECTION);
  const sessionRef = normalizedSessionId ?
    sessionCollection.doc(normalizedSessionId) :
    sessionCollection.doc();
  const lockExpiresAt = timestampFromMillis(
    nowMillis + lockTtlSeconds * 1000,
  );
  const finalizationExpiresAt = timestampFromMillis(
    nowMillis + MATCH_FINALIZATION_GUARD_MS,
  );

  return db.runTransaction((transaction) => reserveMatchPairInTransaction({
    db,
    transaction,
    requesterId,
    responderId,
    responderRole,
    requesterSearchRequestId,
    responderSearchRequestId,
    expectedLanguage,
    sessionRef,
    sessionData,
    nowMillis,
    serverTimestamp,
    lockExpiresAt,
    finalizationExpiresAt,
    pairAttemptId,
  }));
}

module.exports = {
  MATCH_PAIR_LOCK_TTL_SECONDS,
  applyPreparedPairLockWrites,
  buildPairAttemptId,
  buildSearchRequestActiveRestoreUpdate,
  buildSearchRequestPairLockUpdate,
  buildVideoSessionPairLockData,
  canRestoreSearchRequestToActive,
  hasLiveSearchRequestLock,
  isSearchRequestFreshForPairLock,
  prepareExistingSessionNextResponderPairLockInTransaction,
  releaseSessionPairLocksInTransaction,
  resolveMatchProtocolVersion,
  reserveDirectPairInTransaction,
  reserveMatchPair,
  reserveMatchPairInTransaction,
  stopSessionSearchRequestsInTransaction,
  validateSearchRequestForPairLock,
  validateUserForPairLock,
};
