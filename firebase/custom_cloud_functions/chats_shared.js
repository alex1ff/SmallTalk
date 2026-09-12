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
const CALL_EVENT_OUTCOME_COMPLETED = "completed";
const CALL_EVENT_OUTCOME_MISSED = "missed";
const CALL_EVENT_OUTCOME_CANCELLED = "cancelled";
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

function normalizeCallOutcome(value) {
  const normalized = String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, "_");
  if ([
    CALL_EVENT_OUTCOME_COMPLETED,
    CALL_EVENT_OUTCOME_MISSED,
    CALL_EVENT_OUTCOME_CANCELLED,
  ].includes(normalized)) {
    return normalized;
  }
  return "";
}

function getConnectedCallStartMillis(sessionData = {}) {
  const callConnectedAt = toMillis(sessionData.sessionMetadata?.callConnectedAt);
  const legacyCallConnectedAt = toMillis(
    sessionData.sessionMetadata?.callConnectedAtTimestamp,
  );

  return callConnectedAt || legacyCallConnectedAt || 0;
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

function getCallEventParticipants(sessionData = {}, options = {}) {
  const studentId =
    sessionData.studentId ||
    sessionData.matchContext?.requesterId ||
    null;
  const responderId =
    options.partnerId ||
    sessionData.tutorId ||
    sessionData.currentTutorId ||
    sessionData.acceptingTutorId ||
    sessionData.matchContext?.acceptedResponderId ||
    null;

  if (!studentId || !responderId || studentId === responderId) {
    return null;
  }

  const pairId = buildPairId(studentId, responderId);
  if (!pairId) {
    return null;
  }

  const participantIds = [studentId, responderId].sort();
  const participantRefs = participantIds.map((uid) =>
    admin.firestore().collection("users").doc(uid),
  );

  return {
    studentId,
    tutorId: responderId,
    pairId,
    participantIds,
    participantRefs,
    callerId: studentId,
    recipientId: responderId,
  };
}

function getSessionEndedAtMillis(sessionData = {}) {
  return (
    toMillis(sessionData.endedAt) ||
    toMillis(sessionData.sessionMetadata?.endedAtTimestamp) ||
    0
  );
}

function getCallEventEndedAtMillis(sessionData = {}, options = {}) {
  return (
    toMillis(options.eventMillis) ||
    toMillis(options.callEndedAt) ||
    getSessionEndedAtMillis(sessionData) ||
    toMillis(sessionData.cancelledAt) ||
    toMillis(sessionData.declinedAt) ||
    toMillis(sessionData.expiredAt) ||
    toMillis(sessionData.sessionMetadata?.endedAtTimestamp) ||
    Date.now()
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

function resolveConversationCallOutcome(sessionData = {}, options = {}) {
  const override = normalizeCallOutcome(options.callOutcome);
  if (override) {
    return override;
  }

  const status = String(sessionData.status || "").trim().toLowerCase();
  if (status === "ended") {
    return getConnectedCallStartMillis(sessionData) > 0 ?
      CALL_EVENT_OUTCOME_COMPLETED :
      CALL_EVENT_OUTCOME_MISSED;
  }

  if (status === "cancelled" || status === "canceled") {
    return CALL_EVENT_OUTCOME_CANCELLED;
  }

  if (status === "expired" || status === "declined") {
    return CALL_EVENT_OUTCOME_MISSED;
  }

  return "";
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

function getConversationCallEventEligibility(sessionData = {}, options = {}) {
  const participants = getCallEventParticipants(sessionData, options);
  if (!participants) {
    return { eligible: false, reason: "ignored_invalid_pair" };
  }

  const callOutcome = resolveConversationCallOutcome(sessionData, options);
  if (!callOutcome) {
    return { eligible: false, reason: "ignored_not_final" };
  }
  if (
    callOutcome === CALL_EVENT_OUTCOME_COMPLETED &&
    getConnectedCallStartMillis(sessionData) <= 0
  ) {
    return { eligible: false, reason: "ignored_not_connected" };
  }

  if (toMillis(sessionData.createdAt) < getChatsRolloutMillis()) {
    return { eligible: false, reason: "ignored_pre_rollout" };
  }

  const eventMillis = getCallEventEndedAtMillis(sessionData, options);
  if (eventMillis < getChatCallEventsRolloutMillis()) {
    return { eligible: false, reason: "ignored_pre_call_event_rollout" };
  }

  return {
    eligible: true,
    reason: null,
    callOutcome,
    callEndedAtMillis: eventMillis,
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

function buildConversationParticipantMap(participantIds = []) {
  return participantIds.reduce((participantMap, uid) => {
    const normalizedUid = String(uid || "").trim();
    if (normalizedUid) {
      participantMap[normalizedUid] = true;
    }
    return participantMap;
  }, {});
}

function normalizeConversationParticipantText(value, maxLength) {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  if (!normalized || Array.from(normalized).length > maxLength) return null;
  return normalized;
}

function buildConversationParticipantInfoByUserId({
  participants,
  sessionData = {},
  existingInfoByUserId = {},
  preferIncoming = false,
}) {
  const rawInfos = sessionData.participantInfos;
  const sessionInfos = rawInfos && typeof rawInfos === "object" ? rawInfos : {};
  const existingInfos = existingInfoByUserId &&
      typeof existingInfoByUserId === "object" ?
    existingInfoByUserId : {};
  const result = {};

  for (const uid of participants.participantIds || []) {
    const existing = existingInfos[uid] &&
        typeof existingInfos[uid] === "object" ?
      existingInfos[uid] : {};
    const existingHasPhoto = Object.prototype.hasOwnProperty.call(
      existing,
      "photoUrl",
    );
    let incoming = sessionInfos[uid] &&
        typeof sessionInfos[uid] === "object" ?
      sessionInfos[uid] : null;
    let incomingPhotoIsAuthoritative = incoming !== null &&
      Object.prototype.hasOwnProperty.call(incoming, "photoUrl");

    if (!incoming) {
      if (uid === participants.studentId && sessionData.studentInfo) {
        incoming = sessionData.studentInfo;
      } else if (uid === participants.tutorId && sessionData.tutorInfo) {
        incoming = sessionData.tutorInfo;
      }
      incomingPhotoIsAuthoritative = false;
    }

    const existingDisplayName = normalizeConversationParticipantText(
      existing.displayName,
      70,
    );
    const incomingDisplayName = normalizeConversationParticipantText(
      incoming?.displayName ?? incoming?.name,
      70,
    );
    const existingPhotoUrl = normalizeConversationParticipantText(
      existing.photoUrl,
      2048,
    );
    const incomingPhotoValue = incomingPhotoIsAuthoritative ?
      incoming.photoUrl :
      (incoming?.photoUrl ?? incoming?.photo);
    const incomingPhotoUrl = normalizeConversationParticipantText(
      incomingPhotoValue,
      2048,
    );
    const displayName = preferIncoming ?
      (incomingDisplayName || existingDisplayName) :
      (existingDisplayName || incomingDisplayName);
    const photoUrl = preferIncoming && incomingPhotoIsAuthoritative ?
      incomingPhotoUrl :
      (existingHasPhoto ? existingPhotoUrl :
        (incomingPhotoIsAuthoritative ? incomingPhotoUrl :
          (incomingPhotoUrl || existingPhotoUrl)));

    if (displayName || photoUrl || incomingPhotoIsAuthoritative ||
        existingHasPhoto) {
      result[uid] = {
        displayName: displayName || null,
        photoUrl: photoUrl || null,
      };
    }
  }

  return result;
}

function buildConversationSeed({
  participants,
  sessionRef,
  sessionData = {},
}) {
  const now = FieldValue.serverTimestamp();
  return {
    pairId: participants.pairId,
    participantIds: participants.participantIds,
    participantRefs: participants.participantRefs,
    participantMap: buildConversationParticipantMap(participants.participantIds),
    participantInfoByUserId: buildConversationParticipantInfoByUserId({
      participants,
      sessionData,
    }),
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

function buildCallEventMessageId(sessionId, callOutcome = "") {
  const normalizedOutcome = normalizeCallOutcome(callOutcome);
  const suffix =
    normalizedOutcome && normalizedOutcome !== CALL_EVENT_OUTCOME_COMPLETED ?
      `_${normalizedOutcome}` :
      "";
  return `${CALL_EVENT_MESSAGE_PREFIX}${sessionId}${suffix}`;
}

function buildCallEventPreviewText(
  callKind = CALL_EVENT_KIND_VIDEO,
  callOutcome = CALL_EVENT_OUTCOME_COMPLETED,
) {
  if (String(callKind || "").toLowerCase() === CALL_EVENT_KIND_VIDEO) {
    const outcome = normalizeCallOutcome(callOutcome);
    if (outcome === CALL_EVENT_OUTCOME_MISSED) {
      return "Missed video call";
    }
    if (outcome === CALL_EVENT_OUTCOME_CANCELLED) {
      return "Cancelled video call";
    }
    return "Video call";
  }

  return "Call";
}

function buildCallEventMessagePayload({
  sessionId,
  sessionRef,
  sessionData = {},
  callOutcome,
  callEndedAtMillis,
  callerId,
  recipientId,
}) {
  const callKind = CALL_EVENT_KIND_VIDEO;
  const outcome =
    normalizeCallOutcome(callOutcome) ||
    resolveConversationCallOutcome(sessionData) ||
    CALL_EVENT_OUTCOME_COMPLETED;
  const startedAtMillis = getCallEventStartedAtMillis(sessionData);
  const endedAtMillis =
    Number.isFinite(Number(callEndedAtMillis)) && Number(callEndedAtMillis) > 0 ?
      Math.floor(Number(callEndedAtMillis)) :
      getCallEventEndedAtMillis(sessionData);
  const durationSeconds = outcome === CALL_EVENT_OUTCOME_COMPLETED ?
    resolveCallEventDurationSeconds(sessionData) :
    0;

  return {
    senderId: null,
    senderRef: null,
    type: CONVERSATION_MESSAGE_TYPE_CALL_EVENT,
    text: buildCallEventPreviewText(callKind, outcome),
    createdAt: Timestamp.fromMillis(endedAtMillis),
    sessionRef,
    callKind,
    callOutcome: outcome,
    callerId: callerId || sessionData.studentId || null,
    recipientId:
      recipientId ||
      sessionData.tutorId ||
      sessionData.currentTutorId ||
      null,
    callStartedAt:
      startedAtMillis > 0 ? Timestamp.fromMillis(startedAtMillis) : null,
    callEndedAt: Timestamp.fromMillis(endedAtMillis),
    callDurationSeconds: durationSeconds,
    sessionId,
  };
}

async function ensureConversationCallEventForSession({
  db,
  sessionId,
  sessionRef,
  sessionData = {},
  callOutcome,
  eventMillis,
  partnerId,
  conversationRef: providedConversationRef,
}) {
  const eligibility = getConversationCallEventEligibility(sessionData, {
    callOutcome,
    eventMillis,
    partnerId,
  });
  if (!eligibility.eligible) {
    return {
      status: "skipped",
      reason: eligibility.reason,
    };
  }

  const conversationRef =
    providedConversationRef ||
    db.collection("conversations").doc(eligibility.pairId);
  const messageRef = conversationRef
    .collection("messages")
    .doc(buildCallEventMessageId(sessionId, eligibility.callOutcome));
  const messagePayload = buildCallEventMessagePayload({
    sessionId,
    sessionRef,
    sessionData,
    callOutcome: eligibility.callOutcome,
    callEndedAtMillis: eligibility.callEndedAtMillis,
    callerId: eligibility.callerId,
    recipientId: eligibility.recipientId,
  });

  return db.runTransaction(async (transaction) => {
    const conversationSnap = await transaction.get(conversationRef);
    const conversationData = conversationSnap.data() || {};

    if (
      conversationSnap.exists &&
      !conversationMatchesUnlockParticipants(
        {
          ...conversationData,
          pairId: conversationData.pairId || conversationRef.id,
        },
        eligibility,
      )
    ) {
      return { status: "skipped_conversation_pair_mismatch" };
    }

    const messageSnap = await transaction.get(messageRef);

    if (!conversationSnap.exists) {
      transaction.set(
        conversationRef,
        buildConversationSeed({
          participants: eligibility,
          sessionRef,
          sessionData,
        }),
      );
    } else if (conversationData.isUnlocked !== true) {
      transaction.set(
        conversationRef,
        {
          isUnlocked: true,
          unlockedAt: FieldValue.serverTimestamp(),
          unlockedBySessionRef: sessionRef,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    transaction.set(
      conversationRef,
      {
        participantMap: buildConversationParticipantMap(
          eligibility.participantIds,
        ),
        participantInfoByUserId: buildConversationParticipantInfoByUserId({
          participants: eligibility,
          sessionData,
          existingInfoByUserId: conversationData.participantInfoByUserId,
        }),
      },
      { merge: true },
    );

    if (!messageSnap.exists) {
      transaction.set(messageRef, messagePayload);
    }

    const messageTuple = getMessageTuple(messageRef.id, messagePayload);
    const currentTuple = {
      createdAt: conversationData.lastMessageAt || null,
      serverCreatedAt: conversationData.lastMessageServerCreatedAt || null,
      messageId: conversationData.lastMessageId || "",
    };
    const isSameSummaryMessage = conversationData.lastMessageId === messageRef.id;
    const summaryNeedsRefresh =
      isSameSummaryMessage &&
      (
        conversationData.lastMessageType !== CONVERSATION_MESSAGE_TYPE_CALL_EVENT ||
        conversationData.lastCallOutcome !== eligibility.callOutcome ||
        conversationData.lastCallCallerId !== eligibility.callerId ||
        conversationData.lastCallRecipientId !== eligibility.recipientId
      );
    if (
      !conversationSnap.exists ||
      isNewerMessageTuple(messageTuple, currentTuple) ||
      summaryNeedsRefresh
    ) {
      transaction.set(
        conversationRef,
        buildConversationSummaryUpdate({
          messageId: messageRef.id,
          messageData: messagePayload,
        }),
        { merge: true },
      );
    }

    return {
      status: messageSnap.exists ? "already_exists" : "created",
      conversationRef,
      messageRef,
      callOutcome: eligibility.callOutcome,
    };
  });
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
      buildCallEventPreviewText(messageData.callKind, messageData.callOutcome),
    lastMessageSenderId: messageData.senderId || null,
    lastMessageId: messageId,
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (messageType === CONVERSATION_MESSAGE_TYPE_CALL_EVENT) {
    update.lastCallOutcome = messageData.callOutcome || null;
    update.lastCallCallerId = messageData.callerId || null;
    update.lastCallRecipientId = messageData.recipientId || null;
  } else {
    update.lastCallOutcome = FieldValue.delete();
    update.lastCallCallerId = FieldValue.delete();
    update.lastCallRecipientId = FieldValue.delete();
  }

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
  CALL_EVENT_OUTCOME_CANCELLED,
  CALL_EVENT_OUTCOME_COMPLETED,
  CALL_EVENT_OUTCOME_MISSED,
  CONVERSATION_MESSAGE_TYPE_CALL_EVENT,
  CONVERSATION_MESSAGE_TYPE_TEXT,
  buildConversationSeed,
  buildCallEventMessageId,
  buildCallEventMessagePayload,
  buildCallEventPreviewText,
  buildConversationParticipantMap,
  buildConversationParticipantInfoByUserId,
  buildConversationSummaryUpdate,
  conversationMatchesUnlockParticipants,
  buildUnlockEventPayload,
  buildPairId,
  canMessageUpdateConversationSummary,
  compareConversationSortTuples,
  compareMessageTuples,
  ensureConversationCallEventForSession,
  getCallEventStartedAtMillis,
  getConversationCallEventEligibility,
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
  normalizeCallOutcome,
  resolveConversationCallOutcome,
  isEligibleCallEventSession,
  isNewerMessageTuple,
  isQualifyingUnlockSession,
  isSupportedConversationMessageType,
  isStaleUnlockPending,
  isStaleUnlockProcessing,
  resolveCallEventDurationSeconds,
  toMillis,
};
