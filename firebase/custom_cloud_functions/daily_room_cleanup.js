const admin = require("firebase-admin");
const { deleteDailyRoom } = require("./daily_room");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "daily_room_cleanup"});

function buildDailyRoomDeletePatch({
  source,
  roomName,
  deleted,
}) {
  const fieldValue = admin.firestore.FieldValue;
  const patch = {
    "sessionMetadata.dailyRoomDeleteAttemptedAt":
      fieldValue.serverTimestamp(),
    "sessionMetadata.dailyRoomDeleteSource": source || "unknown",
    "sessionMetadata.dailyRoomDeleteRoomName": roomName,
  };

  if (deleted) {
    patch["sessionMetadata.dailyRoomDeletedAt"] = fieldValue.serverTimestamp();
    patch["sessionMetadata.dailyRoomDeleteFailedAt"] = fieldValue.delete();
    patch["sessionMetadata.dailyRoomDeleteError"] = fieldValue.delete();
  } else {
    patch["sessionMetadata.dailyRoomDeleteFailedAt"] =
      fieldValue.serverTimestamp();
    patch["sessionMetadata.dailyRoomDeleteError"] =
      "Daily room deletion failed; retry required";
  }

  return patch;
}

async function deleteDailyRoomForSession({
  db = admin.firestore(),
  sessionId,
  roomName,
  source = "unknown",
}) {
  if (!sessionId || !roomName) return false;

  const deleted = await deleteDailyRoom(roomName);
  const sessionRef = db.collection("videoSessions").doc(sessionId);
  try {
    await sessionRef.update(buildDailyRoomDeletePatch({
      source,
      roomName,
      deleted,
    }));
  } catch (error) {
    safeLog.error("daily_room_cleanup_status_failed", {
      sessionId,
      source,
      error,
    });
  }

  return deleted;
}

module.exports = {
  deleteDailyRoomForSession,
  __private__: {
    buildDailyRoomDeletePatch,
  },
};
