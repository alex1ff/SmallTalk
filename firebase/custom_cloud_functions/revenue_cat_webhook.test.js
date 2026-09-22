const assert = require("node:assert/strict");
const test = require("node:test");

const {
  applyTransferEvent,
  eventAllowlistFailure,
  malformedEventReason,
  buildInitialTrialPayload,
  buildSubscriptionPayload,
  conservativeTrialAccessState,
  deriveWillRenew,
  isImmediateRefund,
  parseEvent,
  preferredTransferDestinationId,
  shouldApplySubscriptionEvent,
  shouldInitializeTrial,
  transactionDocumentIdForEvent,
  trialGrantDocumentId,
  transferSourceDocumentId,
  transferSourceIndex,
} = require("./revenue_cat_webhook").__private__;

function fakeFirestore(initialDocuments = {}) {
  const documents = new Map(Object.entries(initialDocuments));
  const documentRef = (path) => ({
    path,
    id: path.split("/").at(-1),
    collection: (name) => collectionRef(`${path}/${name}`),
  });
  const collectionRef = (path) => ({
    path,
    doc: (id) => documentRef(`${path}/${id}`),
  });
  const snapshot = (ref) => ({
    exists: documents.has(ref.path),
    data: () => documents.get(ref.path),
    ref,
  });
  const assign = (target, key, value) => {
    const parts = key.split(".");
    let current = target;
    for (const part of parts.slice(0, -1)) {
      current[part] = current[part] && typeof current[part] === "object" ?
        current[part] : {};
      current = current[part];
    }
    const leaf = parts.at(-1);
    if (value?.constructor?.name === "DeleteTransform") {
      delete current[leaf];
    } else {
      current[leaf] = value;
    }
  };
  const write = (ref, data, {merge = false} = {}) => {
    const next = merge ? {...(documents.get(ref.path) || {})} : {};
    for (const [key, value] of Object.entries(data)) assign(next, key, value);
    documents.set(ref.path, next);
  };
  const transaction = {
    get: async (ref) => snapshot(ref),
    create: (ref, data) => write(ref, data),
    set: (ref, data, options) => write(ref, data, options),
    update: (ref, data) => write(ref, data, {merge: true}),
    delete: (ref) => documents.delete(ref.path),
  };
  return {
    collection: collectionRef,
    runTransaction: async (callback) => callback(transaction),
    documents,
  };
}

function parsedEvent(overrides = {}) {
  return parseEvent({
    event: {
      type: "INITIAL_PURCHASE",
      id: "event_1",
      app_user_id: "firebase_uid",
      app_id: "app87d4dc887a",
      product_id: "expatlio_1_Month",
      entitlement_ids: ["Expatlio Pro"],
      event_timestamp_ms: 1_000,
      purchased_at_ms: 900,
      expiration_at_ms: 2_000,
      period_type: "NORMAL",
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

test("accepts promotional entitlement events when RevenueCat omits app id", () => {
  assert.equal(
      eventAllowlistFailure(parsedEvent({
        type: "NON_RENEWING_PURCHASE",
        store: "PROMOTIONAL",
        app_id: null,
      }), {}),
      null,
  );
  assert.equal(
      eventAllowlistFailure(parsedEvent({
        type: "NON_RENEWING_PURCHASE",
        store: "PROMOTIONAL",
        app_id: "wrong_app",
      }), {REVENUECAT_APP_ID: "app87d4dc887a"}),
      "unexpected_revenuecat_app",
  );
});

test("promotional entitlement becomes non-renewing Premium", () => {
  const event = parsedEvent({
    type: "NON_RENEWING_PURCHASE",
    store: "PROMOTIONAL",
    app_id: null,
    product_id: null,
    purchased_at_ms: null,
    expiration_at_ms: null,
    period_type: "PROMOTIONAL",
  });
  assert.equal(malformedEventReason(event), null);
  assert.equal(deriveWillRenew(event.type, {}, event), false);
  const subscription = buildSubscriptionPayload(event, {willRenew: false});
  assert.equal(subscription.productId, "revenuecat_promotional");
  assert.equal(subscription.periodType, "PROMOTIONAL");
  assert.equal(subscription.willRenew, false);
  assert.ok(subscription.expiresAt.toMillis() > Date.UTC(9999, 0, 1));
});

test("transfer selects the newest available source mirror", () => {
  const snap = (timestamp) => ({
    exists: true,
    data: () => ({
      subscription: {lastProviderEventTimestampMs: timestamp},
    }),
  });
  assert.equal(transferSourceIndex([
    snap(100),
    {exists: false, data: () => ({})},
    snap(300),
  ]), 2);
  assert.equal(transferSourceIndex([{exists: false, data: () => ({})}]), -1);
});

test("transfer prefers the single identified destination alias", () => {
  assert.equal(preferredTransferDestinationId([
    "$RCAnonymousID:z",
    "firebase-user",
    "$RCAnonymousID:a",
  ]), "firebase-user");
  assert.equal(preferredTransferDestinationId([
    "$RCAnonymousID:z",
    "$RCAnonymousID:a",
  ]), "$RCAnonymousID:a");
  assert.equal(preferredTransferDestinationId(["user-a", "user-b"]), null);
});

test("trial state merge never weakens consumed or expired access", () => {
  assert.equal(conservativeTrialAccessState([
    {trialCallStatus: "eligible", attemptCount: 0},
    {trialCallStatus: "consumed", attemptCount: 1},
  ]).trialCallStatus, "consumed");
  assert.equal(conservativeTrialAccessState([
    {trialCallStatus: "eligible", attemptCount: 2},
    {trialCallStatus: "expired", attemptCount: 0},
  ]).trialCallStatus, "expired");
});

test("transfer to an anonymous destination creates its server mirror", async () => {
  const destinationId = "$RCAnonymousID:destination";
  const db = fakeFirestore({
    "users/source": {
      subscription: {
        productId: "expatlio_1_Month",
        periodType: "NORMAL",
        originalTransactionId: "original-paid",
        lastProviderEventTimestampMs: 1000,
      },
    },
  });
  const parsed = parsedEvent({
    type: "TRANSFER",
    id: "transfer-anonymous-destination",
    app_user_id: null,
    product_id: null,
    entitlement_ids: [],
    event_timestamp_ms: 2000,
    transferred_from: ["source"],
    transferred_to: [destinationId],
  });
  const result = await applyTransferEvent({
    db,
    parsed,
    transactionRef: db.collection("transactions").doc("transfer-1"),
  });

  const destinationPath = "revenueCatTransferSources/" +
    transferSourceDocumentId(destinationId);
  assert.equal(result.destinationId, destinationId);
  assert.equal(
      db.documents.get(destinationPath).subscription.revenueCatUserId,
      destinationId,
  );
  assert.equal(
      db.documents.get("users/source").subscription.willRenew,
      false,
  );
  assert.equal(db.documents.has("transactions/transfer-1"), true);
});

test("anonymous trial transfer preserves call state and anti-replay owner", async () => {
  const sourceId = "$RCAnonymousID:source";
  const sourcePath = "revenueCatTransferSources/" +
    transferSourceDocumentId(sourceId);
  const grantId = trialGrantDocumentId("original-trial");
  const db = fakeFirestore({
    [sourcePath]: {
      subscription: {
        productId: "expatlio_trial_1_Month",
        periodType: "TRIAL",
        originalTransactionId: "original-trial",
        lastProviderEventTimestampMs: 1000,
      },
      trialAccess: {
        trialCallStatus: "eligible",
        trialCallWindowExpiresAt: {toMillis: () => 5000},
      },
    },
    "users/destination": {},
    [`subscriptionTrialGrants/${grantId}`]: {uid: sourceId},
  });
  const parsed = parsedEvent({
    type: "TRANSFER",
    id: "transfer-anonymous-trial",
    app_user_id: null,
    product_id: null,
    entitlement_ids: [],
    event_timestamp_ms: 2000,
    transferred_from: [sourceId],
    transferred_to: ["destination"],
  });
  const result = await applyTransferEvent({
    db,
    parsed,
    transactionRef: db.collection("transactions").doc("transfer-2"),
  });

  assert.equal(result.destinationId, "destination");
  assert.equal(
      db.documents.get("users/destination").subscription.periodType,
      "TRIAL",
  );
  assert.equal(
      db.documents.get("users/destination/trialAccess/current")
          .trialCallStatus,
      "eligible",
  );
  assert.equal(
      db.documents.get(`subscriptionTrialGrants/${grantId}`).uid,
      "destination",
  );
  assert.equal(db.documents.get(sourcePath).trialAccess, undefined);
});

test("transfer removes source trial state when destination already has one", async () => {
  const grantId = trialGrantDocumentId("source-original-trial");
  const db = fakeFirestore({
    "users/source": {subscription: {
      productId: "expatlio_trial_1_Month",
      periodType: "TRIAL",
      originalTransactionId: "source-original-trial",
      lastProviderEventTimestampMs: 1000,
    }},
    "users/source/trialAccess/current": {trialCallStatus: "eligible"},
    "users/destination": {},
    "users/destination/trialAccess/current": {trialCallStatus: "consumed"},
    [`subscriptionTrialGrants/${grantId}`]: {uid: "source"},
  });
  const parsed = parsedEvent({
    type: "TRANSFER",
    id: "transfer-existing-destination-trial",
    app_user_id: null,
    product_id: null,
    entitlement_ids: [],
    event_timestamp_ms: 2000,
    transferred_from: ["source"],
    transferred_to: ["destination"],
  });

  await applyTransferEvent({
    db,
    parsed,
    transactionRef: db.collection("transactions").doc("transfer-3"),
  });

  assert.equal(
      db.documents.has("users/source/trialAccess/current"),
      false,
  );
  assert.equal(
      db.documents.get("users/destination/trialAccess/current")
          .trialCallStatus,
      "consumed",
  );
  assert.equal(
      db.documents.get(`subscriptionTrialGrants/${grantId}`).uid,
      "destination",
  );
});

test("transfer revokes every source alias atomically", async () => {
  const db = fakeFirestore({
    "users/source-old": {subscription: {
      productId: "expatlio_1_Month",
      periodType: "NORMAL",
      lastProviderEventTimestampMs: 800,
    }},
    "users/source-new": {subscription: {
      productId: "expatlio_1_Month",
      periodType: "NORMAL",
      lastProviderEventTimestampMs: 1000,
    }},
    "users/source-old/trialAccess/current": {trialCallStatus: "consumed"},
    "users/source-new/trialAccess/current": {trialCallStatus: "eligible"},
    "users/destination": {},
  });
  const parsed = parsedEvent({
    type: "TRANSFER",
    id: "transfer-all-source-aliases",
    app_user_id: null,
    product_id: null,
    entitlement_ids: [],
    event_timestamp_ms: 2000,
    transferred_from: ["source-old", "source-new"],
    transferred_to: ["destination"],
  });

  await applyTransferEvent({
    db,
    parsed,
    transactionRef: db.collection("transactions").doc("transfer-4"),
  });

  for (const sourceId of ["source-old", "source-new"]) {
    const subscription = db.documents.get(`users/${sourceId}`).subscription;
    assert.equal(subscription.willRenew, false);
    assert.equal(subscription.expiresAt.toMillis(), 2000);
    assert.equal(subscription.lastEventType, "TRANSFER");
  }
  assert.equal(
      db.documents.has("users/source-old/trialAccess/current"),
      false,
  );
  assert.equal(
      db.documents.has("users/source-new/trialAccess/current"),
      false,
  );
  assert.equal(
      db.documents.get("users/destination/trialAccess/current")
          .trialCallStatus,
      "consumed",
  );
  assert.equal(
      db.documents.get("users/destination").subscription.revenueCatUserId,
      "destination",
  );
});

test("accepts a well-formed transfer without product fields", () => {
  assert.equal(
      eventAllowlistFailure(parsedEvent({
        type: "TRANSFER",
        app_user_id: null,
        product_id: null,
        entitlement_ids: [],
        transferred_from: ["source"],
        transferred_to: ["destination"],
      }), {REVENUECAT_APP_ID: "app87d4dc887a"}),
      null,
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

test("fails closed on missing provider timestamps and lifecycle fields", () => {
  assert.equal(
      malformedEventReason(parsedEvent({event_timestamp_ms: null})),
      "missing_event_timestamp",
  );
  assert.equal(
      malformedEventReason(parsedEvent({expiration_at_ms: null})),
      "missing_expiration_timestamp",
  );
  assert.equal(
      malformedEventReason(parsedEvent({period_type: null})),
      "missing_period_type",
  );
  assert.equal(
      malformedEventReason(parsedEvent({purchased_at_ms: null})),
      "missing_purchase_timestamp",
  );
});

test("product changes require an allowlisted destination product", () => {
  const change = parsedEvent({
    type: "PRODUCT_CHANGE",
    new_product_id: "expatlio_3_Month",
  });
  assert.equal(malformedEventReason(change), null);
  assert.equal(eventAllowlistFailure(change, {
    REVENUECAT_APP_ID: "app87d4dc887a",
  }), null);
  assert.equal(eventAllowlistFailure(parsedEvent({
    type: "PRODUCT_CHANGE",
    new_product_id: null,
  }), {REVENUECAT_APP_ID: "app87d4dc887a"}), null);
  assert.equal(eventAllowlistFailure(parsedEvent({
    type: "PRODUCT_CHANGE",
    new_product_id: "other",
  }), {REVENUECAT_APP_ID: "app87d4dc887a"}), "unexpected_new_product");
});

test("refund reversal is a handled restoring lifecycle event", () => {
  const event = parsedEvent({type: "REFUND_REVERSED"});
  assert.equal(malformedEventReason(event), null);
  assert.equal(eventAllowlistFailure(event, {
    REVENUECAT_APP_ID: "app87d4dc887a",
  }), null);
});

test("customer support cancellation is an immediate refund", () => {
  assert.equal(isImmediateRefund(parsedEvent({
    type: "CANCELLATION",
    cancel_reason: "CUSTOMER_SUPPORT",
  })), true);
  assert.equal(isImmediateRefund(parsedEvent({
    type: "CANCELLATION",
    cancel_reason: "UNSUBSCRIBE",
  })), false);
});
