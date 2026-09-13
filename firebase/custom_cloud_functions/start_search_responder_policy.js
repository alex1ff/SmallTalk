const {evaluateTutorAvailabilityWindow} = require("./availability");
const {hasActiveAcceptLockForResponder} = require("./accept_lock_policy");
const {
  buildMatchProfile,
  normalizeRole,
  supportsConversationLanguage,
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_FIELD,
  SEARCH_REQUEST_STATUS,
  normalizeAppState,
} = require("./search_requests");
const {
  readReferenceId,
  timestampToMillis,
} = require("./start_search_request_policy");

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function readNestedObject(value) {
  return value && typeof value === "object" && !Array.isArray(value) ?
    value :
    {};
}

function isFreshBackgroundSearchRequest(
    requestData = {},
    nowMillis = Date.now(),
) {
  if (normalizeString(requestData[SEARCH_REQUEST_FIELD.STATUS]) !==
      SEARCH_REQUEST_STATUS.MATCHED) {
    return false;
  }
  if (normalizeAppState(requestData[SEARCH_REQUEST_FIELD.APP_STATE]) !==
      SEARCH_REQUEST_APP_STATE.BACKGROUND) {
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
  return responseDeadlineMillis !== null && responseDeadlineMillis > nowMillis;
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
  return responderRoles.every((role) => role === "student") &&
    normalizeString(sessionData.scenario) === "student_student";
}

function isTeacherResponderSession(sessionData = {}, responderId = "") {
  const normalizedResponderId = normalizeString(responderId);
  const participantRoles = readNestedObject(sessionData.participantRoles);
  const responderRoles = [
    sessionData.currentResponderRole,
    sessionData.responderRole,
    participantRoles[normalizedResponderId],
  ].map(normalizeRole);
  return responderRoles.every((role) => role === "native_speaker") &&
    normalizeString(sessionData.scenario) === "student_teacher";
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
  if (sessionStatus === VIDEO_SESSION_STATUS.CONNECTING ||
      sessionStatus === VIDEO_SESSION_STATUS.ACTIVE) {
    return {shouldNotify: false, reason: `session_${sessionStatus}`};
  }
  if (sessionStatus !== VIDEO_SESSION_STATUS.PENDING_CONFIRMATION) {
    return {shouldNotify: false, reason: "session_not_pending"};
  }
  if (normalizeString(sessionData.currentResponderId) !==
        normalizedResponderId ||
      normalizeString(sessionData.currentTutorId) !== normalizedResponderId) {
    return {shouldNotify: false, reason: "responder_mismatch"};
  }
  if (!isStudentResponderSession(sessionData, normalizedResponderId)) {
    return {shouldNotify: false, reason: "responder_not_student"};
  }
  if (!isSessionResponseWindowOpen(sessionData, nowMillis)) {
    return {shouldNotify: false, reason: "response_window_closed"};
  }
  if (hasActiveAcceptLockForResponder({
    sessionData,
    responderId: normalizedResponderId,
    nowMillis,
  })) {
    return {shouldNotify: false, reason: "accept_in_progress"};
  }
  if (!isFreshBackgroundSearchRequest(responderSearchRequestData, nowMillis)) {
    return {shouldNotify: false, reason: "responder_not_background"};
  }
  if (!searchRequestBelongsToResponder(
      responderSearchRequestData,
      normalizedResponderId,
  )) {
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
  if (sessionStatus === VIDEO_SESSION_STATUS.CONNECTING ||
      sessionStatus === VIDEO_SESSION_STATUS.ACTIVE) {
    return {shouldNotify: false, reason: `session_${sessionStatus}`};
  }
  if (sessionStatus !== VIDEO_SESSION_STATUS.PENDING_CONFIRMATION) {
    return {shouldNotify: false, reason: "session_not_pending"};
  }
  if (normalizeString(sessionData.currentResponderId) !==
        normalizedResponderId ||
      normalizeString(sessionData.currentTutorId) !== normalizedResponderId) {
    return {shouldNotify: false, reason: "responder_mismatch"};
  }
  if (!isTeacherResponderSession(sessionData, normalizedResponderId)) {
    return {shouldNotify: false, reason: "responder_not_teacher"};
  }
  if (!isSessionResponseWindowOpen(sessionData, nowMillis)) {
    return {shouldNotify: false, reason: "response_window_closed"};
  }
  if (hasActiveAcceptLockForResponder({
    sessionData,
    responderId: normalizedResponderId,
    nowMillis,
  })) {
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
  if (!normalizedSessionId ||
      normalizeString(teacherData.currentSessionId) !== normalizedSessionId) {
    return {valid: false, reason: "teacher_session_mismatch"};
  }
  if (teacherData.isInCall === true) {
    return {valid: false, reason: "teacher_in_call"};
  }
  if (!buildMatchProfile(
      normalizedResponderId,
      teacherData,
      sessionData.language,
  ).approvedTeacher) {
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

module.exports = {
  isFreshBackgroundSearchRequest,
  isSessionResponseWindowOpen,
  isStudentResponderSession,
  isTeacherResponderSession,
  readSessionResponseDeadlineMillis,
  searchRequestBelongsToResponder,
  searchRequestMatchesSession,
  shouldCreateBackgroundStudentResponderIncomingCall,
  shouldCreateTeacherResponderIncomingCall,
  shouldLeaveBackgroundNotificationForAccept,
  shouldRetryBackgroundStudentMatchAfterNotifyResult,
  shouldRetryTeacherMatchAfterNotifyResult,
  shouldUseTeacherResponderForIncomingCall,
};
