const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    buildDeclineResponderFailureRouting,
    readRequesterIdForResponderFailure,
  },
} = require("./decline_call");

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
    "This session is not assigned to you",
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
    "validationSessionData.currentTutorId !== nextTutor",
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
