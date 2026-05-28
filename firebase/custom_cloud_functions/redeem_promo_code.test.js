const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __private__: {
    normalizeCode,
    isPromoActive,
    isPromoExhausted,
    resolvePromoGift,
  },
} = require("./redeem_promo_code");

function tsField(iso) {
  return {toMillis: () => Date.parse(iso)};
}

test("normalizeCode trims whitespace and rejects non-strings", () => {
  assert.equal(normalizeCode("  WELCOME10  "), "WELCOME10");
  assert.equal(normalizeCode("hello"), "hello");
  assert.equal(normalizeCode(""), "");
  assert.equal(normalizeCode(null), "");
  assert.equal(normalizeCode(undefined), "");
  assert.equal(normalizeCode(42), "");
});

test("isPromoActive accepts active codes without expiry", () => {
  assert.equal(isPromoActive({isActive: true}), true);
  assert.equal(isPromoActive({}), true); // isActive defaults to "not false"
});

test("isPromoActive rejects when isActive is explicitly false", () => {
  assert.equal(isPromoActive({isActive: false}), false);
});

test("isPromoActive checks expiredDate against the clock", () => {
  const now = Date.parse("2026-05-12T12:00:00Z");
  assert.equal(
      isPromoActive(
          {isActive: true, expiredDate: tsField("2026-05-20T00:00:00Z")},
          now,
      ),
      true,
  );
  assert.equal(
      isPromoActive(
          {isActive: true, expiredDate: tsField("2026-04-01T00:00:00Z")},
          now,
      ),
      false,
  );
});

test("isPromoActive rejects null / undefined", () => {
  assert.equal(isPromoActive(null), false);
  assert.equal(isPromoActive(undefined), false);
});

test("isPromoExhausted respects usageLimit / usageCount", () => {
  assert.equal(isPromoExhausted({usageLimit: 10, usageCount: 5}), false);
  assert.equal(isPromoExhausted({usageLimit: 10, usageCount: 10}), true);
  assert.equal(isPromoExhausted({usageLimit: 10, usageCount: 11}), true);
});

test("isPromoExhausted treats missing limit as unlimited", () => {
  assert.equal(isPromoExhausted({usageCount: 99999}), false);
  assert.equal(isPromoExhausted({}), false);
});

test("isPromoExhausted handles null promo", () => {
  assert.equal(isPromoExhausted(null), true);
});

test("resolvePromoGift reads new-style minutesGifted + validForDays", () => {
  const gift = resolvePromoGift({minutesGifted: 30, validForDays: 3});
  assert.deepEqual(gift, {minutesGifted: 30, validForDays: 3});
});

test("resolvePromoGift falls back to legacy value_samll_talk (×10)", () => {
  const gift = resolvePromoGift({value_samll_talk: 2});
  // 2 SmallTalks = 20 minutes; validForDays defaults to 1
  assert.deepEqual(gift, {minutesGifted: 20, validForDays: 1});
});

test("resolvePromoGift defaults validForDays to 1 when missing", () => {
  const gift = resolvePromoGift({minutesGifted: 15});
  assert.deepEqual(gift, {minutesGifted: 15, validForDays: 1});
});

test("resolvePromoGift returns null when there's no gift", () => {
  assert.equal(resolvePromoGift({validForDays: 7}), null);
  assert.equal(resolvePromoGift({minutesGifted: 0, validForDays: 7}), null);
  assert.equal(resolvePromoGift({}), null);
  assert.equal(resolvePromoGift(null), null);
});

test("resolvePromoGift prefers new fields over legacy", () => {
  // Both set → new fields win.
  const gift = resolvePromoGift({
    minutesGifted: 5,
    validForDays: 2,
    value_samll_talk: 99,
  });
  assert.deepEqual(gift, {minutesGifted: 5, validForDays: 2});
});
