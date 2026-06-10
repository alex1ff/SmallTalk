// grantPromoEntitlement
//
// Admin-only callable to grant a promotional (free) RevenueCat entitlement
// to a target user. Used by support / marketing / influencer flows where
// we want to give a user paid access without going through the App Store
// or Google Play paywall.
//
// Implementation: calls the RevenueCat REST API
// `POST /v1/subscribers/{app_user_id}/entitlements/{entitlement_id}/promotional`
// with the secret API key from Firebase Secret Manager. RevenueCat then
// fires a `INITIAL_PURCHASE` (or similar) webhook back to us with
// `period_type: "PROMOTIONAL"` and we mirror it into Firestore via
// revenue_cat_webhook.js — so this callable does NOT directly write to
// users/{uid}.subscription. Single source of truth stays in the webhook.
//
// Auth: requires Firebase Auth custom claim `admin === true` on the
// caller. Set this out-of-band via the Admin SDK, e.g.
//   admin.auth().setCustomUserClaims(uid, { admin: true })
//
// Input:
//   { targetUid: string,
//     duration?: "three_day" | "weekly" | "monthly" | "two_month" |
//                "three_month" | "six_month" | "yearly" | "lifetime",
//     customDays?: number,   // overrides `duration` when set; uses custom
//                            // start/end_time_ms in the RC payload
//     reason?: string        // free-text note logged in transactions doc
//   }
//
// Either `duration` or `customDays` must be provided.

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const axios = require("axios");
const {defineSecret} = require("firebase-functions/params");

const revenueCatSecretApiKey = defineSecret("REVENUECAT_SECRET_API_KEY");

const PRO_ENTITLEMENT_ID = "Expatlio Pro";
const REVENUECAT_API_BASE = "https://api.revenuecat.com/v1";
const REQUEST_TIMEOUT_MS = 15000;

const ALLOWED_DURATIONS = new Set([
  "daily",
  "three_day",
  "weekly",
  "monthly",
  "two_month",
  "three_month",
  "six_month",
  "yearly",
  "lifetime",
]);

function buildRequestBody({duration, customDays}) {
  if (customDays && Number.isFinite(customDays) && customDays > 0) {
    const startMs = Date.now();
    const endMs = startMs + customDays * 24 * 60 * 60 * 1000;
    return {
      duration: "custom",
      start_time_ms: startMs,
      end_time_ms: endMs,
    };
  }
  return {duration};
}

exports.grantPromoEntitlement = functions
    .runWith({
      secrets: [revenueCatSecretApiKey],
      timeoutSeconds: 30,
      memory: "256MB",
    })
    .https.onCall(async (data, context) => {
      console.log("🎁 grantPromoEntitlement called");

      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be authenticated",
        );
      }
      if (context.auth.token.admin !== true) {
        console.warn("🛑 grantPromoEntitlement non-admin caller", {
          callerUid: context.auth.uid,
        });
        throw new functions.https.HttpsError(
            "permission-denied",
            "Only admins can grant promotional entitlements",
        );
      }

      const targetUid =
        typeof data?.targetUid === "string" ? data.targetUid.trim() : "";
      const duration =
        typeof data?.duration === "string" ? data.duration.trim() : null;
      const customDays =
        Number.isFinite(Number(data?.customDays)) ?
          Number(data.customDays) :
          null;
      const reason =
        typeof data?.reason === "string" ? data.reason.trim() : null;

      if (!targetUid) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "targetUid is required",
        );
      }
      if (!customDays && (!duration || !ALLOWED_DURATIONS.has(duration))) {
        throw new functions.https.HttpsError(
            "invalid-argument",
          `duration must be one of ${[...ALLOWED_DURATIONS].join(", ")} ` +
            "or customDays must be > 0",
        );
      }
      if (customDays && (customDays <= 0 || customDays > 365 * 5)) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "customDays must be between 1 and 1825 (5 years)",
        );
      }

      const apiKey = revenueCatSecretApiKey.value();
      if (!apiKey) {
        console.error("❌ REVENUECAT_SECRET_API_KEY not configured");
        throw new functions.https.HttpsError(
            "failed-precondition",
            "RevenueCat is not configured on the server",
        );
      }

      const url =
        `${REVENUECAT_API_BASE}/subscribers/` +
        `${encodeURIComponent(targetUid)}/entitlements/` +
        `${encodeURIComponent(PRO_ENTITLEMENT_ID)}/promotional`;
      const body = buildRequestBody({duration, customDays});

      console.log("🎁 grantPromoEntitlement requesting RC", {
        targetUid,
        url,
        body: {...body, customDaysSecondsMasked: undefined},
        callerUid: context.auth.uid,
      });

      try {
        const response = await axios.post(url, body, {
          timeout: REQUEST_TIMEOUT_MS,
          headers: {
            "Authorization": `Bearer ${apiKey}`,
            "Content-Type": "application/json",
            "X-Platform": "stripe", // RC requires a platform; promotional is platform-agnostic
          },
        });

        // Audit trail: log the grant in transactions. The actual
        // subscription state will be written by the RC webhook when it
        // fires for this grant.
        const db = admin.firestore();
        await db.collection("transactions").add({
          userId: db.collection("users").doc(targetUid),
          type: "promotional_grant",
          status: "completed",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          duration: body.duration,
          customStartTimeMs: body.start_time_ms || null,
          customEndTimeMs: body.end_time_ms || null,
          reason: reason || null,
          grantedByUid: context.auth.uid,
          revenueCatResponseStatus: response.status,
        });

        console.log("✅ grantPromoEntitlement succeeded", {
          targetUid,
          duration: body.duration,
          status: response.status,
        });

        return {
          status: "granted",
          targetUid,
          duration: body.duration,
        };
      } catch (err) {
        const status = err?.response?.status || null;
        const responseBody = err?.response?.data || null;
        console.error("❌ grantPromoEntitlement RC API error", {
          targetUid,
          status,
          responseBody,
          message: err?.message,
        });

        if (status === 404) {
          throw new functions.https.HttpsError(
              "not-found",
              "RevenueCat does not know this user yet — " +
              "they need to open the app at least once",
              {targetUid},
          );
        }
        if (status === 401 || status === 403) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "RevenueCat rejected the API key",
          );
        }
        throw new functions.https.HttpsError(
            "internal",
            "Failed to grant promotional entitlement",
            {status, responseBody},
        );
      }
    });
