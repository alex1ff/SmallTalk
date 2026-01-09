const functions = require("firebase-functions");
const admin = require("firebase-admin");

/*
Compatibility function: getSessionTokens
Returns room URL/token for an existing session.
*/

exports.getSessionTokens = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
      );
    }

    const userId = context.auth.uid;
    const { sessionId, callId } = data || {};
    const resolvedSessionId = sessionId || callId;

    if (!resolvedSessionId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Session ID is required",
      );
    }

    const sessionDoc = await admin
      .firestore()
      .collection("videoSessions")
      .doc(resolvedSessionId)
      .get();

    if (!sessionDoc.exists) {
      return {
        status: "not_found",
        sessionId: resolvedSessionId,
      };
    }

    const sessionData = sessionDoc.data();

    if (
      sessionData.studentId !== userId &&
      sessionData.tutorId !== userId
    ) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "You are not a participant of this session",
      );
    }

    return {
      status: sessionData.status || "unknown",
      sessionId: resolvedSessionId,
      roomUrl: sessionData.dailyRoomUrl || null,
      roomName: sessionData.dailyRoomName || null,
      meetingToken: sessionData.meetingToken || null,
      tutorInfo: sessionData.tutorInfo || null,
    };
  } catch (error) {
    console.error("❌ Error in getSessionTokens:", error);
    if (error.code) throw error;
    throw new functions.https.HttpsError("internal", error.message);
  }
});
