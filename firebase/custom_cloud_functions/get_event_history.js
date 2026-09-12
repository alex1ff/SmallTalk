const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "get_event_history"});

const REQUEST_TIMEOUT_SECONDS = 30;
const DEFAULT_HISTORY_LIMIT = 20;
const MAX_HISTORY_LIMIT = 50;
const PARTICIPANT_QUERY_MULTIPLIER = 3;
const MAX_PARTICIPANT_QUERY_LIMIT = 150;
const EVENT_STATUS_ACTIVE = "active";
const EVENT_STATUS_CANCELED = "canceled";
const PARTICIPANT_STATUS_ACTIVE = "active";
const PARTICIPANT_STATUS_LEFT = "left";
const PARTICIPANT_ROLE_ORGANIZER = "organizer";
const PARTICIPANT_ROLE_PARTICIPANT = "participant";
const TIMELINE_STATUS_UPCOMING = "upcoming";
const TIMELINE_STATUS_PAST = "past";
const TIMELINE_STATUS_CANCELED = "canceled";
const TIMELINE_STATUS_LEFT = "left";
const GET_EVENT_HISTORY_KEYS = Object.freeze(["limit"]);
const GET_EVENT_HISTORY_KEY_SET = new Set(GET_EVENT_HISTORY_KEYS);

function throwHistoryError(code, message, details) {
  throw new functions.https.HttpsError(code, message, details);
}

function throwInvalidHistoryRequest(field, reason, message) {
  throwHistoryError(
      "invalid-argument",
      message || "Invalid event history request",
      {
        domainCode: "invalid_event_history_request",
        field,
        reason,
      },
  );
}

function validateExactGetEventHistoryKeys(data) {
  if (data === undefined || data === null) {
    return;
  }
  if (typeof data !== "object" || Array.isArray(data)) {
    throwInvalidHistoryRequest("payload", "invalid_type");
  }
  for (const key of Object.keys(data)) {
    if (!GET_EVENT_HISTORY_KEY_SET.has(key)) {
      throwInvalidHistoryRequest(key, "unknown_key");
    }
  }
}

function normalizeHistoryLimit(value) {
  if (value === undefined || value === null) {
    return DEFAULT_HISTORY_LIMIT;
  }
  if (!Number.isInteger(value)) {
    throwInvalidHistoryRequest("limit", "invalid_type");
  }
  if (value < 1 || value > MAX_HISTORY_LIMIT) {
    throwInvalidHistoryRequest("limit", "out_of_range");
  }
  return value;
}

function normalizeGetEventHistoryPayload(data) {
  validateExactGetEventHistoryKeys(data);
  return {
    limit: normalizeHistoryLimit(data && data.limit),
  };
}

function normalizeString(value) {
  if (typeof value !== "string") {
    return "";
  }
  return value.normalize("NFC").trim();
}

function optionalString(value) {
  const normalized = normalizeString(value);
  return normalized || null;
}

function timestampToMillis(value) {
  if (!value) {
    return null;
  }
  if (value instanceof Date && Number.isFinite(value.getTime())) {
    return value.getTime();
  }
  if (typeof value.toMillis === "function") {
    try {
      const millis = Number(value.toMillis());
      return Number.isFinite(millis) ? millis : null;
    } catch (_) {
      return null;
    }
  }
  if (typeof value.toDate === "function") {
    try {
      const date = value.toDate();
      return date instanceof Date && Number.isFinite(date.getTime()) ?
        date.getTime() :
        null;
    } catch (_) {
      return null;
    }
  }
  return null;
}

function timestampToIso(value) {
  const millis = timestampToMillis(value);
  return millis === null ? null : new Date(millis).toISOString();
}

function compareParticipantDocsByJoinedAtDesc(left, right) {
  const leftMillis = timestampToMillis((left.data() || {}).joinedAt) || 0;
  const rightMillis = timestampToMillis((right.data() || {}).joinedAt) || 0;
  const joinedAtComparison = rightMillis - leftMillis;
  if (joinedAtComparison !== 0) {
    return joinedAtComparison;
  }
  return String(right.ref && right.ref.path || "")
      .localeCompare(String(left.ref && left.ref.path || ""));
}

function isMissingFirestoreIndexError(err) {
  const details = String(err && (err.details || err.message) || "");
  return err && err.code === 9 && /requires an index/i.test(details);
}

async function loadParticipantHistoryDocs({db, uid, participantQueryLimit}) {
  const baseQuery = db
      .collectionGroup("participants")
      .where("userId", "==", uid);

  try {
    const participantSnapshot = await baseQuery
        .orderBy("joinedAt", "desc")
        .limit(participantQueryLimit)
        .get();
    return Array.isArray(participantSnapshot.docs) ?
      participantSnapshot.docs :
      [];
  } catch (err) {
    if (!isMissingFirestoreIndexError(err)) {
      throw err;
    }
    safeLog.warn("event_history_index_missing", {uid});
  }

  const fallbackSnapshot = await baseQuery.get();
  const fallbackDocs = Array.isArray(fallbackSnapshot.docs) ?
    fallbackSnapshot.docs :
    [];
  return fallbackDocs
      .sort(compareParticipantDocsByJoinedAtDesc)
      .slice(0, participantQueryLimit);
}

function eventReferenceForParticipantSnapshot(db, participantDoc) {
  const parentEventRef = participantDoc.ref &&
    participantDoc.ref.parent &&
    participantDoc.ref.parent.parent;
  if (parentEventRef) {
    return parentEventRef;
  }

  const match = String(participantDoc.ref && participantDoc.ref.path || "")
      .match(/^events\/([^/]+)\/participants\/[^/]+$/);
  if (!match) {
    return null;
  }
  return db.collection("events").doc(match[1]);
}

function normalizeParticipantRole(participantRole, eventData, uid) {
  const role = normalizeString(participantRole);
  if (
    role === PARTICIPANT_ROLE_ORGANIZER ||
    role === PARTICIPANT_ROLE_PARTICIPANT
  ) {
    return role;
  }
  return eventData.organizerId === uid ? PARTICIPANT_ROLE_ORGANIZER : null;
}

function canIncludeEventHistoryItem({
  eventData,
  participantData,
  participantRole,
  uid,
}) {
  const eventStatus = normalizeString(eventData.status);
  const participantStatus = normalizeString(participantData.status);
  const isOrganizer =
    participantRole === PARTICIPANT_ROLE_ORGANIZER ||
    eventData.organizerId === uid;

  if (participantData.userId !== uid) {
    return false;
  }
  if (
    participantStatus !== PARTICIPANT_STATUS_ACTIVE &&
    participantStatus !== PARTICIPANT_STATUS_LEFT
  ) {
    return false;
  }
  if (eventStatus === EVENT_STATUS_ACTIVE) {
    return true;
  }
  if (eventStatus === EVENT_STATUS_CANCELED) {
    return isOrganizer ||
      (participantStatus === PARTICIPANT_STATUS_ACTIVE &&
        participantData.leftAt === null);
  }
  return false;
}

function timelineStatusForItem({eventData, participantData, startsAtMillis, now}) {
  if (normalizeString(eventData.status) === EVENT_STATUS_CANCELED) {
    return TIMELINE_STATUS_CANCELED;
  }
  if (normalizeString(participantData.status) === PARTICIPANT_STATUS_LEFT) {
    return TIMELINE_STATUS_LEFT;
  }
  return startsAtMillis >= now.getTime() ?
    TIMELINE_STATUS_UPCOMING :
    TIMELINE_STATUS_PAST;
}

function buildEventHistoryItem({
  eventDoc,
  eventRef,
  participantData,
  uid,
  now,
}) {
  if (!eventDoc.exists) {
    return null;
  }

  const eventData = eventDoc.data() || {};
  const eventId = normalizeString(eventRef.id || (eventDoc.ref && eventDoc.ref.id));
  const title = normalizeString(eventData.title);
  const eventStatus = normalizeString(eventData.status);
  const startsAtIso = timestampToIso(eventData.startsAt);
  const startsAtMillis = timestampToMillis(eventData.startsAt);
  const joinedAtIso = timestampToIso(participantData.joinedAt);
  const participantRole = normalizeParticipantRole(
      participantData.role,
      eventData,
      uid,
  );

  if (
    !eventId ||
    !title ||
    !startsAtIso ||
    startsAtMillis === null ||
    !joinedAtIso ||
    !participantRole ||
    !canIncludeEventHistoryItem({
      eventData,
      participantData,
      participantRole,
      uid,
    })
  ) {
    return null;
  }

  const timeZoneId = normalizeString(eventData.timeZoneId) || "UTC";
  const participantStatus = normalizeString(participantData.status);

  return {
    eventId,
    title,
    startsAt: startsAtIso,
    timeZoneId,
    status: eventStatus,
    canceledAt: timestampToIso(eventData.canceledAt),
    participantRole,
    participantStatus,
    joinedAt: joinedAtIso,
    leftAt: timestampToIso(participantData.leftAt),
    timelineStatus: timelineStatusForItem({
      eventData,
      participantData,
      startsAtMillis,
      now,
    }),
    locationName: optionalString(eventData.locationName),
    countryCode: optionalString(eventData.countryCode),
    cityKey: optionalString(eventData.cityKey),
    cityNameEn: optionalString(eventData.cityNameEn),
    cityNameRu: optionalString(eventData.cityNameRu),
    languageCode: optionalString(eventData.languageCode),
    languageNameEn: optionalString(eventData.languageNameEn),
    languageNameRu: optionalString(eventData.languageNameRu),
    levelMin: optionalString(eventData.levelMin),
    levelMax: optionalString(eventData.levelMax),
    description: optionalString(eventData.description),
    organizerDisplayName: optionalString(eventData.organizerDisplayName),
    organizerPhotoUrl: optionalString(eventData.organizerPhotoUrl),
    participantsCount: Number.isInteger(eventData.participantsCount) ?
      eventData.participantsCount : null,
    capacity: Number.isInteger(eventData.capacity) ? eventData.capacity : null,
  };
}

function compareEventHistoryItems(left, right) {
  const leftUpcoming = left.timelineStatus === TIMELINE_STATUS_UPCOMING;
  const rightUpcoming = right.timelineStatus === TIMELINE_STATUS_UPCOMING;
  if (leftUpcoming !== rightUpcoming) {
    return leftUpcoming ? -1 : 1;
  }

  const leftStartsAt = Date.parse(left.startsAt);
  const rightStartsAt = Date.parse(right.startsAt);
  const startsAtComparison = leftUpcoming ?
    leftStartsAt - rightStartsAt :
    rightStartsAt - leftStartsAt;
  if (startsAtComparison !== 0) {
    return startsAtComparison;
  }

  return left.eventId.localeCompare(right.eventId);
}

async function getEventHistory({
  db,
  uid,
  payload,
  now = new Date(),
}) {
  const limit = payload.limit;
  const participantQueryLimit = Math.min(
      Math.max(limit * PARTICIPANT_QUERY_MULTIPLIER, limit),
      MAX_PARTICIPANT_QUERY_LIMIT,
  );
  const participantDocs = await loadParticipantHistoryDocs({
    db,
    uid,
    participantQueryLimit,
  });
  const entries = [];
  const eventRefs = [];
  const seenEventPaths = new Set();

  for (const participantDoc of participantDocs) {
    const eventRef = eventReferenceForParticipantSnapshot(db, participantDoc);
    if (!eventRef || seenEventPaths.has(eventRef.path)) {
      continue;
    }
    seenEventPaths.add(eventRef.path);
    eventRefs.push(eventRef);
    entries.push({
      eventRef,
      participantData: participantDoc.data() || {},
    });
  }

  const eventDocs = eventRefs.length === 0 ?
    [] :
    typeof db.getAll === "function" ?
      await db.getAll(...eventRefs) :
      await Promise.all(eventRefs.map((eventRef) => eventRef.get()));
  const items = [];

  for (let index = 0; index < entries.length; index += 1) {
    const item = buildEventHistoryItem({
      eventDoc: eventDocs[index],
      eventRef: entries[index].eventRef,
      participantData: entries[index].participantData,
      uid,
      now,
    });
    if (item) {
      items.push(item);
    }
  }

  items.sort(compareEventHistoryItems);

  return {
    items: items.slice(0, limit),
    limit,
    generatedAt: now.toISOString(),
  };
}

async function getEventHistoryHandler(data, context, options = {}) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
        {domainCode: "auth_required"},
    );
  }

  const uid = context.auth.uid;
  const payload = normalizeGetEventHistoryPayload(data);
  const db = options.db || admin.firestore();
  const now = options.now || new Date();

  try {
    return await getEventHistory({db, uid, payload, now});
  } catch (err) {
    if (err instanceof functions.https.HttpsError) {
      throw err;
    }
    safeLog.error("event_history_failed", {uid, error: err});
    throw new functions.https.HttpsError(
        "internal",
        "Could not load event history",
        {domainCode: "event_history_failed"},
    );
  }
}

exports.getEventHistory = functions
    .runWith({timeoutSeconds: REQUEST_TIMEOUT_SECONDS, memory: "256MB"})
    .https.onCall((data, context) => getEventHistoryHandler(data, context));

exports.__private__ = {
  DEFAULT_HISTORY_LIMIT,
  MAX_HISTORY_LIMIT,
  buildEventHistoryItem,
  compareEventHistoryItems,
  getEventHistory,
  getEventHistoryHandler,
  normalizeGetEventHistoryPayload,
};
