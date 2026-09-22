const test = require("node:test");
const assert = require("node:assert/strict");

const {
  REGISTRATION_GIFT_MINUTES,
  REGISTRATION_GIFT_TTL_HOURS,
  hasUsableGiftMinutes,
  remainingGiftMinutes,
  buildGiftDecrementPatch,
  buildRegistrationGrantPayload,
  buildPromoGrantPayload,
} = require("./gift_minutes_shared");

function tsMillis(iso) {
  return Date.parse(iso);
}

function tsField(iso) {
  return {toMillis: () => tsMillis(iso)};
}

test("constants expose the documented gift defaults", () => {
  assert.equal(REGISTRATION_GIFT_MINUTES, 10);
  assert.equal(REGISTRATION_GIFT_TTL_HOURS, 24);
});

test("hasUsableGiftMinutes is true only when minutes > 0 and not expired", () => {
  const now = tsMillis("2026-05-12T12:00:00Z");
  const fresh = {
    giftMinutes: {
      minutes: 7.5,
      expiresAt: tsField("2026-05-13T00:00:00Z"),
    },
  };
  const expired = {
    giftMinutes: {
      minutes: 7.5,
      expiresAt: tsField("2026-05-11T00:00:00Z"),
    },
  };
  const drained = {
    giftMinutes: {
      minutes: 0,
      expiresAt: tsField("2026-05-13T00:00:00Z"),
    },
  };

  assert.equal(hasUsableGiftMinutes(fresh, now), true);
  assert.equal(hasUsableGiftMinutes(expired, now), false);
  assert.equal(hasUsableGiftMinutes(drained, now), false);
  assert.equal(hasUsableGiftMinutes({}, now), false);
  assert.equal(hasUsableGiftMinutes(null, now), false);
});

test("remainingGiftMinutes treats expired bucket as zero", () => {
  const now = tsMillis("2026-05-12T12:00:00Z");
  assert.equal(
      remainingGiftMinutes(
          {
            giftMinutes: {
              minutes: 8,
              expiresAt: tsField("2026-05-13T00:00:00Z"),
            },
          },
          now,
      ),
      8,
  );
  assert.equal(
      remainingGiftMinutes(
          {
            giftMinutes: {
              minutes: 8,
              expiresAt: tsField("2026-05-11T00:00:00Z"),
            },
          },
          now,
      ),
      0,
  );
  assert.equal(remainingGiftMinutes({}, now), 0);
  assert.equal(remainingGiftMinutes(null, now), 0);
});

test("buildGiftDecrementPatch produces a clamped patch", () => {
  const user = {
    giftMinutes: {
      minutes: 5,
      expiresAt: tsField("2099-01-01T00:00:00Z"),
    },
  };
  const patch = buildGiftDecrementPatch(user, 2);
  assert.deepEqual(patch, {"giftMinutes.minutes": 3});

  // Used > remaining → clamps to 0
  const drain = buildGiftDecrementPatch(user, 100);
  assert.deepEqual(drain, {"giftMinutes.minutes": 0});

  // Zero usage → no patch
  assert.equal(buildGiftDecrementPatch(user, 0), null);
  assert.equal(buildGiftDecrementPatch(user, -1), null);

  // Empty / expired → no patch (nothing to debit)
  assert.equal(buildGiftDecrementPatch({}, 5), null);
});

test("buildRegistrationGrantPayload sets minutes=10, +24h, source=registration", () => {
  const now = new Date("2026-05-12T12:00:00Z");
  const payload = buildRegistrationGrantPayload(now);
  assert.equal(payload.minutes, 10);
  assert.equal(payload.totalGranted, 10);
  assert.equal(payload.source, "registration");
  assert.equal(payload.grantedAt.toMillis(), now.getTime());
  assert.equal(
      payload.expiresAt.toMillis(),
      now.getTime() + 24 * 60 * 60 * 1000,
  );
});

test("buildPromoGrantPayload stacks onto a live gift bucket", () => {
  const now = new Date("2026-05-12T12:00:00Z");
  const existingExpiry = new Date("2026-05-14T00:00:00Z");
  const user = {
    giftMinutes: {
      minutes: 3,
      totalGranted: 10,
      expiresAt: {toMillis: () => existingExpiry.getTime()},
    },
  };
  const payload = buildPromoGrantPayload({
    userData: user,
    minutesGifted: 5,
    validForDays: 1,
    now,
  });
  // Stacks: 3 + 5 = 8 minutes
  assert.equal(payload.minutes, 8);
  assert.equal(payload.totalGranted, 15);
  assert.equal(payload.source, "promocode");
  // Expiry = max(existing, now + 1 day). Existing 2026-05-14T00:00Z is
  // later than now+1day = 2026-05-13T12:00Z, so existing wins.
  assert.equal(payload.expiresAt.toMillis(), existingExpiry.getTime());
});

test("buildPromoGrantPayload extends expiry when promo TTL is longer", () => {
  const now = new Date("2026-05-12T12:00:00Z");
  const existingExpiry = new Date("2026-05-13T00:00:00Z"); // 12h away
  const user = {
    giftMinutes: {
      minutes: 1,
      totalGranted: 10,
      expiresAt: {toMillis: () => existingExpiry.getTime()},
    },
  };
  const payload = buildPromoGrantPayload({
    userData: user,
    minutesGifted: 20,
    validForDays: 7, // → 7 days from now
    now,
  });
  assert.equal(payload.minutes, 21);
  assert.equal(payload.totalGranted, 30);
  // Promo TTL > existing → expiry extended
  const expectedMs = now.getTime() + 7 * 24 * 60 * 60 * 1000;
  assert.equal(payload.expiresAt.toMillis(), expectedMs);
});

test("buildPromoGrantPayload replaces expired bucket", () => {
  const now = new Date("2026-05-12T12:00:00Z");
  const staleExpiry = new Date("2026-05-01T00:00:00Z"); // 11 days ago
  const user = {
    giftMinutes: {
      minutes: 99, // remnant from expired bucket
      totalGranted: 99,
      expiresAt: {toMillis: () => staleExpiry.getTime()},
    },
  };
  const payload = buildPromoGrantPayload({
    userData: user,
    minutesGifted: 15,
    validForDays: 2,
    now,
  });
  // Expired bucket discarded; only the new grant counts.
  assert.equal(payload.minutes, 15);
  assert.equal(payload.totalGranted, 15);
  assert.equal(
      payload.expiresAt.toMillis(),
      now.getTime() + 2 * 24 * 60 * 60 * 1000,
  );
});

test("buildPromoGrantPayload rejects invalid inputs", () => {
  const now = new Date("2026-05-12T12:00:00Z");
  assert.equal(
      buildPromoGrantPayload({
        userData: {},
        minutesGifted: 0,
        validForDays: 1,
        now,
      }),
      null,
  );
  assert.equal(
      buildPromoGrantPayload({
        userData: {},
        minutesGifted: 10,
        validForDays: 0,
        now,
      }),
      null,
  );
  assert.equal(
      buildPromoGrantPayload({
        userData: {},
        minutesGifted: "ten",
        validForDays: 1,
        now,
      }),
      null,
  );
});
