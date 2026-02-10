const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {
  createDailyRoom,
  createMeetingToken,
  getDailyRoom,
  getRoomNameFromUrl,
} = require("./daily_room");

const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];

exports.getSessionTokens = functions
  .runWith({ secrets: dailySecrets })
  .https.onCall(async (data, context) => {
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

  let roomUrl = sessionData.dailyRoomUrl || null;
  if (!roomUrl) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Room is not ready yet",
    );
  }

  let roomName =
    sessionData.dailyRoomName || getRoomNameFromUrl(sessionData.dailyRoomUrl);
  const derivedName = getRoomNameFromUrl(roomUrl);
  if (derivedName && roomName !== derivedName) {
    console.log("⚠️ Room name mismatch, using name from URL", {
      roomName,
      derivedName,
    });
    roomName = derivedName;
    try {
      await sessionDoc.ref.update({
        dailyRoomName: roomName,
        "sessionMetadata.roomNameFixedAt": Date.now(),
      });
    } catch (e) {
      console.error("⚠️ Failed to update corrected room name:", e.message);
    }
  }
  if (!roomName) {
    throw new functions.https.HttpsError(
      "internal",
      "Unable to resolve room name",
    );
  }

  const existingRoom = await getDailyRoom(roomName);
  if (!existingRoom) {
    const dailyRoom = await createDailyRoom({
      language: sessionData.language || "en",
      studentId: sessionData.studentId,
      tutorId: sessionData.tutorId,
      studentName: sessionData.studentInfo?.name || "Student",
      tutorName: sessionData.tutorInfo?.name || "Tutor",
      expSeconds: 15 * 60,
    });
    roomUrl = dailyRoom.url;
    roomName = dailyRoom.name;
    try {
      await sessionDoc.ref.update({
        dailyRoomUrl: roomUrl,
        dailyRoomName: roomName,
        "sessionMetadata.roomRecoveredAt": Date.now(),
        "sessionMetadata.roomPrecreated": false,
      });
    } catch (e) {
      console.error("⚠️ Failed to update recovered room info:", e.message);
    }
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
