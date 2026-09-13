const {
  MATCH_CANDIDATE_SOURCE,
  collectMatchCandidatePool,
} = require("./match_candidate_pool");
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

function readMatchContextFilters(sessionData = {}) {
  const filters = sessionData.matchContext?.filters || sessionData.filters;
  return filters && typeof filters === "object" && !Array.isArray(filters) ?
    filters :
    {};
}

function stableJsonStringify(value) {
  if (Array.isArray(value)) {
    return `[${value.map(stableJsonStringify).join(",")}]`;
  }
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${stableJsonStringify(value[key])}`,
    ).join(",")}}`;
  }
  return JSON.stringify(value);
}

function readLanguage(sessionData = {}) {
  return normalizeString(
    sessionData.language ||
      sessionData.matchContext?.requestedLanguage,
  );
}

function buildResponderFailurePoolFingerprint({
  sessionData = {},
  responderId = "",
  requesterId = "",
}) {
  const normalizedRequesterId = normalizeString(requesterId) ||
    normalizeString(sessionData.requesterId) ||
    normalizeString(sessionData.studentId) ||
    normalizeString(sessionData.matchContext?.requesterId);
  return {
    requesterId: normalizedRequesterId,
    responderId: normalizeString(responderId),
    language: readLanguage(sessionData),
    filters: stableJsonStringify(readMatchContextFilters(sessionData)),
    assignment: normalizeString(sessionData.currentResponderId) ||
      normalizeString(sessionData.currentTutorId),
    role: readResponderRole(sessionData, responderId),
    scenario: normalizeScenario(sessionData.scenario),
    direct: isDirectMatchSession(sessionData),
    studentPair: isStudentPairResponderFailure({sessionData, responderId}),
  };
}

function responderFailurePoolFingerprintMatches(left = null, right = null) {
  if (!left || !right) {
    return false;
  }
  return [
    "requesterId",
    "responderId",
    "language",
    "filters",
    "assignment",
    "role",
    "scenario",
    "direct",
    "studentPair",
  ].every((key) => left[key] === right[key]);
}

function isDirectMatchSession(sessionData = {}) {
  return normalizeString(sessionData.matchContext?.matchMode) === "direct" ||
    Boolean(normalizeString(sessionData.matchContext?.directCandidateId)) ||
    Boolean(normalizeString(sessionData.matchContext?.directTutorId));
}

function readFreshResponderIds(candidates = []) {
  return Array.from(new Set(candidates
    .filter((candidate) => {
      const role = normalizeRole(candidate?.role);
      const source = normalizeString(candidate?.source);
      return (
        role === "student" &&
          source === MATCH_CANDIDATE_SOURCE.ACTIVE_STUDENT_QUEUE
      ) || (
        role === "native_speaker" &&
          source === MATCH_CANDIDATE_SOURCE.TEACHER_AVAILABILITY
      );
    })
    .map((candidate) => normalizeString(candidate?.userId))
    .filter(Boolean)));
}

async function collectAvailableRespondersAfterFailure({
  db,
  sessionData = {},
  responderId = "",
  requesterId = "",
  now = new Date(),
  nowMillis = Date.now(),
  candidatePoolCollector = collectMatchCandidatePool,
}) {
  if (isStudentPairResponderFailure({sessionData, responderId})) {
    return {
      availableTutors: [],
      source: "student_pair_terminal",
      stats: null,
    };
  }
  if (isDirectMatchSession(sessionData)) {
    return {
      availableTutors: readAvailableRespondersAfterFailure({
        sessionData,
        responderId,
      }),
      source: "direct_session_snapshot",
      stats: null,
    };
  }

  const normalizedRequesterId = normalizeString(requesterId) ||
    normalizeString(sessionData.requesterId) ||
    normalizeString(sessionData.studentId) ||
    normalizeString(sessionData.matchContext?.requesterId);
  const language = readLanguage(sessionData);
  const fingerprint = buildResponderFailurePoolFingerprint({
    sessionData,
    responderId,
    requesterId: normalizedRequesterId,
  });
  if (
    !db ||
    !normalizedRequesterId ||
    !language ||
    typeof candidatePoolCollector !== "function"
  ) {
    return {
      availableTutors: readAvailableRespondersAfterFailure({
        sessionData,
        responderId,
      }),
      source: "session_snapshot",
      stats: null,
    };
  }

  const candidatePool = await candidatePoolCollector({
    db,
    requesterId: normalizedRequesterId,
    language,
    requesterFilters: readMatchContextFilters(sessionData),
    now,
    nowMillis,
    includeStudents: true,
    includeTeachers: true,
  });

  return {
    availableTutors: readFreshResponderIds(
      candidatePool?.candidates || [],
    ),
    fingerprint,
    source: "common_pool",
    stats: candidatePool?.stats || null,
  };
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
  buildResponderFailurePoolFingerprint,
  collectAvailableRespondersAfterFailure,
  isStudentPairResponderFailure,
  isDirectMatchSession,
  readFreshResponderIds,
  readAvailableRespondersAfterFailure,
  readResponderRole,
  responderFailurePoolFingerprintMatches,
  resolveResponderFailureStopReason,
};
