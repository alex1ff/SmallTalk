const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  SEARCH_REQUEST_STATUS,
} = require("./search_requests");
const {
  __private__: {
    buildDeclineNextResponderPairLockInput,
    buildDeclineResponderFailureRouting,
    collectFreshDeclineFailureResponderIds,
    getPendingAssignedResponderId,
    isPendingSessionAssignedToResponder,
    readRequesterIdForResponderFailure,
  },
} = require("./decline_call");

function timestampFromMillis(millis) {
  return {
    toMillis: () => millis,
    toDate: () => new Date(millis),
  };
}

function fakeSessionRef(data = null) {
  return {
    async get() {
      return {
        exists: data !== null,
        data: () => data,
      };
    },
  };
}

test("declineCall authorizes currentResponderId student assignments", () => {
  assert.equal(
    getPendingAssignedResponderId({
      currentResponderId: " student-b ",
      currentTutorId: "teacher-a",
    }),
    "student-b",
  );
  assert.equal(
    getPendingAssignedResponderId({
      currentResponderId: " ",
      currentTutorId: " teacher-a ",
    }),
    "teacher-a",
  );
  assert.equal(
    isPendingSessionAssignedToResponder(
      {currentResponderId: "student-b", currentTutorId: "teacher-a"},
      "student-b",
    ),
    true,
  );
  assert.equal(
    isPendingSessionAssignedToResponder(
      {currentResponderId: "student-b", currentTutorId: "teacher-a"},
      "teacher-a",
    ),
    false,
  );
  assert.equal(
    isPendingSessionAssignedToResponder(
      {currentTutorId: "teacher-a"},
      "teacher-a",
    ),
    true,
  );
});

test("declineCall routes student-student failure to requester restore", () => {
  const sessionData = {
    scenario: "student_student",
    studentId: "student-a",
    requesterId: "student-a",
    currentTutorId: "student-b",
    currentResponderId: "student-b",
    currentResponderRole: "student",
    participantRoles: {
      "student-a": "student",
      "student-b": "student",
    },
    availableTutors: ["student-b", "student-c", "teacher-a"],
  };

  const routing = buildDeclineResponderFailureRouting({
    sessionData,
    responderId: "student-b",
  });

  assert.equal(readRequesterIdForResponderFailure(sessionData), "student-a");
  assert.deepEqual(routing.availableTutors, []);
  assert.equal(routing.terminalStopReason, "student_pair_declined");
  assert.deepEqual(routing.restoreSearchParticipantIds, ["student-a"]);
  assert.deepEqual(
    routing.restoreSearchExcludedCandidateIdsByParticipantId,
    {"student-a": ["student-b"]},
  );
});

test("declineCall blocks fresh accept-lock races before handoff", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "decline_call.js"),
    "utf8",
  );
  const assignmentGuardIndex = source.indexOf(
    "isPendingSessionAssignedToResponder(sessionData, responderId)",
  );
  const acceptLockGuardIndex = source.indexOf(
    "assertNoActiveAcceptLockForResponderOrThrow({",
    assignmentGuardIndex,
  );
  const triedTutorsIndex = source.indexOf(
    "const triedTutors = Array.from",
    acceptLockGuardIndex,
  );
  const acceptAttemptDeleteIndex = source.indexOf(
    "acceptAttemptId: admin.firestore.FieldValue.delete()",
    acceptLockGuardIndex,
  );

  assert.ok(acceptLockGuardIndex > assignmentGuardIndex);
  assert.ok(triedTutorsIndex > acceptLockGuardIndex);
  assert.ok(acceptAttemptDeleteIndex > acceptLockGuardIndex);
  assert.doesNotMatch(source, /sessionData\.currentTutorId !== responderId/);
});

test("declineCall validates assignment before fresh pool scan", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "decline_call.js"),
    "utf8",
  );
  const preflightIndex = source.indexOf(
    "const preflightSessionDoc = await sessionRef.get()",
  );
  const statusGuardIndex = source.indexOf(
    "DECLINABLE_SESSION_STATUSES.has(preflightSessionData.status)",
    preflightIndex,
  );
  const assignmentGuardIndex = source.indexOf(
    "isPendingSessionAssignedToResponder(",
    statusGuardIndex,
  );
  const acceptLockGuardIndex = source.indexOf(
    "hasActiveAcceptLockForResponder({",
    assignmentGuardIndex,
  );
  const collectIndex = source.indexOf(
    "await failureResponderCollector({",
    acceptLockGuardIndex,
  );

  assert.ok(preflightIndex > 0);
  assert.ok(statusGuardIndex > preflightIndex);
  assert.ok(assignmentGuardIndex > statusGuardIndex);
  assert.ok(acceptLockGuardIndex > assignmentGuardIndex);
  assert.ok(collectIndex > acceptLockGuardIndex);
});

test("declineCall fresh pool preflight returns common candidates for current teacher", async () => {
  const calls = [];
  const result = await collectFreshDeclineFailureResponderIds({
    db: "db",
    sessionRef: fakeSessionRef({
      status: "pending_confirmation",
      requesterId: "student-a",
      language: "en",
      currentResponderId: "teacher-a",
      currentResponderRole: "native_speaker",
    }),
    responderId: "teacher-a",
    nowMillis: Date.parse("2026-06-25T10:00:00.000Z"),
    failureResponderCollector: async (input) => {
      calls.push(input);
      return {availableTutors: ["student-fresh", "teacher-fresh"]};
    },
  });

  assert.deepEqual(result.availableTutors, ["student-fresh", "teacher-fresh"]);
  assert.equal(result.fingerprint.requesterId, "student-a");
  assert.equal(result.fingerprint.responderId, "teacher-a");
  assert.equal(result.fingerprint.language, "en");
  assert.equal(calls.length, 1);
  assert.equal(calls[0].db, "db");
  assert.equal(calls[0].requesterId, "student-a");
  assert.equal(calls[0].responderId, "teacher-a");
  assert.equal(calls[0].now.toISOString(), "2026-06-25T10:00:00.000Z");
});

test("declineCall fresh pool preflight skips stale assignment", async () => {
  let called = false;
  const result = await collectFreshDeclineFailureResponderIds({
    sessionRef: fakeSessionRef({
      status: "pending_confirmation",
      requesterId: "student-a",
      language: "en",
      currentResponderId: "teacher-b",
      currentResponderRole: "native_speaker",
    }),
    responderId: "teacher-a",
    failureResponderCollector: async () => {
      called = true;
      return {availableTutors: ["teacher-fresh"]};
    },
  });

  assert.equal(result, null);
  assert.equal(called, false);
});

test("declineCall fresh pool preflight skips active accept-lock", async () => {
  const nowMillis = Date.parse("2026-06-25T10:00:00.000Z");
  let called = false;
  const result = await collectFreshDeclineFailureResponderIds({
    sessionRef: fakeSessionRef({
      status: "pending_confirmation",
      requesterId: "student-a",
      language: "en",
      currentResponderId: "teacher-a",
      currentResponderRole: "native_speaker",
      acceptingTutorId: "teacher-a",
      acceptingAt: timestampFromMillis(nowMillis - 1_000),
    }),
    responderId: "teacher-a",
    nowMillis,
    failureResponderCollector: async () => {
      called = true;
      return {availableTutors: ["teacher-fresh"]};
    },
  });

  assert.equal(result, null);
  assert.equal(called, false);
});

test("declineCall validates next assignment before sending push", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "decline_call.js"),
    "utf8",
  );
  const helperIndex = source.indexOf(
    "async function sendNotificationToNextTutor",
  );
  const sessionReadIndex = source.indexOf(
    'db.collection("videoSessions").doc(sessionId).get()',
    helperIndex,
  );
  const statusGuardIndex = source.indexOf(
    "!DECLINABLE_SESSION_STATUSES.has(validationSessionData.status)",
    sessionReadIndex,
  );
  const assignmentGuardIndex = source.indexOf(
    "getPendingAssignedResponderId(validationSessionData) !== nextTutor",
    statusGuardIndex,
  );
  const notificationStatusIndex = source.indexOf(
    'notificationData.status !== "sent"',
    assignmentGuardIndex,
  );
  const activeAcceptLockIndex = source.indexOf(
    "hasActiveAcceptLockForResponder({",
    assignmentGuardIndex,
  );
  const pushIndex = source.indexOf(
    "await sendVoipPushToTutor(nextTutor",
    notificationStatusIndex,
  );

  assert.ok(sessionReadIndex > helperIndex);
  assert.ok(statusGuardIndex > sessionReadIndex);
  assert.ok(assignmentGuardIndex > statusGuardIndex);
  assert.ok(activeAcceptLockIndex > assignmentGuardIndex);
  assert.ok(notificationStatusIndex > assignmentGuardIndex);
  assert.ok(pushIndex > notificationStatusIndex);
});

test("declineCall clears pending responder fields on terminal decline", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "decline_call.js"),
    "utf8",
  );

  const sessionUpdateIndex = source.indexOf("const sessionUpdate = {");
  const legacyDeleteIndex = source.indexOf(
    "currentTutorId: nextTutor || admin.firestore.FieldValue.delete()",
    sessionUpdateIndex,
  );
  const responderDeleteIndex = source.indexOf(
    "currentResponderId: nextTutor || admin.firestore.FieldValue.delete()",
    legacyDeleteIndex,
  );
  const responderRoleDeleteIndex = source.indexOf(
    "currentResponderRole: admin.firestore.FieldValue.delete()",
    responderDeleteIndex,
  );

  assert.ok(legacyDeleteIndex > sessionUpdateIndex);
  assert.ok(responderDeleteIndex > legacyDeleteIndex);
  assert.ok(responderRoleDeleteIndex > responderDeleteIndex);
});

test("declineCall backend either hands off or cancels terminal pair", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "decline_call.js"),
    "utf8",
  );

  const notificationIndex = source.indexOf(
    "const notification = nextTutor",
  );
  const pairLockIndex = source.indexOf(
    "if (preparedPairLock) {",
    notificationIndex,
  );
  const applyPairLockIndex = source.indexOf(
    "applyPreparedPairLockWrites(transaction, preparedPairLock)",
    pairLockIndex,
  );
  const terminalReleaseIndex = source.indexOf(
    "await releaseSessionPairLocksInTransaction({",
    applyPairLockIndex,
  );
  const terminalUpdateIndex = source.indexOf(
    "transaction.update(sessionRef, sessionUpdate)",
    terminalReleaseIndex,
  );
  const cancelledStatusIndex = source.indexOf(
    "sessionUpdate.status = VIDEO_SESSION_STATUS.CANCELLED",
  );
  const cancelReasonIndex = source.indexOf(
    "sessionUpdate.cancelReason = terminalStopReason",
    cancelledStatusIndex,
  );
  const nextPushIndex = source.indexOf(
    "await sendNotificationToNextTutor(",
    terminalUpdateIndex,
  );
  const dailyCleanupIndex = source.indexOf(
    "await deleteDailyRoomForSession({",
    terminalUpdateIndex,
  );

  assert.ok(notificationIndex > 0);
  assert.ok(pairLockIndex > notificationIndex);
  assert.ok(applyPairLockIndex > pairLockIndex);
  assert.ok(terminalReleaseIndex > applyPairLockIndex);
  assert.ok(terminalUpdateIndex > terminalReleaseIndex);
  assert.ok(cancelledStatusIndex > 0);
  assert.ok(cancelReasonIndex > cancelledStatusIndex);
  assert.ok(dailyCleanupIndex > terminalUpdateIndex);
  assert.ok(nextPushIndex > terminalUpdateIndex);
});

test("declineCall excludes declined responder during teacher handoff", () => {
  const lockInput = buildDeclineNextResponderPairLockInput({
    db: "db",
    transaction: "transaction",
    sessionId: "session-a",
    sessionData: {language: "en"},
    responderId: "teacher-a",
    nextCandidate: {
      candidateId: "teacher-b",
      role: "native_speaker",
      triedCandidateIds: ["teacher-a", "teacher-b"],
    },
    serverTimestamp: "serverTimestamp",
    lockExpiresAt: "lockExpiresAt",
    fieldDelete: "fieldDelete",
  });

  assert.equal(lockInput.db, "db");
  assert.equal(lockInput.transaction, "transaction");
  assert.equal(lockInput.sessionId, "session-a");
  assert.equal(lockInput.currentResponderId, "teacher-a");
  assert.equal(lockInput.responderId, "teacher-b");
  assert.equal(lockInput.responderRole, "native_speaker");
  assert.equal(lockInput.expectedLanguage, "en");
  assert.deepEqual(lockInput.triedTutors, ["teacher-a", "teacher-b"]);
  assert.equal(
    lockInput.currentResponderSearchRequestStatus,
    SEARCH_REQUEST_STATUS.CANCELLED,
  );
  assert.equal(lockInput.currentResponderStopReason, "declined");
  assert.deepEqual(lockInput.requesterExcludedCandidateIds, ["teacher-a"]);
});

test("declineCall can handoff declined teacher to next student candidate", () => {
  const routing = buildDeclineResponderFailureRouting({
    sessionData: {
      scenario: "student_teacher",
      studentId: "student-a",
      currentTutorId: "teacher-a",
      currentResponderRole: "native_speaker",
    },
    responderId: "teacher-a",
    availableTutors: ["student-fresh", "teacher-fresh"],
  });
  const lockInput = buildDeclineNextResponderPairLockInput({
    db: "db",
    transaction: "transaction",
    sessionId: "session-a",
    sessionData: {language: "en"},
    responderId: "teacher-a",
    nextCandidate: {
      candidateId: routing.availableTutors[0],
      role: "student",
      triedCandidateIds: ["teacher-a", "student-fresh"],
    },
    serverTimestamp: "serverTimestamp",
    lockExpiresAt: "lockExpiresAt",
    fieldDelete: "fieldDelete",
  });

  assert.deepEqual(routing.availableTutors, ["student-fresh", "teacher-fresh"]);
  assert.equal(lockInput.currentResponderId, "teacher-a");
  assert.equal(lockInput.responderId, "student-fresh");
  assert.equal(lockInput.responderRole, "student");
  assert.deepEqual(lockInput.triedTutors, ["teacher-a", "student-fresh"]);
  assert.deepEqual(lockInput.requesterExcludedCandidateIds, ["teacher-a"]);
});

test("declineCall keeps teacher handoff candidates", () => {
  const routing = buildDeclineResponderFailureRouting({
    sessionData: {
      scenario: "student_teacher",
      studentId: "student-a",
      currentTutorId: "teacher-a",
      currentResponderRole: "native_speaker",
      availableTutors: ["teacher-a", "teacher-b"],
    },
    responderId: "teacher-a",
  });

  assert.deepEqual(routing.availableTutors, ["teacher-a", "teacher-b"]);
  assert.equal(
    routing.terminalStopReason,
    "no_available_responder_after_decline",
  );
  assert.deepEqual(routing.restoreSearchParticipantIds, ["student-a"]);
  assert.deepEqual(
    routing.restoreSearchExcludedCandidateIdsByParticipantId,
    {"student-a": ["teacher-a"]},
  );
});

test("declineCall ends direct teacher calls without queue restore", () => {
  const routing = buildDeclineResponderFailureRouting({
    sessionData: {
      scenario: "student_teacher",
      studentId: "student-a",
      requesterId: "student-a",
      currentTutorId: "teacher-a",
      currentResponderId: "teacher-a",
      currentResponderRole: "native_speaker",
      availableTutors: ["teacher-a", "teacher-b"],
      matchContext: {
        matchMode: "direct",
        directCandidateId: "teacher-a",
      },
    },
    responderId: "teacher-a",
    availableTutors: ["student-fresh", "teacher-fresh"],
  });

  assert.deepEqual(routing.availableTutors, []);
  assert.equal(routing.requesterId, "student-a");
  assert.equal(routing.terminalStopReason, "direct_call_declined");
  assert.deepEqual(routing.restoreSearchParticipantIds, []);
  assert.deepEqual(
    routing.restoreSearchExcludedCandidateIdsByParticipantId,
    {},
  );
});

test("declineCall treats legacy direct tutor id as terminal direct call", () => {
  const routing = buildDeclineResponderFailureRouting({
    sessionData: {
      scenario: "student_teacher",
      studentId: "student-a",
      currentTutorId: "teacher-a",
      currentResponderRole: "native_speaker",
      availableTutors: ["teacher-a", "teacher-b"],
      matchContext: {
        directTutorId: "teacher-a",
      },
    },
    responderId: "teacher-a",
  });

  assert.deepEqual(routing.availableTutors, []);
  assert.equal(routing.terminalStopReason, "direct_call_declined");
  assert.deepEqual(routing.restoreSearchParticipantIds, []);
});

test("declineCall uses fresh common pool candidates after teacher decline", () => {
  const routing = buildDeclineResponderFailureRouting({
    sessionData: {
      scenario: "student_teacher",
      studentId: "student-a",
      currentTutorId: "teacher-a",
      currentResponderRole: "native_speaker",
      availableTutors: ["teacher-a", "teacher-stale"],
    },
    responderId: "teacher-a",
    availableTutors: ["student-fresh", "teacher-fresh"],
  });

  assert.deepEqual(routing.availableTutors, ["student-fresh", "teacher-fresh"]);
  assert.deepEqual(
    routing.restoreSearchExcludedCandidateIdsByParticipantId,
    {"student-a": ["teacher-a"]},
  );
});
