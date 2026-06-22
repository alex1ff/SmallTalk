const {
  normalizeRole,
} = require("./video_sessions_shared");

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeScenario(value) {
  return normalizeString(value).toLowerCase();
}

function readResponderRole(sessionData = {}, responderId = "") {
  const normalizedResponderId = normalizeString(responderId);
  return [
    sessionData.currentResponderRole,
    sessionData.responderRole,
    sessionData.participantRoles?.[normalizedResponderId],
    sessionData.matchContext?.selectedResponderRole,
    sessionData.matchContext?.acceptedResponderRole,
  ].map(normalizeRole).find(Boolean) || "";
}

function isStudentPairResponderFailure({
  sessionData = {},
  responderId = "",
}) {
  return normalizeScenario(sessionData.scenario) === "student_student" ||
    readResponderRole(sessionData, responderId) === "student";
}

function readAvailableRespondersAfterFailure({
  sessionData = {},
  responderId = "",
}) {
  if (isStudentPairResponderFailure({sessionData, responderId})) {
    return [];
  }

  return Array.isArray(sessionData.availableTutors) ?
    sessionData.availableTutors :
    [];
}

function resolveResponderFailureStopReason({
  sessionData = {},
  responderId = "",
  fallbackStopReason,
  studentPairStopReason,
}) {
  return isStudentPairResponderFailure({sessionData, responderId}) ?
    studentPairStopReason :
    fallbackStopReason;
}

module.exports = {
  isStudentPairResponderFailure,
  readAvailableRespondersAfterFailure,
  readResponderRole,
  resolveResponderFailureStopReason,
};
