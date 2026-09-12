const functions = require("firebase-functions/v1");
const {
  buildStudentCallAccessDecision,
} = require("./call_access");
const {
  normalizeAppState,
} = require("./search_requests");
const {
  MATCH_PROTOCOL_VERSION,
  supportsMatchProtocolV2,
} = require("./match_protocol_v2");
const {
  normalizeSearchLifecycleRequestId,
} = require("./search_cancellation_intents");
const {
  normalizeSupportedLocation,
} = require("./supported_locations");

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function readCallableData(data) {
  return data && typeof data === "object" && !Array.isArray(data) ? data : {};
}

function readNestedObject(value) {
  return value && typeof value === "object" && !Array.isArray(value) ?
    value :
    {};
}

function hasDirectCallTarget(payload = {}) {
  return [
    payload.directTutorId,
    payload.directUserId,
    payload.targetUserId,
    payload.targetTutorId,
    payload.teacherId,
    payload.tutorId,
  ].some((value) => normalizeString(value));
}

function normalizeStartSearchInput(data) {
  const payload = readCallableData(data);
  if (hasDirectCallTarget(payload)) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Direct calls must use direct-call endpoints",
        {reason: "direct_call_not_supported"},
    );
  }

  const filters = readNestedObject(payload.filters);
  const rawCountryCode = normalizeString(
      payload.preferredCountry || payload.countryCode || filters.countryCode,
  );
  const rawCityKey = normalizeString(payload.cityKey || filters.cityKey);
  const location = normalizeSupportedLocation(rawCountryCode, rawCityKey);
  if ((rawCountryCode || rawCityKey) && !location) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Location is not supported",
        {reason: "unsupported_location"},
    );
  }
  const rawRequestId = payload.requestId;
  const requestId = rawRequestId == null ?
    "" :
    normalizeSearchLifecycleRequestId(rawRequestId);
  if (rawRequestId != null && !requestId) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "requestId is invalid",
    );
  }
  return {
    requestId,
    language: normalizeString(payload.language || payload.languageCode),
    preferredPartnerLevel: normalizeString(
        payload.preferredPartnerLevel ||
        payload.preferredLevel ||
        filters.preferredLevel ||
        filters.level,
    ),
    preferredCountry: location?.countryCode || "",
    cityKey: location?.cityKey || "",
    appState: normalizeAppState(payload.appState),
    platform: normalizeString(payload.platform),
    matchProtocolVersion: supportsMatchProtocolV2(
        payload.matchProtocolVersion,
    ) ? MATCH_PROTOCOL_VERSION : 1,
  };
}

function buildStartSearchAccessDecision({
  requesterRole,
  requesterData = {},
  trialData = null,
  usageData = null,
  nowMillis = Date.now(),
}) {
  return buildStudentCallAccessDecision({
    userRole: requesterRole,
    userData: requesterData,
    trialData,
    usageData,
    nowMillis,
  });
}

function throwAccessDecision(decision) {
  if (decision.allowed) {
    return;
  }

  throw new functions.https.HttpsError(
      decision.code,
      decision.message,
      {
        reason: decision.reason,
        ...(decision.retryAfterMillis ? {
          retryAfterMillis: decision.retryAfterMillis,
        } : {}),
      },
  );
}

module.exports = {
  buildStartSearchAccessDecision,
  normalizeStartSearchInput,
  throwAccessDecision,
};
