const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildAcceptedSessionPolicyState,
  buildInitialSessionPolicyState,
  buildUniversalSessionPolicy,
  getSessionParticipantIds,
  getSessionPolicyEffectiveLimitSeconds,
  getSessionPolicyExpiresAt,
} = require("./video_sessions_shared");

test("buildUniversalSessionPolicy returns the V2 default session contract", () => {
  assert.deepEqual(buildUniversalSessionPolicy(), {
    baseLimitSeconds: 300,
    warningLeadSeconds: 60,
    maxExtensionCount: 1,
    extensionSeconds: 300,
    extensionRequests: {},
    extensionApproved: false,
    effectiveLimitSeconds: 300,
  });
});

test("buildUniversalSessionPolicy preserves supported extension metadata", () => {
  const policy = buildUniversalSessionPolicy({
    baseLimitSeconds: 300,
    warningLeadSeconds: 120,
    maxExtensionCount: 1,
    extensionSeconds: 300,
    extensionRequests: { "user-a": true },
    extensionApproved: true,
    effectiveLimitSeconds: 600,
  });

  assert.deepEqual(policy, {
    baseLimitSeconds: 300,
    warningLeadSeconds: 120,
    maxExtensionCount: 1,
    extensionSeconds: 300,
    extensionRequests: { "user-a": true },
    extensionApproved: true,
    effectiveLimitSeconds: 600,
  });
});

test("buildUniversalSessionPolicy normalizes invalid policy values safely", () => {
  const policy = buildUniversalSessionPolicy({
    baseLimitSeconds: -1,
    warningLeadSeconds: 999,
    maxExtensionCount: -1,
    extensionSeconds: "bad",
    extensionRequests: ["user-a"],
    extensionApproved: "yes",
    effectiveLimitSeconds: 1,
  });

  assert.deepEqual(policy, {
    baseLimitSeconds: 300,
    warningLeadSeconds: 300,
    maxExtensionCount: 1,
    extensionSeconds: 300,
    extensionRequests: {},
    extensionApproved: false,
    effectiveLimitSeconds: 300,
  });
});

test("getSessionPolicyExpiresAt derives expiry from effective limit", () => {
  const nowMillis = Date.parse("2026-04-14T10:00:00Z");
  const expiresAt = getSessionPolicyExpiresAt(
    { effectiveLimitSeconds: 600 },
    nowMillis,
  );

  assert.equal(expiresAt.toISOString(), "2026-04-14T10:10:00.000Z");
  assert.equal(
    getSessionPolicyEffectiveLimitSeconds({ effectiveLimitSeconds: 600 }),
    600,
  );
});

test("buildInitialSessionPolicyState stamps new sessions with 5-minute policy", () => {
  const nowMillis = Date.parse("2026-04-14T10:00:00Z");
  const state = buildInitialSessionPolicyState(nowMillis);

  assert.equal(state.sessionPolicy.baseLimitSeconds, 300);
  assert.equal(state.sessionPolicy.warningLeadSeconds, 60);
  assert.equal(state.sessionPolicy.maxExtensionCount, 1);
  assert.equal(state.sessionPolicy.extensionSeconds, 300);
  assert.deepEqual(state.sessionPolicy.extensionRequests, {});
  assert.equal(state.sessionPolicy.extensionApproved, false);
  assert.equal(state.sessionPolicy.effectiveLimitSeconds, 300);
  assert.equal(state.maxDurationMs, 300000);
  assert.equal(state.expiresAt.toISOString(), "2026-04-14T10:05:00.000Z");
});

test("buildAcceptedSessionPolicyState uses stored policy-backed limits", () => {
  const nowMillis = Date.parse("2026-04-14T10:00:00Z");
  const state = buildAcceptedSessionPolicyState(
    {
      sessionPolicy: {
        baseLimitSeconds: 300,
        warningLeadSeconds: 60,
        maxExtensionCount: 1,
        extensionSeconds: 300,
        effectiveLimitSeconds: 600,
      },
    },
    nowMillis,
  );

  assert.equal(state.sessionPolicy.effectiveLimitSeconds, 600);
  assert.equal(state.maxDurationMs, 600000);
  assert.equal(state.expiresAt.toISOString(), "2026-04-14T10:10:00.000Z");
});

test("buildAcceptedSessionPolicyState preserves legacy fallback without policy", () => {
  const nowMillis = Date.parse("2026-04-14T10:00:00Z");
  const state = buildAcceptedSessionPolicyState({}, nowMillis);

  assert.equal(state.sessionPolicy, null);
  assert.equal(state.maxDurationMs, 3600000);
  assert.equal(state.expiresAt.toISOString(), "2026-04-14T11:00:00.000Z");
});

test("getSessionParticipantIds includes accepted responder fallback", () => {
  assert.deepEqual(
    getSessionParticipantIds({
      participantIds: ["requester-a"],
      matchContext: {
        requesterId: "requester-a",
        acceptedResponderId: "responder-b",
      },
    }),
    ["requester-a", "responder-b"],
  );
});
