const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

const {
  __private__: {
    buildEventEditableUpdate,
    normalizeCreateEventPayload,
  },
} = require("./create_event");

const REQUEST_TIMEOUT_SECONDS = 30;
const EDIT_EVENT_KEYS = Object.freeze([
  "eventId",
  "title",
  "description",
  "languageCode",
  "levelMin",
  "levelMax",
  "countryCode",
  "cityKey",
  "locationName",
  "locationGeoPoint",
  "startsAt",
  "capacity",
]);
const EDIT_EVENT_KEY_SET = new Set(EDIT_EVENT_KEYS);
const SYNTHETIC_CREATE_REQUEST_ID =
  "00000000-0000-4000-8000-000000000000";

function throwEditError(code, message, details) {
  throw new functions.https.HttpsError(code, message, details);
}

function throwInvalidEditRequest(field, reason, message) {
  throwEditError(
      "invalid-argument",
      message || "Invalid edit event request",
      {domainCode: "invalid_edit_request", field, reason},
  );
}

function remapCreateValidationError(err) {
  if (
    err instanceof functions.https.HttpsError &&
    err.code === "invalid-argument" &&
    err.details?.domainCode === "invalid_create_request"
  ) {
    throwInvalidEditRequest(
        err.details.field || "payload",
        err.details.reason || "invalid_format",
    );
  }
  throw err;
}

function validateExactEditEventKeys(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throwInvalidEditRequest("payload", "invalid_type");
  }
  for (const key of Object.keys(data)) {
    if (!EDIT_EVENT_KEY_SET.has(key)) {
      throwInvalidEditRequest(key, "unknown_key");
    }
  }
  for (const key of EDIT_EVENT_KEYS) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) {
      throwInvalidEditRequest(key, "missing");
    }
  }
}

function normalizeEventId(value) {
  if (typeof value !== "string") {
    throwInvalidEditRequest("eventId", "invalid_type");
  }
  const eventId = value.trim();
  if (!eventId || eventId.includes("/")) {
    throwInvalidEditRequest("eventId", "invalid_format");
  }
  return eventId;
}

function normalizeEditEventPayload(data, {now = new Date()} = {}) {
  validateExactEditEventKeys(data);
  const eventId = normalizeEventId(data.eventId);
  try {
    const normalized = normalizeCreateEventPayload({
      createRequestId: SYNTHETIC_CREATE_REQUEST_ID,
      title: data.title,
      description: data.description,
      languageCode: data.languageCode,
      levelMin: data.levelMin,
      levelMax: data.levelMax,
      countryCode: data.countryCode,
      cityKey: data.cityKey,
      locationName: data.locationName,
      locationGeoPoint: data.locationGeoPoint,
      startsAt: data.startsAt,
      capacity: data.capacity,
    }, {now, requireFutureStartsAt: true, requireKnownCity: true});
    return {eventId, normalized};
  } catch (err) {
    remapCreateValidationError(err);
  }
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (value && typeof value.toDate === "function") {
    return value.toDate().getTime();
  }
  return NaN;
}

function assertEventEditable({
  eventExists,
  eventData,
  uid,
  now,
  requestedCapacity,
}) {
  if (!eventExists) {
    throwEditError(
        "not-found",
        "Event not found",
        {domainCode: "event_not_found"},
    );
  }
  if (eventData.organizerId !== uid) {
    throwEditError(
        "permission-denied",
        "Only the organizer can edit this event",
        {domainCode: "not_event_organizer"},
    );
  }
  if (eventData.status !== "active" || eventData.canceledAt !== null) {
    throwEditError(
        "failed-precondition",
        "Only active events can be edited",
        {domainCode: "event_not_editable", reason: "not_active"},
    );
  }
  const existingStartsAtMillis = timestampMillis(eventData.startsAt);
  if (
    !Number.isFinite(existingStartsAtMillis) ||
    existingStartsAtMillis <= now.getTime()
  ) {
    throwEditError(
        "failed-precondition",
        "Past events cannot be edited",
        {domainCode: "event_not_editable", reason: "past_event"},
    );
  }
  const participantsCount = eventData.participantsCount;
  if (
    !Number.isInteger(participantsCount) ||
    participantsCount < 1 ||
    requestedCapacity < participantsCount
  ) {
    throwEditError(
        "failed-precondition",
        "Capacity cannot be lower than active participant count",
        {
          domainCode: "capacity_below_participants_count",
          participantsCount: Number.isInteger(participantsCount) ?
            participantsCount :
            null,
          capacity: requestedCapacity,
        },
    );
  }
}

async function executeEditEventTransaction({
  db,
  uid,
  editDate,
  editTimestamp,
  payload,
}) {
  const eventRef = db.collection("events").doc(payload.eventId);
  return await db.runTransaction(async (tx) => {
    const eventDoc = await tx.get(eventRef);
    const eventData = eventDoc.exists ? eventDoc.data() || {} : {};
    assertEventEditable({
      eventExists: eventDoc.exists,
      eventData,
      uid,
      now: editDate,
      requestedCapacity: payload.normalized.capacity,
    });

    const update = buildEventEditableUpdate({
      normalized: payload.normalized,
      editTimestamp,
    });
    tx.update(eventRef, update);

    return {
      eventId: payload.eventId,
      updatedAt: editDate.toISOString(),
    };
  });
}

exports.__private__ = {
  EDIT_EVENT_KEYS,
  SYNTHETIC_CREATE_REQUEST_ID,
  assertEventEditable,
  executeEditEventTransaction,
  normalizeEditEventPayload,
  normalizeEventId,
};

exports.editEvent = functions
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
      const editDate = new Date();
      const editTimestamp = admin.firestore.Timestamp.fromDate(editDate);
      const payload = normalizeEditEventPayload(data, {now: editDate});
      const db = admin.firestore();

      try {
        return await executeEditEventTransaction({
          db,
          uid,
          editDate,
          editTimestamp,
          payload,
        });
      } catch (err) {
        if (err instanceof functions.https.HttpsError) {
          throw err;
        }
        console.error("editEvent failed", {uid, eventId: payload.eventId, err});
        throw new functions.https.HttpsError(
            "internal",
            "Unable to edit event",
        );
      }
    });
