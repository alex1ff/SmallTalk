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
      return millisValues[Math.min(noArgDateCalls, millisValues.length - 1)];
    }
  }

  Object.setPrototypeOf(SequencedDate, RealDate);
  global.Date = SequencedDate;
  try {
    return await callback(() => noArgDateCalls);
  } finally {
    global.Date = RealDate;
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

function participant(overrides = {}) {
  return {
    status: "active",
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

  for (const key of [
    "clientNowUtc",
    "timezoneOffsetMinutes",
    "timezoneName",
    "timeZoneId",
  ]) {
    assertHttpsError(
        () => normalizeEditEventPayload(
            cloneValidEditRequest({[key]: "America/New_York"}),
            {now: fixedNow},
        ),
        "invalid-argument",
        "invalid_edit_request",
        key,
        "unknown_key",
    );
  }

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
  assert.equal(payload.normalized.city.cityNameEn, "Moscow");
  assert.equal(payload.normalized.city.cityDisplayContext, "Россия");
  assert.equal(payload.normalized.city.regionCode, null);
  assert.equal(payload.normalized.city.regionNameRu, null);
  assert.equal(payload.normalized.city.regionNameEn, null);
  assert.equal(payload.normalized.city.timeZoneId, "Europe/Moscow");
  assert.equal(payload.normalized.locationGeoPoint, null);
});

test("normalizeEditEventPayload normalizes language codes", () => {
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
    const payload = normalizeEditEventPayload(
        cloneValidEditRequest({languageCode: currentCase.languageCode}),
        {now: fixedNow},
    );

    assert.equal(payload.normalized.language.code, currentCase.code);
    assert.equal(payload.normalized.language.nameEn, currentCase.nameEn);
    assert.equal(payload.normalized.language.nameRu, currentCase.nameRu);
    assert.equal(payload.normalized.hashPayload.languageCode,
        currentCase.code);
  }
});

test("normalizeEditEventPayload rejects client language display payloads", () => {
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
    assertHttpsError(
        () => normalizeEditEventPayload(
            cloneValidEditRequest({[key]: value}),
            {now: fixedNow},
        ),
        "invalid-argument",
        "invalid_edit_request",
        key,
        "unknown_key",
    );
  }
  assertHttpsError(
      () => normalizeEditEventPayload(
          cloneValidEditRequest({languageCode: languageStruct}),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_edit_request",
      "languageCode",
      "invalid_type",
  );
});

test("normalizeEditEventPayload rejects client city display payloads", () => {
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
    assertHttpsError(
        () => normalizeEditEventPayload(
            cloneValidEditRequest({[key]: value}),
            {now: fixedNow},
        ),
        "invalid-argument",
        "invalid_edit_request",
        key,
        "unknown_key",
    );
  }
});

test("normalizeEditEventPayload derives timezone from selected city", () => {
  const payload = normalizeEditEventPayload(
      cloneValidEditRequest({
        countryCode: "US",
        cityKey: "new_york",
        startsAt: "2026-06-16T10:00:00.001Z",
      }),
      {now: fixedNow},
  );

  assert.equal(payload.normalized.city.countryCode, "US");
  assert.equal(payload.normalized.city.cityKey, "new_york");
  assert.equal(payload.normalized.city.cityNameRu, "Нью-Йорк");
  assert.equal(payload.normalized.city.cityNameEn, "New York");
  assert.equal(payload.normalized.city.cityDisplayContext, "United States");
  assert.equal(payload.normalized.city.timeZoneId, "America/New_York");
  assert.equal(payload.normalized.startsAtIso, "2026-06-16T10:00:00.001Z");
  assert.equal(
      payload.normalized.startsAtTimestamp.toMillis(),
      Date.parse("2026-06-16T10:00:00.001Z"),
  );
  assert.equal(
      Object.prototype.hasOwnProperty.call(
          payload.normalized.hashPayload,
          "timeZoneId",
      ),
      false,
  );
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
  assertHttpsError(
      () => normalizeEditEventPayload(
          cloneValidEditRequest({languageCode: "zz"}),
          {now: fixedNow},
      ),
      "invalid-argument",
      "invalid_edit_request",
      "languageCode",
      "invalid_format",
  );
  assertHttpsError(
      () => normalizeEditEventPayload(
          cloneValidEditRequest({startsAt: "2026-06-16T10:00:00.000Z"}),
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

test("editEvent callable validates language before transaction writes",
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
        const {db, reads, writes} = createFakeFirestore({
          "events/event-1": eventData(),
        });

        await withAdminFirestore(db, async () => {
          await assertRejectsHttpsError(
              () => editEvent.run(
                  cloneValidEditRequest(currentCase.overrides),
                  {auth: {uid: "uid"}},
              ),
              "invalid-argument",
              "invalid_edit_request",
              currentCase.field,
              currentCase.reason,
          );
        });

        assert.deepEqual(reads, []);
        assert.deepEqual(writes, []);
      }
    });

test("editEvent callable validates city before transaction writes", async () => {
  const cityStruct = {
    countryCode: "RU",
    cityKey: "moscow",
    cityNameRu: "Поддельная Москва",
    cityNameEn: "Fake Moscow",
    cityDisplayContext: "Client supplied",
    timeZoneId: "America/New_York",
  };
  const cases = [
    {
      overrides: {cityKey: "unknown_city"},
      field: "cityKey",
      reason: "unknown_city",
    },
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
    const {db, reads, writes} = createFakeFirestore({
      "events/event-1": eventData(),
    });

    await withAdminFirestore(db, async () => {
      await assertRejectsHttpsError(
          () => editEvent.run(
              cloneValidEditRequest(currentCase.overrides),
              {auth: {uid: "uid"}},
          ),
          "invalid-argument",
          "invalid_edit_request",
          currentCase.field,
          currentCase.reason || "unknown_key",
      );
    });

    assert.deepEqual(reads, []);
    assert.deepEqual(writes, []);
  }
});

test("editEvent callable validates startsAt against trusted backend time",
    async () => {
      for (const startsAt of [
        "2026-06-16T09:59:59.999Z",
        "2026-06-16T10:00:00.000Z",
      ]) {
        const {db, reads, writes} = createFakeFirestore({
          "events/event-1": eventData(),
        });

        await withAdminFirestore(db, async () => {
          await withSequencedDate(["2026-06-16T10:00:00.000Z"],
              async () => {
                await assertRejectsHttpsError(
                    () => editEvent.run(
                        cloneValidEditRequest({startsAt}),
                        {auth: {uid: "uid"}},
                    ),
                    "invalid-argument",
                    "invalid_edit_request",
                    "startsAt",
                    "past_starts_at",
                );
              });
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
    "events/event-1/participants/uid": participant(),
    "events/event-1/participants/alex": participant(),
    "events/event-1/participants/olga": participant(),
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
  assert.equal(event.languageCode, "en");
  assert.equal(event.languageNameEn, "English");
  assert.equal(event.languageNameRu, "Английский");
  assertNoLanguageStructFields(event);
  assert.equal(event.countryCode, "US");
  assert.equal(event.cityKey, "new_york");
  assert.equal(event.cityNameRu, "Нью-Йорк");
  assert.equal(event.cityNameEn, "New York");
  assert.equal(event.cityDisplayContext, "United States");
  assert.equal(event.timeZoneId, "America/New_York");
  assertNoCityStructFields(event);
  assert.equal(event.capacity, 5);
  assert.equal(event.status, "active");
  assert.equal(event.canceledAt, null);
  assert.equal(event.updatedAt, fixedTimestamp);
  assert.deepEqual(writes.map((write) => write.path), ["events/event-1"]);
  assert.equal(writes[0].data.languageCode, "en");
  assert.equal(writes[0].data.languageNameEn, "English");
  assert.equal(writes[0].data.languageNameRu, "Английский");
  assertNoLanguageStructFields(writes[0].data);
  assert.equal(writes[0].data.countryCode, "US");
  assert.equal(writes[0].data.cityKey, "new_york");
  assert.equal(writes[0].data.cityNameRu, "Нью-Йорк");
  assert.equal(writes[0].data.cityNameEn, "New York");
  assert.equal(writes[0].data.cityDisplayContext, "United States");
  assert.equal(writes[0].data.timeZoneId, "America/New_York");
  assertNoCityStructFields(writes[0].data);
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

test("executeEditEventTransaction rejects participant count drift", async () => {
  const payload = normalizeEditEventPayload(
      cloneValidEditRequest({capacity: 10}),
      {now: fixedNow},
  );

  for (const seed of [
    {
      "events/event-1": eventData({participantsCount: 3}),
      "events/event-1/participants/uid": participant(),
      "events/event-1/participants/alex": participant(),
    },
    {
      "events/event-1": eventData({participantsCount: 2}),
      "events/event-1/participants/uid": participant(),
      "events/event-1/participants/alex": participant(),
      "events/event-1/participants/olga": participant(),
    },
    {
      "events/event-1": eventData({participantsCount: 2}),
      "events/event-1/participants/alex": participant(),
      "events/event-1/participants/olga": participant(),
    },
  ]) {
    const {db, writes} = createFakeFirestore(seed);

    await assertRejectsHttpsError(
        () => executeEditEventTransaction({
          db,
          uid: "uid",
          editDate: fixedNow,
          editTimestamp: fixedTimestamp,
          payload,
        }),
        "failed-precondition",
        "event_participant_state_inconsistent",
    );
    assert.deepEqual(writes, []);
  }
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
