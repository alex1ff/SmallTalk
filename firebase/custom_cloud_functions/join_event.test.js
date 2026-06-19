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

function createFakeFirestore(seed = {}, {
  maxTransactionAttempts = 5,
  onBeforeCommit = null,
  retryOnConcurrentModification = false,
} = {}) {
  const store = new Map(Object.entries(seed));
  const versions = new Map(Array.from(store.keys(), (path) => [path, 0]));
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
        const attemptWrites = [];
        const readVersions = new Map();
        const writeLog = retryOnConcurrentModification ? attemptWrites : writes;
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
              readVersions.set(
                  refOrQuery.path,
                  versions.get(refOrQuery.path) || 0,
              );
            }
            return snapshot;
          },
          create(ref, data) {
            hasWrites = true;
            if (
              store.has(ref.path) ||
              pendingWrites.some((write) =>
                write.type === "create" && write.path === ref.path,
              )
            ) {
              throw new Error(`Document already exists: ${ref.path}`);
            }
            writeLog.push({type: "create", path: ref.path, data});
            pendingWrites.push({type: "create", path: ref.path, data});
          },
          update(ref, data) {
            hasWrites = true;
            if (!store.has(ref.path)) {
              throw new Error(`Document does not exist: ${ref.path}`);
            }
            writeLog.push({type: "update", path: ref.path, data});
            pendingWrites.push({type: "update", path: ref.path, data});
          },
        };
        const result = await callback(tx);
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
          writes.push(...attemptWrites);
        }
        for (const write of pendingWrites) {
          if (write.type === "create") {
            store.set(write.path, write.data);
          } else {
            store.set(write.path, {...store.get(write.path), ...write.data});
          }
          versions.set(write.path, (versions.get(write.path) || 0) + 1);
        }
        return result;
      }
      throw new Error("Simulated transaction retry limit exceeded");
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

function activeParticipantIds(store, eventId = "event-1") {
  return Array.from(store.entries())
      .filter(([path, data]) =>
        path.startsWith(`events/${eventId}/participants/`) &&
        data.status === "active",
      )
      .map(([path]) => path.split("/").pop())
      .sort();
}

function assertParticipantCountInvariant(store, eventId = "event-1") {
  const event = store.get(`events/${eventId}`);
  const activeIds = activeParticipantIds(store, eventId);
  assert.equal(event.participantsCount, activeIds.length);
  assert.equal(activeIds.includes(event.organizerId), true);
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
        () => normalizeJoinEventPayload({eventId: "event-1", [field]: "x"}),
        "invalid-argument",
        "invalid_join_request",
        field,
        "unknown_key",
    );
  }
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
  assertParticipantCountInvariant(store);
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
        "create:events/event-1/participants/uid",
        "update:eventChats/event-1",
      ],
  );
});

test("executeJoinEventTransaction allows join into last available seat",
    async () => {
      const counterBefore = counterData();
      const {db, store, writes} = createFakeFirestore({
        "events/event-1": activeEvent({participantsCount: 2, capacity: 3}),
        "eventChats/event-1": eventChat({
          readAccessUserIds: ["organizer", "user-a"],
        }),
        "events/event-1/participants/organizer": organizerParticipant(),
        "events/event-1/participants/user-a": participant({userId: "user-a"}),
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

      assert.equal(response.participantsCount, 3);
      assert.equal(store.get("events/event-1").participantsCount, 3);
      assert.deepEqual(activeParticipantIds(store), [
        "organizer",
        "uid",
        "user-a",
      ]);
      assert.deepEqual(store.get("eventChats/event-1").readAccessUserIds, [
        "organizer",
        "user-a",
        "uid",
      ]);
      assertParticipantCountInvariant(store);
      assert.strictEqual(
          store.get("eventCreationCounters/organizer/days/20260616"),
          counterBefore,
      );
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
  assertParticipantCountInvariant(store);
  assert.deepEqual(
      writes.map((write) => `${write.type}:${write.path}`),
      [
        "update:events/event-1",
        "update:events/event-1/participants/uid",
        "update:eventChats/event-1",
      ],
  );
  assert.deepEqual(writes[1].data, {
    displayName: "Марко",
    photoUrl: null,
    status: "active",
    joinedAt: fixedTimestamp,
    leftAt: null,
    updatedAt: fixedTimestamp,
  });
  for (const immutableField of ["userId", "role", "createdAt"]) {
    assert.equal(
        Object.prototype.hasOwnProperty.call(writes[1].data, immutableField),
        false,
    );
  }
});

test("executeJoinEventTransaction concurrent rejoins reuse one membership",
    async () => {
      let firstAttemptCommits = 0;
      let releaseFirstAttempts;
      const firstAttemptsReady = new Promise((resolve) => {
        releaseFirstAttempts = resolve;
      });
      const firstAttemptBarrierTimeout = setTimeout(() => {
        releaseFirstAttempts();
      }, 1000);
      const {db, store, writes} = createFakeFirestore(
          {
            "events/event-1": activeEvent({participantsCount: 1, capacity: 3}),
            "eventChats/event-1": eventChat({
              readAccessUserIds: ["organizer"],
            }),
            "events/event-1/participants/organizer": organizerParticipant(),
            "events/event-1/participants/uid": participant({
              status: "left",
              leftAt: oldTimestamp,
              createdAt: oldTimestamp,
              updatedAt: oldTimestamp,
            }),
            "users/uid": userProfile({display_name: "Марко Обновленный"}),
          },
          {
            retryOnConcurrentModification: true,
            onBeforeCommit: async ({attempt}) => {
              if (attempt !== 1) {
                return;
              }
              firstAttemptCommits += 1;
              if (firstAttemptCommits === 2) {
                releaseFirstAttempts();
              }
              await firstAttemptsReady;
            },
          },
      );

      const join = () => executeJoinEventTransaction({
        db,
        uid: "uid",
        joinDate: fixedNow,
        joinTimestamp: fixedTimestamp,
        payload: {eventId: "event-1"},
      });

      const results = await Promise.allSettled([join(), join()]);
      clearTimeout(firstAttemptBarrierTimeout);
      const fulfilled = results.filter((result) =>
        result.status === "fulfilled");
      const rejected = results.filter((result) =>
        result.status === "rejected");
      const membership = store.get("events/event-1/participants/uid");

      assert.equal(fulfilled.length, 1);
      assert.equal(rejected.length, 1);
      assert.equal(firstAttemptCommits, 2);
      assert.equal(rejected[0].reason.code, "failed-precondition");
      assert.deepEqual(rejected[0].reason.details, {
        domainCode: "already_joined",
      });
      assert.equal(store.get("events/event-1").participantsCount, 2);
      assert.deepEqual(activeParticipantIds(store), ["organizer", "uid"]);
      assertParticipantCountInvariant(store);
      assert.equal(membership.status, "active");
      assert.equal(membership.leftAt, null);
      assert.equal(membership.createdAt, oldTimestamp);
      assert.equal(membership.joinedAt, fixedTimestamp);
      assert.equal(membership.updatedAt, fixedTimestamp);
      assert.equal(membership.displayName, "Марко Обновленный");
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

test("executeJoinEventTransaction concurrent duplicate joins create one membership",
    async () => {
      let firstAttemptCommits = 0;
      let releaseFirstAttempts;
      const firstAttemptsReady = new Promise((resolve) => {
        releaseFirstAttempts = resolve;
      });
      const firstAttemptBarrierTimeout = setTimeout(() => {
        releaseFirstAttempts();
      }, 1000);
      const {db, store, writes} = createFakeFirestore(
          {
            "events/event-1": activeEvent({participantsCount: 1, capacity: 3}),
            "eventChats/event-1": eventChat({
              readAccessUserIds: ["organizer"],
            }),
            "events/event-1/participants/organizer": organizerParticipant(),
            "users/uid": userProfile(),
          },
          {
            retryOnConcurrentModification: true,
            onBeforeCommit: async ({attempt}) => {
              if (attempt !== 1) {
                return;
              }
              firstAttemptCommits += 1;
              if (firstAttemptCommits === 2) {
                releaseFirstAttempts();
              }
              await firstAttemptsReady;
            },
          },
      );

      const join = () => executeJoinEventTransaction({
        db,
        uid: "uid",
        joinDate: fixedNow,
        joinTimestamp: fixedTimestamp,
        payload: {eventId: "event-1"},
      });

      const results = await Promise.allSettled([join(), join()]);
      clearTimeout(firstAttemptBarrierTimeout);
      const fulfilled = results.filter((result) =>
        result.status === "fulfilled");
      const rejected = results.filter((result) =>
        result.status === "rejected");

      assert.equal(fulfilled.length, 1);
      assert.equal(rejected.length, 1);
      assert.equal(firstAttemptCommits, 2);
      assert.deepEqual(fulfilled[0].value, {
        eventId: "event-1",
        participantStatus: "active",
        participantsCount: 2,
        joinedAt: "2026-06-16T10:00:00.000Z",
      });
      assert.equal(rejected[0].reason.code, "failed-precondition");
      assert.deepEqual(rejected[0].reason.details, {
        domainCode: "already_joined",
      });
      assert.equal(store.get("events/event-1").participantsCount, 2);
      assert.deepEqual(activeParticipantIds(store), ["organizer", "uid"]);
      assertParticipantCountInvariant(store);
      assert.deepEqual(store.get("eventChats/event-1").readAccessUserIds, [
        "organizer",
        "uid",
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

test("executeJoinEventTransaction fails closed on participant count drift",
    async () => {
      for (const seed of [
        {
          "events/event-1": activeEvent({participantsCount: 1, capacity: 3}),
          "eventChats/event-1": eventChat({readAccessUserIds: ["organizer"]}),
          "events/event-1/participants/organizer": organizerParticipant(),
          "events/event-1/participants/user-a": participant({
            userId: "user-a",
          }),
          "users/uid": userProfile(),
        },
        {
          "events/event-1": activeEvent({participantsCount: 3, capacity: 3}),
          "eventChats/event-1": eventChat({readAccessUserIds: ["organizer"]}),
          "events/event-1/participants/organizer": organizerParticipant(),
          "users/uid": userProfile(),
        },
      ]) {
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
            "event_participant_state_inconsistent",
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
      "events/event-1/participants/user-a": participant({userId: "user-a"}),
      "events/event-1/participants/user-b": participant({userId: "user-b"}),
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

test("executeJoinEventTransaction rejects full event without partial writes",
    async () => {
      const eventBefore = activeEvent({participantsCount: 3, capacity: 3});
      const chatBefore = eventChat({
        readAccessUserIds: ["organizer", "user-a", "user-b"],
      });
      const counterBefore = counterData();
      const {db, store, writes} = createFakeFirestore({
        "events/event-1": eventBefore,
        "eventChats/event-1": chatBefore,
        "events/event-1/participants/organizer": organizerParticipant(),
        "events/event-1/participants/user-a": participant({userId: "user-a"}),
        "events/event-1/participants/user-b": participant({userId: "user-b"}),
        "users/uid": userProfile(),
        "eventCreationCounters/organizer/days/20260616": counterBefore,
      });

      await assert.rejects(
          () => executeJoinEventTransaction({
            db,
            uid: "uid",
            joinDate: fixedNow,
            joinTimestamp: fixedTimestamp,
            payload: {eventId: "event-1"},
          }),
          (err) => {
            assert.equal(err.code, "failed-precondition");
            assert.deepEqual(err.details, {
              domainCode: "event_full",
              participantsCount: 3,
              capacity: 3,
            });
            return true;
          },
      );

      assert.deepEqual(writes, []);
      assert.strictEqual(store.get("events/event-1"), eventBefore);
      assert.strictEqual(store.get("eventChats/event-1"), chatBefore);
      assert.strictEqual(
          store.get("eventCreationCounters/organizer/days/20260616"),
          counterBefore,
      );
      assert.equal(store.has("events/event-1/participants/uid"), false);
      assert.deepEqual(activeParticipantIds(store), [
        "organizer",
        "user-a",
        "user-b",
      ]);
      assert.deepEqual(chatBefore.readAccessUserIds, [
        "organizer",
        "user-a",
        "user-b",
      ]);
    });

test("executeJoinEventTransaction concurrent joins never exceed capacity",
    async () => {
      let firstAttemptCommits = 0;
      let releaseFirstAttempts;
      const firstAttemptsReady = new Promise((resolve) => {
        releaseFirstAttempts = resolve;
      });
      const firstAttemptBarrierTimeout = setTimeout(() => {
        releaseFirstAttempts();
      }, 1000);
      const {db, store, writes} = createFakeFirestore(
          {
            "events/event-1": activeEvent({participantsCount: 2, capacity: 3}),
            "eventChats/event-1": eventChat({
              readAccessUserIds: ["organizer", "user-a"],
            }),
            "events/event-1/participants/organizer": organizerParticipant(),
            "events/event-1/participants/user-a": participant({
              userId: "user-a",
            }),
            "users/uid-a": userProfile({display_name: "Алекс"}),
            "users/uid-b": userProfile({display_name: "Ольга"}),
          },
          {
            retryOnConcurrentModification: true,
            onBeforeCommit: async ({attempt}) => {
              if (attempt !== 1) {
                return;
              }
              firstAttemptCommits += 1;
              if (firstAttemptCommits === 2) {
                releaseFirstAttempts();
              }
              await firstAttemptsReady;
            },
          },
      );

      const join = (uid) => executeJoinEventTransaction({
        db,
        uid,
        joinDate: fixedNow,
        joinTimestamp: fixedTimestamp,
        payload: {eventId: "event-1"},
      });

      const results = await Promise.allSettled([join("uid-a"), join("uid-b")]);
      clearTimeout(firstAttemptBarrierTimeout);
      const fulfilled = results.filter((result) =>
        result.status === "fulfilled");
      const rejected = results.filter((result) =>
        result.status === "rejected");

      assert.equal(fulfilled.length, 1);
      assert.equal(rejected.length, 1);
      assert.equal(firstAttemptCommits, 2);
      assert.equal(rejected[0].reason.code, "failed-precondition");
      assert.deepEqual(rejected[0].reason.details, {
        domainCode: "event_full",
        participantsCount: 3,
        capacity: 3,
      });
      assert.equal(store.get("events/event-1").participantsCount, 3);
      assertParticipantCountInvariant(store);

      const joinedUid = ["uid-a", "uid-b"].find((uid) =>
        store.has(`events/event-1/participants/${uid}`));
      const rejectedUid = ["uid-a", "uid-b"].find((uid) => uid !== joinedUid);
      assert.ok(joinedUid);
      assert.equal(store.has(`events/event-1/participants/${rejectedUid}`),
          false);
      assert.deepEqual(activeParticipantIds(store), [
        "organizer",
        joinedUid,
        "user-a",
      ].sort());
      assert.deepEqual(store.get("eventChats/event-1").readAccessUserIds, [
        "organizer",
        "user-a",
        joinedUid,
      ]);
      assert.deepEqual(
          writes.map((write) => `${write.type}:${write.path}`),
          [
            "update:events/event-1",
            `create:events/event-1/participants/${joinedUid}`,
            "update:eventChats/event-1",
          ],
      );
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
