const assert = require("node:assert/strict");
const test = require("node:test");

const {
  eventAllowlistFailure,
  buildInitialTrialPayload,
  parseEvent,
  shouldApplySubscriptionEvent,
  shouldInitializeTrial,
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
      eventAllowlistFailure(parsedEvent({
        product_id: "expatlio_trial_1_Month",
      }), {
        REVENUECAT_APP_ID: "app87d4dc887a",
      }),
      null,
  );
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

test("initializes the 30-minute call window only for the trial SKU", () => {
  const startedAt = Date.parse("2026-08-29T12:00:00.000Z");
  const event = parsedEvent({
    product_id: "expatlio_trial_1_Month",
    period_type: "TRIAL",
    purchased_at_ms: startedAt,
    original_transaction_id: "original-1",
  });
  assert.equal(shouldInitializeTrial(event), true);
  const payload = buildInitialTrialPayload(event, startedAt + 1000);
  assert.equal(payload.trialCallStatus, "eligible");
  assert.equal(
      payload.trialCallWindowExpiresAt.toMillis(),
      startedAt + 30 * 60 * 1000,
  );
  assert.equal(shouldInitializeTrial(parsedEvent()), false);
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

test("ignores provider events older than the subscription mirror", () => {
  const current = {
    lastProviderEventTimestampMs: 2_000,
    lastProviderEventId: "event_2",
  };
  assert.equal(
      shouldApplySubscriptionEvent(current, parsedEvent({
        event_timestamp_ms: 1_000,
      })),
      false,
  );
  assert.equal(
      shouldApplySubscriptionEvent(current, parsedEvent({
        event_timestamp_ms: 3_000,
      })),
      true,
  );
});

test("uses event id as a deterministic tie-breaker", () => {
  const current = {
    lastProviderEventTimestampMs: 2_000,
    lastProviderEventId: "event_b",
  };
  assert.equal(
      shouldApplySubscriptionEvent(current, parsedEvent({
        id: "event_a",
        event_timestamp_ms: 2_000,
      })),
      false,
  );
  assert.equal(
      shouldApplySubscriptionEvent(current, parsedEvent({
        id: "event_c",
        event_timestamp_ms: 2_000,
      })),
      true,
  );
});
