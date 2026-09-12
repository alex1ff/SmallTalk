const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {spawnSync} = require("node:child_process");
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
    sessionHash: require("./safe_log").correlationHash("session-a", {
      canonicalSession: true,
    }),
    responderHash: require("./safe_log").correlationHash("student-b"),
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

  assert.deepEqual(logCalls, [[CALL_LIFECYCLE_LOG_EVENT, {
    operation: infoPayload.event,
    result: infoPayload.result,
    sessionHash: infoPayload.sessionHash,
  }]]);
  assert.deepEqual(errorCalls, [[CALL_LIFECYCLE_LOG_EVENT, {
    errorCode: errorPayload.errorCode,
    operation: errorPayload.event,
    result: errorPayload.result,
    sessionHash: errorPayload.sessionHash,
  }]]);
  assert.equal(errorPayload.result, "error");
});

test("production lifecycle adapter emits Firebase structured JSON", () => {
  const child = spawnSync(process.execPath, ["-e", `
    const {logCallLifecycleEvent} = require("./call_lifecycle_logs");
    logCallLifecycleEvent({
      event: "accept_connected",
      source: "acceptCall",
      sessionId: "private-session-a",
      responderId: "private-responder-b",
      result: "connected",
    });
  `], {
    cwd: __dirname,
    encoding: "utf8",
  });

  assert.equal(child.status, 0, child.stderr);
  const entry = JSON.parse(child.stdout.trim());
  assert.deepEqual(entry, {
    event: CALL_LIFECYCLE_LOG_EVENT,
    message: require("./safe_log").SAFE_EVENT_NAME,
    operation: "accept_connected",
    responderHash: require("./safe_log").correlationHash(
      "private-responder-b",
    ),
    result: "connected",
    sessionHash: require("./safe_log").correlationHash(
      "private-session-a",
      {canonicalSession: true},
    ),
    severity: "INFO",
    source: "call_lifecycle",
  });
  assert.doesNotMatch(child.stdout, /private/);
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
