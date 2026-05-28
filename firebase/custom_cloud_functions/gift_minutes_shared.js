// Gift minutes — short-lived free call credits.
//
// Replaces the legacy "first minute free" mechanic. New users get 10
// minutes that expire 24h after registration. Promo codes top up the
// same bucket. Subscriptions remain the primary access mechanism;
// gift minutes only matter when there's no active subscription.
//
// Storage: users/{uid}.giftMinutes = {
//   minutes: number,          // remaining minutes
//   grantedAt: timestamp,
//   expiresAt: timestamp,     // TTL
//   source: string,           // "registration" | "promocode" | "admin_grant"
//   totalGranted: number,     // initial bucket size (audit)
// }

const admin = require("firebase-admin");

const REGISTRATION_GIFT_MINUTES = 10;
const REGISTRATION_GIFT_TTL_HOURS = 24;

function toMillis(value) {
  if (!value) return 0;
  if (typeof value?.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const num = Number(value);
  return Number.isFinite(num) ? num : 0;
}

// Returns true if the user has at least one unexpired gift minute left.
function hasUsableGiftMinutes(userData, nowMillis = Date.now()) {
  const gift = userData && userData.giftMinutes;
  if (!gift) return false;
  const minutes = Number(gift.minutes);
  if (!Number.isFinite(minutes) || minutes <= 0) return false;
  const expiresMs = toMillis(gift.expiresAt);
  return expiresMs > nowMillis;
}

// Get the remaining gift minute count, treating expired bucket as 0.
function remainingGiftMinutes(userData, nowMillis = Date.now()) {
  const gift = userData && userData.giftMinutes;
  if (!gift) return 0;
  const expiresMs = toMillis(gift.expiresAt);
  if (expiresMs <= nowMillis) return 0;
  const minutes = Number(gift.minutes);
  return Number.isFinite(minutes) && minutes > 0 ? minutes : 0;
}

// Build the dot-notation patch that decrements gift.minutes by
// `usedMinutes`, clamping at zero. Caller applies it via transaction.update.
// Returns null when nothing should be written (no bucket / already 0).
function buildGiftDecrementPatch(userData, usedMinutes) {
  const before = remainingGiftMinutes(userData);
  if (before <= 0 || !Number.isFinite(usedMinutes) || usedMinutes <= 0) {
    return null;
  }
  const after = parseFloat(Math.max(0, before - usedMinutes).toFixed(4));
  return {
    "giftMinutes.minutes": after,
  };
}

// Build a fresh registration-grant payload to write under users/{uid}.giftMinutes.
function buildRegistrationGrantPayload(now = new Date()) {
  const grantedAt = now;
  const expiresAt = new Date(
      now.getTime() + REGISTRATION_GIFT_TTL_HOURS * 60 * 60 * 1000,
  );
  return {
    minutes: REGISTRATION_GIFT_MINUTES,
    grantedAt: admin.firestore.Timestamp.fromDate(grantedAt),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    source: "registration",
    totalGranted: REGISTRATION_GIFT_MINUTES,
  };
}

// Build a promo-code grant payload. Stacks with existing gift bucket if
// it's still alive: extends expiry to max(existing, now + validForDays)
// and adds minutesGifted to the remaining balance. If bucket is expired
// or absent, replaces it.
function buildPromoGrantPayload({
  userData,
  minutesGifted,
  validForDays,
  now = new Date(),
}) {
  const minutesToAdd = Number(minutesGifted);
  const days = Number(validForDays);
  if (
    !Number.isFinite(minutesToAdd) ||
    minutesToAdd <= 0 ||
    !Number.isFinite(days) ||
    days <= 0
  ) {
    return null;
  }
  const nowMs = now.getTime();
  const candidateExpiryMs = nowMs + days * 24 * 60 * 60 * 1000;
  const existing = userData && userData.giftMinutes;
  const existingExpiryMs = existing ? toMillis(existing.expiresAt) : 0;
  const existingMinutes =
    existing && existingExpiryMs > nowMs ? Number(existing.minutes) || 0 : 0;
  const existingTotal =
    existing && existingExpiryMs > nowMs ?
      Number(existing.totalGranted) || 0 :
      0;
  const newExpiryMs = Math.max(existingExpiryMs, candidateExpiryMs);
  return {
    minutes: parseFloat((existingMinutes + minutesToAdd).toFixed(4)),
    grantedAt: admin.firestore.Timestamp.fromDate(now),
    expiresAt: admin.firestore.Timestamp.fromMillis(newExpiryMs),
    source: "promocode",
    totalGranted: parseFloat((existingTotal + minutesToAdd).toFixed(4)),
  };
}

module.exports = {
  REGISTRATION_GIFT_MINUTES,
  REGISTRATION_GIFT_TTL_HOURS,
  hasUsableGiftMinutes,
  remainingGiftMinutes,
  buildGiftDecrementPatch,
  buildRegistrationGrantPayload,
  buildPromoGrantPayload,
};
