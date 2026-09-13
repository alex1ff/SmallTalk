const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const axios = require("axios");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "get_deepgram_token"});
const {
  getCredentialTtlSeconds,
  isAcceptedSessionCredentialParticipant,
  isCredentialSessionJoinable,
} = require("./video_sessions_shared");

const deepgramSecrets = ["DEEPGRAM_API_KEY"];
const DEEPGRAM_GRANT_URL = "https://api.deepgram.com/v1/auth/grant";
const DEFAULT_TTL_SECONDS = 600;

function shouldFallbackToApiKey(error) {
  const status = error?.response?.status;
  const errCode = String(error?.response?.data?.err_code || "").toUpperCase();
  const errMsg = String(error?.response?.data?.err_msg || "").toLowerCase();

  if (status !== 403) return false;

  return (
    errCode === "FORBIDDEN" ||
    errCode === "INSUFFICIENT_PERMISSIONS" ||
    errMsg.includes("insufficient permissions")
  );
}

function isDeepgramGrantConfigurationError(error) {
  return shouldFallbackToApiKey(error);
}

exports.getDeepgramToken = functions
  .runWith({secrets: deepgramSecrets})
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
      );
    }

    const {sessionId} = data || {};
    if (!sessionId || typeof sessionId !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "sessionId is required",
      );
    }

    const userId = context.auth.uid;
    const sessionRef = admin
      .firestore()
      .collection("videoSessions")
      .doc(sessionId);
    const sessionSnap = await sessionRef.get();

    if (!sessionSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Session not found");
    }

    const sessionData = sessionSnap.data() || {};
    if (!isAcceptedSessionCredentialParticipant(sessionData, userId)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Not allowed to access this session",
      );
    }

    if (!isCredentialSessionJoinable(sessionData)) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `Session is not joinable (status: ${sessionData.status || "unknown"})`,
      );
    }

    const apiKey = process.env.DEEPGRAM_API_KEY
      ? String(process.env.DEEPGRAM_API_KEY).trim()
      : "";
    if (!apiKey) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "DEEPGRAM_API_KEY secret is not configured",
      );
    }

    const ttlSeconds = getCredentialTtlSeconds(
      sessionData,
      DEFAULT_TTL_SECONDS,
    );
    if (ttlSeconds < 1) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Session credential window has expired",
      );
    }

    try {
      const response = await axios.post(
        DEEPGRAM_GRANT_URL,
        {ttl_seconds: ttlSeconds},
        {
          headers: {
            Authorization: `Token ${apiKey}`,
            "Content-Type": "application/json",
            "User-Agent": "SmallTalk-Functions/1.0",
          },
          timeout: 5000,
        },
      );

      const token = response?.data?.access_token;
      if (!token || typeof token !== "string") {
        throw new Error("Deepgram grant response did not include access_token");
      }

      return {
        status: "ok",
        sessionId,
        accessToken: token,
        credentialType: "temporary_token",
        ttlSeconds,
      };
    } catch (error) {
      if (isDeepgramGrantConfigurationError(error)) {
        safeLog.warn("deepgram_grant_forbidden", {
          sessionId,
          userId,
          statusCode: error?.response?.status,
        });

        throw new functions.https.HttpsError(
          "failed-precondition",
          "Deepgram temporary token grants are not enabled",
          {reason: "deepgram_token_grant_forbidden"},
        );
      }

      safeLog.error("deepgram_token_failed", {
        sessionId,
        userId,
        statusCode: error?.response?.status,
        error,
      });
      throw new functions.https.HttpsError(
        "internal",
        "Failed to mint Deepgram access token",
      );
    }
  });

exports.__private__ = {
  isDeepgramGrantConfigurationError,
  shouldFallbackToApiKey,
};
