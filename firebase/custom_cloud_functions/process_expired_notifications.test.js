const test = require("node:test");
const assert = require("node:assert/strict");
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
