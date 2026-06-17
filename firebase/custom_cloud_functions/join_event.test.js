const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __private__: {
    executeJoinEventTransaction,
    normalizeJoinEventPayload,
  },
} = require("./join_event");

const fixedNow = new Date("2026-06-16T10:00:00.000Z");
const oldDate = new Date("2026-06-15T10:00:00.000Z");
const fixedTimestamp = {
  toMillis: () => fixedNow.getTime(),
  toDate: () => fixedNow,
};
const oldTimestamp = {
  toMillis: () => oldDate.getTime(),
  toDate: () => oldDate,
};
const futureLeftAt = {
  toMillis: () => Date.parse("2026-06-17T10:00:00.000Z"),
  toDate: () => new Date("2026-06-17T10:00:00.000Z"),
};
const startsAtTimestamp = {
  toMillis: () => Date.parse("2026-06-20T15:00:00.000Z"),
  toDate: () => new Date("2026-06-20T15:00:00.000Z"),
};
const futureStartsAt = {
  toMillis: () => Date.parse("2026-06-20T15:00:00.000Z"),
  toDate: () => new Date("2026-06-20T15:00:00.000Z"),
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

function createFakeFirestore(seed = {}) {
  const store = new Map(Object.entries(seed));
  const reads = [];
  const writes = [];

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
          writes.push({type: "create", path: ref.path, data});
          pendingWrites.push({type: "create", path: ref.path, data});
        },
        update(ref, data) {
          hasWrites = true;
          if (!store.has(ref.path)) {
            throw new Error(`Document does not exist: ${ref.path}`);
          }
          writes.push({type: "update", path: ref.path, data});
          pendingWrites.push({type: "update", path: ref.path, data});
        },
      };
      const result = await callback(tx);
      for (const write of pendingWrites) {
        if (write.type === "create") {
          store.set(write.path, write.data);
        } else {
          store.set(write.path, {...store.get(write.path), ...write.data});
        }
      }
      return result;
    },
  };

  return {db, reads, store, writes};
}

function activeEvent(overrides = {}) {
  return {
    organizerId: "organizer",
    chatId: "event-1",
    status: "active",
    canceledAt: null,
    startsAt: futureStartsAt,
    participantsCount: 1,
    capacity: 3,
    updatedAt: oldTimestamp,
    ...overrides,
  };
}

function eventChat(overrides = {}) {
  return {
    eventId: "event-1",
    readAccessUserIds: ["organizer"],
    createdAt: oldTimestamp,
    updatedAt: oldTimestamp,
    ...overrides,
  };
}

function userProfile(overrides = {}) {
  return {
    display_name: " Марко ",
    photo_url: " https://example.com/avatar.png ",
    ...overrides,
  };
}

function participant(overrides = {}) {
  return {
    userId: "uid",
    displayName: "Марко",
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

function organizerParticipant(overrides = {}) {
  return {
    userId: "organizer",
    displayName: "Анастасия",
    photoUrl: null,
    role: "organizer",
    status: "active",
    joinedAt: oldTimestamp,
    leftAt: null,
    createdAt: oldTimestamp,
    updatedAt: oldTimestamp,
    ...overrides,
  };
}

function counterData() {
  return {
    userId: "organizer",
    dayKeyUtc: "2026-06-16",
    count: 1,
    eventIds: ["event-1"],
    requestEventIds: {request1: "event-1"},
    requestPayloadHashes: {request1: "a".repeat(64)},
    windowStartAt: oldTimestamp,
    windowEndAt: oldTimestamp,
    createdAt: oldTimestamp,
    updatedAt: oldTimestamp,
  };
}

test("normalizeJoinEventPayload rejects unknown and missing keys", () => {
  assertHttpsError(
      () => normalizeJoinEventPayload({eventId: "event-1", status: "active"}),
      "invalid-argument",
      "invalid_join_request",
      "status",
      "unknown_key",
  );
  assertHttpsError(
      () => normalizeJoinEventPayload({}),
      "invalid-argument",
      "invalid_join_request",
      "eventId",
      "missing",
  );
  assertHttpsError(
      () => normalizeJoinEventPayload({eventId: "events/event-1"}),
      "invalid-argument",
      "invalid_join_request",
      "eventId",
      "invalid_format",
  );
});

test("executeJoinEventTransaction creates active participant", async () => {
  const counterBefore = counterData();
  const {db, reads, store, writes} = createFakeFirestore({
    "events/event-1": activeEvent(),
    "eventChats/event-1": eventChat(),
    "events/event-1/participants/organizer": organizerParticipant(),
    "users/uid": userProfile(),
    "eventCreationCounters/organizer/days/20260616": counterBefore,
  });

  const response = await executeJoinEventTransaction({
    db,
    uid: "uid",
    joinDate: fixedNow,
    joinTimestamp: fixedTimestamp,
    payload: {eventId: "event-1"},
  });

  assert.deepEqual(response, {
    eventId: "event-1",
    participantStatus: "active",
    participantsCount: 2,
    joinedAt: "2026-06-16T10:00:00.000Z",
  });
  assert.equal(store.get("events/event-1").participantsCount, 2);
  assert.equal(store.get("events/event-1").updatedAt, fixedTimestamp);
  assert.deepEqual(store.get("events/event-1/participants/uid"), {
    userId: "uid",
    displayName: "Марко",
    photoUrl: "https://example.com/avatar.png",
    role: "participant",
    status: "active",
    joinedAt: fixedTimestamp,
    leftAt: null,
    createdAt: fixedTimestamp,
    updatedAt: fixedTimestamp,
  });
  assert.deepEqual(store.get("eventChats/event-1").readAccessUserIds, [
    "organizer",
    "uid",
  ]);
  assert.strictEqual(
      store.get("eventCreationCounters/organizer/days/20260616"),
      counterBefore,
  );
  assert.deepEqual(reads, [
    "events/event-1",
    "events/event-1/participants/uid",
    "events/event-1/participants/organizer",
    "eventChats/event-1",
    "users/uid",
  ]);
  assert.deepEqual(
      writes.map((write) => `${write.type}:${write.path}`),
      [
        "update:events/event-1",
        "create:events/event-1/participants/uid",
        "update:eventChats/event-1",
      ],
  );
});

test("executeJoinEventTransaction rejoins left participant", async () => {
  const {db, store, writes} = createFakeFirestore({
    "events/event-1": activeEvent({participantsCount: 1}),
    "eventChats/event-1": eventChat({readAccessUserIds: ["organizer"]}),
    "events/event-1/participants/organizer": organizerParticipant(),
    "events/event-1/participants/uid": participant({
      status: "left",
      leftAt: oldTimestamp,
      createdAt: oldTimestamp,
    }),
    "users/uid": userProfile({photo_url: ""}),
  });

  const response = await executeJoinEventTransaction({
    db,
    uid: "uid",
    joinDate: fixedNow,
    joinTimestamp: fixedTimestamp,
    payload: {eventId: "event-1"},
  });
  const membership = store.get("events/event-1/participants/uid");

  assert.equal(response.participantsCount, 2);
  assert.equal(store.get("events/event-1").participantsCount, 2);
  assert.equal(membership.role, "participant");
  assert.equal(membership.createdAt, oldTimestamp);
  assert.equal(membership.status, "active");
  assert.equal(membership.leftAt, null);
  assert.equal(membership.joinedAt, fixedTimestamp);
  assert.equal(membership.photoUrl, null);
  assert.deepEqual(store.get("eventChats/event-1").readAccessUserIds, [
    "organizer",
    "uid",
  ]);
  assert.deepEqual(
      writes.map((write) => `${write.type}:${write.path}`),
      [
        "update:events/event-1",
        "update:events/event-1/participants/uid",
        "update:eventChats/event-1",
      ],
  );
});

test("executeJoinEventTransaction blocks duplicate active join without writes", async () => {
  for (const eventData of [
    activeEvent({participantsCount: 2}),
    activeEvent({participantsCount: 3, capacity: 3}),
  ]) {
    const {db, writes} = createFakeFirestore({
      "events/event-1": eventData,
      "eventChats/event-1": eventChat({
        readAccessUserIds: ["organizer", "uid"],
      }),
      "events/event-1/participants/organizer": organizerParticipant(),
      "events/event-1/participants/uid": participant(),
    });

    await assertRejectsHttpsError(
        () => executeJoinEventTransaction({
          db,
          uid: "uid",
          joinDate: fixedNow,
          joinTimestamp: fixedTimestamp,
          payload: {eventId: "event-1"},
        }),
        "failed-precondition",
        "already_joined",
    );
    assert.deepEqual(writes, []);
  }
});

test("executeJoinEventTransaction blocks organizer self-join drift", async () => {
  const missingOrganizerMembership = createFakeFirestore({
    "events/event-1": activeEvent(),
    "eventChats/event-1": eventChat(),
    "users/organizer": userProfile(),
  });

  await assertRejectsHttpsError(
      () => executeJoinEventTransaction({
        db: missingOrganizerMembership.db,
        uid: "organizer",
        joinDate: fixedNow,
        joinTimestamp: fixedTimestamp,
        payload: {eventId: "event-1"},
      }),
      "failed-precondition",
      "participant_membership_inconsistent",
  );
  assert.deepEqual(missingOrganizerMembership.writes, []);

  const activeOrganizerMembership = createFakeFirestore({
    "events/event-1": activeEvent(),
    "eventChats/event-1": eventChat(),
    "events/event-1/participants/organizer": organizerParticipant(),
  });

  await assertRejectsHttpsError(
      () => executeJoinEventTransaction({
        db: activeOrganizerMembership.db,
        uid: "organizer",
        joinDate: fixedNow,
        joinTimestamp: fixedTimestamp,
        payload: {eventId: "event-1"},
      }),
      "failed-precondition",
      "already_joined",
  );
  assert.deepEqual(activeOrganizerMembership.writes, []);
});

test("executeJoinEventTransaction fails closed on organizer membership drift", async () => {
  for (const organizerSeed of [
    null,
    organizerParticipant({status: "left", leftAt: oldTimestamp}),
    organizerParticipant({userId: "other"}),
    organizerParticipant({role: "participant"}),
  ]) {
    const seed = {
      "events/event-1": activeEvent(),
      "eventChats/event-1": eventChat(),
      "users/uid": userProfile(),
    };
    if (organizerSeed) {
      seed["events/event-1/participants/organizer"] = organizerSeed;
    }
    const {db, writes} = createFakeFirestore(seed);

    await assertRejectsHttpsError(
        () => executeJoinEventTransaction({
          db,
          uid: "uid",
          joinDate: fixedNow,
          joinTimestamp: fixedTimestamp,
          payload: {eventId: "event-1"},
        }),
        "failed-precondition",
        "participant_membership_inconsistent",
    );
    assert.deepEqual(writes, []);
  }
});

test("executeJoinEventTransaction blocks missing, canceled, past, and full events", async () => {
  await assertRejectsHttpsError(
      () => executeJoinEventTransaction({
        db: createFakeFirestore({
          "eventChats/event-1": eventChat(),
          "users/uid": userProfile(),
        }).db,
        uid: "uid",
        joinDate: fixedNow,
        joinTimestamp: fixedTimestamp,
        payload: {eventId: "event-1"},
      }),
      "not-found",
      "event_not_found",
  );

  for (const [eventData, domainCode] of [
    [
      activeEvent({
        status: "canceled",
        canceledAt: fixedTimestamp,
      }),
      "event_not_joinable",
    ],
    [activeEvent({startsAt: pastStartsAt}), "event_not_joinable"],
    [activeEvent({participantsCount: 3, capacity: 3}), "event_full"],
    [activeEvent({capacity: 100}), "event_participant_state_inconsistent"],
  ]) {
    const {db, writes} = createFakeFirestore({
      "events/event-1": eventData,
      "eventChats/event-1": eventChat(),
      "events/event-1/participants/organizer": organizerParticipant(),
      "users/uid": userProfile(),
    });

    await assertRejectsHttpsError(
        () => executeJoinEventTransaction({
          db,
          uid: "uid",
          joinDate: fixedNow,
          joinTimestamp: fixedTimestamp,
          payload: {eventId: "event-1"},
        }),
        "failed-precondition",
        domainCode,
    );
    assert.deepEqual(writes, []);
  }
});

test("executeJoinEventTransaction fails closed on invalid chat metadata", async () => {
  for (const chatSeed of [
    null,
    eventChat({eventId: "other-event"}),
    eventChat({readAccessUserIds: ["uid"]}),
    eventChat({readAccessUserIds: ["organizer", "organizer"]}),
  ]) {
    const seed = {
      "events/event-1": activeEvent(),
      "users/uid": userProfile(),
      "events/event-1/participants/organizer": organizerParticipant(),
    };
    if (chatSeed) {
      seed["eventChats/event-1"] = chatSeed;
    }
    const {db, writes} = createFakeFirestore(seed);

    await assertRejectsHttpsError(
        () => executeJoinEventTransaction({
          db,
          uid: "uid",
          joinDate: fixedNow,
          joinTimestamp: fixedTimestamp,
          payload: {eventId: "event-1"},
        }),
        "failed-precondition",
        "event_chat_metadata_invalid",
    );
    assert.deepEqual(writes, []);
  }
});

test("executeJoinEventTransaction fails closed on corrupt participant/profile", async () => {
  for (const [participantSeed, userSeed, domainCode] of [
    [participant({status: "unknown"}), userProfile(), "participant_membership_inconsistent"],
    [participant({userId: "other"}), userProfile(), "participant_membership_inconsistent"],
    [
      participant({status: "left", leftAt: null}),
      userProfile(),
      "participant_membership_inconsistent",
    ],
    [
      participant({status: "left", leftAt: "bad"}),
      userProfile(),
      "participant_membership_inconsistent",
    ],
    [
      participant({status: "left", leftAt: futureLeftAt}),
      userProfile(),
      "participant_membership_inconsistent",
    ],
    [
      participant({status: "left", leftAt: startsAtTimestamp}),
      userProfile(),
      "participant_membership_inconsistent",
    ],
    [null, null, "participant_profile_required"],
    [null, userProfile({display_name: "  "}), "participant_profile_required"],
  ]) {
    const seed = {
      "events/event-1": activeEvent(),
      "eventChats/event-1": eventChat(),
      "events/event-1/participants/organizer": organizerParticipant(),
    };
    if (participantSeed) {
      seed["events/event-1/participants/uid"] = participantSeed;
    }
    if (userSeed) {
      seed["users/uid"] = userSeed;
    }
    const {db, writes} = createFakeFirestore(seed);

    await assertRejectsHttpsError(
        () => executeJoinEventTransaction({
          db,
          uid: "uid",
          joinDate: fixedNow,
          joinTimestamp: fixedTimestamp,
          payload: {eventId: "event-1"},
        }),
        "failed-precondition",
        domainCode,
    );
    assert.deepEqual(writes, []);
  }
});
