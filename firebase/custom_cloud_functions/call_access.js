const {
  hasUsableGiftMinutes,
} = require("./gift_minutes_shared");
const {
  checkUsageLimits,
  hasActiveSubscription,
} = require("./subscription_usage_shared");

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function hasActiveCallState(userData = {}) {
  return userData.isInCall === true ||
    Boolean(normalizeString(userData.currentSessionId));
}

function buildStudentCallAccessDecision({
  userRole,
  userData = {},
  usageData = null,
  nowMillis = Date.now(),
}) {
  if (userRole !== "student") {
    return {
      allowed: false,
      code: "permission-denied",
      reason: "student_required",
      message: "Only students can start search",
    };
  }

  if (hasActiveCallState(userData)) {
    return {
      allowed: false,
      code: "failed-precondition",
      reason: "active_call",
      message: "Active call must finish before starting search",
    };
  }

  const hasSubscription = hasActiveSubscription(userData, nowMillis);
  const hasGift = hasUsableGiftMinutes(userData, nowMillis);
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

module.exports = {
  buildStudentCallAccessDecision,
  hasActiveCallState,
};
