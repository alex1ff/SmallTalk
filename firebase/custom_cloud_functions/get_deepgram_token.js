const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

const deepgramSecrets = ["DEEPGRAM_API_KEY"];
const DEEPGRAM_GRANT_URL = "https://api.deepgram.com/v1/auth/grant";
const DEFAULT_TTL_SECONDS = 60;

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
    const sessionRef = admin.firestore().collection("videoSessions").doc(sessionId);
    const sessionSnap = await sessionRef.get();

    if (!sessionSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Session not found");
    }

    const sessionData = sessionSnap.data() || {};
    const isStudent = sessionData.studentId === userId;
    const isTutor = sessionData.tutorId === userId;
    if (!isStudent && !isTutor) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Not allowed to access this session",
      );
    }

    if (["ended", "cancelled"].includes(sessionData.status)) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `Session is not active (status: ${sessionData.status})`,
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

    try {
      const response = await axios.post(
        DEEPGRAM_GRANT_URL,
        {ttl_seconds: DEFAULT_TTL_SECONDS},
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
        ttlSeconds: DEFAULT_TTL_SECONDS,
      };
    } catch (error) {
      console.error("❌ Failed to create Deepgram access token:", {
        sessionId,
        userId,
        status: error?.response?.status,
        data: error?.response?.data,
        message: error?.message,
      });
      throw new functions.https.HttpsError(
        "internal",
        "Failed to mint Deepgram access token",
      );
    }
  });
