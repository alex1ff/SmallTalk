const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "send_event_chat_message"});

const REQUEST_TIMEOUT_SECONDS = 30;
const EVENT_STATUS_ACTIVE = "active";
const PARTICIPANT_STATUS_ACTIVE = "active";
const EVENT_CHAT_COLLECTION = "eventChats";
const SEND_EVENT_CHAT_MESSAGE_REQUIRED_KEYS = Object.freeze(["eventId", "text"]);
const SEND_EVENT_CHAT_MESSAGE_KEYS = Object.freeze([
  ...SEND_EVENT_CHAT_MESSAGE_REQUIRED_KEYS,
  "clientMessageId",
]);
const SEND_EVENT_CHAT_MESSAGE_KEY_SET =
  new Set(SEND_EVENT_CHAT_MESSAGE_KEYS);
const LOWERCASE_UUID_V4_PATTERN = new RegExp(
    "^[0-9a-f]{8}-[0-9a-f]{4}-" +
    "4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
);
const EVENT_CHAT_METADATA_KEYS = Object.freeze([
  "eventId",
  "readAccessUserIds",
  "createdAt",
  "updatedAt",
]);
const EVENT_CHAT_METADATA_KEY_SET = new Set(EVENT_CHAT_METADATA_KEYS);
const EVENT_CHAT_MESSAGE_TOMBSTONE_TEXT = "Message removed";
const EVENT_CHAT_MESSAGE_KEYS = Object.freeze([
  "senderId",
  "senderDisplayName",
  "senderPhotoUrl",
  "text",
  "createdAt",
  "deletedAt",
]);
const GRAPHEME_SEGMENTER = typeof Intl !== "undefined" && Intl.Segmenter ?
  new Intl.Segmenter("und", {granularity: "grapheme"}) :
  null;

function throwSendError(code, message, details) {
  throw new functions.https.HttpsError(code, message, details);
}

function throwInvalidSendRequest(field, reason, message) {
  throwSendError(
      "invalid-argument",
      message || "Invalid event chat message request",
      {domainCode: "invalid_event_chat_message_request", field, reason},
  );
}

function validateExactSendEventChatMessageKeys(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throwInvalidSendRequest("payload", "invalid_type");
  }
  for (const key of Object.keys(data)) {
    if (!SEND_EVENT_CHAT_MESSAGE_KEY_SET.has(key)) {
      throwInvalidSendRequest(key, "unknown_key");
    }
  }
  for (const key of SEND_EVENT_CHAT_MESSAGE_REQUIRED_KEYS) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) {
      throwInvalidSendRequest(key, "missing");
    }
  }
}

function countGraphemes(value) {
  if (!GRAPHEME_SEGMENTER) {
    return Array.from(value).length;
  }
  return Array.from(GRAPHEME_SEGMENTER.segment(value)).length;
}

function normalizeEventId(value) {
  if (typeof value !== "string") {
    throwInvalidSendRequest("eventId", "invalid_type");
  }
  const eventId = value.trim();
  if (
    !eventId ||
    eventId === "." ||
    eventId === ".." ||
    eventId.includes("/") ||
    Buffer.byteLength(eventId, "utf8") > 1500
  ) {
    throwInvalidSendRequest("eventId", "invalid_format");
  }
  return eventId;
}

function normalizeMessageText(value) {
  if (typeof value !== "string") {
    throwInvalidSendRequest("text", "invalid_type");
  }
  const text = value
      .normalize("NFC")
      .replace(/\r\n?/g, "\n")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
  if (!text) {
    throwInvalidSendRequest("text", "missing");
  }
  if (countGraphemes(text) > 1000) {
    throwInvalidSendRequest("text", "too_long");
  }
  return text;
}

function normalizeClientMessageId(value) {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value !== "string") {
    throwInvalidSendRequest("clientMessageId", "invalid_type");
  }
  if (!LOWERCASE_UUID_V4_PATTERN.test(value)) {
    throwInvalidSendRequest("clientMessageId", "invalid_format");
  }
  return value;
}

function normalizeSendEventChatMessagePayload(data) {
  validateExactSendEventChatMessageKeys(data);
  return {
    eventId: normalizeEventId(data.eventId),
    text: normalizeMessageText(data.text),
    clientMessageId: normalizeClientMessageId(data.clientMessageId),
  };
}

function isValidPathSegment(value) {
  return typeof value === "string" && value.length > 0 && !value.includes("/");
}

function hasTimestampValue(value) {
  if (!value || typeof value.toMillis !== "function") {
    return false;
  }
  try {
    return Number.isFinite(Number(value.toMillis()));
  } catch (_) {
    return false;
  }
}

function normalizeProfileString(value) {
  return typeof value === "string" ? value.normalize("NFC").trim() : "";
}

function failParticipantMembershipInconsistent() {
  throwSendError(
      "failed-precondition",
      "Participant membership is inconsistent",
      {domainCode: "participant_membership_inconsistent"},
  );
}

function assertEventAllowsChatWrites({eventExists, eventData, eventId}) {
  if (!eventExists) {
    throwSendError(
        "not-found",
        "Event not found",
        {domainCode: "event_not_found"},
    );
  }
  if (eventData.status !== EVENT_STATUS_ACTIVE || eventData.canceledAt !== null) {
    throwSendError(
        "failed-precondition",
        "Event chat is read-only",
        {domainCode: "event_chat_writes_blocked", reason: "event_canceled"},
    );
  }
  if (eventData.chatId !== eventId) {
    throwSendError(
        "failed-precondition",
        "Event chat id does not match event id",
        {
          domainCode: "event_chat_metadata_invalid",
          reason: "event_chat_id_mismatch",
        },
    );
  }
}

function assertChatMetadata({chatExists, chatData, eventId}) {
  if (!chatExists) {
    throwSendError(
        "failed-precondition",
        "Event chat metadata is missing",
        {domainCode: "event_chat_metadata_invalid", reason: "missing"},
    );
  }
  const keys = chatData && typeof chatData === "object" ?
    Object.keys(chatData) :
    [];
  const hasExactKeys = keys.length === EVENT_CHAT_METADATA_KEYS.length &&
    EVENT_CHAT_METADATA_KEYS.every((key) =>
      Object.prototype.hasOwnProperty.call(chatData, key),
    ) &&
    keys.every((key) => EVENT_CHAT_METADATA_KEY_SET.has(key));
  if (
    !hasExactKeys ||
    !Array.isArray(chatData.readAccessUserIds) ||
    !hasTimestampValue(chatData.createdAt) ||
    !hasTimestampValue(chatData.updatedAt)
  ) {
    throwSendError(
        "failed-precondition",
        "Event chat metadata is invalid",
        {domainCode: "event_chat_metadata_invalid", reason: "invalid_shape"},
    );
  }
  if (chatData.eventId !== eventId) {
    throwSendError(
        "failed-precondition",
        "Event chat metadata does not match event id",
        {
          domainCode: "event_chat_metadata_invalid",
          reason: "chat_event_id_mismatch",
        },
    );
  }
}

function assertParticipantCanSend({
  participantExists,
  participantData,
  uid,
}) {
  if (!participantExists || participantData.status === "left") {
    throwSendError(
        "failed-precondition",
        "User is not an active event participant",
        {domainCode: "not_active_participant"},
    );
  }
  if (
    participantData.userId !== uid ||
    !["organizer", "participant"].includes(participantData.role)
  ) {
    failParticipantMembershipInconsistent();
  }
  if (
    participantData.status !== PARTICIPANT_STATUS_ACTIVE ||
    participantData.leftAt !== null
  ) {
    failParticipantMembershipInconsistent();
  }
}

function normalizeSenderPhotoUrl({participantData, userData}) {
  const photoUrl = normalizeProfileString(participantData.photoUrl) ||
    normalizeProfileString(userData.photo_url);
  if (countGraphemes(photoUrl) > 2048) {
    throwSendError(
        "failed-precondition",
        "Sender photo URL is invalid",
        {domainCode: "sender_profile_invalid", field: "photo_url"},
    );
  }
  return photoUrl || null;
}

function buildSenderSnapshot({
  participantData,
  userExists,
  userData = {},
}) {
  const displayName = normalizeProfileString(participantData.displayName) ||
    (userExists ? normalizeProfileString(userData.display_name) : "");
  if (!displayName) {
    throwSendError(
        "failed-precondition",
        "Sender display name is required",
        {domainCode: "sender_profile_required", field: "display_name"},
    );
  }
  if (countGraphemes(displayName) > 70) {
    throwSendError(
        "failed-precondition",
        "Sender display name is invalid",
        {domainCode: "sender_profile_invalid", field: "display_name"},
    );
  }
  return {
    displayName,
    photoUrl: normalizeSenderPhotoUrl({participantData, userData}),
  };
}

function buildMessageData({
  uid,
  senderSnapshot,
  text,
  messageTimestamp,
}) {
  return {
    senderId: uid,
    senderDisplayName: senderSnapshot.displayName,
    senderPhotoUrl: senderSnapshot.photoUrl,
    text,
    createdAt: messageTimestamp,
    deletedAt: null,
  };
}

function throwInvalidTombstoneRequest(field, reason) {
  throwSendError(
      "invalid-argument",
      "Invalid event chat message tombstone request",
      {
        domainCode: "invalid_event_chat_message_tombstone_request",
        field,
        reason,
      },
  );
}

function normalizeTombstonePathSegment(value, field) {
  const normalized = typeof value === "string" ? value.trim() : value;
  if (
    !isValidPathSegment(normalized) ||
    normalized === "." ||
    normalized === ".."
  ) {
    throwInvalidTombstoneRequest(field, "invalid_format");
  }
  return normalized;
}

function validateTombstoneTimestamp(value) {
  if (!hasTimestampValue(value) || typeof value.toDate !== "function") {
    throwInvalidTombstoneRequest("deletedAt", "invalid_type");
  }
  return value;
}

function assertTombstoneMessageData({messageExists, messageData}) {
  if (!messageExists) {
    throwSendError(
        "not-found",
        "Event chat message not found",
        {domainCode: "event_chat_message_not_found"},
    );
  }
  for (const key of EVENT_CHAT_MESSAGE_KEYS) {
    if (!Object.prototype.hasOwnProperty.call(messageData, key)) {
      throwSendError(
          "failed-precondition",
          "Event chat message is invalid",
          {domainCode: "event_chat_message_invalid", reason: "invalid_shape"},
      );
    }
  }
  if (
    typeof messageData.senderId !== "string" ||
    typeof messageData.senderDisplayName !== "string" ||
    !(
      messageData.senderPhotoUrl === null ||
      typeof messageData.senderPhotoUrl === "string"
    ) ||
    typeof messageData.text !== "string" ||
    !hasTimestampValue(messageData.createdAt) ||
    !(
      messageData.deletedAt === null ||
      hasTimestampValue(messageData.deletedAt)
    )
  ) {
    throwSendError(
        "failed-precondition",
        "Event chat message is invalid",
        {domainCode: "event_chat_message_invalid", reason: "invalid_shape"},
    );
  }
}

function buildTombstonedMessageData(messageData, deletedTimestamp) {
  return {
    senderId: messageData.senderId,
    senderDisplayName: messageData.senderDisplayName,
    senderPhotoUrl: messageData.senderPhotoUrl,
    text: EVENT_CHAT_MESSAGE_TOMBSTONE_TEXT,
    createdAt: messageData.createdAt,
    deletedAt: messageData.deletedAt || deletedTimestamp,
  };
}

async function tombstoneEventChatMessage({
  db,
  eventId,
  messageId,
  deletedTimestamp,
}) {
  const normalizedEventId = normalizeTombstonePathSegment(eventId, "eventId");
  const normalizedMessageId = normalizeTombstonePathSegment(
      messageId,
      "messageId",
  );
  const normalizedDeletedTimestamp =
    validateTombstoneTimestamp(deletedTimestamp);
  const messageRef = db
      .collection(EVENT_CHAT_COLLECTION)
      .doc(normalizedEventId)
      .collection("messages")
      .doc(normalizedMessageId);

  return await db.runTransaction(async (tx) => {
    const messageDoc = await tx.get(messageRef);
    const messageData = messageDoc.exists ? messageDoc.data() || {} : {};
    assertTombstoneMessageData({
      messageExists: messageDoc.exists,
      messageData,
    });
    const tombstonedData = buildTombstonedMessageData(
        messageData,
        normalizedDeletedTimestamp,
    );
    tx.set(messageRef, tombstonedData);
    return {
      eventId: normalizedEventId,
      messageId: normalizedMessageId,
      deletedAt: tombstonedData.deletedAt.toDate().toISOString(),
    };
  });
}

async function executeSendEventChatMessageTransaction({
  db,
  uid,
  messageDate,
  messageTimestamp,
  payload,
}) {
  if (!isValidPathSegment(uid)) {
    failParticipantMembershipInconsistent();
  }
  const eventRef = db.collection("events").doc(payload.eventId);
  const chatRef = db.collection(EVENT_CHAT_COLLECTION).doc(payload.eventId);
  const participantRef = eventRef.collection("participants").doc(uid);
  const userRef = db.collection("users").doc(uid);
  const messageRef = payload.clientMessageId ?
    chatRef.collection("messages").doc(payload.clientMessageId) :
    chatRef.collection("messages").doc();

  return await db.runTransaction(async (tx) => {
    const [eventDoc, chatDoc, participantDoc, userDoc, messageDoc] =
    await Promise.all([
      tx.get(eventRef),
      tx.get(chatRef),
      tx.get(participantRef),
      tx.get(userRef),
      payload.clientMessageId ? tx.get(messageRef) : Promise.resolve(null),
    ]);
    const eventData = eventDoc.exists ? eventDoc.data() || {} : {};
    const chatData = chatDoc.exists ? chatDoc.data() || {} : {};
    const participantData = participantDoc.exists ?
      participantDoc.data() || {} :
      {};
    const userData = userDoc.exists ? userDoc.data() || {} : {};
    if (messageDoc?.exists) {
      const messageData = messageDoc.data() || {};
      if (
        messageData.senderId !== uid ||
        messageData.text !== payload.text ||
        !hasTimestampValue(messageData.createdAt)
      ) {
        throwSendError(
            "already-exists",
            "Event chat message id already exists",
            {
              domainCode: "event_chat_message_id_conflict",
              field: "clientMessageId",
            },
        );
      }
      return {
        eventId: payload.eventId,
        messageId: messageRef.id,
        createdAt: messageData.createdAt.toDate().toISOString(),
      };
    }

    assertEventAllowsChatWrites({
      eventExists: eventDoc.exists,
      eventData,
      eventId: payload.eventId,
    });
    assertChatMetadata({
      chatExists: chatDoc.exists,
      chatData,
      eventId: payload.eventId,
    });
    assertParticipantCanSend({
      participantExists: participantDoc.exists,
      participantData,
      uid,
    });
    const senderSnapshot = buildSenderSnapshot({
      participantData,
      userExists: userDoc.exists,
      userData,
    });

    tx.create(messageRef, buildMessageData({
      uid,
      senderSnapshot,
      text: payload.text,
      messageTimestamp,
    }));

    return {
      eventId: payload.eventId,
      messageId: messageRef.id,
      createdAt: messageDate.toISOString(),
    };
  });
}

exports.__private__ = {
  EVENT_CHAT_MESSAGE_TOMBSTONE_TEXT,
  SEND_EVENT_CHAT_MESSAGE_KEYS,
  buildMessageData,
  buildSenderSnapshot,
  executeSendEventChatMessageTransaction,
  normalizeMessageText,
  normalizeSendEventChatMessagePayload,
  tombstoneEventChatMessage,
};

exports.sendEventChatMessage = functions
    .runWith({timeoutSeconds: REQUEST_TIMEOUT_SECONDS, memory: "256MB"})
    .https.onCall(async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be authenticated",
            {domainCode: "auth_required"},
        );
      }

      const uid = context.auth.uid;
      const payload = normalizeSendEventChatMessagePayload(data);
      const messageDate = new Date();
      const messageTimestamp = admin.firestore.Timestamp.fromDate(messageDate);
      const db = admin.firestore();

      try {
        return await executeSendEventChatMessageTransaction({
          db,
          uid,
          messageDate,
          messageTimestamp,
          payload,
        });
      } catch (err) {
        if (err instanceof functions.https.HttpsError) {
          throw err;
        }
        safeLog.error("send_event_chat_message_failed", {
          uid,
          eventId: payload.eventId,
          error: err,
        });
        throw new functions.https.HttpsError(
            "internal",
            "Unable to send event chat message",
        );
      }
    });
