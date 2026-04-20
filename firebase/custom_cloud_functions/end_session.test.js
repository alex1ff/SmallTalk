const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    buildStudentCallCharge,
    resolveTeacherEarningUserId,
    shouldProcessExpiredEndReason,
  },
} = require("./end_session");

test("expired end reasons are ignored when policy expiry moved into the future", () => {
  const shouldProcess = shouldProcessExpiredEndReason({
    sessionData: {
      expiresAt: {
        toMillis: () => Date.parse("2026-04-14T10:10:00Z"),
      },
      sessionPolicy: {
        effectiveLimitSeconds: 600,
      },
    },
    endReason: "expired",
    requestTimestamp: Date.parse("2026-04-14T10:05:01Z"),
  });

  assert.equal(shouldProcess, false);
});

test("expired end reasons are honored once the stored limit is reached", () => {
  const shouldProcess = shouldProcessExpiredEndReason({
    sessionData: {
      expiresAt: {
        toMillis: () => Date.parse("2026-04-14T10:05:00Z"),
      },
      sessionPolicy: {
        effectiveLimitSeconds: 300,
      },
    },
    endReason: "expired",
    requestTimestamp: Date.parse("2026-04-14T10:05:00Z"),
  });

  assert.equal(shouldProcess, true);
});

test("manual end reasons bypass the expiry guard", () => {
  const shouldProcess = shouldProcessExpiredEndReason({
    sessionData: {
      expiresAt: {
        toMillis: () => Date.parse("2026-04-14T10:10:00Z"),
      },
      sessionPolicy: {
        effectiveLimitSeconds: 600,
      },
    },
    endReason: "user_ended",
    requestTimestamp: Date.parse("2026-04-14T10:05:01Z"),
  });

  assert.equal(shouldProcess, true);
});

test("buildStudentCallCharge keeps the free minute and clamps balance", () => {
  const charge = buildStudentCallCharge({
    userId: "student-a",
    currentMinutes: 3,
    currentSmallTalks: 0.3,
    duration: 180,
    formattedDuration: "3:00",
  });

  assert.equal(charge.freeMinuteApplied, true);
  assert.equal(charge.billableMinutes, 2);
  assert.equal(charge.amountST, 0.2);
  assert.equal(charge.newMinutes, 1);
  assert.equal(charge.newSmallTalks, 0.1);
});

test("buildStudentCallCharge can charge a second student without payout semantics", () => {
  const firstStudent = buildStudentCallCharge({
    userId: "student-a",
    currentMinutes: 0.5,
    currentSmallTalks: 0.05,
    duration: 300,
    formattedDuration: "5:00",
  });
  const secondStudent = buildStudentCallCharge({
    userId: "student-b",
    currentMinutes: 1,
    currentSmallTalks: 0.1,
    duration: 300,
    formattedDuration: "5:00",
  });

  assert.equal(firstStudent.newMinutes, 0);
  assert.equal(secondStudent.newMinutes, 0);
  assert.equal(firstStudent.amountST, 0.4);
  assert.equal(secondStudent.amountST, 0.4);
});

test("resolveTeacherEarningUserId pays the teacher regardless of call direction", () => {
  assert.equal(
    resolveTeacherEarningUserId({
      requesterId: "student-a",
      requesterRole: "student",
      responderId: "teacher-b",
      acceptedResponderRole: "native_speaker",
    }),
    "teacher-b",
  );
  assert.equal(
    resolveTeacherEarningUserId({
      requesterId: "teacher-a",
      requesterRole: "native_speaker",
      responderId: "student-b",
      acceptedResponderRole: "student",
    }),
    "teacher-a",
  );
  assert.equal(
    resolveTeacherEarningUserId({
      requesterId: "student-a",
      requesterRole: "student",
      responderId: "student-b",
      acceptedResponderRole: "student",
    }),
    null,
  );
});

test("endSession source keeps the ignored_expired_end wrapper path", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "end_session.js"),
    "utf8",
  );

  assert.match(source, /shouldProcessExpiredEndReason\(\{/);
  assert.match(source, /status:\s*"ignored_expired_end"/);
  assert.match(source, /acceptedResponderRole === "student"/);
  assert.match(source, /acceptedResponderRole === "native_speaker"/);
  assert.match(source, /teacherEarningUserId/);
  assert.match(source, /txResult\.teacherEligibleForPayout/);
});
