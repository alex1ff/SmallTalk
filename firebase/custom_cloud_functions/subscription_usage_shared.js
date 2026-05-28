// Subscription usage tracking — anti-abuse module.
//
// Flat-rate subscribers are not debited per-minute by end_session.js, so we
// need an independent ceiling on call duration to keep tutor payouts
// (15 RUB/min) solvent against the subscription revenue pool.
//
// Storage: a single document per user at users/{uid}/usage/current with:
//   dayKey: "YYYY-MM-DD" (UTC)
//   dayDurationSeconds: number
//   weekKey: "YYYY-Www" (ISO week, UTC)
//   weekDurationSeconds: number
//   lastUpdatedAt: serverTimestamp
//
// Reset semantics: counters auto-reset when the stored key no longer matches
// the current day/week — we don't run a cron, the reset is computed on
// the fly inside `effectiveCounters` (read) and persisted on the next write.
//
// Limits are conservative starting values: 60 min/day, 8 h/week. Tune via
// the constants below; consider externalising to a config doc if marketing
// wants to A/B test caps.

const admin = require("firebase-admin");

// Hard ceilings. A subscriber crossing either limit cannot start new calls
// until the corresponding window resets.
const DAY_LIMIT_SECONDS = 60 * 60; // 60 minutes per day
const WEEK_LIMIT_SECONDS = 8 * 60 * 60; // 8 hours per week

// We emit a console.warn when usage crosses this fraction of a limit so
// Cloud Logging alerts can fire before users actually get blocked.
const ALERT_THRESHOLD = 0.8;

function dayKeyUtc(date = new Date()) {
  return date.toISOString().slice(0, 10);
}

// ISO 8601 week, UTC. Returns "YYYY-Www" (e.g. "2026-W19").
// Algorithm: ISO weeks are defined by the Thursday rule — find the Thursday
// of the given week, then compute the week number from January 1st of that
// Thursday's year.
function weekKeyUtc(date = new Date()) {
  const d = new Date(
      Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
  // Day of week with Monday = 1 ... Sunday = 7; shift so Thursday = 4.
  const dayOfWeek = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayOfWeek);
  const yearStart = Date.UTC(d.getUTCFullYear(), 0, 1);
  const weekNo = Math.ceil(((d.getTime() - yearStart) / 86400000 + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(weekNo).padStart(2, "0")}`;
}

// Resolve the current effective counters from a stored usage doc.
// Counters not matching the current day/week key are treated as zero.
function effectiveCounters(usageData, now = new Date()) {
  const todayKey = dayKeyUtc(now);
  const thisWeekKey = weekKeyUtc(now);
  const dayDurationSeconds =
    usageData && usageData.dayKey === todayKey ?
      Number(usageData.dayDurationSeconds) || 0 :
      0;
  const weekDurationSeconds =
    usageData && usageData.weekKey === thisWeekKey ?
      Number(usageData.weekDurationSeconds) || 0 :
      0;
  return {dayDurationSeconds, weekDurationSeconds, todayKey, thisWeekKey};
}

// Pre-call gate: returns { allowed, reason, dayDurationSeconds,
// weekDurationSeconds }. `reason` is one of "daily_limit_reached",
// "weekly_limit_reached", or null when allowed.
function checkUsageLimits(usageData, now = new Date()) {
  const {dayDurationSeconds, weekDurationSeconds} = effectiveCounters(
      usageData,
      now,
  );
  if (dayDurationSeconds >= DAY_LIMIT_SECONDS) {
    return {
      allowed: false,
      reason: "daily_limit_reached",
      dayDurationSeconds,
      weekDurationSeconds,
    };
  }
  if (weekDurationSeconds >= WEEK_LIMIT_SECONDS) {
    return {
      allowed: false,
      reason: "weekly_limit_reached",
      dayDurationSeconds,
      weekDurationSeconds,
    };
  }
  return {
    allowed: true,
    reason: null,
    dayDurationSeconds,
    weekDurationSeconds,
  };
}

function usageDocRef(db, userId) {
  return db
      .collection("users")
      .doc(userId)
      .collection("usage")
      .doc("current");
}

async function readUsage(db, userId) {
  const snap = await usageDocRef(db, userId).get();
  return snap.exists ? snap.data() : null;
}

// Atomic increment of the daily and weekly counters inside a Firestore
// transaction. Auto-resets stale (rolled-over) counters to zero before
// adding `durationSeconds`. Emits structured warnings when the user
// crosses the 80% alert threshold for either window.
async function incrementUsageInTransaction(
    transaction,
    db,
    userId,
    durationSeconds,
    now = new Date(),
) {
  if (!durationSeconds || durationSeconds <= 0 || !userId) {
    return;
  }
  const ref = usageDocRef(db, userId);
  const snap = await transaction.get(ref);
  const data = snap.exists ? snap.data() : null;
  const {
    dayDurationSeconds,
    weekDurationSeconds,
    todayKey,
    thisWeekKey,
  } = effectiveCounters(data, now);
  const newDayDuration = dayDurationSeconds + durationSeconds;
  const newWeekDuration = weekDurationSeconds + durationSeconds;

  transaction.set(ref, {
    dayKey: todayKey,
    dayDurationSeconds: newDayDuration,
    weekKey: thisWeekKey,
    weekDurationSeconds: newWeekDuration,
    lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const dayThreshold = DAY_LIMIT_SECONDS * ALERT_THRESHOLD;
  if (newDayDuration >= dayThreshold && dayDurationSeconds < dayThreshold) {
    console.warn("⚠️ subscription_usage approaching daily limit", {
      userId,
      dayDurationSeconds: newDayDuration,
      limit: DAY_LIMIT_SECONDS,
    });
  }
  const weekThreshold = WEEK_LIMIT_SECONDS * ALERT_THRESHOLD;
  if (newWeekDuration >= weekThreshold && weekDurationSeconds < weekThreshold) {
    console.warn("⚠️ subscription_usage approaching weekly limit", {
      userId,
      weekDurationSeconds: newWeekDuration,
      limit: WEEK_LIMIT_SECONDS,
    });
  }
}

// True if the user has a subscription whose expiresAt is in the future.
// Mirrors end_session.js#hasActiveSubscription so create_video_session can
// gate without importing that file. Keep the two implementations in sync.
function hasActiveSubscription(userData, nowMillis) {
  const expiresAt = userData && userData.subscription ?
    userData.subscription.expiresAt :
    null;
  if (!expiresAt) {
    return false;
  }
  let millis;
  if (typeof expiresAt.toMillis === "function") {
    millis = expiresAt.toMillis();
  } else if (expiresAt instanceof Date) {
    millis = expiresAt.getTime();
  } else {
    millis = Number(expiresAt);
  }
  return Number.isFinite(millis) && millis > nowMillis;
}

module.exports = {
  DAY_LIMIT_SECONDS,
  WEEK_LIMIT_SECONDS,
  ALERT_THRESHOLD,
  dayKeyUtc,
  weekKeyUtc,
  effectiveCounters,
  checkUsageLimits,
  hasActiveSubscription,
  readUsage,
  incrementUsageInTransaction,
  usageDocRef,
};
