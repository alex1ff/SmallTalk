const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

function readFunctionSource(fileName) {
  return fs.readFileSync(path.join(__dirname, fileName), "utf8");
}

test("terminal call paths derive and delete Daily rooms server-side", () => {
  const endSession = readFunctionSource("end_session.js");
  const cancelCall = readFunctionSource("cancel_call.js");
  const declineCall = readFunctionSource("decline_call.js");
  const processExpiredNotifications = readFunctionSource(
    "process_expired_notifications.js",
  );
  const failedDailyRoomDeleteCleanup = readFunctionSource(
    "cleanup_failed_daily_room_deletes.js",
  );
  const index = readFunctionSource("index.js");

  assert.match(endSession, /deleteDailyRoomForSession\(\{/);
  assert.match(endSession, /source:\s*"endSession_already_ended"/);
  assert.match(
    cancelCall,
    /db\.runTransaction\(async \(transaction\) => \{/,
  );
  assert.match(
    cancelCall,
    /dailyRoomName:\s*resolveDailyRoomName\(sessionData\)/,
  );
  assert.match(
    declineCall,
    /dailyRoomName:\s*nextTutor \? null : resolveDailyRoomName\(sessionData\)/,
  );
  assert.match(
    declineCall,
    /source:\s*"declineCall_no_tutors"/,
  );
  assert.match(
    processExpiredNotifications,
    /dailyRoomName:\s*resolveDailyRoomName\(freshSessionData\)/,
  );
  assert.match(
    processExpiredNotifications,
    /source:\s*"processExpiredNotifications"/,
  );
  assert.match(
    failedDailyRoomDeleteCleanup,
    /\.runWith\(\{\s*secrets:\s*dailySecrets\s*\}\)/,
  );
  assert.match(
    failedDailyRoomDeleteCleanup,
    /\.schedule\("every 15 minutes"\)/,
  );
  assert.match(
    failedDailyRoomDeleteCleanup,
    /where\("sessionMetadata\.dailyRoomDeleteFailedAt",\s*"<=",\s*retryCutoff\)/,
  );
  assert.match(
    failedDailyRoomDeleteCleanup,
    /source:\s*"cleanupFailedDailyRoomDeletes"/,
  );
  assert.match(
    index,
    /exports\.cleanupFailedDailyRoomDeletes\s*=/,
  );
});
