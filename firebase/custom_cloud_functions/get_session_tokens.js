const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  createDailyRoom,
  createMeetingToken,
  DAILY_ROOM_CONFIG_VERSION,
  deleteDailyRoom,
  getDailyRoom,
  getRoomNameFromUrl,
  isDailyRoomConfigCompatible,
} = require("./daily_room");
const {
  getCredentialTtlSeconds,
  getRequesterId,
  getSessionExpiryTtlSeconds,
  isAcceptedSessionCredentialParticipant,
  isCredentialSessionJoinable,
} = require("./video_sessions_shared");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "get_session_tokens"});

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

  let sessionDoc = await admin
    .firestore()
    .collection("videoSessions")
    .doc(sessionId)
    .get();

  if (!sessionDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Session not found");
  }

  let sessionData = sessionDoc.data();
  const userId = context.auth.uid;
  const requesterId = getRequesterId(sessionData);
  const isStudent = requesterId === userId;

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

  const readCredentialTtlSeconds = (currentSessionData = sessionData) => {
    const credentialTtlSeconds =
      getCredentialTtlSeconds(currentSessionData, 60 * 60);
    if (credentialTtlSeconds < 1) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Session credential window has expired",
      );
    }
    return credentialTtlSeconds;
  };
  const readRoomTtlSeconds = (currentSessionData = sessionData) => {
    const roomTtlSeconds = getSessionExpiryTtlSeconds(
      currentSessionData,
      15 * 60,
    );
    if (roomTtlSeconds < 1) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Session room window has expired",
      );
    }
    return roomTtlSeconds;
  };

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
    safeLog.warn("room_name_mismatch", {sessionId});
    roomName = derivedName;
    sessionDoc.ref.update({
      dailyRoomName: roomName,
    }).catch((e) => {
      safeLog.error("room_name_update_failed", {sessionId, error: e});
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
      safeLog.warn("daily_room_recreate_required", {sessionId});
    }
  } else {
    safeLog.log("daily_room_validation_skipped", {sessionId});
  }
  if (shouldCreateRoom) {
    let replacementRoomName = null;
    const staleRoomName = roomName;
    const dailyRoom = await createDailyRoom({
      language: sessionData.language || "en",
      studentId: requesterId,
      tutorId: sessionData.tutorId,
      studentName: sessionData.studentInfo?.name || "Caller",
      tutorName: sessionData.tutorInfo?.name || "Partner",
      expSeconds: readRoomTtlSeconds(),
    });
    roomUrl = dailyRoom.url;
    roomName = dailyRoom.name;
    replacementRoomName = dailyRoom.name;
    const recoveredRoomCreatedAt = Date.now();
    try {
      const recoveryResult = await admin.firestore().runTransaction(async (transaction) => {
        const freshSnap = await transaction.get(sessionDoc.ref);
        if (!freshSnap.exists) {
          throw new functions.https.HttpsError("not-found", "Session not found");
        }

        const freshData = freshSnap.data() || {};
        if (!isAcceptedSessionCredentialParticipant(freshData, userId)) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "Not allowed to access this session",
          );
        }
        if (!isCredentialSessionJoinable(freshData)) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            `Session is not joinable (status: ${freshData.status || "unknown"})`,
          );
        }

        const freshRoomUrl = freshData.dailyRoomUrl || null;
        const freshRoomName =
          freshData.dailyRoomName || getRoomNameFromUrl(freshRoomUrl);
        const freshHasCurrentReplacement =
          freshRoomUrl &&
          freshRoomName &&
          freshRoomName !== staleRoomName &&
          freshRoomName !== replacementRoomName &&
          freshData.sessionMetadata?.dailyRoomConfigVersion ===
            DAILY_ROOM_CONFIG_VERSION;
        if (freshHasCurrentReplacement) {
          roomUrl = freshRoomUrl;
          roomName = freshRoomName;
          sessionData = freshData;
          return { usedExistingReplacement: true };
        }

        const recoveredRoomFields = {
          dailyRoomUrl: roomUrl,
          dailyRoomName: roomName,
          "sessionMetadata.roomCreatedAt": recoveredRoomCreatedAt,
          "sessionMetadata.dailyRoomConfigVersion": DAILY_ROOM_CONFIG_VERSION,
        };
        transaction.update(sessionDoc.ref, recoveredRoomFields);
        sessionData = {
          ...freshData,
          dailyRoomUrl: roomUrl,
          dailyRoomName: roomName,
          sessionMetadata: {
            ...(freshData.sessionMetadata || {}),
            roomCreatedAt: recoveredRoomCreatedAt,
            dailyRoomConfigVersion: DAILY_ROOM_CONFIG_VERSION,
          },
        };
        return { usedExistingReplacement: false };
      });
      if (recoveryResult.usedExistingReplacement && replacementRoomName) {
        await deleteDailyRoom(replacementRoomName);
      }
      replacementRoomName = null;
    } catch (e) {
      safeLog.error("recovered_room_update_failed", {sessionId, error: e});
      if (replacementRoomName) {
        await deleteDailyRoom(replacementRoomName);
      }
      throw e;
    }
  }

  sessionDoc = await sessionDoc.ref.get();
  if (!sessionDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Session not found");
  }
  sessionData = sessionDoc.data() || {};
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

  roomUrl = sessionData.dailyRoomUrl || roomUrl;
  roomName = sessionData.dailyRoomName || getRoomNameFromUrl(roomUrl);
  if (!roomUrl || !roomName) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Room is not ready yet",
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

  const credentialTtlSeconds = readCredentialTtlSeconds();
  const meetingToken = await createMeetingToken({
    roomName,
    expSeconds: credentialTtlSeconds,
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
