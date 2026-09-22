const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __private__: {
    buildChatMessageReportId,
    executeReportEventChatMessageTransaction,
    normalizeReportEventChatMessagePayload,
    reportEventChatMessageHandler,
  },
} = require("./report_event_chat_message");

const fixedNow = new Date("2026-06-16T10:00:00.000Z");
const fixedTimestamp = {
  toMillis: () => fixedNow.getTime(),
  toDate: () => fixedNow,
};
const oldTimestamp = {
  toMillis: () => Date.parse("2026-06-15T10:00:00.000Z"),
  toDate: () => new Date("2026-06-15T10:00:00.000Z"),
};

function assertHttpsError(fn, code, domainCode, field, reason) {
  assert.throws(fn, (err) => {
    assert.equal(err.code, code);
    assert.equal(err.details?.domainCode, domainCode);
    if (field) {
      assert.equal(err.details?.field, field);
    }
    if (reason) {
      assert.equal(err.details?.reason, reason);
    }
    return true;
  });
}

async function assertRejectsHttpsError(promiseFactory, code, domainCode) {
  await assert.rejects(promiseFactory, (err) => {
    assert.equal(err.code, code);
    assert.equal(err.details?.domainCode, domainCode);
    return true;
  });
}

function createFakeFirestore(seed = {}) {
  const store = new Map(Object.entries(seed));
  const reads = [];
  const writes = [];

  const makeRef = (path) => ({
    path,
    id: path.split("/").pop(),
    collection(name) {
      return makeCollection(`${path}/${name}`);
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

  const makeCollection = (path) => ({
    doc(id) {
      return makeRef(`${path}/${id}`);
    },
  });

  const db = {
    collection(name) {
      return makeCollection(name);
    },
    async runTransaction(callback) {
      let hasWrites = false;
      const pendingWrites = [];
      const tx = {
        async get(ref) {
          if (hasWrites) {
            throw new Error("Firestore transactions require reads first");
          }
          reads.push(ref.path);
          return ref.get();
        },
        create(ref, data) {
          hasWrites = true;
          if (store.has(ref.path)) {
            throw new Error(`Document already exists: ${ref.path}`);
          }
          pendingWrites.push({type: "create", path: ref.path, data});
        },
      };
      const result = await callback(tx);
      for (const write of pendingWrites) {
        writes.push(write);
        store.set(write.path, write.data);
      }
      return result;
    },
  };

  return {db, reads, store, writes};
}

function activeEvent(overrides = {}) {
  return {
    organizerId: "organizer-1",
    chatId: "event-1",
    title: "Conversation club",
    status: "active",
    canceledAt: null,
    startsAt: oldTimestamp,
    countryCode: "RU",
    cityKey: "moscow",
    ...overrides,
  };
}

function eventChat(overrides = {}) {
  return {
    eventId: "event-1",
    readAccessUserIds: ["organizer-1", "student-1", "student-2"],
    createdAt: oldTimestamp,
    updatedAt: oldTimestamp,
    ...overrides,
  };
}

function participant(overrides = {}) {
  return {
    userId: "student-1",
    displayName: "Student",
    photoUrl: null,
    role: "participant",
    status: "active",
    joinedAt: oldTimestamp,
    leftAt: null,
    createdAt: oldTimestamp,
    updatedAt: oldTimestamp,
    ...overrides,
  };
}

function message(overrides = {}) {
  return {
    senderId: "student-2",
    senderDisplayName: "Marco Rossi",
    senderPhotoUrl: "https://example.com/marco.png",
    text: "Suspicious message",
    createdAt: oldTimestamp,
    deletedAt: null,
    ...overrides,
  };
}

function validSeed(overrides = {}) {
  return {
    "events/event-1": activeEvent(overrides.event),
    "eventChats/event-1": eventChat(overrides.chat),
    "events/event-1/participants/student-1": participant(
        overrides.participant,
    ),
    "eventChats/event-1/messages/message-1": message(overrides.message),
  };
}

test("normalizeReportEventChatMessagePayload rejects invalid payloads", () => {
  for (const payload of [null, [], "bad"]) {
    assertHttpsError(
        () => normalizeReportEventChatMessagePayload(payload),
        "invalid-argument",
        "invalid_report_event_chat_message_request",
        "payload",
        "invalid_type",
    );
  }
  assertHttpsError(
      () => normalizeReportEventChatMessagePayload({
        eventId: "event-1",
        messageId: "message-1",
        reasonCode: "spam",
        senderId: "spoof",
      }),
      "invalid-argument",
      "invalid_report_event_chat_message_request",
      "senderId",
      "unknown_key",
  );
  assertHttpsError(
      () => normalizeReportEventChatMessagePayload({
        eventId: "event-1",
        reasonCode: "spam",
      }),
      "invalid-argument",
      "invalid_report_event_chat_message_request",
      "messageId",
      "missing",
  );
  for (const [field, value] of [
    ["eventId", "events/event-1"],
    ["eventId", "__reserved__"],
    ["messageId", "messages/message-1"],
    ["reasonCode", "harassment"],
    ["details", "a".repeat(501)],
  ]) {
    assertHttpsError(
        () => normalizeReportEventChatMessagePayload({
          eventId: "event-1",
          messageId: "message-1",
          reasonCode: "spam",
          [field]: value,
        }),
        "invalid-argument",
        "invalid_report_event_chat_message_request",
        field,
  );
  }

  assert.deepEqual(
      normalizeReportEventChatMessagePayload({
        eventId: " event-1 ",
        messageId: " message-1 ",
        reasonCode: " UNSAFE ",
        details: "  опасное сообщение  ",
      }),
      {
        eventId: "event-1",
        messageId: "message-1",
        reasonCode: "unsafe",
        details: "опасное сообщение",
      },
  );
});

test("buildChatMessageReportId keeps id segment boundaries unambiguous", () => {
  assert.notEqual(
      buildChatMessageReportId({
        reporterId: "student-1",
        eventId: "event:1",
        messageId: "message",
      }),
      buildChatMessageReportId({
        reporterId: "student-1",
        eventId: "event",
        messageId: "1:message",
      }),
  );
});

test("executeReportEventChatMessageTransaction creates a private report",
    async () => {
      const {db, store, writes} = createFakeFirestore(validSeed());
      const reportId = buildChatMessageReportId({
        eventId: "event-1",
        messageId: "message-1",
        reporterId: "student-1",
      });

      const result = await executeReportEventChatMessageTransaction({
        db,
        eventId: "event-1",
        messageId: "message-1",
        reporterId: "student-1",
        reasonCode: "unsafe",
        details: "Looks unsafe",
        reportDate: fixedNow,
        reportTimestamp: fixedTimestamp,
      });

      assert.deepEqual(result, {
        eventId: "event-1",
        messageId: "message-1",
        reportId,
        status: "submitted",
        reportedAt: "2026-06-16T10:00:00.000Z",
      });
      assert.equal(writes.length, 1);
      assert.equal(writes[0].path, `chatMessageReports/${reportId}`);
      const report = store.get(`chatMessageReports/${reportId}`);
      assert.equal(report.eventId, "event-1");
      assert.equal(report.chatId, "event-1");
      assert.equal(report.messageId, "message-1");
      assert.equal(report.reporterId, "student-1");
      assert.equal(report.senderId, "student-2");
      assert.equal(report.senderRef.path, "users/student-2");
      assert.equal(report.reasonCode, "unsafe");
      assert.equal(report.details, "Looks unsafe");
      assert.equal(report.status, "open");
      assert.equal(report.createdAt, fixedTimestamp);
      assert.deepEqual(report.eventSnapshot, {
        title: "Conversation club",
        status: "active",
        startsAt: oldTimestamp,
        countryCode: "RU",
        cityKey: "moscow",
        organizerId: "organizer-1",
      });
      assert.deepEqual(report.messageSnapshot, {
        senderId: "student-2",
        senderDisplayName: "Marco Rossi",
        text: "Suspicious message",
        createdAt: oldTimestamp,
      });
    });

test("executeReportEventChatMessageTransaction is idempotent", async () => {
  const reportId = buildChatMessageReportId({
    eventId: "event-1",
    messageId: "message-1",
    reporterId: "student-1",
  });
  const existingReport = {
    status: "open",
    createdAt: oldTimestamp,
  };
  const {db, store, writes} = createFakeFirestore({
    ...validSeed(),
    [`chatMessageReports/${reportId}`]: existingReport,
  });

  const result = await executeReportEventChatMessageTransaction({
    db,
    eventId: "event-1",
    messageId: "message-1",
    reporterId: "student-1",
    reasonCode: "spam",
    reportDate: fixedNow,
    reportTimestamp: fixedTimestamp,
  });

  assert.deepEqual(result, {
    eventId: "event-1",
    messageId: "message-1",
    reportId,
    status: "already_submitted",
    reportedAt: "2026-06-15T10:00:00.000Z",
  });
  assert.equal(writes.length, 0);
  assert.equal(store.get(`chatMessageReports/${reportId}`), existingReport);

  const staleState = createFakeFirestore({
    ...validSeed({
      message: {deletedAt: fixedTimestamp},
      participant: {status: "left", leftAt: oldTimestamp},
    }),
    [`chatMessageReports/${reportId}`]: existingReport,
  });

  const staleResult = await executeReportEventChatMessageTransaction({
    db: staleState.db,
    eventId: "event-1",
    messageId: "message-1",
    reporterId: "student-1",
    reasonCode: "unsafe",
    reportDate: fixedNow,
    reportTimestamp: fixedTimestamp,
  });

  assert.equal(staleResult.status, "already_submitted");
  assert.equal(staleState.writes.length, 0);
});

test("executeReportEventChatMessageTransaction allows canceled frozen readers",
    async () => {
      const {db} = createFakeFirestore(validSeed({
        event: {
          status: "canceled",
          canceledAt: fixedTimestamp,
        },
        participant: {
          status: "left",
          leftAt: oldTimestamp,
        },
      }));

      const result = await executeReportEventChatMessageTransaction({
        db,
        eventId: "event-1",
        messageId: "message-1",
        reporterId: "student-1",
        reasonCode: "offensive",
        reportDate: fixedNow,
        reportTimestamp: fixedTimestamp,
      });

      assert.equal(result.status, "submitted");
    });

test("executeReportEventChatMessageTransaction rejects invalid report states",
    async () => {
      const cases = [
        {
          name: "self report",
          seed: validSeed({message: {senderId: "student-1"}}),
          code: "failed-precondition",
          domainCode: "event_chat_message_report_self",
        },
        {
          name: "deleted message",
          seed: validSeed({message: {deletedAt: fixedTimestamp}}),
          code: "failed-precondition",
          domainCode: "event_chat_message_not_reportable",
        },
        {
          name: "missing message",
          seed: (() => {
            const seed = validSeed();
            delete seed["eventChats/event-1/messages/message-1"];
            return seed;
          })(),
          code: "not-found",
          domainCode: "event_chat_message_not_found",
        },
        {
          name: "left active participant",
          seed: validSeed({
            participant: {status: "left", leftAt: oldTimestamp},
          }),
          code: "failed-precondition",
          domainCode: "not_active_participant",
        },
        {
          name: "canceled chat without frozen access",
          seed: validSeed({
            event: {status: "canceled", canceledAt: fixedTimestamp},
            chat: {readAccessUserIds: ["organizer-1"]},
          }),
          code: "permission-denied",
          domainCode: "event_chat_access_denied",
        },
      ];

      for (const currentCase of cases) {
        const {db, writes} = createFakeFirestore(currentCase.seed);
        await assertRejectsHttpsError(
            () => executeReportEventChatMessageTransaction({
              db,
              eventId: "event-1",
              messageId: "message-1",
              reporterId: "student-1",
              reasonCode: "spam",
              reportDate: fixedNow,
              reportTimestamp: fixedTimestamp,
            }),
            currentCase.code,
            currentCase.domainCode,
        );
        assert.equal(writes.length, 0, currentCase.name);
      }
    });

test("reportEventChatMessageHandler rejects missing auth", async () => {
  await assertRejectsHttpsError(
      () => reportEventChatMessageHandler(
          {
            eventId: "event-1",
            messageId: "message-1",
            reasonCode: "spam",
          },
          {},
          {
            db: createFakeFirestore(validSeed()).db,
            reportDate: fixedNow,
            reportTimestamp: fixedTimestamp,
          },
      ),
      "unauthenticated",
      "auth_required",
  );
});
