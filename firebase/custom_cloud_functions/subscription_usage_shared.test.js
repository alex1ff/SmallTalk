const test = require("node:test");
const assert = require("node:assert/strict");
const {
  DAY_LIMIT_SECONDS,
  WEEK_LIMIT_SECONDS,
  ALERT_THRESHOLD,
  dayKeyUtc,
  weekKeyUtc,
  effectiveCounters,
  checkUsageLimits,
  hasActiveSubscription,
} = require("./subscription_usage_shared");

test("dayKeyUtc formats date as ISO YYYY-MM-DD in UTC", () => {
  assert.equal(dayKeyUtc(new Date("2026-05-11T12:34:56Z")), "2026-05-11");
  // Crosses date boundary in UTC even though local time may differ
  assert.equal(dayKeyUtc(new Date("2026-05-11T23:59:00Z")), "2026-05-11");
  assert.equal(dayKeyUtc(new Date("2026-05-12T00:01:00Z")), "2026-05-12");
});

test("weekKeyUtc returns ISO week containing the date", () => {
  // 2026-05-11 is Monday of ISO week 19 (Thursday 2026-05-14 in week 20? Let's verify)
  // 2026-01-01 is Thursday, so week 1 starts on Mon 2025-12-29.
  // Compute: 2026-05-11 → ISO week 20.
  assert.equal(weekKeyUtc(new Date("2026-05-11T12:00:00Z")), "2026-W20");
  // Same week, different day
  assert.equal(weekKeyUtc(new Date("2026-05-17T23:59:00Z")), "2026-W20");
  // Next week
  assert.equal(weekKeyUtc(new Date("2026-05-18T00:00:00Z")), "2026-W21");
});

test("effectiveCounters returns zero when stored keys don't match today", () => {
  const now = new Date("2026-05-11T12:00:00Z");
  const stale = {
    dayKey: "2026-05-10",
    dayDurationSeconds: 1200,
    weekKey: "2026-W19",
    weekDurationSeconds: 5000,
  };
  const result = effectiveCounters(stale, now);
  assert.equal(result.dayDurationSeconds, 0);
  assert.equal(result.weekDurationSeconds, 0);
  assert.equal(result.todayKey, "2026-05-11");
  assert.equal(result.thisWeekKey, "2026-W20");
});

test("effectiveCounters carries forward when keys match", () => {
  const now = new Date("2026-05-11T12:00:00Z");
  const current = {
    dayKey: "2026-05-11",
    dayDurationSeconds: 600,
    weekKey: "2026-W20",
    weekDurationSeconds: 3000,
  };
  const result = effectiveCounters(current, now);
  assert.equal(result.dayDurationSeconds, 600);
  assert.equal(result.weekDurationSeconds, 3000);
});

test("checkUsageLimits allows below limits", () => {
  const now = new Date("2026-05-11T12:00:00Z");
  const within = {
    dayKey: "2026-05-11",
    dayDurationSeconds: DAY_LIMIT_SECONDS - 1,
    weekKey: "2026-W20",
    weekDurationSeconds: WEEK_LIMIT_SECONDS - 1,
  };
  const result = checkUsageLimits(within, now);
  assert.equal(result.allowed, true);
  assert.equal(result.reason, null);
});

test("checkUsageLimits blocks at exact daily limit", () => {
  const now = new Date("2026-05-11T12:00:00Z");
  const atLimit = {
    dayKey: "2026-05-11",
    dayDurationSeconds: DAY_LIMIT_SECONDS,
    weekKey: "2026-W20",
    weekDurationSeconds: 0,
  };
  const result = checkUsageLimits(atLimit, now);
  assert.equal(result.allowed, false);
  assert.equal(result.reason, "daily_limit_reached");
});

test("checkUsageLimits blocks at exact weekly limit", () => {
  const now = new Date("2026-05-11T12:00:00Z");
  const atLimit = {
    dayKey: "2026-05-11",
    dayDurationSeconds: 0,
    weekKey: "2026-W20",
    weekDurationSeconds: WEEK_LIMIT_SECONDS,
  };
  const result = checkUsageLimits(atLimit, now);
  assert.equal(result.allowed, false);
  assert.equal(result.reason, "weekly_limit_reached");
});

test("checkUsageLimits ignores stale counters", () => {
  const now = new Date("2026-05-11T12:00:00Z");
  // Both counters are at limit but for previous day/week → they reset to 0
  const stale = {
    dayKey: "2026-05-10",
    dayDurationSeconds: DAY_LIMIT_SECONDS,
    weekKey: "2026-W19",
    weekDurationSeconds: WEEK_LIMIT_SECONDS,
  };
  const result = checkUsageLimits(stale, now);
  assert.equal(result.allowed, true);
  assert.equal(result.dayDurationSeconds, 0);
  assert.equal(result.weekDurationSeconds, 0);
});

test("checkUsageLimits handles null / missing data", () => {
  const now = new Date("2026-05-11T12:00:00Z");
  assert.equal(checkUsageLimits(null, now).allowed, true);
  assert.equal(checkUsageLimits(undefined, now).allowed, true);
  assert.equal(checkUsageLimits({}, now).allowed, true);
});

test("hasActiveSubscription accepts Firestore Timestamp-like objects", () => {
  const now = Date.parse("2026-05-11T12:00:00Z");
  const future = { toMillis: () => Date.parse("2026-05-15T00:00:00Z") };
  const past = { toMillis: () => Date.parse("2026-05-01T00:00:00Z") };
  assert.equal(
    hasActiveSubscription({ subscription: { expiresAt: future } }, now),
    true,
  );
  assert.equal(
    hasActiveSubscription({ subscription: { expiresAt: past } }, now),
    false,
  );
  assert.equal(
    hasActiveSubscription({ subscription: {} }, now),
    false,
  );
  assert.equal(hasActiveSubscription({}, now), false);
  assert.equal(hasActiveSubscription(null, now), false);
});

test("hasActiveSubscription accepts Date and numeric millis", () => {
  const now = Date.parse("2026-05-11T12:00:00Z");
  const futureDate = new Date("2026-05-15T00:00:00Z");
  const futureMillis = Date.parse("2026-05-15T00:00:00Z");
  assert.equal(
    hasActiveSubscription({ subscription: { expiresAt: futureDate } }, now),
    true,
  );
  assert.equal(
    hasActiveSubscription({ subscription: { expiresAt: futureMillis } }, now),
    true,
  );
});

test("constants expose conservative defaults", () => {
  assert.equal(DAY_LIMIT_SECONDS, 60 * 60); // 60 min
  assert.equal(WEEK_LIMIT_SECONDS, 8 * 60 * 60); // 8h
  assert.equal(ALERT_THRESHOLD, 0.8);
});
