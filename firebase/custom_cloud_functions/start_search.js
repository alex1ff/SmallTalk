const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  hasUsableGiftMinutes,
} = require("./gift_minutes_shared");
const {
  checkUsageLimits,
  hasActiveSubscription,
  usageDocRef,
} = require("./subscription_usage_shared");
const {
  isSupportedSessionRole,
  normalizeRole,
  readCountryCode,
  readLevelValue,
  resolveActiveConversationLanguage,
} = require("./video_sessions_shared");
const {
  SEARCH_REQUEST_ACTIVE_STATUSES,
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_FIELD,
  SEARCH_REQUEST_STATUS,
  SEARCH_REQUEST_TIMING,
  buildInitialSearchRequestData,
  normalizeAppState,
  normalizeSearchRequestFilters,
} = require("./search_requests");

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

function readCityKey(value) {
  if (!value) {
    return "";
  }

  if (typeof value === "string") {
    return normalizeString(value);
  }

  if (typeof value === "object") {
    return normalizeString(value.key || value.cityKey || value.value || "");
  }

  return "";
}

function hasDirectCallTarget(payload = {}) {
  return [
    payload.directTutorId,
    payload.directUserId,
    payload.targetUserId,
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
  return {
    language: normalizeString(payload.language || payload.languageCode),
    preferredPartnerLevel: normalizeString(
      payload.preferredPartnerLevel ||
        payload.preferredLevel ||
        filters.preferredLevel ||
        filters.level,
    ),
    preferredCountry: normalizeString(
      payload.preferredCountry ||
        payload.countryCode ||
        filters.countryCode,
    ),
    cityKey: normalizeString(payload.cityKey || filters.cityKey),
    appState: normalizeAppState(payload.appState),
    platform: normalizeString(payload.platform),
  };
}

function buildStartSearchAccessDecision({
  requesterRole,
  requesterData = {},
  usageData = null,
  nowMillis = Date.now(),
}) {
  if (requesterRole !== "student") {
    return {
      allowed: false,
      code: "permission-denied",
      reason: "student_required",
      message: "Only students can start search",
    };
  }

  if (
    requesterData.isInCall === true ||
    normalizeString(requesterData.currentSessionId)
  ) {
    return {
      allowed: false,
      code: "failed-precondition",
      reason: "active_call",
      message: "Active call must finish before starting search",
    };
  }

  const hasSubscription = hasActiveSubscription(requesterData, nowMillis);
  const hasGift = hasUsableGiftMinutes(requesterData, nowMillis);
  if (!hasSubscription && !hasGift) {
    return {
      allowed: false,
      code: "failed-precondition",
      reason: "no_active_access",
      message: "Active subscription or gift minutes are required",
    };
  }

  if (hasSubscription) {
    const usageCheck = checkUsageLimits(usageData, new Date(nowMillis));
    if (!usageCheck.allowed) {
      return {
        allowed: false,
        code: "resource-exhausted",
        reason: usageCheck.reason,
        message: usageCheck.reason === "daily_limit_reached" ?
          "Daily subscription call limit reached" :
          "Weekly subscription call limit reached",
      };
    }
  }

  return {
    allowed: true,
    code: null,
    reason: "ready",
    message: "",
  };
}

function throwAccessDecision(decision) {
  if (decision.allowed) {
    return;
  }

  throw new functions.https.HttpsError(
    decision.code,
    decision.message,
    {reason: decision.reason},
  );
}

function buildStartSearchFilters({
  input = {},
  requesterData = {},
}) {
  const storedProfile = readNestedObject(requesterData.matchProfile);
  return normalizeSearchRequestFilters({
    preferredLevel:
      input.preferredPartnerLevel ||
      readLevelValue(requesterData.level) ||
      readLevelValue(storedProfile.level),
    countryCode:
      input.preferredCountry ||
      readCountryCode(requesterData.Country_NS) ||
      readCountryCode(storedProfile.country),
    cityKey:
      input.cityKey ||
      readCityKey(requesterData.profileCity) ||
      readCityKey(storedProfile.city),
  });
}

function timestampToMillis(value) {
  if (!value) {
    return null;
  }
  if (typeof value.toMillis === "function") {
    const millis = Number(value.toMillis());
    return Number.isFinite(millis) ? millis : null;
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  const millis = Number(value);
  return Number.isFinite(millis) ? millis : null;
}

function timestampToIsoString(value) {
  const millis = timestampToMillis(value);
  return millis === null ? null : new Date(millis).toISOString();
}

function readReferenceId(value) {
  return value && typeof value.id === "string" ? value.id.trim() : "";
}

function searchRequestBelongsToUser(requestData = {}, userId) {
  const normalizedUserId = normalizeString(userId);
  const explicitUserIds = [
    requestData.userId,
    requestData.studentId,
    requestData.requesterId,
  ].map(normalizeString).filter(Boolean);
  const referencedUserIds = [
    requestData.userRef,
    requestData.studentRef,
    requestData.requesterRef,
  ].map(readReferenceId).filter(Boolean);
  const ownerIds = [...explicitUserIds, ...referencedUserIds];

  return ownerIds.length === 0 ||
    ownerIds.every((ownerId) => ownerId === normalizedUserId);
}

function isReusableSearchRequest(requestData = {}, nowMillis = Date.now()) {
  const status = normalizeString(requestData.status);
  if (!SEARCH_REQUEST_ACTIVE_STATUSES.includes(status)) {
    return false;
  }

  const expiresAtMillis = timestampToMillis(requestData.expiresAt);
  if (expiresAtMillis === null || expiresAtMillis <= nowMillis) {
    return false;
  }

  if (status === SEARCH_REQUEST_STATUS.MATCHED) {
    return true;
  }

  const isBackgroundSearch =
    normalizeAppState(requestData.appState) ===
      SEARCH_REQUEST_APP_STATE.BACKGROUND;
  const backgroundExpiresAtMillis = timestampToMillis(
    requestData.backgroundExpiresAt,
  );
  if (
    isBackgroundSearch &&
    backgroundExpiresAtMillis !== null &&
    backgroundExpiresAtMillis <= nowMillis
  ) {
    return false;
  }
  if (
    isBackgroundSearch &&
    backgroundExpiresAtMillis !== null &&
    backgroundExpiresAtMillis > nowMillis
  ) {
    return true;
  }

  const heartbeatAtMillis = timestampToMillis(requestData.heartbeatAt);
  const staleCutoffMillis =
    nowMillis - SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS * 1000;

  return heartbeatAtMillis !== null && heartbeatAtMillis >= staleCutoffMillis;
}

function canReuseSearchRequestForUser({
  requestData = {},
  userId,
  nowMillis = Date.now(),
}) {
  return searchRequestBelongsToUser(requestData, userId) &&
    isReusableSearchRequest(requestData, nowMillis);
}

function buildStartSearchResponse({
  userId,
  requestData = {},
  reused = false,
}) {
  return {
    status: normalizeString(requestData.status) || "active",
    searchRequestId: userId,
    requestId: normalizeString(requestData.requestId) || null,
    sessionId:
      normalizeString(requestData.currentSessionId) ||
      normalizeString(requestData.activeSessionId) ||
      normalizeString(requestData.matchedSessionId) ||
      null,
    pairAttemptId: normalizeString(requestData.pairAttemptId) || null,
    expiresAt: timestampToIsoString(requestData.expiresAt),
    errorCode: null,
    reused,
  };
}

function buildStartSearchRequestData({
  userId,
  userRef,
  requestId,
  requesterData = {},
  input = {},
  nowMillis = Date.now(),
  serverTimestamp,
  timestampFromMillis = admin.firestore.Timestamp.fromMillis,
}) {
  const resolvedLanguage = resolveActiveConversationLanguage(
    requesterData,
    input.language,
  );
  if (!resolvedLanguage.code) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Language is required",
      {reason: "language_required"},
    );
  }

  const expiresAt = timestampFromMillis(
    nowMillis + SEARCH_REQUEST_TIMING.MAX_SEARCH_SECONDS * 1000,
  );
  const backgroundExpiresAt =
    input.appState === SEARCH_REQUEST_APP_STATE.BACKGROUND ?
      timestampFromMillis(
        nowMillis +
          SEARCH_REQUEST_TIMING.BACKGROUND_MAX_SEARCH_SECONDS * 1000,
      ) :
      null;

  return buildInitialSearchRequestData({
    userId,
    userRef,
    requestId,
    role: "student",
    language: resolvedLanguage.code,
    filters: buildStartSearchFilters({input, requesterData}),
    appState: input.appState,
    platform: input.platform,
    serverTimestamp,
    expiresAt,
    backgroundExpiresAt,
  });
}

exports.startSearch = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  const input = normalizeStartSearchInput(data);
  const db = admin.firestore();
  const userId = context.auth.uid;
  const userRef = db.collection("users").doc(userId);
  const searchRequestRef = db
    .collection(SEARCH_REQUEST_COLLECTION)
    .doc(userId);
  const usageRef = usageDocRef(db, userId);
  const requestId = db.collection(SEARCH_REQUEST_COLLECTION).doc().id;
  const nowMillis = Date.now();
  const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();

  return db.runTransaction(async (transaction) => {
    const requesterSnapshot = await transaction.get(userRef);
    if (!requesterSnapshot.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Requester not found",
      );
    }

    const usageSnapshot = await transaction.get(usageRef);
    const searchRequestSnapshot = await transaction.get(searchRequestRef);
    const requesterData = requesterSnapshot.data() || {};
    const requesterRole = normalizeRole(requesterData.role);
    if (!isSupportedSessionRole(requesterRole)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "This user role cannot start search",
        {reason: "unsupported_role"},
      );
    }

    const existingRequestData = searchRequestSnapshot.exists ?
      searchRequestSnapshot.data() || {} :
      null;
    const accessDecision = buildStartSearchAccessDecision({
      requesterRole,
      requesterData,
      usageData: usageSnapshot.exists ? usageSnapshot.data() : null,
      nowMillis,
    });

    if (
      existingRequestData &&
      canReuseSearchRequestForUser({
        requestData: existingRequestData,
        userId,
        nowMillis,
      })
    ) {
      return buildStartSearchResponse({
        userId,
        requestData: existingRequestData,
        reused: true,
      });
    }

    throwAccessDecision(accessDecision);

    const nextRequestData = buildStartSearchRequestData({
      userId,
      userRef,
      requestId,
      requesterData,
      input,
      nowMillis,
      serverTimestamp,
    });
    transaction.set(searchRequestRef, nextRequestData);

    return buildStartSearchResponse({
      userId,
      requestData: nextRequestData,
      reused: false,
    });
  });
});

exports.__private__ = {
  buildStartSearchAccessDecision,
  buildStartSearchFilters,
  buildStartSearchRequestData,
  buildStartSearchResponse,
  canReuseSearchRequestForUser,
  isReusableSearchRequest,
  normalizeStartSearchInput,
  searchRequestBelongsToUser,
  timestampToMillis,
};
