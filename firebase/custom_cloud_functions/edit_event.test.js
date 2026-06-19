const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const {
  editEvent,
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

function repeatGrapheme(value, count) {
  return Array.from({length: count}, () => value).join("");
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

async function withAdminFirestore(db, callback) {
  const originalFirestore = Object.getOwnPropertyDescriptor(admin, "firestore");
  const timestamp = admin.firestore.Timestamp;
  const geoPoint = admin.firestore.GeoPoint;
  const firestore = () => db;
  firestore.Timestamp = timestamp;
  firestore.GeoPoint = geoPoint;

  Object.defineProperty(admin, "firestore", {
    configurable: true,
    value: firestore,
  });

  try {
    return await callback();
  } finally {
    if (originalFirestore) {
      Object.defineProperty(admin, "firestore", originalFirestore);
    } else {
      delete admin.firestore;
    }
  }
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
  assertHttpsError(
      () => normalizeEditEventPayload(
          cloneValidEditRequest({status: "active"}),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_edit_request",
      "status",
      "unknown_key",
  );
  assertHttpsError(
      () => normalizeEditEventPayload(
          cloneValidEditRequest({canceledAt: null}),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_edit_request",
      "canceledAt",
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

test("normalizeEditEventPayload remaps title validation errors", () => {
  for (const title of ["", " \t  "]) {
    assertHttpsError(
        () => normalizeEditEventPayload(
            cloneValidEditRequest({title}),
            {now: fixedNow},
        ),
        "invalid-argument",
        "invalid_edit_request",
        "title",
        "missing",
    );
  }

  for (const title of [
    "Title\nwith newline",
    "Title\rwith carriage return",
    "Title\r\nwith CRLF",
  ]) {
    assertHttpsError(
        () => normalizeEditEventPayload(
            cloneValidEditRequest({title}),
            {now: fixedNow},
        ),
        "invalid-argument",
        "invalid_edit_request",
        "title",
        "line_breaks_not_allowed",
    );
  }

  assertHttpsError(
      () => normalizeEditEventPayload(
          cloneValidEditRequest({title: repeatGrapheme("👍🏽", 71)}),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_edit_request",
      "title",
      "too_long",
  );
});

test("normalizeEditEventPayload accepts title boundary and Unicode input", () => {
  const seventyGraphemeTitle = repeatGrapheme("👍🏽", 70);
  const boundary = normalizeEditEventPayload(
      cloneValidEditRequest({title: ` ${seventyGraphemeTitle} `}),
      {now: fixedNow},
  );
  const unicode = normalizeEditEventPayload(
      cloneValidEditRequest({title: " Cafe\u0301  разговорный  клуб  東京  "}),
      {now: fixedNow},
  );

  assert.equal(Array.from(seventyGraphemeTitle).length > 70, true);
  assert.equal(boundary.normalized.title, seventyGraphemeTitle);
  assert.equal(
      boundary.normalized.hashPayload.title,
      seventyGraphemeTitle,
  );
  assert.equal(unicode.normalized.title, "Café разговорный клуб 東京");
  assert.equal(
      unicode.normalized.hashPayload.title,
      "Café разговорный клуб 東京",
  );
});

test("normalizeEditEventPayload remaps description validation errors", () => {
  for (const description of ["", " \t  ", "   \n \t "]) {
    assertHttpsError(
        () => normalizeEditEventPayload(
            cloneValidEditRequest({description}),
            {now: fixedNow},
        ),
        "invalid-argument",
        "invalid_edit_request",
        "description",
        "missing",
    );
  }

  assertHttpsError(
      () => normalizeEditEventPayload(
          cloneValidEditRequest({
            description: repeatGrapheme("👍🏽", 1001),
          }),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_edit_request",
      "description",
      "too_long",
  );
});

test("normalizeEditEventPayload accepts description boundary and Unicode input",
    () => {
      const thousandGraphemeDescription = repeatGrapheme("👍🏽", 1000);
      const boundary = normalizeEditEventPayload(
          cloneValidEditRequest({
            description: ` ${thousandGraphemeDescription} `,
          }),
          {now: fixedNow},
      );
      const multiline = normalizeEditEventPayload(
          cloneValidEditRequest({
            description:
              " Cafe\u0301   line \r\n\r\n\r\n  разговорный\tклуб \n\n\n 東京  ",
          }),
          {now: fixedNow},
      );

      assert.equal(
          Array.from(thousandGraphemeDescription).length > 1000,
          true,
      );
      assert.equal(
          boundary.normalized.description,
          thousandGraphemeDescription,
      );
      assert.equal(
          boundary.normalized.hashPayload.description,
          thousandGraphemeDescription,
      );
      assert.equal(
          multiline.normalized.description,
          "Café line\n\nразговорный клуб\n\n東京",
      );
      assert.equal(
          multiline.normalized.hashPayload.description,
          "Café line\n\nразговорный клуб\n\n東京",
      );
    });

test("normalizeEditEventPayload remaps capacity validation errors", () => {
  for (const currentCase of [
    {capacity: 1, reason: "out_of_range"},
    {capacity: 51, reason: "out_of_range"},
    {capacity: 10.5, reason: "invalid_type"},
  ]) {
    assertHttpsError(
        () => normalizeEditEventPayload(
            cloneValidEditRequest({capacity: currentCase.capacity}),
            {now: fixedNow},
        ),
        "invalid-argument",
        "invalid_edit_request",
        "capacity",
        currentCase.reason,
    );
  }
});

test("normalizeEditEventPayload accepts capacity bounds", () => {
  const minCapacity = normalizeEditEventPayload(
      cloneValidEditRequest({capacity: 2}),
      {now: fixedNow},
  );
  const maxCapacity = normalizeEditEventPayload(
      cloneValidEditRequest({capacity: 50}),
      {now: fixedNow},
  );

  assert.equal(minCapacity.normalized.capacity, 2);
  assert.equal(minCapacity.normalized.hashPayload.capacity, 2);
  assert.equal(maxCapacity.normalized.capacity, 50);
  assert.equal(maxCapacity.normalized.hashPayload.capacity, 50);
});

test("editEvent callable validates title before transaction writes", async () => {
  const cases = [
    {title: "", reason: "missing"},
    {title: " \t  ", reason: "missing"},
    {title: "Title\nwith newline", reason: "line_breaks_not_allowed"},
    {title: "Title\rwith carriage return", reason: "line_breaks_not_allowed"},
    {title: "Title\r\nwith CRLF", reason: "line_breaks_not_allowed"},
    {title: repeatGrapheme("👍🏽", 71), reason: "too_long"},
  ];

  for (const currentCase of cases) {
    const {db, reads, writes} = createFakeFirestore({
      "events/event-1": eventData(),
    });

    await withAdminFirestore(db, async () => {
      await assertRejectsHttpsError(
          () => editEvent.run(
              cloneValidEditRequest({title: currentCase.title}),
              {auth: {uid: "uid"}},
          ),
          "invalid-argument",
          "invalid_edit_request",
          "title",
          currentCase.reason,
      );
    });

    assert.deepEqual(reads, []);
    assert.deepEqual(writes, []);
  }
});

test("editEvent callable validates description before transaction writes",
    async () => {
      const cases = [
        {description: "", reason: "missing"},
        {description: " \t  ", reason: "missing"},
        {description: "   \n \t ", reason: "missing"},
        {description: repeatGrapheme("👍🏽", 1001), reason: "too_long"},
      ];

      for (const currentCase of cases) {
        const {db, reads, writes} = createFakeFirestore({
          "events/event-1": eventData(),
        });

        await withAdminFirestore(db, async () => {
          await assertRejectsHttpsError(
              () => editEvent.run(
                  cloneValidEditRequest({
                    description: currentCase.description,
                  }),
                  {auth: {uid: "uid"}},
              ),
              "invalid-argument",
              "invalid_edit_request",
              "description",
              currentCase.reason,
          );
        });

        assert.deepEqual(reads, []);
        assert.deepEqual(writes, []);
      }
    });

test("editEvent callable validates capacity before transaction writes",
    async () => {
      const cases = [
        {capacity: 1, reason: "out_of_range"},
        {capacity: 51, reason: "out_of_range"},
        {capacity: 10.5, reason: "invalid_type"},
      ];

      for (const currentCase of cases) {
        const {db, reads, writes} = createFakeFirestore({
          "events/event-1": eventData(),
        });

        await withAdminFirestore(db, async () => {
          await assertRejectsHttpsError(
              () => editEvent.run(
                  cloneValidEditRequest({capacity: currentCase.capacity}),
                  {auth: {uid: "uid"}},
              ),
              "invalid-argument",
              "invalid_edit_request",
              "capacity",
              currentCase.reason,
          );
        });

        assert.deepEqual(reads, []);
        assert.deepEqual(writes, []);
      }
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
  assert.equal(event.status, "active");
  assert.equal(event.canceledAt, null);
  assert.equal(event.updatedAt, fixedTimestamp);
  assert.deepEqual(writes.map((write) => write.path), ["events/event-1"]);
  assert.equal(
      Object.prototype.hasOwnProperty.call(writes[0].data, "status"),
      false,
  );
  assert.equal(
      Object.prototype.hasOwnProperty.call(writes[0].data, "canceledAt"),
      false,
  );
  assert.strictEqual(
      store.get("eventCreationCounters/uid/days/20260616"),
      counterBefore,
  );
  const counterAfter = store.get("eventCreationCounters/uid/days/20260616");
  assert.equal(counterAfter.count, 1);
  assert.deepEqual(counterAfter.eventIds, ["event-1"]);
  assert.deepEqual(counterAfter.requestEventIds, {request1: "event-1"});
  assert.deepEqual(counterAfter.requestPayloadHashes, {
    request1: "a".repeat(64),
  });
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
          "events/event-1": eventData({canceledAt: fixedTimestamp}),
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
