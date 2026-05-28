const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  resolveDailyRoomName,
} = require("./daily_room");
const {
  deleteDailyRoomForSession,
} = require("./daily_room_cleanup");

const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const FAILED_DAILY_ROOM_DELETE_BATCH_LIMIT = 20;
const FAILED_DAILY_ROOM_DELETE_RETRY_DELAY_MS = 5 * 60 * 1000;
const DAILY_ROOM_NAME_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const TERMINAL_DAILY_ROOM_DELETE_FALLBACK_STATUSES = new Set([
  "ended",
  "cancelled",
  "canceled",
  "no_tutors_available",
  "expired",
  "declined",
]);

function normalizeDailyRoomName(roomName) {
  const normalized = roomName ? String(roomName).trim() : "";
  return DAILY_ROOM_NAME_PATTERN.test(normalized) ? normalized : null;
}

function isTerminalStatusForDailyDeleteRetry(status) {
  return TERMINAL_DAILY_ROOM_DELETE_FALLBACK_STATUSES.has(
    String(status || "").toLowerCase(),
  );
}

function resolveFailedDailyRoomDeleteName(sessionData = {}) {
  const metadata = sessionData.sessionMetadata || {};
  const recordedRoomName = metadata.dailyRoomDeleteRoomName;
  const retryRoomName = normalizeDailyRoomName(recordedRoomName);
  if (retryRoomName) {
    return retryRoomName;
  }
  if (recordedRoomName) {
    return null;
  }
  if (!isTerminalStatusForDailyDeleteRetry(sessionData.status)) {
    return null;
  }
  return normalizeDailyRoomName(resolveDailyRoomName(sessionData));
}

function buildSkippedFailedDailyRoomDeletePatch({
  reason = "Daily room deletion retry skipped; room name missing or unsafe",
} = {}) {
  const fieldValue = admin.firestore.FieldValue;
  return {
    "sessionMetadata.dailyRoomDeleteAttemptedAt":
      fieldValue.serverTimestamp(),
    "sessionMetadata.dailyRoomDeleteSkippedAt":
      fieldValue.serverTimestamp(),
    "sessionMetadata.dailyRoomDeleteSource": "cleanupFailedDailyRoomDeletes",
    "sessionMetadata.dailyRoomDeleteFailedAt": fieldValue.delete(),
    "sessionMetadata.dailyRoomDeleteError": reason,
  };
}

function buildFailedDailyRoomDeleteQuery({
  db = admin.firestore(),
  nowMillis = Date.now(),
  limit = FAILED_DAILY_ROOM_DELETE_BATCH_LIMIT,
} = {}) {
  const retryCutoff = admin.firestore.Timestamp.fromMillis(
    nowMillis - FAILED_DAILY_ROOM_DELETE_RETRY_DELAY_MS,
  );

  return db
    .collection("videoSessions")
    .where("sessionMetadata.dailyRoomDeleteFailedAt", "<=", retryCutoff)
    .orderBy("sessionMetadata.dailyRoomDeleteFailedAt", "asc")
    .limit(limit);
}

async function cleanupFailedDailyRoomDeleteDocs({
  db = admin.firestore(),
  docs = [],
  deleteRoomForSession = deleteDailyRoomForSession,
  logger = console,
} = {}) {
  const result = {
    scanned: docs.length,
    attempted: 0,
    deleted: 0,
    failed: 0,
    skipped: 0,
    quarantined: 0,
  };

  for (const doc of docs) {
    const sessionData = doc.data() || {};
    const roomName = resolveFailedDailyRoomDeleteName(sessionData);
    if (!roomName) {
      result.skipped += 1;
      logger.warn("Skipping Daily delete retry without room name", {
        sessionId: doc.id,
      });
      if (doc.ref?.update) {
        try {
          await doc.ref.update(buildSkippedFailedDailyRoomDeletePatch());
          result.quarantined += 1;
        } catch (error) {
          logger.error("Failed to mark Daily delete retry as skipped", {
            sessionId: doc.id,
            error: error.message,
          });
        }
      }
      continue;
    }

    result.attempted += 1;
    try {
      const deleted = await deleteRoomForSession({
        db,
        sessionId: doc.id,
        roomName,
        source: "cleanupFailedDailyRoomDeletes",
      });
      if (deleted) {
        result.deleted += 1;
      } else {
        result.failed += 1;
      }
    } catch (error) {
      result.failed += 1;
      logger.error("Failed Daily delete retry", {
        sessionId: doc.id,
        error: error.message,
      });
    }
  }

  return result;
}

exports.cleanupFailedDailyRoomDeletes = functions
  .runWith({ secrets: dailySecrets })
  .pubsub
  .schedule("every 15 minutes")
  .onRun(async () => {
    console.log("Cleaning up failed Daily room deletions...");

    try {
      const query = buildFailedDailyRoomDeleteQuery();
      const failedDeleteQuery = await query.get();
      if (failedDeleteQuery.empty) {
        console.log("No failed Daily room deletes need retry");
        return null;
      }

      const result = await cleanupFailedDailyRoomDeleteDocs({
        docs: failedDeleteQuery.docs,
      });

      console.log("Failed Daily room delete cleanup completed", result);
      return null;
    } catch (error) {
      console.error("Error cleaning up failed Daily room deletes:", error);
      return null;
    }
  });

exports.__private__ = {
  FAILED_DAILY_ROOM_DELETE_BATCH_LIMIT,
  FAILED_DAILY_ROOM_DELETE_RETRY_DELAY_MS,
  buildFailedDailyRoomDeleteQuery,
  buildSkippedFailedDailyRoomDeletePatch,
  cleanupFailedDailyRoomDeleteDocs,
  isTerminalStatusForDailyDeleteRetry,
  normalizeDailyRoomName,
  resolveFailedDailyRoomDeleteName,
};
