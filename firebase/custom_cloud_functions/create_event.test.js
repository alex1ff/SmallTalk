const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const {
  createEvent,
  __private__: {
    CREATE_EVENT_KEYS,
    DAILY_CREATE_LIMIT,
    EVENT_LANGUAGE_CATALOG,
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
const EXPECTED_EVENT_CREATE_REQUEST_MARKER_KEYS = Object.freeze([
  "counterPath",
  "createRequestId",
  "createdAt",
  "dailyCreation",
  "dayKeyUtc",
  "eventId",
  "payloadHash",
  "status",
  "updatedAt",
  "userId",
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

function indexedRequestId(index) {
  return `660e8400-e29b-41d4-a716-${String(index).padStart(12, "0")}`;
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

function assertDailyLimitError(err, {
  dayKeyUtc = "2026-06-16",
  resetAtUtc = "2026-06-17T00:00:00.000Z",
  count = DAILY_CREATE_LIMIT,
  limit = DAILY_CREATE_LIMIT,
} = {}) {
  assert.equal(err.code, "resource-exhausted");
  assert.deepEqual(err.details, {
    domainCode: "daily_limit_reached",
    resetAtUtc,
    dayKeyUtc,
    count,
    limit,
  });
}

function assertCreateRequestConflictError(err, {
  eventId = "event-1",
  createRequestId = validRequest.createRequestId,
  dayKeyUtc = "2026-06-16",
} = {}) {
  assert.equal(err.code, "already-exists");
  assert.deepEqual(err.details, {
    domainCode: "create_request_conflict",
    eventId,
    createRequestId,
    dayKeyUtc,
  });
}

async function assertRejectsDailyLimit(promiseFactory, expected = {}) {
  await assert.rejects(promiseFactory, (err) => {
    assertDailyLimitError(err, expected);
    return true;
  });
}

async function assertRejectsCreateRequestConflict(
    promiseFactory,
    expected = {},
) {
  await assert.rejects(promiseFactory, (err) => {
    assertCreateRequestConflictError(err, expected);
    return true;
  });
}

function createFakeFirestore(seed = {}, {
  eventId = "event-new",
  failAfterBufferedWrites = null,
  failBeforeCommit = false,
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
      for (let attempt = 1; attempt <= maxTransactionAttempts; attempt += 1) {
        let hasWrites = false;
        const pendingWrites = [];
        const attemptWrites = [];
        const readVersions = new Map();
        const writeLog = retryOnConcurrentModification ? attemptWrites : writes;
        const tx = {
          async get(ref) {
            if (hasWrites) {
              throw new Error("Firestore transactions require reads first");
            }
            reads.push(ref.path);
            if (!readVersions.has(ref.path)) {
              readVersions.set(ref.path, versions.get(ref.path) || 0);
            }
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
            writeLog.push({type: "create", path: ref.path, data});
            if (pendingWrites.length === failAfterBufferedWrites) {
              throw new Error(
                  `Simulated transaction interruption after ${pendingWrites.length} writes`,
              );
            }
          },
          set(ref, data) {
            hasWrites = true;
            pendingWrites.push({type: "set", path: ref.path, data});
            writeLog.push({type: "set", path: ref.path, data});
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
          store.set(write.path, write.data);
          versions.set(write.path, (versions.get(write.path) || 0) + 1);
        }
        return result;
      }
      throw new Error("Simulated transaction retry limit exceeded");
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

function repeatGrapheme(value, count) {
  return Array.from({length: count}, () => value).join("");
}

function assertNoLanguageStructFields(data) {
  for (const field of [
    "language",
    "LanguageStruct",
    "alternateCodes",
    "model",
    "isPopular",
    "ss",
  ]) {
    assert.equal(
        Object.prototype.hasOwnProperty.call(data, field),
        false,
    );
  }
}

function assertNoCityStructFields(data) {
  for (const field of [
    "city",
    "catalogVersion",
    "regionCode",
    "regionNameRu",
    "regionNameEn",
  ]) {
    assert.equal(
        Object.prototype.hasOwnProperty.call(data, field),
        false,
    );
  }
}

function readAppEventLanguageAllowlist() {
  const source = JSON.parse(fs.readFileSync(
      path.join(
          __dirname,
          "..",
          "..",
          "assets",
          "jsons",
          "languages_catalog.json",
      ),
      "utf8",
  ));
  assert.equal(Array.isArray(source), true);
  return source.map((language) => ({
    code: language.code,
    alternateCodes: language.alternateCodes,
    nameEn: language.nameEn,
    nameRu: language.nameRu,
  }));
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
      overrides: {cityKey: "Москва"},
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

test("normalizeCreateEventPayload validates title text boundaries", () => {
  for (const title of ["", " \t  "]) {
    assertInvalidCreateRequest({title}, "title", "missing");
  }

  for (const title of [
    "Title\nwith newline",
    "Title\rwith carriage return",
    "Title\r\nwith CRLF",
  ]) {
    assertInvalidCreateRequest(
        {title},
        "title",
        "line_breaks_not_allowed",
    );
  }

  const seventyGraphemeTitle = repeatGrapheme("👍🏽", 70);
  const seventyOneGraphemeTitle = repeatGrapheme("👍🏽", 71);
  const boundary = normalizeCreateEventPayload(
      cloneValidRequest({title: ` ${seventyGraphemeTitle} `}),
      {now: fixedNow},
  );
  assert.equal(Array.from(seventyGraphemeTitle).length > 70, true);
  assert.equal(boundary.title, seventyGraphemeTitle);
  assert.equal(boundary.hashPayload.title, seventyGraphemeTitle);
  assertInvalidCreateRequest(
      {title: seventyOneGraphemeTitle},
      "title",
      "too_long",
  );

  const unicode = normalizeCreateEventPayload(
      cloneValidRequest({title: " Cafe\u0301  разговорный  клуб  東京  "}),
      {now: fixedNow},
  );
  assert.equal(unicode.title, "Café разговорный клуб 東京");
  assert.equal(unicode.hashPayload.title, "Café разговорный клуб 東京");
});

test("normalizeCreateEventPayload validates description text boundaries", () => {
  for (const description of ["", " \t  ", "   \n \t "]) {
    assertInvalidCreateRequest({description}, "description", "missing");
  }

  const thousandGraphemeDescription = repeatGrapheme("👍🏽", 1000);
  const thousandOneGraphemeDescription = repeatGrapheme("👍🏽", 1001);
  const boundary = normalizeCreateEventPayload(
      cloneValidRequest({description: ` ${thousandGraphemeDescription} `}),
      {now: fixedNow},
  );
  assert.equal(Array.from(thousandGraphemeDescription).length > 1000, true);
  assert.equal(boundary.description, thousandGraphemeDescription);
  assert.equal(boundary.hashPayload.description, thousandGraphemeDescription);
  assertInvalidCreateRequest(
      {description: thousandOneGraphemeDescription},
      "description",
      "too_long",
  );

  const multiline = normalizeCreateEventPayload(
      cloneValidRequest({
        description:
          " Cafe\u0301   line \r\n\r\n\r\n  разговорный\tклуб \n\n\n 東京  ",
      }),
      {now: fixedNow},
  );
  assert.equal(
      multiline.description,
      "Café line\n\nразговорный клуб\n\n東京",
  );
  assert.equal(
      multiline.hashPayload.description,
      "Café line\n\nразговорный клуб\n\n東京",
  );
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
  assert.equal(normalized.city.cityNameEn, "Moscow");
  assert.equal(normalized.city.cityDisplayContext, "Россия");
  assert.equal(normalized.city.regionCode, null);
  assert.equal(normalized.city.regionNameRu, null);
  assert.equal(normalized.city.regionNameEn, null);
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

test("normalizeCreateEventPayload normalizes language codes", () => {
  const cases = [
    {
      languageCode: "it",
      code: "it",
      nameEn: "Italian",
      nameRu: "Итальянский",
    },
    {
      languageCode: " EN-us ",
      code: "en",
      nameEn: "English",
      nameRu: "Английский",
    },
    {
      languageCode: " ZH-HANT ",
      code: "zh-TW",
      nameEn: "Chinese (Traditional)",
      nameRu: "Китайский (Традиционный)",
    },
    {
      languageCode: " de-CH ",
      code: "de-CH",
      nameEn: "German (Switzerland)",
      nameRu: "Немецкий (Швейцария)",
    },
  ];

  for (const currentCase of cases) {
    const normalized = normalizeCreateEventPayload(
        cloneValidRequest({languageCode: currentCase.languageCode}),
        {now: fixedNow},
    );

    assert.equal(normalized.language.code, currentCase.code);
    assert.equal(normalized.language.nameEn, currentCase.nameEn);
    assert.equal(normalized.language.nameRu, currentCase.nameRu);
    assert.equal(normalized.hashPayload.languageCode, currentCase.code);
  }
});

test("backend event language catalog matches app asset allowlist", () => {
  assert.deepEqual(EVENT_LANGUAGE_CATALOG, readAppEventLanguageAllowlist());
});

test("backend resolves every app language alternate code uniquely", () => {
  const aliasOwners = new Map();
  let aliasCount = 0;
  const appCatalog = readAppEventLanguageAllowlist();

  for (const language of appCatalog) {
    for (const alias of language.alternateCodes) {
      aliasCount += 1;
      const aliasKey = alias.trim().toLowerCase();
      const previousOwner = aliasOwners.get(aliasKey);
      assert.equal(
          previousOwner,
          undefined,
          `${alias} resolves to both ${previousOwner} and ${language.code}`,
      );
      aliasOwners.set(aliasKey, language.code);

      const normalized = normalizeCreateEventPayload(
          cloneValidRequest({languageCode: ` ${alias.toUpperCase()} `}),
          {now: fixedNow},
      );

      assert.equal(normalized.language.code, language.code);
      assert.equal(normalized.language.nameEn, language.nameEn);
      assert.equal(normalized.language.nameRu, language.nameRu);
      assert.equal(normalized.hashPayload.languageCode, language.code);
    }
  }
  assert.equal(aliasOwners.size, aliasCount);
});

test("normalizeCreateEventPayload rejects client language display payloads", () => {
  const languageStruct = {
    code: "en",
    alternateCodes: ["en", "en-US"],
    nameEn: "Stale English",
    nameRu: "Stale Russian",
    isPopular: true,
    ss: "client-ui-state",
  };

  for (const [key, value] of Object.entries({
    languageNameEn: "Stale English",
    languageNameRu: "Stale Russian",
    language: languageStruct,
    LanguageStruct: languageStruct,
  })) {
    assertInvalidCreateRequest({[key]: value}, key, "unknown_key");
  }
  assertInvalidCreateRequest(
      {languageCode: languageStruct},
      "languageCode",
      "invalid_type",
  );
});

test("normalizeCreateEventPayload rejects client city display payloads", () => {
  const cityStruct = {
    countryCode: "RU",
    cityKey: "moscow",
    cityNameRu: "Поддельная Москва",
    cityNameEn: "Fake Moscow",
    cityDisplayContext: "Client supplied",
    timeZoneId: "America/New_York",
  };

  for (const [key, value] of Object.entries({
    cityNameRu: "Поддельная Москва",
    cityNameEn: "Fake Moscow",
    cityDisplayContext: "Client supplied",
    regionCode: "FAKE",
    regionNameRu: "Фейковый регион",
    regionNameEn: "Fake region",
    city: cityStruct,
    catalogVersion: "client-catalog",
  })) {
    assertInvalidCreateRequest({[key]: value}, key, "unknown_key");
  }
});

test("normalizeCreateEventPayload derives timezone from selected city", () => {
  const dubai = normalizeCreateEventPayload(
      cloneValidRequest({
        countryCode: "ae",
        cityKey: "dubai",
        startsAt: "2026-12-31T20:00:00.000Z",
      }),
      {now: fixedNow},
  );
  const newYork = normalizeCreateEventPayload(
      cloneValidRequest({
        countryCode: "us",
        cityKey: "new_york",
        startsAt: "2026-06-20T15:00:00.000Z",
      }),
      {now: fixedNow},
  );

  assert.equal(dubai.city.timeZoneId, "Asia/Dubai");
  assert.equal(dubai.startsAtIso, "2026-12-31T20:00:00.000Z");
  assert.equal(dubai.startsAtTimestamp.toMillis(),
      Date.parse("2026-12-31T20:00:00.000Z"));
  assert.equal(
      Object.prototype.hasOwnProperty.call(dubai.hashPayload, "timeZoneId"),
      false,
  );
  assert.equal(newYork.city.timeZoneId, "America/New_York");
  assert.equal(newYork.startsAtIso, "2026-06-20T15:00:00.000Z");
});

test("normalizeCreateEventPayload validates startsAt against trusted now", () => {
  for (const startsAt of [
    "2026-06-16T09:59:59.999Z",
    "2026-06-16T10:00:00.000Z",
  ]) {
    assertInvalidCreateRequest({startsAt}, "startsAt", "past_starts_at");
  }

  const normalized = normalizeCreateEventPayload(
      cloneValidRequest({startsAt: "2026-06-16T10:00:00.001Z"}),
      {now: fixedNow},
  );

  assert.equal(normalized.startsAtIso, "2026-06-16T10:00:00.001Z");
  assert.equal(
      normalized.startsAtTimestamp.toMillis(),
      Date.parse("2026-06-16T10:00:00.001Z"),
  );
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
  assert.throws(
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
      (err) => {
        assertDailyLimitError(err);
        return true;
      },
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
  assert.throws(
      () => buildExistingCreateResponse({
        markerData: {
          userId: "uid",
          createRequestId: validRequest.createRequestId,
          status: "created",
          eventId: "event-1",
          payloadHash: HASH_1,
          counterPath: "eventCreationCounters/uid/days/20260616",
          dayKeyUtc: "2026-06-16",
          dailyCreation: {
            dayKeyUtc: "2026-06-16",
            count: 2,
            remaining: 3,
            resetAtUtc: "2026-06-17T00:00:00.000Z",
          },
          createdAt: fixedTimestamp,
          updatedAt: fixedUpdatedTimestamp,
        },
        uid: "uid",
        createRequestId: validRequest.createRequestId,
        payloadHash: HASH_2,
      }),
      (err) => {
        assertCreateRequestConflictError(err);
        return true;
      },
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
  assert.equal(eventData.organizerDisplayName, "Анастасия Иванова");
  assert.equal(eventData.organizerPhotoUrl, null);
  assert.equal(eventData.languageCode, "en");
  assert.equal(eventData.languageNameEn, "English");
  assert.equal(eventData.languageNameRu, "Английский");
  assertNoLanguageStructFields(eventData);
  assert.equal(eventData.createdAt, fixedTimestamp);
  assert.equal(eventData.updatedAt, fixedTimestamp);
  assert.equal(eventData.canceledAt, null);
  assert.equal(participantData.role, "organizer");
  assert.equal(participantData.displayName, "Анастасия Иванова");
  assert.equal(participantData.photoUrl, null);
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
      store.get("events/event-new").organizerDisplayName,
      "Анастасия Иванова",
  );
  assert.equal(
      store.get("events/event-new").organizerPhotoUrl,
      "https://example.test/avatar.jpg",
  );
  assert.equal(
      store.get("events/event-new/participants/uid").role,
      "organizer",
  );
  assert.equal(
      store.get("events/event-new/participants/uid").displayName,
      "Анастасия Иванова",
  );
  assert.equal(
      store.get("events/event-new/participants/uid").photoUrl,
      "https://example.test/avatar.jpg",
  );
  assert.equal(store.get("events/event-new").languageCode, "en");
  assert.equal(store.get("events/event-new").languageNameEn, "English");
  assert.equal(store.get("events/event-new").languageNameRu, "Английский");
  assertNoLanguageStructFields(store.get("events/event-new"));
  assert.equal(store.get("events/event-new").countryCode, "RU");
  assert.equal(store.get("events/event-new").cityKey, "moscow");
  assert.equal(store.get("events/event-new").cityNameRu, "Москва");
  assert.equal(store.get("events/event-new").cityNameEn, "Moscow");
  assert.equal(store.get("events/event-new").cityDisplayContext, "Россия");
  assert.equal(store.get("events/event-new").timeZoneId, "Europe/Moscow");
  assertNoCityStructFields(store.get("events/event-new"));
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

test("executeCreateEventTransaction derives organizer snapshot from profile",
    async () => {
      const {db, makeRef, store} = createFakeFirestore({
        "users/uid": {
          display_name: " Cafe\u0301 Organizer ",
          photo_url: " https://example.test/profile.jpg ",
        },
      });
      const dayInfo = buildUtcDayInfo(fixedNow);
      const {normalized, payloadHash} =
        buildNormalizedAndHash(cloneValidRequest());

      await executeCreateEventTransaction({
        db,
        uid: "uid",
        creationDate: fixedNow,
        creationTimestamp: fixedTimestamp,
        dayInfo,
        normalized,
        payloadHash,
        eventRef: makeRef("events/event-new"),
      });

      const event = store.get("events/event-new");
      const participant = store.get("events/event-new/participants/uid");

      assert.equal(event.organizerId, "uid");
      assert.equal(event.organizerDisplayName, "Café Organizer");
      assert.equal(event.organizerPhotoUrl, "https://example.test/profile.jpg");
      assert.equal(participant.userId, "uid");
      assert.equal(participant.displayName, "Café Organizer");
      assert.equal(participant.photoUrl, "https://example.test/profile.jpg");
    });

test("executeCreateEventTransaction stores null organizer photo from blank profile",
    async () => {
      const {db, makeRef, store} = createFakeFirestore({
        "users/uid": {
          display_name: "Анастасия Иванова",
          photo_url: "   ",
        },
      });
      const dayInfo = buildUtcDayInfo(fixedNow);
      const {normalized, payloadHash} =
        buildNormalizedAndHash(cloneValidRequest());

      await executeCreateEventTransaction({
        db,
        uid: "uid",
        creationDate: fixedNow,
        creationTimestamp: fixedTimestamp,
        dayInfo,
        normalized,
        payloadHash,
        eventRef: makeRef("events/event-new"),
      });

      assert.equal(store.get("events/event-new").organizerDisplayName,
          "Анастасия Иванова");
      assert.equal(store.get("events/event-new").organizerPhotoUrl, null);
      assert.equal(
          store.get("events/event-new/participants/uid").displayName,
          "Анастасия Иванова",
      );
      assert.equal(store.get("events/event-new/participants/uid").photoUrl,
          null);
    });

test("executeCreateEventTransaction rejects missing organizer profile snapshot",
    async () => {
      const cases = [
        {seed: {}, field: "display_name"},
        {seed: {"users/uid": {photo_url: "https://example.test/photo.jpg"}},
          field: "display_name"},
        {seed: {"users/uid": {display_name: "   "}}, field: "display_name"},
      ];

      for (const currentCase of cases) {
        const {db, makeRef, store, writes} =
          createFakeFirestore(currentCase.seed);
        const dayInfo = buildUtcDayInfo(fixedNow);
        const {normalized, payloadHash} =
          buildNormalizedAndHash(cloneValidRequest());

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
            "failed-precondition",
            "organizer_profile_required",
            currentCase.field,
        );

        assert.deepEqual(writes, []);
        assertNoCreateDocuments(store);
      }
    });

test("executeCreateEventTransaction creates exact lowercase request marker schema",
    async () => {
      const uppercaseRequestId = "550E8400-E29B-41D4-A716-446655440000";
      const lowercaseRequestId = uppercaseRequestId.toLowerCase();
      const request = cloneValidRequest({createRequestId: uppercaseRequestId});
      const {normalized, payloadHash} = buildNormalizedAndHash(request);
      const dayInfo = buildUtcDayInfo(fixedNow);
      const {db, makeRef, store} = createFakeFirestore({
        "users/uid": {display_name: "Анастасия Иванова"},
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

      const markerPath =
        `eventCreateRequests/uid/requests/${lowercaseRequestId}`;
      const uppercaseMarkerPath =
        `eventCreateRequests/uid/requests/${uppercaseRequestId}`;
      const marker = store.get(markerPath);

      assert.equal(normalized.createRequestId, lowercaseRequestId);
      assert.equal(store.has(uppercaseMarkerPath), false);
      assert.deepEqual(
          Object.keys(marker).sort(),
          EXPECTED_EVENT_CREATE_REQUEST_MARKER_KEYS,
      );
      assert.equal(markerPath.split("/")[1], marker.userId);
      assert.equal(marker.userId, "uid");
      assert.equal(marker.createRequestId, lowercaseRequestId);
      assert.equal(marker.eventId, "event-new");
      assert.equal(marker.payloadHash, payloadHash);
      assert.equal(
          marker.counterPath,
          "eventCreationCounters/uid/days/20260616",
      );
      assert.equal(marker.dayKeyUtc, "2026-06-16");
      assert.equal(marker.status, "created");
      assert.strictEqual(marker.createdAt, fixedTimestamp);
      assert.strictEqual(marker.updatedAt, fixedTimestamp);
      assert.deepEqual(marker.dailyCreation, response.dailyCreation);
      assert.deepEqual(marker.dailyCreation, {
        dayKeyUtc: "2026-06-16",
        count: 1,
        remaining: 4,
        resetAtUtc: "2026-06-17T00:00:00.000Z",
      });
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
      assert.equal(store.get("events/event-new").cityNameRu, "Дубай");
      assert.equal(store.get("events/event-new").cityNameEn, "Dubai");
      assert.equal(
          store.get("events/event-new").cityDisplayContext,
          "United Arab Emirates",
      );
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
        "users/uid": {
          display_name: " Анастасия Иванова ",
          photo_url: " https://example.test/callable-avatar.jpg ",
        },
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
          assert.equal(
              store.get("events/event-new").organizerDisplayName,
              "Анастасия Иванова",
          );
          assert.equal(
              store.get("events/event-new").organizerPhotoUrl,
              "https://example.test/callable-avatar.jpg",
          );
          assert.equal(
              store.get("events/event-new/participants/uid").displayName,
              "Анастасия Иванова",
          );
          assert.equal(
              store.get("events/event-new/participants/uid").photoUrl,
              "https://example.test/callable-avatar.jpg",
          );
          assert.equal(store.has("eventCreationCounters/uid/days/20260617"),
              false);
        });
      });
    });

test("createEvent callable invalid schema writes no marker", async () => {
  const {db, reads, store, writes} = createFakeFirestore({
    "users/uid": {display_name: "Анастасия Иванова"},
  });

  await withAdminFirestore(db, async () => {
    await assertRejectsHttpsError(
        () => createEvent.run(cloneValidRequest({title: "   "}), {
          auth: {uid: "uid"},
        }),
        "invalid-argument",
        "invalid_create_request",
        "title",
        "missing",
    );
  });

  assert.deepEqual(reads, []);
  assert.deepEqual(writes, []);
  assert.equal(store.has("events/event-new"), false);
  assert.equal(store.has("eventChats/event-new"), false);
  assert.equal(store.has("eventCreationCounters/uid/days/20260616"), false);
  assert.equal(
      store.has(
          `eventCreateRequests/uid/requests/${validRequest.createRequestId}`,
      ),
      false,
  );
});

test("createEvent callable validates title before transaction writes", async () => {
  const cases = [
    {title: "", reason: "missing"},
    {title: " \t  ", reason: "missing"},
    {title: "Title\nwith newline", reason: "line_breaks_not_allowed"},
    {title: "Title\rwith carriage return", reason: "line_breaks_not_allowed"},
    {title: "Title\r\nwith CRLF", reason: "line_breaks_not_allowed"},
    {title: repeatGrapheme("👍🏽", 71), reason: "too_long"},
  ];

  for (const currentCase of cases) {
    const {db, reads, store, writes} = createFakeFirestore({
      "users/uid": {display_name: "Анастасия Иванова"},
    });

    await withAdminFirestore(db, async () => {
      await assertRejectsHttpsError(
          () => createEvent.run(
              cloneValidRequest({title: currentCase.title}),
              {auth: {uid: "uid"}},
          ),
          "invalid-argument",
          "invalid_create_request",
          "title",
          currentCase.reason,
      );
    });

    assert.deepEqual(reads, []);
    assert.deepEqual(writes, []);
    assertNoCreateDocuments(store);
  }
});

test("createEvent callable validates description before transaction writes",
    async () => {
      const cases = [
        {description: "", reason: "missing"},
        {description: " \t  ", reason: "missing"},
        {description: "   \n \t ", reason: "missing"},
        {description: repeatGrapheme("👍🏽", 1001), reason: "too_long"},
      ];

      for (const currentCase of cases) {
        const {db, reads, store, writes} = createFakeFirestore({
          "users/uid": {display_name: "Анастасия Иванова"},
        });

        await withAdminFirestore(db, async () => {
          await assertRejectsHttpsError(
              () => createEvent.run(
                  cloneValidRequest({description: currentCase.description}),
                  {auth: {uid: "uid"}},
              ),
              "invalid-argument",
              "invalid_create_request",
              "description",
              currentCase.reason,
          );
        });

        assert.deepEqual(reads, []);
        assert.deepEqual(writes, []);
        assertNoCreateDocuments(store);
      }
    });

test("createEvent callable validates capacity before transaction writes",
    async () => {
      const cases = [
        {capacity: 1, reason: "out_of_range"},
        {capacity: 51, reason: "out_of_range"},
        {capacity: 10.5, reason: "invalid_type"},
      ];

      for (const currentCase of cases) {
        const {db, reads, store, writes} = createFakeFirestore({
          "users/uid": {display_name: "Анастасия Иванова"},
        });

        await withAdminFirestore(db, async () => {
          await assertRejectsHttpsError(
              () => createEvent.run(
                  cloneValidRequest({capacity: currentCase.capacity}),
                  {auth: {uid: "uid"}},
              ),
              "invalid-argument",
              "invalid_create_request",
              "capacity",
              currentCase.reason,
          );
        });

        assert.deepEqual(reads, []);
        assert.deepEqual(writes, []);
        assertNoCreateDocuments(store);
      }
    });

test("createEvent callable validates language before transaction writes",
    async () => {
      const languageStruct = {
        code: "en",
        alternateCodes: ["en", "en-US"],
        nameEn: "Stale English",
        nameRu: "Stale Russian",
        isPopular: true,
        ss: "client-ui-state",
      };
      const cases = [
        {
          overrides: {languageCode: "zz"},
          field: "languageCode",
          reason: "invalid_format",
        },
        {
          overrides: {languageCode: languageStruct},
          field: "languageCode",
          reason: "invalid_type",
        },
        {
          overrides: {languageNameEn: "Stale English"},
          field: "languageNameEn",
          reason: "unknown_key",
        },
        {
          overrides: {languageNameRu: "Stale Russian"},
          field: "languageNameRu",
          reason: "unknown_key",
        },
        {
          overrides: {language: languageStruct},
          field: "language",
          reason: "unknown_key",
        },
        {
          overrides: {LanguageStruct: languageStruct},
          field: "LanguageStruct",
          reason: "unknown_key",
        },
      ];

      for (const currentCase of cases) {
        const {db, reads, store, writes} = createFakeFirestore({
          "users/uid": {display_name: "Анастасия Иванова"},
        });

        await withAdminFirestore(db, async () => {
          await assertRejectsHttpsError(
              () => createEvent.run(
                  cloneValidRequest(currentCase.overrides),
                  {auth: {uid: "uid"}},
              ),
              "invalid-argument",
              "invalid_create_request",
              currentCase.field,
              currentCase.reason,
          );
        });

        assert.deepEqual(reads, []);
        assert.deepEqual(writes, []);
        assertNoCreateDocuments(store);
      }
    });

test("createEvent callable rejects client city display payloads before writes",
    async () => {
      const cityStruct = {
        countryCode: "RU",
        cityKey: "moscow",
        cityNameRu: "Поддельная Москва",
        cityNameEn: "Fake Moscow",
        cityDisplayContext: "Client supplied",
        timeZoneId: "America/New_York",
      };
      const cases = [
        {overrides: {cityNameRu: "Поддельная Москва"}, field: "cityNameRu"},
        {overrides: {cityNameEn: "Fake Moscow"}, field: "cityNameEn"},
        {
          overrides: {cityDisplayContext: "Client supplied"},
          field: "cityDisplayContext",
        },
        {overrides: {regionCode: "FAKE"}, field: "regionCode"},
        {overrides: {regionNameRu: "Фейковый регион"}, field: "regionNameRu"},
        {overrides: {regionNameEn: "Fake region"}, field: "regionNameEn"},
        {overrides: {city: cityStruct}, field: "city"},
        {
          overrides: {catalogVersion: "client-catalog"},
          field: "catalogVersion",
        },
      ];

      for (const currentCase of cases) {
        const {db, reads, store, writes} = createFakeFirestore({
          "users/uid": {display_name: "Анастасия Иванова"},
        });

        await withAdminFirestore(db, async () => {
          await assertRejectsHttpsError(
              () => createEvent.run(
                  cloneValidRequest(currentCase.overrides),
                  {auth: {uid: "uid"}},
              ),
              "invalid-argument",
              "invalid_create_request",
              currentCase.field,
              "unknown_key",
          );
        });

        assert.deepEqual(reads, []);
        assert.deepEqual(writes, []);
        assertNoCreateDocuments(store);
      }
    });

test("createEvent callable validates startsAt against trusted backend time",
    async () => {
      for (const startsAt of [
        "2026-06-16T09:59:59.999Z",
        "2026-06-16T10:00:00.000Z",
      ]) {
        const {db, reads, store, writes} = createFakeFirestore({
          "users/uid": {display_name: "Анастасия Иванова"},
        });

        await withAdminFirestore(db, async () => {
          await withSequencedDate(["2026-06-16T10:00:00.000Z"],
              async () => {
                await assertRejectsHttpsError(
                    () => createEvent.run(
                        cloneValidRequest({startsAt}),
                        {auth: {uid: "uid"}},
                    ),
                    "invalid-argument",
                    "invalid_create_request",
                    "startsAt",
                    "past_starts_at",
                );
              });
        });

        assert.deepEqual(reads, [
          `eventCreateRequests/uid/requests/${validRequest.createRequestId}`,
        ]);
        assert.deepEqual(writes, []);
        assertNoCreateDocuments(store);
      }
    });

test("createEvent callable rejects client timezone mismatch fields", async () => {
  for (const key of [
    "timeZoneId",
    "timezoneOffsetMinutes",
    "timezoneName",
    "clientNowUtc",
  ]) {
    const {db, reads, store, writes} = createFakeFirestore({
      "users/uid": {display_name: "Анастасия Иванова"},
    });

    await withAdminFirestore(db, async () => {
      await assertRejectsHttpsError(
          () => createEvent.run(
              cloneValidRequest({[key]: "America/New_York"}),
              {auth: {uid: "uid"}},
          ),
          "invalid-argument",
          "invalid_create_request",
          key,
          "unknown_key",
      );
    });

    assert.deepEqual(reads, []);
    assert.deepEqual(writes, []);
    assertNoCreateDocuments(store);
  }
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
  const counterBefore = buildValidCounterData({
    dayInfo: originalDayInfo,
    count: 1,
  });
  const retryDayCounterBefore = buildValidCounterData({
    dayInfo: retryDayInfo,
    count: 1,
  });
  const markerPath =
    `eventCreateRequests/uid/requests/${validRequest.createRequestId}`;
  const {db, makeRef, reads, store, writes} = createFakeFirestore({
    [markerPath]: marker,
    "eventCreationCounters/uid/days/20260616": counterBefore,
    "eventCreationCounters/uid/days/20260621": retryDayCounterBefore,
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
  assert.strictEqual(
      store.get("eventCreationCounters/uid/days/20260616"),
      counterBefore,
  );
  assert.strictEqual(
      store.get("eventCreationCounters/uid/days/20260621"),
      retryDayCounterBefore,
  );
  assert.strictEqual(store.get(markerPath), marker);
});

test("executeCreateEventTransaction rejects changed-payload marker retry",
    async () => {
      const dayInfo = buildUtcDayInfo(fixedNow);
      const original = buildNormalizedAndHash(cloneValidRequest());
      const changed = buildNormalizedAndHash(cloneValidRequest({
        title: "Changed title",
      }));
      const marker = buildCreateRequestMarker({
        uid: "uid",
        createRequestId: validRequest.createRequestId,
        eventId: "event-original",
        payloadHash: original.payloadHash,
        counterPath: "eventCreationCounters/uid/days/20260616",
        dayInfo,
        dailyCreation: buildDailyCreation(1, dayInfo),
        creationTimestamp: fixedTimestamp,
      });
      const counterBefore = buildValidCounterData({dayInfo, count: 1});
      const {db, makeRef, reads, store, writes} = createFakeFirestore({
        [`eventCreateRequests/uid/requests/${validRequest.createRequestId}`]:
          marker,
        "eventCreationCounters/uid/days/20260616": counterBefore,
      });

      await assertRejectsCreateRequestConflict(
          () => executeCreateEventTransaction({
            db,
            uid: "uid",
            creationDate: fixedNow,
            creationTimestamp: fixedTimestamp,
            dayInfo,
            normalized: changed.normalized,
            payloadHash: changed.payloadHash,
            eventRef: makeRef("events/event-new"),
          }),
          {
            eventId: "event-original",
            createRequestId: validRequest.createRequestId,
            dayKeyUtc: "2026-06-16",
          },
      );

      assert.deepEqual(reads, [
        `eventCreateRequests/uid/requests/${validRequest.createRequestId}`,
      ]);
      assert.deepEqual(writes, []);
      assert.strictEqual(
          store.get("eventCreationCounters/uid/days/20260616"),
          counterBefore,
      );
      assert.equal(store.has("events/event-new"), false);
      assert.equal(store.has("eventChats/event-new"), false);
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
  const counterBefore = {
    ...buildValidCounterData({
      dayInfo: originalDayInfo,
      count: 1,
    }),
    eventIds: ["event-original"],
    requestEventIds: {
      [validRequest.createRequestId]: "event-original",
    },
    requestPayloadHashes: {
      [validRequest.createRequestId]: payloadHash,
    },
  };
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
  assert.equal(store.has("events/event-new"), false);
  assert.strictEqual(
      store.get("eventCreationCounters/uid/days/20260616"),
      counterBefore,
  );
  const counterAfter = store.get("eventCreationCounters/uid/days/20260616");
  assert.equal(counterAfter.count, 1);
  assert.deepEqual(counterAfter.eventIds, ["event-original"]);
  assert.deepEqual(counterAfter.requestEventIds, {
    [validRequest.createRequestId]: "event-original",
  });
  assert.deepEqual(counterAfter.requestPayloadHashes, {
    [validRequest.createRequestId]: payloadHash,
  });
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
  const {db, makeRef, store, writes} = createFakeFirestore({
    "users/uid": {display_name: "Анастасия Иванова"},
    "eventCreationCounters/uid/days/20260616": buildValidCounterData({
      dayInfo,
      count: DAILY_CREATE_LIMIT,
    }),
  });

  await assertRejectsDailyLimit(
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
  );
  assert.deepEqual(writes, []);
  assert.equal(store.has("events/event-new"), false);
  assert.equal(store.has("events/event-new/participants/uid"), false);
  assert.equal(store.has("eventChats/event-new"), false);
  assert.equal(
      store.has(
          `eventCreateRequests/uid/requests/${validRequest.createRequestId}`,
      ),
      false,
  );
});

test("executeCreateEventTransaction allows fifth daily create", async () => {
  const creationDate = new Date("2026-06-16T10:00:01.000Z");
  const creationTimestamp = {
    toMillis: () => creationDate.getTime(),
    toDate: () => creationDate,
  };
  const dayInfo = buildUtcDayInfo(creationDate);
  const {normalized, payloadHash} =
    buildNormalizedAndHash(cloneValidRequest());
  const counterBefore = buildValidCounterData({
    dayInfo,
    count: DAILY_CREATE_LIMIT - 1,
  });
  const {db, makeRef, store} = createFakeFirestore({
    "users/uid": {display_name: "Анастасия Иванова"},
    "eventCreationCounters/uid/days/20260616": counterBefore,
  });

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

  assertCreateSuccessResponse(response, {
    eventId: "event-new",
    createdAt: "2026-06-16T10:00:01.000Z",
    dailyCreation: {
      dayKeyUtc: "2026-06-16",
      count: DAILY_CREATE_LIMIT,
      remaining: 0,
      resetAtUtc: "2026-06-17T00:00:00.000Z",
    },
  });
  const counter = store.get("eventCreationCounters/uid/days/20260616");
  assert.equal(counter.count, DAILY_CREATE_LIMIT);
  assert.deepEqual(
      counter.eventIds,
      ["event-1", "event-2", "event-3", "event-4", "event-new"],
  );
  assert.equal(
      counter.requestEventIds[validRequest.createRequestId],
      "event-new",
  );
  assert.equal(
      counter.requestPayloadHashes[validRequest.createRequestId],
      payloadHash,
  );
  assert.strictEqual(counter.createdAt, counterBefore.createdAt);
  assert.strictEqual(counter.updatedAt, creationTimestamp);
  const marker = store.get(
      `eventCreateRequests/uid/requests/${validRequest.createRequestId}`,
  );
  assert.equal(marker.counterPath, "eventCreationCounters/uid/days/20260616");
  assert.equal(marker.status, "created");
  assert.deepEqual(marker.dailyCreation, response.dailyCreation);
});

test("executeCreateEventTransaction concurrent creates never exceed daily limit",
    async () => {
      const dayInfo = buildUtcDayInfo(fixedNow);
      let firstAttemptCommits = 0;
      let releaseFirstAttempts;
      const firstAttemptsReady = new Promise((resolve) => {
        releaseFirstAttempts = resolve;
      });
      const {db, makeRef, store} = createFakeFirestore(
          {
            "users/uid": {display_name: "Анастасия Иванова"},
            "eventCreationCounters/uid/days/20260616": buildValidCounterData({
              dayInfo,
              count: DAILY_CREATE_LIMIT - 1,
            }),
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

      const create = (index) => {
        const createRequestId = indexedRequestId(index);
        const {normalized, payloadHash} = buildNormalizedAndHash(
            cloneValidRequest({
              createRequestId,
              title: `Concurrent create ${index}`,
            }),
        );
        return executeCreateEventTransaction({
          db,
          uid: "uid",
          creationDate: fixedNow,
          creationTimestamp: fixedTimestamp,
          dayInfo,
          normalized,
          payloadHash,
          eventRef: makeRef(`events/event-concurrent-${index}`),
        });
      };

      const results = await Promise.allSettled([create(1), create(2)]);
      const fulfilled = results.filter((result) =>
        result.status === "fulfilled");
      const rejected = results.filter((result) =>
        result.status === "rejected");

      assert.equal(fulfilled.length, 1);
      assert.equal(rejected.length, 1);
      assertDailyLimitError(rejected[0].reason);
      assert.equal(firstAttemptCommits, 2);
      const counter = store.get("eventCreationCounters/uid/days/20260616");
      assert.equal(counter.count, DAILY_CREATE_LIMIT);
      assert.equal(counter.eventIds.length, DAILY_CREATE_LIMIT);
      assert.equal(Object.keys(counter.requestEventIds).length,
          DAILY_CREATE_LIMIT);
      assert.equal(Object.keys(counter.requestPayloadHashes).length,
          DAILY_CREATE_LIMIT);

      const createdIndexes = [1, 2].filter((index) =>
        store.has(`events/event-concurrent-${index}`));
      const rejectedIndexes = [1, 2].filter((index) =>
        !store.has(`events/event-concurrent-${index}`));
      assert.equal(createdIndexes.length, 1);
      assert.equal(rejectedIndexes.length, 1);
      const createdIndex = createdIndexes[0];
      const rejectedIndex = rejectedIndexes[0];
      const createdRequestId = indexedRequestId(createdIndex);
      const rejectedRequestId = indexedRequestId(rejectedIndex);
      const {payloadHash: createdPayloadHash} = buildNormalizedAndHash(
          cloneValidRequest({
            createRequestId: createdRequestId,
            title: `Concurrent create ${createdIndex}`,
          }),
      );

      assert.equal(
          counter.requestEventIds[createdRequestId],
          `event-concurrent-${createdIndex}`,
      );
      assert.equal(
          counter.requestPayloadHashes[createdRequestId],
          createdPayloadHash,
      );
      assert.equal(counter.eventIds.includes(
          `event-concurrent-${createdIndex}`,
      ), true);
      assert.equal(counter.eventIds.includes(
          `event-concurrent-${rejectedIndex}`,
      ), false);
      assert.equal(
          Object.prototype.hasOwnProperty.call(
              counter.requestEventIds,
              rejectedRequestId,
          ),
          false,
      );
      assert.equal(
          Object.prototype.hasOwnProperty.call(
              counter.requestPayloadHashes,
              rejectedRequestId,
          ),
          false,
      );
      assert.equal(
          store.get(`events/event-concurrent-${createdIndex}/participants/uid`)
              .role,
          "organizer",
      );
      assert.deepEqual(
          store.get(`eventChats/event-concurrent-${createdIndex}`)
              .readAccessUserIds,
          ["uid"],
      );
      assert.equal(
          store.get(`eventCreateRequests/uid/requests/${createdRequestId}`)
              .eventId,
          `event-concurrent-${createdIndex}`,
      );
      assert.equal(
          store.has(`events/event-concurrent-${rejectedIndex}/participants/uid`),
          false,
      );
      assert.equal(store.has(`eventChats/event-concurrent-${rejectedIndex}`),
          false);
      assert.equal(
          store.has(`eventCreateRequests/uid/requests/${rejectedRequestId}`),
          false,
      );
});

test("executeCreateEventTransaction retry increments counter once per request",
    async () => {
      const dayInfo = buildUtcDayInfo(fixedNow);
      let firstAttemptCommits = 0;
      let releaseFirstAttempts;
      const firstAttemptsReady = new Promise((resolve) => {
        releaseFirstAttempts = resolve;
      });
      const counterBefore = buildValidCounterData({dayInfo, count: 1});
      const {db, makeRef, store} = createFakeFirestore(
          {
            "users/uid": {display_name: "Анастасия Иванова"},
            "eventCreationCounters/uid/days/20260616": counterBefore,
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

      const create = (index) => {
        const createRequestId = indexedRequestId(index);
        const {normalized, payloadHash} = buildNormalizedAndHash(
            cloneValidRequest({
              createRequestId,
              title: `Retried create ${index}`,
            }),
        );
        return executeCreateEventTransaction({
          db,
          uid: "uid",
          creationDate: fixedNow,
          creationTimestamp: fixedTimestamp,
          dayInfo,
          normalized,
          payloadHash,
          eventRef: makeRef(`events/event-retry-${index}`),
        });
      };

      const [first, second] = await Promise.all([create(1), create(2)]);

      assert.equal(first.dailyCreation.count, 2);
      assert.equal(second.dailyCreation.count, 3);
      assert.equal(firstAttemptCommits, 2);
      const counter = store.get("eventCreationCounters/uid/days/20260616");
      assert.equal(counter.count, 3);
      assert.deepEqual(
          counter.eventIds.sort(),
          ["event-1", "event-retry-1", "event-retry-2"],
      );
      assert.equal(new Set(counter.eventIds).size, 3);
      for (const index of [1, 2]) {
        const createRequestId = indexedRequestId(index);
        assert.equal(
            counter.requestEventIds[createRequestId],
            `event-retry-${index}`,
        );
        assert.equal(
            store.get(`eventCreateRequests/uid/requests/${createRequestId}`)
                .eventId,
            `event-retry-${index}`,
        );
        assert.equal(store.has(`events/event-retry-${index}`), true);
      }
      assert.equal(Object.keys(counter.requestEventIds).length, 3);
      assert.equal(Object.keys(counter.requestPayloadHashes).length, 3);
      assert.strictEqual(counter.createdAt, counterBefore.createdAt);
      assert.strictEqual(counter.updatedAt, fixedTimestamp);
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
