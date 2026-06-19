const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

const REQUEST_TIMEOUT_SECONDS = 30;
const EVENT_STATUS_ACTIVE = "active";
const EVENT_STATUS_CANCELED = "canceled";
const EVENT_CHAT_COLLECTION = "eventChats";
const CANCEL_EVENT_KEYS = Object.freeze(["eventId"]);
const CANCEL_EVENT_KEY_SET = new Set(CANCEL_EVENT_KEYS);
const EVENT_CHAT_METADATA_KEYS = Object.freeze([
  "eventId",
  "readAccessUserIds",
  "createdAt",
  "updatedAt",
]);
const EVENT_CHAT_METADATA_KEY_SET = new Set(EVENT_CHAT_METADATA_KEYS);

function throwCancelError(code, message, details) {
  throw new functions.https.HttpsError(code, message, details);
}

function throwInvalidCancelRequest(field, reason, message) {
  throwCancelError(
      "invalid-argument",
      message || "Invalid cancel event request",
      {domainCode: "invalid_cancel_request", field, reason},
  );
}

function validateExactCancelEventKeys(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throwInvalidCancelRequest("payload", "invalid_type");
  }
  for (const key of Object.keys(data)) {
    if (!CANCEL_EVENT_KEY_SET.has(key)) {
      throwInvalidCancelRequest(key, "unknown_key");
    }
  }
  for (const key of CANCEL_EVENT_KEYS) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) {
      throwInvalidCancelRequest(key, "missing");
    }
  }
}

function normalizeEventId(value) {
  if (typeof value !== "string") {
    throwInvalidCancelRequest("eventId", "invalid_type");
  }
  const eventId = value.trim();
  if (!eventId || eventId.includes("/")) {
    throwInvalidCancelRequest("eventId", "invalid_format");
  }
  return eventId;
}

function normalizeCancelEventPayload(data) {
  validateExactCancelEventKeys(data);
  return {eventId: normalizeEventId(data.eventId)};
}

function timestampToIso(value) {
  if (value instanceof Date) {
    return Number.isFinite(value.getTime()) ? value.toISOString() : "";
  }
  if (value && typeof value.toDate === "function") {
    const date = value.toDate();
    return date instanceof Date && Number.isFinite(date.getTime()) ?
      date.toISOString() :
      "";
  }
  if (value && typeof value.toMillis === "function") {
    const millis = value.toMillis();
    return Number.isFinite(millis) ? new Date(millis).toISOString() : "";
  }
  return "";
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

function isValidPathSegment(value) {
  return typeof value === "string" && value.length > 0 && !value.includes("/");
}

function failParticipantStateInconsistent() {
  throwCancelError(
      "failed-precondition",
      "Event participant state is inconsistent",
      {domainCode: "event_participant_state_inconsistent"},
  );
}

function assertEventOrganizer({eventExists, eventData, uid}) {
  if (!eventExists) {
    throwCancelError(
        "not-found",
        "Event not found",
        {domainCode: "event_not_found"},
    );
  }
  if (eventData.organizerId !== uid) {
    throwCancelError(
        "permission-denied",
        "Only the organizer can cancel this event",
        {domainCode: "not_event_organizer"},
    );
  }
}

function assertChatMetadata({chatExists, chatData, eventData, eventId}) {
  if (!chatExists) {
    throwCancelError(
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
    throwCancelError(
        "failed-precondition",
        "Event chat metadata is invalid",
        {domainCode: "event_chat_metadata_invalid", reason: "invalid_shape"},
    );
  }
  if (eventData.chatId !== eventId) {
    throwCancelError(
        "failed-precondition",
        "Event chat id does not match event id",
        {
          domainCode: "event_chat_metadata_invalid",
          reason: "event_chat_id_mismatch",
        },
    );
  }
  if (chatData.eventId !== eventId) {
    throwCancelError(
        "failed-precondition",
        "Event chat metadata does not match event id",
        {
          domainCode: "event_chat_metadata_invalid",
          reason: "chat_event_id_mismatch",
        },
    );
  }
}

function buildCanceledResponse({eventId, canceledAt}) {
  const canceledAtIso = timestampToIso(canceledAt);
  if (!canceledAtIso) {
    throwCancelError(
        "failed-precondition",
        "Event cancellation timestamp is invalid",
        {domainCode: "event_cancellation_inconsistent"},
    );
  }
  return {
    eventId,
    status: EVENT_STATUS_CANCELED,
    canceledAt: canceledAtIso,
  };
}

function assertEventCancelable(eventData) {
  if (eventData.status !== EVENT_STATUS_ACTIVE || eventData.canceledAt !== null) {
    throwCancelError(
        "failed-precondition",
        "Only active events can be canceled",
        {domainCode: "event_not_cancelable", reason: "not_active"},
    );
  }
}

function buildActiveParticipantIds(activeParticipantDocs) {
  const ids = [];
  for (const doc of activeParticipantDocs) {
    if (!isValidPathSegment(doc.id)) {
      failParticipantStateInconsistent();
    }
    ids.push(doc.id);
  }
  ids.sort();
  const uniqueIds = [...new Set(ids)];
  if (uniqueIds.length !== ids.length) {
    failParticipantStateInconsistent();
  }
  return uniqueIds;
}

function assertParticipantCountInvariant({
  activeParticipantDocs,
  eventData,
}) {
  const activeParticipantIds = buildActiveParticipantIds(activeParticipantDocs);
  const participantsCount = eventData.participantsCount;
  if (
    !Number.isInteger(participantsCount) ||
    participantsCount < 1 ||
    activeParticipantIds.length !== participantsCount ||
    !activeParticipantIds.includes(eventData.organizerId)
  ) {
    failParticipantStateInconsistent();
  }
}

function buildReadAccessSnapshot({organizerId, activeParticipantDocs}) {
  const participantIds = activeParticipantDocs
      .map((doc) => doc.id)
      .filter((id) => id && id !== organizerId)
      .sort();
  return [organizerId, ...new Set(participantIds)];
}

async function executeCancelEventTransaction({
  db,
  uid,
  cancelDate,
  cancelTimestamp,
  payload,
}) {
  const eventRef = db.collection("events").doc(payload.eventId);
  const chatRef = db.collection(EVENT_CHAT_COLLECTION).doc(payload.eventId);
  const activeParticipantsQuery = eventRef
      .collection("participants")
      .where("status", "==", "active");

  return await db.runTransaction(async (tx) => {
    const [eventDoc, chatDoc] = await Promise.all([
      tx.get(eventRef),
      tx.get(chatRef),
    ]);
    const eventData = eventDoc.exists ? eventDoc.data() || {} : {};
    const chatData = chatDoc.exists ? chatDoc.data() || {} : {};

    assertEventOrganizer({
      eventExists: eventDoc.exists,
      eventData,
      uid,
    });
    assertChatMetadata({
      chatExists: chatDoc.exists,
      chatData,
      eventData,
      eventId: payload.eventId,
    });

    if (eventData.status === EVENT_STATUS_CANCELED) {
      return buildCanceledResponse({
        eventId: payload.eventId,
        canceledAt: eventData.canceledAt,
      });
    }

    assertEventCancelable(eventData);

    const activeParticipantsSnapshot = await tx.get(activeParticipantsQuery);
    assertParticipantCountInvariant({
      activeParticipantDocs: activeParticipantsSnapshot.docs || [],
      eventData,
    });
    const readAccessUserIds = buildReadAccessSnapshot({
      organizerId: eventData.organizerId,
      activeParticipantDocs: activeParticipantsSnapshot.docs || [],
    });

    tx.update(eventRef, {
      status: EVENT_STATUS_CANCELED,
      canceledAt: cancelTimestamp,
      updatedAt: cancelTimestamp,
    });
    tx.update(chatRef, {
      readAccessUserIds,
      updatedAt: cancelTimestamp,
    });

    return buildCanceledResponse({
      eventId: payload.eventId,
      canceledAt: cancelDate,
    });
  });
}

exports.__private__ = {
  CANCEL_EVENT_KEYS,
  buildReadAccessSnapshot,
  executeCancelEventTransaction,
  normalizeCancelEventPayload,
};

exports.cancelEvent = functions
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
      const cancelDate = new Date();
      const cancelTimestamp = admin.firestore.Timestamp.fromDate(cancelDate);
      const payload = normalizeCancelEventPayload(data);
      const db = admin.firestore();

      try {
        return await executeCancelEventTransaction({
          db,
          uid,
          cancelDate,
          cancelTimestamp,
          payload,
        });
      } catch (err) {
        if (err instanceof functions.https.HttpsError) {
          throw err;
        }
        console.error("cancelEvent failed", {uid, err});
        throw new functions.https.HttpsError(
            "internal",
            "Unable to cancel event",
        );
      }
    });
