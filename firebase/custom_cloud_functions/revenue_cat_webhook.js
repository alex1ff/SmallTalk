// RevenueCat webhook receiver.
//
// Receives subscription lifecycle events from RevenueCat
// (INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION, BILLING_ISSUE,
// PRODUCT_CHANGE, NON_RENEWING_PURCHASE, UNCANCELLATION, TRANSFER, TEST)
// and mirrors subscription state into `users/{uid}.subscription` plus
// writes a `transactions` record for analytics / history.
//
// Auth: shared secret from RevenueCat Dashboard → Integrations → Webhooks,
// stored in Firebase Secret Manager as REVENUECAT_WEBHOOK_SECRET.
// RevenueCat sends it in the Authorization header verbatim (no Bearer prefix
// by default — value is whatever you configure in the dashboard).
//
// Idempotency: every RevenueCat event has a unique `event.id`. Its transaction
// document uses a deterministic hash and is claimed in the same Firestore
// transaction as the subscription update.

const crypto = require("node:crypto");
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {defineSecret} = require("firebase-functions/params");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "revenue_cat_webhook"});

const revenueCatWebhookSecret = defineSecret("REVENUECAT_WEBHOOK_SECRET");
const {
  TRIAL_PRODUCT_ID,
  TRIAL_WINDOW_MS,
  trialAccessRef,
} = require("./trial_access");

// Entitlement that grants access to the product. Must match the
// Entitlement ID configured in RevenueCat dashboard.
const PRO_ENTITLEMENT_ID = "Expatlio Pro";
const PROMOTIONAL_PRODUCT_ID = "revenuecat_promotional";
const PROMOTIONAL_LIFETIME_EXPIRES_AT_MS = 253402300799999;

// Product → period (months) map. Source of truth lives in App Store Connect
// / Google Play, this map only tells us how long to extend the subscription
// when stacking purchases. Keep in sync with store products.
const PRODUCT_PERIOD_MONTHS = {
  "expatlio_1_Month": 1,
  "expatlio_3_Month": 3,
  [TRIAL_PRODUCT_ID]: 1,
  [PROMOTIONAL_PRODUCT_ID]: 0,
};
const ALLOWED_PRODUCT_IDS = new Set([
  "expatlio_1_Month",
  "expatlio_3_Month",
  TRIAL_PRODUCT_ID,
]);

// Map RevenueCat store identifiers to internal short codes used in the
// SubscriptionStruct.store field.
const STORE_MAP = {
  "APP_STORE": "app_store",
  "MAC_APP_STORE": "app_store",
  "PLAY_STORE": "play_store",
  "AMAZON": "amazon",
  "STRIPE": "stripe",
  "PROMOTIONAL": "promotional",
};

// RevenueCat event types we explicitly handle. Anything else is logged and
// acknowledged with 200 so RevenueCat doesn't retry.
const HANDLED_EVENT_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  "CANCELLATION",
  "EXPIRATION",
  "BILLING_ISSUE",
  "SUBSCRIPTION_PAUSED",
  "SUBSCRIPTION_EXTENDED",
  "REFUND_REVERSED",
  "TRANSFER",
  "TEST",
]);

// Event types that grant or extend an active entitlement.
const GRANTING_EVENT_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  "SUBSCRIPTION_EXTENDED",
  "REFUND_REVERSED",
]);

// Event types that mark the subscription as no longer auto-renewing or
// already expired. They DO NOT immediately revoke access — RevenueCat
// reports CANCELLATION when the user disables auto-renew but the paid
// period continues. We only flip willRenew until EXPIRATION fires.
const NON_GRANTING_EVENT_TYPES = new Set([
  "CANCELLATION",
  "EXPIRATION",
  "BILLING_ISSUE",
  "SUBSCRIPTION_PAUSED",
]);

// Map RevenueCat event type to internal TransactionsRecord.type value.
// Keep aligned with lib/backend/schema/enums/enums.dart TypeTransactions.
function transactionTypeForEvent(eventType) {
  switch (eventType) {
    case "INITIAL_PURCHASE":
    case "NON_RENEWING_PURCHASE":
    case "PRODUCT_CHANGE":
    case "UNCANCELLATION":
      return "subscription_purchase";
    case "RENEWAL":
    case "SUBSCRIPTION_EXTENDED":
    case "REFUND_REVERSED":
      return "subscription_renewal";
    case "CANCELLATION":
      return "subscription_cancellation";
    case "EXPIRATION":
      return "subscription_expiration";
    case "BILLING_ISSUE":
      return "subscription_billing_issue";
    case "SUBSCRIPTION_PAUSED":
      return "subscription_paused";
    case "TRANSFER":
      return "subscription_transfer";
    default:
      return "subscription_other";
  }
}

function toMillisOrNull(value) {
  const num = Number(value);
  return Number.isFinite(num) && num > 0 ? num : null;
}

function toTimestampOrNull(millis) {
  return millis == null ?
    null :
    admin.firestore.Timestamp.fromMillis(millis);
}

function safeString(value) {
  if (typeof value === "string" && value.trim().length > 0) {
    return value.trim();
  }
  return null;
}

function safeStringArray(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.map(safeString).filter(Boolean))];
}

function parseEvent(rawBody) {
  if (!rawBody || typeof rawBody !== "object") {
    return null;
  }
  const event = rawBody.event;
  if (!event || typeof event !== "object") {
    return null;
  }

  const type = safeString(event.type);
  const eventId = safeString(event.id);
  const appUserId = safeString(event.app_user_id);
  const transferredFrom = safeStringArray(event.transferred_from);
  const transferredTo = safeStringArray(event.transferred_to);
  if (!type || !eventId ||
      (type !== "TRANSFER" && !appUserId)) {
    return null;
  }

  const productId = safeString(event.product_id);
  const newProductId = safeString(event.new_product_id);
  const purchasedAtMs = toMillisOrNull(event.purchased_at_ms);
  const expirationAtMs = toMillisOrNull(event.expiration_at_ms);
  const entitlementIds = Array.isArray(event.entitlement_ids) ?
    event.entitlement_ids.filter((id) => typeof id === "string") :
    [];
  const store = safeString(event.store);
  const environment = safeString(event.environment);
  const originalTransactionId = safeString(event.original_transaction_id);
  const eventTimestampMs = toMillisOrNull(event.event_timestamp_ms);
  const revenueCatAppId = safeString(event.app_id);
  const periodType = safeString(event.period_type); // TRIAL, NORMAL, INTRO, etc.
  const cancelReason = safeString(event.cancel_reason);
  const priceInPurchasedCurrency = Number.isFinite(
    Number(event.price_in_purchased_currency),
  ) ?
    Number(event.price_in_purchased_currency) :
    null;
  const currency = safeString(event.currency);

  return {
    type,
    eventId,
    appUserId,
    productId,
    newProductId,
    purchasedAtMs,
    expirationAtMs,
    entitlementIds,
    store,
    storeShort: store && STORE_MAP[store] ? STORE_MAP[store] : "unknown",
    environment,
    originalTransactionId,
    eventTimestampMs,
    revenueCatAppId,
    periodType,
    cancelReason,
    priceInPurchasedCurrency,
    currency,
    transferredFrom,
    transferredTo,
  };
}

function configuredRevenueCatAppIds(env = process.env) {
  return new Set(
      String(env.REVENUECAT_APP_ID || "")
          .split(",")
          .map((value) => value.trim())
          .filter(Boolean),
  );
}

function isPromotionalEvent(parsed) {
  return parsed.store === "PROMOTIONAL" ||
    normalizePeriodType(parsed.periodType) === "PROMOTIONAL";
}

function mirroredProductId(parsed) {
  return isPromotionalEvent(parsed) ?
    PROMOTIONAL_PRODUCT_ID : parsed.productId;
}

function effectiveExpirationAtMs(parsed) {
  if (parsed.expirationAtMs) return parsed.expirationAtMs;
  if (isPromotionalEvent(parsed) &&
      !["CANCELLATION", "EXPIRATION"].includes(parsed.type)) {
    return PROMOTIONAL_LIFETIME_EXPIRES_AT_MS;
  }
  if (isPromotionalEvent(parsed) &&
      ["CANCELLATION", "EXPIRATION"].includes(parsed.type)) {
    return parsed.eventTimestampMs;
  }
  return null;
}

function eventAllowlistFailure(parsed, env = process.env) {
  if (parsed.type === "TEST") {
    return null;
  }

  const appIds = configuredRevenueCatAppIds(env);
  const isPromotional = isPromotionalEvent(parsed);
  if (appIds.size === 0 && !isPromotional) {
    return "missing_revenuecat_app_allowlist";
  }
  if ((!parsed.revenueCatAppId && !isPromotional) ||
      (parsed.revenueCatAppId && !appIds.has(parsed.revenueCatAppId))) {
    return "unexpected_revenuecat_app";
  }
  if (parsed.type === "TRANSFER") return null;
  if (!isPromotional &&
      (!parsed.productId || !ALLOWED_PRODUCT_IDS.has(parsed.productId))) {
    return "unexpected_product";
  }
  if (parsed.type === "PRODUCT_CHANGE" && parsed.newProductId &&
      !ALLOWED_PRODUCT_IDS.has(parsed.newProductId)) {
    return "unexpected_new_product";
  }
  if (!parsed.entitlementIds.includes(PRO_ENTITLEMENT_ID)) {
    return "unexpected_entitlement";
  }
  return null;
}

function malformedEventReason(parsed) {
  if (parsed.type === "TEST") return null;
  if (parsed.eventTimestampMs == null) return "missing_event_timestamp";
  if (parsed.type === "TRANSFER") {
    if (parsed.transferredFrom.length === 0 ||
        parsed.transferredTo.length === 0) {
      return "missing_transfer_identity";
    }
    return null;
  }
  if (!parsed.appUserId) return "missing_app_user_id";
  if (!parsed.productId && !isPromotionalEvent(parsed)) {
    return "missing_product_id";
  }
  if (!effectiveExpirationAtMs(parsed)) return "missing_expiration_timestamp";
  if (!parsed.periodType) return "missing_period_type";
  if (shouldWriteSubscriptionFull(parsed.type) &&
      !parsed.purchasedAtMs && !isPromotionalEvent(parsed)) {
    return "missing_purchase_timestamp";
  }
  return null;
}

function transactionDocumentIdForEvent(eventId) {
  return `revenuecat_${crypto
      .createHash("sha256")
      .update(String(eventId), "utf8")
      .digest("hex")}`;
}

// Build the SubscriptionStruct payload that mirrors RevenueCat state.
function buildSubscriptionPayload(parsed, {willRenew}) {
  const productId = mirroredProductId(parsed) || "unknown";
  const periodMonths = PRODUCT_PERIOD_MONTHS[productId] || 0;
  return {
    entitlementId: PRO_ENTITLEMENT_ID,
    productId,
    periodMonths,
    providerProductId: parsed.productId || null,
    startedAt: toTimestampOrNull(
        parsed.purchasedAtMs || parsed.eventTimestampMs,
    ),
    expiresAt: toTimestampOrNull(effectiveExpirationAtMs(parsed)),
    willRenew,
    store: parsed.storeShort,
    revenueCatUserId: parsed.appUserId,
    originalTransactionId: parsed.originalTransactionId,
    environment: parsed.environment,
    newProductId: parsed.newProductId || null,
    expirationAtMs: parsed.expirationAtMs,
    periodType: isPromotionalEvent(parsed) ?
      "PROMOTIONAL" : parsed.periodType,
    lastProviderEventTimestampMs: parsed.eventTimestampMs,
    lastProviderEventId: parsed.eventId,
    lastEventType: parsed.type,
    lastEventAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function shouldInitializeTrial(parsed) {
  return parsed.type === "INITIAL_PURCHASE" &&
    parsed.productId === TRIAL_PRODUCT_ID &&
    normalizePeriodType(parsed.periodType) === "TRIAL";
}

function normalizePeriodType(value) {
  return safeString(value)?.toUpperCase() || "";
}

function trialGrantDocumentId(originalTransactionId) {
  return `apple_${crypto
      .createHash("sha256")
      .update(String(originalTransactionId), "utf8")
      .digest("hex")}`;
}

function transferSourceDocumentId(appUserId) {
  return `rc_${crypto.createHash("sha256")
      .update(String(appUserId), "utf8").digest("hex")}`;
}

function isAnonymousRevenueCatUserId(appUserId) {
  return safeString(appUserId)?.startsWith("$RCAnonymousID:") === true;
}

function transferSourceRef(db, appUserId) {
  if (isAnonymousRevenueCatUserId(appUserId)) {
    return db.collection("revenueCatTransferSources")
        .doc(transferSourceDocumentId(appUserId));
  }
  return db.collection("users").doc(appUserId);
}

function buildInitialTrialPayload(parsed, nowMillis = Date.now()) {
  const startedAtMillis = parsed.purchasedAtMs;
  if (!startedAtMillis) return null;
  const expiresAtMillis = startedAtMillis + TRIAL_WINDOW_MS;
  const expired = expiresAtMillis <= nowMillis;
  return {
    trialStartedAt: toTimestampOrNull(startedAtMillis),
    trialCallWindowExpiresAt: toTimestampOrNull(expiresAtMillis),
    trialCallStatus: expired ? "expired" : "eligible",
    trialCallId: null,
    attemptCount: 0,
    technicalRetryCount: 0,
    retryNotBeforeAt: null,
    activeConnectedSeconds: 0,
    disconnectCount: 0,
    terminationReason: expired ? "expired" : null,
    originalTransactionId: parsed.originalTransactionId,
    sourceEventId: parsed.eventId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function buildTransactionPayload(parsed, userRef) {
  const productId = mirroredProductId(parsed);
  return {
    userId: userRef,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    type: transactionTypeForEvent(parsed.type),
    status: "completed",
    productId,
    providerProductId: parsed.productId || null,
    newProductId: parsed.newProductId,
    periodMonths: PRODUCT_PERIOD_MONTHS[productId] || 0,
    subscriptionExpiresAt: toTimestampOrNull(effectiveExpirationAtMs(parsed)),
    revenueCatEventId: parsed.eventId,
    revenueCatEventType: parsed.type,
    amount: parsed.priceInPurchasedCurrency,
    currency: parsed.currency,
    store: parsed.storeShort,
    environment: parsed.environment,
    originalTransactionId: parsed.originalTransactionId,
    periodType: isPromotionalEvent(parsed) ?
      "PROMOTIONAL" : parsed.periodType,
    cancelReason: parsed.cancelReason,
  };
}

// Whether to write/overwrite users/{uid}.subscription for this event.
// We only write on grant events. Non-granting events update willRenew on
// the existing subscription doc (if any) but don't change expiresAt.
function shouldWriteSubscriptionFull(eventType) {
  return GRANTING_EVENT_TYPES.has(eventType);
}

function shouldUpdateWillRenew(eventType) {
  return (
    GRANTING_EVENT_TYPES.has(eventType) ||
    NON_GRANTING_EVENT_TYPES.has(eventType)
  );
}

function deriveWillRenew(eventType, currentSubscription = {}, parsed = {}) {
  if (isPromotionalEvent(parsed)) return false;
  if (eventType === "SUBSCRIPTION_EXTENDED" ||
      eventType === "REFUND_REVERSED" ||
      isImmediateRefund(parsed)) {
    return currentSubscription?.willRenew === true;
  }
  if (GRANTING_EVENT_TYPES.has(eventType)) {
    // INITIAL_PURCHASE / RENEWAL / UNCANCELLATION / extension imply
    // the user wants future renewals. NON_RENEWING_PURCHASE explicitly
    // does not auto-renew.
    return eventType !== "NON_RENEWING_PURCHASE";
  }
  // CANCELLATION (user disabled auto-renew), EXPIRATION, BILLING_ISSUE,
  // SUBSCRIPTION_PAUSED — none of these will auto-renew next cycle.
  return false;
}

function providerEventPriority(eventType) {
  switch (eventType) {
    case "BILLING_ISSUE": return 10;
    case "SUBSCRIPTION_PAUSED": return 15;
    case "CANCELLATION": return 20;
    case "EXPIRATION": return 30;
    case "PRODUCT_CHANGE": return 40;
    case "INITIAL_PURCHASE":
    case "NON_RENEWING_PURCHASE":
    case "SUBSCRIPTION_EXTENDED": return 50;
    case "RENEWAL":
    case "UNCANCELLATION": return 60;
    case "REFUND_REVERSED": return 70;
    case "TRANSFER": return 80;
    default: return 0;
  }
}

function providerOrderingUpdate(parsed) {
  return {
    "subscription.lastProviderEventTimestampMs": parsed.eventTimestampMs,
    "subscription.lastProviderEventId": parsed.eventId,
    "subscription.lastEventType": parsed.type,
    "subscription.lastEventAt": admin.firestore.FieldValue.serverTimestamp(),
  };
}

function isImmediateRefund(parsed) {
  return parsed.type === "CANCELLATION" &&
    normalizePeriodType(parsed.cancelReason) === "CUSTOMER_SUPPORT";
}

// RevenueCat retries can arrive out of order. Keep the subscription mirror
// monotonic by provider event timestamp; the transaction record is still
// written for every unique event so analytics remain complete.
function shouldApplySubscriptionEvent(currentSubscription, parsed) {
  if (!currentSubscription || typeof currentSubscription !== "object") {
    return true;
  }
  const incomingAt = parsed.eventTimestampMs;
  const currentAt = toMillisOrNull(
      currentSubscription.lastProviderEventTimestampMs,
  );
  if (incomingAt == null || currentAt == null) return true;
  if (incomingAt > currentAt) return true;
  if (incomingAt < currentAt) return false;
  const currentEventType = safeString(currentSubscription.lastEventType);
  if (currentEventType) {
    const incomingPriority = providerEventPriority(parsed.type);
    const currentPriority = providerEventPriority(currentEventType);
    if (incomingPriority > currentPriority) return true;
    if (incomingPriority < currentPriority) return false;
  }
  const currentEventId = safeString(currentSubscription.lastProviderEventId);
  return !currentEventId || parsed.eventId > currentEventId;
}

function transferSourceIndex(sourceSnaps) {
  let selectedIndex = -1;
  let selectedTimestamp = -1;
  sourceSnaps.forEach((snap, index) => {
    const subscription = snap.exists ? snap.data()?.subscription : null;
    if (!subscription || typeof subscription !== "object") return;
    const timestamp = toMillisOrNull(
        subscription.lastProviderEventTimestampMs,
    ) || 0;
    if (selectedIndex < 0 || timestamp > selectedTimestamp) {
      selectedIndex = index;
      selectedTimestamp = timestamp;
    }
  });
  return selectedIndex;
}

function preferredTransferDestinationId(destinationIds) {
  const ids = safeStringArray(destinationIds);
  const identifiedIds = ids.filter((id) =>
    !isAnonymousRevenueCatUserId(id),
  );
  if (identifiedIds.length === 1) return identifiedIds[0];
  if (identifiedIds.length > 1) return null;
  return ids.sort()[0] || null;
}

function trialAccessStateRank(data) {
  switch (safeString(data?.trialCallStatus)) {
    case "consumed": return 4;
    case "expired": return 3;
    case "inProgress": return 2;
    case "eligible": return 1;
    default: return 0;
  }
}

function conservativeTrialAccessState(states) {
  return states.filter((state) => state && typeof state === "object")
      .reduce((selected, candidate) => {
        if (!selected) return candidate;
        const selectedRank = trialAccessStateRank(selected);
        const candidateRank = trialAccessStateRank(candidate);
        if (candidateRank > selectedRank) return candidate;
        if (candidateRank < selectedRank) return selected;
        const selectedAttempts = Number(selected.attemptCount) || 0;
        const candidateAttempts = Number(candidate.attemptCount) || 0;
        return candidateAttempts > selectedAttempts ? candidate : selected;
      }, null);
}

function buildPendingTransferData(parsed, note) {
  return {
    eventId: parsed.eventId,
    type: parsed.type,
    transferredFrom: parsed.transferredFrom,
    transferredTo: parsed.transferredTo,
    note,
    status: "pending",
    eventTimestampMs: parsed.eventTimestampMs,
    environment: parsed.environment,
    revenueCatAppId: parsed.revenueCatAppId,
    attemptCount: admin.firestore.FieldValue.increment(1),
    lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function applyTransferEvent({db, parsed, transactionRef}) {
  const sourceIds = parsed.transferredFrom;
  const destinationIds = parsed.transferredTo;
  const pendingRef = db.collection("revenueCatPendingTransfers").doc(
      transactionRef.id,
  );
  const destinationId = preferredTransferDestinationId(destinationIds);
  if (!destinationId) {
    return db.runTransaction(async (tx) => {
      const transactionSnap = await tx.get(transactionRef);
      if (transactionSnap.exists) return {duplicate: true};
      tx.set(pendingRef, buildPendingTransferData(
          parsed,
          "transfer_identity_unresolvable",
      ), {merge: true});
      return {pending: true};
    });
  }
  const destinationIsAnonymous = isAnonymousRevenueCatUserId(destinationId);
  const destinationRef = transferSourceRef(db, destinationId);
  const sourceRefs = sourceIds.map((uid) => transferSourceRef(db, uid));
  return db.runTransaction(async (tx) => {
    const [transactionSnap, destinationSnap, ...sourceSnaps] =
      await Promise.all([
        tx.get(transactionRef),
        tx.get(destinationRef),
        ...sourceRefs.map((ref) => tx.get(ref)),
      ]);
    if (transactionSnap.exists) return {duplicate: true};
    const sourceIndex = transferSourceIndex(sourceSnaps);
    if (!destinationIsAnonymous && !destinationSnap.exists) {
      tx.set(pendingRef, buildPendingTransferData(
          parsed,
          "transfer_subscription_unavailable",
      ), {merge: true});
      return {pending: true};
    }
    const destinationSubscription = destinationSnap.data()?.subscription;
    if (sourceIndex < 0) {
      if (!destinationSubscription ||
          typeof destinationSubscription !== "object") {
        tx.set(pendingRef, buildPendingTransferData(
            parsed,
            "transfer_subscription_unavailable",
        ), {merge: true});
        return {pending: true};
      }
      const applyDestinationEvent = shouldApplySubscriptionEvent(
          destinationSubscription,
          parsed,
      );
      if (applyDestinationEvent) {
        tx.update(destinationRef, providerOrderingUpdate(parsed));
      }
      const payload = buildTransactionPayload(parsed, destinationRef);
      if (!applyDestinationEvent) {
        payload.status = "ignored";
        payload.note = "older_provider_event";
      }
      tx.create(transactionRef, {
        ...payload,
        transferredFrom: parsed.transferredFrom,
        transferredTo: parsed.transferredTo,
        note: applyDestinationEvent ?
          "destination_subscription_already_mirrored" : payload.note,
      });
      tx.delete(pendingRef);
      return {duplicate: false, destinationId};
    }
    const sourceRef = sourceRefs[sourceIndex];
    const sourceData = sourceSnaps[sourceIndex].data() || {};
    const sourceSubscription = sourceData.subscription || {};
    const applySourceEvent = shouldApplySubscriptionEvent(
        sourceSubscription,
        parsed,
    );
    const applyDestinationEvent = !destinationSubscription ||
      shouldApplySubscriptionEvent(destinationSubscription, parsed);
    if (!applySourceEvent) {
      tx.create(transactionRef, {
        ...buildTransactionPayload(parsed, destinationRef),
        status: "ignored",
        note: "older_provider_event",
        transferredFrom: parsed.transferredFrom,
        transferredTo: parsed.transferredTo,
      });
      tx.delete(pendingRef);
      return {ignored: true};
    }
    const sourceTrialRefs = sourceIds.map((id, index) =>
      isAnonymousRevenueCatUserId(id) ? null :
        trialAccessRef(db, sourceRefs[index].id),
    );
    const destinationTrialRef = destinationIsAnonymous ? null :
      trialAccessRef(db, destinationId);
    const [sourceTrialSnaps, destinationTrialSnap] = await Promise.all([
      Promise.all(sourceTrialRefs.map((ref) =>
        ref ? tx.get(ref) : Promise.resolve(null),
      )),
      destinationTrialRef ? tx.get(destinationTrialRef) : Promise.resolve(null),
    ]);
    const destinationData = destinationSnap.exists ?
      destinationSnap.data() || {} : {};
    const sourceTrialStates = sourceIds.map((id, index) =>
      isAnonymousRevenueCatUserId(id) ?
        sourceSnaps[index].data()?.trialAccess :
        (sourceTrialSnaps[index]?.exists ?
          sourceTrialSnaps[index].data() || {} : null),
    );
    const destinationTrialData = destinationIsAnonymous ?
      destinationData.trialAccess :
      (destinationTrialSnap?.exists ? destinationTrialSnap.data() || {} : null);
    const mergedTrialData = conservativeTrialAccessState([
      ...sourceTrialStates,
      destinationTrialData,
    ]);
    const trialGrantEntries = new Map();
    sourceSnaps.forEach((snap, index) => {
      const originalTransactionId = safeString(
          snap.exists ? snap.data()?.subscription?.originalTransactionId : null,
      );
      if (!originalTransactionId) return;
      const ref = db.collection("subscriptionTrialGrants").doc(
          trialGrantDocumentId(originalTransactionId),
      );
      const entry = trialGrantEntries.get(ref.path) || {
        ref,
        sourceIds: new Set(),
      };
      entry.sourceIds.add(sourceIds[index]);
      trialGrantEntries.set(ref.path, entry);
    });
    const trialGrantValues = [...trialGrantEntries.values()];
    const trialGrantSnaps = await Promise.all(
        trialGrantValues.map((entry) => tx.get(entry.ref)),
    );
    const nowTimestamp = toTimestampOrNull(parsed.eventTimestampMs);
    sourceSnaps.forEach((snap, index) => {
      if (!snap.exists) return;
      const data = snap.data() || {};
      const subscription = data.subscription;
      const update = {};
      if (subscription && typeof subscription === "object" &&
          shouldApplySubscriptionEvent(subscription, parsed)) {
        Object.assign(update, {
          "subscription.expiresAt": nowTimestamp,
          "subscription.willRenew": false,
          ...providerOrderingUpdate(parsed),
        });
      }
      if (isAnonymousRevenueCatUserId(sourceIds[index]) &&
          data.trialAccess && typeof data.trialAccess === "object") {
        update.trialAccess = admin.firestore.FieldValue.delete();
      }
      if (Object.keys(update).length > 0) tx.update(sourceRefs[index], update);
      if (sourceTrialSnaps[index]?.exists) {
        tx.delete(sourceTrialRefs[index]);
      }
    });
    if (applyDestinationEvent) {
      const destinationUpdate = {
        subscription: {
          ...sourceSubscription,
          revenueCatUserId: destinationId,
          lastProviderEventTimestampMs: parsed.eventTimestampMs,
          lastProviderEventId: parsed.eventId,
          lastEventType: parsed.type,
          lastEventAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      };
      if (destinationIsAnonymous) {
        tx.set(destinationRef, destinationUpdate, {merge: true});
      } else {
        tx.update(destinationRef, destinationUpdate);
      }
    }
    if (mergedTrialData) {
      const movedTrialData = {
        ...mergedTrialData,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (destinationIsAnonymous) {
        tx.set(destinationRef, {trialAccess: movedTrialData}, {merge: true});
      } else {
        tx.set(destinationTrialRef, movedTrialData, {merge: false});
      }
    }
    trialGrantValues.forEach((entry, index) => {
      const grantSnap = trialGrantSnaps[index];
      if (grantSnap.exists &&
          entry.sourceIds.has(safeString(grantSnap.data()?.uid))) {
        tx.update(entry.ref, {
          uid: destinationId,
          transferredAt: admin.firestore.FieldValue.serverTimestamp(),
          transferEventId: parsed.eventId,
        });
      }
    });
    tx.create(transactionRef, {
      ...buildTransactionPayload(
          parsed,
          destinationIsAnonymous ? null : destinationRef,
      ),
      transferredFrom: parsed.transferredFrom,
      transferredTo: parsed.transferredTo,
      sourceUserId: sourceRef,
      note: applyDestinationEvent ? null :
        "destination_subscription_already_newer",
    });
    tx.delete(pendingRef);
    return {duplicate: false, destinationId};
  });
}

exports.revenueCatWebhook = functions
    .runWith({
      secrets: [revenueCatWebhookSecret],
      timeoutSeconds: 60,
      memory: "256MB",
    })
    .https.onRequest(async (req, res) => {
      safeLog.log("webhook_received", {
        method: req.method,
        path: req.path,
        hasAuth: Boolean(req.headers.authorization),
      });

      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }

      // Validate shared secret. RevenueCat sends the configured value as the
      // raw Authorization header — we compare byte-for-byte.
      const expectedSecret = revenueCatWebhookSecret.value();
      if (!expectedSecret) {
        safeLog.error("webhook_secret_missing");
        res.status(500).send("Server not configured");
        return;
      }
      const authHeader = req.headers.authorization || "";
      if (authHeader !== expectedSecret) {
        safeLog.warn("webhook_auth_failed");
        res.status(401).send("Unauthorized");
        return;
      }

      const parsed = parseEvent(req.body);
      if (!parsed) {
        safeLog.warn("webhook_payload_malformed", {
          bodyType: typeof req.body,
          hasEvent: Boolean(req.body && req.body.event),
        });
        // 400 so RevenueCat shows the error in their UI but doesn't retry.
        res.status(400).send("Malformed event");
        return;
      }

      safeLog.log("webhook_event", {
        type: parsed.type,
        eventId: parsed.eventId,
        appUserId: parsed.appUserId,
        productId: parsed.productId,
        environment: parsed.environment,
      });

      if (!HANDLED_EVENT_TYPES.has(parsed.type)) {
        safeLog.log("webhook_event_ignored", {
          type: parsed.type,
        });
        res.status(200).send("Ignored");
        return;
      }

      const malformedReason = malformedEventReason(parsed);
      if (malformedReason) {
        safeLog.warn("webhook_lifecycle_malformed", {
          type: parsed.type,
          eventId: parsed.eventId,
          reason: malformedReason,
        });
        res.status(400).send("Malformed lifecycle event");
        return;
      }

      const allowlistFailure = eventAllowlistFailure(parsed);
      if (allowlistFailure) {
        safeLog.warn("webhook_event_not_allowlisted", {
          type: parsed.type,
          eventId: parsed.eventId,
          productId: parsed.productId,
          reason: allowlistFailure,
        });
        res.status(200).send("Ignored");
        return;
      }

      const db = admin.firestore();
      const transactionRef = db
          .collection("transactions")
          .doc(transactionDocumentIdForEvent(parsed.eventId));
      if (parsed.type === "TRANSFER") {
        try {
          const transferResult = await applyTransferEvent({
            db,
            parsed,
            transactionRef,
          });
          if (transferResult.pending) {
            res.status(500).send("Transfer pending");
          } else {
            res.status(200).send(
                transferResult.duplicate ? "Duplicate" : "OK",
            );
          }
        } catch (err) {
          safeLog.error("webhook_transfer_failed", {
            eventId: parsed.eventId,
            error: err,
          });
          res.status(500).send("Internal error");
        }
        return;
      }
      const isAnonymous = isAnonymousRevenueCatUserId(parsed.appUserId);
      const userRef = isAnonymous ?
        null :
        db.collection("users").doc(parsed.appUserId);
      const initializesTrial = shouldInitializeTrial(parsed);
      if (initializesTrial &&
          (!parsed.originalTransactionId || !parsed.purchasedAtMs)) {
        safeLog.warn("webhook_trial_malformed", {
          eventId: parsed.eventId,
        });
        res.status(400).send("Malformed trial purchase");
        return;
      }
      const trialRef = userRef ? trialAccessRef(db, parsed.appUserId) : null;
      const transferSource = isAnonymous ?
        transferSourceRef(db, parsed.appUserId) : null;
      const trialGrantRef = initializesTrial ?
        db.collection("subscriptionTrialGrants").doc(
            trialGrantDocumentId(parsed.originalTransactionId),
        ) : null;

      try {
        const result = await db.runTransaction(async (tx) => {
          const [transactionSnap, userSnap, trialGrantSnap, trialSnap,
            transferSourceSnap] = await Promise.all([
            tx.get(transactionRef),
            userRef ? tx.get(userRef) : Promise.resolve(null),
            trialGrantRef ? tx.get(trialGrantRef) : Promise.resolve(null),
            trialRef ? tx.get(trialRef) : Promise.resolve(null),
            transferSource ? tx.get(transferSource) : Promise.resolve(null),
          ]);
          if (transactionSnap.exists) {
            return {duplicate: true};
          }
          if (userRef && !userSnap.exists) {
            safeLog.warn("webhook_user_not_found", {
              appUserId: parsed.appUserId,
              eventId: parsed.eventId,
            });
          }

          if (trialGrantSnap?.exists) {
            const ownerUid = safeString(trialGrantSnap.data()?.uid);
            if (ownerUid && ownerUid !== parsed.appUserId) {
              tx.create(transactionRef, {
                ...buildTransactionPayload(parsed, null),
                status: "ignored",
                note: "trial_transaction_owned_by_another_user",
              });
              return {duplicate: false, accountMismatch: true};
            }
          }

          const mirrorSnap = userSnap?.exists ? userSnap : transferSourceSnap;
          const currentSubscription = mirrorSnap?.exists ?
            mirrorSnap.data()?.subscription : null;
          const applySubscription = shouldApplySubscriptionEvent(
              currentSubscription,
              parsed,
          );
          const willRenew = deriveWillRenew(
              parsed.type,
              currentSubscription || {},
              parsed,
          );
          const userUpdate = {};

          if (applySubscription && shouldWriteSubscriptionFull(parsed.type)) {
            // Full overwrite of the subscription struct on grant events.
            userUpdate.subscription = buildSubscriptionPayload(parsed, {
              willRenew,
            });
          } else if (applySubscription && shouldUpdateWillRenew(parsed.type)) {
            // Touch only willRenew + lastEventType on cancellation/expiration.
            // We use dot-notation so we don't wipe the rest of the struct.
            userUpdate["subscription.willRenew"] = willRenew;
            Object.assign(userUpdate, providerOrderingUpdate(parsed));
            if ((parsed.type === "EXPIRATION" || isImmediateRefund(parsed)) &&
                effectiveExpirationAtMs(parsed)) {
              userUpdate["subscription.expiresAt"] = toTimestampOrNull(
                  isImmediateRefund(parsed) ?
                    Math.min(
                        effectiveExpirationAtMs(parsed),
                        parsed.eventTimestampMs,
                    ) : effectiveExpirationAtMs(parsed),
              );
            }
          } else if (applySubscription && parsed.type === "PRODUCT_CHANGE") {
            if (parsed.newProductId) {
              userUpdate["subscription.pendingProductId"] =
                parsed.newProductId;
            }
            Object.assign(userUpdate, providerOrderingUpdate(parsed));
          }

          const embeddedTrial = transferSourceSnap?.exists ?
            transferSourceSnap.data()?.trialAccess : null;
          const hasTrialState = userRef ? trialSnap?.exists === true :
            embeddedTrial && typeof embeddedTrial === "object";
          const canInitializeTrial = userRef ? userSnap?.exists === true :
            transferSource != null;
          if (initializesTrial && canInitializeTrial && !hasTrialState) {
            const trialPayload = buildInitialTrialPayload(parsed);
            if (userRef) {
              tx.set(trialRef, trialPayload, {merge: false});
            } else {
              userUpdate.trialAccess = trialPayload;
            }
            if (!trialGrantSnap.exists) {
              tx.create(trialGrantRef, {
                uid: parsed.appUserId,
                productId: parsed.productId,
                originalTransactionId: parsed.originalTransactionId,
                sourceEventId: parsed.eventId,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            }
          }

          if (userRef && userSnap.exists && Object.keys(userUpdate).length > 0) {
            tx.update(userRef, userUpdate);
          } else if (transferSource && Object.keys(userUpdate).length > 0) {
            tx.set(transferSource, userUpdate, {merge: true});
          }

          const transactionPayload = buildTransactionPayload(parsed, userRef);
          if (!applySubscription) {
            transactionPayload.status = "ignored";
            transactionPayload.note = "older_provider_event";
          }
          if (isAnonymous) {
            transactionPayload.userId = null;
            transactionPayload.note = "anonymous_rc_user";
          }
          tx.create(transactionRef, transactionPayload);
          return {duplicate: false};
        });

        if (result.duplicate) {
          safeLog.log("webhook_duplicate", {
            eventId: parsed.eventId,
            transactionId: transactionRef.id,
          });
          res.status(200).send("Duplicate");
          return;
        }
        if (result.accountMismatch) {
          safeLog.warn("webhook_trial_ownership_mismatch", {
            eventId: parsed.eventId,
            appUserId: parsed.appUserId,
          });
          res.status(200).send("Ignored account mismatch");
          return;
        }

        safeLog.log("webhook_applied", {
          type: parsed.type,
          eventId: parsed.eventId,
          appUserId: parsed.appUserId,
        });
        res.status(200).send("OK");
      } catch (err) {
        safeLog.error("webhook_apply_failed", {
          eventId: parsed.eventId,
          appUserId: parsed.appUserId,
          error: err,
        });
        // 500 → RevenueCat retries with backoff (up to ~72h).
        res.status(500).send("Internal error");
      }
    });

exports.__private__ = {
  ALLOWED_PRODUCT_IDS,
  PRODUCT_PERIOD_MONTHS,
  PRO_ENTITLEMENT_ID,
  configuredRevenueCatAppIds,
  eventAllowlistFailure,
  malformedEventReason,
  parseEvent,
  buildInitialTrialPayload,
  buildSubscriptionPayload,
  deriveWillRenew,
  shouldApplySubscriptionEvent,
  shouldInitializeTrial,
  isImmediateRefund,
  isAnonymousRevenueCatUserId,
  applyTransferEvent,
  trialGrantDocumentId,
  transactionDocumentIdForEvent,
  preferredTransferDestinationId,
  conservativeTrialAccessState,
  transferSourceDocumentId,
  transferSourceIndex,
};
