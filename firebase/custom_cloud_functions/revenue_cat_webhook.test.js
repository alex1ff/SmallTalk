const assert = require("node:assert/strict");
const test = require("node:test");

const {
  eventAllowlistFailure,
  parseEvent,
  transactionDocumentIdForEvent,
} = require("./revenue_cat_webhook").__private__;

function parsedEvent(overrides = {}) {
  return parseEvent({
    event: {
      type: "INITIAL_PURCHASE",
      id: "event_1",
      app_user_id: "firebase_uid",
      app_id: "app87d4dc887a",
      product_id: "expatlio_1_Month",
      entitlement_ids: ["Expatlio Pro"],
      ...overrides,
    },
  });
}

test("accepts only the Expatlio product and entitlement allowlist", () => {
  assert.equal(
      eventAllowlistFailure(parsedEvent(), {
        REVENUECAT_APP_ID: "app87d4dc887a",
      }),
      null,
  );
  assert.equal(
      eventAllowlistFailure(parsedEvent({product_id: "other"}), {
        REVENUECAT_APP_ID: "app87d4dc887a",
      }),
      "unexpected_product",
  );
  assert.equal(
      eventAllowlistFailure(parsedEvent({entitlement_ids: ["other"]}), {
        REVENUECAT_APP_ID: "app87d4dc887a",
      }),
      "unexpected_entitlement",
  );
  assert.equal(
      eventAllowlistFailure(parsedEvent({
        type: "EXPIRATION",
        entitlement_ids: ["other"],
      }), {
        REVENUECAT_APP_ID: "app87d4dc887a",
      }),
      "unexpected_entitlement",
  );
  assert.equal(
      eventAllowlistFailure(parsedEvent({app_id: "other_app"}), {
        REVENUECAT_APP_ID: "app87d4dc887a",
      }),
      "unexpected_revenuecat_app",
  );
});

test("fails closed when the RevenueCat app allowlist is missing", () => {
  assert.equal(
      eventAllowlistFailure(parsedEvent(), {}),
      "missing_revenuecat_app_allowlist",
  );
});

test("rejects transfer projection instead of writing an unknown subscription", () => {
  assert.equal(
      eventAllowlistFailure(parsedEvent({
        type: "TRANSFER",
        product_id: null,
        entitlement_ids: [],
      })),
      "unsupported_transfer",
  );
});

test("keeps RevenueCat TEST events available for integration checks", () => {
  assert.equal(
      eventAllowlistFailure(parsedEvent({
        type: "TEST",
        product_id: null,
        entitlement_ids: [],
      })),
      null,
  );
});

test("uses a deterministic Firestore-safe transaction id per event", () => {
  const first = transactionDocumentIdForEvent("event/with/slash");
  const duplicate = transactionDocumentIdForEvent("event/with/slash");
  const other = transactionDocumentIdForEvent("other-event");

  assert.equal(first, duplicate);
  assert.notEqual(first, other);
  assert.match(first, /^revenuecat_[a-f0-9]{64}$/);
  assert.doesNotMatch(first, /\//);
});
