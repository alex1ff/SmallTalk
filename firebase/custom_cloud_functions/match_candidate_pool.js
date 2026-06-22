const { evaluateTutorAvailabilityWindow } = require("./availability");
const {
  buildStudentCallAccessDecision,
  hasActiveCallState,
} = require("./call_access");
const {
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_FIELD,
  SEARCH_REQUEST_FILTER_FIELD,
  SEARCH_REQUEST_LEVEL_RANK,
  SEARCH_REQUEST_STATUS,
  SEARCH_REQUEST_TIMING,
  normalizeSearchRequestCityKey,
  normalizeSearchRequestCountryCode,
  normalizeSearchRequestLevel,
} = require("./search_requests");
const {
  buildMatchProfile,
  extractBlockedIds,
  normalizeRole,
  readLanguageCode,
  readMatchLevelValue,
  supportsConversationLanguage,
} = require("./video_sessions_shared");
const {
  getReadOnlyUserVoipTokenState,
} = require("./voip_tokens");
const {
  usageDocRef,
} = require("./subscription_usage_shared");
const {
  getUtcDayKey,
  loadSameDayRepeatCandidateIds,
} = require("./match_repeat_prevention");

const USER_COLLECTION = "users";
const DEFAULT_STUDENT_QUERY_LIMIT = 50;
const DEFAULT_TEACHER_QUERY_LIMIT = 50;
const DEFAULT_SCAN_PAGE_SIZE = 50;
const DEFAULT_SCAN_MAX_PAGES = 5;
const MATCH_CANDIDATE_SOURCE = Object.freeze({
  ACTIVE_STUDENT_QUEUE: "active_student_queue",
  TEACHER_AVAILABILITY: "teacher_availability",
});
const INTERNAL_REPEAT_EMAIL = Symbol("repeatPreventionEmail");

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function timestampToMillis(value) {
  if (!value) {
    return null;
  }
  if (typeof value.toMillis === "function") {
    const millis = Number(value.toMillis());
    return Number.isFinite(millis) ? millis : null;
  }
  if (typeof value.toDate === "function") {
    const millis = value.toDate().getTime();
    return Number.isFinite(millis) ? millis : null;
  }
  if (value instanceof Date) {
    const millis = value.getTime();
    return Number.isFinite(millis) ? millis : null;
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }
  if (typeof value === "string") {
    const millis = Date.parse(value);
    return Number.isFinite(millis) ? millis : null;
  }
  return null;
}

function resolveNowMillis(now = new Date(), nowMillis = null) {
  const explicitMillis = Number(nowMillis);
  if (Number.isFinite(explicitMillis)) {
    return explicitMillis;
  }

  return timestampToMillis(now) ?? Date.now();
}

function normalizePositiveInteger(value, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) {
    return fallback;
  }
  return Math.floor(number);
}

function normalizeLevelRank(rank) {
  const normalizedRank = typeof rank === "number" ?
    rank :
    Number.parseInt(String(rank || "").trim(), 10);
  return Number.isInteger(normalizedRank) &&
    normalizedRank >= 1 &&
    normalizedRank <= 6 ?
    normalizedRank :
    null;
}

function readLevelRankFromLevel(value) {
  const level = normalizeSearchRequestLevel(value);
  return level ? SEARCH_REQUEST_LEVEL_RANK[level] : null;
}

function readNestedObject(value) {
  return value && typeof value === "object" && !Array.isArray(value) ?
    value :
    {};
}

function readCandidateLevelValue(userData = {}) {
  const matchProfile = readNestedObject(userData.matchProfile);
  return readMatchLevelValue(userData) ||
    userData.level ||
    matchProfile.level ||
    "";
}

function readCityKeyValue(value) {
  if (!value) {
    return "";
  }
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "object") {
    return value.key || value.cityKey || value.value || "";
  }
  return "";
}

function readLocationCountryCode(value) {
  if (!value) {
    return "";
  }
  if (typeof value === "string") {
    return normalizeSearchRequestCountryCode(value);
  }
  if (typeof value === "object") {
    return normalizeSearchRequestCountryCode(
      value.countryCode ||
        value.code ||
        value.value ||
        readLocationCountryCode(value.country),
    );
  }
  return "";
}

function readCandidateLocation(userData = {}) {
  const matchProfile = readNestedObject(userData.matchProfile);
  const profileCity = readNestedObject(userData.profileCity);
  const matchProfileCity = readNestedObject(matchProfile.city);
  const countryCode = readLocationCountryCode(userData.Country_NS) ||
    readLocationCountryCode(matchProfile.country);
  const profileCityKey = normalizeSearchRequestCityKey(
    readCityKeyValue(profileCity),
  );
  const matchProfileCityKey = normalizeSearchRequestCityKey(
    readCityKeyValue(matchProfileCity),
  );
  const cityKey = profileCityKey || matchProfileCityKey;
  const cityCountryCode = profileCityKey ?
    (readLocationCountryCode(profileCity) || countryCode) :
    (matchProfileCityKey ?
      (readLocationCountryCode(matchProfileCity) || countryCode) :
      "");

  return {
    countryCode,
    cityKey,
    cityCountryCode,
  };
}

function readPreferredLevelRank(filters = {}) {
  if (!filters || typeof filters !== "object" || Array.isArray(filters)) {
    return null;
  }
  const preferredLevelRank = readLevelRankFromLevel(
    filters[SEARCH_REQUEST_FILTER_FIELD.PREFERRED_LEVEL] ||
      filters.level ||
      filters.preferredLevel,
  );
  if (preferredLevelRank !== null) {
    return preferredLevelRank;
  }

  return normalizeLevelRank(
    filters[SEARCH_REQUEST_FILTER_FIELD.LEVEL_RANK] ||
      filters.levelRank,
  );
}

function readPreferredLocation(filters = {}) {
  if (!filters || typeof filters !== "object" || Array.isArray(filters)) {
    return {
      countryCode: "",
      cityKey: "",
      invalidCityFilter: false,
    };
  }

  const countryCode = readLocationCountryCode(
    filters[SEARCH_REQUEST_FILTER_FIELD.COUNTRY_CODE] ||
      filters.countryCode ||
      filters.country,
  );
  const rawCityKey = normalizeSearchRequestCityKey(
    readCityKeyValue(
      filters[SEARCH_REQUEST_FILTER_FIELD.CITY_KEY] ||
        filters.cityKey ||
        filters.city,
    ),
  );

  return {
    countryCode,
    cityKey: countryCode ? rawCityKey : "",
    invalidCityFilter: Boolean(rawCityKey && !countryCode),
  };
}

function buildLevelMatch({
  candidateLevelRank = null,
  preferredLevelRank = null,
}) {
  if (preferredLevelRank === null) {
    return {
      valid: true,
      applied: false,
      distance: null,
      tier: null,
    };
  }
  if (candidateLevelRank === null) {
    return {
      valid: false,
      applied: true,
      distance: null,
      tier: "missing",
    };
  }

  const distance = Math.abs(candidateLevelRank - preferredLevelRank);
  if (distance > 1) {
    return {
      valid: false,
      applied: true,
      distance,
      tier: "out_of_range",
    };
  }

  return {
    valid: true,
    applied: true,
    distance,
    tier: distance === 0 ? "exact" : "adjacent",
  };
}

function hasLocationFilter(location = {}) {
  return Boolean(
    location.invalidCityFilter ||
      location.countryCode ||
      location.cityKey,
  );
}

function buildLocationMatch({
  candidateLocation = {},
  preferredLocation = {},
}) {
  if (!hasLocationFilter(preferredLocation)) {
    return {
      valid: true,
      applied: false,
      distance: null,
      tier: null,
    };
  }
  if (preferredLocation.invalidCityFilter) {
    return {
      valid: false,
      applied: true,
      distance: null,
      tier: "invalid_city_filter",
    };
  }

  if (preferredLocation.cityKey) {
    if (
      !candidateLocation.cityKey ||
      !candidateLocation.cityCountryCode
    ) {
      return {
        valid: false,
        applied: true,
        distance: null,
        tier: "missing_city",
      };
    }
    const cityMatches =
      candidateLocation.cityKey === preferredLocation.cityKey &&
      candidateLocation.cityCountryCode === preferredLocation.countryCode;
    return cityMatches ?
      {
        valid: true,
        applied: true,
        distance: 0,
        tier: "city_exact",
      } :
      {
        valid: false,
        applied: true,
        distance: null,
        tier: "city_mismatch",
      };
  }

  if (!candidateLocation.countryCode) {
    return {
      valid: false,
      applied: true,
      distance: null,
      tier: "missing_country",
    };
  }
  return candidateLocation.countryCode === preferredLocation.countryCode ?
    {
      valid: true,
      applied: true,
      distance: 1,
      tier: "country_exact",
    } :
    {
      valid: false,
      applied: true,
      distance: null,
      tier: "country_mismatch",
    };
}

function readDocData(doc) {
  if (!doc || doc.exists === false || typeof doc.data !== "function") {
    return null;
  }
  return doc.data() || {};
}

function readDocId(doc) {
  return normalizeString(doc?.id);
}

function readReferenceId(value) {
  return value && typeof value.id === "string" ? value.id.trim() : "";
}

function normalizeBlockedUserId(value) {
  const normalized = normalizeString(value);
  if (!normalized.includes("/")) {
    return normalized;
  }
  return normalized.split("/").filter(Boolean).pop() || "";
}

function readBlockedUserIds(userData = {}) {
  return extractBlockedIds(userData.blockedUsers)
    .map(normalizeBlockedUserId)
    .filter(Boolean);
}

function readCandidateIdList(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.map((entry) => {
    if (typeof entry === "string") {
      return normalizeBlockedUserId(entry);
    }
    if (entry && typeof entry.id === "string") {
      return normalizeBlockedUserId(entry.id);
    }
    if (entry && typeof entry.path === "string") {
      return normalizeBlockedUserId(entry.path);
    }
    return "";
  }).filter(Boolean);
}

function readSearchRequestExcludedCandidateIds(requestData = {}) {
  return Array.from(new Set([
    ...readCandidateIdList(
      requestData[SEARCH_REQUEST_FIELD.EXCLUDED_CANDIDATE_IDS],
    ),
    ...readCandidateIdList(
      requestData[SEARCH_REQUEST_FIELD.ATTEMPT_EXCLUDED_CANDIDATE_IDS],
    ),
  ]));
}

function buildBlockMatch({
  requesterId = "",
  requesterBlockedIds = [],
  candidateId = "",
  candidateData = {},
}) {
  const normalizedRequesterId = normalizeBlockedUserId(requesterId);
  const normalizedCandidateId = normalizeBlockedUserId(candidateId);
  const requesterBlockedSet = new Set(
    requesterBlockedIds.map(normalizeBlockedUserId).filter(Boolean),
  );
  if (normalizedCandidateId && requesterBlockedSet.has(normalizedCandidateId)) {
    return {valid: false, reason: "blocked_by_requester"};
  }

  if (!normalizedRequesterId) {
    return {valid: true, reason: "not_blocked"};
  }
  const candidateBlockedSet = new Set(readBlockedUserIds(candidateData));
  if (candidateBlockedSet.has(normalizedRequesterId)) {
    return {valid: false, reason: "blocked_by_candidate"};
  }

  return {valid: true, reason: "not_blocked"};
}

function buildSearchLifecycleRepeatMatch({
  requesterId = "",
  requesterExcludedCandidateIds = [],
  candidateId = "",
  candidateRequestData = null,
}) {
  const normalizedRequesterId = normalizeBlockedUserId(requesterId);
  const normalizedCandidateId = normalizeBlockedUserId(candidateId);
  const requesterExcludedSet = new Set(
    readCandidateIdList(requesterExcludedCandidateIds),
  );

  if (normalizedCandidateId && requesterExcludedSet.has(normalizedCandidateId)) {
    return {valid: false, reason: "excluded_by_requester"};
  }

  if (!normalizedRequesterId || !candidateRequestData) {
    return {valid: true, reason: "not_excluded"};
  }

  const candidateExcludedSet = new Set(
    readSearchRequestExcludedCandidateIds(candidateRequestData),
  );
  if (candidateExcludedSet.has(normalizedRequesterId)) {
    return {valid: false, reason: "excluded_by_candidate"};
  }

  return {valid: true, reason: "not_excluded"};
}

function readUserEmail(userData = {}) {
  return normalizeString(
    userData.email ||
      userData.authEmail ||
      userData.privateEmail ||
      userData.emailAddress ||
      "",
  ).toLowerCase();
}

function withInternalRepeatEmail(candidate = {}, userData = {}) {
  const email = readUserEmail(userData);
  if (!email) {
    return candidate;
  }

  return {
    ...candidate,
    [INTERNAL_REPEAT_EMAIL]: email,
  };
}

function readInternalRepeatEmail(candidate = {}) {
  return normalizeString(candidate[INTERNAL_REPEAT_EMAIL]).toLowerCase();
}

function stripInternalCandidateFields(candidate = {}) {
  const publicCandidate = {...candidate};
  delete publicCandidate[INTERNAL_REPEAT_EMAIL];
  return publicCandidate;
}

function buildCandidateEmailMap(candidates = []) {
  const emailsById = new Map();
  candidates.forEach((candidate) => {
    const userId = normalizeBlockedUserId(candidate.userId);
    const email = readInternalRepeatEmail(candidate);
    if (userId && email) {
      emailsById.set(userId, email);
    }
  });
  return emailsById;
}

async function filterSameDayRepeatCandidateObjects({
  db,
  requesterId = "",
  requesterEmail = "",
  candidates = [],
  dayKey = getUtcDayKey(),
}) {
  const normalizedRequesterId = normalizeBlockedUserId(requesterId);
  if (!normalizedRequesterId || candidates.length === 0) {
    return candidates;
  }

  const repeatContext = await loadSameDayRepeatCandidateIds(
    db,
    normalizedRequesterId,
    candidates.map((candidate) => normalizeBlockedUserId(candidate.userId)),
    {
      dayKey,
      requesterEmail,
      userEmailsById: buildCandidateEmailMap(candidates),
    },
  );
  const excludedCandidateIds = repeatContext.excludedCandidateIds || new Set();
  return candidates.filter((candidate) =>
    !excludedCandidateIds.has(normalizeBlockedUserId(candidate.userId)),
  );
}

function readRequestUserId(requestDoc, requestData = {}) {
  return normalizeString(requestData[SEARCH_REQUEST_FIELD.USER_ID]) ||
    readReferenceId(requestData[SEARCH_REQUEST_FIELD.USER_REF]) ||
    readDocId(requestDoc);
}

function searchRequestOwnerMatchesDoc(requestDoc, requestData = {}) {
  const explicitOwnerIds = [
    requestData[SEARCH_REQUEST_FIELD.USER_ID],
    readReferenceId(requestData[SEARCH_REQUEST_FIELD.USER_REF]),
  ].map(normalizeString).filter(Boolean);
  if (explicitOwnerIds.length === 0) {
    return false;
  }

  const requestUserId = explicitOwnerIds[0];
  const ownerIds = [...explicitOwnerIds, readDocId(requestDoc)]
    .map(normalizeString)
    .filter(Boolean);

  return Boolean(requestUserId) &&
    ownerIds.every((ownerId) => ownerId === requestUserId);
}

function hasOpenMatchState(requestData = {}) {
  return Boolean(
    requestData[SEARCH_REQUEST_FIELD.ACTIVE_SESSION_ID] ||
      requestData[SEARCH_REQUEST_FIELD.CURRENT_SESSION_ID] ||
      requestData[SEARCH_REQUEST_FIELD.MATCHED_SESSION_ID] ||
      requestData[SEARCH_REQUEST_FIELD.MATCHED_USER_ID] ||
      requestData[SEARCH_REQUEST_FIELD.MATCHED_RESPONDER_ID] ||
      requestData[SEARCH_REQUEST_FIELD.MATCHED_ROLE] ||
      requestData[SEARCH_REQUEST_FIELD.PAIR_ATTEMPT_ID] ||
      requestData[SEARCH_REQUEST_FIELD.LOCK_OWNER] ||
      requestData[SEARCH_REQUEST_FIELD.LOCK_EXPIRES_AT],
  );
}

function validateActiveStudentSearchRequest(
  requestData = {},
  nowMillis = Date.now(),
) {
  const safeNowMillis = Number.isFinite(Number(nowMillis)) ?
    Number(nowMillis) :
    Date.now();
  if (
    normalizeString(requestData[SEARCH_REQUEST_FIELD.STATUS]) !==
    SEARCH_REQUEST_STATUS.ACTIVE
  ) {
    return {valid: false, reason: "inactive_status"};
  }
  if (normalizeRole(requestData[SEARCH_REQUEST_FIELD.ROLE]) !== "student") {
    return {valid: false, reason: "not_student"};
  }
  if (!readLanguageCode(requestData[SEARCH_REQUEST_FIELD.LANGUAGE])) {
    return {valid: false, reason: "missing_language"};
  }
  if (hasOpenMatchState(requestData)) {
    return {valid: false, reason: "open_match_state"};
  }

  const heartbeatAtMillis = timestampToMillis(
    requestData[SEARCH_REQUEST_FIELD.HEARTBEAT_AT],
  );
  if (heartbeatAtMillis === null) {
    return {valid: false, reason: "missing_heartbeat"};
  }
  const staleCutoffMillis =
    safeNowMillis -
    SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS * 1000;
  if (heartbeatAtMillis < staleCutoffMillis) {
    return {valid: false, reason: "stale_heartbeat"};
  }

  const expiresAtMillis = timestampToMillis(
    requestData[SEARCH_REQUEST_FIELD.EXPIRES_AT],
  );
  if (expiresAtMillis === null || expiresAtMillis <= safeNowMillis) {
    return {valid: false, reason: "expired_request"};
  }

  const appState = normalizeString(
    requestData[SEARCH_REQUEST_FIELD.APP_STATE],
  );
  const backgroundExpiresAtMillis = timestampToMillis(
    requestData[SEARCH_REQUEST_FIELD.BACKGROUND_EXPIRES_AT],
  );
  if (
    appState === "background" &&
    (backgroundExpiresAtMillis === null ||
      backgroundExpiresAtMillis <= safeNowMillis)
  ) {
    return {valid: false, reason: "background_expired"};
  }

  return {valid: true, reason: "active"};
}

function isActiveStudentSearchRequest(requestData = {}, nowMillis = Date.now()) {
  return validateActiveStudentSearchRequest(requestData, nowMillis).valid;
}

function isAvailableAfterInFuture(userData = {}, now = new Date()) {
  const availableAfter = userData.availableAfter;
  if (!availableAfter || typeof availableAfter.toDate !== "function") {
    return false;
  }

  return availableAfter.toDate() > now;
}

function readTeacherJoinedPoolMillis(userData = {}, nowMillis = Date.now()) {
  return timestampToMillis(userData.availableSince) ??
    timestampToMillis(userData.availabilityUpdatedAt) ??
    timestampToMillis(userData.updated_time) ??
    timestampToMillis(userData.created_time) ??
    nowMillis;
}

function buildCandidateMatchQuality({
  userData = {},
  preferredLevelRank = null,
  preferredLocation = {},
  requesterLevelRank = null,
  requesterLocation = {},
  candidateFilters = {},
}) {
  const candidateLevel = normalizeSearchRequestLevel(
    readCandidateLevelValue(userData),
  );
  const candidateLevelRank = candidateLevel ?
    SEARCH_REQUEST_LEVEL_RANK[candidateLevel] :
    null;
  const levelMatch = buildLevelMatch({
    candidateLevelRank,
    preferredLevelRank,
  });
  if (!levelMatch.valid) {
    return {valid: false, reason: "level_mismatch"};
  }

  const candidateLocation = readCandidateLocation(userData);
  const locationMatch = buildLocationMatch({
    candidateLocation,
    preferredLocation,
  });
  if (!locationMatch.valid) {
    return {valid: false, reason: "location_mismatch"};
  }

  const candidatePreferredLevelRank = requesterLevelRank === null ?
    null :
    readPreferredLevelRank(candidateFilters);
  const requesterLevelMatch = buildLevelMatch({
    candidateLevelRank: requesterLevelRank,
    preferredLevelRank: candidatePreferredLevelRank,
  });
  if (!requesterLevelMatch.valid) {
    return {valid: false, reason: "requester_level_mismatch"};
  }

  const candidatePreferredLocation = requesterLocation === null ?
    {} :
    readPreferredLocation(candidateFilters);
  const requesterLocationMatch = buildLocationMatch({
    candidateLocation: requesterLocation || {},
    preferredLocation: candidatePreferredLocation,
  });
  if (!requesterLocationMatch.valid) {
    return {valid: false, reason: "requester_location_mismatch"};
  }

  return {
    valid: true,
    matchQuality: {
      levelApplied: levelMatch.applied,
      levelDistance: levelMatch.distance,
      levelTier: levelMatch.tier,
      candidateLevel,
      candidateLevelRank,
      locationApplied: locationMatch.applied,
      locationDistance: locationMatch.distance,
      locationTier: locationMatch.tier,
      candidateCountryCode: candidateLocation.countryCode || null,
      candidateCityKey: candidateLocation.cityKey || null,
      candidateCityCountryCode: candidateLocation.cityCountryCode || null,
      requesterLevelApplied: requesterLevelMatch.applied,
      requesterLevelDistance: requesterLevelMatch.distance,
      requesterLevelTier: requesterLevelMatch.tier,
      requesterLocationApplied: requesterLocationMatch.applied,
      requesterLocationDistance: requesterLocationMatch.distance,
      requesterLocationTier: requesterLocationMatch.tier,
    },
  };
}

function buildStudentQueueCandidateFromDocs({
  requestDoc,
  userDoc,
  language = "",
  nowMillis = Date.now(),
  preferredLevelRank = null,
  preferredLocation = {},
  requesterLevelRank = null,
  requesterLocation = null,
  requesterId = "",
  requesterBlockedIds = [],
  requesterExcludedCandidateIds = [],
  usageData = null,
}) {
  const requestData = readDocData(requestDoc);
  const userData = readDocData(userDoc);
  if (!requestData || !userData) {
    return null;
  }
  const requestValidation = validateActiveStudentSearchRequest(
    requestData,
    nowMillis,
  );
  if (!requestValidation.valid) {
    return null;
  }

  if (!searchRequestOwnerMatchesDoc(requestDoc, requestData)) {
    return null;
  }
  const requestUserId = readRequestUserId(requestDoc, requestData);
  const userDocId = readDocId(userDoc);
  if (userDocId && userDocId !== requestUserId) {
    return null;
  }
  const userRole = normalizeRole(userData.role);
  if (userRole !== "student") {
    return null;
  }
  const accessDecision = buildStudentCallAccessDecision({
    userRole,
    userData,
    usageData,
    nowMillis,
  });
  if (!accessDecision.allowed) {
    return null;
  }
  const repeatMatch = buildSearchLifecycleRepeatMatch({
    requesterId,
    requesterExcludedCandidateIds,
    candidateId: requestUserId,
    candidateRequestData: requestData,
  });
  if (!repeatMatch.valid) {
    return null;
  }

  const blockMatch = buildBlockMatch({
    requesterId,
    requesterBlockedIds,
    candidateId: requestUserId,
    candidateData: userData,
  });
  if (!blockMatch.valid) {
    return null;
  }

  const requestLanguage = readLanguageCode(
    requestData[SEARCH_REQUEST_FIELD.LANGUAGE],
  );
  const normalizedLanguage = readLanguageCode(language);
  if (!normalizedLanguage || requestLanguage !== normalizedLanguage) {
    return null;
  }
  if (!supportsConversationLanguage(userData, normalizedLanguage)) {
    return null;
  }

  const filters = requestData[SEARCH_REQUEST_FIELD.FILTERS] || {};
  const matchQuality = buildCandidateMatchQuality({
    userData,
    preferredLevelRank,
    preferredLocation,
    requesterLevelRank,
    requesterLocation,
    candidateFilters: filters,
  });
  if (!matchQuality.valid) {
    return null;
  }

  const createdAtMillis = timestampToMillis(
    requestData[SEARCH_REQUEST_FIELD.CREATED_AT],
  );
  const heartbeatAtMillis = timestampToMillis(
    requestData[SEARCH_REQUEST_FIELD.HEARTBEAT_AT],
  );

  return withInternalRepeatEmail({
    userId: requestUserId,
    role: "student",
    source: MATCH_CANDIDATE_SOURCE.ACTIVE_STUDENT_QUEUE,
    language: normalizedLanguage,
    searchRequestId:
      normalizeString(requestData[SEARCH_REQUEST_FIELD.REQUEST_ID]) ||
      readDocId(requestDoc),
    searchRequestDocId: readDocId(requestDoc),
    filters,
    profile: buildMatchProfile(requestUserId, userData, normalizedLanguage),
    matchQuality: matchQuality.matchQuality,
    availability: {
      isAvailable: true,
      reason: "active_search_request",
      searchRequestValidationReason: requestValidation.reason,
    },
    createdAtMillis,
    heartbeatAtMillis,
    expiresAtMillis: timestampToMillis(
      requestData[SEARCH_REQUEST_FIELD.EXPIRES_AT],
    ),
    joinedPoolAtMillis: createdAtMillis ?? heartbeatAtMillis ?? nowMillis,
  }, userData);
}

function buildTeacherAvailabilityCandidateFromDoc({
  userDoc,
  language = "",
  now = new Date(),
  nowMillis = null,
  preferredLevelRank = null,
  preferredLocation = {},
  requesterId = "",
  requesterBlockedIds = [],
  requesterExcludedCandidateIds = [],
}) {
  const effectiveNowMillis = resolveNowMillis(now, nowMillis);
  const userData = readDocData(userDoc);
  const userId = readDocId(userDoc);
  if (!userData || !userId) {
    return null;
  }
  if (normalizeRole(userData.role) !== "native_speaker") {
    return null;
  }
  if (hasActiveCallState(userData)) {
    return null;
  }
  const repeatMatch = buildSearchLifecycleRepeatMatch({
    requesterId,
    requesterExcludedCandidateIds,
    candidateId: userId,
  });
  if (!repeatMatch.valid) {
    return null;
  }
  const blockMatch = buildBlockMatch({
    requesterId,
    requesterBlockedIds,
    candidateId: userId,
    candidateData: userData,
  });
  if (!blockMatch.valid) {
    return null;
  }

  const normalizedLanguage = readLanguageCode(language);
  if (!normalizedLanguage) {
    return null;
  }
  if (!supportsConversationLanguage(userData, normalizedLanguage)) {
    return null;
  }

  const profile = buildMatchProfile(userId, userData, normalizedLanguage);
  const matchQuality = buildCandidateMatchQuality({
    userData,
    preferredLevelRank,
    preferredLocation,
  });
  if (!matchQuality.valid) {
    return null;
  }
  if (!profile.approvedTeacher) {
    return null;
  }
  if (isAvailableAfterInFuture(userData, now)) {
    return null;
  }

  const availabilityCheck = evaluateTutorAvailabilityWindow(userData, now);
  if (!availabilityCheck.isAvailable) {
    return null;
  }

  const candidateLanguage = normalizedLanguage ||
    readLanguageCode(profile.activeLanguage);
  if (!candidateLanguage) {
    return null;
  }

  return withInternalRepeatEmail({
    userId,
    role: "native_speaker",
    source: MATCH_CANDIDATE_SOURCE.TEACHER_AVAILABILITY,
    language: candidateLanguage,
    searchRequestId: null,
    searchRequestDocId: null,
    filters: {},
    profile,
    matchQuality: matchQuality.matchQuality,
    availability: {
      isAvailable: true,
      reason: availabilityCheck.reason,
      localTime: availabilityCheck.localTime || null,
      timezoneOffsetMinutes:
        availabilityCheck.timezoneOffsetMinutes ?? null,
    },
    createdAtMillis: timestampToMillis(userData.created_time),
    heartbeatAtMillis: null,
    expiresAtMillis: null,
    joinedPoolAtMillis: readTeacherJoinedPoolMillis(
      userData,
      effectiveNowMillis,
    ),
  }, userData);
}

function buildCandidateTokenState(tokenState = {}) {
  const hasFcmToken = tokenState.hasFcmToken === true;
  const hasVoipPushToken = tokenState.hasVoipPushToken === true;
  return {
    hasFcmToken,
    hasVoipPushToken,
    source: normalizeString(tokenState.source) || "none",
  };
}

function compareOptionalDistance(leftValue, rightValue) {
  const leftHasDistance =
    typeof leftValue === "number" &&
    Number.isFinite(leftValue);
  const rightHasDistance =
    typeof rightValue === "number" &&
    Number.isFinite(rightValue);

  if (leftHasDistance && rightHasDistance && leftValue !== rightValue) {
    return leftValue - rightValue;
  }

  if (leftHasDistance !== rightHasDistance) {
    return leftHasDistance ? -1 : 1;
  }

  return 0;
}

function compareNeutralCandidateOrder(left, right) {
  const levelDistanceOrder = compareOptionalDistance(
    left.matchQuality?.levelDistance,
    right.matchQuality?.levelDistance,
  );
  if (levelDistanceOrder !== 0) {
    return levelDistanceOrder;
  }

  const requesterLevelDistanceOrder = compareOptionalDistance(
    left.matchQuality?.requesterLevelDistance,
    right.matchQuality?.requesterLevelDistance,
  );
  if (requesterLevelDistanceOrder !== 0) {
    return requesterLevelDistanceOrder;
  }

  const locationDistanceOrder = compareOptionalDistance(
    left.matchQuality?.locationDistance,
    right.matchQuality?.locationDistance,
  );
  if (locationDistanceOrder !== 0) {
    return locationDistanceOrder;
  }

  const requesterLocationDistanceOrder = compareOptionalDistance(
    left.matchQuality?.requesterLocationDistance,
    right.matchQuality?.requesterLocationDistance,
  );
  if (requesterLocationDistanceOrder !== 0) {
    return requesterLocationDistanceOrder;
  }

  const leftJoinedAt = Number.isFinite(Number(left.joinedPoolAtMillis)) ?
    Number(left.joinedPoolAtMillis) :
    Number.MAX_SAFE_INTEGER;
  const rightJoinedAt = Number.isFinite(Number(right.joinedPoolAtMillis)) ?
    Number(right.joinedPoolAtMillis) :
    Number.MAX_SAFE_INTEGER;
  if (leftJoinedAt !== rightJoinedAt) {
    return leftJoinedAt - rightJoinedAt;
  }

  return String(left.userId).localeCompare(String(right.userId));
}

function limitQualityRankedCandidates({
  candidates = [],
  targetCount = 0,
  qualityRankingEnabled = false,
}) {
  if (!qualityRankingEnabled) {
    return candidates;
  }
  return [...candidates]
    .sort(compareNeutralCandidateOrder)
    .slice(0, targetCount);
}

function mergeCandidatePools({
  studentCandidates = [],
  teacherCandidates = [],
  requesterId = "",
}) {
  const normalizedRequesterId = normalizeBlockedUserId(requesterId);
  const candidatesById = new Map();

  [...studentCandidates, ...teacherCandidates]
    .filter(Boolean)
    .forEach((candidate) => {
      const userId = normalizeBlockedUserId(candidate.userId);
      if (!userId || userId === normalizedRequesterId) {
        return;
      }
      if (!candidatesById.has(userId)) {
        candidatesById.set(userId, {...candidate, userId});
      }
    });

  return Array.from(candidatesById.values())
    .sort(compareNeutralCandidateOrder)
    .map(stripInternalCandidateFields);
}

function buildActiveStudentSearchRequestsQuery(db, {
  language = "",
  limit = 0,
} = {}) {
  let query = db
    .collection(SEARCH_REQUEST_COLLECTION)
    .where(SEARCH_REQUEST_FIELD.STATUS, "==", SEARCH_REQUEST_STATUS.ACTIVE);
  const normalizedLanguage = readLanguageCode(language);
  if (normalizedLanguage) {
    query = query.where(SEARCH_REQUEST_FIELD.LANGUAGE, "==", normalizedLanguage);
  }
  query = query.orderBy(SEARCH_REQUEST_FIELD.CREATED_AT, "asc");
  if (limit) {
    query = query.limit(limit);
  }
  return query;
}

function buildAvailableTeachersQuery(db, {
  language = "",
  limit = 0,
} = {}) {
  let query = db
    .collection(USER_COLLECTION)
    .where("role", "==", "native_speaker");
  const normalizedLanguage = readLanguageCode(language);
  if (normalizedLanguage) {
    query = query.where("language_instruction_NS.code", "==", normalizedLanguage);
  }
  if (limit) {
    query = query.limit(limit);
  }
  return query;
}

async function readQueryPage(baseQuery, {
  lastDoc = null,
  pageSize = DEFAULT_SCAN_PAGE_SIZE,
}) {
  let pageQuery = baseQuery;
  if (lastDoc) {
    if (typeof pageQuery.startAfter !== "function") {
      return [];
    }
    pageQuery = pageQuery.startAfter(lastDoc);
  }

  const snapshot = await pageQuery
    .limit(normalizePositiveInteger(pageSize, DEFAULT_SCAN_PAGE_SIZE))
    .get();
  return snapshot.docs || [];
}

async function readUserDocsById(db, userIds = []) {
  const uniqueUserIds = Array.from(new Set(userIds.filter(Boolean)));
  const userDocs = await Promise.all(
    uniqueUserIds.map((userId) =>
      db.collection(USER_COLLECTION).doc(userId).get(),
    ),
  );
  return new Map(userDocs.map((doc) => [readDocId(doc), doc]));
}

async function readUsageDataByUserId(db, userIds = []) {
  const uniqueUserIds = Array.from(new Set(userIds.filter(Boolean)));
  const usageDocs = await Promise.all(
    uniqueUserIds.map(async (userId) => {
      const usageDoc = await usageDocRef(db, userId).get();
      return [
        userId,
        usageDoc && usageDoc.exists ? usageDoc.data() || null : null,
      ];
    }),
  );
  return new Map(usageDocs);
}

async function collectStudentQueueCandidates({
  db,
  query,
  language = "",
  nowMillis,
  candidateLimit = DEFAULT_STUDENT_QUERY_LIMIT,
  pageSize = DEFAULT_SCAN_PAGE_SIZE,
  maxPages = DEFAULT_SCAN_MAX_PAGES,
  preferredLevelRank = null,
  preferredLocation = {},
  requesterLevelRank = null,
  requesterLocation = null,
  requesterId = "",
  requesterBlockedIds = [],
  requesterExcludedCandidateIds = [],
  requesterEmail = "",
  repeatDayKey = getUtcDayKey(nowMillis),
}) {
  const targetCount = normalizePositiveInteger(
    candidateLimit,
    DEFAULT_STUDENT_QUERY_LIMIT,
  );
  const scanPageSize = normalizePositiveInteger(pageSize, DEFAULT_SCAN_PAGE_SIZE);
  const scanMaxPages = normalizePositiveInteger(
    maxPages,
    DEFAULT_SCAN_MAX_PAGES,
  );
  const candidates = [];
  let scannedCount = 0;
  let lastDoc = null;
  const qualityRankingEnabled =
    preferredLevelRank !== null ||
    hasLocationFilter(preferredLocation) ||
    requesterLevelRank !== null ||
    hasLocationFilter(requesterLocation || {});

  for (
    let page = 0;
    page < scanMaxPages &&
      (qualityRankingEnabled || candidates.length < targetCount);
    page += 1
  ) {
    const requestDocs = await readQueryPage(query, {
      lastDoc,
      pageSize: scanPageSize,
    });
    if (requestDocs.length === 0) {
      break;
    }

    scannedCount += requestDocs.length;
    const studentUserIds = requestDocs
      .map((doc) => readRequestUserId(doc, readDocData(doc) || {}))
      .filter(Boolean);
    const [studentUserDocsById, usageDataByUserId] = await Promise.all([
      readUserDocsById(db, studentUserIds),
      readUsageDataByUserId(db, studentUserIds),
    ]);
    const pageCandidates = [];
    requestDocs.forEach((requestDoc) => {
      if (!qualityRankingEnabled && candidates.length >= targetCount) {
        return;
      }
      const requestData = readDocData(requestDoc) || {};
      const userId = readRequestUserId(requestDoc, requestData);
      const candidate = buildStudentQueueCandidateFromDocs({
        requestDoc,
        userDoc: studentUserDocsById.get(userId),
        language,
        nowMillis,
        preferredLevelRank,
        preferredLocation,
        requesterLevelRank,
        requesterLocation,
        requesterId,
        requesterBlockedIds,
        requesterExcludedCandidateIds,
        usageData: usageDataByUserId.get(userId) || null,
      });
      if (candidate) {
        pageCandidates.push(candidate);
      }
    });
    const repeatFilteredCandidates = await filterSameDayRepeatCandidateObjects({
      db,
      requesterId,
      requesterEmail,
      candidates: pageCandidates,
      dayKey: repeatDayKey,
    });
    for (const candidate of repeatFilteredCandidates) {
      if (!qualityRankingEnabled && candidates.length >= targetCount) {
        break;
      }
      candidates.push(candidate);
    }

    lastDoc = requestDocs[requestDocs.length - 1];
    if (requestDocs.length < scanPageSize) {
      break;
    }
  }

  return {
    candidates: limitQualityRankedCandidates({
      candidates,
      targetCount,
      qualityRankingEnabled,
    }).map(stripInternalCandidateFields),
    scannedCount,
  };
}

async function collectTeacherAvailabilityCandidates({
  db,
  query,
  language = "",
  now,
  nowMillis,
  candidateLimit = DEFAULT_TEACHER_QUERY_LIMIT,
  pageSize = DEFAULT_SCAN_PAGE_SIZE,
  maxPages = DEFAULT_SCAN_MAX_PAGES,
  tokenReader = getReadOnlyUserVoipTokenState,
  preferredLevelRank = null,
  preferredLocation = {},
  requesterId = "",
  requesterBlockedIds = [],
  requesterExcludedCandidateIds = [],
  requesterEmail = "",
  repeatDayKey = getUtcDayKey(nowMillis),
}) {
  const targetCount = normalizePositiveInteger(
    candidateLimit,
    DEFAULT_TEACHER_QUERY_LIMIT,
  );
  const scanPageSize = normalizePositiveInteger(pageSize, DEFAULT_SCAN_PAGE_SIZE);
  const scanMaxPages = normalizePositiveInteger(
    maxPages,
    DEFAULT_SCAN_MAX_PAGES,
  );
  const candidates = [];
  let scannedCount = 0;
  let lastDoc = null;
  const qualityRankingEnabled =
    preferredLevelRank !== null || hasLocationFilter(preferredLocation);

  for (
    let page = 0;
    page < scanMaxPages &&
      (qualityRankingEnabled || candidates.length < targetCount);
    page += 1
  ) {
    const userDocs = await readQueryPage(query, {
      lastDoc,
      pageSize: scanPageSize,
    });
    if (userDocs.length === 0) {
      break;
    }

    scannedCount += userDocs.length;
    const pageCandidates = [];
    for (const userDoc of userDocs) {
      const candidate = buildTeacherAvailabilityCandidateFromDoc({
        userDoc,
        language,
        now,
        nowMillis,
        preferredLevelRank,
        preferredLocation,
        requesterId,
        requesterBlockedIds,
        requesterExcludedCandidateIds,
      });
      if (!candidate) {
        continue;
      }
      pageCandidates.push({candidate, userDoc});
    }

    const tokenStates = await Promise.all(
      pageCandidates.map(({candidate, userDoc}) =>
        tokenReader(candidate.userId, readDocData(userDoc) || {}, db),
      ),
    );
    const tokenFilteredCandidates = [];
    for (
      let index = 0;
      index < pageCandidates.length;
      index += 1
    ) {
      const tokenState = tokenStates[index] || {};
      const candidateTokenState = buildCandidateTokenState(tokenState);
      if (
        tokenState.hasUsableToken !== true ||
        !candidateTokenState.hasFcmToken &&
        !candidateTokenState.hasVoipPushToken
      ) {
        continue;
      }
      tokenFilteredCandidates.push({
        ...pageCandidates[index].candidate,
        tokenState: candidateTokenState,
      });
    }
    const repeatFilteredCandidates = await filterSameDayRepeatCandidateObjects({
      db,
      requesterId,
      requesterEmail,
      candidates: tokenFilteredCandidates,
      dayKey: repeatDayKey,
    });
    for (const candidate of repeatFilteredCandidates) {
      if (!qualityRankingEnabled && candidates.length >= targetCount) {
        break;
      }
      candidates.push(candidate);
    }

    lastDoc = userDocs[userDocs.length - 1];
    if (userDocs.length < scanPageSize) {
      break;
    }
  }

  return {
    candidates: limitQualityRankedCandidates({
      candidates,
      targetCount,
      qualityRankingEnabled,
    }).map(stripInternalCandidateFields),
    scannedCount,
  };
}

async function readRequesterMatchQualityProfile(
  db,
  requesterId,
  requesterLevel = "",
) {
  const explicitLevelRank = readLevelRankFromLevel(requesterLevel);
  const normalizedRequesterId = normalizeBlockedUserId(requesterId);
  if (!normalizedRequesterId || !db || typeof db.collection !== "function") {
    return {
      levelRank: explicitLevelRank,
      location: null,
      blockedIds: [],
      excludedCandidateIds: [],
      email: "",
    };
  }

  const [requesterDoc, requesterSearchRequestDoc] = await Promise.all([
    db
      .collection(USER_COLLECTION)
      .doc(normalizedRequesterId)
      .get(),
    db
      .collection(SEARCH_REQUEST_COLLECTION)
      .doc(normalizedRequesterId)
      .get(),
  ]);
  const requesterSearchRequestData = readDocData(requesterSearchRequestDoc);
  const excludedCandidateIds = readSearchRequestExcludedCandidateIds(
    requesterSearchRequestData || {},
  );
  const requesterData = readDocData(requesterDoc);
  if (!requesterData) {
    return {
      levelRank: explicitLevelRank,
      location: null,
      blockedIds: [],
      excludedCandidateIds,
      email: "",
    };
  }

  return {
    levelRank: explicitLevelRank ??
      readLevelRankFromLevel(readCandidateLevelValue(requesterData)),
    location: readCandidateLocation(requesterData),
    blockedIds: readBlockedUserIds(requesterData),
    excludedCandidateIds,
    email: readUserEmail(requesterData),
  };
}

async function collectMatchCandidatePool({
  db,
  language = "",
  requesterId = "",
  requesterEmail = "",
  requesterFilters = {},
  requesterLevel = "",
  now = new Date(),
  nowMillis = null,
  studentLimit = DEFAULT_STUDENT_QUERY_LIMIT,
  teacherLimit = DEFAULT_TEACHER_QUERY_LIMIT,
  studentScanPageSize = DEFAULT_SCAN_PAGE_SIZE,
  teacherScanPageSize = DEFAULT_SCAN_PAGE_SIZE,
  studentMaxScanPages = DEFAULT_SCAN_MAX_PAGES,
  teacherMaxScanPages = DEFAULT_SCAN_MAX_PAGES,
}) {
  const effectiveNowMillis = resolveNowMillis(now, nowMillis);
  const normalizedLanguage = readLanguageCode(language);
  const normalizedRequesterId = normalizeBlockedUserId(requesterId);
  if (!normalizedLanguage) {
    return {
      candidates: [],
      stats: {
        studentRequestsScanned: 0,
        studentCandidates: 0,
        teacherUsersScanned: 0,
        teacherCandidates: 0,
        totalCandidates: 0,
      },
    };
  }

  const preferredLevelRank = readPreferredLevelRank(requesterFilters);
  const preferredLocation = readPreferredLocation(requesterFilters);
  const repeatDayKey = getUtcDayKey(effectiveNowMillis);
  const requesterProfile = await readRequesterMatchQualityProfile(
    db,
    normalizedRequesterId,
    requesterLevel,
  );
  const effectiveRequesterEmail =
    normalizeString(requesterEmail).toLowerCase() || requesterProfile.email;

  const [studentResult, teacherResult] = await Promise.all([
    collectStudentQueueCandidates({
      db,
      query: buildActiveStudentSearchRequestsQuery(db, {
        language: normalizedLanguage,
      }),
      language: normalizedLanguage,
      nowMillis: effectiveNowMillis,
      candidateLimit: studentLimit,
      pageSize: studentScanPageSize,
      maxPages: studentMaxScanPages,
      preferredLevelRank,
      preferredLocation,
      requesterLevelRank: requesterProfile.levelRank,
      requesterLocation: requesterProfile.location,
      requesterId: normalizedRequesterId,
      requesterBlockedIds: requesterProfile.blockedIds,
      requesterExcludedCandidateIds: requesterProfile.excludedCandidateIds,
      requesterEmail: effectiveRequesterEmail,
      repeatDayKey,
    }),
    collectTeacherAvailabilityCandidates({
      db,
      query: buildAvailableTeachersQuery(db, {language: normalizedLanguage}),
      language: normalizedLanguage,
      now,
      nowMillis: effectiveNowMillis,
      candidateLimit: teacherLimit,
      pageSize: teacherScanPageSize,
      maxPages: teacherMaxScanPages,
      preferredLevelRank,
      preferredLocation,
      requesterId: normalizedRequesterId,
      requesterBlockedIds: requesterProfile.blockedIds,
      requesterExcludedCandidateIds: requesterProfile.excludedCandidateIds,
      requesterEmail: effectiveRequesterEmail,
      repeatDayKey,
    }),
  ]);

  const candidates = mergeCandidatePools({
    studentCandidates: studentResult.candidates,
    teacherCandidates: teacherResult.candidates,
    requesterId: normalizedRequesterId,
  });

  return {
    candidates,
    stats: {
      studentRequestsScanned: studentResult.scannedCount,
      studentCandidates: studentResult.candidates.length,
      teacherUsersScanned: teacherResult.scannedCount,
      teacherCandidates: teacherResult.candidates.length,
      totalCandidates: candidates.length,
    },
  };
}

module.exports = {
  DEFAULT_STUDENT_QUERY_LIMIT,
  DEFAULT_TEACHER_QUERY_LIMIT,
  DEFAULT_SCAN_MAX_PAGES,
  DEFAULT_SCAN_PAGE_SIZE,
  MATCH_CANDIDATE_SOURCE,
  buildActiveStudentSearchRequestsQuery,
  buildAvailableTeachersQuery,
  buildStudentQueueCandidateFromDocs,
  buildTeacherAvailabilityCandidateFromDoc,
  collectStudentQueueCandidates,
  collectTeacherAvailabilityCandidates,
  collectMatchCandidatePool,
  compareNeutralCandidateOrder,
  readPreferredLevelRank,
  isActiveStudentSearchRequest,
  mergeCandidatePools,
  timestampToMillis,
  validateActiveStudentSearchRequest,
};
