const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const {Timestamp} = require("firebase-admin/firestore");

const {
  CALL_EVENT_KIND_VIDEO,
  CALL_EVENT_OUTCOME_CANCELLED,
  CALL_EVENT_OUTCOME_COMPLETED,
  CALL_EVENT_OUTCOME_MISSED,
  CONVERSATION_MESSAGE_TYPE_CALL_EVENT,
  buildCallEventMessageId,
  buildCallEventMessagePayload,
  buildConversationParticipantMap,
  buildConversationSummaryUpdate,
  ensureConversationCallEventForSession,
  getConnectedCallStartMillis,
  getConversationCallEventEligibility,
  getUnlockEligibility,
} = require("./chats_shared");
const {
  __private__: {
    ensureCallEventMessageForProcessedConversation,
    maybeWriteCallEventForProcessedOutcome,
  },
} = require("./conversation_unlock_events");

if (!admin.apps.length) {
  admin.initializeApp({projectId: "demo-smalltalk"});
}

function createFakeFirestore(seed = {}) {
  const store = new Map(Object.entries(seed));

  const makeRef = (path) => ({
    path,
    id: path.split("/").pop(),
    collection(name) {
      return {
        doc(id) {
          return makeRef(`${path}/${name}/${id}`);
        },
      };
    },
    async get() {
      const data = store.get(path);
      return {
        exists: data !== undefined,
        data: () => data,
        ref: makeRef(path),
      };
    },
    async set(data, options = {}) {
      const current = store.get(path) || {};
      store.set(path, options.merge ? {...current, ...data} : data);
    },
  });

  const db = {
    collection(name) {
      return {
        doc(id) {
          return makeRef(`${name}/${id}`);
        },
      };
    },
    async runTransaction(callback) {
      const transaction = {
        async get(ref) {
          return ref.get();
        },
        set(ref, data, options = {}) {
          const current = store.get(ref.path) || {};
          store.set(ref.path, options.merge ? {...current, ...data} : data);
        },
        update(ref, data) {
          const current = store.get(ref.path) || {};
          store.set(ref.path, {...current, ...data});
        },
      };

      return callback(transaction);
    },
  };

  return {
    db,
    store,
    makeRef,
  };
}

test("buildCallEventMessagePayload materializes video call metadata", () => {
  const {makeRef} = createFakeFirestore();
  const startedAtMillis = Date.parse("2026-04-19T09:00:00Z");
  const endedAtMillis = Date.parse("2026-04-19T09:12:30Z");
  const sessionRef = makeRef("videoSessions/session-1");

  const payload = buildCallEventMessagePayload({
    sessionId: "session-1",
    sessionRef,
    sessionData: {
      createdAt: Timestamp.fromMillis(startedAtMillis - 60 * 1000),
      endedAt: Timestamp.fromMillis(endedAtMillis),
      sessionMetadata: {
        callConnectedAt: Timestamp.fromMillis(startedAtMillis),
      },
    },
  });

  assert.equal(payload.type, CONVERSATION_MESSAGE_TYPE_CALL_EVENT);
  assert.equal(payload.text, "Video call");
  assert.equal(payload.callKind, CALL_EVENT_KIND_VIDEO);
  assert.equal(payload.callOutcome, CALL_EVENT_OUTCOME_COMPLETED);
  assert.equal(payload.sessionRef.path, "videoSessions/session-1");
  assert.equal(payload.callDurationSeconds, 750);
  assert.equal(payload.callStartedAt.toMillis(), startedAtMillis);
  assert.equal(payload.callEndedAt.toMillis(), endedAtMillis);
  assert.equal(payload.createdAt.toMillis(), endedAtMillis);
});

test("startedAt alone is not a connected-call proof", () => {
  const startedAtMillis = Date.parse("2026-04-19T09:00:30Z");
  const sessionData = {
    status: "ended",
    studentId: "student",
    tutorId: "teacher",
    createdAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:00:00Z")),
    acceptedAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:00:01Z")),
    startedAt: Timestamp.fromMillis(startedAtMillis),
  };

  assert.equal(getConnectedCallStartMillis(sessionData), 0);
  assert.deepEqual(getUnlockEligibility(sessionData), {
    eligible: false,
    reason: "ignored_not_connected",
  });
});

test("buildConversationParticipantMap materializes query-friendly participants", () => {
  assert.deepEqual(
    buildConversationParticipantMap([" student ", "", "teacher", null]),
    {
      student: true,
      teacher: true,
    },
  );
});

test("startedAt-only sessions are not treated as verified connected calls", () => {
  const sessionData = {
    status: "ended",
    createdAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:00:00Z")),
    startedAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:00:10Z")),
    endedAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:05:00Z")),
    acceptedAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:00:00Z")),
    studentId: "student",
    tutorId: "teacher",
  };

  assert.equal(getConnectedCallStartMillis(sessionData), 0);
  assert.deepEqual(
    getConversationCallEventEligibility(sessionData, {
      callOutcome: CALL_EVENT_OUTCOME_COMPLETED,
    }),
    {
      eligible: false,
      reason: "ignored_not_connected",
    },
  );
});

test("ensureConversationCallEventForSession creates missed event for assigned unanswered call", async () => {
  const {db, store, makeRef} = createFakeFirestore({
    "videoSessions/session-missed": {
      status: "searching",
    },
  });
  const sessionRef = makeRef("videoSessions/session-missed");
  const eventMillis = Date.parse("2026-04-19T10:05:00Z");

  const result = await ensureConversationCallEventForSession({
    db,
    sessionId: "session-missed",
    sessionRef,
    callOutcome: CALL_EVENT_OUTCOME_MISSED,
    eventMillis,
    partnerId: "teacher",
    sessionData: {
      createdAt: Timestamp.fromMillis(Date.parse("2026-04-19T10:00:00Z")),
      status: "searching",
      studentId: "student",
      currentTutorId: "teacher",
    },
  });

  const messagePath =
    "conversations/student_teacher/messages/" +
    buildCallEventMessageId("session-missed", CALL_EVENT_OUTCOME_MISSED);
  assert.equal(result.status, "created");
  assert.equal(store.get("conversations/student_teacher").isUnlocked, true);
  assert.equal(
    store.get("conversations/student_teacher").lastMessageType,
    CONVERSATION_MESSAGE_TYPE_CALL_EVENT,
  );
  assert.equal(
    store.get("conversations/student_teacher").lastCallOutcome,
    CALL_EVENT_OUTCOME_MISSED,
  );
  assert.equal(store.get(messagePath).callOutcome, CALL_EVENT_OUTCOME_MISSED);
  assert.equal(store.get(messagePath).callerId, "student");
  assert.equal(store.get(messagePath).recipientId, "teacher");
});

test("ensureConversationCallEventForSession creates cancelled event for cancelled session", async () => {
  const {db, store, makeRef} = createFakeFirestore();
  const sessionRef = makeRef("videoSessions/session-cancelled");
  const eventMillis = Date.parse("2026-04-19T10:05:00Z");

  const result = await ensureConversationCallEventForSession({
    db,
    sessionId: "session-cancelled",
    sessionRef,
    eventMillis,
    sessionData: {
      createdAt: Timestamp.fromMillis(Date.parse("2026-04-19T10:00:00Z")),
      status: "cancelled",
      studentId: "student",
      currentTutorId: "teacher",
    },
  });

  const messagePath =
    "conversations/student_teacher/messages/" +
    buildCallEventMessageId("session-cancelled", CALL_EVENT_OUTCOME_CANCELLED);
  assert.equal(result.status, "created");
  assert.equal(store.get(messagePath).callOutcome, CALL_EVENT_OUTCOME_CANCELLED);
});

test("ensureCallEventMessageForProcessedConversation creates one deterministic call event", async () => {
  const {db, store, makeRef} = createFakeFirestore({
    "conversationUnlockEvents/session-1": {
      status: "processed",
    },
    "conversations/student_teacher": {
      pairId: "student_teacher",
      participantIds: ["student", "teacher"],
      isUnlocked: true,
    },
  });

  const eventRef = makeRef("conversationUnlockEvents/session-1");
  const conversationRef = makeRef("conversations/student_teacher");
  const sessionRef = makeRef("videoSessions/session-1");
  const sessionData = {
    createdAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:00:00Z")),
    endedAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:12:30Z")),
    status: "ended",
    studentId: "student",
    tutorId: "teacher",
    sessionMetadata: {
      callConnectedAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:00:30Z")),
    },
  };

  const firstResult = await ensureCallEventMessageForProcessedConversation({
    db,
    eventRef,
    sessionId: "session-1",
    sessionRef,
    sessionData,
    conversationRef,
  });
  const secondResult = await ensureCallEventMessageForProcessedConversation({
    db,
    eventRef,
    sessionId: "session-1",
    sessionRef,
    sessionData,
    conversationRef,
  });

  const messagePath =
    "conversations/student_teacher/messages/" + buildCallEventMessageId("session-1");
  assert.equal(firstResult.status, "created");
  assert.equal(secondResult.status, "already_exists");
  assert.ok(store.has(messagePath));
  assert.deepEqual(
    store.get("conversations/student_teacher").participantMap,
    {
      student: true,
      teacher: true,
    },
  );
  assert.equal(store.get(messagePath).type, CONVERSATION_MESSAGE_TYPE_CALL_EVENT);
  assert.equal(
    store.get("conversations/student_teacher").lastMessageType,
    CONVERSATION_MESSAGE_TYPE_CALL_EVENT,
  );
  assert.equal(
    store.get("conversations/student_teacher").lastCallOutcome,
    CALL_EVENT_OUTCOME_COMPLETED,
  );
});

test("ensureCallEventMessageForProcessedConversation rejects pair mismatch", async () => {
  const {db, store, makeRef} = createFakeFirestore({
    "conversationUnlockEvents/session-1": {
      status: "processed",
    },
    "conversations/other_teacher": {
      pairId: "other_teacher",
      participantIds: ["other", "teacher"],
      isUnlocked: true,
    },
  });

  const eventRef = makeRef("conversationUnlockEvents/session-1");
  const conversationRef = makeRef("conversations/other_teacher");
  const sessionRef = makeRef("videoSessions/session-1");

  const result = await ensureCallEventMessageForProcessedConversation({
    db,
    eventRef,
    sessionId: "session-1",
    sessionRef,
    sessionData: {
      createdAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:00:00Z")),
      endedAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:12:30Z")),
      status: "ended",
      studentId: "student",
      tutorId: "teacher",
      sessionMetadata: {
        callConnectedAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:00:30Z")),
      },
    },
    conversationRef,
  });

  assert.equal(result.status, "skipped_conversation_pair_mismatch");
  assert.equal(
    store.get("conversationUnlockEvents/session-1").callEventSkipReason,
    "conversation_pair_mismatch",
  );
  assert.equal(
    store.has(
      "conversations/other_teacher/messages/" + buildCallEventMessageId("session-1"),
    ),
    false,
  );
});

test("buildConversationSummaryUpdate materializes lastMessageType for call events", () => {
  const createdAt = Timestamp.fromMillis(Date.parse("2026-04-19T10:00:00Z"));
  const serverCreatedAt = Timestamp.fromMillis(Date.parse("2026-04-19T10:00:05Z"));

  const update = buildConversationSummaryUpdate({
    messageId: "call_session-1",
    messageData: {
      type: CONVERSATION_MESSAGE_TYPE_CALL_EVENT,
      text: "",
      callKind: CALL_EVENT_KIND_VIDEO,
      callOutcome: CALL_EVENT_OUTCOME_MISSED,
      callerId: "student",
      recipientId: "teacher",
      createdAt,
      senderId: null,
    },
    serverCreatedAt,
  });

  assert.equal(update.lastMessageType, CONVERSATION_MESSAGE_TYPE_CALL_EVENT);
  assert.equal(update.lastMessageText, "Missed video call");
  assert.equal(update.lastMessageSenderId, null);
  assert.equal(update.lastCallOutcome, CALL_EVENT_OUTCOME_MISSED);
  assert.equal(update.lastCallCallerId, "student");
  assert.equal(update.lastCallRecipientId, "teacher");
  assert.equal(update.lastMessageAt.toMillis(), createdAt.toMillis());
  assert.equal("lastUnreadMessageAt" in update, false);
  assert.equal("lastUnreadMessageSenderId" in update, false);
});

test("buildConversationSummaryUpdate keeps unread anchor for text messages", () => {
  const createdAt = Timestamp.fromMillis(Date.parse("2026-04-19T10:00:00Z"));

  const update = buildConversationSummaryUpdate({
    messageId: "message-1",
    messageData: {
      type: "text",
      text: "Hello",
      createdAt,
      senderId: "teacher",
    },
  });

  assert.equal(update.lastMessageType, "text");
  assert.equal(update.lastUnreadMessageAt.toMillis(), createdAt.toMillis());
  assert.equal(update.lastUnreadMessageSenderId, "teacher");
});

test("maybeWriteCallEventForProcessedOutcome skips pre-rollout sessions", async () => {
  const {db, store, makeRef} = createFakeFirestore({
    "conversationUnlockEvents/session-legacy": {
      status: "processed",
    },
    "conversations/student_teacher": {
      isUnlocked: true,
    },
  });

  const eventRef = makeRef("conversationUnlockEvents/session-legacy");
  const sessionRef = makeRef("videoSessions/session-legacy");
  const conversationRef = makeRef("conversations/student_teacher");

  const result = await maybeWriteCallEventForProcessedOutcome({
    db,
    eventRef,
    sessionId: "session-legacy",
    sessionRef,
    sessionData: {
      createdAt: Timestamp.fromMillis(Date.parse("2026-04-18T09:00:00Z")),
      endedAt: Timestamp.fromMillis(Date.parse("2026-04-18T09:05:00Z")),
      status: "ended",
      studentId: "student",
      tutorId: "teacher",
      sessionMetadata: {
        callConnectedAt: Timestamp.fromMillis(Date.parse("2026-04-18T09:00:10Z")),
      },
    },
    conversationRef,
  });

  assert.equal(result.status, "skipped_pre_call_event_rollout");
  assert.equal(
    store.get("conversationUnlockEvents/session-legacy").callEventSkipReason,
    "ignored_pre_call_event_rollout",
  );
  assert.equal(
    store.has(
      "conversations/student_teacher/messages/" +
        buildCallEventMessageId("session-legacy"),
    ),
    false,
  );
});

test("maybeWriteCallEventForProcessedOutcome swallows call-event writer failures", async () => {
  const eventWrites = [];
  const eventRef = {
    async set(data) {
      eventWrites.push(data);
    },
  };

  const result = await maybeWriteCallEventForProcessedOutcome({
    db: {
      async runTransaction() {
        throw new Error("boom");
      },
    },
    eventRef,
    sessionId: "session-2",
    sessionRef: {path: "videoSessions/session-2"},
    sessionData: {
      createdAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:00:00Z")),
      endedAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:05:00Z")),
      status: "ended",
      studentId: "student",
      tutorId: "teacher",
      sessionMetadata: {
        callConnectedAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:00:10Z")),
      },
    },
    conversationRef: {
      path: "conversations/student_teacher",
      collection() {
        return {
          doc(id) {
            return {path: `conversations/student_teacher/messages/${id}`};
          },
        };
      },
    },
  });

  assert.equal(result.status, "failed");
  assert.equal(eventWrites.length, 1);
  assert.equal(eventWrites[0].callEventErrorMessage, "boom");
});
