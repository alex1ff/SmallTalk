function normalizeUserId(value) {
  if (typeof value !== "string") {
    return "";
  }

  return value.trim();
}

function buildSessionParticipantIds(...values) {
  const participantIds = [];
  const seen = new Set();

  values.flat(Infinity).forEach((value) => {
    const normalized = normalizeUserId(value);
    if (!normalized || seen.has(normalized)) {
      return;
    }

    seen.add(normalized);
    participantIds.push(normalized);
  });

  return participantIds;
}

function getSessionParticipantIds(sessionData = {}) {
  return buildSessionParticipantIds(
    Array.isArray(sessionData.participantIds) ? sessionData.participantIds : [],
    sessionData.studentId,
    sessionData.tutorId,
  );
}

function isSessionParticipant(sessionData = {}, userId) {
  const normalizedUserId = normalizeUserId(userId);
  if (!normalizedUserId) {
    return false;
  }

  return getSessionParticipantIds(sessionData).includes(normalizedUserId);
}

module.exports = {
  buildSessionParticipantIds,
  getSessionParticipantIds,
  isSessionParticipant,
};
