const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildStudentCallAccessDecision,
  hasActiveCallState,
} = require("./call_access");

const fixedNowMillis = Date.parse("2026-01-01T12:00:00.000Z");

function timestampFromMillis(millis) {
  return {
    toMillis: () => millis,
    toDate: () => new Date(millis),
  };
}

function futureTimestamp(minutes = 60) {
  return timestampFromMillis(fixedNowMillis + minutes * 60 * 1000);
}

function activeGift() {
  return {
    minutes: 10,
    expiresAt: futureTimestamp(60),
  };
}

function activeSubscription({
  productId = "expatlio_1_Month",
  periodType = "NORMAL",
} = {}) {
  return {
    expiresAt: futureTimestamp(60),
    productId,
    periodType,
  };
}

function dailyLimitUsage() {
  return {
    dayKey: "2026-01-01",
    dayDurationSeconds: 60 * 60,
    weekKey: "2026-W01",
    weekDurationSeconds: 60 * 60,
  };
}

test("active call state covers flags and current sessions", () => {
  assert.equal(hasActiveCallState({isInCall: true}), true);
  assert.equal(hasActiveCallState({currentSessionId: " session-a "}), true);
  assert.equal(hasActiveCallState({isInCall: false, currentSessionId: ""}), false);
});

test("student call access matches start search entitlement semantics", () => {
  assert.deepEqual(
    buildStudentCallAccessDecision({
      userRole: "native_speaker",
      userData: {giftMinutes: activeGift()},
      nowMillis: fixedNowMillis,
    }),
    {
      allowed: false,
      code: "permission-denied",
      reason: "student_required",
      message: "Only students can start search",
    },
  );
  assert.equal(
    buildStudentCallAccessDecision({
      userRole: "student",
      userData: {giftMinutes: activeGift(), isInCall: true},
      nowMillis: fixedNowMillis,
    }).reason,
    "active_call",
  );
  assert.equal(
    buildStudentCallAccessDecision({
      userRole: "student",
      userData: {},
      nowMillis: fixedNowMillis,
    }).reason,
    "no_subscription",
  );
  assert.equal(
    buildStudentCallAccessDecision({
      userRole: "student",
      userData: {giftMinutes: activeGift()},
      nowMillis: fixedNowMillis,
    }).mode,
    "gift",
  );
  assert.equal(
    buildStudentCallAccessDecision({
      userRole: "student",
      userData: {subscription: activeSubscription()},
      usageData: dailyLimitUsage(),
      nowMillis: fixedNowMillis,
    }).allowed,
    true,
  );
  assert.equal(
    buildStudentCallAccessDecision({
      userRole: "student",
      userData: {
        subscription: activeSubscription({
          productId: "expatlio_trial_1_Month",
          periodType: "TRIAL",
        }),
      },
      trialData: {
        trialCallStatus: "eligible",
        trialCallWindowExpiresAt: futureTimestamp(30),
      },
      nowMillis: fixedNowMillis,
    }).mode,
    "trial",
  );
});
