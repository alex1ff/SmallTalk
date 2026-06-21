const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    buildResponse,
    buildStopSearchDecision,
    buildStopSessionDecision,
    canStopSessionAfterSearchDecision,
    getAssignedResponderId,
    normalizeRequestId,
    normalizeSessionId,
    requestBelongsToUser,
    requestMatchesSearchRequestId,
    requestMatchesSession,
    resolveStopSessionId,
  },
} = require("./stop_search");

const serverTimestamp = Symbol("serverTimestamp");
const fieldDelete = Symbol("fieldDelete");

function stopSearchDecision(overrides = {}) {
  return buildStopSearchDecision({
    requestExists: true,
    requestData: {
      status: "searching",
      userId: "student-a",
      activeSessionId: "session-a",
      requestId: "request-a",
    },
    userId: "student-a",
    sessionId: "session-a",
    requestId: "request-a",
    serverTimestamp,
    fieldDelete,
    ...overrides,
  });
}

function stopSessionDecision(overrides = {}) {
  return buildStopSessionDecision({
    sessionExists: true,
    sessionData: {
      status: "searching",
      studentId: "student-a",
      currentTutorId: "teacher-a",
      dailyRoomName: "room-a",
    },
    userId: "student-a",
    sessionId: "session-a",
    requesterCurrentSessionId: "session-a",
    responderCurrentSessionId: "session-a",
    serverTimestamp,
    fieldDelete,
    ...overrides,
  });
}

test("normalize ids trim valid ids and reject invalid paths", () => {
  assert.equal(normalizeSessionId("  session-a  "), "session-a");
  assert.equal(normalizeSessionId("videoSessions/session-a"), "");
  assert.equal(normalizeSessionId("__bad__"), "");
  assert.equal(normalizeSessionId("."), "");
  assert.equal(normalizeSessionId(".."), "");
  assert.equal(normalizeSessionId(123), "");
  assert.equal(normalizeSessionId(null), "");
  assert.equal(normalizeRequestId(" request-a "), "request-a");
  assert.equal(normalizeRequestId("requests/request-a"), "");
});

test("request owner can be stored as ids, refs, or omitted for uid doc", () => {
  assert.equal(requestBelongsToUser({userId: "student-a"}, "student-a"), true);
  assert.equal(requestBelongsToUser({studentId: "student-a"}, "student-a"), true);
  assert.equal(
      requestBelongsToUser({userRef: {id: "student-a"}}, "student-a"),
      true,
  );
  assert.equal(requestBelongsToUser({}, "student-a"), true);
  assert.equal(requestBelongsToUser({userId: "student-b"}, "student-a"), false);
});

test("requestMatchesSession requires an explicit match when session is provided", () => {
  assert.equal(requestMatchesSession({}, "session-a"), false);
  assert.equal(
      requestMatchesSession({activeSessionId: "session-a"}, "session-a"),
      true,
  );
  assert.equal(
      requestMatchesSession({currentSessionId: "session-a"}, "session-a"),
      true,
  );
  assert.equal(
      requestMatchesSession({activeSessionId: "session-b"}, "session-a"),
      false,
  );
  assert.equal(requestMatchesSession({activeSessionId: "session-b"}, ""), true);
});

test("requestMatchesSearchRequestId protects sessionless requests", () => {
  assert.equal(requestMatchesSearchRequestId({}, "request-a"), false);
  assert.equal(
      requestMatchesSearchRequestId({requestId: "request-a"}, "request-a"),
      true,
  );
  assert.equal(
      requestMatchesSearchRequestId(
          {clientSearchId: "request-a"},
          "request-a",
      ),
      true,
  );
  assert.equal(
      requestMatchesSearchRequestId({requestId: "request-b"}, "request-a"),
      false,
  );
  assert.equal(requestMatchesSearchRequestId({requestId: "request-b"}, ""), true);
});

test("resolveStopSessionId prefers explicit, then request, then user session", () => {
  assert.equal(
      resolveStopSessionId({
        explicitSessionId: "session-explicit",
        requestData: {activeSessionId: "session-request"},
        requesterCurrentSessionId: "session-user",
      }),
      "session-explicit",
  );
  assert.equal(
      resolveStopSessionId({
        requestData: {activeSessionId: "session-request"},
        requesterCurrentSessionId: "session-user",
      }),
      "session-request",
  );
  assert.equal(
      resolveStopSessionId({
        requestData: {},
        requesterCurrentSessionId: "session-user",
      }),
      "session-user",
  );
});

test("missing active request is an idempotent noop", () => {
  const decision = stopSearchDecision({
    requestExists: false,
    requestData: {},
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update, null);
  assert.deepEqual(decision.response, {
    status: "noop",
    stopped: false,
    reason: "not_found",
  });
});

test("active request is marked stopped and transient match fields are cleared", () => {
  const decision = stopSearchDecision();

  assert.equal(decision.ok, true);
  assert.deepEqual(decision.response, {
    status: "stopped",
    stopped: true,
    reason: "manual",
  });
  assert.equal(decision.update.status, "stopped");
  assert.equal(decision.update.stopReason, "manual");
  assert.equal(decision.update.stoppedBy, "student-a");
  assert.equal(decision.update.stoppedAt, serverTimestamp);
  assert.equal(decision.update.updatedAt, serverTimestamp);
  assert.equal(decision.update.activeSessionId, fieldDelete);
  assert.equal(decision.update.currentSessionId, fieldDelete);
  assert.equal(decision.update.matchedSessionId, fieldDelete);
  assert.equal(decision.update.matchedResponderId, fieldDelete);
  assert.equal(decision.update.matchedRole, fieldDelete);
  assert.equal(decision.update.pairAttemptId, fieldDelete);
  assert.equal(decision.update.attemptExcludedCandidateIds, fieldDelete);
  assert.equal(decision.update.candidateLockOwner, fieldDelete);
  assert.equal(decision.update.candidateLockExpiresAt, fieldDelete);
  assert.equal(decision.update.lockOwner, fieldDelete);
  assert.equal(decision.update.lockExpiresAt, fieldDelete);
});

test("matched request stop clears transient match state", () => {
  const decision = stopSearchDecision({
    requestData: {
      status: "matched",
      userId: "student-a",
      activeSessionId: "session-a",
      requestId: "request-a",
    },
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update.status, "stopped");
  assert.equal(decision.update.matchedSessionId, fieldDelete);
  assert.equal(decision.update.matchedResponderId, fieldDelete);
  assert.equal(decision.update.matchedRole, fieldDelete);
  assert.equal(decision.update.pairAttemptId, fieldDelete);
  assert.equal(decision.update.lockOwner, fieldDelete);
  assert.deepEqual(decision.response, {
    status: "stopped",
    stopped: true,
    reason: "manual",
  });
});

test("terminal request stop is idempotent and does not overwrite state", () => {
  const decision = stopSearchDecision({
    requestData: {
      status: "completed",
      userId: "student-a",
      activeSessionId: "session-a",
      requestId: "request-a",
    },
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update, null);
  assert.deepEqual(decision.response, {
    status: "noop",
    stopped: false,
    reason: "already_inactive",
  });
});

test("different session id does not stop a newer request", () => {
  const decision = stopSearchDecision({
    requestData: {
      status: "searching",
      userId: "student-a",
      activeSessionId: "session-b",
      requestId: "request-a",
    },
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update, null);
  assert.deepEqual(decision.response, {
    status: "noop",
    stopped: false,
    reason: "session_mismatch",
  });
});

test("different request id does not stop a newer sessionless request", () => {
  const decision = stopSearchDecision({
    requestData: {
      status: "searching",
      userId: "student-a",
      requestId: "request-b",
    },
    sessionId: "",
    requestId: "request-a",
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update, null);
  assert.deepEqual(decision.response, {
    status: "noop",
    stopped: false,
    reason: "request_mismatch",
  });
});

test("request owned by another user is rejected", () => {
  const decision = stopSearchDecision({
    requestData: {
      status: "searching",
      userId: "student-b",
      activeSessionId: "session-a",
      requestId: "request-a",
    },
  });

  assert.equal(decision.ok, false);
  assert.equal(decision.code, "permission-denied");
});

test("searching video session is cancelled and user pointers are cleared", () => {
  const decision = stopSessionDecision();

  assert.equal(decision.ok, true);
  assert.deepEqual(decision.response, {
    status: "cancelled",
    stopped: true,
    reason: "manual",
    dailyRoomName: "room-a",
    responderUserId: "teacher-a",
  });
  assert.equal(decision.sessionUpdate.status, "cancelled");
  assert.equal(decision.sessionUpdate.cancelReason, "manual_stop_search");
  assert.equal(decision.sessionUpdate.currentTutorId, fieldDelete);
  assert.equal(decision.sessionUpdate.acceptingTutorId, fieldDelete);
  assert.equal(decision.requesterUpdate.currentSessionId, fieldDelete);
  assert.equal(decision.responderUpdate.currentSessionId, fieldDelete);
});

test("active video session is not cancelled by stopSearch", () => {
  const decision = stopSessionDecision({
    sessionData: {
      status: "active",
      studentId: "student-a",
      tutorId: "teacher-a",
    },
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.sessionUpdate, null);
  assert.deepEqual(decision.response, {
    status: "noop",
    stopped: false,
    reason: "session_not_searching",
  });
});

test("connecting video session is not cancelled by stopSearch", () => {
  const decision = stopSessionDecision({
    sessionData: {
      status: "connecting",
      studentId: "student-a",
      tutorId: "teacher-a",
      dailyRoomName: "room-a",
    },
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.sessionUpdate, null);
  assert.deepEqual(decision.response, {
    status: "noop",
    stopped: false,
    reason: "session_not_searching",
  });
});

test("assigned responder lookup supports legacy and neutral fields", () => {
  assert.equal(getAssignedResponderId({currentTutorId: "teacher-a"}), "teacher-a");
  assert.equal(getAssignedResponderId({tutorId: "teacher-b"}), "teacher-b");
  assert.equal(
      getAssignedResponderId({currentResponderId: "student-b"}),
      "student-b",
  );
  assert.equal(getAssignedResponderId({responderId: "student-c"}), "student-c");
  assert.equal(
      getAssignedResponderId({
        matchContext: {acceptedResponderId: "student-d"},
      }),
      "student-d",
  );
});

test("video session owned by another requester is rejected", () => {
  const decision = stopSessionDecision({
    sessionData: {
      status: "searching",
      studentId: "student-b",
      currentTutorId: "teacher-a",
    },
  });

  assert.equal(decision.ok, false);
  assert.equal(decision.code, "permission-denied");
});

test("combined response succeeds when either request or session is stopped", () => {
  const response = buildResponse({
    userId: "student-a",
    sessionId: "session-a",
    requestId: "request-a",
    searchDecision: {
      response: {
        status: "noop",
        stopped: false,
        reason: "not_found",
      },
    },
    sessionDecision: stopSessionDecision(),
  });

  assert.equal(response.status, "cancelled");
  assert.equal(response.stopped, true);
  assert.equal(response.reason, "manual");
  assert.equal(response.cancelledSessionId, "session-a");
});

test("derived session is not stopped when request guard mismatches", () => {
  const requestMismatchDecision = stopSearchDecision({
    requestData: {
      status: "searching",
      userId: "student-a",
      activeSessionId: "session-b",
      requestId: "request-b",
    },
  });

  assert.equal(requestMismatchDecision.response.reason, "session_mismatch");
  assert.equal(
      canStopSessionAfterSearchDecision({
        explicitSessionId: "",
        searchDecision: requestMismatchDecision,
      }),
      false,
  );
  assert.equal(
      canStopSessionAfterSearchDecision({
        explicitSessionId: "session-a",
        searchDecision: requestMismatchDecision,
      }),
      true,
  );
});

test("stopSearch is exported and included in readiness deploy target", () => {
  const indexSource = fs.readFileSync(path.join(__dirname, "index.js"), "utf8");
  const packageJson = JSON.parse(fs.readFileSync(
      path.join(__dirname, "package.json"),
      "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];

  assert.match(indexSource, /exports\.stopSearch\b/);
  assert.match(deployScript, /functions:custom_cloud_functions:stopSearch\b/);
});
