const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { evaluateTutorAvailabilityWindow } = require("./availability");
const {
  buildMatchProfile,
  extractBlockedIds,
  isSupportedSessionRole,
  normalizeRole,
  resolveActiveConversationLanguage,
  supportsConversationLanguage,
} = require("./video_sessions_shared");
const {
  getRepeatBypassUserIds,
  loadSameDayRepeatCandidateIds,
} = require("./match_repeat_prevention");
const {
  getReadOnlyUserVoipTokenState,
} = require("./voip_tokens");
const {
  checkUsageLimits,
  hasActiveSubscription,
  readUsage,
} = require("./subscription_usage_shared");
const { hasUsableGiftMinutes } = require("./gift_minutes_shared");
const {
  hasActiveCallState,
} = require("./call_access");

const DIRECT_CALL_STATUS_TTL_SECONDS = 15;
const MAX_UID_LENGTH = 128;

function normalizeTargetUserId(rawValue) {
  if (typeof rawValue !== "string") {
    return "";
  }

  const value = rawValue.trim();
  if (
    value.length === 0 ||
    value.length > MAX_UID_LENGTH ||
    value.includes("/") ||
    value === "." ||
    value === ".." ||
    /^__.*__$/.test(value)
  ) {
    return "";
  }

  return value;
}

function readCallableData(data) {
  return data && typeof data === "object" && !Array.isArray(data) ? data : {};
}

function buildDirectCallStatusResponse({
  targetUserId,
  canStartDirectCall = false,
  callability,
  reason,
  checkedAtMillis = Date.now(),
}) {
  return {
    status: "ok",
    targetUserId,
    canStartDirectCall,
    callability,
    reason,
    checkedAtMillis,
    ttlSeconds: DIRECT_CALL_STATUS_TTL_SECONDS,
  };
}

function buildUnavailableStatus(targetUserId, checkedAtMillis = Date.now()) {
  return buildDirectCallStatusResponse({
    targetUserId,
    callability: "unavailable",
    reason: "unavailable",
    checkedAtMillis,
  });
}

function isAvailableAfterInFuture(userData = {}, now = new Date()) {
  const availableAfter = userData.availableAfter;
  if (!availableAfter || typeof availableAfter.toDate !== "function") {
    return false;
  }

  return availableAfter.toDate() > now;
}

function buildAccessDecision({
  requesterRole,
  requesterData = {},
  usageData = null,
  nowMillis = Date.now(),
}) {
  if (requesterRole !== "student") {
    return {
      allowed: false,
      callability: "unknown",
      reason: "unavailable",
    };
  }
  if (hasActiveCallState(requesterData)) {
    return {
      allowed: false,
      callability: "unavailable",
      reason: "unavailable",
    };
  }

  const requesterHasSubscription = hasActiveSubscription(
    requesterData,
    nowMillis,
  );
  const requesterHasGift = hasUsableGiftMinutes(requesterData, nowMillis);
  if (!requesterHasSubscription && !requesterHasGift) {
    return {
      allowed: false,
      callability: "requires_access",
      reason: "requires_access",
    };
  }

  if (requesterHasSubscription) {
    const usageCheck = checkUsageLimits(usageData, new Date(nowMillis));
    if (!usageCheck.allowed) {
      return {
        allowed: false,
        callability: "requires_access",
        reason: "requires_access",
      };
    }
  }

  return {
    allowed: true,
    callability: "callable",
    reason: "ready",
  };
}

function buildPreTargetAccessResponse({
  targetUserId,
  requesterRole,
  requesterData = {},
  checkedAtMillis = Date.now(),
}) {
  const accessDecision = buildAccessDecision({
    requesterRole,
    requesterData,
    usageData: null,
    nowMillis: checkedAtMillis,
  });
  if (accessDecision.allowed) {
    return null;
  }

  return buildDirectCallStatusResponse({
    targetUserId,
    callability: accessDecision.callability,
    reason: accessDecision.reason,
    checkedAtMillis,
  });
}

function buildDirectCallStatusDecision({
  requesterId,
  requesterData = {},
  requesterRole,
  targetUserId,
  targetData = null,
  language,
  sameDayRepeatBlocked = false,
  targetHasCallToken = true,
  now = new Date(),
  checkedAtMillis = Date.now(),
}) {
  if (targetUserId === requesterId) {
    return buildDirectCallStatusResponse({
      targetUserId,
      callability: "self",
      reason: "self",
      checkedAtMillis,
    });
  }

  const requesterBlockedIds = extractBlockedIds(requesterData.blockedUsers);
  if (requesterBlockedIds.includes(targetUserId)) {
    return buildDirectCallStatusResponse({
      targetUserId,
      callability: "blocked_for_requester",
      reason: "blocked_for_requester",
      checkedAtMillis,
    });
  }

  if (!targetData) {
    return buildUnavailableStatus(targetUserId, checkedAtMillis);
  }

  const normalizedRequesterRole = normalizeRole(
    requesterRole || requesterData.role,
  );
  if (normalizedRequesterRole !== "student") {
    return buildDirectCallStatusResponse({
      targetUserId,
      callability: "unknown",
      reason: "unavailable",
      checkedAtMillis,
    });
  }

  const targetRole = normalizeRole(targetData.role);
  if (targetRole !== "native_speaker") {
    return buildUnavailableStatus(targetUserId, checkedAtMillis);
  }

  const resolvedLanguage = resolveActiveConversationLanguage(
    requesterData,
    language,
  );
  const normalizedLanguage = resolvedLanguage.code;
  if (!normalizedLanguage) {
    return buildUnavailableStatus(targetUserId, checkedAtMillis);
  }

  const targetProfile = buildMatchProfile(
    targetUserId,
    targetData,
    normalizedLanguage,
  );
  if (!targetProfile.approvedTeacher) {
    return buildUnavailableStatus(targetUserId, checkedAtMillis);
  }

  const targetBlockedIds = extractBlockedIds(targetData.blockedUsers);
  if (targetBlockedIds.includes(requesterId)) {
    return buildUnavailableStatus(targetUserId, checkedAtMillis);
  }

  if (!supportsConversationLanguage(targetData, normalizedLanguage)) {
    return buildUnavailableStatus(targetUserId, checkedAtMillis);
  }

  if (isAvailableAfterInFuture(targetData, now)) {
    return buildUnavailableStatus(targetUserId, checkedAtMillis);
  }

  const availabilityCheck = evaluateTutorAvailabilityWindow(targetData, now);
  if (!availabilityCheck.isAvailable || hasActiveCallState(targetData)) {
    return buildUnavailableStatus(targetUserId, checkedAtMillis);
  }

  if (!targetHasCallToken) {
    return buildUnavailableStatus(targetUserId, checkedAtMillis);
  }

  if (sameDayRepeatBlocked) {
    return buildUnavailableStatus(targetUserId, checkedAtMillis);
  }

  return buildDirectCallStatusResponse({
    targetUserId,
    canStartDirectCall: true,
    callability: "callable",
    reason: "ready",
    checkedAtMillis,
  });
}

exports.getDirectCallStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  const payload = readCallableData(data);
  const targetUserId = normalizeTargetUserId(
    payload.targetUserId || payload.directUserId || payload.directTutorId,
  );
  if (!targetUserId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "targetUserId is required",
    );
  }

  const requesterId = context.auth.uid;
  const checkedAtMillis = Date.now();
  const db = admin.firestore();
  const requesterDoc = await db.collection("users").doc(requesterId).get();
  if (!requesterDoc.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "Requester not found",
    );
  }

  const requesterData = requesterDoc.data() || {};
  const requesterRole = normalizeRole(requesterData.role);
  if (!isSupportedSessionRole(requesterRole)) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "This user role cannot start direct calls",
    );
  }
  if (requesterRole !== "student") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only students can check direct call status",
    );
  }

  const preTargetAccessResponse = buildPreTargetAccessResponse({
    targetUserId,
    requesterRole,
    requesterData,
    checkedAtMillis,
  });
  if (preTargetAccessResponse) {
    return preTargetAccessResponse;
  }

  const usageData = await readUsage(db, requesterId);
  const accessDecision = buildAccessDecision({
    requesterRole,
    requesterData,
    usageData,
    nowMillis: checkedAtMillis,
  });
  if (!accessDecision.allowed) {
    return buildDirectCallStatusResponse({
      targetUserId,
      callability: accessDecision.callability,
      reason: accessDecision.reason,
      checkedAtMillis,
    });
  }

  if (targetUserId === requesterId) {
    return buildDirectCallStatusDecision({
      requesterId,
      requesterData,
      requesterRole,
      targetUserId,
      checkedAtMillis,
    });
  }

  const targetDoc = await db.collection("users").doc(targetUserId).get();
  const targetData = targetDoc.exists ? targetDoc.data() || {} : null;
  let status = buildDirectCallStatusDecision({
    requesterId,
    requesterData,
    requesterRole,
    targetUserId,
    targetData,
    language: payload.language,
    checkedAtMillis,
  });
  if (!status.canStartDirectCall) {
    return status;
  }

  const targetTokenState = await getReadOnlyUserVoipTokenState(
    targetUserId,
    targetData,
    db,
  );
  const targetHasCallToken =
    targetTokenState.hasUsableToken === true &&
    (
      targetTokenState.hasFcmToken === true ||
      targetTokenState.hasVoipPushToken === true
    );
  if (!targetHasCallToken) {
    return buildDirectCallStatusDecision({
      requesterId,
      requesterData,
      requesterRole,
      targetUserId,
      targetData,
      language: payload.language,
      targetHasCallToken: false,
      checkedAtMillis,
    });
  }

  const repeatPreventionContext = await loadSameDayRepeatCandidateIds(
    db,
    requesterId,
    [targetUserId],
    {
      bypassUserIds: getRepeatBypassUserIds(),
      requesterEmail: requesterData.email || context.auth.token.email,
      userEmailsById: {[targetUserId]: targetData.email},
    },
  );
  if (repeatPreventionContext.excludedCandidateIds.has(targetUserId)) {
    status = buildDirectCallStatusDecision({
      requesterId,
      requesterData,
      requesterRole,
      targetUserId,
      targetData,
      language: payload.language,
      sameDayRepeatBlocked: true,
      checkedAtMillis,
    });
  }

  return status;
});

exports.__private__ = {
  DIRECT_CALL_STATUS_TTL_SECONDS,
  buildAccessDecision,
  buildDirectCallStatusDecision,
  buildDirectCallStatusResponse,
  buildPreTargetAccessResponse,
  normalizeTargetUserId,
};
