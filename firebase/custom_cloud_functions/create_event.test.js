const fs = require("node:fs");
const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const {
  createEvent,
  __private__: {
    CREATE_EVENT_KEYS,
    DAILY_CREATE_LIMIT,
    buildCreateRequestMarker,
    buildDailyCreation,
    buildEventChatData,
    buildEventData,
    buildExistingCreateResponse,
    buildNextCounterState,
    buildOrganizerParticipantData,
    buildOrganizerSnapshot,
    buildUtcDayInfo,
    canonicalize,
    executeCreateEventTransaction,
    hashCreatePayload,
    normalizeCreateEventPayload,
    validateExistingCounter,
  },
} = require("./create_event");

const fixedNow = new Date("2026-06-16T10:00:00.000Z");
const fixedTimestamp = {
  toMillis: () => fixedNow.getTime(),
  toDate: () => fixedNow,
};
const fixedUpdatedTimestamp = {
  toMillis: () => fixedNow.getTime() + 1000,
  toDate: () => new Date(fixedNow.getTime() + 1000),
};
const HASH_1 = "a".repeat(64);
const HASH_2 = "b".repeat(64);
const HASH_3 = "c".repeat(64);
const ISO_UTC_MILLIS_RE =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;
const EXPECTED_CREATE_EVENT_KEYS = Object.freeze([
  "createRequestId",
  "title",
  "description",
  "languageCode",
  "levelMin",
  "levelMax",
  "countryCode",
  "cityKey",
  "locationName",
  "locationGeoPoint",
  "startsAt",
  "capacity",
]);
const EXPECTED_DAILY_COUNTER_KEYS = Object.freeze([
  "count",
  "createdAt",
  "dayKeyUtc",
  "eventIds",
  "requestEventIds",
  "requestPayloadHashes",
  "updatedAt",
  "userId",
  "windowEndAt",
  "windowStartAt",
]);
const validRequest = Object.freeze({
  createRequestId: "550e8400-e29b-41d4-a716-446655440000",
  title: " Разговорный  клуб: кофе и английский ",
  description: " Неформальная   встреча\n\n\nдля практики. ",
  languageCode: " EN-us ",
  levelMin: " b1 ",
  levelMax: "c1",
  countryCode: " ru ",
  cityKey: "moscow",
  locationName: " Starbucks,   ул. Арбат, 5 ",
  locationGeoPoint: {latitude: 55.7522, longitude: 37.6156},
  startsAt: "2026-06-20T15:00:00.000Z",
  capacity: 10,
});

function cloneValidRequest(overrides = {}) {
  return {
    ...validRequest,
    locationGeoPoint: {...validRequest.locationGeoPoint},
    ...overrides,
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

function createFakeFirestore(seed = {}, {
  eventId = "event-new",
  failAfterBufferedWrites = null,
  failBeforeCommit = false,
} = {}) {
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
        doc(id = eventId) {
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
          if (
            store.has(ref.path) ||
            pendingWrites.some((write) =>
              write.type === "create" && write.path === ref.path,
            )
          ) {
            throw new Error(`Document already exists: ${ref.path}`);
          }
          pendingWrites.push({type: "create", path: ref.path, data});
          writes.push({type: "create", path: ref.path, data});
          if (pendingWrites.length === failAfterBufferedWrites) {
            throw new Error(
                `Simulated transaction interruption after ${pendingWrites.length} writes`,
            );
          }
        },
        set(ref, data) {
          hasWrites = true;
          pendingWrites.push({type: "set", path: ref.path, data});
          writes.push({type: "set", path: ref.path, data});
          if (pendingWrites.length === failAfterBufferedWrites) {
            throw new Error(
                `Simulated transaction interruption after ${pendingWrites.length} writes`,
            );
          }
        },
      };
      const result = await callback(tx);
      if (failBeforeCommit) {
        throw new Error("Simulated transaction commit failure");
      }
      for (const write of pendingWrites) {
        store.set(write.path, write.data);
      }
      return result;
    },
  };

  return {db, makeRef, reads, store, writes};
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

async function withSequencedDate(isoValues, callback) {
  const RealDate = Date;
  const millisValues = isoValues.map((isoValue) => RealDate.parse(isoValue));
  let noArgDateCalls = 0;

  class SequencedDate extends RealDate {
    constructor(...args) {
      if (args.length === 0) {
        const index = Math.min(noArgDateCalls, millisValues.length - 1);
        noArgDateCalls += 1;
        super(millisValues[index]);
        return;
      }
      super(...args);
    }

    static now() {
      const index = Math.min(noArgDateCalls, millisValues.length - 1);
      return millisValues[index];
    }
  }
  SequencedDate.parse = RealDate.parse;
  SequencedDate.UTC = RealDate.UTC;

  global.Date = SequencedDate;
  try {
    return await callback(() => noArgDateCalls);
  } finally {
    global.Date = RealDate;
  }
}

function buildValidCounterData({
  uid = "uid",
  dayInfo = buildUtcDayInfo(fixedNow),
  count = 1,
} = {}) {
  const eventIds = [];
  const requestEventIds = {};
  const requestPayloadHashes = {};

  for (let index = 1; index <= count; index += 1) {
    const requestId = `00000000-0000-4000-8000-${String(index).padStart(12, "0")}`;
    const eventId = `event-${index}`;
    eventIds.push(eventId);
    requestEventIds[requestId] = eventId;
    requestPayloadHashes[requestId] = String(index).repeat(64);
  }

  return {
    userId: uid,
    dayKeyUtc: dayInfo.dayKeyUtc,
    count,
    eventIds,
    requestEventIds,
    requestPayloadHashes,
    windowStartAt: dayInfo.windowStartAt,
    windowEndAt: dayInfo.windowEndAt,
    createdAt: fixedTimestamp,
    updatedAt: fixedUpdatedTimestamp,
  };
}

function cloneCounterData(counterData, overrides = {}) {
  return {
    ...counterData,
    eventIds: [...counterData.eventIds],
    requestEventIds: {...counterData.requestEventIds},
    requestPayloadHashes: {...counterData.requestPayloadHashes},
    ...overrides,
  };
}

function assertCounterInconsistent(counterData, message) {
  assert.throws(
      () => validateExistingCounter(counterData, {
        uid: "uid",
        dayInfo: buildUtcDayInfo(fixedNow),
      }),
      (err) => {
        assert.equal(err.code, "failed-precondition");
        assert.equal(
            err.details?.domainCode,
            "event_creation_counter_inconsistent",
        );
        return true;
      },
      message,
  );
}

function buildNormalizedAndHash(request, options = {}) {
  const normalized = normalizeCreateEventPayload(request, {
    now: fixedNow,
    ...options,
  });
  return {
    normalized,
    payloadHash: hashCreatePayload(normalized.hashPayload),
  };
}

function assertCreateSuccessResponse(response, {
  eventId,
  createdAt,
  dailyCreation,
}) {
  assert.deepEqual(Object.keys(response).sort(), [
    "createdAt",
    "dailyCreation",
    "eventId",
  ]);
  assert.equal(typeof response.eventId, "string");
  assert.equal(response.eventId, eventId);
  assert.equal(typeof response.createdAt, "string");
  assert.match(response.createdAt, ISO_UTC_MILLIS_RE);
  assert.equal(response.createdAt, createdAt);
  assert.equal(
      new Date(response.createdAt).toISOString(),
      response.createdAt,
  );

  assert.deepEqual(Object.keys(response.dailyCreation).sort(), [
    "count",
    "dayKeyUtc",
    "remaining",
    "resetAtUtc",
  ]);
  assert.equal(typeof response.dailyCreation.dayKeyUtc, "string");
  assert.equal(Number.isInteger(response.dailyCreation.count), true);
  assert.equal(Number.isInteger(response.dailyCreation.remaining), true);
  assert.equal(typeof response.dailyCreation.resetAtUtc, "string");
  assert.match(response.dailyCreation.resetAtUtc, ISO_UTC_MILLIS_RE);
  assert.deepEqual(response.dailyCreation, dailyCreation);
}

function assertInvalidCreateRequest(overrides, field, reason) {
  assertHttpsError(
      () => normalizeCreateEventPayload(
          cloneValidRequest(overrides),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_create_request",
      field,
      reason,
  );
}

function assertNoCreateDocuments(store, {
  eventId = "event-new",
  uid = "uid",
  createRequestId = validRequest.createRequestId,
  dayKeyCompact = "20260616",
} = {}) {
  assert.equal(store.has(`events/${eventId}`), false);
  assert.equal(store.has(`events/${eventId}/participants/${uid}`), false);
  assert.equal(store.has(`eventChats/${eventId}`), false);
  assert.equal(
      store.has(`eventCreationCounters/${uid}/days/${dayKeyCompact}`),
      false,
  );
  assert.equal(
      store.has(`eventCreateRequests/${uid}/requests/${createRequestId}`),
      false,
  );
}

test("create event request schema uses exact required keys", () => {
  assert.deepEqual(CREATE_EVENT_KEYS, EXPECTED_CREATE_EVENT_KEYS);
  assert.deepEqual(Object.keys(validRequest), EXPECTED_CREATE_EVENT_KEYS);

  for (const payload of [null, undefined, "payload", [], 42]) {
    assertHttpsError(
        () => normalizeCreateEventPayload(payload, {now: fixedNow}),
        "invalid-argument",
        "invalid_create_request",
        "payload",
        "invalid_type",
    );
  }
});

test("normalizeCreateEventPayload rejects unknown and missing keys", () => {
  assertHttpsError(
      () => normalizeCreateEventPayload(
          cloneValidRequest({unexpected: true}),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_create_request",
      "unexpected",
      "unknown_key",
  );

  for (const key of Object.keys(validRequest)) {
    const missing = cloneValidRequest();
    delete missing[key];
    assertHttpsError(
        () => normalizeCreateEventPayload(missing, {now: fixedNow}),
        "invalid-argument",
        "invalid_create_request",
        key,
        "missing",
    );
  }
});

test("normalizeCreateEventPayload rejects client time and timezone spoof keys",
    () => {
      for (const key of [
        "creationTimeUtc",
        "createdAt",
        "clientNowUtc",
        "timezoneOffsetMinutes",
        "timezoneName",
        "timeZoneId",
      ]) {
        assertHttpsError(
            () => normalizeCreateEventPayload(
                cloneValidRequest({[key]: "2026-06-17T00:00:00.000Z"}),
                {now: fixedNow},
            ),
            "invalid-argument",
            "invalid_create_request",
            key,
            "unknown_key",
        );
      }
    });

test("normalizeCreateEventPayload rejects invalid schema field values", () => {
  const cases = [
    {
      overrides: {createRequestId: null},
      field: "createRequestId",
      reason: "invalid_type",
    },
    {
      overrides: {createRequestId: "550e8400-e29b-11d4-a716-446655440000"},
      field: "createRequestId",
      reason: "invalid_format",
    },
    {overrides: {title: null}, field: "title", reason: "invalid_type"},
    {overrides: {title: "   "}, field: "title", reason: "missing"},
    {
      overrides: {title: "Title\nwith newline"},
      field: "title",
      reason: "line_breaks_not_allowed",
    },
    {
      overrides: {description: null},
      field: "description",
      reason: "invalid_type",
    },
    {
      overrides: {description: "   \n \t "},
      field: "description",
      reason: "missing",
    },
    {
      overrides: {languageCode: null},
      field: "languageCode",
      reason: "invalid_type",
    },
    {
      overrides: {languageCode: "zz"},
      field: "languageCode",
      reason: "invalid_format",
    },
    {overrides: {levelMin: null}, field: "levelMin", reason: "invalid_type"},
    {
      overrides: {levelMin: "D1"},
      field: "levelMin",
      reason: "invalid_format",
    },
    {overrides: {levelMax: null}, field: "levelMax", reason: "invalid_type"},
    {
      overrides: {levelMax: "D1"},
      field: "levelMax",
      reason: "invalid_format",
    },
    {
      overrides: {levelMin: "C2", levelMax: "B1"},
      field: "levelMax",
      reason: "out_of_range",
    },
    {
      overrides: {countryCode: null},
      field: "countryCode",
      reason: "invalid_type",
    },
    {
      overrides: {countryCode: "RUS"},
      field: "countryCode",
      reason: "invalid_format",
    },
    {overrides: {cityKey: null}, field: "cityKey", reason: "invalid_type"},
    {
      overrides: {cityKey: "Moscow"},
      field: "cityKey",
      reason: "invalid_format",
    },
    {
      overrides: {locationName: null},
      field: "locationName",
      reason: "invalid_type",
    },
    {
      overrides: {locationName: " \t "},
      field: "locationName",
      reason: "missing",
    },
    {
      overrides: {locationGeoPoint: "55,37"},
      field: "locationGeoPoint",
      reason: "invalid_type",
    },
    {
      overrides: {locationGeoPoint: [55.7522, 37.6156]},
      field: "locationGeoPoint",
      reason: "invalid_type",
    },
    {
      overrides: {locationGeoPoint: {latitude: "55.75", longitude: 37.61}},
      field: "locationGeoPoint",
      reason: "invalid_type",
    },
    {
      overrides: {locationGeoPoint: {latitude: 91, longitude: 37.61}},
      field: "locationGeoPoint",
      reason: "out_of_range",
    },
    {
      overrides: {locationGeoPoint: {latitude: 55.75, longitude: 181}},
      field: "locationGeoPoint",
      reason: "out_of_range",
    },
    {overrides: {startsAt: null}, field: "startsAt", reason: "invalid_type"},
    {
      overrides: {startsAt: "2026-06-20T15:00:00Z"},
      field: "startsAt",
      reason: "invalid_format",
    },
    {overrides: {capacity: null}, field: "capacity", reason: "invalid_type"},
    {overrides: {capacity: 1}, field: "capacity", reason: "out_of_range"},
    {overrides: {capacity: 51}, field: "capacity", reason: "out_of_range"},
    {
      overrides: {capacity: 10.5},
      field: "capacity",
      reason: "invalid_type",
    },
  ];

  for (const currentCase of cases) {
    assertInvalidCreateRequest(
        currentCase.overrides,
        currentCase.field,
        currentCase.reason,
    );
  }
});

test("normalizeCreateEventPayload accepts nullable or exact geo point shape", () => {
  const nullableGeo = normalizeCreateEventPayload(
      cloneValidRequest({locationGeoPoint: null}),
      {now: fixedNow},
  );
  const boundaryGeo = normalizeCreateEventPayload(
      cloneValidRequest({
        locationGeoPoint: {latitude: -0, longitude: 180},
      }),
      {now: fixedNow},
  );

  assert.equal(nullableGeo.locationGeoPoint, null);
  assert.equal(nullableGeo.hashPayload.locationGeoPoint, null);
  assert.deepEqual(boundaryGeo.locationGeoPointHashValue, {
    latitude: 0,
    longitude: 180,
  });

  for (const locationGeoPoint of [
    {latitude: 55.7522},
    {longitude: 37.6156},
    {latitude: 55.7522, longitude: 37.6156, altitude: 200},
  ]) {
    assertInvalidCreateRequest(
        {locationGeoPoint},
        "locationGeoPoint",
        "unknown_key",
    );
  }
});

test("normalizeCreateEventPayload normalizes trusted create fields", () => {
  const normalized =
    normalizeCreateEventPayload(cloneValidRequest(), {now: fixedNow});

  assert.equal(normalized.createRequestId, validRequest.createRequestId);
  assert.equal(
      normalized.title,
      "Разговорный клуб: кофе и английский",
  );
  assert.equal(
      normalized.description,
      "Неформальная встреча\n\nдля практики.",
  );
  assert.equal(normalized.language.code, "en");
  assert.equal(normalized.language.nameEn, "English");
  assert.equal(normalized.language.nameRu, "Английский");
  assert.equal(normalized.levelMin, "B1");
  assert.equal(normalized.levelMax, "C1");
  assert.equal(normalized.city.countryCode, "RU");
  assert.equal(normalized.city.cityKey, "moscow");
  assert.equal(normalized.city.cityNameRu, "Москва");
  assert.equal(normalized.city.timeZoneId, "Europe/Moscow");
  assert.equal(normalized.locationName, "Starbucks, ул. Арбат, 5");
  assert.deepEqual(normalized.locationGeoPointHashValue, {
    latitude: 55.7522,
    longitude: 37.6156,
  });
  assert.equal(normalized.startsAtIso, "2026-06-20T15:00:00.000Z");
  assert.equal(normalized.startsAtDate.toISOString(), normalized.startsAtIso);
  assert.equal(normalized.capacity, 10);
});

test("normalizeCreateEventPayload builds exact hash input fields", () => {
  const normalized =
    normalizeCreateEventPayload(cloneValidRequest(), {now: fixedNow});

  assert.deepEqual(Object.keys(normalized.hashPayload), [
    "title",
    "description",
    "languageCode",
    "levelMin",
    "levelMax",
    "countryCode",
    "cityKey",
    "locationName",
    "locationGeoPoint",
    "startsAt",
    "capacity",
  ]);
  assert.deepEqual(normalized.hashPayload, {
    title: "Разговорный клуб: кофе и английский",
    description: "Неформальная встреча\n\nдля практики.",
    languageCode: "en",
    levelMin: "B1",
    levelMax: "C1",
    countryCode: "RU",
    cityKey: "moscow",
    locationName: "Starbucks, ул. Арбат, 5",
    locationGeoPoint: {
      latitude: 55.7522,
      longitude: 37.6156,
    },
    startsAt: "2026-06-20T15:00:00.000Z",
    capacity: 10,
  });
});

test("normalizeCreateEventPayload accepts nullable geo and capacity boundaries", () => {
  const nullableGeo = normalizeCreateEventPayload(
      cloneValidRequest({locationGeoPoint: null}),
      {now: fixedNow},
  );
  const minCapacity = normalizeCreateEventPayload(
      cloneValidRequest({capacity: 2}),
      {now: fixedNow},
  );
  const maxCapacity = normalizeCreateEventPayload(
      cloneValidRequest({capacity: 50}),
      {now: fixedNow},
  );

  assert.equal(nullableGeo.locationGeoPoint, null);
  assert.equal(nullableGeo.hashPayload.locationGeoPoint, null);
  assert.equal(minCapacity.capacity, 2);
  assert.equal(maxCapacity.capacity, 50);
});

test("hashCreatePayload uses normalized values and excludes createRequestId", () => {
  const decomposed = normalizeCreateEventPayload(
      cloneValidRequest({
        createRequestId: "650e8400-e29b-41d4-a716-446655440000",
        title: " Cafe\u0301   club ",
        description: " Line\u0301   one\n\n\n two ",
        languageCode: " EN-US ",
        levelMin: " b1 ",
        levelMax: " c1 ",
        countryCode: " ru ",
        locationName: " Main   hall ",
        locationGeoPoint: {latitude: -0, longitude: 0},
      }),
      {now: fixedNow},
  );
  const composed = normalizeCreateEventPayload(
      cloneValidRequest({
        createRequestId: "750e8400-e29b-41d4-a716-446655440000",
        title: "Café club",
        description: "Liné one\n\ntwo",
        languageCode: "en",
        levelMin: "B1",
        levelMax: "C1",
        countryCode: "RU",
        locationName: "Main hall",
        locationGeoPoint: {latitude: 0, longitude: 0},
      }),
      {now: fixedNow},
  );

  assert.notEqual(decomposed.createRequestId, composed.createRequestId);
  assert.deepEqual(decomposed.hashPayload, composed.hashPayload);
  assert.equal(
      hashCreatePayload(decomposed.hashPayload),
      hashCreatePayload(composed.hashPayload),
  );
});

test("normalizeCreateEventPayload rejects invalid field values", () => {
  assertHttpsError(
      () => normalizeCreateEventPayload(
          cloneValidRequest({createRequestId: "not-a-uuid"}),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_create_request",
      "createRequestId",
      "invalid_format",
  );
  assertHttpsError(
      () => normalizeCreateEventPayload(
          cloneValidRequest({levelMin: "C2", levelMax: "B1"}),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_create_request",
      "levelMax",
      "out_of_range",
  );
  assertHttpsError(
      () => normalizeCreateEventPayload(
          cloneValidRequest({startsAt: "2026-06-16T10:00:00.000Z"}),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_create_request",
      "startsAt",
      "past_starts_at",
  );
  assertHttpsError(
      () => normalizeCreateEventPayload(
          cloneValidRequest({capacity: 51}),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_create_request",
      "capacity",
      "out_of_range",
  );
  assertHttpsError(
      () => normalizeCreateEventPayload(
          cloneValidRequest({
            locationGeoPoint: {latitude: "55.75", longitude: 37.61},
          }),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_create_request",
      "locationGeoPoint",
      "invalid_type",
  );
  for (const startsAt of [
    "2026-06-20T15:00:00Z",
    "2026-06-20T15:00:00.000+03:00",
    "2026-02-31T15:00:00.000Z",
  ]) {
    assertHttpsError(
        () => normalizeCreateEventPayload(
            cloneValidRequest({startsAt}),
            {now: fixedNow},
        ),
        "invalid-argument",
        "invalid_create_request",
        "startsAt",
        "invalid_format",
    );
  }
});

test("hashCreatePayload uses stable canonical JSON and excludes request id", () => {
  const normalized =
    normalizeCreateEventPayload(cloneValidRequest(), {now: fixedNow});
  const reorderedPayload = {
    capacity: normalized.hashPayload.capacity,
    startsAt: normalized.hashPayload.startsAt,
    locationGeoPoint: {
      longitude: normalized.hashPayload.locationGeoPoint.longitude,
      latitude: normalized.hashPayload.locationGeoPoint.latitude,
    },
    locationName: normalized.hashPayload.locationName,
    cityKey: normalized.hashPayload.cityKey,
    countryCode: normalized.hashPayload.countryCode,
    levelMax: normalized.hashPayload.levelMax,
    levelMin: normalized.hashPayload.levelMin,
    languageCode: normalized.hashPayload.languageCode,
    description: normalized.hashPayload.description,
    title: normalized.hashPayload.title,
  };

  assert.equal(
      hashCreatePayload(normalized.hashPayload),
      hashCreatePayload(reorderedPayload),
  );
  assert.doesNotMatch(
      canonicalize(normalized.hashPayload),
      /createRequestId/,
  );
});

test("buildUtcDayInfo and buildDailyCreation use trusted UTC boundaries", () => {
  for (const {
    now,
    dayKeyUtc,
    dayKeyCompact,
    resetAtUtc,
    windowStartAt,
    windowEndAt,
  } of [
    {
      now: "2026-06-16T23:59:59.999Z",
      dayKeyUtc: "2026-06-16",
      dayKeyCompact: "20260616",
      resetAtUtc: "2026-06-17T00:00:00.000Z",
      windowStartAt: "2026-06-16T00:00:00.000Z",
      windowEndAt: "2026-06-17T00:00:00.000Z",
    },
    {
      now: "2026-06-17T00:00:00.000Z",
      dayKeyUtc: "2026-06-17",
      dayKeyCompact: "20260617",
      resetAtUtc: "2026-06-18T00:00:00.000Z",
      windowStartAt: "2026-06-17T00:00:00.000Z",
      windowEndAt: "2026-06-18T00:00:00.000Z",
    },
  ]) {
    const dayInfo = buildUtcDayInfo(new Date(now));
    const dailyCreation = buildDailyCreation(3, dayInfo);

    assert.equal(dayInfo.dayKeyUtc, dayKeyUtc);
    assert.equal(dayInfo.dayKeyCompact, dayKeyCompact);
    assert.equal(dayInfo.resetAtUtc, resetAtUtc);
    assert.equal(dayInfo.windowStartAt.toMillis(), Date.parse(windowStartAt));
    assert.equal(dayInfo.windowEndAt.toMillis(), Date.parse(windowEndAt));
    assert.deepEqual(dailyCreation, {
      dayKeyUtc,
      count: 3,
      remaining: 2,
      resetAtUtc,
    });
  }
});

test("buildNextCounterState appends atomically counted create request", () => {
  const dayInfo = buildUtcDayInfo(fixedNow);
  const next = buildNextCounterState({
    counterExists: true,
    counterData: {
      ...buildValidCounterData({dayInfo, count: 1}),
      userId: "uid",
      requestEventIds: {"450e8400-e29b-41d4-a716-446655440000": "event-1"},
      requestPayloadHashes: {
        "450e8400-e29b-41d4-a716-446655440000": HASH_1,
      },
    },
    uid: "uid",
    createRequestId: validRequest.createRequestId,
    eventId: "event-2",
    payloadHash: HASH_2,
    dayInfo,
    creationTimestamp: fixedTimestamp,
  });

  assert.equal(next.count, 2);
  assert.deepEqual(next.eventIds, ["event-1", "event-2"]);
  assert.equal(next.requestEventIds[validRequest.createRequestId], "event-2");
  assert.equal(next.requestPayloadHashes[validRequest.createRequestId], HASH_2);
  assert.equal(next.createdAt, fixedTimestamp);
  assert.equal(next.updatedAt, fixedTimestamp);
});

test("buildNextCounterState preserves createdAt and refreshes updatedAt", () => {
  const dayInfo = buildUtcDayInfo(fixedNow);
  const counterData = buildValidCounterData({dayInfo, count: 1});
  const next = buildNextCounterState({
    counterExists: true,
    counterData,
    uid: "uid",
    createRequestId: validRequest.createRequestId,
    eventId: "event-2",
    payloadHash: HASH_2,
    dayInfo,
    creationTimestamp: fixedUpdatedTimestamp,
  });

  assert.equal(next.count, 2);
  assert.deepEqual(next.eventIds, ["event-1", "event-2"]);
  assert.strictEqual(next.createdAt, counterData.createdAt);
  assert.strictEqual(next.updatedAt, fixedUpdatedTimestamp);
});

test("buildNextCounterState creates exact daily counter schema", () => {
  const dayInfo = buildUtcDayInfo(fixedNow);
  const next = buildNextCounterState({
    counterExists: false,
    uid: "uid",
    createRequestId: validRequest.createRequestId,
    eventId: "event-new",
    payloadHash: HASH_2,
    dayInfo,
    creationTimestamp: fixedTimestamp,
  });

  assert.deepEqual(Object.keys(next).sort(), EXPECTED_DAILY_COUNTER_KEYS);
  assert.equal(next.userId, "uid");
  assert.equal(next.dayKeyUtc, "2026-06-16");
  assert.equal(next.count, 1);
  assert.deepEqual(next.eventIds, ["event-new"]);
  assert.deepEqual(next.requestEventIds, {
    [validRequest.createRequestId]: "event-new",
  });
  assert.deepEqual(next.requestPayloadHashes, {
    [validRequest.createRequestId]: HASH_2,
  });
  assert.equal(next.windowStartAt.toMillis(), Date.parse("2026-06-16Z"));
  assert.equal(next.windowEndAt.toMillis(), Date.parse("2026-06-17Z"));
  assert.strictEqual(next.createdAt, fixedTimestamp);
  assert.strictEqual(next.updatedAt, fixedTimestamp);
  assert.deepEqual(validateExistingCounter(next, {uid: "uid", dayInfo}), {
    count: 1,
    eventIds: ["event-new"],
    requestEventIds: {[validRequest.createRequestId]: "event-new"},
    requestPayloadHashes: {[validRequest.createRequestId]: HASH_2},
  });
});

test("buildNextCounterState rejects daily limit before writing", () => {
  const dayInfo = buildUtcDayInfo(fixedNow);
  assertHttpsError(
      () => buildNextCounterState({
        counterExists: true,
        counterData: {
          ...buildValidCounterData({
            dayInfo,
            count: DAILY_CREATE_LIMIT,
          }),
        },
        uid: "uid",
        createRequestId: validRequest.createRequestId,
        eventId: "event-6",
        payloadHash: HASH_3,
        dayInfo,
        creationTimestamp: fixedTimestamp,
      }),
      "resource-exhausted",
      "daily_limit_reached",
  );
});

test("validateExistingCounter requires the full daily counter schema", () => {
  const validCounter = buildValidCounterData({count: 2});
  const requiredFields = [
    "userId",
    "dayKeyUtc",
    "count",
    "eventIds",
    "requestEventIds",
    "requestPayloadHashes",
    "windowStartAt",
    "windowEndAt",
    "createdAt",
    "updatedAt",
  ];

  for (const field of requiredFields) {
    const counter = cloneCounterData(validCounter);
    delete counter[field];

    assertCounterInconsistent(counter, `missing ${field}`);
  }
});

test("validateExistingCounter rejects identity and timestamp mismatches", () => {
  const validCounter = buildValidCounterData({count: 2});

  for (const {name, overrides} of [
    {name: "wrong userId", overrides: {userId: "another-user"}},
    {name: "wrong dayKeyUtc", overrides: {dayKeyUtc: "2026-06-17"}},
    {name: "wrong windowStartAt", overrides: {windowStartAt: fixedUpdatedTimestamp}},
    {name: "wrong windowEndAt", overrides: {windowEndAt: fixedTimestamp}},
    {name: "invalid createdAt", overrides: {createdAt: fixedNow}},
    {name: "invalid updatedAt", overrides: {updatedAt: fixedNow}},
  ]) {
    assertCounterInconsistent(
        cloneCounterData(validCounter, overrides),
        name,
    );
  }
});

test("validateExistingCounter rejects count and request map invariants", () => {
  const validCounter = buildValidCounterData({count: 2});
  const requestIds = Object.keys(validCounter.requestEventIds).sort();
  const firstRequestId = requestIds[0];

  const cases = [
    {
      name: "count below eventIds length",
      mutate(counter) {
        counter.count = 1;
      },
    },
    {
      name: "count above eventIds length",
      mutate(counter) {
        counter.count = 3;
      },
    },
    {
      name: "requestEventIds missing counted request",
      mutate(counter) {
        delete counter.requestEventIds[firstRequestId];
      },
    },
    {
      name: "requestPayloadHashes missing counted request",
      mutate(counter) {
        delete counter.requestPayloadHashes[firstRequestId];
      },
    },
    {
      name: "request maps use different request ids",
      mutate(counter) {
        delete counter.requestPayloadHashes[firstRequestId];
        counter.requestPayloadHashes[validRequest.createRequestId] = HASH_1;
      },
    },
    {
      name: "duplicate eventIds",
      mutate(counter) {
        counter.eventIds = ["event-1", "event-1"];
      },
    },
    {
      name: "eventId contains a path separator",
      mutate(counter) {
        counter.eventIds[0] = "events/event-1";
        counter.requestEventIds[firstRequestId] = "events/event-1";
      },
    },
    {
      name: "request id is not UUID v4",
      mutate(counter) {
        const eventId = counter.requestEventIds[firstRequestId];
        const payloadHash = counter.requestPayloadHashes[firstRequestId];
        delete counter.requestEventIds[firstRequestId];
        delete counter.requestPayloadHashes[firstRequestId];
        counter.requestEventIds["not-a-uuid"] = eventId;
        counter.requestPayloadHashes["not-a-uuid"] = payloadHash;
      },
    },
    {
      name: "requestEventIds value is empty",
      mutate(counter) {
        counter.requestEventIds[firstRequestId] = "";
      },
    },
    {
      name: "requestPayloadHashes value is not sha256 hex",
      mutate(counter) {
        counter.requestPayloadHashes[firstRequestId] = "not-a-sha";
      },
    },
    {
      name: "requestEventIds points outside eventIds",
      mutate(counter) {
        counter.requestEventIds[firstRequestId] = "event-missing";
      },
    },
    {
      name: "requestEventIds values do not cover every eventId",
      mutate(counter) {
        const secondRequestId = requestIds[1];
        counter.requestEventIds[secondRequestId] = "event-1";
      },
    },
  ];

  for (const {name, mutate} of cases) {
    const counter = cloneCounterData(validCounter);
    mutate(counter);

    assertCounterInconsistent(counter, name);
  }

  assertCounterInconsistent(
      buildValidCounterData({count: DAILY_CREATE_LIMIT + 1}),
      "count above daily limit",
  );
});

test("validateExistingCounter fails closed on corrupt stored counters", () => {
  assertHttpsError(
      () => validateExistingCounter({
        count: 0,
        eventIds: [],
        requestEventIds: {},
      }),
      "failed-precondition",
      "event_creation_counter_inconsistent",
  );
  assertHttpsError(
      () => validateExistingCounter({
        count: "1",
        eventIds: ["event-1"],
        requestEventIds: {
          "00000000-0000-4000-8000-000000000001": "event-1",
        },
        requestPayloadHashes: {
          "00000000-0000-4000-8000-000000000001": "hash-1",
        },
      }),
      "failed-precondition",
      "event_creation_counter_inconsistent",
  );
});

test("buildExistingCreateResponse returns original idempotency snapshot", () => {
  const response = buildExistingCreateResponse({
    markerData: {
      userId: "uid",
      createRequestId: validRequest.createRequestId,
      status: "created",
      eventId: "event-1",
      payloadHash: HASH_1,
      counterPath: "eventCreationCounters/uid/days/20260616",
      createdAt: fixedTimestamp,
      updatedAt: fixedUpdatedTimestamp,
      dayKeyUtc: "2026-06-16",
      dailyCreation: {
        dayKeyUtc: "2026-06-16",
        count: 2,
        remaining: 3,
        resetAtUtc: "2026-06-17T00:00:00.000Z",
      },
    },
    uid: "uid",
    createRequestId: validRequest.createRequestId,
    payloadHash: HASH_1,
  });

  assert.deepEqual(response, {
    eventId: "event-1",
    createdAt: "2026-06-16T10:00:00.000Z",
    dailyCreation: {
      dayKeyUtc: "2026-06-16",
      count: 2,
      remaining: 3,
      resetAtUtc: "2026-06-17T00:00:00.000Z",
    },
  });
});

test("buildExistingCreateResponse rejects changed-payload retry", () => {
  assertHttpsError(
      () => buildExistingCreateResponse({
        markerData: {
          userId: "uid",
          createRequestId: validRequest.createRequestId,
          status: "created",
          eventId: "event-1",
          payloadHash: HASH_1,
          counterPath: "eventCreationCounters/uid/days/20260616",
          dayKeyUtc: "2026-06-16",
          dailyCreation: {},
          createdAt: fixedTimestamp,
          updatedAt: fixedUpdatedTimestamp,
        },
        uid: "uid",
        createRequestId: validRequest.createRequestId,
        payloadHash: HASH_2,
      }),
      "already-exists",
      "create_request_conflict",
  );
});

test("buildExistingCreateResponse fails closed on corrupt marker shape", () => {
  assertHttpsError(
      () => buildExistingCreateResponse({
        markerData: {
          userId: "uid",
          createRequestId: validRequest.createRequestId,
          status: "created",
          eventId: "event-1",
          payloadHash: HASH_1,
          counterPath: "eventCreationCounters/uid/days/20260616",
          dayKeyUtc: "2026-06-16",
          createdAt: fixedTimestamp,
          updatedAt: fixedUpdatedTimestamp,
          dailyCreation: {
            dayKeyUtc: "2026-06-16",
            count: 2,
            remaining: 99,
            resetAtUtc: "2026-06-17T00:00:00.000Z",
          },
        },
        uid: "uid",
        createRequestId: validRequest.createRequestId,
        payloadHash: HASH_1,
      }),
      "failed-precondition",
      "create_request_marker_inconsistent",
  );
  assertHttpsError(
      () => buildExistingCreateResponse({
        markerData: {
          userId: "other-uid",
          createRequestId: validRequest.createRequestId,
          status: "created",
          eventId: "event-1",
          payloadHash: HASH_1,
          counterPath: "eventCreationCounters/uid/days/20260616",
          dayKeyUtc: "2026-06-16",
          createdAt: fixedTimestamp,
          updatedAt: fixedUpdatedTimestamp,
          dailyCreation: {
            dayKeyUtc: "2026-06-16",
            count: 2,
            remaining: 3,
            resetAtUtc: "2026-06-17T00:00:00.000Z",
          },
        },
        uid: "uid",
        createRequestId: validRequest.createRequestId,
        payloadHash: HASH_1,
      }),
      "failed-precondition",
      "create_request_marker_inconsistent",
  );
});

test("event, participant, chat, and marker builders share one timestamp", () => {
  const normalized =
    normalizeCreateEventPayload(cloneValidRequest(), {now: fixedNow});
  const organizerSnapshot = buildOrganizerSnapshot({
    userExists: true,
    userData: {display_name: " Анастасия Иванова ", photo_url: ""},
  });
  const dayInfo = buildUtcDayInfo(fixedNow);
  const dailyCreation = buildDailyCreation(1, dayInfo);
  const eventData = buildEventData({
    normalized,
    uid: "uid",
    eventId: "event-1",
    organizerSnapshot,
    creationTimestamp: fixedTimestamp,
  });
  const participantData = buildOrganizerParticipantData({
    uid: "uid",
    organizerSnapshot,
    creationTimestamp: fixedTimestamp,
  });
  const chatData = buildEventChatData({
    eventId: "event-1",
    uid: "uid",
    creationTimestamp: fixedTimestamp,
  });
  const marker = buildCreateRequestMarker({
    uid: "uid",
    createRequestId: validRequest.createRequestId,
    eventId: "event-1",
    payloadHash: HASH_1,
    counterPath: "eventCreationCounters/uid/days/20260616",
    dayInfo,
    dailyCreation,
    creationTimestamp: fixedTimestamp,
  });

  assert.equal(eventData.status, "active");
  assert.equal(eventData.participantsCount, 1);
  assert.equal(eventData.chatId, "event-1");
  assert.equal(eventData.createdAt, fixedTimestamp);
  assert.equal(eventData.updatedAt, fixedTimestamp);
  assert.equal(eventData.canceledAt, null);
  assert.equal(participantData.role, "organizer");
  assert.equal(participantData.status, "active");
  assert.equal(participantData.joinedAt, fixedTimestamp);
  assert.equal(Object.prototype.hasOwnProperty.call(chatData, "chatId"), false);
  assert.deepEqual(chatData.readAccessUserIds, ["uid"]);
  assert.equal(marker.status, "created");
  assert.equal(marker.dailyCreation, dailyCreation);
  assert.equal(marker.createdAt, fixedTimestamp);
});

test("executeCreateEventTransaction creates all event documents", async () => {
  const {db, makeRef, store, writes} = createFakeFirestore({
    "users/uid": {
      display_name: "Анастасия Иванова",
      photo_url: "https://example.test/avatar.jpg",
    },
  });
  const dayInfo = buildUtcDayInfo(fixedNow);
  const {normalized, payloadHash} =
    buildNormalizedAndHash(cloneValidRequest());

  const response = await executeCreateEventTransaction({
    db,
    uid: "uid",
    creationDate: fixedNow,
    creationTimestamp: fixedTimestamp,
    dayInfo,
    normalized,
    payloadHash,
    eventRef: makeRef("events/event-new"),
  });

  assertCreateSuccessResponse(response, {
    eventId: "event-new",
    createdAt: "2026-06-16T10:00:00.000Z",
    dailyCreation: {
      dayKeyUtc: "2026-06-16",
      count: 1,
      remaining: 4,
      resetAtUtc: "2026-06-17T00:00:00.000Z",
    },
  });
  assert.equal(store.get("events/event-new").participantsCount, 1);
  assert.equal(
      store.get("events/event-new/participants/uid").role,
      "organizer",
  );
  assert.deepEqual(store.get("eventChats/event-new"), {
    eventId: "event-new",
    readAccessUserIds: ["uid"],
    createdAt: fixedTimestamp,
    updatedAt: fixedTimestamp,
  });
  const counter = store.get("eventCreationCounters/uid/days/20260616");
  assert.deepEqual(Object.keys(counter).sort(), EXPECTED_DAILY_COUNTER_KEYS);
  assert.equal(counter.userId, "uid");
  assert.equal(counter.dayKeyUtc, "2026-06-16");
  assert.equal(counter.count, 1);
  assert.deepEqual(counter.eventIds, ["event-new"]);
  assert.deepEqual(counter.requestEventIds, {
    [validRequest.createRequestId]: "event-new",
  });
  assert.deepEqual(counter.requestPayloadHashes, {
    [validRequest.createRequestId]: payloadHash,
  });
  assert.equal(counter.windowStartAt.toMillis(), Date.parse("2026-06-16Z"));
  assert.equal(counter.windowEndAt.toMillis(), Date.parse("2026-06-17Z"));
  assert.strictEqual(counter.createdAt, fixedTimestamp);
  assert.strictEqual(counter.updatedAt, fixedTimestamp);
  assert.equal(
      store.get(
          `eventCreateRequests/uid/requests/${validRequest.createRequestId}`,
      ).eventId,
      "event-new",
  );
  assert.deepEqual(
      writes.map((write) => `${write.type}:${write.path}`),
      [
        "create:events/event-new",
        "create:events/event-new/participants/uid",
        "create:eventChats/event-new",
        "set:eventCreationCounters/uid/days/20260616",
        `create:eventCreateRequests/uid/requests/${validRequest.createRequestId}`,
      ],
  );
});

test("executeCreateEventTransaction ignores event day and city timezone for counter",
    async () => {
      const creationDate = new Date("2026-06-16T23:59:59.999Z");
      const creationTimestamp = admin.firestore.Timestamp.fromDate(creationDate);
      const dayInfo = buildUtcDayInfo(creationDate);
      const {db, makeRef, store} = createFakeFirestore({
        "users/uid": {display_name: "Анастасия Иванова"},
      });
      const {normalized, payloadHash} = buildNormalizedAndHash(
          cloneValidRequest({
            countryCode: "ae",
            cityKey: "dubai",
            startsAt: "2026-12-31T20:00:00.000Z",
          }),
          {now: creationDate},
      );

      const response = await executeCreateEventTransaction({
        db,
        uid: "uid",
        creationDate,
        creationTimestamp,
        dayInfo,
        normalized,
        payloadHash,
        eventRef: makeRef("events/event-new"),
      });

      assert.equal(response.createdAt, "2026-06-16T23:59:59.999Z");
      assert.deepEqual(response.dailyCreation, {
        dayKeyUtc: "2026-06-16",
        count: 1,
        remaining: 4,
        resetAtUtc: "2026-06-17T00:00:00.000Z",
      });
      assert.equal(store.get("events/event-new").cityKey, "dubai");
      assert.equal(store.get("events/event-new").timeZoneId, "Asia/Dubai");
      assert.equal(
          store.get("events/event-new").startsAt.toMillis(),
          Date.parse("2026-12-31T20:00:00.000Z"),
      );
      assert.equal(
          store.get("eventCreationCounters/uid/days/20260616").dayKeyUtc,
          "2026-06-16",
      );
      assert.equal(
          store.has("eventCreationCounters/uid/days/20260617"),
          false,
      );
      assert.equal(
          store.has("eventCreationCounters/uid/days/20261231"),
          false,
      );
    });

test("createEvent callable captures one trusted backend UTC instant",
    async () => {
      const {db, store} = createFakeFirestore({
        "users/uid": {display_name: "Анастасия Иванова"},
      });
      const request = cloneValidRequest({
        countryCode: "ae",
        cityKey: "dubai",
        startsAt: "2026-12-31T20:00:00.000Z",
      });

      await withAdminFirestore(db, async () => {
        await withSequencedDate([
          "2026-06-16T23:59:59.999Z",
          "2026-06-17T00:00:00.000Z",
        ], async (dateCallCount) => {
          const response = await createEvent.run(request, {
            auth: {uid: "uid"},
          });

          assert.equal(dateCallCount(), 1);
          assertCreateSuccessResponse(response, {
            eventId: "event-new",
            createdAt: "2026-06-16T23:59:59.999Z",
            dailyCreation: {
              dayKeyUtc: "2026-06-16",
              count: 1,
              remaining: 4,
              resetAtUtc: "2026-06-17T00:00:00.000Z",
            },
          });
          const counter =
            store.get("eventCreationCounters/uid/days/20260616");
          const marker = store.get(
              `eventCreateRequests/uid/requests/${validRequest.createRequestId}`,
          );

          assert.equal(counter.dayKeyUtc, "2026-06-16");
          assert.equal(
              counter.createdAt.toMillis(),
              Date.parse("2026-06-16T23:59:59.999Z"),
          );
          assert.equal(
              counter.updatedAt.toMillis(),
              Date.parse("2026-06-16T23:59:59.999Z"),
          );
          assert.equal(marker.createdAt.toMillis(), counter.createdAt.toMillis());
          assert.deepEqual(marker.dailyCreation, response.dailyCreation);
          assert.equal(store.has("eventCreationCounters/uid/days/20260617"),
              false);
        });
      });
    });

test("executeCreateEventTransaction rolls back buffered writes on failure", async () => {
  const {db, makeRef, store, writes} = createFakeFirestore(
      {"users/uid": {display_name: "Анастасия Иванова"}},
      {failBeforeCommit: true},
  );
  const dayInfo = buildUtcDayInfo(fixedNow);
  const {normalized, payloadHash} =
    buildNormalizedAndHash(cloneValidRequest());

  await assert.rejects(
      () => executeCreateEventTransaction({
        db,
        uid: "uid",
        creationDate: fixedNow,
        creationTimestamp: fixedTimestamp,
        dayInfo,
        normalized,
        payloadHash,
        eventRef: makeRef("events/event-new"),
      }),
      /Simulated transaction commit failure/,
  );

  assert.equal(writes.length, 5);
  assert.equal(store.has("events/event-new"), false);
  assert.equal(store.has("events/event-new/participants/uid"), false);
  assert.equal(store.has("eventChats/event-new"), false);
  assert.equal(store.has("eventCreationCounters/uid/days/20260616"), false);
  assert.equal(
      store.has(
          `eventCreateRequests/uid/requests/${validRequest.createRequestId}`,
      ),
      false,
  );
});

test("executeCreateEventTransaction leaves no partial docs when interrupted", async () => {
  for (const writeCount of [1, 2, 3, 4, 5]) {
    const {db, makeRef, store, writes} = createFakeFirestore(
        {"users/uid": {display_name: "Анастасия Иванова"}},
        {failAfterBufferedWrites: writeCount},
    );
    const dayInfo = buildUtcDayInfo(fixedNow);
    const {normalized, payloadHash} =
      buildNormalizedAndHash(cloneValidRequest());

    await assert.rejects(
        () => executeCreateEventTransaction({
          db,
          uid: "uid",
          creationDate: fixedNow,
          creationTimestamp: fixedTimestamp,
          dayInfo,
          normalized,
          payloadHash,
          eventRef: makeRef("events/event-new"),
        }),
        new RegExp(`Simulated transaction interruption after ${writeCount} writes`),
    );

    assert.equal(writes.length, writeCount);
    assertNoCreateDocuments(store);
  }
});

test("executeCreateEventTransaction preserves existing counter on interruption", async () => {
  const dayInfo = buildUtcDayInfo(fixedNow);
  const counterBefore = buildValidCounterData({dayInfo, count: 1});
  const {db, makeRef, store, writes} = createFakeFirestore(
      {
        "users/uid": {display_name: "Анастасия Иванова"},
        "eventCreationCounters/uid/days/20260616": counterBefore,
      },
      {failAfterBufferedWrites: 4},
  );
  const {normalized, payloadHash} =
    buildNormalizedAndHash(cloneValidRequest());

  await assert.rejects(
      () => executeCreateEventTransaction({
        db,
        uid: "uid",
        creationDate: fixedNow,
        creationTimestamp: fixedTimestamp,
        dayInfo,
        normalized,
        payloadHash,
        eventRef: makeRef("events/event-new"),
      }),
      /Simulated transaction interruption after 4 writes/,
  );

  assert.equal(writes.length, 4);
  assert.equal(store.has("events/event-new"), false);
  assert.equal(store.has("events/event-new/participants/uid"), false);
  assert.equal(store.has("eventChats/event-new"), false);
  assert.strictEqual(
      store.get("eventCreationCounters/uid/days/20260616"),
      counterBefore,
  );
  assert.equal(
      store.has(
          `eventCreateRequests/uid/requests/${validRequest.createRequestId}`,
      ),
      false,
  );
});

test("executeCreateEventTransaction returns marker retry after startsAt", async () => {
  const originalDayInfo = buildUtcDayInfo(fixedNow);
  const retryDate = new Date("2026-06-21T10:00:00.000Z");
  const retryDayInfo = buildUtcDayInfo(retryDate);
  const retryTimestamp = {
    toMillis: () => retryDate.getTime(),
    toDate: () => retryDate,
  };
  const {normalized, payloadHash} = buildNormalizedAndHash(
      cloneValidRequest(),
      {now: retryDate, requireFutureStartsAt: false},
  );
  const dailyCreation = buildDailyCreation(1, originalDayInfo);
  const marker = buildCreateRequestMarker({
    uid: "uid",
    createRequestId: validRequest.createRequestId,
    eventId: "event-original",
    payloadHash,
    counterPath: "eventCreationCounters/uid/days/20260616",
    dayInfo: originalDayInfo,
    dailyCreation,
    creationTimestamp: fixedTimestamp,
  });
  const {db, makeRef, reads, writes} = createFakeFirestore({
    [`eventCreateRequests/uid/requests/${validRequest.createRequestId}`]:
      marker,
  });

  const response = await executeCreateEventTransaction({
    db,
    uid: "uid",
    creationDate: retryDate,
    creationTimestamp: retryTimestamp,
    dayInfo: retryDayInfo,
    normalized,
    payloadHash,
    eventRef: makeRef("events/event-new"),
  });

  assertCreateSuccessResponse(response, {
    eventId: "event-original",
    createdAt: "2026-06-16T10:00:00.000Z",
    dailyCreation,
  });
  assert.deepEqual(reads, [
    `eventCreateRequests/uid/requests/${validRequest.createRequestId}`,
  ]);
  assert.deepEqual(writes, []);
});

test("executeCreateEventTransaction keeps counter after admin event delete", async () => {
  const originalDayInfo = buildUtcDayInfo(fixedNow);
  const {normalized, payloadHash} =
    buildNormalizedAndHash(cloneValidRequest());
  const dailyCreation = buildDailyCreation(1, originalDayInfo);
  const marker = buildCreateRequestMarker({
    uid: "uid",
    createRequestId: validRequest.createRequestId,
    eventId: "event-original",
    payloadHash,
    counterPath: "eventCreationCounters/uid/days/20260616",
    dayInfo: originalDayInfo,
    dailyCreation,
    creationTimestamp: fixedTimestamp,
  });
  const counterBefore = buildValidCounterData({
    dayInfo: originalDayInfo,
    count: 1,
  });
  const {db, makeRef, reads, store, writes} = createFakeFirestore({
    [`eventCreateRequests/uid/requests/${validRequest.createRequestId}`]:
      marker,
    "eventCreationCounters/uid/days/20260616": counterBefore,
  });

  const response = await executeCreateEventTransaction({
    db,
    uid: "uid",
    creationDate: fixedNow,
    creationTimestamp: fixedTimestamp,
    dayInfo: originalDayInfo,
    normalized,
    payloadHash,
    eventRef: makeRef("events/event-new"),
  });

  assertCreateSuccessResponse(response, {
    eventId: "event-original",
    createdAt: "2026-06-16T10:00:00.000Z",
    dailyCreation,
  });
  assert.equal(store.has("events/event-original"), false);
  assert.strictEqual(
      store.get("eventCreationCounters/uid/days/20260616"),
      counterBefore,
  );
  assert.deepEqual(reads, [
    `eventCreateRequests/uid/requests/${validRequest.createRequestId}`,
  ]);
  assert.deepEqual(writes, []);
});

test("executeCreateEventTransaction returns marker retry for stale city", async () => {
  const staleCityRequest = cloneValidRequest({cityKey: "removed_city"});
  const {normalized, payloadHash} = buildNormalizedAndHash(
      staleCityRequest,
      {requireKnownCity: false},
  );
  const originalDayInfo = buildUtcDayInfo(fixedNow);
  const marker = buildCreateRequestMarker({
    uid: "uid",
    createRequestId: validRequest.createRequestId,
    eventId: "event-original",
    payloadHash,
    counterPath: "eventCreationCounters/uid/days/20260616",
    dayInfo: originalDayInfo,
    dailyCreation: buildDailyCreation(1, originalDayInfo),
    creationTimestamp: fixedTimestamp,
  });
  const {db, makeRef, reads, writes} = createFakeFirestore({
    [`eventCreateRequests/uid/requests/${validRequest.createRequestId}`]:
      marker,
  });

  const response = await executeCreateEventTransaction({
    db,
    uid: "uid",
    creationDate: fixedNow,
    creationTimestamp: fixedTimestamp,
    dayInfo: originalDayInfo,
    normalized,
    payloadHash,
    eventRef: makeRef("events/event-new"),
  });

  assert.equal(response.eventId, "event-original");
  assert.deepEqual(reads, [
    `eventCreateRequests/uid/requests/${validRequest.createRequestId}`,
  ]);
  assert.deepEqual(writes, []);
});

test("executeCreateEventTransaction rejects new past event without writes", async () => {
  const pastRequest = cloneValidRequest({
    startsAt: "2026-06-16T09:00:00.000Z",
  });
  const {normalized, payloadHash} = buildNormalizedAndHash(
      pastRequest,
      {requireFutureStartsAt: false},
  );
  const {db, makeRef, reads, writes} = createFakeFirestore({
    "users/uid": {display_name: "Анастасия Иванова"},
  });

  await assertRejectsHttpsError(
      () => executeCreateEventTransaction({
        db,
        uid: "uid",
        creationDate: fixedNow,
        creationTimestamp: fixedTimestamp,
        dayInfo: buildUtcDayInfo(fixedNow),
        normalized,
        payloadHash,
        eventRef: makeRef("events/event-new"),
      }),
      "invalid-argument",
      "invalid_create_request",
  );
  assert.deepEqual(reads, [
    `eventCreateRequests/uid/requests/${validRequest.createRequestId}`,
  ]);
  assert.deepEqual(writes, []);
});

test("executeCreateEventTransaction rejects unknown city before writes", async () => {
  const unknownCityRequest = cloneValidRequest({cityKey: "unknown_city"});
  const {normalized, payloadHash} = buildNormalizedAndHash(
      unknownCityRequest,
      {requireKnownCity: false},
  );
  const {db, makeRef, reads, writes} = createFakeFirestore({
    "users/uid": {display_name: "Анастасия Иванова"},
  });

  await assertRejectsHttpsError(
      () => executeCreateEventTransaction({
        db,
        uid: "uid",
        creationDate: fixedNow,
        creationTimestamp: fixedTimestamp,
        dayInfo: buildUtcDayInfo(fixedNow),
        normalized,
        payloadHash,
        eventRef: makeRef("events/event-new"),
      }),
      "invalid-argument",
      "invalid_create_request",
  );
  assert.deepEqual(reads, [
    `eventCreateRequests/uid/requests/${validRequest.createRequestId}`,
  ]);
  assert.deepEqual(writes, []);
});

test("executeCreateEventTransaction rejects full daily counter without writes", async () => {
  const dayInfo = buildUtcDayInfo(fixedNow);
  const {normalized, payloadHash} =
    buildNormalizedAndHash(cloneValidRequest());
  const {db, makeRef, writes} = createFakeFirestore({
    "users/uid": {display_name: "Анастасия Иванова"},
    "eventCreationCounters/uid/days/20260616": buildValidCounterData({
      dayInfo,
      count: DAILY_CREATE_LIMIT,
    }),
  });

  await assertRejectsHttpsError(
      () => executeCreateEventTransaction({
        db,
        uid: "uid",
        creationDate: fixedNow,
        creationTimestamp: fixedTimestamp,
        dayInfo,
        normalized,
        payloadHash,
        eventRef: makeRef("events/event-new"),
      }),
      "resource-exhausted",
      "daily_limit_reached",
  );
  assert.deepEqual(writes, []);
});

test("executeCreateEventTransaction allows fifth daily create", async () => {
  const dayInfo = buildUtcDayInfo(fixedNow);
  const {normalized, payloadHash} =
    buildNormalizedAndHash(cloneValidRequest());
  const {db, makeRef, store} = createFakeFirestore({
    "users/uid": {display_name: "Анастасия Иванова"},
    "eventCreationCounters/uid/days/20260616": buildValidCounterData({
      dayInfo,
      count: DAILY_CREATE_LIMIT - 1,
    }),
  });

  const response = await executeCreateEventTransaction({
    db,
    uid: "uid",
    creationDate: fixedNow,
    creationTimestamp: fixedTimestamp,
    dayInfo,
    normalized,
    payloadHash,
    eventRef: makeRef("events/event-new"),
  });

  assert.equal(response.dailyCreation.count, DAILY_CREATE_LIMIT);
  assert.equal(response.dailyCreation.remaining, 0);
  assert.equal(
      store.get("eventCreationCounters/uid/days/20260616").count,
      DAILY_CREATE_LIMIT,
  );
});

test("create_event callable uses a Firestore transaction and no serverTimestamp", () => {
  const source = fs.readFileSync(require.resolve("./create_event"), "utf8");

  assert.match(source, /runTransaction/);
  assert.match(source, /tx\.create\(refs\.eventRef/);
  assert.match(source, /tx\.create\(refs\.participantRef/);
  assert.match(source, /tx\.create\(refs\.chatRef/);
  assert.match(source, /tx\.create\(refs\.markerRef/);
  assert.doesNotMatch(source, /serverTimestamp/);
});
