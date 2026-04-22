const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  createDailyRoom,
  createMeetingToken,
  DAILY_ROOM_CONFIG_VERSION,
  getDailyRoom,
  getRoomNameFromUrl,
  isDailyRoomConfigCompatible,
} = require("./daily_room");
const { getRequesterId, isSessionParticipant } = require("./video_sessions_shared");

const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const PRECREATED_ROOM_VALIDATION_WINDOW_MS = 60 * 1000;

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
  const requesterId = getRequesterId(sessionData);
  const isStudent = requesterId === userId;
  const isTutor = sessionData.tutorId === userId;

  if (!isSessionParticipant(sessionData, userId)) {
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
    sessionDoc.ref.update({
      dailyRoomName: roomName,
    }).catch((e) => {
      console.error("⚠️ Failed to update corrected room name:", e.message);
    });
  }
  if (!roomName) {
    throw new functions.https.HttpsError(
      "internal",
      "Unable to resolve room name",
    );
  }

  const roomCreatedAtMs = Number(sessionData.sessionMetadata?.roomCreatedAt || 0);
  const roomAgeMs = roomCreatedAtMs > 0 ? Date.now() - roomCreatedAtMs : Infinity;
  const hasCurrentRoomConfig =
    sessionData.sessionMetadata?.dailyRoomConfigVersion ===
    DAILY_ROOM_CONFIG_VERSION;
  let shouldCreateRoom = false;
  if (!hasCurrentRoomConfig || roomAgeMs > PRECREATED_ROOM_VALIDATION_WINDOW_MS) {
    const existingRoom = await getDailyRoom(roomName);
    shouldCreateRoom = !existingRoom || !isDailyRoomConfigCompatible(existingRoom);
    if (shouldCreateRoom && existingRoom) {
      console.warn("⚠️ Daily room uses legacy config, recreating room");
    }
  } else {
    console.log(
      "⚡ Skipping room validation - room is fresh/current (" +
        roomAgeMs +
        "ms old)",
    );
  }
  if (shouldCreateRoom) {
    const dailyRoom = await createDailyRoom({
      language: sessionData.language || "en",
      studentId: requesterId,
      tutorId: sessionData.tutorId,
      studentName: sessionData.studentInfo?.name || "Caller",
      tutorName: sessionData.tutorInfo?.name || "Partner",
      expSeconds: 15 * 60,
    });
    roomUrl = dailyRoom.url;
    roomName = dailyRoom.name;
    const recoveredRoomCreatedAt = Date.now();
    try {
      await sessionDoc.ref.update({
        dailyRoomUrl: roomUrl,
        dailyRoomName: roomName,
        "sessionMetadata.roomCreatedAt": recoveredRoomCreatedAt,
        "sessionMetadata.dailyRoomConfigVersion": DAILY_ROOM_CONFIG_VERSION,
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
