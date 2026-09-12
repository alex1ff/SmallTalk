const test = require("node:test");
const assert = require("node:assert/strict");
const {
  TRIAL_QUALIFICATION_SECONDS,
  buildTrialCallAccessDecision,
  isPaidPremium,
  isTrialSubscription,
  markSessionTrialCallContextsConnectedInTransaction,
  reconcileTrialCallInTransaction,
  reserveTrialCallInTransaction,
} = require("./trial_access");

const now = Date.parse("2026-08-29T12:00:00.000Z");
const timestamp = (millis) => ({toMillis: () => millis});
const trialSubscription = (periodType = "TRIAL") => ({
  productId: "expatlio_trial_1_Month",
  periodType,
  expiresAt: timestamp(now + 3 * 24 * 60 * 60 * 1000),
});

function snap(data) {
  return {exists: true, data: () => data};
}

function fakeTransaction() {
  const writes = [];
  return {
    writes,
    set(ref, data, options) {
      writes.push({ref, data, options});
    },
  };
}

test("distinguishes restricted trial from paid Premium", () => {
  const trialUser = {subscription: trialSubscription()};
  const paidUser = {subscription: trialSubscription("NORMAL")};
  assert.equal(isTrialSubscription(trialUser, now), true);
  assert.equal(isPaidPremium(trialUser, now), false);
  assert.equal(isPaidPremium(paidUser, now), true);
});

test("trial access requires eligible state inside the 30-minute window", () => {
  const decision = buildTrialCallAccessDecision({
    userData: {subscription: trialSubscription()},
    trialData: {
      trialCallStatus: "eligible",
      trialCallWindowExpiresAt: timestamp(now + 30 * 60 * 1000),
    },
    nowMillis: now,
  });
  assert.equal(decision.allowed, true);
  assert.equal(decision.mode, "trial");

  const expired = buildTrialCallAccessDecision({
    userData: {subscription: trialSubscription()},
    trialData: {
      trialCallStatus: "eligible",
      trialCallWindowExpiresAt: timestamp(now),
    },
    nowMillis: now,
  });
  assert.equal(expired.allowed, false);
  assert.equal(expired.reason, "trial_window_expired");
});

test("active gift minutes grant call access without a subscription", () => {
  const decision = buildTrialCallAccessDecision({
    userData: {
      giftMinutes: {
        minutes: 10,
        expiresAt: timestamp(now + 60 * 60 * 1000),
      },
    },
    nowMillis: now,
  });
  assert.equal(decision.allowed, true);
  assert.equal(decision.mode, "gift");
});

test("reservation is atomic and idempotently uses the session id", () => {
  const transaction = fakeTransaction();
  const ref = {path: "users/u/trialAccess/current"};
  const result = reserveTrialCallInTransaction({
    transaction,
    trialRef: ref,
    trialSnap: snap({
      trialCallStatus: "eligible",
      trialCallWindowExpiresAt: timestamp(now + 30 * 60 * 1000),
      attemptCount: 0,
      technicalRetryCount: 0,
    }),
    requestId: "session-1",
    nowMillis: now,
  });
  assert.equal(result.allowed, true);
  assert.equal(result.trialCallId, "session-1");
  assert.equal(transaction.writes[0].data.attemptCount, 1);
  assert.equal(transaction.writes[0].data.trialCallStatus, "inProgress");
});

test("120-second call consumes trial and technical failure permits cooldown", () => {
  const ref = {path: "users/u/trialAccess/current"};
  const consumedTx = fakeTransaction();
  const consumed = reconcileTrialCallInTransaction({
    transaction: consumedTx,
    trialRef: ref,
    trialSnap: snap({
      trialCallStatus: "inProgress",
      trialCallId: "session-1",
      bothJoinedAt: timestamp(now - 120000),
    }),
    trialCallId: "session-1",
    durationSeconds: TRIAL_QUALIFICATION_SECONDS,
    nowMillis: now,
  });
  assert.equal(consumed.status, "consumed");

  const retryTx = fakeTransaction();
  const retry = reconcileTrialCallInTransaction({
    transaction: retryTx,
    trialRef: ref,
    trialSnap: snap({
      trialCallStatus: "inProgress",
      trialCallId: "session-2",
      technicalRetryCount: 0,
      trialCallWindowExpiresAt: timestamp(now + 60000),
    }),
    trialCallId: "session-2",
    durationSeconds: 0,
    technicalFailure: true,
    nowMillis: now,
  });
  assert.equal(retry.status, "eligible");
  assert.equal(retryTx.writes[0].data.technicalRetryCount, 1);
  assert.ok(retry.retryNotBeforeAt > now);
});

test("expired reservation leases become a bounded technical retry", () => {
  const trial = {
    trialCallStatus: "inProgress",
    trialCallId: "stale-session",
    reservationLeaseExpiresAt: timestamp(now - 1),
    trialCallWindowExpiresAt: timestamp(now + 20 * 60 * 1000),
    attemptCount: 1,
    technicalRetryCount: 0,
  };
  assert.equal(
      buildTrialCallAccessDecision({
        userData: {subscription: trialSubscription()},
        trialData: trial,
        nowMillis: now,
      }).allowed,
      true,
  );
  const writes = [];
  const result = reserveTrialCallInTransaction({
    transaction: {set: (...args) => writes.push(args)},
    trialRef: {},
    trialSnap: {exists: true, data: () => trial},
    requestId: "next-session",
    nowMillis: now,
  });
  assert.equal(result.allowed, false);
  assert.equal(result.reason, "retry_cooldown");
  assert.equal(writes.length, 1);
  assert.equal(writes[0][1].technicalRetryCount, 1);
});

test("connection evidence ignores stale call ids and preserves first marker", () => {
  const transaction = fakeTransaction();
  const firstMarker = timestamp(now - 1000);
  const result = markSessionTrialCallContextsConnectedInTransaction({
    transaction,
    contexts: [
      {
        ref: {path: "users/a/trialAccess/current"},
        trialCallId: "current-session",
        snap: snap({
          trialCallStatus: "inProgress",
          trialCallId: "newer-session",
        }),
      },
      {
        ref: {path: "users/b/trialAccess/current"},
        trialCallId: "current-session",
        snap: snap({
          trialCallStatus: "inProgress",
          trialCallId: "current-session",
          bothJoinedAt: firstMarker,
        }),
      },
    ],
    serverTimestamp: timestamp(now),
  });

  assert.deepEqual(result, {participantCount: 2, updated: 0});
  assert.equal(transaction.writes.length, 0);
});
