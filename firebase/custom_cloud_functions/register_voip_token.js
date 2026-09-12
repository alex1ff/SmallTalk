const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  clearUserVoipTokens,
  getReadOnlyUserVoipTokenState,
  normalizeVoipTokenType,
  removeUserVoipToken,
  saveUserVoipToken,
} = require("./voip_tokens");

function normalizePlatform(value) {
  const normalized = typeof value === "string" ?
    value.trim().toLowerCase() :
    "";
  return ["ios", "android"].includes(normalized) ? normalized : "";
}

function buildMatchProtocolCapabilityUpdate({
  tokenType,
  platform,
  requestedVersion = 1,
  tokenState = {},
  nowMillis = Date.now(),
} = {}) {
  const normalizedType = normalizeVoipTokenType(tokenType);
  const normalizedPlatform = normalizePlatform(platform) ||
    (normalizedType === "pushkit" || tokenState.hasVoipPushToken === true ?
      "ios" : "");
  const requestedV2 = Number(requestedVersion) >= 2;
  const capabilityExpiresAtMillis = normalizedPlatform === "android" ?
    Number(tokenState.freshFcmTokenExpiresAtMillis) :
    Number(tokenState.freshVoipPushTokenExpiresAtMillis);
  const hasRequiredFreshToken = normalizedPlatform === "android" ?
    tokenState.hasFreshFcmToken === true :
    tokenState.hasFreshVoipPushToken === true;
  const callKitCapable = requestedV2 &&
    hasRequiredFreshToken &&
    Number.isFinite(capabilityExpiresAtMillis) &&
    capabilityExpiresAtMillis > nowMillis;
  return {
    matchProtocolVersion: callKitCapable ? 2 : 1,
    v2CallKitCapable: callKitCapable,
    v2CallKitCapabilityExpiresAt: callKitCapable ?
      admin.firestore.Timestamp.fromMillis(
        capabilityExpiresAtMillis,
      ) :
      null,
    matchProtocolPlatform: normalizedPlatform || null,
    matchProtocolUpdatedAt:
      admin.firestore.FieldValue.serverTimestamp(),
  };
}

exports.registerVoipToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  const userId = context.auth.uid;
  if (data?.clearAll === true) {
    await clearUserVoipTokens(userId);
    await admin.firestore().collection("users").doc(userId).set({
      matchProtocolVersion: 1,
      v2CallKitCapable: false,
      v2CallKitCapabilityExpiresAt: null,
      matchProtocolUpdatedAt:
        admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return { status: "cleared" };
  }

  if (data?.removeTokenType) {
    const removed = await removeUserVoipToken(
      userId,
      data.removeTokenType,
    );
    if (!removed) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "removeTokenType must be fcm or pushkit",
      );
    }
    const firestore = admin.firestore();
    const userSnap = await firestore.collection("users").doc(userId).get();
    const tokenState = await getReadOnlyUserVoipTokenState(
      userId,
      userSnap.exists ? userSnap.data() || {} : {},
      firestore,
    );
    await firestore.collection("users").doc(userId).set(
      buildMatchProtocolCapabilityUpdate({
        tokenType: data.removeTokenType,
        platform: data?.platform,
        requestedVersion: data?.matchProtocolVersion,
        tokenState,
      }),
      {merge: true},
    );
    return {status: "removed"};
  }

  const saved = await saveUserVoipToken(
    userId,
    data?.tokenType,
    data?.token,
  );
  if (!saved) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "tokenType and token are required",
    );
  }

  const firestore = admin.firestore();
  const userSnap = await firestore.collection("users").doc(userId).get();
  const tokenState = await getReadOnlyUserVoipTokenState(
    userId,
    userSnap.exists ? userSnap.data() || {} : {},
    firestore,
  );
  await firestore.collection("users").doc(userId).set(
    buildMatchProtocolCapabilityUpdate({
      tokenType: data?.tokenType,
      platform: data?.platform,
      requestedVersion: data?.matchProtocolVersion,
      tokenState,
    }),
    {merge: true},
  );

  return { status: "ok" };
});

exports.__private__ = {
  buildMatchProtocolCapabilityUpdate,
  normalizePlatform,
};
