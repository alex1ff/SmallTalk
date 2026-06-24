const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    buildTerminalTimeoutSessionProjection,
    buildTimeoutResponderDecision,
    buildTimeoutResponderFailureRouting,
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
