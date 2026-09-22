const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const axios = require("axios");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "create_payment_session"});

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

function buildProviderErrorInfo(error) {
  const responseData = error?.response?.data || {};
  const providerDetails =
    responseData && typeof responseData.details === "object" ?
      responseData.details :
      {};

  const providerCode = extractString(
    providerDetails.ErrorCode || responseData.errorCode,
  );
  const providerMessage =
    extractString(providerDetails.Details) ||
    extractString(providerDetails.Message) ||
    extractString(responseData.details) ||
    extractString(responseData.error) ||
    extractString(error?.message);

  let userMessage = "Не удалось создать платеж. Попробуйте еще раз.";
  let errorCode = "internal";

  if (providerCode === "204") {
    userMessage =
      "Платежный сервис отклонил запрос. Проверьте настройки T-Bank.";
    errorCode = "failed-precondition";
  } else if (providerMessage) {
    userMessage = `Не удалось создать платеж: ${providerMessage}`;
    errorCode = "failed-precondition";
  }

  return {
    errorCode,
    providerCode,
    providerMessage,
    responseData,
    userMessage,
  };
}

function buildErrorDetails({
  userMessage,
  providerCode = null,
  providerMessage = null,
  transactionRefPath = null,
  reason = null,
}) {
  return {
    userMessage,
    providerCode,
    providerMessage,
    transactionRefPath,
    reason,
  };
}

exports.createPaymentSession = functions.https.onCall(async (data, context) => {
  safeLog.log("payment_session_started");

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
  const baseTransactionData = {
    userId: userRef,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    type: "purchase",
    packageDocRef: packageRef,
    amount: amountRubles,
    amount_ST: amountSmallTalks,
    minutesPurchased: minutesPurchased,
    paymentId: null,
  };

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
      await transactionRef.set({
        ...baseTransactionData,
        status: "failed",
        paymentInitErrorMessage:
          "Payment session was created without payment URL or payment ID",
        paymentInitFailedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      throw new functions.https.HttpsError(
        "internal",
        "Payment session was created without payment URL or payment ID",
        buildErrorDetails({
          userMessage: "Не удалось открыть оплату. Попробуйте еще раз.",
          transactionRefPath: transactionRef.path,
          reason: "missing_payment_url_or_id",
        }),
      );
    }

    await transactionRef.set({
      ...baseTransactionData,
      status: "pending",
      paymentId: paymentId,
    });

    safeLog.log("payment_session_created", {
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
    const providerError = buildProviderErrorInfo(error);

    safeLog.error("payment_session_failed", {
      uid,
      packageId,
      transactionId: transactionRef.id,
      providerCode: providerError.providerCode,
      error,
    });

    await transactionRef.set({
      ...baseTransactionData,
      status: "failed",
      paymentInitErrorCode: providerError.providerCode,
      paymentInitErrorMessage:
        providerError.providerMessage || "Unable to create payment session",
      paymentInitFailedAt: admin.firestore.FieldValue.serverTimestamp(),
    }).catch((updateError) => {
      safeLog.error("payment_failure_persist_failed", {error: updateError});
    });

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      providerError.errorCode,
      providerError.userMessage,
      buildErrorDetails({
        userMessage: providerError.userMessage,
        providerCode: providerError.providerCode,
        providerMessage: providerError.providerMessage,
        transactionRefPath: transactionRef.path,
        reason: "init_payment_failed",
      }),
    );
  }
});
