const {
  buildTrialCallAccessDecision,
} = require("./trial_access");

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
  trialData = null,
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

  const subscriptionDecision = buildTrialCallAccessDecision({
    userData,
    trialData,
    nowMillis,
  });
  if (!subscriptionDecision.allowed) {
    return {
      allowed: false,
      code: "failed-precondition",
      reason: subscriptionDecision.reason,
      message: subscriptionDecision.reason === "trial_call_consumed" ?
        "Trial call already used" :
        subscriptionDecision.reason === "trial_window_expired" ?
          "Trial call window has expired" :
          subscriptionDecision.reason === "retry_cooldown" ?
            "Please wait before retrying" :
            "Active subscription is required",
      mode: subscriptionDecision.mode,
      retryAfterMillis: subscriptionDecision.retryAfterMillis || null,
    };
  }

  return {
    allowed: true,
    code: null,
    reason: "ready",
    message: "",
    mode: subscriptionDecision.mode,
    retryAfterMillis: null,
  };
}

module.exports = {
  buildStudentCallAccessDecision,
  hasActiveCallState,
};
