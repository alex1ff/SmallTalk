const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __private__: {
    executeLeaveEventTransaction,
    normalizeLeaveEventPayload,
  },
} = require("./leave_event");

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
const futureStartsAt = {
  toMillis: () => Date.parse("2026-06-20T15:00:00.000Z"),
  toDate: () => new Date("2026-06-20T15:00:00.000Z"),
};
const pastStartsAt = {
  toMillis: () => Date.parse("2026-06-16T09:00:00.000Z"),
  toDate: () => new Date("2026-06-16T09:00:00.000Z"),
};
const equalStartsAt = {
  toMillis: () => fixedNow.getTime(),
  toDate: () => fixedNow,
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

async function assertRejectsHttpsError(
    promiseFactory,
    code,
    domainCode,
    field,
    reason,
) {
  await assert.rejects(promiseFactory, (err) => {
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

function createFakeFirestore(seed = {}, {
  maxTransactionAttempts = 5,
  onBeforeCommit = null,
  retryBeforeCommitCount = 0,
  retryOnConcurrentModification = false,
} = {}) {
  const store = new Map(Object.entries(seed));
  const versions = new Map(Array.from(store.keys(), (path) => [path, 0]));
  const reads = [];
  const writes = [];
  let attempts = 0;

  const applyWriteData = (existing = {}, data = {}) => {
    const next = {...existing};
    for (const [field, value] of Object.entries(data)) {
      if (value?.constructor?.name === "ArrayRemoveTransform") {
        const removed = new Set(value.elements);
        next[field] = (Array.isArray(next[field]) ? next[field] : [])
            .filter((item) => !removed.has(item));
      } else {
        next[field] = value;
      }
    }
    return next;
  };

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

  const makeQuery = (collectionPath, filters) => ({
    path: `${collectionPath}?${filters
        .map((filter) => `${filter.field}${filter.op}${filter.value}`)
        .join("&")}`,
    async get() {
      const docs = [];
      const prefix = `${collectionPath}/`;
      for (const [path, data] of store.entries()) {
        if (!path.startsWith(prefix)) {
          continue;
        }
        const remainder = path.slice(prefix.length);
        if (!remainder || remainder.includes("/")) {
          continue;
        }
        const matches = filters.every((filter) => (
          filter.op === "==" && data?.[filter.field] === filter.value
        ));
        if (matches) {
          docs.push({
            id: remainder,
            exists: true,
            data: () => data,
            ref: makeRef(path),
          });
        }
      }
      docs.sort((left, right) => left.id.localeCompare(right.id));
      return {docs};
    },
  });

  const makeCollection = (path) => ({
    doc(id) {
      return makeRef(`${path}/${id}`);
    },
    where(field, op, value) {
      return makeQuery(path, [{field, op, value}]);
    },
  });

  const db = {
    collection(name) {
      return makeCollection(name);
    },
    async runTransaction(callback) {
      for (let attempt = 1; attempt <= maxTransactionAttempts; attempt += 1) {
        let hasWrites = false;
        const pendingWrites = [];
        const readVersions = new Map();
        const tx = {
          async get(refOrQuery) {
            if (hasWrites) {
              throw new Error("Firestore transactions require reads first");
            }
            reads.push(refOrQuery.path);
            const snapshot = await refOrQuery.get();
            if (Array.isArray(snapshot.docs)) {
              for (const doc of snapshot.docs) {
                if (!readVersions.has(doc.ref.path)) {
                  readVersions.set(doc.ref.path, versions.get(doc.ref.path) || 0);
                }
              }
            } else if (!readVersions.has(refOrQuery.path)) {
              readVersions.set(refOrQuery.path, versions.get(refOrQuery.path) || 0);
            }
            return snapshot;
          },
          update(ref, data) {
            hasWrites = true;
            if (!store.has(ref.path)) {
              throw new Error(`Document does not exist: ${ref.path}`);
            }
            pendingWrites.push({type: "update", path: ref.path, data});
          },
        };
        attempts += 1;
        const result = await callback(tx);
        if (attempts <= retryBeforeCommitCount) {
          continue;
        }
        if (onBeforeCommit) {
          await onBeforeCommit({attempt, pendingWrites, store});
        }
        if (retryOnConcurrentModification) {
          const staleRead = Array.from(readVersions).some(
              ([path, version]) => (versions.get(path) || 0) !== version,
          );
          if (staleRead) {
            continue;
          }
        }
        for (const write of pendingWrites) {
          writes.push(write);
          store.set(
              write.path,
              applyWriteData(store.get(write.path), write.data),
          );
          versions.set(write.path, (versions.get(write.path) || 0) + 1);
        }
        return result;
      }
      throw new Error("Simulated transaction retry limit exceeded");
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
    startsAt: futureStartsAt,
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

function validLeaveSeed(overrides = {}) {
  return {
    "events/event-1": activeEvent(overrides.event),
    "eventChats/event-1": eventChat(overrides.chat),
    "events/event-1/participants/organizer": organizerParticipant(
        overrides.organizer,
    ),
    "events/event-1/participants/uid": participant(overrides.participant),
    "users/uid": {
      eventChatInboxEventIds: ["event-old", "event-1"],
    },
  };
}

function fixedLeaveTime() {
  return {
    leaveDate: fixedNow,
    leaveTimestamp: fixedTimestamp,
  };
}

function executeLeave(params) {
  return executeLeaveEventTransaction({
    ...params,
    getLeaveTime: params.getLeaveTime || fixedLeaveTime,
  });
}

function createFirstAttemptBarrier(expectedCommits = 2) {
  let firstAttemptCommits = 0;
  let releaseFirstAttempts;
  const firstAttemptsReady = new Promise((resolve) => {
    releaseFirstAttempts = resolve;
  });
  const timeout = setTimeout(() => {
    releaseFirstAttempts();
  }, 1000);

  return {
    async onBeforeCommit({attempt}) {
      if (attempt !== 1) {
        return;
      }
      firstAttemptCommits += 1;
      if (firstAttemptCommits === expectedCommits) {
        releaseFirstAttempts();
      }
      await firstAttemptsReady;
    },
    clear() {
      clearTimeout(timeout);
    },
    get count() {
      return firstAttemptCommits;
    },
  };
}

test("normalizeLeaveEventPayload rejects unknown and missing keys", () => {
  for (const field of [
    "status",
    "role",
    "displayName",
    "photoUrl",
    "joinedAt",
    "leftAt",
    "createdAt",
    "updatedAt",
  ]) {
    assertHttpsError(
        () => normalizeLeaveEventPayload({eventId: "event-1", [field]: "x"}),
        "invalid-argument",
        "invalid_leave_request",
        field,
        "unknown_key",
    );
  }
  assertHttpsError(
      () => normalizeLeaveEventPayload({}),
      "invalid-argument",
      "invalid_leave_request",
      "eventId",
      "missing",
  );
  assertHttpsError(
      () => normalizeLeaveEventPayload({eventId: "events/event-1"}),
      "invalid-argument",
      "invalid_leave_request",
      "eventId",
      "invalid_format",
  );
});

test("executeLeaveEventTransaction marks participant left", async () => {
  const counterBefore = counterData();
  const {db, reads, store, writes} = createFakeFirestore({
    ...validLeaveSeed({
      chat: {readAccessUserIds: ["uid", "organizer"]},
    }),
    "eventCreationCounters/organizer/days/20260616": counterBefore,
  });

  const response = await executeLeave({
    db,
    uid: "uid",
    leaveDate: fixedNow,
    leaveTimestamp: fixedTimestamp,
    payload: {eventId: "event-1"},
  });
  const membership = store.get("events/event-1/participants/uid");

  assert.deepEqual(response, {
    eventId: "event-1",
    participantStatus: "left",
    participantsCount: 1,
    leftAt: "2026-06-16T10:00:00.000Z",
  });
  assert.equal(store.has("events/event-1/participants/uid"), true);
  assert.equal(store.get("events/event-1").participantsCount, 1);
  assert.equal(store.get("events/event-1").updatedAt, fixedTimestamp);
  assert.equal(membership.status, "left");
  assert.equal(membership.leftAt, fixedTimestamp);
  assert.equal(membership.updatedAt, fixedTimestamp);
  assert.equal(membership.role, "participant");
  assert.equal(membership.createdAt, oldTimestamp);
  assert.equal(membership.joinedAt, oldTimestamp);
  assert.deepEqual(store.get("eventChats/event-1").readAccessUserIds, [
    "organizer",
  ]);
  assert.deepEqual(store.get("users/uid").eventChatInboxEventIds, [
    "event-old",
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
    "events/event-1/participants?status==active",
  ]);
  assert.deepEqual(
      writes.map((write) => `${write.type}:${write.path}`),
      [
        "update:events/event-1",
        "update:events/event-1/participants/uid",
        "update:eventChats/event-1",
        "update:users/uid",
      ],
  );
  assert.deepEqual(writes[2].data, {
    readAccessUserIds: ["organizer"],
    updatedAt: fixedTimestamp,
  });
  assert.deepEqual(writes[1].data, {
    status: "left",
    leftAt: fixedTimestamp,
    updatedAt: fixedTimestamp,
  });
  for (const immutableField of [
    "userId",
    "role",
    "displayName",
    "photoUrl",
    "joinedAt",
    "createdAt",
  ]) {
    assert.equal(
        Object.prototype.hasOwnProperty.call(writes[1].data, immutableField),
        false,
    );
  }
});

test("executeLeaveEventTransaction succeeds without a user document",
    async () => {
      const seed = validLeaveSeed({
        chat: {readAccessUserIds: ["organizer", "uid"]},
      });
      delete seed["users/uid"];
      const {db, store, writes} = createFakeFirestore(seed);

      const response = await executeLeave({
        db,
        uid: "uid",
        payload: {eventId: "event-1"},
      });

      assert.equal(response.participantStatus, "left");
      assert.equal(store.get("events/event-1").participantsCount, 1);
      assert.equal(
          store.get("events/event-1/participants/uid").status,
          "left",
      );
      assert.deepEqual(store.get("eventChats/event-1").readAccessUserIds, [
        "organizer",
      ]);
      assert.equal(
          writes.some((write) => write.path === "users/uid"),
          false,
      );
    });

test("executeLeaveEventTransaction retries same-user concurrent inbox leaves",
    async () => {
      const firstAttemptBarrier = createFirstAttemptBarrier();
      const fake = createFakeFirestore(
          {
            "events/event-1": activeEvent(),
            "eventChats/event-1": eventChat(),
            "events/event-1/participants/organizer": organizerParticipant(),
            "events/event-1/participants/uid": participant(),
            "events/event-2": activeEvent({chatId: "event-2"}),
            "eventChats/event-2": eventChat({eventId: "event-2"}),
            "events/event-2/participants/organizer": organizerParticipant(),
            "events/event-2/participants/uid": participant(),
            "users/uid": {
              eventChatInboxEventIds: ["event-old", "event-1", "event-2"],
            },
          },
          {
            retryOnConcurrentModification: true,
            onBeforeCommit: firstAttemptBarrier.onBeforeCommit,
          },
      );
      const leave = (eventId) => executeLeave({
        db: fake.db,
        uid: "uid",
        payload: {eventId},
      });

      let results;
      try {
        results = await Promise.all([
          leave("event-1"),
          leave("event-2"),
        ]);
      } finally {
        firstAttemptBarrier.clear();
      }

      assert.deepEqual(
          results.map((result) => result.eventId).sort(),
          ["event-1", "event-2"],
      );
      assert.equal(firstAttemptBarrier.count, 2);
      assert.equal(fake.attempts, 3);
      assert.equal(
          fake.reads.filter((path) => path === "users/uid").length,
          3,
      );
      assert.deepEqual(
          fake.store.get("users/uid").eventChatInboxEventIds,
          ["event-old"],
      );
      assert.equal(
          fake.writes.filter((write) => write.path === "users/uid").length,
          2,
      );
      for (const eventId of ["event-1", "event-2"]) {
        assert.equal(
            fake.store.get(`events/${eventId}/participants/uid`).status,
            "left",
        );
      }
    });

test("executeLeaveEventTransaction concurrent duplicate leaves decrement once",
    async () => {
      const firstAttemptBarrier = createFirstAttemptBarrier();
      const {db, store, writes} = createFakeFirestore(
          validLeaveSeed(),
          {
            retryOnConcurrentModification: true,
            onBeforeCommit: firstAttemptBarrier.onBeforeCommit,
          },
      );
      const leave = () => executeLeave({
        db,
        uid: "uid",
        payload: {eventId: "event-1"},
      });

      let results;
      try {
        results = await Promise.allSettled([leave(), leave()]);
      } finally {
        firstAttemptBarrier.clear();
      }
      const fulfilled = results.filter((result) =>
        result.status === "fulfilled");
      const rejected = results.filter((result) =>
        result.status === "rejected");
      const membership = store.get("events/event-1/participants/uid");

      assert.equal(fulfilled.length, 1);
      assert.equal(rejected.length, 1);
      assert.equal(firstAttemptBarrier.count, 2);
      assert.deepEqual(fulfilled[0].value, {
        eventId: "event-1",
        participantStatus: "left",
        participantsCount: 1,
        leftAt: "2026-06-16T10:00:00.000Z",
      });
      assert.equal(rejected[0].reason.code, "failed-precondition");
      assert.deepEqual(rejected[0].reason.details, {
        domainCode: "not_active_participant",
      });
      assert.equal(store.get("events/event-1").participantsCount, 1);
      assert.equal(membership.status, "left");
      assert.equal(membership.leftAt, fixedTimestamp);
      assert.deepEqual(store.get("eventChats/event-1").readAccessUserIds, [
        "organizer",
      ]);
      assert.deepEqual(
          writes.map((write) => `${write.type}:${write.path}`),
          [
            "update:events/event-1",
            "update:events/event-1/participants/uid",
            "update:eventChats/event-1",
            "update:users/uid",
          ],
      );
    });

test("executeLeaveEventTransaction concurrent leaves recompute occupancy and chat",
    async () => {
      const firstAttemptBarrier = createFirstAttemptBarrier();
      const {db, store, writes} = createFakeFirestore(
          {
            "events/event-1": activeEvent({
              participantsCount: 3,
              capacity: 3,
            }),
            "eventChats/event-1": eventChat({
              readAccessUserIds: ["organizer", "uid-a", "uid-b"],
            }),
            "events/event-1/participants/organizer": organizerParticipant(),
            "events/event-1/participants/uid-a": participant({
              userId: "uid-a",
            }),
            "events/event-1/participants/uid-b": participant({
              userId: "uid-b",
            }),
            "users/uid-a": {
              eventChatInboxEventIds: ["event-1"],
            },
            "users/uid-b": {
              eventChatInboxEventIds: ["event-1"],
            },
          },
          {
            retryOnConcurrentModification: true,
            onBeforeCommit: firstAttemptBarrier.onBeforeCommit,
          },
      );
      const leave = (uid) => executeLeave({
        db,
        uid,
        payload: {eventId: "event-1"},
      });

      let results;
      try {
        results = await Promise.allSettled([leave("uid-a"), leave("uid-b")]);
      } finally {
        firstAttemptBarrier.clear();
      }
      const fulfilled = results.filter((result) =>
        result.status === "fulfilled");

      assert.equal(fulfilled.length, 2);
      assert.equal(firstAttemptBarrier.count, 2);
      assert.deepEqual(
          fulfilled
              .map((result) => result.value.participantsCount)
              .sort((left, right) => left - right),
          [1, 2],
      );
      assert.equal(store.get("events/event-1").participantsCount, 1);
      for (const uid of ["uid-a", "uid-b"]) {
        const membership = store.get(`events/event-1/participants/${uid}`);
        assert.equal(membership.status, "left");
        assert.equal(membership.leftAt, fixedTimestamp);
      }
      assert.deepEqual(store.get("eventChats/event-1").readAccessUserIds, [
        "organizer",
      ]);

      const writePaths = writes.map((write) => `${write.type}:${write.path}`);
      assert.equal(writePaths.filter((path) =>
        path === "update:events/event-1").length, 2);
      assert.deepEqual(
          writePaths
              .filter((path) => path.startsWith(
                  "update:events/event-1/participants/",
              ))
              .sort(),
          [
            "update:events/event-1/participants/uid-a",
            "update:events/event-1/participants/uid-b",
          ],
      );
      assert.equal(writePaths.filter((path) =>
        path === "update:eventChats/event-1").length, 2);
      assert.deepEqual(
          writePaths
              .filter((path) => path.startsWith("update:users/"))
              .sort(),
          ["update:users/uid-a", "update:users/uid-b"],
      );
    });

test("executeLeaveEventTransaction blocks leave at or after startsAt", async () => {
  for (const startsAt of [pastStartsAt, equalStartsAt]) {
    const eventBefore = activeEvent({startsAt});
    const participantBefore = participant();
    const chatBefore = eventChat();
    const {db, store, writes} = createFakeFirestore(
        validLeaveSeed({
          event: {startsAt},
          participant: participantBefore,
          chat: chatBefore,
        }),
    );

    await assertRejectsHttpsError(
        () => executeLeave({
          db,
          uid: "uid",
          leaveDate: fixedNow,
          leaveTimestamp: fixedTimestamp,
          payload: {eventId: "event-1"},
        }),
        "failed-precondition",
        "event_not_leaveable",
        null,
        "event_started",
    );
    assert.deepEqual(store.get("events/event-1"), eventBefore);
    assert.deepEqual(
        store.get("events/event-1/participants/uid"),
        participantBefore,
    );
    assert.deepEqual(store.get("eventChats/event-1"), chatBefore);
    assert.deepEqual(writes, []);
  }
});

test("executeLeaveEventTransaction rechecks startsAt on retry", async () => {
  const retryNow = new Date("2026-06-20T15:00:00.000Z");
  const retryTimestamp = {
    toMillis: () => retryNow.getTime(),
    toDate: () => retryNow,
  };
  const leaveTimes = [
    {
      leaveDate: fixedNow,
      leaveTimestamp: fixedTimestamp,
    },
    {
      leaveDate: retryNow,
      leaveTimestamp: retryTimestamp,
    },
  ];
  let leaveTimeIndex = 0;
  const fake = createFakeFirestore(
      validLeaveSeed(),
      {retryBeforeCommitCount: 1},
  );
  const {db, store, writes} = fake;
  const eventBefore = store.get("events/event-1");
  const participantBefore = store.get("events/event-1/participants/uid");
  const chatBefore = store.get("eventChats/event-1");

  await assertRejectsHttpsError(
      () => executeLeave({
        db,
        uid: "uid",
        getLeaveTime: () => leaveTimes[leaveTimeIndex++] ||
          leaveTimes[leaveTimes.length - 1],
        payload: {eventId: "event-1"},
      }),
      "failed-precondition",
      "event_not_leaveable",
      null,
      "event_started",
  );
  assert.equal(fake.attempts, 2);
  assert.deepEqual(store.get("events/event-1"), eventBefore);
  assert.deepEqual(
      store.get("events/event-1/participants/uid"),
      participantBefore,
  );
  assert.deepEqual(store.get("eventChats/event-1"), chatBefore);
  assert.deepEqual(writes, []);
});

test("executeLeaveEventTransaction blocks organizer leave", async () => {
  const {db, store, writes} = createFakeFirestore(validLeaveSeed());
  const eventBefore = store.get("events/event-1");
  const organizerBefore = store.get("events/event-1/participants/organizer");
  const participantBefore = store.get("events/event-1/participants/uid");
  const chatBefore = store.get("eventChats/event-1");

  await assertRejectsHttpsError(
      () => executeLeave({
        db,
        uid: "organizer",
        leaveDate: fixedNow,
        leaveTimestamp: fixedTimestamp,
        payload: {eventId: "event-1"},
      }),
      "failed-precondition",
      "organizer_cannot_leave",
  );
  assert.deepEqual(store.get("events/event-1"), eventBefore);
  assert.deepEqual(
      store.get("events/event-1/participants/organizer"),
      organizerBefore,
  );
  assert.deepEqual(
      store.get("events/event-1/participants/uid"),
      participantBefore,
  );
  assert.deepEqual(store.get("eventChats/event-1"), chatBefore);
  assert.deepEqual(writes, []);
});

test("executeLeaveEventTransaction blocks missing, canceled, and corrupt events", async () => {
  await assertRejectsHttpsError(
      () => executeLeave({
        db: createFakeFirestore({
          "eventChats/event-1": eventChat(),
        }).db,
        uid: "uid",
        leaveDate: fixedNow,
        leaveTimestamp: fixedTimestamp,
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
      "event_not_leaveable",
    ],
    [activeEvent({participantsCount: 1}), "event_participant_state_inconsistent"],
    [activeEvent({capacity: 100}), "event_participant_state_inconsistent"],
    [activeEvent({chatId: "other-chat"}), "event_chat_metadata_invalid"],
  ]) {
    const {db, writes} = createFakeFirestore({
      ...validLeaveSeed(),
      "events/event-1": eventData,
    });

    await assertRejectsHttpsError(
        () => executeLeave({
          db,
          uid: "uid",
          leaveDate: fixedNow,
          leaveTimestamp: fixedTimestamp,
          payload: {eventId: "event-1"},
        }),
        "failed-precondition",
        domainCode,
    );
    assert.deepEqual(writes, []);
  }
});

test("executeLeaveEventTransaction fails closed on organizer membership drift", async () => {
  for (const organizerSeed of [
    null,
    organizerParticipant({status: "left", leftAt: oldTimestamp}),
    organizerParticipant({userId: "other"}),
    organizerParticipant({role: "participant"}),
    organizerParticipant({leftAt: oldTimestamp}),
  ]) {
    const seed = {
      "events/event-1": activeEvent(),
      "eventChats/event-1": eventChat(),
      "events/event-1/participants/uid": participant(),
    };
    if (organizerSeed) {
      seed["events/event-1/participants/organizer"] = organizerSeed;
    }
    const {db, writes} = createFakeFirestore(seed);

    await assertRejectsHttpsError(
        () => executeLeave({
          db,
          uid: "uid",
          leaveDate: fixedNow,
          leaveTimestamp: fixedTimestamp,
          payload: {eventId: "event-1"},
        }),
        "failed-precondition",
        "participant_membership_inconsistent",
    );
    assert.deepEqual(writes, []);
  }
});

test("executeLeaveEventTransaction fails closed on invalid participant", async () => {
  for (const [participantSeed, domainCode] of [
    [null, "not_active_participant"],
    [participant({status: "left", leftAt: oldTimestamp}), "not_active_participant"],
    [participant({status: "unknown"}), "participant_membership_inconsistent"],
    [participant({userId: "other"}), "participant_membership_inconsistent"],
    [participant({role: "organizer"}), "participant_membership_inconsistent"],
    [participant({leftAt: oldTimestamp}), "participant_membership_inconsistent"],
  ]) {
    const seed = {
      "events/event-1": activeEvent(),
      "eventChats/event-1": eventChat(),
      "events/event-1/participants/organizer": organizerParticipant(),
    };
    if (participantSeed) {
      seed["events/event-1/participants/uid"] = participantSeed;
    }
    const {db, writes} = createFakeFirestore(seed);

    await assertRejectsHttpsError(
        () => executeLeave({
          db,
          uid: "uid",
          leaveDate: fixedNow,
          leaveTimestamp: fixedTimestamp,
          payload: {eventId: "event-1"},
        }),
        "failed-precondition",
        domainCode,
    );
    assert.deepEqual(writes, []);
  }
});

test("executeLeaveEventTransaction fails closed on participant count drift",
    async () => {
      for (const seed of [
        validLeaveSeed({event: {participantsCount: 3, capacity: 3}}),
        {
          ...validLeaveSeed({
            event: {participantsCount: 2, capacity: 3},
            chat: {readAccessUserIds: ["organizer", "uid", "other"]},
          }),
          "events/event-1/participants/other": participant({userId: "other"}),
        },
      ]) {
        const {db, writes} = createFakeFirestore(seed);

        await assertRejectsHttpsError(
            () => executeLeave({
              db,
              uid: "uid",
              leaveDate: fixedNow,
              leaveTimestamp: fixedTimestamp,
              payload: {eventId: "event-1"},
            }),
            "failed-precondition",
            "event_participant_state_inconsistent",
        );
        assert.deepEqual(writes, []);
      }
    });

test("executeLeaveEventTransaction fails closed on corrupt active participant set", async () => {
  for (const otherParticipant of [
    participant({userId: "attacker"}),
    participant({userId: "other", role: "organizer"}),
    participant({userId: "other", leftAt: oldTimestamp}),
  ]) {
    const {db, writes} = createFakeFirestore({
      ...validLeaveSeed({
        event: {participantsCount: 3, capacity: 3},
        chat: {readAccessUserIds: ["organizer", "uid", "other"]},
      }),
      "events/event-1/participants/other": otherParticipant,
    });

    await assertRejectsHttpsError(
        () => executeLeave({
          db,
          uid: "uid",
          leaveDate: fixedNow,
          leaveTimestamp: fixedTimestamp,
          payload: {eventId: "event-1"},
        }),
        "failed-precondition",
        "event_participant_state_inconsistent",
    );
    assert.deepEqual(writes, []);
  }
});

test("executeLeaveEventTransaction fails closed on invalid chat metadata", async () => {
  for (const chatSeed of [
    null,
    eventChat({eventId: "other-event"}),
    eventChat({status: "active"}),
    eventChat({canceledAt: null}),
    (() => {
      const chatData = eventChat();
      delete chatData.createdAt;
      return chatData;
    })(),
    (() => {
      const chatData = eventChat();
      delete chatData.updatedAt;
      return chatData;
    })(),
    eventChat({createdAt: "2026-06-16T10:00:00.000Z"}),
    eventChat({updatedAt: "2026-06-16T10:00:00.000Z"}),
    eventChat({readAccessUserIds: ["uid"]}),
    eventChat({readAccessUserIds: ["organizer"]}),
    eventChat({readAccessUserIds: ["organizer", "uid", "extra"]}),
    eventChat({readAccessUserIds: ["organizer", "uid", "uid"]}),
    eventChat({readAccessUserIds: ["organizer", "attacker"]}),
  ]) {
    const seed = {
      "events/event-1": activeEvent(),
      "events/event-1/participants/organizer": organizerParticipant(),
      "events/event-1/participants/uid": participant(),
    };
    if (chatSeed) {
      seed["eventChats/event-1"] = chatSeed;
    }
    const {db, writes} = createFakeFirestore(seed);

    await assertRejectsHttpsError(
        () => executeLeave({
          db,
          uid: "uid",
          leaveDate: fixedNow,
          leaveTimestamp: fixedTimestamp,
          payload: {eventId: "event-1"},
        }),
        "failed-precondition",
        "event_chat_metadata_invalid",
    );
    assert.deepEqual(writes, []);
  }
});
