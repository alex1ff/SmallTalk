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

const revenueCatWebhookSecret = defineSecret("REVENUECAT_WEBHOOK_SECRET");
const {
  TRIAL_PRODUCT_ID,
  TRIAL_WINDOW_MS,
  trialAccessRef,
} = require("./trial_access");

// Entitlement that grants access to the product. Must match the
// Entitlement ID configured in RevenueCat dashboard.
const PRO_ENTITLEMENT_ID = "Expatlio Pro";

// Product → period (months) map. Source of truth lives in App Store Connect
// / Google Play, this map only tells us how long to extend the subscription
// when stacking purchases. Keep in sync with store products.
const PRODUCT_PERIOD_MONTHS = {
  "expatlio_1_Month": 1,
  "expatlio_3_Month": 3,
  [TRIAL_PRODUCT_ID]: 1,
};
const ALLOWED_PRODUCT_IDS = new Set(Object.keys(PRODUCT_PERIOD_MONTHS));

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
  "TRANSFER",
  "TEST",
]);

// Event types that grant or extend an active entitlement.
const GRANTING_EVENT_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
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
  if (!type || !eventId || !appUserId) {
    return null;
  }

  const productId = safeString(event.product_id);
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

function eventAllowlistFailure(parsed, env = process.env) {
  if (parsed.type === "TRANSFER") {
    return "unsupported_transfer";
  }
  if (parsed.type === "TEST") {
    return null;
  }

  const appIds = configuredRevenueCatAppIds(env);
  if (appIds.size === 0) {
    return "missing_revenuecat_app_allowlist";
  }
  if (!parsed.revenueCatAppId || !appIds.has(parsed.revenueCatAppId)) {
    return "unexpected_revenuecat_app";
  }
  if (!parsed.productId || !ALLOWED_PRODUCT_IDS.has(parsed.productId)) {
    return "unexpected_product";
  }
  if (!parsed.entitlementIds.includes(PRO_ENTITLEMENT_ID)) {
    return "unexpected_entitlement";
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
  const productId = parsed.productId || "unknown";
  const periodMonths = PRODUCT_PERIOD_MONTHS[productId] || 0;
  return {
    entitlementId: PRO_ENTITLEMENT_ID,
    productId,
    periodMonths,
    startedAt: toTimestampOrNull(parsed.purchasedAtMs),
    expiresAt: toTimestampOrNull(parsed.expirationAtMs),
    willRenew,
    store: parsed.storeShort,
    revenueCatUserId: parsed.appUserId,
    originalTransactionId: parsed.originalTransactionId,
    environment: parsed.environment,
    periodType: parsed.periodType,
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
  return {
    userId: userRef,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    type: transactionTypeForEvent(parsed.type),
    status: "completed",
    productId: parsed.productId,
    periodMonths: PRODUCT_PERIOD_MONTHS[parsed.productId] || 0,
    subscriptionExpiresAt: toTimestampOrNull(parsed.expirationAtMs),
    revenueCatEventId: parsed.eventId,
    revenueCatEventType: parsed.type,
    amount: parsed.priceInPurchasedCurrency,
    currency: parsed.currency,
    store: parsed.storeShort,
    environment: parsed.environment,
    originalTransactionId: parsed.originalTransactionId,
    periodType: parsed.periodType,
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

function deriveWillRenew(eventType) {
  if (GRANTING_EVENT_TYPES.has(eventType)) {
    // INITIAL_PURCHASE / RENEWAL / UNCANCELLATION / PRODUCT_CHANGE imply
    // the user wants future renewals. NON_RENEWING_PURCHASE explicitly
    // does not auto-renew.
    return eventType !== "NON_RENEWING_PURCHASE";
  }
  // CANCELLATION (user disabled auto-renew), EXPIRATION, BILLING_ISSUE,
  // SUBSCRIPTION_PAUSED — none of these will auto-renew next cycle.
  return false;
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
  const currentEventId = safeString(currentSubscription.lastProviderEventId);
  return !currentEventId || parsed.eventId > currentEventId;
}

exports.revenueCatWebhook = functions
    .runWith({
      secrets: [revenueCatWebhookSecret],
      timeoutSeconds: 60,
      memory: "256MB",
    })
    .https.onRequest(async (req, res) => {
      console.log("📬 revenueCatWebhook received", {
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
        console.error("❌ REVENUECAT_WEBHOOK_SECRET not configured");
        res.status(500).send("Server not configured");
        return;
      }
      const authHeader = req.headers.authorization || "";
      if (authHeader !== expectedSecret) {
        console.warn("⚠️ revenueCatWebhook auth failed");
        res.status(401).send("Unauthorized");
        return;
      }

      const parsed = parseEvent(req.body);
      if (!parsed) {
        console.warn("⚠️ revenueCatWebhook malformed payload", {
          bodyType: typeof req.body,
          hasEvent: Boolean(req.body && req.body.event),
        });
        // 400 so RevenueCat shows the error in their UI but doesn't retry.
        res.status(400).send("Malformed event");
        return;
      }

      console.log("📬 revenueCatWebhook event", {
        type: parsed.type,
        eventId: parsed.eventId,
        appUserId: parsed.appUserId,
        productId: parsed.productId,
        environment: parsed.environment,
      });

      if (!HANDLED_EVENT_TYPES.has(parsed.type)) {
        console.log("ℹ️ revenueCatWebhook ignoring unhandled event type", {
          type: parsed.type,
        });
        res.status(200).send("Ignored");
        return;
      }

      const allowlistFailure = eventAllowlistFailure(parsed);
      if (allowlistFailure) {
        console.warn("⚠️ revenueCatWebhook ignored by allowlist", {
          type: parsed.type,
          eventId: parsed.eventId,
          productId: parsed.productId,
          reason: allowlistFailure,
        });
        res.status(200).send("Ignored");
        return;
      }

      const db = admin.firestore();
      const isAnonymous = parsed.appUserId.startsWith("$RCAnonymousID:");
      const userRef = isAnonymous ?
        null :
        db.collection("users").doc(parsed.appUserId);
      const transactionRef = db
          .collection("transactions")
          .doc(transactionDocumentIdForEvent(parsed.eventId));
      const initializesTrial = shouldInitializeTrial(parsed);
      if (initializesTrial &&
          (!parsed.originalTransactionId || !parsed.purchasedAtMs)) {
        console.warn("⚠️ revenueCatWebhook malformed trial purchase", {
          eventId: parsed.eventId,
        });
        res.status(400).send("Malformed trial purchase");
        return;
      }
      const trialRef = userRef ? trialAccessRef(db, parsed.appUserId) : null;
      const trialGrantRef = initializesTrial ?
        db.collection("subscriptionTrialGrants").doc(
            trialGrantDocumentId(parsed.originalTransactionId),
        ) : null;

      try {
        const result = await db.runTransaction(async (tx) => {
          const [transactionSnap, userSnap, trialGrantSnap, trialSnap] = await Promise.all([
            tx.get(transactionRef),
            userRef ? tx.get(userRef) : Promise.resolve(null),
            trialGrantRef ? tx.get(trialGrantRef) : Promise.resolve(null),
            trialRef ? tx.get(trialRef) : Promise.resolve(null),
          ]);
          if (transactionSnap.exists) {
            return {duplicate: true};
          }
          if (userRef && !userSnap.exists) {
            console.warn(
                "⚠️ revenueCatWebhook user not found, recording transaction only",
                {uid: parsed.appUserId, eventId: parsed.eventId},
            );
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

          const currentSubscription = userSnap?.exists ?
            userSnap.data()?.subscription : null;
          const applySubscription = shouldApplySubscriptionEvent(
              currentSubscription,
              parsed,
          );
          const willRenew = deriveWillRenew(parsed.type);
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
            userUpdate["subscription.lastEventType"] = parsed.type;
            userUpdate["subscription.lastEventAt"] =
              admin.firestore.FieldValue.serverTimestamp();
            if (parsed.type === "EXPIRATION" && parsed.expirationAtMs) {
              userUpdate["subscription.expiresAt"] = toTimestampOrNull(
                  parsed.expirationAtMs,
              );
            }
          }

          if (userRef && userSnap.exists && Object.keys(userUpdate).length > 0) {
            tx.update(userRef, userUpdate);
          }

          if (initializesTrial && userRef && userSnap.exists &&
              !trialSnap?.exists) {
            const trialPayload = buildInitialTrialPayload(parsed);
            tx.set(trialRef, trialPayload, {merge: false});
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

          const transactionPayload = buildTransactionPayload(parsed, userRef);
          if (isAnonymous) {
            transactionPayload.userId = null;
            transactionPayload.note = "anonymous_rc_user";
          }
          tx.create(transactionRef, transactionPayload);
          return {duplicate: false};
        });

        if (result.duplicate) {
          console.log("ℹ️ revenueCatWebhook duplicate event, acking", {
            eventId: parsed.eventId,
            transactionId: transactionRef.id,
          });
          res.status(200).send("Duplicate");
          return;
        }
        if (result.accountMismatch) {
          console.warn("⚠️ revenueCatWebhook trial ownership mismatch", {
            eventId: parsed.eventId,
            uid: parsed.appUserId,
          });
          res.status(200).send("Ignored account mismatch");
          return;
        }

        console.log("✅ revenueCatWebhook applied", {
          type: parsed.type,
          eventId: parsed.eventId,
          uid: parsed.appUserId,
        });
        res.status(200).send("OK");
      } catch (err) {
        console.error("❌ revenueCatWebhook apply failed", {
          eventId: parsed.eventId,
          uid: parsed.appUserId,
          err: err && err.message ? err.message : err,
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
  parseEvent,
  buildInitialTrialPayload,
  shouldApplySubscriptionEvent,
  shouldInitializeTrial,
  trialGrantDocumentId,
  transactionDocumentIdForEvent,
};
