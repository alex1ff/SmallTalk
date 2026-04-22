const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const {
  CONVERSATION_MESSAGE_TYPE_TEXT,
  buildConversationSeed,
  conversationMatchesUnlockParticipants,
  getConnectedCallStartMillis,
  getSessionEndedAtMillis,
  getUnlockEligibility,
  toMillis,
} = require("./chats_shared");

const MAX_CALL_CHAT_MESSAGES = 100;
const MAX_CALL_CHAT_TEXT_LENGTH = 2000;
const PERSIST_WINDOW_AFTER_END_MS = 30 * 60 * 1000;

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function sanitizeDocIdSegment(value, fallback) {
  const normalized = normalizeString(value)
    .replace(/\//g, "_")
    .replace(/[^A-Za-z0-9_-]/g, "_")
    .slice(0, 120);
  return normalized || fallback;
}

function normalizeCallChatMessages(rawMessages) {
  if (!Array.isArray(rawMessages)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Messages must be an array.",
    );
  }

  if (rawMessages.length > MAX_CALL_CHAT_MESSAGES) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Too many messages.",
    );
  }

  const seenClientIds = new Set();
  const messages = [];
  rawMessages.forEach((rawMessage, index) => {
    if (!rawMessage || typeof rawMessage !== "object") {
      return;
    }

    const text = normalizeString(rawMessage.text);
    if (!text) {
      return;
    }
    if (text.length > MAX_CALL_CHAT_TEXT_LENGTH) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Message text is too long.",
      );
    }

    const sentAtMs = Number(rawMessage.sentAtMs);
    if (!Number.isFinite(sentAtMs) || sentAtMs <= 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Message timestamp is invalid.",
      );
    }

    const clientId = sanitizeDocIdSegment(rawMessage.clientId, `m_${index}`);
    if (seenClientIds.has(clientId)) {
      return;
    }
    seenClientIds.add(clientId);

    messages.push({
      clientId,
      text,
      sentAtMs: Math.floor(sentAtMs),
    });
  });

  return messages;
}

function assertPersistEligibility({
  sessionData = {},
  userId,
  nowMillis = Date.now(),
}) {
  const eligibility = getUnlockEligibility(sessionData);
  if (!eligibility.eligible) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Session is not eligible for persisted call chat.",
      {reason: eligibility.reason},
    );
  }

  if (!eligibility.participantIds.includes(userId)) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "You are not a participant of this session.",
    );
  }

  const endedAtMillis = getSessionEndedAtMillis(sessionData) || nowMillis;
  if (endedAtMillis > 0 &&
      nowMillis - endedAtMillis > PERSIST_WINDOW_AFTER_END_MS) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Call chat persistence window has expired.",
      {reason: "persist_window_expired"},
    );
  }

  return {
    eligibility,
    endedAtMillis,
  };
}

function clampMessageCreatedAtMillis({
  messageSentAtMs,
  sessionData = {},
  endedAtMillis,
}) {
  const startedAtMillis =
    getConnectedCallStartMillis(sessionData) ||
    toMillis(sessionData.startedAt) ||
    toMillis(sessionData.createdAt) ||
    messageSentAtMs;
  const latestMessageMillis = endedAtMillis > 0 ?
    Math.max(startedAtMillis, endedAtMillis - 1) :
    messageSentAtMs;

  return Math.min(
    Math.max(messageSentAtMs, startedAtMillis),
    latestMessageMillis,
  );
}

function buildPersistCallChatMessages({
  sessionId,
  sessionRef,
  sessionData = {},
  userId,
  userRef,
  messages = [],
  endedAtMillis,
}) {
  const safeSessionId = sanitizeDocIdSegment(sessionId, "session");
  const safeUserId = sanitizeDocIdSegment(userId, "user");

  return messages.map((message) => {
    const messageId = [
      "incall",
      safeSessionId,
      safeUserId,
      message.clientId,
    ].join("_");
    const createdAtMillis = clampMessageCreatedAtMillis({
      messageSentAtMs: message.sentAtMs,
      sessionData,
      endedAtMillis,
    });

    return {
      messageId,
      payload: {
        senderId: userId,
        senderRef: userRef,
        type: CONVERSATION_MESSAGE_TYPE_TEXT,
        text: message.text,
        createdAt: Timestamp.fromMillis(createdAtMillis),
        inCallSessionRef: sessionRef,
      },
    };
  });
}

async function persistCallChatForUser({
  db,
  userId,
  sessionId,
  messages,
  nowMillis = Date.now(),
}) {
  const sessionRef = db.collection("videoSessions").doc(sessionId);
  const userRef = db.collection("users").doc(userId);

  return db.runTransaction(async (transaction) => {
    const sessionSnap = await transaction.get(sessionRef);
    if (!sessionSnap.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Video session not found.",
      );
    }

    const sessionData = sessionSnap.data() || {};
    const {eligibility, endedAtMillis} = assertPersistEligibility({
      sessionData,
      userId,
      nowMillis,
    });
    const conversationRef = db.collection("conversations").doc(
      eligibility.pairId,
    );
    const conversationSnap = await transaction.get(conversationRef);
    const conversationData = conversationSnap.data() || {};

    if (
      conversationSnap.exists &&
      !conversationMatchesUnlockParticipants(conversationData, eligibility)
    ) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Conversation participant data does not match the session.",
      );
    }

    const messageWrites = buildPersistCallChatMessages({
      sessionId,
      sessionRef,
      sessionData,
      userId,
      userRef,
      messages,
      endedAtMillis,
    });
    const messageRefs = messageWrites.map((messageWrite) =>
      conversationRef.collection("messages").doc(messageWrite.messageId),
    );
    const messageSnaps = [];
    for (const messageRef of messageRefs) {
      messageSnaps.push(await transaction.get(messageRef));
    }

    if (!conversationSnap.exists) {
      transaction.set(
        conversationRef,
        buildConversationSeed({
          participants: eligibility,
          sessionRef,
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
        {merge: true},
      );
    }

    let written = 0;
    let skipped = 0;
    messageWrites.forEach((messageWrite, index) => {
      if (messageSnaps[index].exists) {
        skipped += 1;
        return;
      }
      transaction.set(messageRefs[index], messageWrite.payload);
      written += 1;
    });

    return {
      status: written > 0 ? "persisted" : "already_persisted",
      written,
      skipped,
      conversationPath: conversationRef.path,
    };
  });
}

exports.persistCallChat = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated.",
      );
    }

    const sessionId = normalizeString(data?.sessionId);
    if (!sessionId || sessionId.includes("/")) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Session ID is required.",
      );
    }

    const messages = normalizeCallChatMessages(data?.messages);
    if (messages.length === 0) {
      return {
        status: "empty",
        written: 0,
        skipped: 0,
      };
    }

    return await persistCallChatForUser({
      db: admin.firestore(),
      userId: context.auth.uid,
      sessionId,
      messages,
    });
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      "internal",
      error.message || "Failed to persist call chat.",
    );
  }
});

exports.__private__ = {
  MAX_CALL_CHAT_MESSAGES,
  MAX_CALL_CHAT_TEXT_LENGTH,
  PERSIST_WINDOW_AFTER_END_MS,
  assertPersistEligibility,
  buildPersistCallChatMessages,
  clampMessageCreatedAtMillis,
  normalizeCallChatMessages,
  persistCallChatForUser,
  sanitizeDocIdSegment,
};
