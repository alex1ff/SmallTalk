const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    DIRECT_CALL_STATUS_TTL_SECONDS,
    buildAccessDecision,
    buildDirectCallStatusDecision,
    normalizeTargetUserId,
  },
} = require("./direct_call_status");
const {
  DAY_LIMIT_SECONDS,
} = require("./subscription_usage_shared");

const NOW = new Date("2026-05-26T12:00:00.000Z");
const NOW_MILLIS = NOW.getTime();

function futureTimestamp(minutes = 30) {
  return {
    toDate: () => new Date(NOW_MILLIS + minutes * 60 * 1000),
    toMillis: () => NOW_MILLIS + minutes * 60 * 1000,
  };
}

function activeSubscription() {
  return {
    expiresAt: futureTimestamp(60),
  };
}

function requester(overrides = {}) {
  return {
    role: "student",
    learningLanguage: {code: "en"},
    subscription: activeSubscription(),
    blockedUsers: [],
    ...overrides,
  };
}

function availableTutor(overrides = {}) {
  return {
    role: "native_speaker",
    language_instruction_NS: {code: "en"},
    teacherAccreditationStatus: "approved",
    blockedUsers: [],
    availabilityToday: {enabled: true},
    ...overrides,
  };
}

function decision({targetData = availableTutor(), ...overrides} = {}) {
  return buildDirectCallStatusDecision({
    requesterId: "student-a",
    requesterData: requester(),
    requesterRole: "student",
    targetUserId: "teacher-a",
    targetData,
    language: "en",
    now: NOW,
    checkedAtMillis: NOW_MILLIS,
    ...overrides,
  });
}

test("direct call status target ids are plain document ids only", () => {
  assert.equal(normalizeTargetUserId(" teacher-a "), "teacher-a");
  assert.equal(normalizeTargetUserId("users/teacher-a"), "");
  assert.equal(normalizeTargetUserId(""), "");
  assert.equal(normalizeTargetUserId(null), "");
  assert.equal(normalizeTargetUserId("x".repeat(129)), "");
  assert.equal(normalizeTargetUserId("."), "");
  assert.equal(normalizeTargetUserId(".."), "");
  assert.equal(normalizeTargetUserId("__bad__"), "");
});

test("direct call access fails closed before target live state is needed", () => {
  assert.deepEqual(
    buildAccessDecision({
      requesterRole: "native_speaker",
      requesterData: requester({role: "native_speaker"}),
      usageData: null,
      nowMillis: NOW_MILLIS,
    }),
    {
      allowed: false,
      callability: "unknown",
      reason: "unavailable",
    },
  );

  assert.deepEqual(
    buildAccessDecision({
      requesterRole: "student",
      requesterData: requester({subscription: null, giftMinutes: null}),
      usageData: null,
      nowMillis: NOW_MILLIS,
    }),
    {
      allowed: false,
      callability: "requires_access",
      reason: "requires_access",
    },
  );

  assert.deepEqual(
    buildAccessDecision({
      requesterRole: "student",
      requesterData: requester(),
      usageData: {
        dayKey: "2026-05-26",
        dayDurationSeconds: DAY_LIMIT_SECONDS,
      },
      nowMillis: NOW_MILLIS,
    }),
    {
      allowed: false,
      callability: "requires_access",
      reason: "requires_access",
    },
  );
});

test("direct call status returns callable without exposing live fields", () => {
  const status = decision();

  assert.equal(status.status, "ok");
  assert.equal(status.targetUserId, "teacher-a");
  assert.equal(status.canStartDirectCall, true);
  assert.equal(status.callability, "callable");
  assert.equal(status.reason, "ready");
  assert.equal(status.ttlSeconds, DIRECT_CALL_STATUS_TTL_SECONDS);
  assert.equal(status.currentSessionId, undefined);
  assert.equal(status.availabilityToday, undefined);
  assert.equal(status.timezoneOffsetMinutes, undefined);
});

test("direct call status gives requester-owned denials separately", () => {
  assert.equal(
    decision({targetUserId: "student-a"}).callability,
    "self",
  );
  assert.equal(
    decision({
      requesterData: requester({blockedUsers: ["teacher-a"]}),
    }).callability,
    "blocked_for_requester",
  );
});

test("direct call status collapses target-side denials to unavailable", () => {
  const unavailableCases = [
    {...availableTutor(), role: "student"},
    availableTutor({teacherAccreditationStatus: "pending"}),
    availableTutor({availabilityToday: {enabled: false}, isAvailable: true}),
    availableTutor({isInCall: true}),
    availableTutor({availableAfter: futureTimestamp(10)}),
    availableTutor({blockedUsers: ["student-a"]}),
    availableTutor({language_instruction_NS: {code: "es"}}),
  ];

  for (const targetData of unavailableCases) {
    const status = decision({targetData});
    assert.equal(status.canStartDirectCall, false);
    assert.equal(status.callability, "unavailable");
    assert.equal(status.reason, "unavailable");
  }

  assert.equal(
    decision({sameDayRepeatBlocked: true}).callability,
    "unavailable",
  );
  assert.equal(
    decision({targetHasCallToken: false}).callability,
    "unavailable",
  );
});

test("direct call status callable is exported and does not edit public projection", () => {
  const indexSource = fs.readFileSync(path.join(__dirname, "index.js"), "utf8");
  const publicProfileSource = fs.readFileSync(
    path.join(__dirname, "public_user_profiles.js"),
    "utf8",
  );

  assert.match(indexSource, /exports\.getDirectCallStatus/);
  assert.doesNotMatch(publicProfileSource, /getDirectCallStatus/);
});

test("direct call status source checks access and target role before live state", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "direct_call_status.js"),
    "utf8",
  );
  const nonStudentGateIndex = source.indexOf('requesterRole !== "student"');
  const targetReadIndex = source.indexOf('collection("users").doc(targetUserId)');
  const targetRoleGateIndex = source.indexOf('targetRole !== "native_speaker"');
  const targetApprovalGateIndex = source.indexOf('!targetProfile.approvedTeacher');
  const availabilityIndex = source.indexOf(
    "const availabilityCheck = evaluateTutorAvailabilityWindow",
  );

  assert.ok(nonStudentGateIndex > 0);
  assert.ok(targetReadIndex > nonStudentGateIndex);
  assert.ok(targetRoleGateIndex > 0);
  assert.ok(availabilityIndex > targetRoleGateIndex);
  assert.ok(availabilityIndex > targetApprovalGateIndex);
  assert.match(source, /getReadOnlyUserVoipTokenState/);
  assert.match(source, /targetHasCallToken:\s*false/);
});
