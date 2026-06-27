const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  SEARCH_REQUEST_STATUS,
} = require("./search_requests");
const {
  __private__: {
    buildTerminalTimeoutSessionProjection,
    buildTimeoutNextResponderPairLockInput,
    buildTimeoutResponderDecision,
    buildTimeoutResponderFailureRouting,
    collectFreshTimeoutFailureResponderIds,
    getPendingAssignedResponderId,
    isPendingSessionAssignedToResponder,
    readRequesterIdForResponderFailure,
    resolveTimedOutResponderForNotification,
  },
} = require("./process_expired_notifications");

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

test("notification timeout resolves currentResponderId with legacy fallback", () => {
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
  assert.equal(getPendingAssignedResponderId({}), "");
});

test("notification timeout skips stale recipient after handoff", () => {
  assert.deepEqual(
    resolveTimedOutResponderForNotification({
      sessionData: {
        currentResponderId: "student-c",
        currentTutorId: "student-b",
      },
      notificationData: {
        recipientId: "student-b",
      },
    }),
    {
      ok: false,
      skipReason: "current_responder_changed_student-c",
      currentResponderId: "student-c",
      expiredResponderId: "student-b",
      timedOutResponderId: "",
    },
  );
});

test("notification timeout resolves responder from current assignment only", () => {
  assert.deepEqual(
    resolveTimedOutResponderForNotification({
      sessionData: {
        currentResponderId: " ",
        currentTutorId: " teacher-a ",
      },
      notificationData: {
        recipientId: "teacher-a",
      },
    }),
    {
      ok: true,
      skipReason: "",
      currentResponderId: "teacher-a",
      expiredResponderId: "teacher-a",
      timedOutResponderId: "teacher-a",
    },
  );
  assert.deepEqual(
    resolveTimedOutResponderForNotification({
      sessionData: {},
      notificationData: {
        recipientId: " student-b ",
      },
    }),
    {
      ok: false,
      skipReason: "missing_current_responder",
      currentResponderId: "",
      expiredResponderId: "student-b",
      timedOutResponderId: "",
    },
  );
  assert.deepEqual(
    resolveTimedOutResponderForNotification({
      sessionData: {},
      notificationData: {},
    }),
    {
      ok: false,
      skipReason: "missing_current_responder",
      currentResponderId: "",
      expiredResponderId: "",
      timedOutResponderId: "",
    },
  );
});

test("notification timeout decision keeps active accept-lock notification pending", () => {
  const nowMillis = Date.parse("2026-06-25T10:00:00Z");
  assert.deepEqual(
    buildTimeoutResponderDecision({
      sessionData: {
        currentResponderId: "student-b",
        acceptingTutorId: "student-b",
        acceptingAt: timestampFromMillis(nowMillis - 10_000),
      },
      notificationData: {
        recipientId: "student-b",
      },
      nowMillis,
    }),
    {
      ok: false,
      skipReason: "accept_lock_active",
      currentResponderId: "student-b",
      expiredResponderId: "student-b",
      timedOutResponderId: "student-b",
      shouldProcess: false,
      shouldExpireNotification: false,
    },
  );
});

test("notification timeout decision expires stale notifications only", () => {
  assert.deepEqual(
    buildTimeoutResponderDecision({
      sessionData: {
        currentResponderId: "student-c",
      },
      notificationData: {
        recipientId: "student-b",
      },
    }),
    {
      ok: false,
      skipReason: "current_responder_changed_student-c",
      currentResponderId: "student-c",
      expiredResponderId: "student-b",
      timedOutResponderId: "",
      shouldProcess: false,
      shouldExpireNotification: true,
    },
  );
});

test("notification timeout push validation uses neutral assignment", () => {
  assert.equal(
    isPendingSessionAssignedToResponder(
      {
        status: "pending_confirmation",
        currentResponderId: "student-c",
        currentTutorId: "teacher-a",
      },
      "student-c",
    ),
    true,
  );
  assert.equal(
    isPendingSessionAssignedToResponder(
      {
        status: "pending_confirmation",
        currentResponderId: "student-c",
        currentTutorId: "teacher-a",
      },
      "teacher-a",
    ),
    false,
  );
});

test("notification timeout terminal projection clears pending responder state", () => {
  assert.deepEqual(
    buildTerminalTimeoutSessionProjection({
      sessionData: {
        currentTutorId: "student-b",
        currentResponderId: "student-b",
        currentResponderRole: "student",
        status: "pending_confirmation",
        language: "en",
      },
      triedTutors: ["student-b"],
    }),
    {
      currentTutorId: null,
      currentResponderId: null,
      currentResponderRole: null,
      status: "expired",
      pairStatus: "expired",
      language: "en",
      triedTutors: ["student-b"],
    },
  );
});

test("notification timeout routes student-student failure to requester restore", () => {
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

  const routing = buildTimeoutResponderFailureRouting({
    sessionData,
    responderId: "student-b",
  });

  assert.equal(readRequesterIdForResponderFailure(sessionData), "student-a");
  assert.deepEqual(routing.availableTutors, []);
  assert.equal(routing.terminalStopReason, "student_pair_response_timeout");
  assert.deepEqual(routing.restoreSearchParticipantIds, ["student-a"]);
  assert.deepEqual(
    routing.restoreSearchExcludedCandidateIdsByParticipantId,
    {"student-a": ["student-b"]},
  );
});

test("notification timeout validates next assignment before sending push", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "process_expired_notifications.js"),
    "utf8",
  );
  const shouldNotifyIndex = source.indexOf("if (transition.shouldNotify)");
  const sessionReadIndex = source.indexOf("sessionRef.get()", shouldNotifyIndex);
  const notificationReadIndex = source.indexOf(
    'db.collection("notifications").doc(transition.notificationId).get()',
    sessionReadIndex,
  );
  const assignmentGuardIndex = source.indexOf(
    "!isPendingSessionAssignedToResponder(",
    notificationReadIndex,
  );
  const activeAcceptLockIndex = source.indexOf(
    "hasActiveAcceptLockForResponder({",
    assignmentGuardIndex,
  );
  const notificationStatusIndex = source.indexOf(
    'notificationData.status !== "sent"',
    activeAcceptLockIndex,
  );
  const pushIndex = source.indexOf(
    "await sendVoipPushToTutor(transition.nextTutor",
    notificationStatusIndex,
  );

  assert.ok(sessionReadIndex > shouldNotifyIndex);
  assert.ok(notificationReadIndex > sessionReadIndex);
  assert.ok(assignmentGuardIndex > notificationReadIndex);
  assert.ok(activeAcceptLockIndex > assignmentGuardIndex);
  assert.ok(notificationStatusIndex > activeAcceptLockIndex);
  assert.ok(pushIndex > notificationStatusIndex);
});

test("notification timeout validates assignment before fresh pool scan", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "process_expired_notifications.js"),
    "utf8",
  );
  const preflightIndex = source.indexOf(
    "const preflightSessionSnap = await sessionRef.get()",
  );
  const timeoutDecisionIndex = source.indexOf(
    "const preflightTimeoutDecision = buildTimeoutResponderDecision({",
    preflightIndex,
  );
  const shouldProcessIndex = source.indexOf(
    "preflightTimeoutDecision.shouldProcess",
    timeoutDecisionIndex,
  );
  const statusGuardIndex = source.indexOf(
    "PENDING_RESPONSE_SESSION_STATUSES.has(preflightSessionData.status)",
    shouldProcessIndex,
  );
  const collectIndex = source.indexOf(
    "await failureResponderCollector({",
    statusGuardIndex,
  );

  assert.ok(preflightIndex > 0);
  assert.ok(timeoutDecisionIndex > preflightIndex);
  assert.ok(shouldProcessIndex > timeoutDecisionIndex);
  assert.ok(statusGuardIndex > shouldProcessIndex);
  assert.ok(collectIndex > statusGuardIndex);
});

test("notification timeout fresh pool preflight returns common candidates", async () => {
  const calls = [];
  const result = await collectFreshTimeoutFailureResponderIds({
    db: "db",
    sessionRef: fakeSessionRef({
      status: "pending_confirmation",
      requesterId: "student-a",
      language: "en",
      currentResponderId: "teacher-a",
      currentResponderRole: "native_speaker",
    }),
    notificationData: {
      recipientId: "teacher-a",
    },
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

test("notification timeout fresh pool preflight skips stale notification", async () => {
  let called = false;
  const result = await collectFreshTimeoutFailureResponderIds({
    sessionRef: fakeSessionRef({
      status: "pending_confirmation",
      requesterId: "student-a",
      language: "en",
      currentResponderId: "teacher-b",
      currentResponderRole: "native_speaker",
    }),
    notificationData: {
      recipientId: "teacher-a",
    },
    failureResponderCollector: async () => {
      called = true;
      return {availableTutors: ["teacher-fresh"]};
    },
  });

  assert.equal(result, null);
  assert.equal(called, false);
});

test("notification timeout fresh pool preflight skips active accept-lock", async () => {
  const nowMillis = Date.parse("2026-06-25T10:00:00.000Z");
  let called = false;
  const result = await collectFreshTimeoutFailureResponderIds({
    sessionRef: fakeSessionRef({
      status: "pending_confirmation",
      requesterId: "student-a",
      language: "en",
      currentResponderId: "teacher-a",
      currentResponderRole: "native_speaker",
      acceptingTutorId: "teacher-a",
      acceptingAt: timestampFromMillis(nowMillis - 1_000),
    }),
    notificationData: {
      recipientId: "teacher-a",
    },
    nowMillis,
    failureResponderCollector: async () => {
      called = true;
      return {availableTutors: ["teacher-fresh"]};
    },
  });

  assert.equal(result, null);
  assert.equal(called, false);
});

test("notification timeout clears pending responder fields on terminal expiry", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "process_expired_notifications.js"),
    "utf8",
  );

  const terminalUpdateIndex = source.indexOf("transaction.update(sessionRef, {");
  const legacyDeleteIndex = source.indexOf(
    "currentTutorId: admin.firestore.FieldValue.delete()",
    terminalUpdateIndex,
  );
  const responderDeleteIndex = source.indexOf(
    "currentResponderId: admin.firestore.FieldValue.delete()",
    legacyDeleteIndex,
  );
  const responderRoleDeleteIndex = source.indexOf(
    "currentResponderRole: admin.firestore.FieldValue.delete()",
    responderDeleteIndex,
  );
  const expiredStatusIndex = source.indexOf(
    "status: VIDEO_SESSION_STATUS.EXPIRED",
    responderRoleDeleteIndex,
  );

  assert.ok(legacyDeleteIndex > terminalUpdateIndex);
  assert.ok(responderDeleteIndex > legacyDeleteIndex);
  assert.ok(responderRoleDeleteIndex > responderDeleteIndex);
  assert.ok(expiredStatusIndex > responderRoleDeleteIndex);
});

test("notification timeout backend either hands off or expires terminal pair", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "process_expired_notifications.js"),
    "utf8",
  );

  const terminalBranchIndex = source.indexOf("if (!nextTutor) {");
  const terminalReleaseIndex = source.indexOf(
    "await releaseSessionPairLocksInTransaction({",
    terminalBranchIndex,
  );
  const terminalSessionUpdateIndex = source.indexOf(
    "transaction.update(sessionRef, {",
    terminalReleaseIndex,
  );
  const expiredStatusIndex = source.indexOf(
    "status: VIDEO_SESSION_STATUS.EXPIRED",
    terminalSessionUpdateIndex,
  );
  const expireReasonIndex = source.indexOf(
    "expireReason: terminalStopReason",
    expiredStatusIndex,
  );
  const handoffNotificationIndex = source.indexOf(
    "const notification = createIncomingCallNotificationInTransaction({",
    terminalSessionUpdateIndex,
  );
  const handoffPairLockIndex = source.indexOf(
    "applyPreparedPairLockWrites(transaction, preparedPairLock)",
    handoffNotificationIndex,
  );
  const pushValidationIndex = source.indexOf(
    "const validationReads = [sessionRef.get()]",
    handoffPairLockIndex,
  );
  const sendPushIndex = source.indexOf(
    "await sendVoipPushToTutor(transition.nextTutor",
    pushValidationIndex,
  );
  const dailyCleanupIndex = source.indexOf(
    "await deleteDailyRoomForSession({",
    terminalSessionUpdateIndex,
  );

  assert.ok(terminalBranchIndex > 0);
  assert.ok(terminalReleaseIndex > terminalBranchIndex);
  assert.ok(terminalSessionUpdateIndex > terminalReleaseIndex);
  assert.ok(expiredStatusIndex > terminalSessionUpdateIndex);
  assert.ok(expireReasonIndex > expiredStatusIndex);
  assert.ok(handoffNotificationIndex > terminalSessionUpdateIndex);
  assert.ok(handoffPairLockIndex > handoffNotificationIndex);
  assert.ok(pushValidationIndex > handoffPairLockIndex);
  assert.ok(sendPushIndex > pushValidationIndex);
  assert.ok(dailyCleanupIndex > terminalSessionUpdateIndex);
});

test("notification timeout excludes timed-out responder during teacher handoff", () => {
  const lockInput = buildTimeoutNextResponderPairLockInput({
    db: "db",
    transaction: "transaction",
    sessionId: "session-a",
    sessionData: {language: "en"},
    timedOutResponderId: "teacher-a",
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
    SEARCH_REQUEST_STATUS.EXPIRED,
  );
  assert.equal(lockInput.currentResponderStopReason, "response_timeout");
  assert.deepEqual(lockInput.requesterExcludedCandidateIds, ["teacher-a"]);
});

test("notification timeout can handoff timed-out teacher to next student", () => {
  const routing = buildTimeoutResponderFailureRouting({
    sessionData: {
      scenario: "student_teacher",
      studentId: "student-a",
      currentTutorId: "teacher-a",
      currentResponderRole: "native_speaker",
    },
    responderId: "teacher-a",
    availableTutors: ["student-fresh", "teacher-fresh"],
  });
  const lockInput = buildTimeoutNextResponderPairLockInput({
    db: "db",
    transaction: "transaction",
    sessionId: "session-a",
    sessionData: {language: "en"},
    timedOutResponderId: "teacher-a",
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

test("notification timeout keeps teacher handoff candidates", () => {
  const routing = buildTimeoutResponderFailureRouting({
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
    "no_available_responder_after_timeout",
  );
  assert.deepEqual(routing.restoreSearchParticipantIds, ["student-a"]);
  assert.deepEqual(
    routing.restoreSearchExcludedCandidateIdsByParticipantId,
    {"student-a": ["teacher-a"]},
  );
});

test("notification timeout ends direct teacher calls without queue restore", () => {
  const routing = buildTimeoutResponderFailureRouting({
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
  assert.equal(routing.terminalStopReason, "direct_call_timeout");
  assert.deepEqual(routing.restoreSearchParticipantIds, []);
  assert.deepEqual(
    routing.restoreSearchExcludedCandidateIdsByParticipantId,
    {},
  );
});

test("notification timeout treats legacy direct tutor id as terminal direct call", () => {
  const routing = buildTimeoutResponderFailureRouting({
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
  assert.equal(routing.terminalStopReason, "direct_call_timeout");
  assert.deepEqual(routing.restoreSearchParticipantIds, []);
});

test("notification timeout uses fresh common pool candidates after teacher timeout", () => {
  const routing = buildTimeoutResponderFailureRouting({
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
