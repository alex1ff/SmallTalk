const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __private__: {
    getEventChatAccessState,
    normalizeGetEventChatAccessStatePayload,
  },
} = require("./get_event_chat_access_state");

const oldTimestamp = {
  toMillis: () => Date.parse("2026-06-15T10:00:00.000Z"),
  toDate: () => new Date("2026-06-15T10:00:00.000Z"),
};
const canceledTimestamp = {
  toMillis: () => Date.parse("2026-06-16T10:00:00.000Z"),
  toDate: () => new Date("2026-06-16T10:00:00.000Z"),
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

  const makeRef = (path) => ({
    path,
    id: path.split("/").pop(),
    collection(name) {
      return makeCollection(`${path}/${name}`);
    },
    async get() {
      reads.push(path);
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

  return {
    db: {
      collection(name) {
        return makeCollection(name);
      },
    },
    reads,
    store,
  };
}

function activeEvent(overrides = {}) {
  return {
    organizerId: "organizer",
    chatId: "event-1",
    status: "active",
    canceledAt: null,
    participantsCount: 2,
    capacity: 3,
    updatedAt: oldTimestamp,
    ...overrides,
  };
}

function canceledEvent(overrides = {}) {
  return activeEvent({
    status: "canceled",
    canceledAt: canceledTimestamp,
    ...overrides,
  });
}

function eventChat(overrides = {}) {
  return {
    eventId: "event-1",
    readAccessUserIds: ["organizer", "uid"],
    createdAt: oldTimestamp,
    updatedAt: oldTimestamp,
    ...overrides,
  };
}

function participant(overrides = {}) {
  return {
    userId: "uid",
    displayName: "Marco",
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

function validSeed(overrides = {}) {
  return {
    "events/event-1": activeEvent(overrides.event),
    "eventChats/event-1": eventChat(overrides.chat),
    "events/event-1/participants/uid": participant(overrides.participant),
  };
}

test("normalizeGetEventChatAccessStatePayload rejects unknown and missing keys", () => {
  for (const payload of [null, [], "bad"]) {
    assertHttpsError(
        () => normalizeGetEventChatAccessStatePayload(payload),
        "invalid-argument",
        "invalid_event_chat_access_request",
        "payload",
        "invalid_type",
    );
  }
  assertHttpsError(
      () => normalizeGetEventChatAccessStatePayload({
        eventId: "event-1",
        status: "canceled",
      }),
      "invalid-argument",
      "invalid_event_chat_access_request",
      "status",
      "unknown_key",
  );
  assertHttpsError(
      () => normalizeGetEventChatAccessStatePayload({}),
      "invalid-argument",
      "invalid_event_chat_access_request",
      "eventId",
      "missing",
  );
});

test("normalizeGetEventChatAccessStatePayload validates event id", () => {
  const invalidIds = [
    "",
    " ",
    "events/event-1",
    ".",
    "..",
    "x".repeat(1501),
  ];
  for (const eventId of invalidIds) {
    assertHttpsError(
        () => normalizeGetEventChatAccessStatePayload({eventId}),
        "invalid-argument",
        "invalid_event_chat_access_request",
        "eventId",
        "invalid_format",
    );
  }
  assert.deepEqual(
      normalizeGetEventChatAccessStatePayload({eventId: " event-1 "}),
      {eventId: "event-1"},
  );
});

test("getEventChatAccessState returns writable active participant state", async () => {
  const {db, reads} = createFakeFirestore(validSeed());

  const response = await getEventChatAccessState({
    db,
    uid: "uid",
    payload: {eventId: "event-1"},
  });

  assert.deepEqual(response, {
    eventId: "event-1",
    status: "active",
    readOnly: false,
  });
  assert.deepEqual(reads, [
    "events/event-1",
    "eventChats/event-1",
    "events/event-1/participants/uid",
  ]);
});

test("getEventChatAccessState returns read-only canceled reader state", async () => {
  const {db} = createFakeFirestore({
    ...validSeed(),
    "events/event-1": canceledEvent(),
    "events/event-1/participants/uid": participant({
      status: "left",
      leftAt: canceledTimestamp,
    }),
  });

  const response = await getEventChatAccessState({
    db,
    uid: "uid",
    payload: {eventId: "event-1"},
  });

  assert.deepEqual(response, {
    eventId: "event-1",
    status: "canceled",
    readOnly: true,
  });
});

test("getEventChatAccessState fails closed for malformed canceled timestamps", async () => {
  const malformedCanceledAtValues = [
    undefined,
    null,
    "2026-06-16T10:00:00.000Z",
    {toMillis: () => Number.NaN},
    {toMillis: () => {
      throw new Error("bad timestamp");
    }},
  ];

  for (const canceledAt of malformedCanceledAtValues) {
    await assertRejectsHttpsError(
        () => getEventChatAccessState({
          db: createFakeFirestore({
            ...validSeed(),
            "events/event-1": canceledEvent({canceledAt}),
          }).db,
          uid: "uid",
          payload: {eventId: "event-1"},
        }),
        "failed-precondition",
        "event_chat_metadata_invalid",
    );
  }
});

test("getEventChatAccessState denies active nonparticipants and left users", async () => {
  for (const seed of [
    {
      "events/event-1": activeEvent(),
      "eventChats/event-1": eventChat(),
    },
    {
      ...validSeed({
        participant: {
          status: "left",
          leftAt: canceledTimestamp,
        },
      }),
    },
  ]) {
    await assertRejectsHttpsError(
        () => getEventChatAccessState({
          db: createFakeFirestore(seed).db,
          uid: "uid",
          payload: {eventId: "event-1"},
        }),
        "failed-precondition",
        "not_active_participant",
    );
  }
});

test("getEventChatAccessState denies canceled users outside frozen access", async () => {
  const {db} = createFakeFirestore({
    ...validSeed(),
    "events/event-1": canceledEvent(),
    "eventChats/event-1": eventChat({readAccessUserIds: ["organizer"]}),
  });

  await assertRejectsHttpsError(
      () => getEventChatAccessState({
        db,
        uid: "uid",
        payload: {eventId: "event-1"},
      }),
      "permission-denied",
      "event_chat_access_denied",
  );
});

test("getEventChatAccessState fails closed for missing or mismatched metadata", async () => {
  for (const [seed, code, domainCode] of [
    [
      {
        "eventChats/event-1": eventChat(),
        "events/event-1/participants/uid": participant(),
      },
      "not-found",
      "event_not_found",
    ],
    [
      {
        "events/event-1": activeEvent(),
        "events/event-1/participants/uid": participant(),
      },
      "failed-precondition",
      "event_chat_metadata_invalid",
    ],
    [
      {
        ...validSeed(),
        "events/event-1": activeEvent({chatId: "other-chat"}),
      },
      "failed-precondition",
      "event_chat_metadata_invalid",
    ],
    [
      {
        ...validSeed(),
        "eventChats/event-1": eventChat({eventId: "other-event"}),
      },
      "failed-precondition",
      "event_chat_metadata_invalid",
    ],
    [
      {
        ...validSeed(),
        "eventChats/event-1": eventChat({status: "active"}),
      },
      "failed-precondition",
      "event_chat_metadata_invalid",
    ],
    [
      {
        ...validSeed(),
        "eventChats/event-1": eventChat({canceledAt: null}),
      },
      "failed-precondition",
      "event_chat_metadata_invalid",
    ],
    [
      {
        ...validSeed(),
        "eventChats/event-1": (() => {
          const chatData = eventChat();
          delete chatData.createdAt;
          return chatData;
        })(),
      },
      "failed-precondition",
      "event_chat_metadata_invalid",
    ],
    [
      {
        ...validSeed(),
        "eventChats/event-1": (() => {
          const chatData = eventChat();
          delete chatData.updatedAt;
          return chatData;
        })(),
      },
      "failed-precondition",
      "event_chat_metadata_invalid",
    ],
    [
      {
        ...validSeed(),
        "eventChats/event-1": eventChat({
          createdAt: "2026-06-16T10:00:00.000Z",
        }),
      },
      "failed-precondition",
      "event_chat_metadata_invalid",
    ],
    [
      {
        ...validSeed(),
        "eventChats/event-1": eventChat({
          updatedAt: "2026-06-16T10:00:00.000Z",
        }),
      },
      "failed-precondition",
      "event_chat_metadata_invalid",
    ],
  ]) {
    await assertRejectsHttpsError(
        () => getEventChatAccessState({
          db: createFakeFirestore(seed).db,
          uid: "uid",
          payload: {eventId: "event-1"},
        }),
        code,
        domainCode,
    );
  }
});
