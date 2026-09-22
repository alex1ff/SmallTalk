const test = require("node:test");
const assert = require("node:assert/strict");
const {
  SEARCH_REQUEST_ACTIVE_STATUSES,
  SEARCH_REQUEST_ALLOWED_FILTER_FIELDS,
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_CANONICAL_STATUSES,
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_FIELD,
  SEARCH_REQUEST_FILTER_FIELD,
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
  normalizeSearchRequestFilters,
} = require("./search_requests");

test("search request contract defines canonical lifecycle statuses", () => {
  assert.equal(SEARCH_REQUEST_COLLECTION, "searchRequests");
  assert.deepEqual(SEARCH_REQUEST_CANONICAL_STATUSES, [
    "active",
    "matching",
    "matched",
    "stopped",
    "expired",
    "cancelled",
    "error",
  ]);
  assert.equal(SEARCH_REQUEST_STATUS.ACTIVE, "active");
  assert.equal(SEARCH_REQUEST_STATUS.ERROR, "error");
  assert.equal(SEARCH_REQUEST_STATUS.LEGACY_SEARCHING, "searching");
  assert.ok(SEARCH_REQUEST_ACTIVE_STATUSES.includes("active"));
  assert.ok(SEARCH_REQUEST_ACTIVE_STATUSES.includes("matching"));
  assert.ok(SEARCH_REQUEST_ACTIVE_STATUSES.includes("matched"));
  assert.ok(SEARCH_REQUEST_ACTIVE_STATUSES.includes("searching"));
  assert.ok(SEARCH_REQUEST_TERMINAL_STATUSES.includes("stopped"));
  assert.ok(SEARCH_REQUEST_TERMINAL_STATUSES.includes("error"));
  assert.ok(SEARCH_REQUEST_TERMINAL_STATUSES.includes("failed"));
  assert.ok(SEARCH_REQUEST_TERMINAL_STATUSES.includes("completed"));
  assert.equal(isActiveSearchRequestStatus("active"), true);
  assert.equal(isActiveSearchRequestStatus("searching"), true);
  assert.equal(isTerminalSearchRequestStatus("stopped"), true);
  assert.equal(isTerminalSearchRequestStatus("error"), true);
  assert.equal(isTerminalSearchRequestStatus("matched"), false);
});

test("search request timing constants match product timeouts", () => {
  assert.deepEqual(SEARCH_REQUEST_TIMING, {
    HEARTBEAT_INTERVAL_SECONDS: 30,
    HEARTBEAT_STALE_SECONDS: 90,
    MAX_SEARCH_SECONDS: 120,
    BACKGROUND_MAX_SEARCH_SECONDS: 120,
  });
});

test("search request filters are whitelisted and normalized", () => {
  assert.deepEqual(SEARCH_REQUEST_ALLOWED_FILTER_FIELDS, [
    "preferredLevel",
    "levelRank",
    "countryCode",
    "cityKey",
  ]);
  assert.deepEqual(normalizeSearchRequestFilters({
    preferredLevel: " b1 ",
    levelRank: 6,
    countryCode: " ru ",
    cityKey: " Moscow_1 ",
    displayName: "Student A",
    email: "student@example.com",
    unknown: "value",
  }), {
    [SEARCH_REQUEST_FILTER_FIELD.PREFERRED_LEVEL]: "B1",
    [SEARCH_REQUEST_FILTER_FIELD.LEVEL_RANK]: 3,
    [SEARCH_REQUEST_FILTER_FIELD.COUNTRY_CODE]: "RU",
    [SEARCH_REQUEST_FILTER_FIELD.CITY_KEY]: "moscow_1",
  });
  assert.deepEqual(normalizeSearchRequestFilters({
    level: "C2",
    countryCode: "too long country code",
    cityKey: "bad city key",
  }), {
    [SEARCH_REQUEST_FILTER_FIELD.PREFERRED_LEVEL]: "C2",
    [SEARCH_REQUEST_FILTER_FIELD.LEVEL_RANK]: 6,
  });
  assert.deepEqual(normalizeSearchRequestFilters({
    preferredLevel: "Basic",
  }), {
    [SEARCH_REQUEST_FILTER_FIELD.PREFERRED_LEVEL]: "A2",
    [SEARCH_REQUEST_FILTER_FIELD.LEVEL_RANK]: 2,
  });
  assert.deepEqual(normalizeSearchRequestFilters({
    preferredLevel: {name: "Fluent"},
  }), {
    [SEARCH_REQUEST_FILTER_FIELD.PREFERRED_LEVEL]: "C1",
    [SEARCH_REQUEST_FILTER_FIELD.LEVEL_RANK]: 5,
  });
  assert.deepEqual(normalizeSearchRequestFilters({
    cityKey: "new_york",
  }), {});
  assert.deepEqual(normalizeSearchRequestFilters({
    countryCode: "us",
    cityKey: "new_york",
  }), {
    [SEARCH_REQUEST_FILTER_FIELD.COUNTRY_CODE]: "US",
    [SEARCH_REQUEST_FILTER_FIELD.CITY_KEY]: "new_york",
  });
  assert.deepEqual(normalizeSearchRequestFilters(null), {});
});

test("initial search request data has required active queue fields", () => {
  const serverTimestamp = Symbol("serverTimestamp");
  const expiresAt = Symbol("expiresAt");
  const backgroundExpiresAt = Symbol("backgroundExpiresAt");
  const userRef = {path: "users/student-a"};
  const data = buildInitialSearchRequestData({
    userId: " student-a ",
    userRef,
    requestId: " request-a ",
    role: "student",
    language: " EN ",
    filters: {
      preferredLevel: "b1",
      countryCode: "US",
      displayName: "Student A",
    },
    appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
    platform: "ios",
    serverTimestamp,
    expiresAt,
    backgroundExpiresAt,
  });

  assert.equal(data[SEARCH_REQUEST_FIELD.REQUEST_ID], "request-a");
  assert.equal(data[SEARCH_REQUEST_FIELD.USER_ID], "student-a");
  assert.equal(data[SEARCH_REQUEST_FIELD.USER_REF], userRef);
  assert.equal(data[SEARCH_REQUEST_FIELD.ROLE], "student");
  assert.equal(data[SEARCH_REQUEST_FIELD.LANGUAGE], "en");
  assert.equal(data.languageCode, undefined);
  assert.deepEqual(data[SEARCH_REQUEST_FIELD.FILTERS], {
    preferredLevel: "B1",
    levelRank: 3,
    countryCode: "US",
  });
  assert.equal(data[SEARCH_REQUEST_FIELD.STATUS], "active");
  assert.equal(data[SEARCH_REQUEST_FIELD.APP_STATE], "background");
  assert.equal(
    data[SEARCH_REQUEST_FIELD.APP_STATE_UPDATED_AT],
    serverTimestamp,
  );
  assert.equal(data[SEARCH_REQUEST_FIELD.CREATED_AT], serverTimestamp);
  assert.equal(data[SEARCH_REQUEST_FIELD.UPDATED_AT], serverTimestamp);
  assert.equal(data[SEARCH_REQUEST_FIELD.HEARTBEAT_AT], serverTimestamp);
  assert.equal(data[SEARCH_REQUEST_FIELD.EXPIRES_AT], expiresAt);
  assert.equal(
    data[SEARCH_REQUEST_FIELD.BACKGROUND_EXPIRES_AT],
    backgroundExpiresAt,
  );
  assert.equal(data[SEARCH_REQUEST_FIELD.CURRENT_SESSION_ID], null);
  assert.equal(data[SEARCH_REQUEST_FIELD.MATCHED_USER_ID], null);
  assert.equal(data[SEARCH_REQUEST_FIELD.MATCHED_ROLE], null);
  assert.equal(data[SEARCH_REQUEST_FIELD.PAIR_ATTEMPT_ID], null);
  assert.deepEqual(data[SEARCH_REQUEST_FIELD.EXCLUDED_CANDIDATE_IDS], []);
  assert.deepEqual(
    data[SEARCH_REQUEST_FIELD.ATTEMPT_EXCLUDED_CANDIDATE_IDS],
    [],
  );
  assert.equal(data[SEARCH_REQUEST_FIELD.LOCK_OWNER], null);
  assert.equal(data[SEARCH_REQUEST_FIELD.LOCK_EXPIRES_AT], null);
  assert.equal(data[SEARCH_REQUEST_FIELD.VERSION], 1);
  assert.equal(data[SEARCH_REQUEST_FIELD.STOP_REASON], null);
  assert.equal(data[SEARCH_REQUEST_FIELD.STOPPED_AT], null);
  assert.equal(data[SEARCH_REQUEST_FIELD.LAST_ERROR], null);
  assert.equal(hasRequiredSearchRequestFields(data), true);
});

test("search request contract keeps server-owned and PII fields explicit", () => {
  assert.ok(SEARCH_REQUEST_REQUIRED_FIELDS.includes("requestId"));
  assert.ok(SEARCH_REQUEST_REQUIRED_FIELDS.includes("language"));
  assert.ok(SEARCH_REQUEST_REQUIRED_FIELDS.includes("heartbeatAt"));
  assert.ok(SEARCH_REQUEST_REQUIRED_FIELDS.includes("appStateUpdatedAt"));
  assert.ok(SEARCH_REQUEST_REQUIRED_FIELDS.includes("currentSessionId"));
  assert.ok(SEARCH_REQUEST_REQUIRED_FIELDS.includes("matchedUserId"));
  assert.ok(SEARCH_REQUEST_REQUIRED_FIELDS.includes("pairAttemptId"));
  assert.ok(SEARCH_REQUEST_REQUIRED_FIELDS.includes("excludedCandidateIds"));
  assert.ok(SEARCH_REQUEST_REQUIRED_FIELDS.includes("lockOwner"));
  assert.ok(SEARCH_REQUEST_REQUIRED_FIELDS.includes("version"));
  assert.ok(SEARCH_REQUEST_REQUIRED_FIELDS.includes("stopReason"));
  assert.ok(SEARCH_REQUEST_REQUIRED_FIELDS.includes("stoppedAt"));
  assert.ok(SEARCH_REQUEST_REQUIRED_FIELDS.includes("lastError"));
  assert.ok(SEARCH_REQUEST_SERVER_OWNED_FIELDS.includes("status"));
  assert.ok(SEARCH_REQUEST_SERVER_OWNED_FIELDS.includes("lockOwner"));
  assert.ok(SEARCH_REQUEST_SERVER_OWNED_FIELDS.includes("matchedUserId"));
  assert.ok(SEARCH_REQUEST_SERVER_OWNED_FIELDS.includes("lastError"));
  assert.ok(SEARCH_REQUEST_PUBLIC_PROFILE_FIELDS.includes("displayName"));
  assert.throws(
    () => assertSearchRequestHasNoPublicProfileSnapshot({
      userId: "student-a",
      displayName: "Student A",
    }),
    /displayName/,
  );
});

test("search request helpers reject invalid identity input", () => {
  assert.equal(buildSearchRequestPath("student-a"), "searchRequests/student-a");
  assert.throws(() => buildSearchRequestPath("users/student-a"), /userId/);
  assert.throws(() => buildSearchRequestPath("."), /userId/);
  assert.throws(() => buildSearchRequestPath(".."), /userId/);
  assert.throws(() => buildSearchRequestPath("__bad__"), /userId/);
  assert.throws(
    () => buildInitialSearchRequestData({
      userId: "student-a",
      userRef: {path: "users/student-a"},
      requestId: "request-a",
      language: "",
      serverTimestamp: Symbol("serverTimestamp"),
      expiresAt: Symbol("expiresAt"),
    }),
    /required/,
  );
  assert.equal(normalizeAppState("foreground"), "foreground");
  assert.equal(normalizeAppState("bad"), "unknown");
});
