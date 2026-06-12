const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const {Timestamp} = require("firebase-admin/firestore");

const {
  CALL_EVENT_OUTCOME_COMPLETED,
  buildCallEventMessageId,
} = require("./chats_shared");

const {
  __private__: {
    assertPersistEligibility,
    buildPersistCallChatMessages,
    normalizeCallChatMessages,
    persistCallChatForUser,
  },
} = require("./persist_call_chat");

if (!admin.apps.length) {
  admin.initializeApp({projectId: "demo-smalltalk"});
}

function createFakeFirestore(seed = {}, options = {}) {
  const store = new Map(Object.entries(seed));
  const enforceReadsBeforeWrites = options.enforceReadsBeforeWrites === true;

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
      let hasWrites = false;
      const transaction = {
        async get(ref) {
          if (enforceReadsBeforeWrites && hasWrites) {
            throw new Error(
              "Firestore transactions require all reads before writes",
            );
          }
          return ref.get();
        },
        set(ref, data, options = {}) {
          hasWrites = true;
          const current = store.get(ref.path) || {};
          store.set(ref.path, options.merge ? {...current, ...data} : data);
        },
        update(ref, data) {
          hasWrites = true;
          const current = store.get(ref.path) || {};
          store.set(ref.path, {...current, ...data});
        },
      };
      return callback(transaction);
    },
  };

  return {db, store, makeRef};
}

function qualifyingSessionData() {
  return {
    status: "ended",
    createdAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:00:00Z")),
    startedAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:00:20Z")),
    endedAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:05:00Z")),
    studentId: "student",
    tutorId: "teacher",
    sessionMetadata: {
      callConnectedAt: Timestamp.fromMillis(Date.parse("2026-04-19T09:00:30Z")),
    },
  };
}

test("normalizeCallChatMessages validates and sanitizes client messages", () => {
  const messages = normalizeCallChatMessages([
    {
      clientId: "client/one",
      text: "  hello  ",
      sentAtMs: Date.parse("2026-04-19T09:01:00Z"),
    },
    {
      clientId: "empty",
      text: " ",
      sentAtMs: Date.parse("2026-04-19T09:02:00Z"),
    },
  ]);

  assert.equal(messages.length, 1);
  assert.equal(messages[0].clientId, "client_one");
  assert.equal(messages[0].text, "hello");
});

test("assertPersistEligibility rejects non-participants", () => {
  assert.throws(
    () =>
      assertPersistEligibility({
        sessionData: qualifyingSessionData(),
        userId: "stranger",
        nowMillis: Date.parse("2026-04-19T09:05:10Z"),
      }),
    /not a participant/,
  );
});

test("assertPersistEligibility rejects startedAt-only sessions", () => {
  const sessionData = qualifyingSessionData();
  delete sessionData.sessionMetadata.callConnectedAt;

  assert.throws(
    () =>
      assertPersistEligibility({
        sessionData,
        userId: "student",
        nowMillis: Date.parse("2026-04-19T09:05:10Z"),
      }),
    /not eligible/,
  );
});

test("buildPersistCallChatMessages keeps text before call event timestamp", () => {
  const {makeRef} = createFakeFirestore();
  const sessionRef = makeRef("videoSessions/session-1");
  const userRef = makeRef("users/student");
  const endedAtMillis = Date.parse("2026-04-19T09:05:00Z");

  const messages = buildPersistCallChatMessages({
    sessionId: "session-1",
    sessionRef,
    sessionData: qualifyingSessionData(),
    userId: "student",
    userRef,
    endedAtMillis,
    messages: [
      {
        clientId: "m1",
        text: "late message",
        sentAtMs: Date.parse("2026-04-19T09:06:00Z"),
      },
    ],
  });

  assert.equal(messages[0].messageId, "incall_session-1_student_m1");
  assert.equal(messages[0].payload.type, "text");
  assert.equal(messages[0].payload.senderId, "student");
  assert.equal(messages[0].payload.inCallSessionRef.path, "videoSessions/session-1");
  assert.equal(messages[0].payload.createdAt.toMillis(), endedAtMillis - 1);
});

test("persistCallChatForUser upserts conversation and is idempotent", async () => {
  const sessionData = qualifyingSessionData();
  const {db, store} = createFakeFirestore({
    "videoSessions/session-1": sessionData,
  });
  const messages = normalizeCallChatMessages([
    {
      clientId: "m1",
      text: "hello",
      sentAtMs: Date.parse("2026-04-19T09:01:00Z"),
    },
  ]);

  const first = await persistCallChatForUser({
    db,
    userId: "student",
    sessionId: "session-1",
    messages,
    nowMillis: Date.parse("2026-04-19T09:05:10Z"),
  });
  const second = await persistCallChatForUser({
    db,
    userId: "student",
    sessionId: "session-1",
    messages,
    nowMillis: Date.parse("2026-04-19T09:05:20Z"),
  });

  assert.equal(first.status, "persisted");
  assert.equal(first.written, 1);
  assert.equal(first.callEventStatus, "created");
  assert.equal(second.status, "already_persisted");
  assert.equal(second.callEventStatus, "already_exists");
  assert.equal(second.skipped, 1);
  assert.equal(store.get("conversations/student_teacher").isUnlocked, true);
  assert.deepEqual(
    store.get("conversations/student_teacher").participantMap,
    {
      student: true,
      teacher: true,
    },
  );
  assert.equal(
    store.get("conversations/student_teacher").lastMessageType,
    "call_event",
  );
  assert.equal(
    store.get("conversations/student_teacher").lastCallOutcome,
    CALL_EVENT_OUTCOME_COMPLETED,
  );
  assert.equal(
    store.get(
      "conversations/student_teacher/messages/" +
        buildCallEventMessageId("session-1", CALL_EVENT_OUTCOME_COMPLETED),
    ).callOutcome,
    CALL_EVENT_OUTCOME_COMPLETED,
  );
  assert.equal(
    store.get("conversations/student_teacher/messages/incall_session-1_student_m1").text,
    "hello",
  );
});

test(
  "persistCallChatForUser writes call event and in-call text with Firestore ordering",
  async () => {
    const sessionData = qualifyingSessionData();
    const {db, store} = createFakeFirestore(
      {
        "videoSessions/session-1": sessionData,
        "conversations/student_teacher": {
          pairId: "student_teacher",
          participantIds: ["student", "teacher"],
          isUnlocked: true,
        },
      },
      {enforceReadsBeforeWrites: true},
    );
    const messages = normalizeCallChatMessages([
      {
        clientId: "m1",
        text: "hello after call",
        sentAtMs: Date.parse("2026-04-19T09:01:00Z"),
      },
    ]);

    const result = await persistCallChatForUser({
      db,
      userId: "student",
      sessionId: "session-1",
      messages,
      nowMillis: Date.parse("2026-04-19T09:05:10Z"),
    });

    const callEventPath =
      "conversations/student_teacher/messages/" +
      buildCallEventMessageId("session-1", CALL_EVENT_OUTCOME_COMPLETED);

    assert.equal(result.status, "persisted");
    assert.equal(result.callEventStatus, "created");
    assert.equal(
      store.get(callEventPath).callOutcome,
      CALL_EVENT_OUTCOME_COMPLETED,
    );
    assert.equal(
      store.get(
        "conversations/student_teacher/messages/incall_session-1_student_m1",
      ).text,
      "hello after call",
    );
  },
);

test("persistCallChatForUser creates call event even without in-call text", async () => {
  const {db, store} = createFakeFirestore({
    "videoSessions/session-1": qualifyingSessionData(),
  });

  const result = await persistCallChatForUser({
    db,
    userId: "student",
    sessionId: "session-1",
    messages: [],
    nowMillis: Date.parse("2026-04-19T09:05:10Z"),
  });

  assert.equal(result.status, "call_event_persisted");
  assert.equal(result.written, 0);
  assert.equal(
    store.get("conversations/student_teacher").lastMessageType,
    "call_event",
  );
  assert.equal(
    store.has(
      "conversations/student_teacher/messages/" +
        buildCallEventMessageId("session-1", CALL_EVENT_OUTCOME_COMPLETED),
    ),
    true,
  );
});
