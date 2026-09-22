const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  buildResponderFailurePoolFingerprint,
  collectAvailableRespondersAfterFailure,
  isDirectMatchSession,
  isStudentPairResponderFailure,
  readAvailableRespondersAfterFailure,
  readFreshResponderIds,
  readResponderRole,
  responderFailurePoolFingerprintMatches,
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

test("teacher responder failure collects fresh common pool without role priority", async () => {
  const calls = [];
  const result = await collectAvailableRespondersAfterFailure({
    db: "db",
    requesterId: "student-a",
    sessionData: {
      scenario: "student_teacher",
      language: "en",
      currentResponderId: "teacher-a",
      currentResponderRole: "native_speaker",
      matchContext: {
        filters: {preferredLevel: "B1"},
      },
      availableTutors: ["teacher-a", "teacher-stale"],
    },
    responderId: "teacher-a",
    now: new Date("2026-06-25T10:00:00.000Z"),
    nowMillis: Date.parse("2026-06-25T10:00:00.000Z"),
    candidatePoolCollector: async (input) => {
      calls.push(input);
      return {
        candidates: [
          {
            userId: "student-fresh",
            role: "student",
            source: "active_student_queue",
          },
          {
            userId: "teacher-fresh",
            role: "native_speaker",
            source: "teacher_availability",
          },
        ],
        stats: {studentCandidates: 1, teacherCandidates: 1},
      };
    },
  });

  assert.deepEqual(result.availableTutors, ["student-fresh", "teacher-fresh"]);
  assert.equal(result.source, "common_pool");
  assert.deepEqual(result.stats, {studentCandidates: 1, teacherCandidates: 1});
  assert.equal(calls.length, 1);
  assert.equal(calls[0].db, "db");
  assert.equal(calls[0].requesterId, "student-a");
  assert.equal(calls[0].language, "en");
  assert.deepEqual(calls[0].requesterFilters, {preferredLevel: "B1"});
  assert.equal(calls[0].includeStudents, true);
  assert.equal(calls[0].includeTeachers, true);
});

test("student responder failure does not collect common pool", async () => {
  let called = false;
  const result = await collectAvailableRespondersAfterFailure({
    db: "db",
    requesterId: "student-a",
    sessionData: {
      scenario: "student_student",
      language: "en",
      currentResponderId: "student-b",
      currentResponderRole: "student",
      availableTutors: ["student-b", "teacher-a"],
    },
    responderId: "student-b",
    candidatePoolCollector: async () => {
      called = true;
      return {candidates: [{userId: "teacher-a", role: "native_speaker"}]};
    },
  });

  assert.equal(called, false);
  assert.deepEqual(result.availableTutors, []);
  assert.equal(result.source, "student_pair_terminal");
});

test("direct teacher failure does not collect common pool", async () => {
  let called = false;
  const sessionData = {
    scenario: "student_teacher",
    language: "en",
    currentResponderId: "teacher-a",
    currentResponderRole: "native_speaker",
    availableTutors: ["teacher-a"],
    matchContext: {
      matchMode: "direct",
      directCandidateId: "teacher-a",
    },
  };

  const result = await collectAvailableRespondersAfterFailure({
    db: "db",
    requesterId: "student-a",
    sessionData,
    responderId: "teacher-a",
    candidatePoolCollector: async () => {
      called = true;
      return {candidates: [{userId: "teacher-b", role: "native_speaker"}]};
    },
  });

  assert.equal(isDirectMatchSession(sessionData), true);
  assert.equal(called, false);
  assert.deepEqual(result.availableTutors, ["teacher-a"]);
  assert.equal(result.source, "direct_session_snapshot");
});

test("fresh responder ids preserve common pool order without role priority", () => {
  assert.deepEqual(
    readFreshResponderIds([
      {
        userId: "student-a",
        role: "student",
        source: "active_student_queue",
      },
      {
        userId: "teacher-a",
        role: "native_speaker",
        source: "teacher_availability",
      },
      {
        userId: "student-b",
        role: "student",
        source: "teacher_availability",
      },
      {
        userId: "student-c",
        role: "student",
      },
      {
        userId: "teacher-b",
        role: "native_speaker",
        source: "active_student_queue",
      },
      {
        userId: "teacher-c",
        role: "native_speaker",
      },
      {
        userId: "student-a",
        role: "student",
        source: "active_student_queue",
      },
    ]),
    ["student-a", "teacher-a"],
  );
});

test("responder failure pool fingerprint detects stale filters", () => {
  const base = buildResponderFailurePoolFingerprint({
    sessionData: {
      scenario: "student_teacher",
      requesterId: "student-a",
      language: "en",
      currentResponderId: "teacher-a",
      currentResponderRole: "native_speaker",
      matchContext: {
        filters: {
          levelRank: 3,
          cityKey: "boston",
        },
      },
    },
    responderId: "teacher-a",
  });
  const sameDifferentKeyOrder = buildResponderFailurePoolFingerprint({
    sessionData: {
      scenario: "student_teacher",
      requesterId: "student-a",
      language: "en",
      currentResponderId: "teacher-a",
      currentResponderRole: "native_speaker",
      matchContext: {
        filters: {
          cityKey: "boston",
          levelRank: 3,
        },
      },
    },
    responderId: "teacher-a",
  });
  const changedFilters = buildResponderFailurePoolFingerprint({
    sessionData: {
      scenario: "student_teacher",
      requesterId: "student-a",
      language: "en",
      currentResponderId: "teacher-a",
      currentResponderRole: "native_speaker",
      matchContext: {
        filters: {
          levelRank: 4,
          cityKey: "boston",
        },
      },
    },
    responderId: "teacher-a",
  });

  assert.equal(
    responderFailurePoolFingerprintMatches(base, sameDifferentKeyOrder),
    true,
  );
  assert.equal(
    responderFailurePoolFingerprintMatches(base, changedFilters),
    false,
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
