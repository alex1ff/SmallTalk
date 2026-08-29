const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  applyTransferEvent,
  transactionDocumentIdForEvent,
} = require("./revenue_cat_webhook").__private__;

exports.retryPendingRevenueCatTransfers = functions.pubsub
    .schedule("every 5 minutes")
    .onRun(async () => {
      const db = admin.firestore();
      const snapshot = await db.collection("revenueCatPendingTransfers")
          .where("status", "==", "pending")
          .orderBy("updatedAt", "asc")
          .limit(100)
          .get();
      let resolved = 0;
      for (const pending of snapshot.docs) {
        const data = pending.data() || {};
        const eventId = typeof data.eventId === "string" ? data.eventId : "";
        if (!eventId) continue;
        const parsed = {
          type: "TRANSFER",
          eventId,
          appUserId: null,
          productId: data.productId || null,
          newProductId: data.newProductId || null,
          purchasedAtMs: null,
          expirationAtMs: data.expirationAtMs || null,
          entitlementIds: [],
          store: data.store || null,
          storeShort: data.store === "APP_STORE" ? "app_store" :
            data.store === "PLAY_STORE" ? "play_store" : "unknown",
          environment: data.environment || null,
          originalTransactionId: data.originalTransactionId || null,
          eventTimestampMs: data.eventTimestampMs || null,
          revenueCatAppId: data.revenueCatAppId || null,
          periodType: data.periodType || null,
          cancelReason: null,
          priceInPurchasedCurrency: null,
          currency: null,
          transferredFrom: Array.isArray(data.transferredFrom) ?
            data.transferredFrom : [],
          transferredTo: Array.isArray(data.transferredTo) ?
            data.transferredTo : [],
        };
        const result = await applyTransferEvent({
          db,
          parsed,
          transactionRef: db.collection("transactions").doc(
              transactionDocumentIdForEvent(eventId),
          ),
        });
        if (!result.pending && !result.duplicate) resolved += 1;
      }
      console.log("✅ Pending RevenueCat transfers retried", {
        scanned: snapshot.size,
        resolved,
      });
      return null;
    });
