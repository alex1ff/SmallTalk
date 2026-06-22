const SEARCH_REQUEST_COLLECTION = "searchRequests";

const SEARCH_REQUEST_STATUS = Object.freeze({
  ACTIVE: "active",
  MATCHING: "matching",
  MATCHED: "matched",
  STOPPED: "stopped",
  EXPIRED: "expired",
  CANCELLED: "cancelled",
  ERROR: "error",
  LEGACY_SEARCHING: "searching",
  LEGACY_FAILED: "failed",
  LEGACY_COMPLETED: "completed",
});

const SEARCH_REQUEST_CANONICAL_STATUSES = Object.freeze([
  SEARCH_REQUEST_STATUS.ACTIVE,
  SEARCH_REQUEST_STATUS.MATCHING,
  SEARCH_REQUEST_STATUS.MATCHED,
  SEARCH_REQUEST_STATUS.STOPPED,
  SEARCH_REQUEST_STATUS.EXPIRED,
  SEARCH_REQUEST_STATUS.CANCELLED,
  SEARCH_REQUEST_STATUS.ERROR,
]);

const SEARCH_REQUEST_APP_STATE = Object.freeze({
  FOREGROUND: "foreground",
  BACKGROUND: "background",
  INACTIVE: "inactive",
  UNKNOWN: "unknown",
});

const SEARCH_REQUEST_TIMING = Object.freeze({
  HEARTBEAT_INTERVAL_SECONDS: 30,
  HEARTBEAT_STALE_SECONDS: 90,
  MAX_SEARCH_SECONDS: 10 * 60,
  BACKGROUND_MAX_SEARCH_SECONDS: 10 * 60,
});

const SEARCH_REQUEST_FIELD = Object.freeze({
  REQUEST_ID: "requestId",
  USER_ID: "userId",
  USER_REF: "userRef",
  ROLE: "role",
  LANGUAGE: "language",
  FILTERS: "filters",
  STATUS: "status",
  APP_STATE: "appState",
  APP_STATE_UPDATED_AT: "appStateUpdatedAt",
  PLATFORM: "platform",
  CREATED_AT: "createdAt",
  UPDATED_AT: "updatedAt",
  HEARTBEAT_AT: "heartbeatAt",
  EXPIRES_AT: "expiresAt",
  BACKGROUND_EXPIRES_AT: "backgroundExpiresAt",
  ACTIVE_SESSION_ID: "activeSessionId",
  CURRENT_SESSION_ID: "currentSessionId",
  MATCHED_SESSION_ID: "matchedSessionId",
  MATCHED_USER_ID: "matchedUserId",
  MATCHED_RESPONDER_ID: "matchedResponderId",
  MATCHED_ROLE: "matchedRole",
  PAIR_ATTEMPT_ID: "pairAttemptId",
  EXCLUDED_CANDIDATE_IDS: "excludedCandidateIds",
  ATTEMPT_EXCLUDED_CANDIDATE_IDS: "attemptExcludedCandidateIds",
  LOCK_OWNER: "lockOwner",
  LOCK_EXPIRES_AT: "lockExpiresAt",
  VERSION: "version",
  STOP_REASON: "stopReason",
  STOPPED_AT: "stoppedAt",
  STOPPED_BY: "stoppedBy",
  LAST_ERROR: "lastError",
  ERROR_CODE: "errorCode",
  ERROR_MESSAGE: "errorMessage",
});

const SEARCH_REQUEST_FILTER_FIELD = Object.freeze({
  PREFERRED_LEVEL: "preferredLevel",
  LEVEL_RANK: "levelRank",
  COUNTRY_CODE: "countryCode",
  CITY_KEY: "cityKey",
});

const SEARCH_REQUEST_ALLOWED_FILTER_FIELDS = Object.freeze(
  Object.values(SEARCH_REQUEST_FILTER_FIELD),
);

const SEARCH_REQUEST_LEVEL_RANK = Object.freeze({
  A1: 1,
  A2: 2,
  B1: 3,
  B2: 4,
  C1: 5,
  C2: 6,
});
const SEARCH_REQUEST_LEVEL_ALIASES = Object.freeze({
  BEGINNER: "A1",
  BASIC: "A2",
  INTERMEDIATE: "B1",
  FLUENT: "C1",
});

const SEARCH_REQUEST_REQUIRED_FIELDS = Object.freeze([
  SEARCH_REQUEST_FIELD.REQUEST_ID,
  SEARCH_REQUEST_FIELD.USER_ID,
  SEARCH_REQUEST_FIELD.USER_REF,
  SEARCH_REQUEST_FIELD.ROLE,
  SEARCH_REQUEST_FIELD.LANGUAGE,
  SEARCH_REQUEST_FIELD.FILTERS,
  SEARCH_REQUEST_FIELD.STATUS,
  SEARCH_REQUEST_FIELD.APP_STATE,
  SEARCH_REQUEST_FIELD.APP_STATE_UPDATED_AT,
  SEARCH_REQUEST_FIELD.CREATED_AT,
  SEARCH_REQUEST_FIELD.UPDATED_AT,
  SEARCH_REQUEST_FIELD.HEARTBEAT_AT,
  SEARCH_REQUEST_FIELD.EXPIRES_AT,
  SEARCH_REQUEST_FIELD.BACKGROUND_EXPIRES_AT,
  SEARCH_REQUEST_FIELD.CURRENT_SESSION_ID,
  SEARCH_REQUEST_FIELD.MATCHED_USER_ID,
  SEARCH_REQUEST_FIELD.MATCHED_ROLE,
  SEARCH_REQUEST_FIELD.PAIR_ATTEMPT_ID,
  SEARCH_REQUEST_FIELD.EXCLUDED_CANDIDATE_IDS,
  SEARCH_REQUEST_FIELD.ATTEMPT_EXCLUDED_CANDIDATE_IDS,
  SEARCH_REQUEST_FIELD.LOCK_OWNER,
  SEARCH_REQUEST_FIELD.LOCK_EXPIRES_AT,
  SEARCH_REQUEST_FIELD.VERSION,
  SEARCH_REQUEST_FIELD.STOP_REASON,
  SEARCH_REQUEST_FIELD.STOPPED_AT,
  SEARCH_REQUEST_FIELD.LAST_ERROR,
]);

const SEARCH_REQUEST_SERVER_OWNED_FIELDS = Object.freeze([
  SEARCH_REQUEST_FIELD.STATUS,
  SEARCH_REQUEST_FIELD.CREATED_AT,
  SEARCH_REQUEST_FIELD.UPDATED_AT,
  SEARCH_REQUEST_FIELD.HEARTBEAT_AT,
  SEARCH_REQUEST_FIELD.EXPIRES_AT,
  SEARCH_REQUEST_FIELD.BACKGROUND_EXPIRES_AT,
  SEARCH_REQUEST_FIELD.APP_STATE_UPDATED_AT,
  SEARCH_REQUEST_FIELD.ACTIVE_SESSION_ID,
  SEARCH_REQUEST_FIELD.CURRENT_SESSION_ID,
  SEARCH_REQUEST_FIELD.MATCHED_SESSION_ID,
  SEARCH_REQUEST_FIELD.MATCHED_USER_ID,
  SEARCH_REQUEST_FIELD.MATCHED_RESPONDER_ID,
  SEARCH_REQUEST_FIELD.MATCHED_ROLE,
  SEARCH_REQUEST_FIELD.PAIR_ATTEMPT_ID,
  SEARCH_REQUEST_FIELD.EXCLUDED_CANDIDATE_IDS,
  SEARCH_REQUEST_FIELD.ATTEMPT_EXCLUDED_CANDIDATE_IDS,
  SEARCH_REQUEST_FIELD.LOCK_OWNER,
  SEARCH_REQUEST_FIELD.LOCK_EXPIRES_AT,
  SEARCH_REQUEST_FIELD.VERSION,
  SEARCH_REQUEST_FIELD.STOP_REASON,
  SEARCH_REQUEST_FIELD.STOPPED_AT,
  SEARCH_REQUEST_FIELD.STOPPED_BY,
  SEARCH_REQUEST_FIELD.LAST_ERROR,
  SEARCH_REQUEST_FIELD.ERROR_CODE,
  SEARCH_REQUEST_FIELD.ERROR_MESSAGE,
]);

const SEARCH_REQUEST_ACTIVE_STATUSES = Object.freeze([
  SEARCH_REQUEST_STATUS.ACTIVE,
  SEARCH_REQUEST_STATUS.MATCHING,
  SEARCH_REQUEST_STATUS.MATCHED,
  SEARCH_REQUEST_STATUS.LEGACY_SEARCHING,
]);

const SEARCH_REQUEST_TERMINAL_STATUSES = Object.freeze([
  SEARCH_REQUEST_STATUS.STOPPED,
  SEARCH_REQUEST_STATUS.EXPIRED,
  SEARCH_REQUEST_STATUS.CANCELLED,
  SEARCH_REQUEST_STATUS.ERROR,
  SEARCH_REQUEST_STATUS.LEGACY_FAILED,
  SEARCH_REQUEST_STATUS.LEGACY_COMPLETED,
]);

const SEARCH_REQUEST_PUBLIC_PROFILE_FIELDS = Object.freeze([
  "displayName",
  "display_name",
  "photoUrl",
  "photo_url",
  "email",
  "phone",
]);

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function normalizeSearchRequestStatus(status) {
  return typeof status === "string" ? status.trim() : "";
}

function isActiveSearchRequestStatus(status) {
  return SEARCH_REQUEST_ACTIVE_STATUSES.includes(
    normalizeSearchRequestStatus(status),
  );
}

function isTerminalSearchRequestStatus(status) {
  return SEARCH_REQUEST_TERMINAL_STATUSES.includes(
    normalizeSearchRequestStatus(status),
  );
}

function normalizeAppState(appState) {
  const normalized = typeof appState === "string" ? appState.trim() : "";
  return Object.values(SEARCH_REQUEST_APP_STATE).includes(normalized) ?
    normalized :
    SEARCH_REQUEST_APP_STATE.UNKNOWN;
}

function normalizeSearchRequestLevel(level) {
  const rawLevel = typeof level === "string" ?
    level :
    (level && typeof level === "object" ?
      level.code || level.value || level.name || "" :
      "");
  const normalized = String(rawLevel || "").trim().toUpperCase();
  if (Object.hasOwn(SEARCH_REQUEST_LEVEL_RANK, normalized)) {
    return normalized;
  }
  return SEARCH_REQUEST_LEVEL_ALIASES[normalized] || "";
}

function normalizeSearchRequestRank(rank) {
  const numericRank = typeof rank === "number" ?
    rank :
    Number.parseInt(String(rank || "").trim(), 10);

  return Number.isInteger(numericRank) &&
    numericRank >= 1 &&
    numericRank <= 6 ?
    numericRank :
    null;
}

function normalizeSearchRequestCountryCode(countryCode) {
  const normalized =
    typeof countryCode === "string" ? countryCode.trim().toUpperCase() : "";
  return /^[A-Z0-9_-]{2,16}$/.test(normalized) ? normalized : "";
}

function normalizeSearchRequestCityKey(cityKey) {
  const normalized =
    typeof cityKey === "string" ? cityKey.trim().toLowerCase() : "";
  return /^[a-z0-9_-]{1,80}$/.test(normalized) ? normalized : "";
}

function normalizeSearchRequestFilters(filters = {}) {
  if (!isPlainObject(filters)) {
    return {};
  }

  const normalized = {};
  const preferredLevel = normalizeSearchRequestLevel(
    filters[SEARCH_REQUEST_FILTER_FIELD.PREFERRED_LEVEL] || filters.level,
  );
  if (preferredLevel) {
    normalized[SEARCH_REQUEST_FILTER_FIELD.PREFERRED_LEVEL] = preferredLevel;
    normalized[SEARCH_REQUEST_FILTER_FIELD.LEVEL_RANK] =
      SEARCH_REQUEST_LEVEL_RANK[preferredLevel];
  } else {
    const levelRank = normalizeSearchRequestRank(
      filters[SEARCH_REQUEST_FILTER_FIELD.LEVEL_RANK],
    );
    if (levelRank !== null) {
      normalized[SEARCH_REQUEST_FILTER_FIELD.LEVEL_RANK] = levelRank;
    }
  }

  const countryCode = normalizeSearchRequestCountryCode(
    filters[SEARCH_REQUEST_FILTER_FIELD.COUNTRY_CODE],
  );
  if (countryCode) {
    normalized[SEARCH_REQUEST_FILTER_FIELD.COUNTRY_CODE] = countryCode;
  }

  const cityKey = normalizeSearchRequestCityKey(
    filters[SEARCH_REQUEST_FILTER_FIELD.CITY_KEY],
  );
  if (countryCode && cityKey) {
    normalized[SEARCH_REQUEST_FILTER_FIELD.CITY_KEY] = cityKey;
  }

  return normalized;
}

function assertSearchRequestHasNoPublicProfileSnapshot(data = {}) {
  const forbiddenField = SEARCH_REQUEST_PUBLIC_PROFILE_FIELDS.find((field) =>
    Object.hasOwn(data, field),
  );
  if (forbiddenField) {
    throw new Error(`searchRequest must not contain ${forbiddenField}`);
  }
}

function normalizeSearchRequestDocumentId(userId) {
  const normalizedUserId = typeof userId === "string" ? userId.trim() : "";
  if (!normalizedUserId ||
      normalizedUserId.includes("/") ||
      normalizedUserId === "." ||
      normalizedUserId === ".." ||
      /^__.*__$/.test(normalizedUserId)) {
    return "";
  }

  return normalizedUserId;
}

function buildSearchRequestPath(userId) {
  const normalizedUserId = normalizeSearchRequestDocumentId(userId);
  if (!normalizedUserId) {
    throw new Error("userId is required");
  }

  return `${SEARCH_REQUEST_COLLECTION}/${normalizedUserId}`;
}

function buildInitialSearchRequestData({
  userId,
  userRef,
  requestId,
  role = "student",
  language,
  languageCode,
  filters = {},
  appState = SEARCH_REQUEST_APP_STATE.FOREGROUND,
  platform = "",
  serverTimestamp,
  expiresAt,
  backgroundExpiresAt = null,
}) {
  const normalizedUserId = normalizeSearchRequestDocumentId(userId);
  const normalizedRequestId = normalizeSearchRequestDocumentId(requestId);
  const rawLanguage = language ?? languageCode;
  const normalizedLanguage =
    typeof rawLanguage === "string" ? rawLanguage.trim().toLowerCase() : "";

  if (!normalizedUserId ||
      !userRef ||
      !normalizedRequestId ||
      !normalizedLanguage) {
    throw new Error("userId, userRef, requestId and language are required");
  }
  if (!serverTimestamp || !expiresAt) {
    throw new Error("serverTimestamp and expiresAt are required");
  }

  const data = {
    [SEARCH_REQUEST_FIELD.REQUEST_ID]: normalizedRequestId,
    [SEARCH_REQUEST_FIELD.USER_ID]: normalizedUserId,
    [SEARCH_REQUEST_FIELD.USER_REF]: userRef,
    [SEARCH_REQUEST_FIELD.ROLE]: role,
    [SEARCH_REQUEST_FIELD.LANGUAGE]: normalizedLanguage,
    [SEARCH_REQUEST_FIELD.FILTERS]: normalizeSearchRequestFilters(filters),
    [SEARCH_REQUEST_FIELD.STATUS]: SEARCH_REQUEST_STATUS.ACTIVE,
    [SEARCH_REQUEST_FIELD.APP_STATE]: normalizeAppState(appState),
    [SEARCH_REQUEST_FIELD.APP_STATE_UPDATED_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.CREATED_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.UPDATED_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.HEARTBEAT_AT]: serverTimestamp,
    [SEARCH_REQUEST_FIELD.EXPIRES_AT]: expiresAt,
    [SEARCH_REQUEST_FIELD.BACKGROUND_EXPIRES_AT]: backgroundExpiresAt,
    [SEARCH_REQUEST_FIELD.CURRENT_SESSION_ID]: null,
    [SEARCH_REQUEST_FIELD.MATCHED_USER_ID]: null,
    [SEARCH_REQUEST_FIELD.MATCHED_ROLE]: null,
    [SEARCH_REQUEST_FIELD.PAIR_ATTEMPT_ID]: null,
    [SEARCH_REQUEST_FIELD.EXCLUDED_CANDIDATE_IDS]: [],
    [SEARCH_REQUEST_FIELD.ATTEMPT_EXCLUDED_CANDIDATE_IDS]: [],
    [SEARCH_REQUEST_FIELD.LOCK_OWNER]: null,
    [SEARCH_REQUEST_FIELD.LOCK_EXPIRES_AT]: null,
    [SEARCH_REQUEST_FIELD.VERSION]: 1,
    [SEARCH_REQUEST_FIELD.STOP_REASON]: null,
    [SEARCH_REQUEST_FIELD.STOPPED_AT]: null,
    [SEARCH_REQUEST_FIELD.LAST_ERROR]: null,
  };

  if (platform) {
    data[SEARCH_REQUEST_FIELD.PLATFORM] = String(platform).trim();
  }

  assertSearchRequestHasNoPublicProfileSnapshot(data);
  return data;
}

function hasRequiredSearchRequestFields(data = {}) {
  return SEARCH_REQUEST_REQUIRED_FIELDS.every((field) =>
    Object.hasOwn(data, field),
  );
}

module.exports = {
  SEARCH_REQUEST_ACTIVE_STATUSES,
  SEARCH_REQUEST_ALLOWED_FILTER_FIELDS,
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_CANONICAL_STATUSES,
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_FIELD,
  SEARCH_REQUEST_FILTER_FIELD,
  SEARCH_REQUEST_LEVEL_RANK,
  SEARCH_REQUEST_PUBLIC_PROFILE_FIELDS,
  SEARCH_REQUEST_REQUIRED_FIELDS,
  SEARCH_REQUEST_SERVER_OWNED_FIELDS,
  SEARCH_REQUEST_STATUS,
  SEARCH_REQUEST_TERMINAL_STATUSES,
  SEARCH_REQUEST_TIMING,
  assertSearchRequestHasNoPublicProfileSnapshot,
  buildInitialSearchRequestData,
  buildSearchRequestPath,
  hasRequiredSearchRequestFields,
  isActiveSearchRequestStatus,
  isTerminalSearchRequestStatus,
  normalizeAppState,
  normalizeSearchRequestCityKey,
  normalizeSearchRequestCountryCode,
  normalizeSearchRequestFilters,
  normalizeSearchRequestLevel,
  normalizeSearchRequestStatus,
};
