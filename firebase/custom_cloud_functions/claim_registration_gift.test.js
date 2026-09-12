const test = require("node:test");
const assert = require("node:assert/strict");
const {
  __private__: {
    REGISTRATION_GIFT_MAX_ACCOUNT_AGE_MS,
    buildClaimRegistrationGiftDecision,
    hasMapValue,
    isWithinRegistrationGiftWindow,
    readAuthCreatedAtMillis,
  },
} = require("./claim_registration_gift");

const fixedNow = new Date("2026-05-26T10:00:00.000Z");

test("hasMapValue accepts map-like values only", () => {
  assert.equal(hasMapValue({minutes: 10}), true);
  assert.equal(hasMapValue(null), false);
  assert.equal(hasMapValue(["bad"]), false);
  assert.equal(hasMapValue("bad"), false);
});

test("registration gift window uses trusted auth creation time", () => {
  assert.equal(
    readAuthCreatedAtMillis({
      metadata: {creationTime: "2026-05-26T09:00:00.000Z"},
    }),
    Date.parse("2026-05-26T09:00:00.000Z"),
  );
  assert.equal(
    isWithinRegistrationGiftWindow({
      authCreatedAtMillis: fixedNow.getTime() - 1000,
      nowMillis: fixedNow.getTime(),
    }),
    true,
  );
  assert.equal(
    isWithinRegistrationGiftWindow({
      authCreatedAtMillis:
        fixedNow.getTime() - REGISTRATION_GIFT_MAX_ACCOUNT_AGE_MS - 1,
      nowMillis: fixedNow.getTime(),
    }),
    false,
  );
});

test("registration gift requires an existing non-teacher user document", () => {
  const missing = buildClaimRegistrationGiftDecision({
    userExists: false,
    userData: {},
    now: fixedNow,
  });
  const teacher = buildClaimRegistrationGiftDecision({
    userExists: true,
    userData: {role: "native_speaker"},
    now: fixedNow,
  });

  assert.equal(missing.ok, false);
  assert.equal(missing.code, "failed-precondition");
  assert.equal(teacher.ok, false);
  assert.equal(teacher.code, "failed-precondition");
});

test("registration gift grants a deterministic 24 hour student trial and role", () => {
  const decision = buildClaimRegistrationGiftDecision({
    userExists: true,
    userData: {},
    now: fixedNow,
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.claimStatus, "granted");
  assert.equal(decision.giftPayload.minutes, 10);
  assert.equal(decision.giftPayload.source, "registration");
  assert.equal(decision.giftPayload.totalGranted, 10);
  assert.equal(decision.userUpdate.role, "student");
  assert.equal(decision.userUpdate.giftMinutes, decision.giftPayload);
  assert.equal(
    decision.giftPayload.expiresAt.toMillis(),
    Date.parse("2026-05-27T10:00:00.000Z"),
  );
  assert.deepEqual(decision.response, {
    status: "granted",
    updated: true,
    roleUpdated: true,
    minutesGranted: 10,
    expiresAtMs: Date.parse("2026-05-27T10:00:00.000Z"),
    remainingMinutes: 10,
  });
});

test("registration gift removes stale student availability", () => {
  const decision = buildClaimRegistrationGiftDecision({
    userExists: true,
    userData: {
      availabilityToday: {
        enabled: true,
        intervals: [],
      },
    },
    now: fixedNow,
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.userUpdate.role, "student");
  assert.equal(typeof decision.userUpdate.availabilityToday, "object");
});

test("registration gift rejects old accounts even with student role", () => {
  const decision = buildClaimRegistrationGiftDecision({
    userExists: true,
    userData: {role: "student"},
    now: fixedNow,
    authCreatedAtMillis:
      fixedNow.getTime() - REGISTRATION_GIFT_MAX_ACCOUNT_AGE_MS - 1,
  });

  assert.equal(decision.ok, false);
  assert.equal(decision.code, "failed-precondition");
});

test("registration gift is idempotent for prior claims or gifts", () => {
  const claimed = buildClaimRegistrationGiftDecision({
    userExists: true,
    claimExists: true,
    userData: {role: "student"},
    now: fixedNow,
  });
  const alreadyGifted = buildClaimRegistrationGiftDecision({
    userExists: true,
    userData: {
      role: "student",
      giftMinutes: {minutes: 3, source: "registration"},
    },
    now: fixedNow,
  });

  assert.equal(claimed.ok, true);
  assert.equal(claimed.giftPayload, null);
  assert.deepEqual(claimed.userUpdate, {});
  assert.equal(claimed.response.status, "already_claimed");
  assert.equal(alreadyGifted.ok, true);
  assert.equal(alreadyGifted.giftPayload, null);
  assert.deepEqual(alreadyGifted.userUpdate, {});
  assert.equal(alreadyGifted.response.status, "already_has_gift");
});
