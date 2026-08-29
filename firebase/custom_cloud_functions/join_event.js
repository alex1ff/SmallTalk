const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  buildBoundedEventChatInboxEventIds,
} = require("./event_chat_inbox");
const {isPaidPremium} = require("./trial_access");
const {
  eventPreviewRef,
  writeEventPreview,
} = require("./event_public_projection");

const REQUEST_TIMEOUT_SECONDS = 30;
const EVENT_STATUS_ACTIVE = "active";
const PARTICIPANT_STATUS_ACTIVE = "active";
const PARTICIPANT_STATUS_LEFT = "left";
const PARTICIPANT_ROLE_PARTICIPANT = "participant";
const EVENT_CHAT_COLLECTION = "eventChats";
const JOIN_EVENT_KEYS = Object.freeze(["eventId"]);
const JOIN_EVENT_KEY_SET = new Set(JOIN_EVENT_KEYS);
const EVENT_CHAT_METADATA_KEYS = Object.freeze([
  "eventId",
  "readAccessUserIds",
  "createdAt",
  "updatedAt",
]);
const EVENT_CHAT_METADATA_KEY_SET = new Set(EVENT_CHAT_METADATA_KEYS);

function throwJoinError(code, message, details) {
  throw new functions.https.HttpsError(code, message, details);
}

function throwInvalidJoinRequest(field, reason, message) {
  throwJoinError(
      "invalid-argument",
      message || "Invalid join event request",
      {domainCode: "invalid_join_request", field, reason},
  );
}

function validateExactJoinEventKeys(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throwInvalidJoinRequest("payload", "invalid_type");
  }
  for (const key of Object.keys(data)) {
    if (!JOIN_EVENT_KEY_SET.has(key)) {
      throwInvalidJoinRequest(key, "unknown_key");
    }
  }
  for (const key of JOIN_EVENT_KEYS) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) {
      throwInvalidJoinRequest(key, "missing");
    }
  }
}

function normalizeEventId(value) {
  if (typeof value !== "string") {
    throwInvalidJoinRequest("eventId", "invalid_type");
  }
  const eventId = value.trim();
  if (!eventId || eventId.includes("/")) {
    throwInvalidJoinRequest("eventId", "invalid_format");
  }
  return eventId;
}

function normalizeJoinEventPayload(data) {
  validateExactJoinEventKeys(data);
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

function normalizeProfileString(value) {
  return typeof value === "string" ? value.normalize("NFC").trim() : "";
}

function buildParticipantSnapshot({userExists, userData = {}}) {
  if (!userExists) {
    throwJoinError(
        "failed-precondition",
        "Participant profile must exist",
        {domainCode: "participant_profile_required", field: "display_name"},
    );
  }
  const displayName = normalizeProfileString(userData.display_name);
  if (!displayName) {
    throwJoinError(
        "failed-precondition",
        "Participant display name is required",
        {domainCode: "participant_profile_required", field: "display_name"},
    );
  }
  const photoUrl = normalizeProfileString(userData.photo_url);
  return {
    displayName,
    photoUrl: photoUrl || null,
  };
}

function assertEventJoinable({eventExists, eventData, eventId, now}) {
  if (!eventExists) {
    throwJoinError(
        "not-found",
        "Event not found",
        {domainCode: "event_not_found"},
    );
  }
  if (eventData.status !== EVENT_STATUS_ACTIVE || eventData.canceledAt !== null) {
    throwJoinError(
        "failed-precondition",
        "Only active events can be joined",
        {domainCode: "event_not_joinable", reason: "not_active"},
    );
  }
  if (eventData.chatId !== eventId) {
    throwJoinError(
        "failed-precondition",
        "Event chat id does not match event id",
        {
          domainCode: "event_chat_metadata_invalid",
          reason: "event_chat_id_mismatch",
        },
    );
  }
  if (!isValidPathSegment(eventData.organizerId)) {
    throwJoinError(
        "failed-precondition",
        "Event participant state is inconsistent",
        {domainCode: "event_participant_state_inconsistent"},
    );
  }
  const startsAtMillis = timestampMillis(eventData.startsAt);
  if (!Number.isFinite(startsAtMillis) || startsAtMillis <= now.getTime()) {
    throwJoinError(
        "failed-precondition",
        "Past events cannot be joined",
        {domainCode: "event_not_joinable", reason: "past_event"},
    );
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
    throwJoinError(
        "failed-precondition",
        "Event participant state is inconsistent",
        {domainCode: "event_participant_state_inconsistent"},
    );
  }
}

function failParticipantStateInconsistent() {
  throwJoinError(
      "failed-precondition",
      "Event participant state is inconsistent",
      {domainCode: "event_participant_state_inconsistent"},
  );
}

function assertOrganizerParticipantActive({
  organizerParticipantExists,
  organizerParticipantData,
  organizerId,
}) {
  if (
    !organizerParticipantExists ||
    organizerParticipantData.userId !== organizerId ||
    organizerParticipantData.role !== "organizer" ||
    organizerParticipantData.status !== PARTICIPANT_STATUS_ACTIVE
  ) {
    throwJoinError(
        "failed-precondition",
        "Participant membership is inconsistent",
        {domainCode: "participant_membership_inconsistent"},
    );
  }
}

function assertEventHasCapacity(eventData) {
  const participantsCount = eventData.participantsCount;
  const capacity = eventData.capacity;
  if (participantsCount >= capacity) {
    throwJoinError(
        "failed-precondition",
        "Event is full",
        {
          domainCode: "event_full",
          participantsCount,
          capacity,
        },
    );
  }
}

function assertChatMetadata({chatExists, chatData, eventId}) {
  if (!chatExists) {
    throwJoinError(
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
    throwJoinError(
        "failed-precondition",
        "Event chat metadata is invalid",
        {domainCode: "event_chat_metadata_invalid", reason: "invalid_shape"},
    );
  }
  if (chatData.eventId !== eventId) {
    throwJoinError(
        "failed-precondition",
        "Event chat metadata does not match event id",
        {
          domainCode: "event_chat_metadata_invalid",
          reason: "chat_event_id_mismatch",
        },
    );
  }
}

function areEqualStringArrays(left, right) {
  return left.length === right.length &&
    left.every((value, index) => value === right[index]);
}

function validateReadAccessUserIds(value, {organizerId, activeParticipantIds}) {
  if (!Array.isArray(value)) {
    throwJoinError(
        "failed-precondition",
        "Event chat access metadata is invalid",
        {domainCode: "event_chat_metadata_invalid", reason: "invalid_access"},
    );
  }
  const seen = new Set();
  for (const uid of value) {
    if (typeof uid !== "string" || !uid || uid.includes("/") || seen.has(uid)) {
      throwJoinError(
          "failed-precondition",
          "Event chat access metadata is invalid",
          {domainCode: "event_chat_metadata_invalid", reason: "invalid_access"},
      );
    }
    seen.add(uid);
  }
  if (!seen.has(organizerId)) {
    throwJoinError(
        "failed-precondition",
        "Event chat access metadata is invalid",
        {domainCode: "event_chat_metadata_invalid", reason: "missing_organizer"},
    );
  }
  const readAccessUserIds = [...seen].sort();
  if (
    Array.isArray(activeParticipantIds) &&
    !areEqualStringArrays(readAccessUserIds, activeParticipantIds)
  ) {
    throwJoinError(
        "failed-precondition",
        "Event chat access metadata is invalid",
        {domainCode: "event_chat_metadata_invalid", reason: "invalid_access"},
    );
  }
  return [...value];
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
  if (
    activeParticipantIds.length !== eventData.participantsCount ||
    !activeParticipantIds.includes(eventData.organizerId)
  ) {
    failParticipantStateInconsistent();
  }
  return activeParticipantIds;
}

function assertParticipantJoinable({
  participantExists,
  participantData,
  uid,
  organizerId,
  eventStartsAt,
  now,
}) {
  if (!participantExists) {
    if (uid === organizerId) {
      throwJoinError(
          "failed-precondition",
          "Participant membership is inconsistent",
          {domainCode: "participant_membership_inconsistent"},
      );
    }
    return "new";
  }
  if (
    participantData.userId !== uid ||
    !["organizer", PARTICIPANT_ROLE_PARTICIPANT].includes(participantData.role) ||
    ![PARTICIPANT_STATUS_ACTIVE, PARTICIPANT_STATUS_LEFT]
        .includes(participantData.status)
  ) {
    throwJoinError(
        "failed-precondition",
        "Participant membership is inconsistent",
        {domainCode: "participant_membership_inconsistent"},
    );
  }
  if (participantData.status === PARTICIPANT_STATUS_ACTIVE) {
    throwJoinError(
        "failed-precondition",
        "User already joined this event",
        {domainCode: "already_joined"},
    );
  }
  if (participantData.role !== PARTICIPANT_ROLE_PARTICIPANT) {
    throwJoinError(
        "failed-precondition",
        "Participant membership is inconsistent",
        {domainCode: "participant_membership_inconsistent"},
    );
  }
  const leftAtMillis = timestampMillis(participantData.leftAt);
  const startsAtMillis = timestampMillis(eventStartsAt);
  if (
    !Number.isFinite(leftAtMillis) ||
    !Number.isFinite(startsAtMillis) ||
    leftAtMillis > now.getTime() ||
    leftAtMillis >= startsAtMillis
  ) {
    throwJoinError(
        "failed-precondition",
        "Participant membership is inconsistent",
        {domainCode: "participant_membership_inconsistent"},
    );
  }
  return "rejoin";
}

function buildNewParticipantData({
  uid,
  participantSnapshot,
  joinTimestamp,
}) {
  return {
    userId: uid,
    displayName: participantSnapshot.displayName,
    photoUrl: participantSnapshot.photoUrl,
    role: PARTICIPANT_ROLE_PARTICIPANT,
    status: PARTICIPANT_STATUS_ACTIVE,
    joinedAt: joinTimestamp,
    leftAt: null,
    createdAt: joinTimestamp,
    updatedAt: joinTimestamp,
  };
}

function buildRejoinParticipantUpdate({
  participantSnapshot,
  joinTimestamp,
}) {
  return {
    displayName: participantSnapshot.displayName,
    photoUrl: participantSnapshot.photoUrl,
    status: PARTICIPANT_STATUS_ACTIVE,
    joinedAt: joinTimestamp,
    leftAt: null,
    updatedAt: joinTimestamp,
  };
}

function addReadAccessUser(readAccessUserIds, uid) {
  return [...new Set([...readAccessUserIds, uid])];
}

async function executeJoinEventTransaction({
  db,
  uid,
  joinDate,
  joinTimestamp,
  payload,
}) {
  const eventRef = db.collection("events").doc(payload.eventId);
  const previewRef = eventPreviewRef(db, payload.eventId);
  const participantRef = eventRef.collection("participants").doc(uid);
  const chatRef = db.collection(EVENT_CHAT_COLLECTION).doc(payload.eventId);
  const userRef = db.collection("users").doc(uid);
  const activeParticipantsQuery = eventRef
      .collection("participants")
      .where("status", "==", PARTICIPANT_STATUS_ACTIVE);

  return await db.runTransaction(async (tx) => {
    const eventDoc = await tx.get(eventRef);
    const eventData = eventDoc.exists ? eventDoc.data() || {} : {};
    assertEventJoinable({
      eventExists: eventDoc.exists,
      eventData,
      eventId: payload.eventId,
      now: joinDate,
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
    ] = await Promise.all([
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
    const userData = userDoc.exists ? userDoc.data() || {} : {};

    assertOrganizerParticipantActive({
      organizerParticipantExists: organizerParticipantDoc.exists,
      organizerParticipantData,
      organizerId: eventData.organizerId,
    });
    assertChatMetadata({
      chatExists: chatDoc.exists,
      chatData,
      eventId: payload.eventId,
    });
    const joinMode = assertParticipantJoinable({
      participantExists: participantDoc.exists,
      participantData,
      uid,
      organizerId: eventData.organizerId,
      eventStartsAt: eventData.startsAt,
      now: joinDate,
    });
    const activeParticipantIds = assertParticipantCountInvariant({
      activeParticipantDocs: activeParticipantsSnapshot.docs || [],
      eventData,
    });
    assertEventHasCapacity(eventData);
    const participantSnapshot = buildParticipantSnapshot({
      userExists: userDoc.exists,
      userData,
    });
    if (eventData.organizerId !== uid &&
        !isPaidPremium(userData, joinDate.getTime())) {
      throwJoinError(
          "permission-denied",
          "Premium is required to join events",
          {domainCode: "premium_required"},
      );
    }
    const readAccessUserIds = addReadAccessUser(
        validateReadAccessUserIds(chatData.readAccessUserIds, {
          organizerId: eventData.organizerId,
          activeParticipantIds,
        }),
        uid,
    );
    const participantsCount = eventData.participantsCount + 1;
    const previewDoc = await tx.get(previewRef);

    tx.update(eventRef, {
      participantsCount,
      updatedAt: joinTimestamp,
    });
    if (joinMode === "new") {
      tx.create(participantRef, buildNewParticipantData({
        uid,
        participantSnapshot,
        joinTimestamp,
      }));
    } else {
      tx.update(participantRef, buildRejoinParticipantUpdate({
        participantSnapshot,
        joinTimestamp,
      }));
    }
    tx.update(chatRef, {
      readAccessUserIds,
      updatedAt: joinTimestamp,
    });
    tx.update(userRef, {
      eventChatInboxEventIds: buildBoundedEventChatInboxEventIds(
          userDoc.data()?.eventChatInboxEventIds,
          payload.eventId,
      ),
      hiddenChatKeys: admin.firestore.FieldValue.arrayRemove(
          `event:${payload.eventId}`,
      ),
    });
    writeEventPreview({
      tx,
      previewDoc,
      previewRef,
      eventData: {
        ...eventData,
        participantsCount,
        updatedAt: joinTimestamp,
      },
    });

    return {
      eventId: payload.eventId,
      participantStatus: PARTICIPANT_STATUS_ACTIVE,
      participantsCount,
      joinedAt: joinDate.toISOString(),
    };
  });
}

exports.__private__ = {
  JOIN_EVENT_KEYS,
  addReadAccessUser,
  buildNewParticipantData,
  buildParticipantSnapshot,
  buildRejoinParticipantUpdate,
  executeJoinEventTransaction,
  normalizeJoinEventPayload,
};

exports.joinEvent = functions
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
      const joinDate = new Date();
      const joinTimestamp = admin.firestore.Timestamp.fromDate(joinDate);
      const payload = normalizeJoinEventPayload(data);
      const db = admin.firestore();

      try {
        return await executeJoinEventTransaction({
          db,
          uid,
          joinDate,
          joinTimestamp,
          payload,
        });
      } catch (err) {
        if (err instanceof functions.https.HttpsError) {
          throw err;
        }
        console.error("joinEvent failed", {uid, err});
        throw new functions.https.HttpsError(
            "internal",
            "Unable to join event",
        );
      }
    });
