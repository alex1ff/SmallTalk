// Server-owned trial call access policy.
//
// A RevenueCat introductory subscription is active while its period type is
// TRIAL, but that must not be treated as full Premium. This module keeps the
// distinction in one place for every call entry point.

const crypto = require("node:crypto");
const admin = require("firebase-admin");

const TRIAL_PRODUCT_ID = "expatlio_trial_1_Month";
const PREMIUM_PRODUCT_IDS = new Set([
  "expatlio_1_Month",
  "expatlio_3_Month",
  TRIAL_PRODUCT_ID,
]);
const PAID_PERIOD_TYPES = new Set(["NORMAL"]);
const TRIAL_WINDOW_MS = 30 * 60 * 1000;
const TRIAL_QUALIFICATION_SECONDS = 120;
const TRIAL_MAX_ATTEMPTS = 3;
const TRIAL_MAX_TECHNICAL_RETRIES = 2;
const TRIAL_RETRY_COOLDOWN_MS = 10 * 1000;
const TRIAL_RESERVATION_LEASE_MS = 90 * 1000;

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function timestampToMillis(value) {
  if (value == null) return null;
  if (typeof value.toMillis === "function") {
    const result = Number(value.toMillis());
    return Number.isFinite(result) ? result : null;
  }
  if (value instanceof Date) return value.getTime();
  const result = Number(value);
  return Number.isFinite(result) ? result : null;
}

function trialAccessRef(db, uid) {
  return db.collection("users").doc(uid)
      .collection("trialAccess").doc("current");
}

function subscriptionData(userData = {}) {
  const subscription = userData.subscription;
  return subscription && typeof subscription === "object" ? subscription : {};
}

function subscriptionProductId(userData = {}) {
  return normalizeString(subscriptionData(userData).productId);
}

function subscriptionPeriodType(userData = {}) {
  return normalizeString(subscriptionData(userData).periodType).toUpperCase();
}

function hasActiveSubscription(userData = {}, nowMillis = Date.now()) {
  const expiresAt = timestampToMillis(subscriptionData(userData).expiresAt);
  return expiresAt != null && expiresAt > nowMillis;
}

function isTrialSubscription(userData = {}, nowMillis = Date.now()) {
  return hasActiveSubscription(userData, nowMillis) &&
    subscriptionProductId(userData) === TRIAL_PRODUCT_ID &&
    subscriptionPeriodType(userData) === "TRIAL";
}

function isPaidPremium(userData = {}, nowMillis = Date.now()) {
  return hasActiveSubscription(userData, nowMillis) &&
    PREMIUM_PRODUCT_IDS.has(subscriptionProductId(userData)) &&
    PAID_PERIOD_TYPES.has(subscriptionPeriodType(userData));
}

function normalizeTrialStatus(value) {
  const status = normalizeString(value);
  return ["eligible", "inProgress", "consumed", "expired"].includes(status) ?
    status : "expired";
}

function buildTrialCallAccessDecision({
  userData = {},
  trialData = null,
  nowMillis = Date.now(),
} = {}) {
  if (isPaidPremium(userData, nowMillis)) {
    return {
      allowed: true,
      mode: "premium",
      reason: "ready",
      trialCallId: null,
      retryAfterMillis: null,
    };
  }

  if (!isTrialSubscription(userData, nowMillis)) {
    return {
      allowed: false,
      mode: null,
      reason: "no_subscription",
      trialCallId: null,
      retryAfterMillis: null,
    };
  }

  if (!trialData || typeof trialData !== "object") {
    return {
      allowed: false,
      mode: "trial",
      reason: "trial_state_unavailable",
      trialCallId: null,
      retryAfterMillis: null,
    };
  }

  const status = normalizeTrialStatus(trialData.trialCallStatus);
  const deadline = timestampToMillis(trialData.trialCallWindowExpiresAt);
  const retryNotBeforeAt = timestampToMillis(trialData.retryNotBeforeAt);
  const reservationLeaseExpiresAt = timestampToMillis(
      trialData.reservationLeaseExpiresAt,
  );
  if (deadline == null || deadline <= nowMillis) {
    return {
      allowed: false,
      mode: "trial",
      reason: "trial_window_expired",
      trialCallId: null,
      retryAfterMillis: null,
    };
  }
  if (status === "consumed") {
    return {
      allowed: false,
      mode: "trial",
      reason: "trial_call_consumed",
      trialCallId: null,
      retryAfterMillis: null,
    };
  }
  if (status === "expired") {
    return {
      allowed: false,
      mode: "trial",
      reason: "trial_window_expired",
      trialCallId: null,
      retryAfterMillis: null,
    };
  }
  if (status === "inProgress" &&
      (reservationLeaseExpiresAt == null ||
        reservationLeaseExpiresAt > nowMillis)) {
    return {
      allowed: false,
      mode: "trial",
      reason: "trial_call_in_progress",
      trialCallId: normalizeString(trialData.trialCallId) || null,
      retryAfterMillis: null,
    };
  }
  if (retryNotBeforeAt != null && retryNotBeforeAt > nowMillis) {
    return {
      allowed: false,
      mode: "trial",
      reason: "retry_cooldown",
      trialCallId: null,
      retryAfterMillis: retryNotBeforeAt,
    };
  }

  return {
    allowed: true,
    mode: "trial",
    reason: "ready",
    trialCallId: null,
    retryAfterMillis: null,
  };
}

function reserveTrialCallInTransaction({
  transaction,
  trialRef,
  trialSnap,
  requestId,
  nowMillis = Date.now(),
} = {}) {
  const data = trialSnap && trialSnap.exists ? trialSnap.data() || {} : {};
  const status = normalizeTrialStatus(data.trialCallStatus);
  const deadline = timestampToMillis(data.trialCallWindowExpiresAt);
  const retryNotBeforeAt = timestampToMillis(data.retryNotBeforeAt);
  const reservationLeaseExpiresAt = timestampToMillis(
      data.reservationLeaseExpiresAt,
  );
  const attemptCount = Number(data.attemptCount) || 0;
  let technicalRetryCount = Number(data.technicalRetryCount) || 0;
  if (status === "inProgress" && reservationLeaseExpiresAt != null &&
      reservationLeaseExpiresAt <= nowMillis) {
    // A crashed client may never call endSession. Convert its expired lease
    // into one technical retry before trying to reserve the next call.
    technicalRetryCount += 1;
    if (deadline == null || deadline <= nowMillis ||
        technicalRetryCount > TRIAL_MAX_TECHNICAL_RETRIES) {
      transaction.set(trialRef, {
        trialCallStatus: "expired",
        terminationReason: "technical_failure",
        lastEndedAt: admin.firestore.Timestamp.fromMillis(nowMillis),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      return {allowed: false, reason: "trial_call_consumed"};
    }
    transaction.set(trialRef, {
      trialCallStatus: "eligible",
      technicalRetryCount,
      trialCallId: null,
      reservationLeaseExpiresAt: null,
      retryNotBeforeAt: admin.firestore.Timestamp.fromMillis(
          nowMillis + TRIAL_RETRY_COOLDOWN_MS,
      ),
      terminationReason: "technical_failure",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return {
      allowed: false,
      reason: "retry_cooldown",
      retryAfterMillis: nowMillis + TRIAL_RETRY_COOLDOWN_MS,
    };
  }
  if (status !== "eligible" || deadline == null || deadline <= nowMillis) {
    return {
      allowed: false,
      reason: deadline != null && deadline <= nowMillis ?
        "trial_window_expired" : "trial_call_consumed",
    };
  }
  if (retryNotBeforeAt != null && retryNotBeforeAt > nowMillis) {
    return {
      allowed: false,
      reason: "retry_cooldown",
      retryAfterMillis: retryNotBeforeAt,
    };
  }
  if (attemptCount >= TRIAL_MAX_ATTEMPTS ||
      technicalRetryCount > TRIAL_MAX_TECHNICAL_RETRIES) {
    transaction.set(trialRef, {
      trialCallStatus: "expired",
      terminationReason: "expired",
      lastEndedAt: admin.firestore.Timestamp.fromMillis(nowMillis),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return {allowed: false, reason: "trial_call_consumed"};
  }

  const trialCallId = normalizeString(requestId) || `trial_${crypto.randomUUID()}`;
  transaction.set(trialRef, {
    trialCallStatus: "inProgress",
    trialCallId,
    attemptCount: attemptCount + 1,
    reservationLeaseExpiresAt: admin.firestore.Timestamp.fromMillis(
        nowMillis + TRIAL_RESERVATION_LEASE_MS),
    lastLifecycleAt: admin.firestore.Timestamp.fromMillis(nowMillis),
    retryNotBeforeAt: null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return {allowed: true, trialCallId};
}

function reconcileTrialCallInTransaction({
  transaction,
  trialRef,
  trialSnap,
  trialCallId,
  durationSeconds = 0,
  technicalFailure = false,
  nowMillis = Date.now(),
} = {}) {
  if (!trialSnap || !trialSnap.exists) return {updated: false};
  const data = trialSnap.data() || {};
  if (normalizeString(data.trialCallId) !== normalizeString(trialCallId) ||
      normalizeTrialStatus(data.trialCallStatus) !== "inProgress") {
    return {updated: false};
  }
  const duration = Math.max(0, Math.floor(Number(durationSeconds) || 0));
  const bothJoined = data.bothJoinedAt != null || duration > 0;
  if (duration >= TRIAL_QUALIFICATION_SECONDS || (bothJoined && !technicalFailure)) {
    transaction.set(trialRef, {
      trialCallStatus: "consumed",
      qualifiedAt: admin.firestore.Timestamp.fromMillis(nowMillis),
      lastEndedAt: admin.firestore.Timestamp.fromMillis(nowMillis),
      terminationReason: duration >= TRIAL_QUALIFICATION_SECONDS ?
        "qualified" : "user_ended",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return {updated: true, status: "consumed"};
  }

  const retryCount = Number(data.technicalRetryCount) || 0;
  const deadline = timestampToMillis(data.trialCallWindowExpiresAt);
  const canRetry = technicalFailure &&
    deadline != null && deadline > nowMillis &&
    retryCount < TRIAL_MAX_TECHNICAL_RETRIES;
  if (canRetry) {
    const retryAt = nowMillis + TRIAL_RETRY_COOLDOWN_MS;
    transaction.set(trialRef, {
      trialCallStatus: "eligible",
      technicalRetryCount: retryCount + 1,
      retryNotBeforeAt: admin.firestore.Timestamp.fromMillis(retryAt),
      lastEndedAt: admin.firestore.Timestamp.fromMillis(nowMillis),
      terminationReason: "technical_failure",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return {updated: true, status: "eligible", retryNotBeforeAt: retryAt};
  }

  transaction.set(trialRef, {
    trialCallStatus: "expired",
    lastEndedAt: admin.firestore.Timestamp.fromMillis(nowMillis),
    terminationReason: technicalFailure ? "technical_failure" : "expired",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return {updated: true, status: "expired"};
}

module.exports = {
  PAID_PERIOD_TYPES,
  PREMIUM_PRODUCT_IDS,
  TRIAL_MAX_ATTEMPTS,
  TRIAL_MAX_TECHNICAL_RETRIES,
  TRIAL_PRODUCT_ID,
  TRIAL_QUALIFICATION_SECONDS,
  TRIAL_RESERVATION_LEASE_MS,
  TRIAL_RETRY_COOLDOWN_MS,
  TRIAL_WINDOW_MS,
  buildTrialCallAccessDecision,
  hasActiveSubscription,
  isPaidPremium,
  isTrialSubscription,
  normalizeString,
  reserveTrialCallInTransaction,
  reconcileTrialCallInTransaction,
  subscriptionProductId,
  subscriptionPeriodType,
  timestampToMillis,
  trialAccessRef,
};
