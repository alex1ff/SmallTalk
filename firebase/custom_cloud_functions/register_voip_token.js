const functions = require("firebase-functions/v1");
const {
  clearUserVoipTokens,
  saveUserVoipToken,
} = require("./voip_tokens");

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
    return { status: "cleared" };
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

  return { status: "ok" };
});
