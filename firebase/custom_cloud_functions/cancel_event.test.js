const fs = require("node:fs");
const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __private__: {
    executeCancelEventTransaction,
    normalizeCancelEventPayload,
  },
} = require("./cancel_event");

const fixedNow = new Date("2026-06-16T10:00:00.000Z");
const fixedTimestamp = {
  toMillis: () => fixedNow.getTime(),
  toDate: () => fixedNow,
};
const originalCanceledAt = {
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
      let hasWrites = false;
      const pendingWrites = [];
      const tx = {
        async get(refOrQuery) {
          if (hasWrites) {
            throw new Error("Firestore transactions require reads first");
          }
          reads.push(refOrQuery.path);
          return refOrQuery.get();
        },
        update(ref, data) {
          hasWrites = true;
          if (!store.has(ref.path)) {
            throw new Error(`Document does not exist: ${ref.path}`);
          }
          writes.push({type: "update", path: ref.path, data});
          pendingWrites.push({path: ref.path, data});
        },
      };
      const result = await callback(tx);
      for (const write of pendingWrites) {
        store.set(write.path, {...store.get(write.path), ...write.data});
      }
      return result;
    },
  };

  return {db, reads, store, writes};
}

function activeEvent(overrides = {}) {
  return {
    organizerId: "uid",
    chatId: "event-1",
    status: "active",
    canceledAt: null,
    participantsCount: 3,
    capacity: 10,
    ...overrides,
  };
}

function eventChat(overrides = {}) {
  return {
    eventId: "event-1",
    readAccessUserIds: ["uid"],
    createdAt: fixedTimestamp,
    updatedAt: fixedTimestamp,
    ...overrides,
  };
}

function participant(status = "active") {
  return {
    status,
    role: "participant",
    joinedAt: fixedTimestamp,
    leftAt: status === "left" ? fixedTimestamp : null,
  };
}

function counterData() {
  return {
    userId: "uid",
    dayKeyUtc: "2026-06-16",
    count: 4,
    eventIds: ["event-a", "event-b", "event-c", "event-1"],
    requestEventIds: {
      req1: "event-a",
      req2: "event-b",
      req3: "event-c",
      req4: "event-1",
    },
    requestPayloadHashes: {
      req1: "a".repeat(64),
      req2: "b".repeat(64),
      req3: "c".repeat(64),
      req4: "d".repeat(64),
    },
    windowStartAt: fixedTimestamp,
    windowEndAt: fixedTimestamp,
    createdAt: fixedTimestamp,
    updatedAt: fixedTimestamp,
  };
}

test("normalizeCancelEventPayload rejects unknown and missing keys", () => {
  for (const field of ["status", "canceledAt", "updatedAt"]) {
    assertHttpsError(
        () => normalizeCancelEventPayload({
          eventId: "event-1",
          [field]: field === "status" ? "canceled" : fixedNow.toISOString(),
        }),
        "invalid-argument",
        "invalid_cancel_request",
        field,
        "unknown_key",
    );
  }
  assertHttpsError(
      () => normalizeCancelEventPayload({}),
      "invalid-argument",
      "invalid_cancel_request",
      "eventId",
      "missing",
  );
  assertHttpsError(
      () => normalizeCancelEventPayload({eventId: "events/event-1"}),
      "invalid-argument",
      "invalid_cancel_request",
      "eventId",
      "invalid_format",
  );
});

test("cancelEvent callable captures trusted backend timestamp", () => {
  const source = fs.readFileSync(require.resolve("./cancel_event"), "utf8");

  assert.match(source, /const cancelDate = new Date\(\);/);
  assert.match(
      source,
      /const cancelTimestamp = admin\.firestore\.Timestamp\.fromDate\(cancelDate\);/,
  );
  assert.match(source, /executeCancelEventTransaction\(\{[\s\S]*cancelDate,/);
  assert.match(source, /executeCancelEventTransaction\(\{[\s\S]*cancelTimestamp,/);
  assert.doesNotMatch(source, /serverTimestamp/);
});

test("executeCancelEventTransaction cancels active event without counter writes", async () => {
  const counterBefore = counterData();
  const {db, reads, store, writes} = createFakeFirestore({
    "events/event-1": activeEvent(),
    "eventChats/event-1": eventChat({
      readAccessUserIds: ["uid", "left-before-cancel"],
    }),
    "events/event-1/participants/uid": participant("active"),
    "events/event-1/participants/alex": participant("active"),
    "events/event-1/participants/olga": participant("active"),
    "events/event-1/participants/left-before-cancel": participant("left"),
    "eventCreationCounters/uid/days/20260616": counterBefore,
  });

  const response = await executeCancelEventTransaction({
    db,
    uid: "uid",
    cancelDate: fixedNow,
    cancelTimestamp: fixedTimestamp,
    payload: {eventId: "event-1"},
  });

  assert.deepEqual(response, {
    eventId: "event-1",
    status: "canceled",
    canceledAt: "2026-06-16T10:00:00.000Z",
  });
  assert.equal(store.get("events/event-1").status, "canceled");
  assert.equal(store.get("events/event-1").canceledAt, fixedTimestamp);
  assert.equal(store.get("events/event-1").participantsCount, 3);
  assert.deepEqual(writes[0].data, {
    status: "canceled",
    canceledAt: fixedTimestamp,
    updatedAt: fixedTimestamp,
  });
  assert.equal(writes[1].data.updatedAt, fixedTimestamp);
  assert.deepEqual(
      store.get("eventChats/event-1").readAccessUserIds,
      ["uid", "alex", "olga"],
  );
  assert.strictEqual(
      store.get("eventCreationCounters/uid/days/20260616"),
      counterBefore,
  );
  const counterAfter = store.get("eventCreationCounters/uid/days/20260616");
  assert.equal(counterAfter.count, 4);
  assert.deepEqual(
      counterAfter.eventIds,
      ["event-a", "event-b", "event-c", "event-1"],
  );
  assert.deepEqual(counterAfter.requestEventIds, counterBefore.requestEventIds);
  assert.deepEqual(
      counterAfter.requestPayloadHashes,
      counterBefore.requestPayloadHashes,
  );
  assert.deepEqual(
      writes.map((write) => `${write.type}:${write.path}`),
      ["update:events/event-1", "update:eventChats/event-1"],
  );
  assert.equal(
      writes.some((write) => write.path.includes("eventCreationCounters")),
      false,
  );
  assert.deepEqual(reads, [
    "events/event-1",
    "eventChats/event-1",
    "events/event-1/participants?status==active",
  ]);
});

test("executeCancelEventTransaction rejects non-organizer without writes", async () => {
  const {db, writes} = createFakeFirestore({
    "events/event-1": activeEvent({organizerId: "other"}),
    "eventChats/event-1": eventChat(),
  });

  await assertRejectsHttpsError(
      () => executeCancelEventTransaction({
        db,
        uid: "uid",
        cancelDate: fixedNow,
        cancelTimestamp: fixedTimestamp,
        payload: {eventId: "event-1"},
      }),
      "permission-denied",
      "not_event_organizer",
  );
  assert.deepEqual(writes, []);
});

test("executeCancelEventTransaction fails closed on invalid chat metadata", async () => {
  await assertRejectsHttpsError(
      () => executeCancelEventTransaction({
        db: createFakeFirestore({
          "events/event-1": activeEvent(),
        }).db,
        uid: "uid",
        cancelDate: fixedNow,
        cancelTimestamp: fixedTimestamp,
        payload: {eventId: "event-1"},
      }),
      "failed-precondition",
      "event_chat_metadata_invalid",
  );

  const {db, writes} = createFakeFirestore({
    "events/event-1": activeEvent(),
    "eventChats/event-1": eventChat({eventId: "other-event"}),
  });

  await assertRejectsHttpsError(
      () => executeCancelEventTransaction({
        db,
        uid: "uid",
        cancelDate: fixedNow,
        cancelTimestamp: fixedTimestamp,
        payload: {eventId: "event-1"},
      }),
      "failed-precondition",
      "event_chat_metadata_invalid",
  );
  assert.deepEqual(writes, []);
});

test("executeCancelEventTransaction fails closed on event chat id mismatch", async () => {
  const {db, writes} = createFakeFirestore({
    "events/event-1": activeEvent({chatId: "other-chat"}),
    "eventChats/event-1": eventChat(),
  });

  await assertRejectsHttpsError(
      () => executeCancelEventTransaction({
        db,
        uid: "uid",
        cancelDate: fixedNow,
        cancelTimestamp: fixedTimestamp,
        payload: {eventId: "event-1"},
      }),
      "failed-precondition",
      "event_chat_metadata_invalid",
  );
  assert.deepEqual(writes, []);
});

test("executeCancelEventTransaction returns idempotent canceled response", async () => {
  const counterBefore = counterData();
  const {db, reads, store, writes} = createFakeFirestore({
    "events/event-1": activeEvent({
      status: "canceled",
      canceledAt: originalCanceledAt,
    }),
    "eventChats/event-1": eventChat({
      readAccessUserIds: ["uid", "alex"],
      updatedAt: originalCanceledAt,
    }),
    "events/event-1/participants/new-user": participant("active"),
    "eventCreationCounters/uid/days/20260616": counterBefore,
  });

  const response = await executeCancelEventTransaction({
    db,
    uid: "uid",
    cancelDate: fixedNow,
    cancelTimestamp: fixedTimestamp,
    payload: {eventId: "event-1"},
  });

  assert.deepEqual(response, {
    eventId: "event-1",
    status: "canceled",
    canceledAt: "2026-06-15T10:00:00.000Z",
  });
  assert.equal(store.get("events/event-1").status, "canceled");
  assert.equal(store.get("events/event-1").canceledAt, originalCanceledAt);
  assert.deepEqual(store.get("eventChats/event-1").readAccessUserIds, [
    "uid",
    "alex",
  ]);
  assert.equal(store.get("eventChats/event-1").updatedAt, originalCanceledAt);
  assert.strictEqual(
      store.get("eventCreationCounters/uid/days/20260616"),
      counterBefore,
  );
  const counterAfter = store.get("eventCreationCounters/uid/days/20260616");
  assert.equal(counterAfter.count, 4);
  assert.deepEqual(
      counterAfter.eventIds,
      ["event-a", "event-b", "event-c", "event-1"],
  );
  assert.deepEqual(counterAfter.requestEventIds, counterBefore.requestEventIds);
  assert.deepEqual(
      counterAfter.requestPayloadHashes,
      counterBefore.requestPayloadHashes,
  );
  assert.deepEqual(reads, ["events/event-1", "eventChats/event-1"]);
  assert.deepEqual(writes, []);
});

test("executeCancelEventTransaction rejects non-active statuses without writes", async () => {
  for (const status of ["draft", "completed", "deleted", "archived"]) {
    const {db, writes} = createFakeFirestore({
      "events/event-1": activeEvent({status}),
      "eventChats/event-1": eventChat(),
    });

    await assertRejectsHttpsError(
        () => executeCancelEventTransaction({
          db,
          uid: "uid",
          cancelDate: fixedNow,
          cancelTimestamp: fixedTimestamp,
          payload: {eventId: "event-1"},
        }),
        "failed-precondition",
        "event_not_cancelable",
    );
    assert.deepEqual(writes, [], status);
  }
});

test("executeCancelEventTransaction fails closed on corrupt canceled event", async () => {
  for (const canceledAt of [null, "bad"]) {
    const {db, writes} = createFakeFirestore({
      "events/event-1": activeEvent({
        status: "canceled",
        canceledAt,
      }),
      "eventChats/event-1": eventChat(),
    });

    await assertRejectsHttpsError(
        () => executeCancelEventTransaction({
          db,
          uid: "uid",
          cancelDate: fixedNow,
          cancelTimestamp: fixedTimestamp,
          payload: {eventId: "event-1"},
        }),
        "failed-precondition",
        "event_cancellation_inconsistent",
    );
    assert.deepEqual(writes, []);
  }
});

test("executeCancelEventTransaction rejects active event with cancellation timestamp", async () => {
  const {db, writes} = createFakeFirestore({
    "events/event-1": activeEvent({canceledAt: originalCanceledAt}),
    "eventChats/event-1": eventChat(),
  });

  await assertRejectsHttpsError(
      () => executeCancelEventTransaction({
        db,
        uid: "uid",
        cancelDate: fixedNow,
        cancelTimestamp: fixedTimestamp,
        payload: {eventId: "event-1"},
      }),
      "failed-precondition",
      "event_not_cancelable",
  );
  assert.deepEqual(writes, []);
});
