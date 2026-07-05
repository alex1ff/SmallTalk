const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  __private__: {
    DEFAULT_HISTORY_LIMIT,
    MAX_HISTORY_LIMIT,
    getEventHistoryHandler,
    normalizeGetEventHistoryPayload,
  },
} = require("./get_event_history");

function timestamp(iso) {
  const date = new Date(iso);
  return {
    toMillis: () => date.getTime(),
    toDate: () => date,
  };
}

function timestampMillis(value) {
  if (!value) {
    return null;
  }
  if (typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  return null;
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
  const collectionGroupCalls = [];

  const makeSnapshot = (docPath) => {
    const data = store.get(docPath);
    return {
      exists: data !== undefined,
      ref: makeDocumentRef(docPath),
      data: () => data,
    };
  };

  const makeCollectionRef = (collectionPath) => {
    const segments = collectionPath.split("/");
    const parentPath = segments.length > 1 ?
      segments.slice(0, -1).join("/") :
      null;
    return {
      path: collectionPath,
      id: segments[segments.length - 1],
      parent: parentPath ? makeDocumentRef(parentPath) : null,
      doc(id) {
        return makeDocumentRef(`${collectionPath}/${id}`);
      },
    };
  };

  const makeDocumentRef = (docPath) => {
    const segments = docPath.split("/");
    return {
      path: docPath,
      id: segments[segments.length - 1],
      parent: makeCollectionRef(segments.slice(0, -1).join("/")),
      collection(name) {
        return makeCollectionRef(`${docPath}/${name}`);
      },
      async get() {
        return makeSnapshot(docPath);
      },
    };
  };

  const makeCollectionGroupQuery = (
      collectionId,
      filters = [],
      orders = [],
      limitCount = null,
  ) => ({
    where(field, operator, value) {
      return makeCollectionGroupQuery(
          collectionId,
          [...filters, {field, operator, value}],
          orders,
          limitCount,
      );
    },
    orderBy(field, direction = "asc") {
      return makeCollectionGroupQuery(
          collectionId,
          filters,
          [...orders, {field, direction}],
          limitCount,
      );
    },
    limit(value) {
      return makeCollectionGroupQuery(
          collectionId,
          filters,
          orders,
          value,
      );
    },
    async get() {
      collectionGroupCalls.push({collectionId, filters, orders, limitCount});
      let docs = [...store.entries()]
          .filter(([docPath]) => matchesCollectionGroup(docPath, collectionId))
          .map(([docPath]) => makeSnapshot(docPath));
      for (const filter of filters) {
        assert.equal(filter.operator, "==");
        docs = docs.filter((doc) => {
          const data = doc.data() || {};
          return data[filter.field] === filter.value;
        });
      }
      for (const order of [...orders].reverse()) {
        docs.sort((left, right) => {
          const leftValue = timestampMillis((left.data() || {})[order.field]);
          const rightValue = timestampMillis((right.data() || {})[order.field]);
          const comparison = (leftValue || 0) - (rightValue || 0);
          return order.direction === "desc" ? -comparison : comparison;
        });
      }
      if (limitCount !== null) {
        docs = docs.slice(0, limitCount);
      }
      return {docs};
    },
  });

  const db = {
    collection(name) {
      return makeCollectionRef(name);
    },
    collectionGroup(collectionId) {
      return makeCollectionGroupQuery(collectionId);
    },
    async getAll(...refs) {
      return Promise.all(refs.map((ref) => ref.get()));
    },
  };

  return {db, collectionGroupCalls, store};
}

function matchesCollectionGroup(docPath, collectionId) {
  const segments = docPath.split("/");
  return segments.length % 2 === 0 &&
    segments[segments.length - 2] === collectionId;
}

function event(overrides = {}) {
  return {
    organizerId: "organizer-1",
    title: "Conversation club",
    status: "active",
    canceledAt: null,
    startsAt: timestamp("2026-06-20T10:00:00.000Z"),
    timeZoneId: "Europe/Moscow",
    locationName: "Starbucks, Arbat 5",
    countryCode: "RU",
    cityKey: "moscow",
    cityNameEn: "Moscow",
    cityNameRu: "Москва",
    languageCode: "en",
    languageNameEn: "English",
    languageNameRu: "Английский",
    levelMin: "B1",
    levelMax: "C1",
    ...overrides,
  };
}

function participant(overrides = {}) {
  return {
    userId: "student-1",
    role: "participant",
    status: "active",
    joinedAt: timestamp("2026-06-10T10:00:00.000Z"),
    leftAt: null,
    ...overrides,
  };
}

test("normalizeGetEventHistoryPayload validates exact optional payload", () => {
  assert.deepEqual(normalizeGetEventHistoryPayload(undefined), {
    limit: DEFAULT_HISTORY_LIMIT,
  });
  assert.deepEqual(normalizeGetEventHistoryPayload({}), {
    limit: DEFAULT_HISTORY_LIMIT,
  });
  assert.deepEqual(normalizeGetEventHistoryPayload({limit: MAX_HISTORY_LIMIT}), {
    limit: MAX_HISTORY_LIMIT,
  });

  for (const payload of ["bad", []]) {
    assertHttpsError(
        () => normalizeGetEventHistoryPayload(payload),
        "invalid-argument",
        "invalid_event_history_request",
        "payload",
        "invalid_type",
    );
  }
  assertHttpsError(
      () => normalizeGetEventHistoryPayload({eventId: "spoof"}),
      "invalid-argument",
      "invalid_event_history_request",
      "eventId",
      "unknown_key",
  );
  for (const value of [0, 51, 1.5, "20"]) {
    assertHttpsError(
        () => normalizeGetEventHistoryPayload({limit: value}),
        "invalid-argument",
        "invalid_event_history_request",
        "limit",
    );
  }
});

test("getEventHistoryHandler rejects missing auth", async () => {
  const {db} = createFakeFirestore();

  await assertRejectsHttpsError(
      () => getEventHistoryHandler(
          {limit: 5},
          {},
          {db, now: new Date("2026-06-16T10:00:00.000Z")},
      ),
      "unauthenticated",
      "auth_required",
  );
});

test("getEventHistoryHandler returns sorted eligible event history", async () => {
  const now = new Date("2026-06-16T10:00:00.000Z");
  const {db, collectionGroupCalls} = createFakeFirestore({
    "events/upcoming-soon": event({
      title: "Coffee talk",
      startsAt: timestamp("2026-06-20T10:00:00.000Z"),
    }),
    "events/upcoming-later": event({
      title: "Dinner practice",
      startsAt: timestamp("2026-07-01T18:00:00.000Z"),
    }),
    "events/left-future": event({
      title: "Left future event",
      startsAt: timestamp("2026-07-03T18:00:00.000Z"),
    }),
    "events/canceled-active": event({
      title: "Canceled club",
      status: "canceled",
      canceledAt: timestamp("2026-06-15T10:00:00.000Z"),
      startsAt: timestamp("2026-06-25T10:00:00.000Z"),
    }),
    "events/past": event({
      title: "Past club",
      startsAt: timestamp("2026-06-01T10:00:00.000Z"),
    }),
    "events/canceled-left": event({
      title: "Canceled after leave",
      status: "canceled",
      canceledAt: timestamp("2026-06-15T10:00:00.000Z"),
      startsAt: timestamp("2026-06-24T10:00:00.000Z"),
    }),
    "events/malformed": event({
      title: "",
      startsAt: timestamp("2026-06-23T10:00:00.000Z"),
    }),
    "events/upcoming-soon/participants/student-1": participant({
      joinedAt: timestamp("2026-06-10T10:00:00.000Z"),
    }),
    "events/upcoming-later/participants/student-1": participant({
      joinedAt: timestamp("2026-06-11T10:00:00.000Z"),
    }),
    "events/left-future/participants/student-1": participant({
      status: "left",
      joinedAt: timestamp("2026-06-12T10:00:00.000Z"),
      leftAt: timestamp("2026-06-13T10:00:00.000Z"),
    }),
    "events/canceled-active/participants/student-1": participant({
      joinedAt: timestamp("2026-06-13T10:00:00.000Z"),
    }),
    "events/past/participants/student-1": participant({
      joinedAt: timestamp("2026-06-09T10:00:00.000Z"),
    }),
    "events/canceled-left/participants/student-1": participant({
      status: "left",
      joinedAt: timestamp("2026-06-08T10:00:00.000Z"),
      leftAt: timestamp("2026-06-14T10:00:00.000Z"),
    }),
    "events/malformed/participants/student-1": participant({
      joinedAt: timestamp("2026-06-07T10:00:00.000Z"),
    }),
    "events/upcoming-soon/participants/other-user": participant({
      userId: "other-user",
      joinedAt: timestamp("2026-06-20T10:00:00.000Z"),
    }),
  });

  const result = await getEventHistoryHandler(
      {limit: 5},
      {auth: {uid: "student-1"}},
      {db, now},
  );

  assert.deepEqual(
      result.items.map((item) => [item.eventId, item.timelineStatus]),
      [
        ["upcoming-soon", "upcoming"],
        ["upcoming-later", "upcoming"],
        ["left-future", "left"],
        ["canceled-active", "canceled"],
        ["past", "past"],
      ],
  );
  assert.equal(result.limit, 5);
  assert.equal(result.generatedAt, "2026-06-16T10:00:00.000Z");
  assert.deepEqual(result.items[0], {
    eventId: "upcoming-soon",
    title: "Coffee talk",
    startsAt: "2026-06-20T10:00:00.000Z",
    timeZoneId: "Europe/Moscow",
    status: "active",
    canceledAt: null,
    participantRole: "participant",
    participantStatus: "active",
    joinedAt: "2026-06-10T10:00:00.000Z",
    leftAt: null,
    timelineStatus: "upcoming",
    locationName: "Starbucks, Arbat 5",
    countryCode: "RU",
    cityKey: "moscow",
    cityNameEn: "Moscow",
    cityNameRu: "Москва",
    languageCode: "en",
    languageNameEn: "English",
    languageNameRu: "Английский",
    levelMin: "B1",
    levelMax: "C1",
  });
  assert.deepEqual(collectionGroupCalls[0], {
    collectionId: "participants",
    filters: [{field: "userId", operator: "==", value: "student-1"}],
    orders: [{field: "joinedAt", direction: "desc"}],
    limitCount: 15,
  });
});

test("getEventHistoryHandler includes canceled events for organizers", async () => {
  const {db} = createFakeFirestore({
    "events/canceled-owned": event({
      organizerId: "organizer-1",
      title: "Owned canceled",
      status: "canceled",
      canceledAt: timestamp("2026-06-15T10:00:00.000Z"),
      startsAt: timestamp("2026-06-25T10:00:00.000Z"),
    }),
    "events/canceled-owned/participants/organizer-1": participant({
      userId: "organizer-1",
      role: "organizer",
      status: "active",
      joinedAt: timestamp("2026-06-10T10:00:00.000Z"),
    }),
  });

  const result = await getEventHistoryHandler(
      {limit: 5},
      {auth: {uid: "organizer-1"}},
      {db, now: new Date("2026-06-16T10:00:00.000Z")},
  );

  assert.deepEqual(result.items.map((item) => item.eventId), [
    "canceled-owned",
  ]);
  assert.equal(result.items[0].participantRole, "organizer");
  assert.equal(result.items[0].timelineStatus, "canceled");
});

test("firestore indexes contain event history participants collection group index", () => {
  const indexes = JSON.parse(fs.readFileSync(
      path.join(__dirname, "..", "firestore.indexes.json"),
      "utf8",
  ));
  const hasParticipantsHistoryIndex = indexes.indexes.some((index) =>
    index.collectionGroup === "participants" &&
      index.queryScope === "COLLECTION" &&
      JSON.stringify(index.fields) === JSON.stringify([
        {fieldPath: "userId", order: "ASCENDING"},
        {fieldPath: "joinedAt", order: "DESCENDING"},
        {fieldPath: "__name__", order: "DESCENDING"},
      ]),
  );

  assert.equal(hasParticipantsHistoryIndex, true);
});
