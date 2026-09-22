const crypto = require("node:crypto");
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

const REQUEST_TIMEOUT_SECONDS = 30;
const CHAT_MESSAGE_REPORTS_COLLECTION = "chatMessageReports";
const EVENT_CHAT_COLLECTION = "eventChats";
const EVENT_STATUS_ACTIVE = "active";
const EVENT_STATUS_CANCELED = "canceled";
const PARTICIPANT_STATUS_ACTIVE = "active";
const REPORT_EVENT_CHAT_MESSAGE_KEYS = Object.freeze([
  "eventId",
  "messageId",
  "reasonCode",
  "details",
]);
const REPORT_EVENT_CHAT_MESSAGE_REQUIRED_KEYS = Object.freeze([
  "eventId",
  "messageId",
  "reasonCode",
]);
const REPORT_EVENT_CHAT_MESSAGE_KEY_SET =
  new Set(REPORT_EVENT_CHAT_MESSAGE_KEYS);
const CHAT_MESSAGE_REPORT_REASON_CODES = Object.freeze([
  "spam",
  "offensive",
  "unsafe",
  "other",
]);
const CHAT_MESSAGE_REPORT_REASON_CODE_SET =
  new Set(CHAT_MESSAGE_REPORT_REASON_CODES);
const CHAT_MESSAGE_REPORT_DETAILS_MAX_LENGTH = 500;
const EVENT_CHAT_METADATA_KEYS = Object.freeze([
  "eventId",
  "readAccessUserIds",
  "createdAt",
  "updatedAt",
]);
const EVENT_CHAT_METADATA_KEY_SET = new Set(EVENT_CHAT_METADATA_KEYS);
const EVENT_CHAT_MESSAGE_KEYS = Object.freeze([
  "senderId",
  "senderDisplayName",
  "senderPhotoUrl",
  "text",
  "createdAt",
  "deletedAt",
]);
const EVENT_CHAT_MESSAGE_KEY_SET = new Set(EVENT_CHAT_MESSAGE_KEYS);

function throwReportChatMessageError(code, message, details) {
  throw new functions.https.HttpsError(code, message, details);
}

function throwInvalidReportChatMessageRequest(field, reason, message) {
  throwReportChatMessageError(
      "invalid-argument",
      message || "Invalid report event chat message request",
      {
        domainCode: "invalid_report_event_chat_message_request",
        field,
        reason,
      },
  );
}

function validateExactReportEventChatMessageKeys(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throwInvalidReportChatMessageRequest("payload", "invalid_type");
  }
  for (const key of Object.keys(data)) {
    if (!REPORT_EVENT_CHAT_MESSAGE_KEY_SET.has(key)) {
      throwInvalidReportChatMessageRequest(key, "unknown_key");
    }
  }
  for (const key of REPORT_EVENT_CHAT_MESSAGE_REQUIRED_KEYS) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) {
      throwInvalidReportChatMessageRequest(key, "missing");
    }
  }
}

function normalizePathSegment(value, field) {
  if (typeof value !== "string") {
    throwInvalidReportChatMessageRequest(field, "invalid_type");
  }
  const normalized = value.trim();
  if (!isValidPathSegment(normalized)) {
    throwInvalidReportChatMessageRequest(field, "invalid_format");
  }
  return normalized;
}

function normalizeReasonCode(value) {
  if (typeof value !== "string") {
    throwInvalidReportChatMessageRequest("reasonCode", "invalid_type");
  }
  const reasonCode = value.trim().toLowerCase();
  if (!CHAT_MESSAGE_REPORT_REASON_CODE_SET.has(reasonCode)) {
    throwInvalidReportChatMessageRequest("reasonCode", "unsupported");
  }
  return reasonCode;
}

function normalizeDetails(value) {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value !== "string") {
    throwInvalidReportChatMessageRequest("details", "invalid_type");
  }
  const details = value.normalize("NFC").trim();
  if (!details) {
    return null;
  }
  if ([...details].length > CHAT_MESSAGE_REPORT_DETAILS_MAX_LENGTH) {
    throwInvalidReportChatMessageRequest("details", "too_long");
  }
  return details;
}

function normalizeReportEventChatMessagePayload(data) {
  validateExactReportEventChatMessageKeys(data);
  return {
    eventId: normalizePathSegment(data.eventId, "eventId"),
    messageId: normalizePathSegment(data.messageId, "messageId"),
    reasonCode: normalizeReasonCode(data.reasonCode),
    details: normalizeDetails(data.details),
  };
}

function normalizeUserId(value) {
  return typeof value === "string" ? value.trim() : "";
}

function isValidPathSegment(value) {
  return typeof value === "string" &&
    value.length > 0 &&
    value !== "." &&
    value !== ".." &&
    !value.includes("/") &&
    !/^__.*__$/.test(value) &&
    Buffer.byteLength(value, "utf8") <= 1500;
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

function timestampToIso(value) {
  if (value && typeof value.toDate === "function") {
    const date = value.toDate();
    if (date instanceof Date && Number.isFinite(date.getTime())) {
      return date.toISOString();
    }
  }
  if (value instanceof Date && Number.isFinite(value.getTime())) {
    return value.toISOString();
  }
  return null;
}

function buildChatMessageReportId({eventId, messageId, reporterId}) {
  return crypto
      .createHash("sha256")
      .update(JSON.stringify([reporterId, "event_chat", eventId, messageId]))
      .digest("hex");
}

function normalizeSnapshotString(value) {
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.normalize("NFC").trim();
  return normalized || null;
}

function eventSnapshot(eventData = {}) {
  return {
    title: normalizeSnapshotString(eventData.title),
    status: normalizeSnapshotString(eventData.status),
    startsAt: eventData.startsAt || null,
    countryCode: normalizeSnapshotString(eventData.countryCode),
    cityKey: normalizeSnapshotString(eventData.cityKey),
    organizerId: normalizeSnapshotString(eventData.organizerId),
  };
}

function messageSnapshot(messageData = {}) {
  return {
    senderId: normalizeSnapshotString(messageData.senderId),
    senderDisplayName: normalizeSnapshotString(messageData.senderDisplayName),
    text: normalizeSnapshotString(messageData.text),
    createdAt: messageData.createdAt || null,
  };
}

function assertEventAndChatMetadata({
  eventExists,
  eventData,
  chatExists,
  chatData,
  eventId,
}) {
  if (!eventExists) {
    throwReportChatMessageError(
        "not-found",
        "Event not found",
        {domainCode: "event_not_found"},
    );
  }
  if (eventData.chatId !== eventId) {
    throwReportChatMessageError(
        "failed-precondition",
        "Event chat id does not match event id",
        {
          domainCode: "event_chat_metadata_invalid",
          reason: "event_chat_id_mismatch",
        },
    );
  }
  if (!chatExists) {
    throwReportChatMessageError(
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
    chatData.eventId !== eventId ||
    !Array.isArray(chatData.readAccessUserIds) ||
    !hasTimestampValue(chatData.createdAt) ||
    !hasTimestampValue(chatData.updatedAt)
  ) {
    throwReportChatMessageError(
        "failed-precondition",
        "Event chat metadata is invalid",
        {domainCode: "event_chat_metadata_invalid", reason: "invalid_shape"},
    );
  }
}

function isActiveParticipant({participantExists, participantData, uid}) {
  return participantExists &&
    participantData.userId === uid &&
    participantData.status === PARTICIPANT_STATUS_ACTIVE &&
    participantData.leftAt === null &&
    ["organizer", "participant"].includes(participantData.role);
}

function assertReporterCanReadChat({
  eventData,
  chatData,
  participantExists,
  participantData,
  reporterId,
}) {
  if (
    eventData.status === EVENT_STATUS_ACTIVE &&
    eventData.canceledAt === null
  ) {
    if (!isActiveParticipant({
      participantExists,
      participantData,
      uid: reporterId,
    })) {
      throwReportChatMessageError(
          "failed-precondition",
          "User is not an active event participant",
          {domainCode: "not_active_participant"},
      );
    }
    return;
  }

  if (
    eventData.status === EVENT_STATUS_CANCELED &&
    hasTimestampValue(eventData.canceledAt)
  ) {
    if (!chatData.readAccessUserIds.includes(reporterId)) {
      throwReportChatMessageError(
          "permission-denied",
          "User cannot read this canceled event chat",
          {domainCode: "event_chat_access_denied"},
      );
    }
    return;
  }

  throwReportChatMessageError(
      "failed-precondition",
      "Event chat state is invalid",
      {domainCode: "event_chat_metadata_invalid", reason: "event_state_invalid"},
  );
}

function assertReportableMessage({messageExists, messageData, reporterId}) {
  if (!messageExists) {
    throwReportChatMessageError(
        "not-found",
        "Event chat message not found",
        {domainCode: "event_chat_message_not_found"},
    );
  }
  const keys = messageData && typeof messageData === "object" ?
    Object.keys(messageData) :
    [];
  const hasExactKeys = keys.length === EVENT_CHAT_MESSAGE_KEYS.length &&
    EVENT_CHAT_MESSAGE_KEYS.every((key) =>
      Object.prototype.hasOwnProperty.call(messageData, key),
    ) &&
    keys.every((key) => EVENT_CHAT_MESSAGE_KEY_SET.has(key));
  if (
    !hasExactKeys ||
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
    throwReportChatMessageError(
        "failed-precondition",
        "Event chat message is invalid",
        {domainCode: "event_chat_message_invalid", reason: "invalid_shape"},
    );
  }
  if (messageData.deletedAt !== null) {
    throwReportChatMessageError(
        "failed-precondition",
        "Event chat message is not reportable",
        {
          domainCode: "event_chat_message_not_reportable",
          reason: "message_deleted",
        },
    );
  }
  if (messageData.senderId === reporterId) {
    throwReportChatMessageError(
        "failed-precondition",
        "User cannot report their own event chat message",
        {domainCode: "event_chat_message_report_self"},
    );
  }
}

function chatMessageReportDocument({
  db,
  eventRef,
  chatRef,
  messageRef,
  eventData,
  messageData,
  eventId,
  messageId,
  reporterId,
  reportTimestamp,
  reasonCode,
  details,
}) {
  const senderId = normalizeSnapshotString(messageData.senderId);
  return {
    eventId,
    eventRef,
    eventPath: eventRef.path,
    chatId: eventId,
    chatRef,
    chatPath: chatRef.path,
    messageId,
    messageRef,
    messagePath: messageRef.path,
    reporterId,
    reporterRef: db.collection("users").doc(reporterId),
    senderId,
    senderRef: isValidPathSegment(senderId) ?
      db.collection("users").doc(senderId) :
      null,
    reasonCode,
    details,
    status: "open",
    eventSnapshot: eventSnapshot(eventData),
    messageSnapshot: messageSnapshot(messageData),
    createdAt: reportTimestamp,
    updatedAt: reportTimestamp,
  };
}

async function executeReportEventChatMessageTransaction({
  db,
  eventId,
  messageId,
  reporterId,
  reasonCode,
  details = null,
  reportDate = new Date(),
  reportTimestamp = admin.firestore.FieldValue.serverTimestamp(),
}) {
  const normalizedReporterId = normalizeUserId(reporterId);
  if (!isValidPathSegment(normalizedReporterId)) {
    throwReportChatMessageError(
        "unauthenticated",
        "User must be authenticated.",
        {domainCode: "auth_required"},
    );
  }

  const eventRef = db.collection("events").doc(eventId);
  const chatRef = db.collection(EVENT_CHAT_COLLECTION).doc(eventId);
  const messageRef = chatRef.collection("messages").doc(messageId);
  const participantRef =
    eventRef.collection("participants").doc(normalizedReporterId);
  const reportId = buildChatMessageReportId({
    eventId,
    messageId,
    reporterId: normalizedReporterId,
  });
  const reportRef =
    db.collection(CHAT_MESSAGE_REPORTS_COLLECTION).doc(reportId);

  return db.runTransaction(async (transaction) => {
    const [
      eventSnap,
      chatSnap,
      participantSnap,
      messageSnap,
      reportSnap,
    ] = await Promise.all([
      transaction.get(eventRef),
      transaction.get(chatRef),
      transaction.get(participantRef),
      transaction.get(messageRef),
      transaction.get(reportRef),
    ]);
    const eventData = eventSnap.exists ? eventSnap.data() || {} : {};
    const chatData = chatSnap.exists ? chatSnap.data() || {} : {};
    const participantData = participantSnap.exists ?
      participantSnap.data() || {} :
      {};
    const messageData = messageSnap.exists ? messageSnap.data() || {} : {};

    if (reportSnap.exists) {
      const existingReport = reportSnap.data() || {};
      return {
        eventId,
        messageId,
        reportId,
        status: "already_submitted",
        reportedAt: timestampToIso(existingReport.createdAt) ||
          reportDate.toISOString(),
      };
    }

    assertEventAndChatMetadata({
      eventExists: eventSnap.exists,
      eventData,
      chatExists: chatSnap.exists,
      chatData,
      eventId,
    });
    assertReporterCanReadChat({
      eventData,
      chatData,
      participantExists: participantSnap.exists,
      participantData,
      reporterId: normalizedReporterId,
    });
    assertReportableMessage({
      messageExists: messageSnap.exists,
      messageData,
      reporterId: normalizedReporterId,
    });

    transaction.create(
        reportRef,
        chatMessageReportDocument({
          db,
          eventRef,
          chatRef,
          messageRef,
          eventData,
          messageData,
          eventId,
          messageId,
          reporterId: normalizedReporterId,
          reportTimestamp,
          reasonCode,
          details,
        }),
    );

    return {
      eventId,
      messageId,
      reportId,
      status: "submitted",
      reportedAt: reportDate.toISOString(),
    };
  });
}

async function reportEventChatMessageHandler(data, context, options = {}) {
  if (!context.auth) {
    throwReportChatMessageError(
        "unauthenticated",
        "User must be authenticated.",
        {domainCode: "auth_required"},
    );
  }

  const payload = normalizeReportEventChatMessagePayload(data);
  const db = options.db || admin.firestore();
  return executeReportEventChatMessageTransaction({
    db,
    eventId: payload.eventId,
    messageId: payload.messageId,
    reporterId: context.auth.uid,
    reasonCode: payload.reasonCode,
    details: payload.details,
    reportDate: options.reportDate || new Date(),
    reportTimestamp: options.reportTimestamp ||
      admin.firestore.FieldValue.serverTimestamp(),
  });
}

exports.reportEventChatMessage = functions
    .runWith({timeoutSeconds: REQUEST_TIMEOUT_SECONDS})
    .https.onCall((data, context) =>
      reportEventChatMessageHandler(data, context),
    );

exports.__private__ = {
  CHAT_MESSAGE_REPORTS_COLLECTION,
  CHAT_MESSAGE_REPORT_DETAILS_MAX_LENGTH,
  CHAT_MESSAGE_REPORT_REASON_CODES,
  buildChatMessageReportId,
  executeReportEventChatMessageTransaction,
  normalizeReportEventChatMessagePayload,
  reportEventChatMessageHandler,
};
