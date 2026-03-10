const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

const INIT_PAYMENT_URL =
  process.env.INIT_PAYMENT_URL ||
  "https://init-payment-1024626146715.europe-west1.run.app";
const PAYMENT_DESCRIPTION = "Пополнение баланса";
const REQUEST_TIMEOUT_MS = 15000;

function toFiniteNumber(value) {
  const numericValue = Number(value);
  return Number.isFinite(numericValue) ? numericValue : null;
}

function extractString(value) {
  if (typeof value === "string" && value.trim().length > 0) {
    return value.trim();
  }

  if (typeof value === "number" && Number.isFinite(value)) {
    return String(value);
  }

  return null;
}

exports.createPaymentSession = functions.https.onCall(async (data, context) => {
  console.log("💳 createPaymentSession started");

  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  const packageId =
    typeof data?.packageId === "string" ? data.packageId.trim() : "";
  if (!packageId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Package ID is required",
    );
  }

  const db = admin.firestore();
  const uid = context.auth.uid;
  const userRef = db.collection("users").doc(uid);
  const packageRef = db.collection("packages").doc(packageId);
  const packageSnap = await packageRef.get();

  if (!packageSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Package not found");
  }

  const packageData = packageSnap.data() || {};
  const amountRubles = toFiniteNumber(packageData.price);
  const amountSmallTalks = toFiniteNumber(packageData.smallTalks);
  const minutesPurchased = toFiniteNumber(packageData.minutes);

  if (amountRubles == null || amountRubles <= 0) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Package price is invalid",
    );
  }

  const transactionRef = db.collection("transactions").doc();
  await transactionRef.set({
    userId: userRef,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    type: "purchase",
    status: "pending",
    packageDocRef: packageRef,
    amount: amountRubles,
    amount_ST: amountSmallTalks,
    minutesPurchased: minutesPurchased,
    paymentId: null,
  });

  try {
    const amountInKopeks = Math.round(amountRubles * 100);
    const initPaymentResponse = await axios.post(
      INIT_PAYMENT_URL,
      {
        amount: amountInKopeks,
        description: PAYMENT_DESCRIPTION,
        orderId: transactionRef.id,
        customerKey: uid,
      },
      {
        timeout: REQUEST_TIMEOUT_MS,
        headers: {
          "Content-Type": "application/json",
        },
      },
    );

    const responseData = initPaymentResponse.data || {};
    const paymentUrl =
      extractString(responseData.paymentUrl) ||
      extractString(responseData.paymentURL) ||
      extractString(responseData.url);
    const paymentId =
      extractString(responseData.paymentId) ||
      extractString(responseData.PaymentId);

    if (!paymentUrl || !paymentId) {
      await transactionRef.update({
        status: "failed",
      });
      throw new functions.https.HttpsError(
        "internal",
        "Payment session was created without payment URL or payment ID",
      );
    }

    await transactionRef.update({
      paymentId: paymentId,
    });

    console.log("💳 createPaymentSession succeeded", {
      uid,
      packageId,
      transactionId: transactionRef.id,
      paymentId,
    });

    return {
      paymentUrl,
      paymentId,
      transactionId: transactionRef.id,
      transactionRefPath: transactionRef.path,
    };
  } catch (error) {
    console.error("❌ createPaymentSession failed", {
      uid,
      packageId,
      transactionId: transactionRef.id,
      error:
        error?.response?.data ||
        error?.message ||
        error,
    });

    await transactionRef.update({
      status: "failed",
    }).catch((updateError) => {
      console.error("❌ Failed to mark transaction as failed", updateError);
    });

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      "internal",
      "Unable to create payment session",
    );
  }
});
