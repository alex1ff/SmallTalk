const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "request_withdrawal"});
const {
  isApprovedTeacher,
} = require("./video_sessions_shared");

const REQUEST_TIMEOUT_SECONDS = 30;

function normalizeCardId(value) {
  if (typeof value !== "string") return "";
  const normalized = value.trim();
  if (!normalized || normalized.includes("/")) return "";
  return normalized;
}

function buildRejectedDecision(code, message) {
  return {
    ok: false,
    code,
    message,
  };
}

function readPositiveBalance(userData = {}) {
  const balance = Number(userData.balance_NS);
  return Number.isFinite(balance) && balance > 0 ? balance : 0;
}

function buildWithdrawalDecision({
  userExists,
  userData = {},
  cardExists,
  cardId,
}) {
  const normalizedCardId = normalizeCardId(cardId);
  if (!normalizedCardId) {
    return buildRejectedDecision("invalid-argument", "Card is required");
  }
  if (!userExists) {
    return buildRejectedDecision("failed-precondition", "User not found");
  }
  if (!isApprovedTeacher(userData)) {
    return buildRejectedDecision(
        "permission-denied",
        "Withdrawals are available only after teacher approval",
    );
  }
  if (!cardExists) {
    return buildRejectedDecision("failed-precondition", "Card not found");
  }

  const amount = readPositiveBalance(userData);
  if (amount <= 0) {
    return buildRejectedDecision(
        "failed-precondition",
        "No available balance to withdraw",
    );
  }

  return {
    ok: true,
    amount,
    cardId: normalizedCardId,
    response: {
      status: "created",
      amount,
    },
  };
}

function throwCallableError(decision) {
  throw new functions.https.HttpsError(decision.code, decision.message);
}

exports.__private__ = {
  buildWithdrawalDecision,
  normalizeCardId,
  readPositiveBalance,
};

exports.requestWithdrawal = functions
    .runWith({timeoutSeconds: REQUEST_TIMEOUT_SECONDS, memory: "256MB"})
    .https.onCall(async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be authenticated",
        );
      }

      const uid = context.auth.uid;
      const cardId = normalizeCardId(data?.cardId);
      const db = admin.firestore();
      const userRef = db.collection("users").doc(uid);
      const cardRef = userRef.collection("cards").doc(cardId || "_invalid");
      const transactionRef = db.collection("transactions").doc();

      try {
        const result = await db.runTransaction(async (tx) => {
          const [userDoc, cardDoc] = await Promise.all([
            tx.get(userRef),
            tx.get(cardRef),
          ]);
          const decision = buildWithdrawalDecision({
            userExists: userDoc.exists,
            userData: userDoc.exists ? userDoc.data() : {},
            cardExists: cardDoc.exists,
            cardId,
          });

          if (!decision.ok) {
            throwCallableError(decision);
          }

          tx.set(transactionRef, {
            userId: userRef,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            type: "withdrawal",
            status: "pending",
            amount: decision.amount,
            card: cardRef,
          });
          tx.update(userRef, {
            balance_NS: admin.firestore.FieldValue.delete(),
          });

          return {
            ...decision.response,
            transactionId: transactionRef.id,
          };
        });

        return result;
      } catch (err) {
        if (err instanceof functions.https.HttpsError) {
          throw err;
        }
        safeLog.error("request_withdrawal_failed", {uid, error: err});
        throw new functions.https.HttpsError(
            "internal",
            "Unable to create withdrawal request",
        );
      }
    });
