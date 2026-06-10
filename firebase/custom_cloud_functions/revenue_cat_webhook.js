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
// Idempotency: every RevenueCat event has a unique `event.id`. We refuse to
// process the same event twice by checking `transactions` for an existing
// record with matching `revenueCatEventId` before applying state changes.

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {defineSecret} = require("firebase-functions/params");

const revenueCatWebhookSecret = defineSecret("REVENUECAT_WEBHOOK_SECRET");

// Entitlement that grants access to the product. Must match the
// Entitlement ID configured in RevenueCat dashboard.
const PRO_ENTITLEMENT_ID = "Expatlio Pro";

// Product → period (months) map. Source of truth lives in App Store Connect
// / Google Play, this map only tells us how long to extend the subscription
// when stacking purchases. Keep in sync with store products.
const PRODUCT_PERIOD_MONTHS = {
  "expatlio_1_Month": 1,
  "expatlio_3_Month": 3,
};

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
    periodType,
    cancelReason,
    priceInPurchasedCurrency,
    currency,
  };
}

// Returns the existing transaction snapshot if one with the same
// revenueCatEventId already exists, otherwise null. Used for idempotency.
async function findExistingTransaction(db, eventId) {
  const existing = await db
      .collection("transactions")
      .where("revenueCatEventId", "==", eventId)
      .limit(1)
      .get();
  return existing.empty ? null : existing.docs[0];
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
    lastEventType: parsed.type,
    lastEventAt: admin.firestore.FieldValue.serverTimestamp(),
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

      const db = admin.firestore();

      // Idempotency: if we've already processed this event.id, ack with 200.
      try {
        const existing = await findExistingTransaction(db, parsed.eventId);
        if (existing) {
          console.log("ℹ️ revenueCatWebhook duplicate event, acking", {
            eventId: parsed.eventId,
            existingTransactionId: existing.id,
          });
          res.status(200).send("Duplicate");
          return;
        }
      } catch (err) {
        console.error("❌ revenueCatWebhook idempotency check failed", err);
        // Don't 500 — RevenueCat will retry. Fall through to processing;
        // if Firestore is fully down we'll fail later and 500 there.
      }

      // Resolve the user. RevenueCat App User ID is the Firebase uid (set
      // client-side via Purchases.logIn). Anonymous IDs ($RCAnonymousID:…)
      // are not linked to a user and we cannot mirror state for them.
      if (parsed.appUserId.startsWith("$RCAnonymousID:")) {
        console.warn(
            "⚠️ revenueCatWebhook anonymous app_user_id, skipping mirror",
            {appUserId: parsed.appUserId, eventId: parsed.eventId},
        );
        // Still record the transaction (without userId) for audit.
        try {
          await db.collection("transactions").add({
            ...buildTransactionPayload(parsed, null),
            userId: null,
            note: "anonymous_rc_user",
          });
        } catch (err) {
          console.error("❌ revenueCatWebhook anon transaction write failed", err);
        }
        res.status(200).send("Anonymous user, no mirror");
        return;
      }

      const userRef = db.collection("users").doc(parsed.appUserId);

      try {
        await db.runTransaction(async (tx) => {
          const userSnap = await tx.get(userRef);
          if (!userSnap.exists) {
            console.warn(
                "⚠️ revenueCatWebhook user not found, recording transaction only",
                {uid: parsed.appUserId, eventId: parsed.eventId},
            );
          }

          const willRenew = deriveWillRenew(parsed.type);
          const userUpdate = {};

          if (shouldWriteSubscriptionFull(parsed.type)) {
            // Full overwrite of the subscription struct on grant events.
            userUpdate.subscription = buildSubscriptionPayload(parsed, {
              willRenew,
            });
          } else if (shouldUpdateWillRenew(parsed.type)) {
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

          if (userSnap.exists && Object.keys(userUpdate).length > 0) {
            tx.update(userRef, userUpdate);
          }

          const txDocRef = db.collection("transactions").doc();
          tx.set(txDocRef, buildTransactionPayload(parsed, userRef));
        });

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
