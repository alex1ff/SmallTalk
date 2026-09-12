const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "leave_event"});
const {
  eventPreviewRef,
  writeEventPreview,
} = require("./event_public_projection");

const REQUEST_TIMEOUT_SECONDS = 30;
const EVENT_STATUS_ACTIVE = "active";
const PARTICIPANT_STATUS_ACTIVE = "active";
const PARTICIPANT_STATUS_LEFT = "left";
const PARTICIPANT_ROLE_ORGANIZER = "organizer";
const PARTICIPANT_ROLE_PARTICIPANT = "participant";
const EVENT_CHAT_COLLECTION = "eventChats";
const LEAVE_EVENT_KEYS = Object.freeze(["eventId"]);
const LEAVE_EVENT_KEY_SET = new Set(LEAVE_EVENT_KEYS);
const EVENT_CHAT_METADATA_KEYS = Object.freeze([
  "eventId",
  "readAccessUserIds",
  "createdAt",
  "updatedAt",
]);
const EVENT_CHAT_METADATA_KEY_SET = new Set(EVENT_CHAT_METADATA_KEYS);

function throwLeaveError(code, message, details) {
  throw new functions.https.HttpsError(code, message, details);
}

function throwInvalidLeaveRequest(field, reason, message) {
  throwLeaveError(
      "invalid-argument",
      message || "Invalid leave event request",
      {domainCode: "invalid_leave_request", field, reason},
  );
}

function validateExactLeaveEventKeys(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throwInvalidLeaveRequest("payload", "invalid_type");
  }
  for (const key of Object.keys(data)) {
    if (!LEAVE_EVENT_KEY_SET.has(key)) {
      throwInvalidLeaveRequest(key, "unknown_key");
    }
  }
  for (const key of LEAVE_EVENT_KEYS) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) {
      throwInvalidLeaveRequest(key, "missing");
    }
  }
}

function normalizeEventId(value) {
  if (typeof value !== "string") {
    throwInvalidLeaveRequest("eventId", "invalid_type");
  }
  const eventId = value.trim();
  if (!eventId || eventId.includes("/")) {
    throwInvalidLeaveRequest("eventId", "invalid_format");
  }
  return eventId;
}

function normalizeLeaveEventPayload(data) {
  validateExactLeaveEventKeys(data);
  return {eventId: normalizeEventId(data.eventId)};
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (value && typeof value.toDate === "function") {
    const date = value.toDate();
    return date instanceof Date ? date.getTime() : NaN;
  }
  return NaN;
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

function createServerLeaveTime() {
  const leaveDate = new Date();
  return {
    leaveDate,
    leaveTimestamp: admin.firestore.Timestamp.fromDate(leaveDate),
  };
}

function failParticipantStateInconsistent() {
  throwLeaveError(
      "failed-precondition",
      "Event participant state is inconsistent",
      {domainCode: "event_participant_state_inconsistent"},
  );
}

function assertEventLeaveable({eventExists, eventData, eventId}) {
  if (!eventExists) {
    throwLeaveError(
        "not-found",
        "Event not found",
        {domainCode: "event_not_found"},
    );
  }
  if (eventData.status !== EVENT_STATUS_ACTIVE || eventData.canceledAt !== null) {
    throwLeaveError(
        "failed-precondition",
        "Only active events can be left",
        {domainCode: "event_not_leaveable", reason: "not_active"},
    );
  }
  if (eventData.chatId !== eventId) {
    throwLeaveError(
        "failed-precondition",
        "Event chat id does not match event id",
        {
          domainCode: "event_chat_metadata_invalid",
          reason: "event_chat_id_mismatch",
        },
    );
  }
  if (!isValidPathSegment(eventData.organizerId)) {
    failParticipantStateInconsistent();
  }
  const participantsCount = eventData.participantsCount;
  const capacity = eventData.capacity;
  if (
    !Number.isInteger(participantsCount) ||
    !Number.isInteger(capacity) ||
    participantsCount < 1 ||
    capacity < 2 ||
    capacity > 50 ||
    participantsCount > capacity
  ) {
    failParticipantStateInconsistent();
  }
}

function assertEventStartsInFuture({eventData, now}) {
  const startsAtMillis = timestampMillis(eventData.startsAt);
  if (!Number.isFinite(startsAtMillis) || startsAtMillis <= now.getTime()) {
    throwLeaveError(
        "failed-precondition",
        "Event already started",
        {domainCode: "event_not_leaveable", reason: "event_started"},
    );
  }
}

function assertEventCanDecrement(eventData) {
  if (eventData.participantsCount < 2) {
    failParticipantStateInconsistent();
  }
}

function assertOrganizerParticipantActive({
  organizerParticipantExists,
  organizerParticipantData,
  organizerId,
}) {
  if (
    !organizerParticipantExists ||
    organizerParticipantData.userId !== organizerId ||
    organizerParticipantData.role !== PARTICIPANT_ROLE_ORGANIZER ||
    organizerParticipantData.status !== PARTICIPANT_STATUS_ACTIVE ||
    organizerParticipantData.leftAt !== null
  ) {
    throwLeaveError(
        "failed-precondition",
        "Participant membership is inconsistent",
        {domainCode: "participant_membership_inconsistent"},
    );
  }
}

function assertParticipantCanLeave({
  participantExists,
  participantData,
  uid,
  organizerId,
}) {
  if (uid === organizerId) {
    throwLeaveError(
        "failed-precondition",
        "Organizer cannot leave own event",
        {domainCode: "organizer_cannot_leave"},
    );
  }
  if (!participantExists) {
    throwLeaveError(
        "failed-precondition",
        "User is not an active event participant",
        {domainCode: "not_active_participant"},
    );
  }
  if (
    participantData.userId !== uid ||
    participantData.role !== PARTICIPANT_ROLE_PARTICIPANT
  ) {
    throwLeaveError(
        "failed-precondition",
        "Participant membership is inconsistent",
        {domainCode: "participant_membership_inconsistent"},
    );
  }
  if (participantData.status === PARTICIPANT_STATUS_LEFT) {
    throwLeaveError(
        "failed-precondition",
        "User is not an active event participant",
        {domainCode: "not_active_participant"},
    );
  }
  if (
    participantData.status !== PARTICIPANT_STATUS_ACTIVE ||
    participantData.leftAt !== null
  ) {
    throwLeaveError(
        "failed-precondition",
        "Participant membership is inconsistent",
        {domainCode: "participant_membership_inconsistent"},
    );
  }
}

function assertChatMetadata({chatExists, chatData, eventId}) {
  if (!chatExists) {
    throwLeaveError(
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
    throwLeaveError(
        "failed-precondition",
        "Event chat metadata is invalid",
        {domainCode: "event_chat_metadata_invalid", reason: "invalid_shape"},
    );
  }
  if (chatData.eventId !== eventId) {
    throwLeaveError(
        "failed-precondition",
        "Event chat metadata does not match event id",
        {
          domainCode: "event_chat_metadata_invalid",
          reason: "chat_event_id_mismatch",
        },
    );
  }
}

function assertActiveParticipantDoc({doc, organizerId}) {
  const data = doc.data() || {};
  const expectedRole = doc.id === organizerId ?
    PARTICIPANT_ROLE_ORGANIZER :
    PARTICIPANT_ROLE_PARTICIPANT;
  if (
    !isValidPathSegment(doc.id) ||
    data.userId !== doc.id ||
    data.role !== expectedRole ||
    data.status !== PARTICIPANT_STATUS_ACTIVE ||
    data.leftAt !== null
  ) {
    failParticipantStateInconsistent();
  }
}

function buildActiveParticipantIds(activeParticipantDocs, {organizerId}) {
  const ids = [];
  for (const doc of activeParticipantDocs) {
    assertActiveParticipantDoc({doc, organizerId});
    ids.push(doc.id);
  }
  ids.sort();
  const uniqueIds = [...new Set(ids)];
  if (uniqueIds.length !== ids.length) {
    failParticipantStateInconsistent();
  }
  return uniqueIds;
}

function areEqualStringArrays(left, right) {
  if (left.length !== right.length) {
    return false;
  }
  for (let index = 0; index < left.length; index += 1) {
    if (left[index] !== right[index]) {
      return false;
    }
  }
  return true;
}

function assertActiveParticipantSet({
  activeParticipantIds,
  organizerId,
  uid,
  participantsCount,
}) {
  if (
    activeParticipantIds.length !== participantsCount ||
    !activeParticipantIds.includes(organizerId) ||
    !activeParticipantIds.includes(uid)
  ) {
    failParticipantStateInconsistent();
  }
}

function validateReadAccessUserIds(value, {activeParticipantIds}) {
  if (!Array.isArray(value)) {
    throwLeaveError(
        "failed-precondition",
        "Event chat access metadata is invalid",
        {domainCode: "event_chat_metadata_invalid", reason: "invalid_access"},
    );
  }
  if (value.length !== activeParticipantIds.length) {
    throwLeaveError(
        "failed-precondition",
        "Event chat access metadata is invalid",
        {domainCode: "event_chat_metadata_invalid", reason: "invalid_access"},
    );
  }
  const seen = new Set();
  for (const item of value) {
    if (
      typeof item !== "string" ||
      !item ||
      item.includes("/") ||
      seen.has(item)
    ) {
      throwLeaveError(
          "failed-precondition",
          "Event chat access metadata is invalid",
          {domainCode: "event_chat_metadata_invalid", reason: "invalid_access"},
      );
    }
    seen.add(item);
  }
  const readAccessUserIds = [...seen].sort();
  if (!areEqualStringArrays(readAccessUserIds, activeParticipantIds)) {
    throwLeaveError(
        "failed-precondition",
        "Event chat access metadata is invalid",
        {domainCode: "event_chat_metadata_invalid", reason: "invalid_access"},
    );
  }
}

function buildReadAccessAfterLeave(activeParticipantIds, {organizerId, uid}) {
  return [
    organizerId,
    ...activeParticipantIds
        .filter((item) => item !== organizerId && item !== uid)
        .sort(),
  ];
}

async function executeLeaveEventTransaction({
  db,
  uid,
  getLeaveTime,
  payload,
}) {
  const eventRef = db.collection("events").doc(payload.eventId);
  const previewRef = eventPreviewRef(db, payload.eventId);
  const participantRef = eventRef.collection("participants").doc(uid);
  const chatRef = db.collection(EVENT_CHAT_COLLECTION).doc(payload.eventId);
  const userRef = db.collection("users").doc(uid);
  const activeParticipantsQuery = eventRef
      .collection("participants")
      .where("status", "==", "active");

  return await db.runTransaction(async (tx) => {
    const eventDoc = await tx.get(eventRef);
    const eventData = eventDoc.exists ? eventDoc.data() || {} : {};
    assertEventLeaveable({
      eventExists: eventDoc.exists,
      eventData,
      eventId: payload.eventId,
    });

    const organizerParticipantRef = eventRef
        .collection("participants")
        .doc(eventData.organizerId);
    const participantRead = tx.get(participantRef);
    const organizerParticipantRead = eventData.organizerId === uid ?
      participantRead :
      tx.get(organizerParticipantRef);
    const [
      participantDoc,
      organizerParticipantDoc,
      chatDoc,
      userDoc,
      activeParticipantsSnapshot,
    ] =
      await Promise.all([
        participantRead,
        organizerParticipantRead,
        tx.get(chatRef),
        tx.get(userRef),
        tx.get(activeParticipantsQuery),
      ]);
    const participantData = participantDoc.exists ?
      participantDoc.data() || {} :
      {};
    const organizerParticipantData = organizerParticipantDoc.exists ?
      organizerParticipantDoc.data() || {} :
      {};
    const chatData = chatDoc.exists ? chatDoc.data() || {} : {};

    assertOrganizerParticipantActive({
      organizerParticipantExists: organizerParticipantDoc.exists,
      organizerParticipantData,
      organizerId: eventData.organizerId,
    });
    assertParticipantCanLeave({
      participantExists: participantDoc.exists,
      participantData,
      uid,
      organizerId: eventData.organizerId,
    });
    assertEventCanDecrement(eventData);
    assertChatMetadata({
      chatExists: chatDoc.exists,
      chatData,
      eventId: payload.eventId,
    });

    const activeParticipantIds = buildActiveParticipantIds(
        activeParticipantsSnapshot.docs || [],
        {organizerId: eventData.organizerId},
    );
    assertActiveParticipantSet({
      activeParticipantIds,
      organizerId: eventData.organizerId,
      uid,
      participantsCount: eventData.participantsCount,
    });
    validateReadAccessUserIds(chatData.readAccessUserIds, {
      activeParticipantIds,
    });
    const {
      leaveDate,
      leaveTimestamp,
    } = getLeaveTime();
    assertEventStartsInFuture({
      eventData,
      now: leaveDate,
    });
    const readAccessUserIds = buildReadAccessAfterLeave(activeParticipantIds, {
      organizerId: eventData.organizerId,
      uid,
    });
    const participantsCount = eventData.participantsCount - 1;
    const previewDoc = await tx.get(previewRef);

    tx.update(eventRef, {
      participantsCount,
      updatedAt: leaveTimestamp,
    });
    tx.update(participantRef, {
      status: PARTICIPANT_STATUS_LEFT,
      leftAt: leaveTimestamp,
      updatedAt: leaveTimestamp,
    });
    tx.update(chatRef, {
      readAccessUserIds,
      updatedAt: leaveTimestamp,
    });
    if (userDoc.exists) {
      tx.update(userRef, {
        eventChatInboxEventIds: admin.firestore.FieldValue.arrayRemove(
            payload.eventId,
        ),
      });
    }
    writeEventPreview({
      tx,
      previewDoc,
      previewRef,
      eventData: {
        ...eventData,
        participantsCount,
        updatedAt: leaveTimestamp,
      },
    });

    return {
      eventId: payload.eventId,
      participantStatus: PARTICIPANT_STATUS_LEFT,
      participantsCount,
      leftAt: leaveDate.toISOString(),
    };
  });
}

exports.__private__ = {
  LEAVE_EVENT_KEYS,
  executeLeaveEventTransaction,
  normalizeLeaveEventPayload,
};

exports.leaveEvent = functions
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
      const payload = normalizeLeaveEventPayload(data);
      const db = admin.firestore();

      try {
        return await executeLeaveEventTransaction({
          db,
          uid,
          getLeaveTime: createServerLeaveTime,
          payload,
        });
      } catch (err) {
        if (err instanceof functions.https.HttpsError) {
          throw err;
        }
        safeLog.error("leave_event_failed", {uid, error: err});
        throw new functions.https.HttpsError(
            "internal",
            "Unable to leave event",
        );
      }
    });
