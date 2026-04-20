const admin = require("firebase-admin");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");

const DEFAULT_CHATS_ROLLOUT_ISO = "2026-04-13T00:00:00Z";
const DEFAULT_CHATS_ROLLOUT_MS = Date.parse(DEFAULT_CHATS_ROLLOUT_ISO);
const DEFAULT_CHAT_CALL_EVENTS_ROLLOUT_ISO = "2026-04-19T00:00:00Z";
const DEFAULT_CHAT_CALL_EVENTS_ROLLOUT_MS = Date.parse(
  DEFAULT_CHAT_CALL_EVENTS_ROLLOUT_ISO,
);
const DEFAULT_REPAIR_PAGE_SIZE = 50;
const STALE_UNLOCK_PROCESSING_MS = 5 * 60 * 1000;
const CONVERSATION_MESSAGE_TYPE_TEXT = "text";
const CONVERSATION_MESSAGE_TYPE_CALL_EVENT = "call_event";
const CALL_EVENT_KIND_VIDEO = "video";
const CALL_EVENT_MESSAGE_PREFIX = "call_";

function toMillis(value) {
  if (!value) return 0;
  if (typeof value?.toMillis === "function") {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  const numericValue = Number(value);
  return Number.isFinite(numericValue) ? numericValue : 0;
}

function getChatsRolloutMillis() {
  const rawValue = process.env.CHATS_ROLLOUT_AT || DEFAULT_CHATS_ROLLOUT_ISO;
  const parsedMillis = Date.parse(rawValue);
  return Number.isFinite(parsedMillis) ? parsedMillis : DEFAULT_CHATS_ROLLOUT_MS;
}

function getChatsRolloutTimestamp() {
  return Timestamp.fromMillis(getChatsRolloutMillis());
}

function getChatCallEventsRolloutMillis() {
  const rawValue =
    process.env.CHAT_CALL_EVENTS_ROLLOUT_AT ||
    DEFAULT_CHAT_CALL_EVENTS_ROLLOUT_ISO;
  const parsedMillis = Date.parse(rawValue);
  return Number.isFinite(parsedMillis) ?
    parsedMillis :
    DEFAULT_CHAT_CALL_EVENTS_ROLLOUT_MS;
}

function buildPairId(leftUid, rightUid) {
  if (!leftUid || !rightUid) return null;
  const sorted = [String(leftUid), String(rightUid)].sort();
  if (sorted[0] === sorted[1]) return null;
  return `${sorted[0]}_${sorted[1]}`;
}

function getConnectedCallStartMillis(sessionData = {}) {
  const callConnectedAt = toMillis(sessionData.sessionMetadata?.callConnectedAt);
  const legacyCallConnectedAt = toMillis(
    sessionData.sessionMetadata?.callConnectedAtTimestamp,
  );
  const startedAt = toMillis(sessionData.startedAt);
  const acceptedAt =
    toMillis(sessionData.acceptedAt) ||
    toMillis(sessionData.sessionMetadata?.acceptedAt);
  const serverConnectedAt =
    startedAt > 0 && (acceptedAt === 0 || startedAt - acceptedAt > 1000)
      ? startedAt
      : 0;

  return callConnectedAt || legacyCallConnectedAt || serverConnectedAt || 0;
}

function getUnlockParticipants(sessionData = {}) {
  const studentId = sessionData.studentId || null;
  const tutorId = sessionData.tutorId || sessionData.currentTutorId || null;

  if (!studentId || !tutorId || studentId === tutorId) {
    return null;
  }

  const pairId = buildPairId(studentId, tutorId);
  if (!pairId) {
    return null;
  }

  const participantIds = [studentId, tutorId].sort();
  const participantRefs = participantIds.map((uid) =>
    admin.firestore().collection("users").doc(uid),
  );

  return {
    studentId,
    tutorId,
    pairId,
    participantIds,
    participantRefs,
  };
}

function getSessionEndedAtMillis(sessionData = {}) {
  return (
    toMillis(sessionData.endedAt) ||
    toMillis(sessionData.sessionMetadata?.endedAtTimestamp) ||
    0
  );
}

function getCallEventStartedAtMillis(sessionData = {}) {
  return (
    getConnectedCallStartMillis(sessionData) ||
    toMillis(sessionData.startedAt) ||
    toMillis(sessionData.createdAt) ||
    0
  );
}

function resolveCallEventDurationSeconds(sessionData = {}) {
  const storedDuration = Number(sessionData.duration || 0);
  if (Number.isFinite(storedDuration) && storedDuration > 0) {
    return Math.max(0, Math.floor(storedDuration));
  }

  const startedAtMillis = getCallEventStartedAtMillis(sessionData);
  const endedAtMillis = getSessionEndedAtMillis(sessionData);
  if (startedAtMillis <= 0 || endedAtMillis <= 0) {
    return 0;
  }

  return Math.max(0, Math.floor((endedAtMillis - startedAtMillis) / 1000));
}

function isQualifyingUnlockSession(sessionData = {}) {
  return (
    String(sessionData.status || "").toLowerCase() === "ended" &&
    toMillis(sessionData.createdAt) >= getChatsRolloutMillis() &&
    getConnectedCallStartMillis(sessionData) > 0 &&
    !!getUnlockParticipants(sessionData)
  );
}

function getUnlockEligibility(sessionData = {}) {
  if (String(sessionData.status || "").toLowerCase() !== "ended") {
    return { eligible: false, reason: "ignored_not_ended" };
  }

  if (toMillis(sessionData.createdAt) < getChatsRolloutMillis()) {
    return { eligible: false, reason: "ignored_pre_rollout" };
  }

  if (getConnectedCallStartMillis(sessionData) <= 0) {
    return { eligible: false, reason: "ignored_not_connected" };
  }

  const participants = getUnlockParticipants(sessionData);
  if (!participants) {
    return { eligible: false, reason: "ignored_invalid_pair" };
  }

  return {
    eligible: true,
    reason: null,
    ...participants,
  };
}

function conversationMatchesUnlockParticipants(conversationData = {}, participants = {}) {
  if (!participants?.pairId || conversationData.pairId !== participants.pairId) {
    return false;
  }

  if (!Array.isArray(conversationData.participantIds)) {
    return false;
  }

  const conversationParticipantIds = conversationData.participantIds
    .map((uid) => String(uid || ""))
    .filter(Boolean)
    .sort();
  const expectedParticipantIds = (participants.participantIds || [])
    .map((uid) => String(uid || ""))
    .filter(Boolean)
    .sort();

  return (
    conversationParticipantIds.length === expectedParticipantIds.length &&
    conversationParticipantIds.every(
      (uid, index) => uid === expectedParticipantIds[index],
    )
  );
}

function isEligibleCallEventSession(sessionData = {}) {
  const eligibility = getUnlockEligibility(sessionData);
  if (!eligibility.eligible) {
    return false;
  }

  return getSessionEndedAtMillis(sessionData) >= getChatCallEventsRolloutMillis();
}

function buildUnlockEventPayload({
  sessionId,
  sessionRef,
  participants,
  source,
}) {
  const now = FieldValue.serverTimestamp();
  return {
    sessionId,
    sessionRef,
    participantIds: participants.participantIds,
    participantRefs: participants.participantRefs,
    pairId: participants.pairId,
    source,
    status: "pending",
    attemptCount: 0,
    createdAt: now,
    updatedAt: now,
  };
}

function buildConversationSeed({
  participants,
  sessionRef,
}) {
  const now = FieldValue.serverTimestamp();
  return {
    pairId: participants.pairId,
    participantIds: participants.participantIds,
    participantRefs: participants.participantRefs,
    isUnlocked: true,
    unlockedAt: now,
    unlockedBySessionRef: sessionRef,
    createdAt: now,
    updatedAt: now,
    lastMessageAt: null,
    lastMessageType: null,
    lastMessageText: null,
    lastMessageSenderId: null,
    lastMessageId: null,
    lastUnreadMessageAt: null,
    lastUnreadMessageSenderId: null,
    lastReadAtByUserId: {},
  };
}

function buildCallEventMessageId(sessionId) {
  return `${CALL_EVENT_MESSAGE_PREFIX}${sessionId}`;
}

function buildCallEventPreviewText(callKind = CALL_EVENT_KIND_VIDEO) {
  if (String(callKind || "").toLowerCase() === CALL_EVENT_KIND_VIDEO) {
    return "Video call";
  }

  return "Call";
}

function buildCallEventMessagePayload({
  sessionId,
  sessionRef,
  sessionData = {},
}) {
  const callKind = CALL_EVENT_KIND_VIDEO;
  const startedAtMillis = getCallEventStartedAtMillis(sessionData);
  const endedAtMillis = getSessionEndedAtMillis(sessionData) || Date.now();

  return {
    senderId: null,
    senderRef: null,
    type: CONVERSATION_MESSAGE_TYPE_CALL_EVENT,
    text: buildCallEventPreviewText(callKind),
    createdAt: Timestamp.fromMillis(endedAtMillis),
    sessionRef,
    callKind,
    callStartedAt:
      startedAtMillis > 0 ? Timestamp.fromMillis(startedAtMillis) : null,
    callDurationSeconds: resolveCallEventDurationSeconds(sessionData),
    sessionId,
  };
}

function getConversationSortTuple(conversationData = {}) {
  const conversationSortAt =
    conversationData.lastMessageAt || conversationData.unlockedAt || null;
  const conversationSortId =
    conversationData.lastMessageId || conversationData.pairId || "";

  return {
    conversationSortAt,
    conversationSortId,
    pairId: conversationData.pairId || "",
  };
}

function compareConversationSortTuples(left = {}, right = {}) {
  const leftAt = toMillis(left.conversationSortAt);
  const rightAt = toMillis(right.conversationSortAt);
  if (leftAt !== rightAt) return leftAt - rightAt;

  if (left.conversationSortId !== right.conversationSortId) {
    return String(left.conversationSortId || "").localeCompare(
      String(right.conversationSortId || ""),
    );
  }

  return String(left.pairId || "").localeCompare(String(right.pairId || ""));
}

function getMessageTuple(messageId, messageData = {}) {
  return {
    messageId,
    createdAt: messageData.createdAt || null,
    serverCreatedAt: messageData.serverCreatedAt || null,
  };
}

function compareMessageTuples(left = {}, right = {}) {
  const leftAt = toMillis(left.createdAt);
  const rightAt = toMillis(right.createdAt);
  if (leftAt !== rightAt) return leftAt - rightAt;

  const leftServerAt = toMillis(left.serverCreatedAt);
  const rightServerAt = toMillis(right.serverCreatedAt);
  if (leftServerAt !== rightServerAt) return leftServerAt - rightServerAt;

  if (left.messageId !== right.messageId) {
    return String(left.messageId || "").localeCompare(
      String(right.messageId || ""),
    );
  }

  return 0;
}

function isNewerMessageTuple(left = {}, right = {}) {
  return compareMessageTuples(left, right) > 0;
}

function isSupportedConversationMessageType(type) {
  return [
    CONVERSATION_MESSAGE_TYPE_TEXT,
    CONVERSATION_MESSAGE_TYPE_CALL_EVENT,
  ].includes(String(type || ""));
}

function canMessageUpdateConversationSummary(messageData = {}, conversationData = {}) {
  const messageType = String(messageData.type || "");
  if (!isSupportedConversationMessageType(messageType)) {
    return false;
  }

  if (messageType === CONVERSATION_MESSAGE_TYPE_CALL_EVENT) {
    return !!messageData.sessionRef;
  }

  return (
    Array.isArray(conversationData.participantIds) &&
    conversationData.participantIds.includes(messageData.senderId)
  );
}

function buildConversationSummaryUpdate({
  messageId,
  messageData = {},
  serverCreatedAt = null,
}) {
  const messageType =
    String(messageData.type || "") || CONVERSATION_MESSAGE_TYPE_TEXT;
  const update = {
    lastMessageAt: messageData.createdAt || null,
    lastMessageServerCreatedAt: serverCreatedAt || null,
    lastMessageType: messageType,
    lastMessageText:
      String(messageData.text || "") ||
      buildCallEventPreviewText(messageData.callKind),
    lastMessageSenderId: messageData.senderId || null,
    lastMessageId: messageId,
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (messageType === CONVERSATION_MESSAGE_TYPE_TEXT) {
    update.lastUnreadMessageAt = messageData.createdAt || null;
    update.lastUnreadMessageSenderId = messageData.senderId || null;
  }

  return update;
}

function getMaintenanceJobRef(jobName) {
  return admin.firestore().collection("maintenanceJobs").doc(jobName);
}

function getRepairPageSize() {
  const rawValue = Number(process.env.CHATS_REPAIR_PAGE_SIZE);
  if (Number.isFinite(rawValue) && rawValue > 0) {
    return Math.min(Math.floor(rawValue), 200);
  }

  return DEFAULT_REPAIR_PAGE_SIZE;
}

function isStaleUnlockProcessing(eventData = {}, nowMillis = Date.now()) {
  if (String(eventData.status || "") !== "processing") {
    return false;
  }

  const startedAtMillis = toMillis(eventData.processingStartedAt);
  if (startedAtMillis <= 0) {
    return true;
  }

  return nowMillis - startedAtMillis >= STALE_UNLOCK_PROCESSING_MS;
}

function isStaleUnlockPending(eventData = {}, nowMillis = Date.now()) {
  if (String(eventData.status || "") !== "pending") {
    return false;
  }

  const updatedAtMillis = toMillis(eventData.updatedAt);
  const createdAtMillis = toMillis(eventData.createdAt);
  const referenceMillis = updatedAtMillis || createdAtMillis;
  if (referenceMillis <= 0) {
    return true;
  }

  return nowMillis - referenceMillis >= STALE_UNLOCK_PROCESSING_MS;
}

function getMaintenanceCursorState(snapshot) {
  if (!snapshot?.exists) return null;

  const data = snapshot.data() || {};
  const cursorCreatedAt = data.cursorCreatedAt || null;
  const cursorDocumentId = data.cursorDocumentId || null;

  if (!cursorCreatedAt || !cursorDocumentId) {
    return null;
  }

  return {
    cursorCreatedAt,
    cursorDocumentId,
  };
}

module.exports = {
  CALL_EVENT_KIND_VIDEO,
  CONVERSATION_MESSAGE_TYPE_CALL_EVENT,
  CONVERSATION_MESSAGE_TYPE_TEXT,
  buildConversationSeed,
  buildCallEventMessageId,
  buildCallEventMessagePayload,
  buildCallEventPreviewText,
  buildConversationSummaryUpdate,
  conversationMatchesUnlockParticipants,
  buildUnlockEventPayload,
  buildPairId,
  canMessageUpdateConversationSummary,
  compareConversationSortTuples,
  compareMessageTuples,
  getCallEventStartedAtMillis,
  getChatCallEventsRolloutMillis,
  getChatsRolloutMillis,
  getChatsRolloutTimestamp,
  getConnectedCallStartMillis,
  getConversationSortTuple,
  getMaintenanceCursorState,
  getMaintenanceJobRef,
  getMessageTuple,
  getRepairPageSize,
  getSessionEndedAtMillis,
  getUnlockEligibility,
  getUnlockParticipants,
  isEligibleCallEventSession,
  isNewerMessageTuple,
  isQualifyingUnlockSession,
  isSupportedConversationMessageType,
  isStaleUnlockPending,
  isStaleUnlockProcessing,
  resolveCallEventDurationSeconds,
  toMillis,
};
