const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __private__: {
    executeSendEventChatMessageTransaction,
    normalizeSendEventChatMessagePayload,
  },
} = require("./send_event_chat_message");

const fixedNow = new Date("2026-06-16T10:00:00.000Z");
const fixedTimestamp = {
  toMillis: () => fixedNow.getTime(),
  toDate: () => fixedNow,
};
const oldTimestamp = {
  toMillis: () => Date.parse("2026-06-15T10:00:00.000Z"),
  toDate: () => new Date("2026-06-15T10:00:00.000Z"),
};
const pastStartsAt = {
  toMillis: () => Date.parse("2026-06-16T09:00:00.000Z"),
  toDate: () => new Date("2026-06-16T09:00:00.000Z"),
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

function createFakeFirestore(seed = {}, options = {}) {
  const store = new Map(Object.entries(seed));
  const reads = [];
  const writes = [];
  let autoId = 0;
  let attempts = 0;

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
      const docId = id || `message-${++autoId}`;
      return makeRef(`${path}/${docId}`);
    },
  });

  const db = {
    collection(name) {
      return makeCollection(name);
    },
    async runTransaction(callback) {
      while (true) {
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
        attempts += 1;
        const result = await callback(tx);
        if (typeof options.beforeCommit === "function") {
          options.beforeCommit({attempt: attempts, pendingWrites, store});
        }
        if (attempts <= (options.retryBeforeCommitCount || 0)) {
          continue;
        }
        for (const write of pendingWrites) {
          writes.push(write);
          store.set(write.path, write.data);
        }
        return result;
      }
    },
  };

  return {db, reads, store, writes, get attempts() {
    return attempts;
  }};
}

function activeEvent(overrides = {}) {
  return {
    organizerId: "organizer",
    chatId: "event-1",
    status: "active",
    canceledAt: null,
    startsAt: pastStartsAt,
    participantsCount: 2,
    capacity: 3,
    updatedAt: oldTimestamp,
    ...overrides,
  };
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
    photoUrl: "https://example.com/member.png",
    role: "participant",
    status: "active",
    joinedAt: oldTimestamp,
    leftAt: null,
    createdAt: oldTimestamp,
    updatedAt: oldTimestamp,
    ...overrides,
  };
}

function userProfile(overrides = {}) {
  return {
    display_name: "User Fallback",
    photo_url: "https://example.com/profile.png",
    ...overrides,
  };
}

function validSeed(overrides = {}) {
  return {
    "events/event-1": activeEvent(overrides.event),
    "eventChats/event-1": eventChat(overrides.chat),
    "events/event-1/participants/uid": participant(overrides.participant),
    "users/uid": userProfile(overrides.user),
  };
}

test("normalizeSendEventChatMessagePayload rejects unknown and missing keys", () => {
  for (const payload of [null, [], "bad"]) {
    assertHttpsError(
        () => normalizeSendEventChatMessagePayload(payload),
        "invalid-argument",
        "invalid_event_chat_message_request",
        "payload",
        "invalid_type",
    );
  }
  assertHttpsError(
      () => normalizeSendEventChatMessagePayload({
        eventId: "event-1",
        text: "Hello",
        senderId: "attacker",
      }),
      "invalid-argument",
      "invalid_event_chat_message_request",
      "senderId",
      "unknown_key",
  );
  for (const key of [
    "createdAt",
    "deletedAt",
    "deletedBy",
    "deletedText",
    "editedAt",
    "isDeleted",
    "messageId",
    "operation",
    "action",
    "senderDisplayName",
    "senderPhotoUrl",
    "updatedAt",
  ]) {
    assertHttpsError(
        () => normalizeSendEventChatMessagePayload({
          eventId: "event-1",
          text: "Hello",
          [key]: "spoof",
        }),
        "invalid-argument",
        "invalid_event_chat_message_request",
        key,
        "unknown_key",
    );
  }
  assertHttpsError(
      () => normalizeSendEventChatMessagePayload({eventId: "event-1"}),
      "invalid-argument",
      "invalid_event_chat_message_request",
      "text",
      "missing",
  );
});

test("normalizeSendEventChatMessagePayload validates event id and text", () => {
  for (const eventId of ["events/event-1", ".", "..", "x".repeat(1501)]) {
    assertHttpsError(
        () => normalizeSendEventChatMessagePayload({
          eventId,
          text: "Hello",
        }),
        "invalid-argument",
        "invalid_event_chat_message_request",
        "eventId",
        "invalid_format",
    );
  }
  assertHttpsError(
      () => normalizeSendEventChatMessagePayload({
        eventId: "event-1",
        text: " \n\t ",
      }),
      "invalid-argument",
      "invalid_event_chat_message_request",
      "text",
      "missing",
  );
  assertHttpsError(
      () => normalizeSendEventChatMessagePayload({
        eventId: "event-1",
        text: "a".repeat(1001),
      }),
      "invalid-argument",
      "invalid_event_chat_message_request",
      "text",
      "too_long",
  );

  assert.deepEqual(
      normalizeSendEventChatMessagePayload({
        eventId: " event-1 ",
        text: "  Line 1\r\nLine 2\rLine 3\n\n\nLine 4  ",
      }),
      {
        eventId: "event-1",
        text: "Line 1\nLine 2\nLine 3\n\nLine 4",
      },
  );
  assert.equal(
      normalizeSendEventChatMessagePayload({
        eventId: "event-1",
        text: "a".repeat(1000),
      }).text.length,
      1000,
  );
});

test("executeSendEventChatMessageTransaction creates message for active participant", async () => {
  const {db, reads, store, writes} = createFakeFirestore(validSeed());

  const response = await executeSendEventChatMessageTransaction({
    db,
    uid: "uid",
    messageDate: fixedNow,
    messageTimestamp: fixedTimestamp,
    payload: {eventId: "event-1", text: "Hello event"},
  });

  assert.deepEqual(response, {
    eventId: "event-1",
    messageId: "message-1",
    createdAt: "2026-06-16T10:00:00.000Z",
  });
  assert.deepEqual(reads, [
    "events/event-1",
    "eventChats/event-1",
    "events/event-1/participants/uid",
    "users/uid",
  ]);
  assert.deepEqual(
      writes.map((write) => `${write.type}:${write.path}`),
      ["create:eventChats/event-1/messages/message-1"],
  );
  assert.deepEqual(store.get("eventChats/event-1/messages/message-1"), {
    senderId: "uid",
    senderDisplayName: "Marco",
    senderPhotoUrl: "https://example.com/member.png",
    text: "Hello event",
    createdAt: fixedTimestamp,
    deletedAt: null,
  });
  assert.deepEqual(Object.keys(writes[0].data).sort(), [
    "createdAt",
    "deletedAt",
    "senderDisplayName",
    "senderId",
    "senderPhotoUrl",
    "text",
  ]);
  assert.equal(store.get("events/event-1").updatedAt, oldTimestamp);
  assert.equal(store.get("eventChats/event-1").updatedAt, oldTimestamp);
});

test("executeSendEventChatMessageTransaction blocks canceled chat writes", async () => {
  for (const event of [
    activeEvent({status: "canceled", canceledAt: fixedTimestamp}),
    activeEvent({canceledAt: fixedTimestamp}),
  ]) {
    const {db, writes} = createFakeFirestore({
      ...validSeed(),
      "events/event-1": event,
    });

    await assertRejectsHttpsError(
        () => executeSendEventChatMessageTransaction({
          db,
          uid: "uid",
          messageDate: fixedNow,
          messageTimestamp: fixedTimestamp,
          payload: {eventId: "event-1", text: "Blocked"},
        }),
        "failed-precondition",
        "event_chat_writes_blocked",
    );
    assert.deepEqual(writes, []);
  }
});

test("executeSendEventChatMessageTransaction fails closed after cancel retry", async () => {
  const fake = createFakeFirestore(
      validSeed(),
      {
        retryBeforeCommitCount: 1,
        beforeCommit({attempt, store}) {
          if (attempt === 1) {
            store.set("events/event-1", {
              ...store.get("events/event-1"),
              status: "canceled",
              canceledAt: fixedTimestamp,
            });
          }
        },
      },
  );

  await assertRejectsHttpsError(
      () => executeSendEventChatMessageTransaction({
        db: fake.db,
        uid: "uid",
        messageDate: fixedNow,
        messageTimestamp: fixedTimestamp,
        payload: {eventId: "event-1", text: "Race"},
      }),
      "failed-precondition",
      "event_chat_writes_blocked",
  );
  assert.equal(fake.attempts, 2);
  assert.deepEqual(fake.writes, []);
  assert.equal(fake.store.has("eventChats/event-1/messages/message-1"), false);
});

test("executeSendEventChatMessageTransaction fails closed on event and chat drift", async () => {
  await assertRejectsHttpsError(
      () => executeSendEventChatMessageTransaction({
        db: createFakeFirestore({
          "eventChats/event-1": eventChat(),
          "events/event-1/participants/uid": participant(),
        }).db,
        uid: "uid",
        messageDate: fixedNow,
        messageTimestamp: fixedTimestamp,
        payload: {eventId: "event-1", text: "Missing"},
      }),
      "not-found",
      "event_not_found",
  );

  for (const [seed, domainCode] of [
    [
      {
        ...validSeed(),
        "events/event-1": activeEvent({chatId: "other-chat"}),
      },
      "event_chat_metadata_invalid",
    ],
    [
      {
        ...validSeed(),
        "eventChats/event-1": eventChat({eventId: "other-event"}),
      },
      "event_chat_metadata_invalid",
    ],
    [
      {
        "events/event-1": activeEvent(),
        "events/event-1/participants/uid": participant(),
      },
      "event_chat_metadata_invalid",
    ],
  ]) {
    const {db, writes} = createFakeFirestore(seed);

    await assertRejectsHttpsError(
        () => executeSendEventChatMessageTransaction({
          db,
          uid: "uid",
          messageDate: fixedNow,
          messageTimestamp: fixedTimestamp,
          payload: {eventId: "event-1", text: "Drift"},
        }),
        "failed-precondition",
        domainCode,
    );
    assert.deepEqual(writes, []);
  }
});

test("executeSendEventChatMessageTransaction requires active participant", async () => {
  for (const [participantSeed, domainCode] of [
    [null, "not_active_participant"],
    [participant({status: "left", leftAt: oldTimestamp}), "not_active_participant"],
    [participant({status: "unknown"}), "participant_membership_inconsistent"],
    [participant({userId: "other"}), "participant_membership_inconsistent"],
    [participant({role: "speaker"}), "participant_membership_inconsistent"],
    [participant({leftAt: oldTimestamp}), "participant_membership_inconsistent"],
  ]) {
    const seed = {
      "events/event-1": activeEvent(),
      "eventChats/event-1": eventChat(),
      "users/uid": userProfile(),
    };
    if (participantSeed) {
      seed["events/event-1/participants/uid"] = participantSeed;
    }
    const {db, writes} = createFakeFirestore(seed);

    await assertRejectsHttpsError(
        () => executeSendEventChatMessageTransaction({
          db,
          uid: "uid",
          messageDate: fixedNow,
          messageTimestamp: fixedTimestamp,
          payload: {eventId: "event-1", text: "No access"},
        }),
        "failed-precondition",
        domainCode,
    );
    assert.deepEqual(writes, []);
  }
});

test("executeSendEventChatMessageTransaction falls back to user sender snapshot", async () => {
  const {db, store} = createFakeFirestore(validSeed({
    participant: {displayName: " ", photoUrl: " "},
    user: {
      display_name: " Fallback Name ",
      photo_url: " https://example.com/fallback.png ",
    },
  }));

  await executeSendEventChatMessageTransaction({
    db,
    uid: "uid",
    messageDate: fixedNow,
    messageTimestamp: fixedTimestamp,
    payload: {eventId: "event-1", text: "Fallback"},
  });

  assert.equal(
      store.get("eventChats/event-1/messages/message-1").senderDisplayName,
      "Fallback Name",
  );
  assert.equal(
      store.get("eventChats/event-1/messages/message-1").senderPhotoUrl,
      "https://example.com/fallback.png",
  );
});

test("executeSendEventChatMessageTransaction accepts sender snapshot boundaries", async () => {
  const photoUrl = "x".repeat(2048);
  const {db, store} = createFakeFirestore(validSeed({
    participant: {
      displayName: "a".repeat(70),
      photoUrl: "",
    },
    user: {photo_url: photoUrl},
  }));

  await executeSendEventChatMessageTransaction({
    db,
    uid: "uid",
    messageDate: fixedNow,
    messageTimestamp: fixedTimestamp,
    payload: {eventId: "event-1", text: "Boundaries"},
  });

  const message = store.get("eventChats/event-1/messages/message-1");
  assert.equal(message.senderDisplayName, "a".repeat(70));
  assert.equal(message.senderPhotoUrl, photoUrl);
});

test("executeSendEventChatMessageTransaction rejects invalid sender snapshot", async () => {
  for (const overrides of [
    {participant: {displayName: " "}, user: {display_name: " "}},
    {participant: {displayName: "a".repeat(71)}},
    {participant: {photoUrl: "x".repeat(2049)}},
  ]) {
    const {db, writes} = createFakeFirestore(validSeed(overrides));

    await assertRejectsHttpsError(
        () => executeSendEventChatMessageTransaction({
          db,
          uid: "uid",
          messageDate: fixedNow,
          messageTimestamp: fixedTimestamp,
          payload: {eventId: "event-1", text: "Invalid sender"},
        }),
        "failed-precondition",
        overrides.participant.photoUrl ?
          "sender_profile_invalid" :
          overrides.participant.displayName.trim() ?
            "sender_profile_invalid" :
            "sender_profile_required",
    );
    assert.deepEqual(writes, []);
  }
});
