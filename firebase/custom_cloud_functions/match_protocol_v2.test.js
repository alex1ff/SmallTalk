const test = require("node:test");
const assert = require("node:assert/strict");
const {
  MATCH_ACTION,
  MATCH_DECISION,
  MATCH_DELIVERY,
  MATCH_SURFACE,
  allParticipantsAccepted,
  buildInitialParticipantStates,
  claimCallKitDispatch,
  finalizeCallKitDelivery,
  transitionParticipantState,
} = require("./match_protocol_v2");
const {
  resolveMatchProtocolVersion,
} = require("./match_pair_lock");

function studentState(overrides = {}) {
  return {
    role: "student",
    surface: MATCH_SURFACE.PENDING,
    decision: MATCH_DECISION.PENDING,
    delivery: MATCH_DELIVERY.PENDING,
    callKitId: "call-student",
    actionId: null,
    dispatchId: null,
    deliveryFailureKind: null,
    updatedAt: null,
    ...overrides,
  };
}

test("protocol v2 initializes students pending and teachers CallKit-only", () => {
  const states = buildInitialParticipantStates({
    participantIds: ["student-a", "teacher-a"],
    participantRoles: {
      "student-a": "student",
      "teacher-a": "native_speaker",
    },
    callKitIds: {
      "student-a": "call-student",
      "teacher-a": "call-teacher",
    },
  });
  assert.equal(states["student-a"].surface, MATCH_SURFACE.PENDING);
  assert.equal(states["teacher-a"].surface, MATCH_SURFACE.CALLKIT);
  assert.equal(states["teacher-a"].delivery, MATCH_DELIVERY.PENDING);
});

test("protocol v2 is capability-gated for legacy student and teacher apps", () => {
  assert.equal(resolveMatchProtocolVersion({
    requestedVersion: 2,
    requesterSearchData: {matchProtocolVersion: 2},
    responderSearchData: {matchProtocolVersion: 1},
    responderRole: "student",
  }), 1);
  assert.equal(resolveMatchProtocolVersion({
    requestedVersion: 2,
    requesterSearchData: {matchProtocolVersion: 2},
    responderRole: "native_speaker",
    responderCapabilityVersion: 1,
  }), 1);
  assert.equal(resolveMatchProtocolVersion({
    requestedVersion: 2,
    requesterSearchData: {matchProtocolVersion: 2},
    responderRole: "native_speaker",
    responderCapabilityVersion: 2,
    responderCallKitCapable: true,
    responderCapabilityExpiresAt: 2_000,
    nowMillis: 1_000,
  }), 2);
});

test("foreground claim wins before dispatch and is idempotent", () => {
  const claimed = transitionParticipantState({
    state: studentState(),
    action: MATCH_ACTION.CLAIM_IN_APP,
    actionId: "claim-a",
  });
  assert.equal(claimed.changed, true);
  assert.equal(claimed.state.surface, MATCH_SURFACE.IN_APP);
  assert.equal(claimed.state.decision, MATCH_DECISION.ACCEPTED);
  assert.equal(claimed.state.delivery, MATCH_DELIVERY.NOT_REQUIRED);

  const dispatch = claimCallKitDispatch({
    state: claimed.state,
    dispatchId: "dispatch-a",
    callKitId: "call-a",
  });
  assert.equal(dispatch.changed, false);
  assert.equal(dispatch.reason, "decision_locked");

  const duplicate = transitionParticipantState({
    state: claimed.state,
    action: MATCH_ACTION.CLAIM_IN_APP,
    actionId: "claim-a",
  });
  assert.equal(duplicate.changed, false);
  assert.equal(duplicate.reason, "duplicate_action");
});

test("atomic CallKit dispatch wins before a late foreground claim", () => {
  const dispatch = claimCallKitDispatch({
    state: studentState(),
    dispatchId: "dispatch-a",
    callKitId: "call-a",
  });
  assert.equal(dispatch.changed, true);
  assert.equal(dispatch.state.surface, MATCH_SURFACE.CALLKIT);
  assert.equal(dispatch.state.delivery, MATCH_DELIVERY.DISPATCHING);

  const lateClaim = transitionParticipantState({
    state: dispatch.state,
    action: MATCH_ACTION.CLAIM_IN_APP,
    actionId: "claim-late",
  });
  assert.equal(lateClaim.changed, false);
  assert.equal(lateClaim.reason, "surface_locked");
});

test("CallKit acceptance is gated by delivery and two accepts finalize", () => {
  const notDelivered = transitionParticipantState({
    state: studentState({surface: MATCH_SURFACE.CALLKIT}),
    action: MATCH_ACTION.ACCEPT,
    actionId: "accept-a",
  });
  assert.equal(notDelivered.reason, "callkit_not_delivered");

  const first = transitionParticipantState({
    state: studentState({
      surface: MATCH_SURFACE.CALLKIT,
      delivery: MATCH_DELIVERY.SENT,
    }),
    action: MATCH_ACTION.ACCEPT,
    actionId: "accept-a",
  });
  const second = transitionParticipantState({
    state: studentState({
      surface: MATCH_SURFACE.CALLKIT,
      delivery: MATCH_DELIVERY.SENT,
    }),
    action: MATCH_ACTION.ACCEPT,
    actionId: "accept-b",
  });
  assert.equal(allParticipantsAccepted({a: first.state, b: second.state}, [
    "a",
    "b",
  ]), true);
  const duplicate = transitionParticipantState({
    state: first.state,
    action: MATCH_ACTION.ACCEPT,
    actionId: "accept-a",
  });
  assert.equal(duplicate.reason, "duplicate_action");
});

test("decline stays monotonic while explicit cancel can stop auto-ready", () => {
  const accepted = studentState({
    surface: MATCH_SURFACE.IN_APP,
    decision: MATCH_DECISION.ACCEPTED,
    delivery: MATCH_DELIVERY.NOT_REQUIRED,
  });
  const decline = transitionParticipantState({
    state: accepted,
    action: MATCH_ACTION.DECLINE,
    actionId: "decline-late",
  });
  assert.equal(decline.changed, false);
  assert.equal(decline.reason, "already_accepted");

  const cancel = transitionParticipantState({
    state: accepted,
    action: MATCH_ACTION.CANCEL,
    actionId: "cancel-search",
  });
  assert.equal(cancel.changed, true);
  assert.equal(cancel.state.decision, MATCH_DECISION.DECLINED);

  const timeout = transitionParticipantState({
    state: studentState(),
    action: MATCH_ACTION.TIMEOUT,
    actionId: "timeout-callkit",
  });
  assert.equal(timeout.reason, "timed_out");
});

test("delivery failure records definitive versus ambiguous outcome", () => {
  const dispatch = claimCallKitDispatch({
    state: studentState(),
    dispatchId: "dispatch-a",
    callKitId: "call-a",
  });
  const definitive = finalizeCallKitDelivery({
    state: dispatch.state,
    dispatchId: "dispatch-a",
    sent: false,
    failureKind: "definitive",
  });
  assert.equal(definitive.state.delivery, MATCH_DELIVERY.FAILED);
  assert.equal(definitive.state.deliveryFailureKind, "definitive");
  assert.equal(transitionParticipantState({
    state: definitive.state,
    action: MATCH_ACTION.CLAIM_IN_APP,
    actionId: "recover",
  }).reason, "delivery_recovered");

  const ambiguous = finalizeCallKitDelivery({
    state: dispatch.state,
    dispatchId: "dispatch-a",
    sent: false,
    failureKind: "unknown",
  });
  assert.equal(ambiguous.state.deliveryFailureKind, "unknown");
  assert.equal(transitionParticipantState({
    state: ambiguous.state,
    action: MATCH_ACTION.ACCEPT,
    actionId: "accept-visible-callkit",
  }).reason, "accepted");
  assert.equal(transitionParticipantState({
    state: ambiguous.state,
    action: MATCH_ACTION.CLAIM_IN_APP,
    actionId: "unsafe-recover",
  }).reason, "surface_locked");

  assert.equal(finalizeCallKitDelivery({
    state: dispatch.state,
    dispatchId: "stale-dispatch",
    sent: true,
  }).reason, "dispatch_stale");
});
