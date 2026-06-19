const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

const {
  REGISTRATION_GIFT_MINUTES,
  buildRegistrationGrantPayload,
} = require("./gift_minutes_shared");

const REQUEST_TIMEOUT_SECONDS = 30;
const REGISTRATION_GIFT_MAX_ACCOUNT_AGE_MS = 24 * 60 * 60 * 1000;

function hasMapValue(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function buildRejectedDecision(code, message) {
  return {
    ok: false,
    code,
    message,
  };
}

function readAuthCreatedAtMillis(authUser) {
  const creationTime = authUser?.metadata?.creationTime;
  const createdAtMillis = Date.parse(creationTime || "");
  return Number.isFinite(createdAtMillis) ? createdAtMillis : null;
}

function isWithinRegistrationGiftWindow({
  authCreatedAtMillis,
  nowMillis,
}) {
  if (!Number.isFinite(authCreatedAtMillis)) {
    return false;
  }
  const ageMs = nowMillis - authCreatedAtMillis;
  return ageMs >= 0 && ageMs <= REGISTRATION_GIFT_MAX_ACCOUNT_AGE_MS;
}

function hasOwnField(data, fieldName) {
  return Object.prototype.hasOwnProperty.call(data || {}, fieldName);
}

function buildClaimRegistrationGiftDecision({
  userExists,
  claimExists = false,
  userData = {},
  now = new Date(),
  authCreatedAtMillis = now.getTime(),
}) {
  if (!userExists) {
    return buildRejectedDecision(
        "failed-precondition",
        "User document must exist before claiming registration gift",
    );
  }

  if (userData.role && userData.role !== "student") {
    return buildRejectedDecision(
        "failed-precondition",
        "Registration gift is only available to student accounts",
    );
  }

  if (!isWithinRegistrationGiftWindow({
    authCreatedAtMillis,
    nowMillis: now.getTime(),
  })) {
    return buildRejectedDecision(
        "failed-precondition",
        "Registration gift is only available for new accounts",
    );
  }

  const userUpdate = userData.role === "student" ? {} : {role: "student"};
  if (hasOwnField(userData, "availabilityToday")) {
    userUpdate.availabilityToday = admin.firestore.FieldValue.delete();
  }
  const existingGift = userData.giftMinutes;
  if (claimExists || hasMapValue(existingGift)) {
    return {
      ok: true,
      giftPayload: null,
      userUpdate,
      claimStatus: claimExists ? "already_claimed" : "already_has_gift",
      response: {
        status: claimExists ? "already_claimed" : "already_has_gift",
        updated: false,
        roleUpdated: Object.keys(userUpdate).length > 0,
      },
    };
  }

  const giftPayload = buildRegistrationGrantPayload(now);
  userUpdate.giftMinutes = giftPayload;
  return {
    ok: true,
    giftPayload,
    userUpdate,
    claimStatus: "granted",
    response: {
      status: "granted",
      updated: true,
      roleUpdated: userData.role !== "student",
      minutesGranted: REGISTRATION_GIFT_MINUTES,
      expiresAtMs: giftPayload.expiresAt.toMillis(),
      remainingMinutes: giftPayload.minutes,
    },
  };
}

function throwCallableError(decision) {
  throw new functions.https.HttpsError(decision.code, decision.message);
}

exports.__private__ = {
  REGISTRATION_GIFT_MAX_ACCOUNT_AGE_MS,
  buildClaimRegistrationGiftDecision,
  hasMapValue,
  isWithinRegistrationGiftWindow,
  readAuthCreatedAtMillis,
};

exports.claimRegistrationGift = functions
    .runWith({timeoutSeconds: REQUEST_TIMEOUT_SECONDS, memory: "256MB"})
    .https.onCall(async (_data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be authenticated",
        );
      }

      const uid = context.auth.uid;
      const authUser = await admin.auth().getUser(uid);
      const authCreatedAtMillis = readAuthCreatedAtMillis(authUser);
      const db = admin.firestore();
      const userRef = db.collection("users").doc(uid);
      const claimRef = db.collection("registrationGiftClaims").doc(uid);
      const transactionRef = db
          .collection("transactions")
          .doc(`registration_gift_${uid}`);

      try {
        return await db.runTransaction(async (tx) => {
          const [userDoc, claimDoc] = await Promise.all([
            tx.get(userRef),
            tx.get(claimRef),
          ]);
          const decision = buildClaimRegistrationGiftDecision({
            userExists: userDoc.exists,
            claimExists: claimDoc.exists,
            userData: userDoc.exists ? userDoc.data() : {},
            authCreatedAtMillis,
          });

          if (!decision.ok) {
            throwCallableError(decision);
          }

          if (!claimDoc.exists) {
            tx.set(
                claimRef,
                {
                  uid,
                  status: decision.claimStatus,
                  claimedAt: admin.firestore.FieldValue.serverTimestamp(),
                  minutesGranted: decision.giftPayload ?
                    REGISTRATION_GIFT_MINUTES :
                    0,
                },
                {merge: true},
            );
          }

          if (Object.keys(decision.userUpdate).length > 0) {
            tx.update(userRef, decision.userUpdate);
          }

          if (decision.giftPayload) {
            tx.set(
                transactionRef,
                {
                  userId: userRef,
                  createdAt: admin.firestore.FieldValue.serverTimestamp(),
                  type: "bonus",
                  status: "completed",
                  minutesPurchased: REGISTRATION_GIFT_MINUTES,
                  source: "registration",
                },
                {merge: true},
            );
          }

          return decision.response;
        });
      } catch (err) {
        if (err instanceof functions.https.HttpsError) {
          throw err;
        }
        console.error("claimRegistrationGift failed", {uid, err});
        throw new functions.https.HttpsError(
            "internal",
            "Unable to claim registration gift",
        );
      }
    });
