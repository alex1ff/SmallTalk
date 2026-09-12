const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  buildConversationParticipantInfoByUserId,
  buildConversationParticipantMap,
  buildPairId,
} = require("./chats_shared");

const REQUEST_TIMEOUT_SECONDS = 30;
const EVENT_STATUS_ACTIVE = "active";
const OPEN_EVENT_ORGANIZER_CHAT_KEYS = Object.freeze(["eventId"]);
const OPEN_EVENT_ORGANIZER_CHAT_KEY_SET =
  new Set(OPEN_EVENT_ORGANIZER_CHAT_KEYS);

function throwOrganizerChatError(code, message, details) {
  throw new functions.https.HttpsError(code, message, details);
}

function throwInvalidOrganizerChatRequest(field, reason, message) {
  throwOrganizerChatError(
      "invalid-argument",
      message || "Invalid event organizer chat request",
      {
        domainCode: "invalid_event_organizer_chat_request",
        field,
        reason,
      },
  );
}

function validateExactOpenEventOrganizerChatKeys(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throwInvalidOrganizerChatRequest("payload", "invalid_type");
  }
  for (const key of Object.keys(data)) {
    if (!OPEN_EVENT_ORGANIZER_CHAT_KEY_SET.has(key)) {
      throwInvalidOrganizerChatRequest(key, "unknown_key");
    }
  }
  for (const key of OPEN_EVENT_ORGANIZER_CHAT_KEYS) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) {
      throwInvalidOrganizerChatRequest(key, "missing");
    }
  }
}

function normalizeEventId(value) {
  if (typeof value !== "string") {
    throwInvalidOrganizerChatRequest("eventId", "invalid_type");
  }
  const eventId = value.trim();
  if (
    !eventId ||
    eventId === "." ||
    eventId === ".." ||
    eventId.includes("/") ||
    Buffer.byteLength(eventId, "utf8") > 1500
  ) {
    throwInvalidOrganizerChatRequest("eventId", "invalid_format");
  }
  return eventId;
}

function normalizeOpenEventOrganizerChatPayload(data) {
  validateExactOpenEventOrganizerChatKeys(data);
  return {
    eventId: normalizeEventId(data.eventId),
  };
}

function normalizeUserId(value) {
  return typeof value === "string" ? value.trim() : "";
}

function hasConversationParticipants(conversationData, participantIds) {
  const existingParticipantIds = Array.isArray(conversationData?.participantIds) ?
    conversationData.participantIds.map((value) => String(value || "").trim()) :
    [];
  return participantIds.every((participantId) =>
    existingParticipantIds.includes(participantId),
  );
}

function conversationSeed({
  db,
  pairId,
  participantIds,
  participantInfoByUserId,
}) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  return {
    pairId,
    participantIds,
    participantRefs: participantIds.map((participantId) =>
      db.doc(`users/${participantId}`),
    ),
    participantMap: buildConversationParticipantMap(participantIds),
    participantInfoByUserId,
    isUnlocked: true,
    unlockedAt: now,
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

async function executeOpenEventOrganizerChatTransaction({
  db,
  eventId,
  requesterId,
}) {
  const normalizedRequesterId = normalizeUserId(requesterId);
  if (!normalizedRequesterId) {
    throwOrganizerChatError(
        "unauthenticated",
        "User must be authenticated.",
        {domainCode: "event_organizer_chat_requires_auth"},
    );
  }

  const eventRef = db.collection("events").doc(eventId);
  return db.runTransaction(async (transaction) => {
    const eventSnap = await transaction.get(eventRef);
    if (!eventSnap.exists) {
      throwOrganizerChatError(
          "not-found",
          "Event not found.",
          {domainCode: "event_not_found"},
      );
    }

    const eventData = eventSnap.data() || {};
    if (String(eventData.status || "").trim() !== EVENT_STATUS_ACTIVE) {
      throwOrganizerChatError(
          "failed-precondition",
          "Event is not active.",
          {domainCode: "event_not_active"},
      );
    }

    const organizerId = normalizeUserId(eventData.organizerId);
    if (!organizerId) {
      throwOrganizerChatError(
          "failed-precondition",
          "Event organizer is missing.",
          {domainCode: "event_organizer_missing"},
      );
    }
    if (organizerId === normalizedRequesterId) {
      throwOrganizerChatError(
          "failed-precondition",
          "Organizer cannot message themselves.",
          {domainCode: "event_organizer_chat_self"},
      );
    }

    const pairId = buildPairId(organizerId, normalizedRequesterId);
    if (!pairId) {
      throwOrganizerChatError(
          "failed-precondition",
          "Could not create organizer chat.",
          {domainCode: "event_organizer_chat_pair_invalid"},
      );
    }

    const participantIds = [organizerId, normalizedRequesterId].sort();
    const conversationRef = db.collection("conversations").doc(pairId);
    const conversationSnap = await transaction.get(conversationRef);
    const conversationData = conversationSnap.data() || {};

    if (
      conversationSnap.exists &&
      !hasConversationParticipants(conversationData, participantIds)
    ) {
      throwOrganizerChatError(
          "failed-precondition",
          "Conversation participant data is invalid.",
          {domainCode: "event_organizer_chat_conversation_mismatch"},
      );
    }

    const publicProfileSnaps = [];
    for (const participantId of participantIds) {
      publicProfileSnaps.push(await transaction.get(
          db.collection("user_public_profiles").doc(participantId),
      ));
    }
    const participantInfos = Object.fromEntries(
        publicProfileSnaps
            .filter((snapshot) => snapshot.exists)
            .map((snapshot) => [snapshot.ref.id, snapshot.data() || {}]),
    );
    const participantInfoByUserId =
      buildConversationParticipantInfoByUserId({
        participants: {participantIds},
        sessionData: {
          participantInfos: Object.fromEntries(
              Object.entries(participantInfos).map(([uid, profile]) => [
                uid,
                {
                  displayName: profile.display_name ?? profile.displayName,
                  photoUrl: profile.photo_url ?? profile.photoUrl ?? null,
                },
              ]),
          ),
        },
        existingInfoByUserId: conversationData.participantInfoByUserId,
        preferIncoming: true,
      });

    if (!conversationSnap.exists) {
      transaction.set(
          conversationRef,
          conversationSeed({
            db,
            pairId,
            participantIds,
            participantInfoByUserId,
          }),
      );
    } else {
      const updates = {participantInfoByUserId};
      if (conversationData.isUnlocked !== true) {
        Object.assign(updates, {
          isUnlocked: true,
          unlockedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      transaction.set(
          conversationRef,
          updates,
          {merge: true},
      );
    }

    return {
      conversationId: conversationRef.id,
      conversationPath: conversationRef.path,
    };
  });
}

async function openEventOrganizerChatHandler(data, context, options = {}) {
  if (!context.auth) {
    throwOrganizerChatError(
        "unauthenticated",
        "User must be authenticated.",
        {domainCode: "event_organizer_chat_requires_auth"},
    );
  }

  const payload = normalizeOpenEventOrganizerChatPayload(data);
  const db = options.db || admin.firestore();
  return executeOpenEventOrganizerChatTransaction({
    db,
    eventId: payload.eventId,
    requesterId: context.auth.uid,
  });
}

exports.openEventOrganizerChat = functions
    .runWith({timeoutSeconds: REQUEST_TIMEOUT_SECONDS})
    .https.onCall((data, context) => openEventOrganizerChatHandler(data, context));

exports.__private__ = {
  executeOpenEventOrganizerChatTransaction,
  openEventOrganizerChatHandler,
  normalizeOpenEventOrganizerChatPayload,
};
