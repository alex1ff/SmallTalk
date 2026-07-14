const crypto = require("node:crypto");
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  CITY_CATALOG_VERSION,
  EVENT_CITY_CATALOG,
  EventCityCatalogError,
  normalizeEventCityIdentityInput,
  resolveEventCityIdentity,
} = require("./event_city_catalog");
const {
  buildBoundedEventChatInboxEventIds,
} = require("./event_chat_inbox");

const REQUEST_TIMEOUT_SECONDS = 30;
const DAILY_CREATE_LIMIT = 5;
const EVENT_STATUS_ACTIVE = "active";
const EVENT_CHAT_COLLECTION = "eventChats";
const EVENT_CREATE_REQUESTS_COLLECTION = "eventCreateRequests";
const EVENT_CREATION_COUNTERS_COLLECTION = "eventCreationCounters";

const CREATE_EVENT_KEYS = Object.freeze([
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
const CREATE_EVENT_KEY_SET = new Set(CREATE_EVENT_KEYS);

const UUID_V4_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const ISO_UTC_MILLIS_RE =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

const LEVEL_RANK = Object.freeze({
  A1: 0,
  A2: 1,
  B1: 2,
  B2: 3,
  C1: 4,
  C2: 5,
});

const LANGUAGE_CATALOG_VERSION = "assets-jsons-languages-catalog-2026-06-16";
const EVENT_LANGUAGE_CATALOG = Object.freeze([
  {
    code: "en",
    alternateCodes: ["en", "en-US", "en-AU", "en-GB", "en-IN", "en-NZ"],
    nameEn: "English",
    nameRu: "Английский",
  },
  {code: "ru", alternateCodes: ["ru"], nameEn: "Russian", nameRu: "Русский"},
  {
    code: "es",
    alternateCodes: ["es", "es-419"],
    nameEn: "Spanish",
    nameRu: "Испанский",
  },
  {
    code: "fr",
    alternateCodes: ["fr", "fr-CA"],
    nameEn: "French",
    nameRu: "Французский",
  },
  {code: "de", alternateCodes: ["de"], nameEn: "German", nameRu: "Немецкий"},
  {
    code: "zh",
    alternateCodes: ["zh", "zh-CN", "zh-Hans"],
    nameEn: "Chinese",
    nameRu: "Китайский",
  },
  {code: "ja", alternateCodes: ["ja"], nameEn: "Japanese", nameRu: "Японский"},
  {
    code: "ko",
    alternateCodes: ["ko", "ko-KR"],
    nameEn: "Korean",
    nameRu: "Корейский",
  },
  {code: "it", alternateCodes: ["it"], nameEn: "Italian", nameRu: "Итальянский"},
  {
    code: "pt",
    alternateCodes: ["pt", "pt-BR", "pt-PT"],
    nameEn: "Portuguese",
    nameRu: "Португальский",
  },
  {code: "hi", alternateCodes: ["hi"], nameEn: "Hindi", nameRu: "Хинди"},
  {code: "bg", alternateCodes: ["bg"], nameEn: "Bulgarian", nameRu: "Болгарский"},
  {code: "cs", alternateCodes: ["cs"], nameEn: "Czech", nameRu: "Чешский"},
  {
    code: "da",
    alternateCodes: ["da", "da-DK"],
    nameEn: "Danish",
    nameRu: "Датский",
  },
  {code: "nl", alternateCodes: ["nl"], nameEn: "Dutch", nameRu: "Нидерландский"},
  {code: "fi", alternateCodes: ["fi"], nameEn: "Finnish", nameRu: "Финский"},
  {code: "hu", alternateCodes: ["hu"], nameEn: "Hungarian", nameRu: "Венгерский"},
  {
    code: "id",
    alternateCodes: ["id"],
    nameEn: "Indonesian",
    nameRu: "Индонезийский",
  },
  {code: "no", alternateCodes: ["no"], nameEn: "Norwegian", nameRu: "Норвежский"},
  {code: "pl", alternateCodes: ["pl"], nameEn: "Polish", nameRu: "Польский"},
  {
    code: "sv",
    alternateCodes: ["sv", "sv-SE"],
    nameEn: "Swedish",
    nameRu: "Шведский",
  },
  {code: "tr", alternateCodes: ["tr"], nameEn: "Turkish", nameRu: "Турецкий"},
  {code: "uk", alternateCodes: ["uk"], nameEn: "Ukrainian", nameRu: "Украинский"},
  {
    code: "vi",
    alternateCodes: ["vi"],
    nameEn: "Vietnamese",
    nameRu: "Вьетнамский",
  },
  {code: "ca", alternateCodes: ["ca"], nameEn: "Catalan", nameRu: "Каталанский"},
  {
    code: "zh-TW",
    alternateCodes: ["zh-TW", "zh-Hant"],
    nameEn: "Chinese (Traditional)",
    nameRu: "Китайский (Традиционный)",
  },
  {
    code: "zh-HK",
    alternateCodes: ["zh-HK"],
    nameEn: "Chinese (Cantonese)",
    nameRu: "Китайский (Кантонский)",
  },
  {code: "et", alternateCodes: ["et"], nameEn: "Estonian", nameRu: "Эстонский"},
  {code: "nl-BE", alternateCodes: ["nl-BE"], nameEn: "Flemish", nameRu: "Фламандский"},
  {
    code: "de-CH",
    alternateCodes: ["de-CH"],
    nameEn: "German (Switzerland)",
    nameRu: "Немецкий (Швейцария)",
  },
  {code: "el", alternateCodes: ["el"], nameEn: "Greek", nameRu: "Греческий"},
  {code: "lv", alternateCodes: ["lv"], nameEn: "Latvian", nameRu: "Латышский"},
  {
    code: "lt",
    alternateCodes: ["lt"],
    nameEn: "Lithuanian",
    nameRu: "Литовский",
  },
  {code: "ms", alternateCodes: ["ms"], nameEn: "Malay", nameRu: "Малайский"},
  {code: "ro", alternateCodes: ["ro"], nameEn: "Romanian", nameRu: "Румынский"},
  {code: "sk", alternateCodes: ["sk"], nameEn: "Slovak", nameRu: "Словацкий"},
  {
    code: "th",
    alternateCodes: ["th", "th-TH"],
    nameEn: "Thai",
    nameRu: "Тайский",
  },
]);

const LANGUAGE_BY_INPUT = buildLanguageLookup(EVENT_LANGUAGE_CATALOG);
const GRAPHEME_SEGMENTER = typeof Intl !== "undefined" && Intl.Segmenter ?
  new Intl.Segmenter("und", {granularity: "grapheme"}) :
  null;

function buildLanguageLookup(catalog) {
  const lookup = new Map();
  for (const language of catalog) {
    const aliases = [language.code, ...(language.alternateCodes || [])];
    for (const alias of aliases) {
      lookup.set(String(alias).trim().toLowerCase(), language);
    }
  }
  return lookup;
}

function throwCreateEventError(code, message, details) {
  throw new functions.https.HttpsError(code, message, details);
}

function throwInvalidCreateRequest(field, reason, message) {
  throwCreateEventError(
      "invalid-argument",
      message || "Invalid create event request",
      {domainCode: "invalid_create_request", field, reason},
  );
}

function throwDailyLimitReached(dayInfo, count) {
  throwCreateEventError(
      "resource-exhausted",
      "Daily event creation limit reached",
      {
        domainCode: "daily_limit_reached",
        resetAtUtc: dayInfo.resetAtUtc,
        dayKeyUtc: dayInfo.dayKeyUtc,
        count,
        limit: DAILY_CREATE_LIMIT,
      },
  );
}

function throwCreateRequestConflict({
  eventId,
  createRequestId,
  dayKeyUtc,
}) {
  throwCreateEventError(
      "already-exists",
      "Create request id was already used with another payload",
      {
        domainCode: "create_request_conflict",
        eventId,
        createRequestId,
        dayKeyUtc,
      },
  );
}

function normalizeTextInput(value, field) {
  if (typeof value !== "string") {
    throwInvalidCreateRequest(field, "invalid_type");
  }
  return value.normalize("NFC");
}

function countGraphemes(value) {
  if (!GRAPHEME_SEGMENTER) {
    return Array.from(value).length;
  }
  return Array.from(GRAPHEME_SEGMENTER.segment(value)).length;
}

function normalizeTitle(value) {
  const text = normalizeTextInput(value, "title");
  if (/[\r\n]/.test(text)) {
    throwInvalidCreateRequest("title", "line_breaks_not_allowed");
  }
  const normalized = text.trim().replace(/\s+/g, " ");
  if (!normalized) {
    throwInvalidCreateRequest("title", "missing");
  }
  if (countGraphemes(normalized) > 70) {
    throwInvalidCreateRequest("title", "too_long");
  }
  return normalized;
}

function normalizeDescription(value) {
  const text = normalizeTextInput(value, "description");
  const normalized = text
      .replace(/\r\n?/g, "\n")
      .split("\n")
      .map((line) => line.trim().replace(/[^\S\n]+/g, " "))
      .join("\n")
      .replace(/\n{3,}/g, "\n\n")
      .trim();

  if (!normalized) {
    throwInvalidCreateRequest("description", "missing");
  }
  if (countGraphemes(normalized) > 1000) {
    throwInvalidCreateRequest("description", "too_long");
  }
  return normalized;
}

function normalizeLocationName(value) {
  const text = normalizeTextInput(value, "locationName")
      .trim()
      .replace(/\s+/g, " ");
  if (!text) {
    throwInvalidCreateRequest("locationName", "missing");
  }
  return text;
}

function normalizeCreateRequestId(value) {
  if (typeof value !== "string") {
    throwInvalidCreateRequest("createRequestId", "invalid_type");
  }
  const normalized = value.trim().toLowerCase();
  if (!UUID_V4_RE.test(normalized)) {
    throwInvalidCreateRequest("createRequestId", "invalid_format");
  }
  return normalized;
}

function normalizeLanguageCode(value) {
  if (typeof value !== "string") {
    throwInvalidCreateRequest("languageCode", "invalid_type");
  }
  const language = LANGUAGE_BY_INPUT.get(value.trim().toLowerCase());
  if (!language) {
    throwInvalidCreateRequest("languageCode", "invalid_format");
  }
  return language;
}

function normalizeLevel(value, field) {
  if (typeof value !== "string") {
    throwInvalidCreateRequest(field, "invalid_type");
  }
  const normalized = value.trim().toUpperCase();
  if (!Object.prototype.hasOwnProperty.call(LEVEL_RANK, normalized)) {
    throwInvalidCreateRequest(field, "invalid_format");
  }
  return normalized;
}

function cityCatalogErrorToHttps(error) {
  if (!(error instanceof EventCityCatalogError)) {
    throw error;
  }
  if (error.internal) {
    throw new functions.https.HttpsError(
        "internal",
        "Configured city catalog is invalid",
        {
          domainCode: "invalid_city_catalog",
          reason: error.reason,
          timeZoneId: error.timeZoneId,
        },
    );
  }
  throwInvalidCreateRequest(error.field, error.reason);
}

function normalizeCityIdentity(countryCodeValue, cityKeyValue, {
  requireKnownCity = true,
} = {}) {
  try {
    return requireKnownCity ?
      resolveEventCityIdentity(countryCodeValue, cityKeyValue) :
      normalizeEventCityIdentityInput(countryCodeValue, cityKeyValue);
  } catch (err) {
    cityCatalogErrorToHttps(err);
  }
}

function resolveNormalizedCity(normalized) {
  if (normalized.city.timeZoneId) {
    return normalized;
  }
  const city = normalizeCityIdentity(
      normalized.city.countryCode,
      normalized.city.cityKey,
      {requireKnownCity: true},
  );
  return {
    ...normalized,
    city,
  };
}

function normalizeGeoPoint(value) {
  if (value === null) {
    return {hashValue: null, firestoreValue: null};
  }
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throwInvalidCreateRequest("locationGeoPoint", "invalid_type");
  }
  const keys = Object.keys(value).sort();
  if (keys.join(",") !== "latitude,longitude") {
    throwInvalidCreateRequest("locationGeoPoint", "unknown_key");
  }
  const latitude = value.latitude;
  const longitude = value.longitude;
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throwInvalidCreateRequest("locationGeoPoint", "invalid_type");
  }
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    throwInvalidCreateRequest("locationGeoPoint", "out_of_range");
  }

  const hashValue = {
    latitude: Object.is(latitude, -0) ? 0 : latitude,
    longitude: Object.is(longitude, -0) ? 0 : longitude,
  };
  return {
    hashValue,
    firestoreValue: new admin.firestore.GeoPoint(
        hashValue.latitude,
        hashValue.longitude,
    ),
  };
}

function normalizeStartsAt(value, {
  now = new Date(),
  requireFuture = true,
} = {}) {
  if (typeof value !== "string") {
    throwInvalidCreateRequest("startsAt", "invalid_type");
  }
  const normalized = value.trim();
  if (!ISO_UTC_MILLIS_RE.test(normalized)) {
    throwInvalidCreateRequest("startsAt", "invalid_format");
  }
  const timestamp = Date.parse(normalized);
  if (!Number.isFinite(timestamp)) {
    throwInvalidCreateRequest("startsAt", "invalid_format");
  }
  const date = new Date(timestamp);
  if (date.toISOString() !== normalized) {
    throwInvalidCreateRequest("startsAt", "invalid_format");
  }
  if (requireFuture && date.getTime() <= now.getTime()) {
    throwInvalidCreateRequest("startsAt", "past_starts_at");
  }
  return {
    iso: normalized,
    date,
    timestamp: admin.firestore.Timestamp.fromDate(date),
  };
}

function normalizeCapacity(value) {
  if (!Number.isInteger(value)) {
    throwInvalidCreateRequest("capacity", "invalid_type");
  }
  if (value < 2 || value > 50) {
    throwInvalidCreateRequest("capacity", "out_of_range");
  }
  return value;
}

function validateExactCreateEventKeys(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throwInvalidCreateRequest("payload", "invalid_type");
  }

  for (const key of Object.keys(data)) {
    if (!CREATE_EVENT_KEY_SET.has(key)) {
      throwInvalidCreateRequest(key, "unknown_key");
    }
  }
  for (const key of CREATE_EVENT_KEYS) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) {
      throwInvalidCreateRequest(key, "missing");
    }
  }
}

function normalizeCreateEventPayload(data, {
  now = new Date(),
  requireFutureStartsAt = true,
  requireKnownCity = true,
} = {}) {
  validateExactCreateEventKeys(data);

  const createRequestId = normalizeCreateRequestId(data.createRequestId);
  const title = normalizeTitle(data.title);
  const description = normalizeDescription(data.description);
  const language = normalizeLanguageCode(data.languageCode);
  const levelMin = normalizeLevel(data.levelMin, "levelMin");
  const levelMax = normalizeLevel(data.levelMax, "levelMax");
  if (LEVEL_RANK[levelMin] > LEVEL_RANK[levelMax]) {
    throwInvalidCreateRequest("levelMax", "out_of_range");
  }
  const city = normalizeCityIdentity(data.countryCode, data.cityKey, {
    requireKnownCity,
  });
  const locationName = normalizeLocationName(data.locationName);
  const geoPoint = normalizeGeoPoint(data.locationGeoPoint);
  const startsAt = normalizeStartsAt(data.startsAt, {
    now,
    requireFuture: requireFutureStartsAt,
  });
  const capacity = normalizeCapacity(data.capacity);

  const hashPayload = {
    title,
    description,
    languageCode: language.code,
    levelMin,
    levelMax,
    countryCode: city.countryCode,
    cityKey: city.cityKey,
    locationName,
    locationGeoPoint: geoPoint.hashValue,
    startsAt: startsAt.iso,
    capacity,
  };

  return {
    createRequestId,
    title,
    description,
    language,
    levelMin,
    levelMax,
    city,
    locationName,
    locationGeoPoint: geoPoint.firestoreValue,
    locationGeoPointHashValue: geoPoint.hashValue,
    startsAtIso: startsAt.iso,
    startsAtDate: startsAt.date,
    startsAtTimestamp: startsAt.timestamp,
    capacity,
    hashPayload,
  };
}

function assertFutureStartsAt(normalized, now) {
  if (normalized.startsAtDate.getTime() <= now.getTime()) {
    throwInvalidCreateRequest("startsAt", "past_starts_at");
  }
}

function canonicalize(value) {
  if (value === null) {
    return "null";
  }
  if (typeof value === "string") {
    return JSON.stringify(value.normalize("NFC"));
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new Error("Cannot canonicalize non-finite number");
    }
    return JSON.stringify(Object.is(value, -0) ? 0 : value);
  }
  if (typeof value === "boolean") {
    return value ? "true" : "false";
  }
  if (Array.isArray(value)) {
    return `[${value.map((item) => canonicalize(item)).join(",")}]`;
  }
  if (typeof value === "object") {
    const keys = Object.keys(value).sort();
    return `{${keys.map((key) =>
      `${JSON.stringify(key)}:${canonicalize(value[key])}`,
    ).join(",")}}`;
  }
  throw new Error(`Unsupported canonical value: ${typeof value}`);
}

function hashCreatePayload(hashPayload) {
  return crypto
      .createHash("sha256")
      .update(canonicalize(hashPayload), "utf8")
      .digest("hex");
}

function pad2(value) {
  return String(value).padStart(2, "0");
}

function buildUtcDayInfo(now) {
  const year = now.getUTCFullYear();
  const monthIndex = now.getUTCMonth();
  const day = now.getUTCDate();
  const month = pad2(monthIndex + 1);
  const dayText = pad2(day);
  const startDate = new Date(Date.UTC(year, monthIndex, day));
  const endDate = new Date(startDate.getTime() + 24 * 60 * 60 * 1000);

  return {
    dayKeyUtc: `${year}-${month}-${dayText}`,
    dayKeyCompact: `${year}${month}${dayText}`,
    windowStartAt: admin.firestore.Timestamp.fromDate(startDate),
    windowEndAt: admin.firestore.Timestamp.fromDate(endDate),
    resetAtUtc: endDate.toISOString(),
  };
}

function buildDailyCreation(count, dayInfo) {
  return {
    dayKeyUtc: dayInfo.dayKeyUtc,
    count,
    remaining: Math.max(DAILY_CREATE_LIMIT - count, 0),
    resetAtUtc: dayInfo.resetAtUtc,
  };
}

function hasPlainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function hasTimestampValue(value) {
  return Boolean(value) && typeof value.toMillis === "function";
}

function timestampMillis(value) {
  return hasTimestampValue(value) ? value.toMillis() : NaN;
}

function isNonEmptyPathSegment(value) {
  return typeof value === "string" && value.length > 0 && !value.includes("/");
}

function isSha256Hex(value) {
  return typeof value === "string" && /^[0-9a-f]{64}$/.test(value);
}

function failCounterInconsistent() {
  throw new functions.https.HttpsError(
      "failed-precondition",
      "Event creation counter is inconsistent",
      {domainCode: "event_creation_counter_inconsistent"},
  );
}

function validateExistingCounter(counterData = {}, {
  allowMissing = false,
  uid = "",
  dayInfo = null,
} = {}) {
  if (allowMissing && Object.keys(counterData).length === 0) {
    return {
      count: 0,
      eventIds: [],
      requestEventIds: {},
      requestPayloadHashes: {},
    };
  }

  const hasCount = Object.prototype.hasOwnProperty.call(counterData, "count");
  const hasEventIds =
    Object.prototype.hasOwnProperty.call(counterData, "eventIds");
  const hasRequestEventIds =
    Object.prototype.hasOwnProperty.call(counterData, "requestEventIds");
  const hasRequestPayloadHashes =
    Object.prototype.hasOwnProperty.call(counterData, "requestPayloadHashes");
  const hasUserId =
    Object.prototype.hasOwnProperty.call(counterData, "userId");
  const hasDayKeyUtc =
    Object.prototype.hasOwnProperty.call(counterData, "dayKeyUtc");
  const hasWindowStartAt =
    Object.prototype.hasOwnProperty.call(counterData, "windowStartAt");
  const hasWindowEndAt =
    Object.prototype.hasOwnProperty.call(counterData, "windowEndAt");
  const hasCreatedAt =
    Object.prototype.hasOwnProperty.call(counterData, "createdAt");
  const hasUpdatedAt =
    Object.prototype.hasOwnProperty.call(counterData, "updatedAt");
  const hasRequiredFields = hasCount &&
    hasEventIds &&
    hasRequestEventIds &&
    hasRequestPayloadHashes &&
    hasUserId &&
    hasDayKeyUtc &&
    hasWindowStartAt &&
    hasWindowEndAt &&
    hasCreatedAt &&
    hasUpdatedAt;
  const count = counterData.count;
  const eventIds = counterData.eventIds;
  const requestEventIds = counterData.requestEventIds;
  const requestPayloadHashes = counterData.requestPayloadHashes;
  const requestIds = hasPlainObject(requestEventIds) ?
    Object.keys(requestEventIds).sort() :
    [];
  const hashRequestIds = hasPlainObject(requestPayloadHashes) ?
    Object.keys(requestPayloadHashes).sort() :
    [];
  const requestEventIdValues = hasPlainObject(requestEventIds) ?
    Object.values(requestEventIds).sort() :
    [];
  const sortedEventIds = Array.isArray(eventIds) ? [...eventIds].sort() : [];

  if (
    (!allowMissing && !hasRequiredFields) ||
    !Number.isInteger(count) ||
    count < 0 ||
    count > DAILY_CREATE_LIMIT ||
    !Array.isArray(eventIds) ||
    !hasPlainObject(requestEventIds) ||
    !hasPlainObject(requestPayloadHashes) ||
    count !== eventIds.length ||
    count !== requestIds.length ||
    requestIds.join("\n") !== hashRequestIds.join("\n") ||
    requestEventIdValues.join("\n") !== sortedEventIds.join("\n") ||
    new Set(eventIds).size !== eventIds.length
  ) {
    failCounterInconsistent();
  }

  if (
    counterData.userId !== uid ||
    counterData.dayKeyUtc !== dayInfo?.dayKeyUtc ||
    timestampMillis(counterData.windowStartAt) !==
      timestampMillis(dayInfo?.windowStartAt) ||
    timestampMillis(counterData.windowEndAt) !==
      timestampMillis(dayInfo?.windowEndAt) ||
    !hasTimestampValue(counterData.createdAt) ||
    !hasTimestampValue(counterData.updatedAt)
  ) {
    failCounterInconsistent();
  }

  for (const eventId of eventIds) {
    if (!isNonEmptyPathSegment(eventId)) {
      failCounterInconsistent();
    }
  }
  for (const requestId of requestIds) {
    if (
      !UUID_V4_RE.test(requestId) ||
      !isNonEmptyPathSegment(requestEventIds[requestId]) ||
      !isSha256Hex(requestPayloadHashes[requestId])
    ) {
      failCounterInconsistent();
    }
  }

  for (const eventId of Object.values(requestEventIds)) {
    if (!eventIds.includes(eventId)) {
      failCounterInconsistent();
    }
  }

  return {
    count,
    eventIds: [...eventIds],
    requestEventIds: {...requestEventIds},
    requestPayloadHashes: {...requestPayloadHashes},
  };
}

function buildNextCounterState({
  counterExists,
  counterData = {},
  uid,
  createRequestId,
  eventId,
  payloadHash,
  dayInfo,
  creationTimestamp,
}) {
  const existing = counterExists ?
    validateExistingCounter(counterData, {uid, dayInfo}) :
    validateExistingCounter({}, {allowMissing: true});

  if (Object.prototype.hasOwnProperty.call(
      existing.requestEventIds,
      createRequestId,
  )) {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "Create request marker is missing for an already counted request",
        {domainCode: "create_request_marker_missing"},
    );
  }

  if (existing.count >= DAILY_CREATE_LIMIT) {
    throwDailyLimitReached(dayInfo, existing.count);
  }

  const eventIds = [...existing.eventIds, eventId];
  const requestEventIds = {
    ...existing.requestEventIds,
    [createRequestId]: eventId,
  };
  const requestPayloadHashes = {
    ...existing.requestPayloadHashes,
    [createRequestId]: payloadHash,
  };

  return {
    userId: uid,
    dayKeyUtc: dayInfo.dayKeyUtc,
    count: eventIds.length,
    eventIds,
    requestEventIds,
    requestPayloadHashes,
    windowStartAt: dayInfo.windowStartAt,
    windowEndAt: dayInfo.windowEndAt,
    createdAt: counterExists && counterData.createdAt ?
      counterData.createdAt :
      creationTimestamp,
    updatedAt: creationTimestamp,
  };
}

function normalizeProfileString(value) {
  return typeof value === "string" ? value.normalize("NFC").trim() : "";
}

function buildOrganizerSnapshot({userExists, userData = {}}) {
  if (!userExists) {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "Organizer profile must exist",
        {domainCode: "organizer_profile_required", field: "display_name"},
    );
  }
  const displayName = normalizeProfileString(userData.display_name);
  if (!displayName) {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "Organizer display name is required",
        {domainCode: "organizer_profile_required", field: "display_name"},
    );
  }
  const photoUrl = normalizeProfileString(userData.photo_url);
  return {
    displayName,
    photoUrl: photoUrl || null,
  };
}

function buildEventData({
  normalized,
  uid,
  eventId,
  organizerSnapshot,
  creationTimestamp,
}) {
  return {
    title: normalized.title,
    description: normalized.description,
    languageCode: normalized.language.code,
    languageNameEn: normalized.language.nameEn,
    languageNameRu: normalized.language.nameRu,
    levelMin: normalized.levelMin,
    levelMax: normalized.levelMax,
    countryCode: normalized.city.countryCode,
    cityKey: normalized.city.cityKey,
    cityNameRu: normalized.city.cityNameRu,
    cityNameEn: normalized.city.cityNameEn,
    cityDisplayContext: normalized.city.cityDisplayContext,
    locationName: normalized.locationName,
    locationGeoPoint: normalized.locationGeoPoint,
    startsAt: normalized.startsAtTimestamp,
    capacity: normalized.capacity,
    participantsCount: 1,
    organizerId: uid,
    organizerDisplayName: organizerSnapshot.displayName,
    organizerPhotoUrl: organizerSnapshot.photoUrl,
    chatId: eventId,
    status: EVENT_STATUS_ACTIVE,
    timeZoneId: normalized.city.timeZoneId,
    createdAt: creationTimestamp,
    updatedAt: creationTimestamp,
    canceledAt: null,
  };
}

function buildEventEditableUpdate({normalized, editTimestamp}) {
  return {
    title: normalized.title,
    description: normalized.description,
    languageCode: normalized.language.code,
    languageNameEn: normalized.language.nameEn,
    languageNameRu: normalized.language.nameRu,
    levelMin: normalized.levelMin,
    levelMax: normalized.levelMax,
    countryCode: normalized.city.countryCode,
    cityKey: normalized.city.cityKey,
    cityNameRu: normalized.city.cityNameRu,
    cityNameEn: normalized.city.cityNameEn,
    cityDisplayContext: normalized.city.cityDisplayContext,
    locationName: normalized.locationName,
    locationGeoPoint: normalized.locationGeoPoint,
    startsAt: normalized.startsAtTimestamp,
    capacity: normalized.capacity,
    timeZoneId: normalized.city.timeZoneId,
    updatedAt: editTimestamp,
  };
}

function buildOrganizerParticipantData({
  uid,
  organizerSnapshot,
  creationTimestamp,
}) {
  return {
    userId: uid,
    displayName: organizerSnapshot.displayName,
    photoUrl: organizerSnapshot.photoUrl,
    role: "organizer",
    status: "active",
    joinedAt: creationTimestamp,
    leftAt: null,
    createdAt: creationTimestamp,
    updatedAt: creationTimestamp,
  };
}

function buildEventChatData({eventId, uid, creationTimestamp}) {
  return {
    eventId,
    readAccessUserIds: [uid],
    createdAt: creationTimestamp,
    updatedAt: creationTimestamp,
  };
}

function buildCreateRequestMarker({
  uid,
  createRequestId,
  eventId,
  payloadHash,
  counterPath,
  dayInfo,
  dailyCreation,
  creationTimestamp,
}) {
  return {
    userId: uid,
    createRequestId,
    eventId,
    payloadHash,
    counterPath,
    dayKeyUtc: dayInfo.dayKeyUtc,
    dailyCreation,
    status: "created",
    createdAt: creationTimestamp,
    updatedAt: creationTimestamp,
  };
}

function timestampToIso(value) {
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (value && typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }
  if (value && typeof value.toMillis === "function") {
    return new Date(value.toMillis()).toISOString();
  }
  if (typeof value === "string") {
    return value;
  }
  return "";
}

function failMarkerInconsistent() {
  throw new functions.https.HttpsError(
      "failed-precondition",
      "Create request marker is inconsistent",
      {domainCode: "create_request_marker_inconsistent"},
  );
}

function validateDailyCreationSnapshot(dailyCreation, dayKeyUtc) {
  if (!hasPlainObject(dailyCreation)) {
    failMarkerInconsistent();
  }
  const keys = Object.keys(dailyCreation).sort();
  const expectedKeys = ["count", "dayKeyUtc", "remaining", "resetAtUtc"];
  if (keys.join("\n") !== expectedKeys.join("\n")) {
    failMarkerInconsistent();
  }
  const count = dailyCreation.count;
  const remaining = dailyCreation.remaining;
  if (
    dailyCreation.dayKeyUtc !== dayKeyUtc ||
    !Number.isInteger(count) ||
    count < 1 ||
    count > DAILY_CREATE_LIMIT ||
    !Number.isInteger(remaining) ||
    remaining !== DAILY_CREATE_LIMIT - count ||
    typeof dailyCreation.resetAtUtc !== "string" ||
    !ISO_UTC_MILLIS_RE.test(dailyCreation.resetAtUtc) ||
    !Number.isFinite(Date.parse(dailyCreation.resetAtUtc))
  ) {
    failMarkerInconsistent();
  }
}

function buildExistingCreateResponse({
  markerData,
  uid = "",
  createRequestId,
  payloadHash,
}) {
  const expectedCounterPath = markerData.dayKeyUtc ?
    `${EVENT_CREATION_COUNTERS_COLLECTION}/${uid}/days/` +
      `${String(markerData.dayKeyUtc).replace(/-/g, "")}` :
    "";

  if (
    markerData.userId !== uid ||
    markerData.createRequestId !== createRequestId ||
    !isNonEmptyPathSegment(markerData.eventId) ||
    markerData.status !== "created" ||
    !isSha256Hex(markerData.payloadHash) ||
    !/^\d{4}-\d{2}-\d{2}$/.test(String(markerData.dayKeyUtc || "")) ||
    markerData.counterPath !== expectedCounterPath ||
    !hasTimestampValue(markerData.createdAt) ||
    !hasTimestampValue(markerData.updatedAt)
  ) {
    failMarkerInconsistent();
  }

  if (markerData.payloadHash !== payloadHash) {
    throwCreateRequestConflict({
      eventId: String(markerData.eventId || ""),
      createRequestId,
      dayKeyUtc: String(markerData.dayKeyUtc || ""),
    });
  }

  const createdAt = timestampToIso(markerData.createdAt);
  if (!createdAt) {
    failMarkerInconsistent();
  }
  validateDailyCreationSnapshot(markerData.dailyCreation, markerData.dayKeyUtc);

  return {
    eventId: markerData.eventId,
    createdAt,
    dailyCreation: markerData.dailyCreation,
  };
}

function buildCreateEventRefs({db, uid, createRequestId, dayInfo, eventRef}) {
  return {
    userRef: db.collection("users").doc(uid),
    eventRef,
    participantRef: eventRef.collection("participants").doc(uid),
    chatRef: db.collection(EVENT_CHAT_COLLECTION).doc(eventRef.id),
    counterRef: db
        .collection(EVENT_CREATION_COUNTERS_COLLECTION)
        .doc(uid)
        .collection("days")
        .doc(dayInfo.dayKeyCompact),
    markerRef: db
        .collection(EVENT_CREATE_REQUESTS_COLLECTION)
        .doc(uid)
        .collection("requests")
        .doc(createRequestId),
  };
}

async function executeCreateEventTransaction({
  db,
  uid,
  creationDate,
  creationTimestamp,
  dayInfo,
  normalized,
  payloadHash,
  eventRef = db.collection("events").doc(),
}) {
  const refs = buildCreateEventRefs({
    db,
    uid,
    createRequestId: normalized.createRequestId,
    dayInfo,
    eventRef,
  });

  return await db.runTransaction(async (tx) => {
    const markerDoc = await tx.get(refs.markerRef);
    if (markerDoc.exists) {
      return buildExistingCreateResponse({
        markerData: markerDoc.data() || {},
        uid,
        createRequestId: normalized.createRequestId,
        payloadHash,
      });
    }
    assertFutureStartsAt(normalized, creationDate);
    const eventNormalized = resolveNormalizedCity(normalized);

    const [counterDoc, userDoc] = await Promise.all([
      tx.get(refs.counterRef),
      tx.get(refs.userRef),
    ]);
    const organizerSnapshot = buildOrganizerSnapshot({
      userExists: userDoc.exists,
      userData: userDoc.exists ? userDoc.data() || {} : {},
    });
    const nextCounter = buildNextCounterState({
      counterExists: counterDoc.exists,
      counterData: counterDoc.exists ? counterDoc.data() || {} : {},
      uid,
      createRequestId: normalized.createRequestId,
      eventId: refs.eventRef.id,
      payloadHash,
      dayInfo,
      creationTimestamp,
    });
    const dailyCreation = buildDailyCreation(nextCounter.count, dayInfo);

    tx.create(refs.eventRef, buildEventData({
      normalized: eventNormalized,
      uid,
      eventId: refs.eventRef.id,
      organizerSnapshot,
      creationTimestamp,
    }));
    tx.create(refs.participantRef, buildOrganizerParticipantData({
      uid,
      organizerSnapshot,
      creationTimestamp,
    }));
    tx.create(refs.chatRef, buildEventChatData({
      eventId: refs.eventRef.id,
      uid,
      creationTimestamp,
    }));
    tx.update(refs.userRef, {
      eventChatInboxEventIds: buildBoundedEventChatInboxEventIds(
          userDoc.data()?.eventChatInboxEventIds,
          refs.eventRef.id,
      ),
      hiddenChatKeys: admin.firestore.FieldValue.arrayRemove(
          `event:${refs.eventRef.id}`,
      ),
    });
    tx.set(refs.counterRef, nextCounter);
    tx.create(refs.markerRef, buildCreateRequestMarker({
      uid,
      createRequestId: normalized.createRequestId,
      eventId: refs.eventRef.id,
      payloadHash,
      counterPath: refs.counterRef.path,
      dayInfo,
      dailyCreation,
      creationTimestamp,
    }));

    return {
      eventId: refs.eventRef.id,
      createdAt: creationDate.toISOString(),
      dailyCreation,
    };
  });
}

exports.__private__ = {
  CITY_CATALOG_VERSION,
  CREATE_EVENT_KEYS,
  DAILY_CREATE_LIMIT,
  EVENT_CITY_CATALOG,
  EVENT_LANGUAGE_CATALOG,
  LANGUAGE_CATALOG_VERSION,
  buildCreateRequestMarker,
  buildDailyCreation,
  buildEventChatData,
  buildEventData,
  buildEventEditableUpdate,
  buildExistingCreateResponse,
  buildNextCounterState,
  buildOrganizerParticipantData,
  buildOrganizerSnapshot,
  buildUtcDayInfo,
  canonicalize,
  executeCreateEventTransaction,
  hashCreatePayload,
  assertFutureStartsAt,
  normalizeCreateEventPayload,
  normalizeCreateRequestId,
  resolveNormalizedCity,
  validateExistingCounter,
};

exports.createEvent = functions
    .runWith({timeoutSeconds: REQUEST_TIMEOUT_SECONDS, memory: "256MB"})
    .https.onCall(async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be authenticated",
            {domainCode: "auth_required"},
        );
      }

      const uid = context.auth.uid;
      const creationDate = new Date();
      const creationTimestamp =
        admin.firestore.Timestamp.fromDate(creationDate);
      const dayInfo = buildUtcDayInfo(creationDate);
      const normalized = normalizeCreateEventPayload(data, {
        now: creationDate,
        requireFutureStartsAt: false,
        requireKnownCity: false,
      });
      const payloadHash = hashCreatePayload(normalized.hashPayload);

      const db = admin.firestore();

      try {
        return await executeCreateEventTransaction({
          db,
          uid,
          creationDate,
          creationTimestamp,
          dayInfo,
          normalized,
          payloadHash,
        });
      } catch (err) {
        if (err instanceof functions.https.HttpsError) {
          throw err;
        }
        console.error("createEvent failed", {uid, err});
        throw new functions.https.HttpsError(
            "internal",
            "Unable to create event",
        );
      }
    });
