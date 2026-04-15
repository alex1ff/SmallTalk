const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  buildUniversalSessionPolicy,
  getSessionParticipantIds,
  isSessionParticipant,
} = require("./video_sessions_shared");

function createSessionExtensionError(code, message) {
  const error = new Error(message);
  error.code = code;
  return error;
}

function toMillis(value) {
  if (!value) return 0;
  if (typeof value?.toMillis === "function") {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  const numericValue = Number(value);
  return Number.isFinite(numericValue) ? numericValue : 0;
}

function buildSessionExtensionMutation({
  sessionData = {},
  userId,
  nowMillis = Date.now(),
}) {
  if (!isSessionParticipant(sessionData, userId)) {
    throw createSessionExtensionError(
      "permission-denied",
      "You are not a participant of this session",
    );
  }

  if (!["active", "connecting"].includes(sessionData.status)) {
    throw createSessionExtensionError(
      "failed-precondition",
      "Session is not active",
    );
  }

  if (
    !sessionData.sessionPolicy ||
    typeof sessionData.sessionPolicy !== "object" ||
    Array.isArray(sessionData.sessionPolicy)
  ) {
    throw createSessionExtensionError(
      "failed-precondition",
      "Session extension is not available for this session",
    );
  }

  const sessionPolicy = buildUniversalSessionPolicy(sessionData.sessionPolicy);
  if (sessionPolicy.extensionApproved) {
    return {
      status: "already_extended",
      sessionPolicy,
      expiresAtMillis: toMillis(sessionData.expiresAt),
    };
  }

  const expiresAtMillis = toMillis(sessionData.expiresAt);
  if (expiresAtMillis <= 0) {
    throw createSessionExtensionError(
      "failed-precondition",
      "Session expiry is missing",
    );
  }

  if (nowMillis >= expiresAtMillis) {
    throw createSessionExtensionError(
      "failed-precondition",
      "Session extension window has expired",
    );
  }

  const remainingSeconds = Math.max(
    0,
    Math.floor((expiresAtMillis - nowMillis) / 1000),
  );
  if (remainingSeconds > sessionPolicy.warningLeadSeconds) {
    throw createSessionExtensionError(
      "failed-precondition",
      "Session extension is not available yet",
    );
  }

  const participantIds = getSessionParticipantIds(sessionData);
  if (participantIds.length < 2) {
    throw createSessionExtensionError(
      "failed-precondition",
      "Session participants are incomplete",
    );
  }

  if (sessionPolicy.maxExtensionCount <= 0 || sessionPolicy.extensionSeconds <= 0) {
    throw createSessionExtensionError(
      "failed-precondition",
      "Session extension is disabled",
    );
  }

  if (sessionPolicy.extensionRequests[userId] === true) {
    return {
      status: "already_requested",
      sessionPolicy,
      expiresAtMillis,
    };
  }

  const extensionRequests = {
    ...sessionPolicy.extensionRequests,
    [userId]: true,
  };
  const approved = participantIds.every(
    (participantId) => extensionRequests[participantId] === true,
  );

  const nextSessionPolicy = {
    ...sessionPolicy,
    extensionRequests,
    extensionApproved: approved,
    effectiveLimitSeconds: approved
      ? sessionPolicy.baseLimitSeconds + sessionPolicy.extensionSeconds
      : sessionPolicy.effectiveLimitSeconds,
  };

  return {
    status: approved ? "approved" : "pending_partner",
    sessionPolicy: nextSessionPolicy,
    expiresAtMillis: approved
      ? expiresAtMillis + sessionPolicy.extensionSeconds * 1000
      : expiresAtMillis,
  };
}

exports.requestSessionExtension = functions.https.onCall(
  async (data, context) => {
    try {
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated",
        );
      }

      const userId = context.auth.uid;
      const sessionId = typeof data?.sessionId === "string" ?
        data.sessionId.trim() :
        "";

      if (!sessionId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Session ID is required",
        );
      }

      const db = admin.firestore();
      const sessionRef = db.collection("videoSessions").doc(sessionId);
      const txResult = await db.runTransaction(async (transaction) => {
        const sessionSnap = await transaction.get(sessionRef);
        if (!sessionSnap.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "Video session not found",
          );
        }

        const mutation = buildSessionExtensionMutation({
          sessionData: sessionSnap.data() || {},
          userId,
          nowMillis: Date.now(),
        });

        if (mutation.status === "pending_partner" || mutation.status === "approved") {
          transaction.update(sessionRef, {
            sessionPolicy: mutation.sessionPolicy,
            expiresAt: admin.firestore.Timestamp.fromMillis(
              mutation.expiresAtMillis,
            ),
          });
        }

        return mutation;
      });

      return {
        status: txResult.status,
        expiresAt: txResult.expiresAtMillis,
        sessionPolicy: txResult.sessionPolicy,
      };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      if (error?.code) {
        throw new functions.https.HttpsError(
          error.code,
          error.message || "Failed to request session extension",
        );
      }
      throw new functions.https.HttpsError(
        "internal",
        error.message || "Failed to request session extension",
      );
    }
  },
);

exports.__private__ = {
  buildSessionExtensionMutation,
  createSessionExtensionError,
  toMillis,
};
