const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

const REQUEST_TIMEOUT_SECONDS = 30;
const EVENT_STATUS_ACTIVE = "active";
const EVENT_STATUS_CANCELED = "canceled";
const PARTICIPANT_STATUS_ACTIVE = "active";
const EVENT_CHAT_COLLECTION = "eventChats";
const GET_EVENT_CHAT_ACCESS_STATE_KEYS = Object.freeze(["eventId"]);
const GET_EVENT_CHAT_ACCESS_STATE_KEY_SET =
  new Set(GET_EVENT_CHAT_ACCESS_STATE_KEYS);
const EVENT_CHAT_METADATA_KEYS = Object.freeze([
  "eventId",
  "readAccessUserIds",
  "createdAt",
  "updatedAt",
]);
const EVENT_CHAT_METADATA_KEY_SET = new Set(EVENT_CHAT_METADATA_KEYS);

function throwAccessError(code, message, details) {
  throw new functions.https.HttpsError(code, message, details);
}

function throwInvalidAccessRequest(field, reason, message) {
  throwAccessError(
      "invalid-argument",
      message || "Invalid event chat access request",
      {domainCode: "invalid_event_chat_access_request", field, reason},
  );
}

function validateExactGetEventChatAccessStateKeys(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throwInvalidAccessRequest("payload", "invalid_type");
  }
  for (const key of Object.keys(data)) {
    if (!GET_EVENT_CHAT_ACCESS_STATE_KEY_SET.has(key)) {
      throwInvalidAccessRequest(key, "unknown_key");
    }
  }
  for (const key of GET_EVENT_CHAT_ACCESS_STATE_KEYS) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) {
      throwInvalidAccessRequest(key, "missing");
    }
  }
}

function normalizeEventId(value) {
  if (typeof value !== "string") {
    throwInvalidAccessRequest("eventId", "invalid_type");
  }
  const eventId = value.trim();
  if (
    !eventId ||
    eventId === "." ||
    eventId === ".." ||
    eventId.includes("/") ||
    Buffer.byteLength(eventId, "utf8") > 1500
  ) {
    throwInvalidAccessRequest("eventId", "invalid_format");
  }
  return eventId;
}

function normalizeGetEventChatAccessStatePayload(data) {
  validateExactGetEventChatAccessStateKeys(data);
  return {eventId: normalizeEventId(data.eventId)};
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

function assertEventAndChatMetadata({
  eventExists,
  eventData,
  chatExists,
  chatData,
  eventId,
}) {
  if (!eventExists) {
    throwAccessError(
        "not-found",
        "Event not found",
        {domainCode: "event_not_found"},
    );
  }
  if (eventData.chatId !== eventId) {
    throwAccessError(
        "failed-precondition",
        "Event chat id does not match event id",
        {
          domainCode: "event_chat_metadata_invalid",
          reason: "event_chat_id_mismatch",
        },
    );
  }
  if (!chatExists) {
    throwAccessError(
        "failed-precondition",
        "Event chat metadata is missing",
        {domainCode: "event_chat_metadata_invalid", reason: "missing"},
    );
  }
  if (chatData.eventId !== eventId) {
    throwAccessError(
        "failed-precondition",
        "Event chat metadata does not match event id",
        {
          domainCode: "event_chat_metadata_invalid",
          reason: "chat_event_id_mismatch",
        },
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
    throwAccessError(
        "failed-precondition",
        "Event chat metadata is invalid",
        {
          domainCode: "event_chat_metadata_invalid",
          reason: "invalid_shape",
        },
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

async function getEventChatAccessState({
  db,
  uid,
  payload,
}) {
  const eventRef = db.collection("events").doc(payload.eventId);
  const chatRef = db.collection(EVENT_CHAT_COLLECTION).doc(payload.eventId);
  const participantRef = eventRef.collection("participants").doc(uid);
  const [eventDoc, chatDoc, participantDoc] = await Promise.all([
    eventRef.get(),
    chatRef.get(),
    participantRef.get(),
  ]);
  const eventData = eventDoc.exists ? eventDoc.data() || {} : {};
  const chatData = chatDoc.exists ? chatDoc.data() || {} : {};
  const participantData = participantDoc.exists ?
    participantDoc.data() || {} :
    {};

  assertEventAndChatMetadata({
    eventExists: eventDoc.exists,
    eventData,
    chatExists: chatDoc.exists,
    chatData,
    eventId: payload.eventId,
  });

  if (
    eventData.status === EVENT_STATUS_ACTIVE &&
    eventData.canceledAt === null
  ) {
    if (!isActiveParticipant({
      participantExists: participantDoc.exists,
      participantData,
      uid,
    })) {
      throwAccessError(
          "failed-precondition",
          "User is not an active event participant",
          {domainCode: "not_active_participant"},
      );
    }
    return {
      eventId: payload.eventId,
      status: EVENT_STATUS_ACTIVE,
      readOnly: false,
    };
  }

  if (
    eventData.status === EVENT_STATUS_CANCELED &&
    hasTimestampValue(eventData.canceledAt)
  ) {
    if (!chatData.readAccessUserIds.includes(uid)) {
      throwAccessError(
          "permission-denied",
          "User cannot read this canceled event chat",
          {domainCode: "event_chat_access_denied"},
      );
    }
    return {
      eventId: payload.eventId,
      status: EVENT_STATUS_CANCELED,
      readOnly: true,
    };
  }

  throwAccessError(
      "failed-precondition",
      "Event chat state is invalid",
      {domainCode: "event_chat_metadata_invalid", reason: "event_state_invalid"},
  );
}

exports.__private__ = {
  GET_EVENT_CHAT_ACCESS_STATE_KEYS,
  getEventChatAccessState,
  normalizeGetEventChatAccessStatePayload,
};

exports.getEventChatAccessState = functions
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
      const payload = normalizeGetEventChatAccessStatePayload(data);
      const db = admin.firestore();

      try {
        return await getEventChatAccessState({db, uid, payload});
      } catch (err) {
        if (err instanceof functions.https.HttpsError) {
          throw err;
        }
        console.error("getEventChatAccessState failed", {uid, err});
        throw new functions.https.HttpsError(
            "internal",
            "Could not load event chat access state",
            {domainCode: "event_chat_access_state_failed"},
        );
      }
    });
