// Server-owned trial call access policy.
//
// A RevenueCat introductory subscription is active while its period type is
// TRIAL, but that must not be treated as full Premium. Gift minutes are a
// separate, server-owned call-access mode. This module keeps the distinction
// in one place for every call entry point.

const crypto = require("node:crypto");
const admin = require("firebase-admin");
const {hasUsableGiftMinutes} = require("./gift_minutes_shared");

const TRIAL_PRODUCT_ID = "expatlio_trial_1_Month";
const PROMOTIONAL_PRODUCT_ID = "revenuecat_promotional";
const PREMIUM_PRODUCT_IDS = new Set([
  "expatlio_1_Month",
  "expatlio_3_Month",
  TRIAL_PRODUCT_ID,
  PROMOTIONAL_PRODUCT_ID,
]);
const PAID_PERIOD_TYPES = new Set(["NORMAL", "PROMOTIONAL"]);
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

  if (hasUsableGiftMinutes(userData, nowMillis)) {
    return {
      allowed: true,
      mode: "gift",
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

function buildTrialCallReservationPlan({
  trialData = {},
  requestId,
  nowMillis = Date.now(),
} = {}) {
  const data = trialData && typeof trialData === "object" ? trialData : {};
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
      return {
        allowed: false,
        reason: "trial_call_consumed",
        writeData: {
          trialCallStatus: "expired",
          terminationReason: "technical_failure",
          lastEndedAt: admin.firestore.Timestamp.fromMillis(nowMillis),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      };
    }
    return {
      allowed: false,
      reason: "retry_cooldown",
      retryAfterMillis: nowMillis + TRIAL_RETRY_COOLDOWN_MS,
      writeData: {
        trialCallStatus: "eligible",
        technicalRetryCount,
        trialCallId: null,
        reservationLeaseExpiresAt: null,
        retryNotBeforeAt: admin.firestore.Timestamp.fromMillis(
            nowMillis + TRIAL_RETRY_COOLDOWN_MS,
        ),
        terminationReason: "technical_failure",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
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
    return {
      allowed: false,
      reason: "trial_call_consumed",
      writeData: {
        trialCallStatus: "expired",
        terminationReason: "expired",
        lastEndedAt: admin.firestore.Timestamp.fromMillis(nowMillis),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    };
  }

  const trialCallId = normalizeString(requestId) || `trial_${crypto.randomUUID()}`;
  return {
    allowed: true,
    trialCallId,
    writeData: {
      trialCallStatus: "inProgress",
      trialCallId,
      attemptCount: attemptCount + 1,
      reservationLeaseExpiresAt: admin.firestore.Timestamp.fromMillis(
          nowMillis + TRIAL_RESERVATION_LEASE_MS),
      lastLifecycleAt: admin.firestore.Timestamp.fromMillis(nowMillis),
      retryNotBeforeAt: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  };
}

function applyTrialCallReservationPlanInTransaction({
  transaction,
  trialRef,
  plan = {},
} = {}) {
  const {writeData, ...result} = plan;
  if (writeData) {
    transaction.set(trialRef, writeData, {merge: true});
  }
  return result;
}

function reserveTrialCallInTransaction({
  transaction,
  trialRef,
  trialSnap,
  requestId,
  nowMillis = Date.now(),
} = {}) {
  const trialData = trialSnap && trialSnap.exists ? trialSnap.data() || {} : {};
  const plan = buildTrialCallReservationPlan({
    trialData,
    requestId,
    nowMillis,
  });
  return applyTrialCallReservationPlanInTransaction({
    transaction,
    trialRef,
    plan,
  });
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

function sessionTrialCallIds(sessionData = {}, sessionId = "") {
  const stored = sessionData.trialCallIdsByUserId;
  if (stored && typeof stored === "object" && !Array.isArray(stored)) {
    return Object.fromEntries(
        Object.entries(stored).filter(([uid, trialCallId]) =>
          normalizeString(uid) && !uid.includes("/") &&
          normalizeString(trialCallId),
        ),
    );
  }
  const studentId = normalizeString(sessionData.studentId);
  if (sessionData.accessMode === "trial" && studentId &&
      !studentId.includes("/")) {
    return {
      [studentId]: normalizeString(sessionData.trialCallId) || sessionId,
    };
  }
  return {};
}

async function reconcileSessionTrialCallsInTransaction({
  db,
  transaction,
  sessionId,
  sessionData = {},
  durationSeconds = 0,
  technicalFailure = false,
  nowMillis = Date.now(),
} = {}) {
  const entries = Object.entries(sessionTrialCallIds(sessionData, sessionId));
  const contexts = await Promise.all(entries.map(async ([uid, trialCallId]) => {
    const ref = trialAccessRef(db, uid);
    return {ref, trialCallId, snap: await transaction.get(ref)};
  }));
  return contexts.map((context) => reconcileTrialCallInTransaction({
    transaction,
    trialRef: context.ref,
    trialSnap: context.snap,
    trialCallId: context.trialCallId,
    durationSeconds,
    technicalFailure,
    nowMillis,
  }));
}

async function readSessionTrialCallContextsInTransaction({
  db,
  transaction,
  sessionId,
  sessionData = {},
} = {}) {
  const entries = Object.entries(sessionTrialCallIds(sessionData, sessionId));
  return Promise.all(entries.map(async ([uid, trialCallId]) => {
    const ref = trialAccessRef(db, uid);
    return {ref, trialCallId, snap: await transaction.get(ref)};
  }));
}

/**
 * Records trusted two-party connection evidence for every trial participant.
 * Callers must read contexts before queuing any other transaction writes.
 */
function markSessionTrialCallContextsConnectedInTransaction({
  transaction,
  contexts = [],
  serverTimestamp = admin.firestore.FieldValue.serverTimestamp(),
} = {}) {
  let updated = 0;
  for (const context of contexts) {
    const data = context.snap?.exists ? context.snap.data() || {} : {};
    if (normalizeString(data.trialCallId) !==
          normalizeString(context.trialCallId) ||
        data.bothJoinedAt != null) {
      continue;
    }
    transaction.set(context.ref, {
      bothJoinedAt: serverTimestamp,
      lastLifecycleAt: serverTimestamp,
      updatedAt: serverTimestamp,
    }, {merge: true});
    updated += 1;
  }
  return {
    participantCount: contexts.length,
    updated,
  };
}

module.exports = {
  PAID_PERIOD_TYPES,
  PREMIUM_PRODUCT_IDS,
  TRIAL_MAX_ATTEMPTS,
  TRIAL_MAX_TECHNICAL_RETRIES,
  TRIAL_PRODUCT_ID,
  PROMOTIONAL_PRODUCT_ID,
  TRIAL_QUALIFICATION_SECONDS,
  TRIAL_RESERVATION_LEASE_MS,
  TRIAL_RETRY_COOLDOWN_MS,
  TRIAL_WINDOW_MS,
  buildTrialCallAccessDecision,
  buildTrialCallReservationPlan,
  applyTrialCallReservationPlanInTransaction,
  hasActiveSubscription,
  isPaidPremium,
  isTrialSubscription,
  normalizeString,
  reserveTrialCallInTransaction,
  reconcileTrialCallInTransaction,
  reconcileSessionTrialCallsInTransaction,
  readSessionTrialCallContextsInTransaction,
  markSessionTrialCallContextsConnectedInTransaction,
  sessionTrialCallIds,
  subscriptionProductId,
  subscriptionPeriodType,
  timestampToMillis,
  trialAccessRef,
};
