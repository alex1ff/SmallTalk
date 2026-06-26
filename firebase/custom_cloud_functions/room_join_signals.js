function normalizeParticipantId(value) {
  return typeof value === "string" ? value.trim() : "";
}

function readSignalMap(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value;
}

function readRoomJoinSignals(sessionMetadata = {}) {
  return readSignalMap(sessionMetadata.roomJoinParticipantSignals);
}

function normalizeRoomJoinSignal(signal = {}) {
  const normalizedSignal = readSignalMap(signal);
  const joinedAt =
    normalizedSignal.joinedAt ||
    normalizedSignal.markedAt ||
    normalizedSignal.eventTs ||
    normalizedSignal.receivedAt ||
    null;
  const dailyJoinedAt =
    normalizedSignal.dailyJoinedAt ||
    (normalizedSignal.source === "dailyWebhook" ?
      normalizedSignal.joinedAt || normalizedSignal.eventTs || null :
      null);
  const result = {
    ...normalizedSignal,
    joinedAt,
    lastSeenAt:
      normalizedSignal.lastSeenAt ||
      normalizedSignal.markedAt ||
      normalizedSignal.receivedAt ||
      joinedAt,
  };
  if (dailyJoinedAt) {
    result.dailyJoinedAt = dailyJoinedAt;
  }
  return result;
}

function mergeRoomJoinSignal(existingSignal = {}, nextSignal = {}) {
  const normalizedExisting = normalizeRoomJoinSignal(existingSignal);
  const normalizedNext = normalizeRoomJoinSignal(nextSignal);
  const dailyJoinedAt =
    normalizedExisting.dailyJoinedAt || normalizedNext.dailyJoinedAt || null;
  const source = normalizedExisting.source || normalizedNext.source || null;
  const result = {
    ...normalizedExisting,
    ...normalizedNext,
    joinedAt: normalizedExisting.joinedAt || normalizedNext.joinedAt || null,
    lastSeenAt:
      normalizedNext.lastSeenAt ||
      normalizedNext.joinedAt ||
      normalizedExisting.lastSeenAt ||
      normalizedExisting.joinedAt ||
      null,
  };
  if (dailyJoinedAt) {
    result.dailyJoinedAt = dailyJoinedAt;
  }
  if (source) {
    result.source = source;
  }
  return result;
}

function buildRoomJoinParticipantMetadata({
  sessionMetadata = {},
  participantIds = [],
  userId,
  signal = {},
}) {
  const normalizedParticipantIds = Array.from(new Set(
    participantIds.map(normalizeParticipantId).filter(Boolean),
  ));
  const acceptedParticipantIds = new Set(normalizedParticipantIds);
  const normalizedUserId = normalizeParticipantId(userId);
  const nextSignals = {};
  const seedMaps = [
    sessionMetadata.roomJoinParticipantSignals,
    sessionMetadata.dailyWebhookParticipantSignals,
    sessionMetadata.connectedParticipantSignals,
  ];

  for (const signalMap of seedMaps.map(readSignalMap)) {
    for (const [participantId, participantSignal] of Object.entries(signalMap)) {
      const normalizedParticipantId = normalizeParticipantId(participantId);
      if (!acceptedParticipantIds.has(normalizedParticipantId)) {
        continue;
      }
      nextSignals[normalizedParticipantId] = mergeRoomJoinSignal(
        nextSignals[normalizedParticipantId],
        participantSignal,
      );
    }
  }

  if (acceptedParticipantIds.has(normalizedUserId)) {
    nextSignals[normalizedUserId] = mergeRoomJoinSignal(
      nextSignals[normalizedUserId],
      signal,
    );
  }

  const roomJoinedParticipantIds = normalizedParticipantIds.filter(
    (participantId) => Boolean(nextSignals[participantId]),
  );

  return {
    roomJoinParticipantSignals: nextSignals,
    roomJoinedParticipantIds,
    roomJoinSignalsComplete:
      normalizedParticipantIds.length >= 2 &&
      roomJoinedParticipantIds.length === normalizedParticipantIds.length,
  };
}

module.exports = {
  buildRoomJoinParticipantMetadata,
  readRoomJoinSignals,
};
