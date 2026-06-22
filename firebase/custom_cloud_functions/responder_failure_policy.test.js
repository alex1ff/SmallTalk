const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  isStudentPairResponderFailure,
  readAvailableRespondersAfterFailure,
  readResponderRole,
  resolveResponderFailureStopReason,
} = require("./responder_failure_policy");

test("student-student responder failure does not handoff to stale candidates", () => {
  const sessionData = {
    scenario: "student_student",
    currentResponderId: "student-b",
    currentResponderRole: "student",
    participantRoles: {
      "student-a": "student",
      "student-b": "student",
    },
    availableTutors: ["student-b", "student-c", "teacher-a"],
  };

  assert.equal(
    isStudentPairResponderFailure({
      sessionData,
      responderId: "student-b",
    }),
    true,
  );
  assert.equal(readResponderRole(sessionData, "student-b"), "student");
  assert.deepEqual(
    readAvailableRespondersAfterFailure({
      sessionData,
      responderId: "student-b",
    }),
    [],
  );
  assert.equal(
    resolveResponderFailureStopReason({
      sessionData,
      responderId: "student-b",
      fallbackStopReason: "no_available_responder_after_decline",
      studentPairStopReason: "student_pair_declined",
    }),
    "student_pair_declined",
  );
});

test("student-teacher responder failure can handoff to remaining candidates", () => {
  const sessionData = {
    scenario: "student_teacher",
    currentResponderId: "teacher-a",
    currentResponderRole: "native_speaker",
    participantRoles: {
      "student-a": "student",
      "teacher-a": "native_speaker",
    },
    availableTutors: ["teacher-a", "teacher-b"],
  };

  assert.equal(
    isStudentPairResponderFailure({
      sessionData,
      responderId: "teacher-a",
    }),
    false,
  );
  assert.equal(readResponderRole(sessionData, "teacher-a"), "native_speaker");
  assert.deepEqual(
    readAvailableRespondersAfterFailure({
      sessionData,
      responderId: "teacher-a",
    }),
    ["teacher-a", "teacher-b"],
  );
  assert.equal(
    resolveResponderFailureStopReason({
      sessionData,
      responderId: "teacher-a",
      fallbackStopReason: "no_available_responder_after_decline",
      studentPairStopReason: "student_pair_declined",
    }),
    "no_available_responder_after_decline",
  );
});

test("decline and timeout flows use responder failure policy", () => {
  const declineSource = fs.readFileSync(
    path.join(__dirname, "decline_call.js"),
    "utf8",
  );
  const timeoutSource = fs.readFileSync(
    path.join(__dirname, "process_expired_notifications.js"),
    "utf8",
  );

  assert.match(declineSource, /readAvailableRespondersAfterFailure\(\{/);
  assert.match(declineSource, /student_pair_declined/);
  assert.match(timeoutSource, /readAvailableRespondersAfterFailure\(\{/);
  assert.match(timeoutSource, /student_pair_response_timeout/);
});
