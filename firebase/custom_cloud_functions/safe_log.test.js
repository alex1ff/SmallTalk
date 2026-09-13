const test = require("node:test");
const assert = require("node:assert/strict");

const {
  SAFE_EVENT_NAME,
  buildSafeLogPayload,
  correlationHash,
  createSafeConsole,
} = require("./safe_log");

test("safe backend log preserves correlation without exposing raw data", () => {
  const rawUserId = "user-secret-123";
  const rawSessionId = "session-secret-456";
  const rawToken = "authorization-secret";
  const rawEmail = "person@example.com";
  const rawRoomUrl = "https://daily.example/private-room";
  const rawTranscript = "private conversation text";

  const payload = buildSafeLogPayload({
    userId: rawUserId,
    sessionId: rawSessionId,
    operation: "accept_attempt",
    errorCode: "provider_unavailable",
    statusCode: 503,
    token: rawToken,
    email: rawEmail,
    roomUrl: rawRoomUrl,
    transcript: rawTranscript,
    providerPayload: {authorization: rawToken},
  });

  assert.equal(payload.userHash, correlationHash(rawUserId));
  assert.equal(
    payload.sessionHash,
    correlationHash(rawSessionId, {canonicalSession: true}),
  );
  assert.equal(payload.operation, "accept_attempt");
  assert.equal(payload.errorCode, "provider_unavailable");
  assert.equal(payload.statusCode, 503);

  const serialized = JSON.stringify(payload);
  for (const sensitiveValue of [
    rawUserId,
    rawSessionId,
    rawToken,
    rawEmail,
    rawRoomUrl,
    rawTranscript,
  ]) {
    assert.doesNotMatch(serialized, new RegExp(sensitiveValue));
  }
});

test("legacy console adapter emits only sanitized structured fields", () => {
  const calls = [];
  const sink = {
    log: (...args) => calls.push(["log", ...args]),
    warn: (...args) => calls.push(["warn", ...args]),
    error: (...args) => calls.push(["error", ...args]),
  };
  const safeConsole = createSafeConsole({
    source: "create_payment_session",
    logger: sink,
  });

  safeConsole.error("Provider failed for person@example.com", {
    uid: "user-secret-123",
    source: "accept_call",
    event: "accept_attempt",
    providerStatus: 503,
    responseBody: {token: "secret-token"},
    message: "person@example.com could not be charged",
    error: Object.assign(new Error("secret provider message"), {
      code: "gateway_timeout",
    }),
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0][0], "error");
  assert.equal(calls[0][1], SAFE_EVENT_NAME);
  assert.equal(calls[0][2].source, "create_payment_session");
  assert.equal(calls[0][2].event, "unknown");
  assert.equal(calls[0][2].providerStatus, 503);
  assert.equal(calls[0][2].errorCode, "gateway_timeout");
  assert.equal(calls[0][2].errorType, "Error");

  const serialized = JSON.stringify(calls);
  assert.doesNotMatch(serialized, /person@example\.com/);
  assert.doesNotMatch(serialized, /secret-token/);
  assert.doesNotMatch(serialized, /secret provider message/);
  assert.doesNotMatch(serialized, /user-secret-123/);
});

test("free-form log messages cannot become event names", () => {
  const calls = [];
  const safeConsole = createSafeConsole({
    source: "create_payment_session",
    logger: {log: (...args) => calls.push(args)},
  });

  safeConsole.log("Provider failed for person@example.com");

  assert.equal(calls[0][1].event, "unknown");
  assert.doesNotMatch(JSON.stringify(calls), /person|example|com/);
});

test("token-shaped input is rejected or reduced to a code-owned value", () => {
  const payload = buildSafeLogPayload({
    event: "private_token_123",
    operation: "private_token_123",
    source: "private_token_123",
    status: "private_token_123",
    errorCode: "private_token_123",
    reasonCode: "current_responder_changed_private_user_123",
    packageId: "private_package_123",
    counts: {private_user_123: 1, cleaned: 2},
  });

  assert.deepEqual(payload, {
    event: "unknown",
    operation: "unknown",
    errorCode: "unknown",
    reasonCode: "current_responder_changed",
    packageHash: correlationHash("private_package_123"),
    counts: {cleaned: 2},
  });
  assert.doesNotMatch(JSON.stringify(payload), /private/);
});

test("logging failures never replace the application error path", () => {
  const hostileError = new Error("private provider message");
  Object.defineProperty(hostileError, "code", {
    get() {
      throw new Error("code getter failed");
    },
  });
  const throwingLogger = {
    log() {
      throw new Error("sink failed");
    },
  };
  const malformedLogger = Object.defineProperty({}, "log", {
    get() {
      throw new Error("getter failed");
    },
  });

  assert.doesNotThrow(() => createSafeConsole({logger: throwingLogger}).log(
    "accept_attempt",
  ));
  assert.doesNotThrow(() => createSafeConsole({logger: malformedLogger}).log(
    "accept_attempt",
  ));
  assert.doesNotThrow(() => createSafeConsole({logger: null}).log(
    "accept_attempt",
  ));

  const calls = [];
  const safeConsole = createSafeConsole({
    source: "call_feedback",
    logger: {error: (...args) => calls.push(args)},
  });
  assert.doesNotThrow(() => safeConsole.error("feedback_provider_failed", {
    error: hostileError,
    statusCode: Symbol("private-status"),
  }));
  assert.deepEqual(calls, [[SAFE_EVENT_NAME, {
    errorCode: "unknown",
    errorType: "Error",
    source: "call_feedback",
    event: "feedback_provider_failed",
  }]]);
});
