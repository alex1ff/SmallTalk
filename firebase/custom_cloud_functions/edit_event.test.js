const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __private__: {
    executeEditEventTransaction,
    normalizeEditEventPayload,
  },
} = require("./edit_event");

const fixedNow = new Date("2026-06-16T10:00:00.000Z");
const fixedTimestamp = {
  toMillis: () => fixedNow.getTime(),
  toDate: () => fixedNow,
};
const futureStartsAt = {
  toMillis: () => Date.parse("2026-06-20T15:00:00.000Z"),
  toDate: () => new Date("2026-06-20T15:00:00.000Z"),
};
const pastStartsAt = {
  toMillis: () => Date.parse("2026-06-16T09:00:00.000Z"),
  toDate: () => new Date("2026-06-16T09:00:00.000Z"),
};

const validEditRequest = Object.freeze({
  eventId: "event-1",
  title: " Updated event ",
  description: " Updated   description ",
  languageCode: " en-US ",
  levelMin: "b1",
  levelMax: "c1",
  countryCode: " ru ",
  cityKey: "moscow",
  locationName: " Starbucks,   ул. Арбат, 5 ",
  locationGeoPoint: null,
  startsAt: "2026-06-20T15:00:00.000Z",
  capacity: 10,
});

function cloneValidEditRequest(overrides = {}) {
  return {
    ...validEditRequest,
    ...overrides,
  };
}

function counterData() {
  return {
    userId: "uid",
    dayKeyUtc: "2026-06-16",
    count: 1,
    eventIds: ["event-1"],
    requestEventIds: {request1: "event-1"},
    requestPayloadHashes: {request1: "a".repeat(64)},
    windowStartAt: fixedTimestamp,
    windowEndAt: fixedTimestamp,
    createdAt: fixedTimestamp,
    updatedAt: fixedTimestamp,
  };
}

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
    async get() {
      const data = store.get(path);
      return {
        exists: data !== undefined,
        data: () => data,
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

function eventData(overrides = {}) {
  return {
    organizerId: "uid",
    status: "active",
    canceledAt: null,
    startsAt: futureStartsAt,
    participantsCount: 3,
    capacity: 10,
    ...overrides,
  };
}

test("normalizeEditEventPayload rejects unknown and missing keys", () => {
  assertHttpsError(
      () => normalizeEditEventPayload(
          cloneValidEditRequest({unexpected: true}),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_edit_request",
      "unexpected",
      "unknown_key",
  );

  for (const key of Object.keys(validEditRequest)) {
    const missing = cloneValidEditRequest();
    delete missing[key];
    assertHttpsError(
        () => normalizeEditEventPayload(missing, {now: fixedNow}),
        "invalid-argument",
        "invalid_edit_request",
        key,
        "missing",
    );
  }
});

test("normalizeEditEventPayload normalizes city and editable fields", () => {
  const payload = normalizeEditEventPayload(
      cloneValidEditRequest(),
      {now: fixedNow},
  );

  assert.equal(payload.eventId, "event-1");
  assert.equal(payload.normalized.title, "Updated event");
  assert.equal(payload.normalized.description, "Updated description");
  assert.equal(payload.normalized.language.code, "en");
  assert.equal(payload.normalized.city.countryCode, "RU");
  assert.equal(payload.normalized.city.cityKey, "moscow");
  assert.equal(payload.normalized.city.cityNameRu, "Москва");
  assert.equal(payload.normalized.city.timeZoneId, "Europe/Moscow");
  assert.equal(payload.normalized.locationGeoPoint, null);
});

test("normalizeEditEventPayload remaps create validation errors", () => {
  assertHttpsError(
      () => normalizeEditEventPayload(
          cloneValidEditRequest({cityKey: "unknown_city"}),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_edit_request",
      "cityKey",
      "unknown_city",
  );
  assertHttpsError(
      () => normalizeEditEventPayload(
          cloneValidEditRequest({startsAt: "2026-06-16T09:00:00.000Z"}),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_edit_request",
      "startsAt",
      "past_starts_at",
  );
});

test("executeEditEventTransaction updates organizer active future event", async () => {
  const payload = normalizeEditEventPayload(
      cloneValidEditRequest({
        countryCode: "US",
        cityKey: "new_york",
        capacity: 5,
      }),
      {now: fixedNow},
  );
  const counterBefore = counterData();
  const {db, store, writes} = createFakeFirestore({
    "events/event-1": eventData(),
    "eventCreationCounters/uid/days/20260616": counterBefore,
  });

  const response = await executeEditEventTransaction({
    db,
    uid: "uid",
    editDate: fixedNow,
    editTimestamp: fixedTimestamp,
    payload,
  });
  const event = store.get("events/event-1");

  assert.deepEqual(response, {
    eventId: "event-1",
    updatedAt: "2026-06-16T10:00:00.000Z",
  });
  assert.equal(event.title, "Updated event");
  assert.equal(event.countryCode, "US");
  assert.equal(event.cityKey, "new_york");
  assert.equal(event.cityNameRu, "Нью-Йорк");
  assert.equal(event.timeZoneId, "America/New_York");
  assert.equal(event.capacity, 5);
  assert.equal(event.updatedAt, fixedTimestamp);
  assert.deepEqual(writes.map((write) => write.path), ["events/event-1"]);
  assert.strictEqual(
      store.get("eventCreationCounters/uid/days/20260616"),
      counterBefore,
  );
  assert.equal(
      writes.some((write) => write.path.includes("eventCreationCounters")),
      false,
  );
});

test("executeEditEventTransaction rejects non-organizer edit", async () => {
  const payload = normalizeEditEventPayload(
      cloneValidEditRequest(),
      {now: fixedNow},
  );
  const {db, writes} = createFakeFirestore({
    "events/event-1": eventData({organizerId: "other"}),
  });

  await assertRejectsHttpsError(
      () => executeEditEventTransaction({
        db,
        uid: "uid",
        editDate: fixedNow,
        editTimestamp: fixedTimestamp,
        payload,
      }),
      "permission-denied",
      "not_event_organizer",
  );
  assert.deepEqual(writes, []);
});

test("executeEditEventTransaction rejects canceled or past events", async () => {
  const payload = normalizeEditEventPayload(
      cloneValidEditRequest(),
      {now: fixedNow},
  );

  await assertRejectsHttpsError(
      () => executeEditEventTransaction({
        db: createFakeFirestore({
          "events/event-1": eventData({
            status: "canceled",
            canceledAt: fixedTimestamp,
          }),
        }).db,
        uid: "uid",
        editDate: fixedNow,
        editTimestamp: fixedTimestamp,
        payload,
      }),
      "failed-precondition",
      "event_not_editable",
  );
  await assertRejectsHttpsError(
      () => executeEditEventTransaction({
        db: createFakeFirestore({
          "events/event-1": eventData({startsAt: pastStartsAt}),
        }).db,
        uid: "uid",
        editDate: fixedNow,
        editTimestamp: fixedTimestamp,
        payload,
      }),
      "failed-precondition",
      "event_not_editable",
  );
  await assertRejectsHttpsError(
      () => executeEditEventTransaction({
        db: createFakeFirestore({
          "events/event-1": eventData({startsAt: null}),
        }).db,
        uid: "uid",
        editDate: fixedNow,
        editTimestamp: fixedTimestamp,
        payload,
      }),
      "failed-precondition",
      "event_not_editable",
  );
});

test("executeEditEventTransaction rejects capacity below participants", async () => {
  const payload = normalizeEditEventPayload(
      cloneValidEditRequest({capacity: 2}),
      {now: fixedNow},
  );
  const {db, writes} = createFakeFirestore({
    "events/event-1": eventData({participantsCount: 3}),
  });

  await assertRejectsHttpsError(
      () => executeEditEventTransaction({
        db,
        uid: "uid",
        editDate: fixedNow,
        editTimestamp: fixedTimestamp,
        payload,
      }),
      "failed-precondition",
      "capacity_below_participants_count",
  );
  assert.deepEqual(writes, []);
});
