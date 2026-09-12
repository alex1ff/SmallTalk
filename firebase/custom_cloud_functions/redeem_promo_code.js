// redeemPromoCode
//
// Callable that grants gift minutes to the authenticated user against a
// promo code stored in the `promoCodes` Firestore collection.
//
// Promo code schema:
//   promoCodes/{id} = {
//     code: string,            // case-insensitive lookup key
//     isActive: bool,
//     expiredDate: timestamp,  // when the code itself expires
//     usageLimit: int,         // total redemptions allowed (across users)
//     usageCount: int,         // server-incremented
//     minutesGifted: int,      // free minutes added to user.giftMinutes
//     validForDays: int,       // TTL of the granted gift bucket
//   }
//
// Per-user uniqueness: a redemption document is written at
// `promoCodes/{id}/redemptions/{uid}` to prevent double-redemption.
//
// Atomicity: lookup + redemption check + counter increment + user update
// all happen inside a single Firestore transaction.

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {createSafeConsole} = require("./safe_log");

const {
  buildPromoGrantPayload,
} = require("./gift_minutes_shared");

const REQUEST_TIMEOUT_SECONDS = 30;
const safeConsole = createSafeConsole({source: "redeem_promo_code"});

function normalizeCode(value) {
  if (typeof value !== "string") return "";
  return value.trim();
}

// Pure validators — extracted so they can be unit-tested in isolation.
// All assume `promoData` is a Firestore document.data() shape.

function isPromoActive(promoData, nowMs = Date.now()) {
  if (!promoData || promoData.isActive === false) return false;
  const expired = promoData.expiredDate;
  if (expired) {
    const expiredMs = typeof expired.toMillis === "function" ?
      expired.toMillis() :
      Number(expired);
    if (Number.isFinite(expiredMs) && expiredMs < nowMs) {
      return false;
    }
  }
  return true;
}

function isPromoExhausted(promoData) {
  if (!promoData) return true;
  const limit = Number(promoData.usageLimit);
  const count = Number(promoData.usageCount) || 0;
  return Number.isFinite(limit) && count >= limit;
}

// Resolves the gift (minutesGifted, validForDays) from a promo document.
// Returns null if the promo doesn't carry a valid gift.
function resolvePromoGift(promoData) {
  if (!promoData) return null;
  const minutesGifted = Number(promoData.minutesGifted);
  let validForDays = Number(promoData.validForDays);
  if (!Number.isFinite(validForDays) || validForDays <= 0) {
    validForDays = 1;
  }
  if (!Number.isFinite(minutesGifted) || minutesGifted <= 0) {
    return null;
  }
  return {minutesGifted, validForDays};
}

exports.__private__ = {
  normalizeCode,
  isPromoActive,
  isPromoExhausted,
  resolvePromoGift,
};

exports.redeemPromoCode = functions
    .runWith({timeoutSeconds: REQUEST_TIMEOUT_SECONDS, memory: "256MB"})
    .https.onCall(async (data, context) => {
      safeConsole.log("promo_code_redeem_started");

      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be authenticated",
        );
      }
      const uid = context.auth.uid;
      const rawCode = normalizeCode(data?.code);
      if (!rawCode) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Промокод обязателен",
        );
      }

      const db = admin.firestore();

      // Look up the promo by code (case-insensitive: try raw, then upper).
      // We do this OUTSIDE the transaction because Firestore transactions
      // can't run queries — only doc reads.
      const candidates = Array.from(
          new Set([rawCode, rawCode.toUpperCase(), rawCode.toLowerCase()]),
      );
      let promoSnap = null;
      for (const candidate of candidates) {
        const q = await db
            .collection("promoCodes")
            .where("code", "==", candidate)
            .limit(1)
            .get();
        if (!q.empty) {
          promoSnap = q.docs[0];
          break;
        }
      }
      if (!promoSnap) {
        throw new functions.https.HttpsError(
            "not-found",
            "Промокод не найден",
        );
      }

      const promoRef = promoSnap.ref;
      const redemptionRef = promoRef.collection("redemptions").doc(uid);
      const userRef = db.collection("users").doc(uid);

      try {
        const result = await db.runTransaction(async (tx) => {
          const [
            promoDoc,
            redemptionDoc,
            userDoc,
          ] = await Promise.all([
            tx.get(promoRef),
            tx.get(redemptionRef),
            tx.get(userRef),
          ]);

          if (!promoDoc.exists) {
            throw new functions.https.HttpsError(
                "not-found",
                "Промокод не найден",
            );
          }
          const promo = promoDoc.data() || {};

          if (!isPromoActive(promo)) {
            throw new functions.https.HttpsError(
                "failed-precondition",
                promo.isActive === false ?
                  "Промокод отключён" :
                  "Срок действия промокода истёк",
            );
          }
          if (isPromoExhausted(promo)) {
            throw new functions.https.HttpsError(
                "failed-precondition",
                "Лимит активаций промокода исчерпан",
            );
          }
          if (redemptionDoc.exists) {
            throw new functions.https.HttpsError(
                "already-exists",
                "Этот промокод уже активирован",
            );
          }

          const gift = resolvePromoGift(promo);
          if (!gift) {
            throw new functions.https.HttpsError(
                "failed-precondition",
                "Промокод не содержит подарка",
            );
          }
          const {minutesGifted, validForDays} = gift;

          const userData = userDoc.exists ? userDoc.data() : {};
          const giftPayload = buildPromoGrantPayload({
            userData,
            minutesGifted,
            validForDays,
          });
          if (!giftPayload) {
            throw new functions.https.HttpsError(
                "internal",
                "Не удалось рассчитать подарок",
            );
          }

          tx.set(redemptionRef, {
            uid,
            redeemedAt: admin.firestore.FieldValue.serverTimestamp(),
            minutesGifted,
            validForDays,
            code: promo.code || rawCode,
          });

          tx.update(promoRef, {
            usageCount: admin.firestore.FieldValue.increment(1),
          });

          tx.update(userRef, {
            giftMinutes: giftPayload,
          });

          const transactionRef = db.collection("transactions").doc();
          tx.set(transactionRef, {
            userId: userRef,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            type: "promocode",
            status: "completed",
            promoCodeDocRef: promoRef,
            promoCode: promo.code || rawCode,
            minutesPurchased: minutesGifted,
          });

          return {
            minutesGifted,
            validForDays,
            expiresAtMs: giftPayload.expiresAt.toMillis(),
            remainingMinutes: giftPayload.minutes,
          };
        });

        safeConsole.log("promo_code_redeem_succeeded", {
          uid,
          counts: {minutesGifted: result.minutesGifted},
        });

        return {
          status: "granted",
          minutesGifted: result.minutesGifted,
          validForDays: result.validForDays,
          expiresAtMs: result.expiresAtMs,
          remainingMinutes: result.remainingMinutes,
        };
      } catch (err) {
        if (err instanceof functions.https.HttpsError) {
          throw err;
        }
        safeConsole.error("promo_code_redeem_failed", {error: err});
        throw new functions.https.HttpsError(
            "internal",
            "Не удалось активировать промокод",
        );
      }
    });
