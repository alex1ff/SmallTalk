const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  CALL_LIFECYCLE_LOG_EVENT,
  buildCallLifecycleLogPayload,
  logCallLifecycleError,
  logCallLifecycleEvent,
} = require("./call_lifecycle_logs");

function readFunctionSource(fileName) {
  return fs.readFileSync(path.join(__dirname, fileName), "utf8");
}

test("call lifecycle payload keeps stable non-sensitive fields only", () => {
  const payload = buildCallLifecycleLogPayload({
    event: " accept_connected ",
    source: "acceptCall",
    sessionId: " session-a ",
    responderId: " student-b ",
    statusBefore: "pending_confirmation",
    statusAfter: "connecting",
    roomUrl: "https://daily.example/secret-room",
    meetingToken: "secret-token",
    pushPayload: {token: "secret-push-token"},
    counts: {
      found: "4",
      cleaned: 2,
      skipped: "not-a-number",
    },
  });

  assert.deepEqual(payload, {
    event: "accept_connected",
    source: "acceptCall",
    sessionId: "session-a",
    responderId: "student-b",
    statusBefore: "pending_confirmation",
    statusAfter: "connecting",
    counts: {
      found: 4,
      cleaned: 2,
    },
  });
});

test("call lifecycle logger uses a stable event name", () => {
  const logCalls = [];
  const errorCalls = [];
  const logger = {
    log: (...args) => logCalls.push(args),
    error: (...args) => errorCalls.push(args),
  };

  const infoPayload = logCallLifecycleEvent({
    event: "decline_completed",
    sessionId: "session-a",
    result: "handoff",
  }, logger);
  const errorPayload = logCallLifecycleError({
    event: "timeout_failed",
    sessionId: "session-a",
    errorCode: "internal",
    result: "overridden",
  }, logger);

  assert.deepEqual(logCalls, [[CALL_LIFECYCLE_LOG_EVENT, infoPayload]]);
  assert.deepEqual(errorCalls, [[CALL_LIFECYCLE_LOG_EVENT, errorPayload]]);
  assert.equal(errorPayload.result, "error");
});

test("backend call lifecycle scenarios emit structured logs", () => {
  const acceptSource = readFunctionSource("accept_call.js");
  const declineSource = readFunctionSource("decline_call.js");
  const timeoutSource = readFunctionSource("process_expired_notifications.js");
  const sessionCleanupSource = readFunctionSource("cleanup_expired_sessions.js");
  const searchCleanupSource =
    readFunctionSource("cleanup_stale_search_requests.js");

  assert.match(
    acceptSource,
    /logCallLifecycleEvent\(\{\s*event:\s*"accept_attempt"/s,
  );
  assert.match(acceptSource, /event:\s*"accept_connected"/);
  assert.match(
    acceptSource,
    /logCallLifecycleError\(\{\s*event:\s*"accept_failed"/s,
  );
  assert.match(acceptSource, /statusAfter:\s*acceptedLiveSession\.status/);

  assert.match(
    declineSource,
    /logCallLifecycleEvent\(\{\s*event:\s*"decline_attempt"/s,
  );
  assert.match(declineSource, /event:\s*"decline_completed"/);
  assert.match(
    declineSource,
    /logCallLifecycleError\(\{\s*event:\s*"decline_failed"/s,
  );
  assert.match(declineSource, /nextResponderId:\s*declineResult\.nextTutor/);

  assert.match(timeoutSource, /event:\s*"timeout_processing_started"/);
  assert.match(timeoutSource, /event:\s*"timeout_push_skipped"/);
  assert.match(timeoutSource, /event:\s*"timeout_completed"/);
  assert.match(timeoutSource, /event:\s*"timeout_failed"/);

  assert.match(sessionCleanupSource, /event:\s*"cleanup_sessions_completed"/);
  assert.match(sessionCleanupSource, /event:\s*"cleanup_sessions_failed"/);
  assert.match(sessionCleanupSource, /counts:\s*\{\s*found:/s);

  assert.match(
    searchCleanupSource,
    /event:\s*"cleanup_search_requests_completed"/,
  );
  assert.match(searchCleanupSource, /event:\s*"cleanup_search_requests_failed"/);
  assert.match(searchCleanupSource, /backgroundExpiredCleaned:/);
});
