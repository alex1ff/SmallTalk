const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {
  createMeetingToken,
  getRoomNameFromUrl,
} = require("./daily_room");

exports.getSessionTokens = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  const { sessionId } = data || {};
  if (!sessionId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "sessionId is required",
    );
  }

  const sessionDoc = await admin
    .firestore()
    .collection("videoSessions")
    .doc(sessionId)
    .get();

  if (!sessionDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Session not found");
  }

  const sessionData = sessionDoc.data();
  const userId = context.auth.uid;
  const isStudent = sessionData.studentId === userId;
  const isTutor = sessionData.tutorId === userId;

  if (!isStudent && !isTutor) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Not allowed to access this session",
    );
  }

  const roomUrl = sessionData.dailyRoomUrl || null;
  if (!roomUrl) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Room is not ready yet",
    );
  }

  const roomName =
    sessionData.dailyRoomName || getRoomNameFromUrl(sessionData.dailyRoomUrl);
  if (!roomName) {
    throw new functions.https.HttpsError(
      "internal",
      "Unable to resolve room name",
    );
  }

  let userName = isStudent
    ? sessionData.studentInfo?.name
    : sessionData.tutorInfo?.name;

  if (!userName) {
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    if (userDoc.exists) {
      userName = userDoc.data().display_name;
    }
  }

  userName = userName || (isStudent ? "Student" : "Tutor");

  const meetingToken = await createMeetingToken({
    roomName,
    expSeconds: 60 * 60,
    isOwner: isStudent,
    userId,
    userName,
  });

  return {
    status: "ok",
    sessionId,
    roomUrl,
    roomName,
    meetingToken,
    isOwner: isStudent,
  };
});
