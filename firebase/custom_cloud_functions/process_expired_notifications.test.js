const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    buildTimeoutResponderFailureRouting,
    readRequesterIdForResponderFailure,
  },
} = require("./process_expired_notifications");

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

test("notification timeout skips sessions with active accept lock", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "process_expired_notifications.js"),
    "utf8",
  );
  const timedOutTutorIndex = source.indexOf(
    "const timedOutTutorId = currentTutorId || expiredTutorId;",
  );
  const acceptLockGuardIndex = source.indexOf(
    "hasActiveAcceptLockForResponder({",
    timedOutTutorIndex,
  );
  const skipReasonIndex = source.indexOf(
    'skipReason: "accept_lock_active"',
    acceptLockGuardIndex,
  );
  const expireNotificationIndex = source.indexOf(
    "transaction.update(notificationDoc.ref, expireNotificationUpdate);",
    acceptLockGuardIndex,
  );
  const acceptAttemptDeleteIndex = source.indexOf(
    "acceptAttemptId: admin.firestore.FieldValue.delete()",
    acceptLockGuardIndex,
  );

  assert.ok(acceptLockGuardIndex > timedOutTutorIndex);
  assert.ok(skipReasonIndex > acceptLockGuardIndex);
  assert.ok(acceptAttemptDeleteIndex > skipReasonIndex);
  assert.ok(
    expireNotificationIndex === -1 ||
      expireNotificationIndex > skipReasonIndex,
    "active accept lock must return before expiring notification",
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
    "freshValidationData.currentTutorId !== transition.nextTutor",
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
