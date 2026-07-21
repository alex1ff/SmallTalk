const MATCH_PROTOCOL_VERSION = 2;

const MATCH_ACTION = Object.freeze({
  CLAIM_IN_APP: "claim_in_app",
  ACCEPT: "accept",
  DECLINE: "decline",
  CANCEL: "cancel",
  TIMEOUT: "timeout",
});

const MATCH_SURFACE = Object.freeze({
  PENDING: "pending",
  IN_APP: "in_app",
  CALLKIT: "callkit",
});

const MATCH_DECISION = Object.freeze({
  PENDING: "pending",
  ACCEPTED: "accepted",
  DECLINED: "declined",
});

const MATCH_DELIVERY = Object.freeze({
  NOT_REQUIRED: "not_required",
  PENDING: "pending",
  DISPATCHING: "dispatching",
  SENT: "sent",
  FAILED: "failed",
});

const MATCH_STAGE = Object.freeze({
  AWAITING_INITIAL_DISPATCH: "awaiting_initial_dispatch",
  AWAITING_TEACHER_RESPONSE: "awaiting_teacher_response",
  AWAITING_STUDENT_DISPATCH: "awaiting_student_dispatch",
  AWAITING_ACCEPTANCE: "awaiting_acceptance",
  FINALIZATION_REQUESTED: "finalization_requested",
  CONNECTING: "connecting",
});

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeProtocolVersion(value) {
  const version = Number(value);
  return Number.isInteger(version) && version >= MATCH_PROTOCOL_VERSION ?
    MATCH_PROTOCOL_VERSION :
    1;
}

function supportsMatchProtocolV2(value) {
  return normalizeProtocolVersion(value) === MATCH_PROTOCOL_VERSION;
}

function normalizeParticipantState(state = {}, role = "student") {
  return {
    role: normalizeString(state.role) || normalizeString(role) || "student",
    surface: Object.values(MATCH_SURFACE).includes(state.surface) ?
      state.surface :
      MATCH_SURFACE.PENDING,
    decision: Object.values(MATCH_DECISION).includes(state.decision) ?
      state.decision :
      MATCH_DECISION.PENDING,
    delivery: Object.values(MATCH_DELIVERY).includes(state.delivery) ?
      state.delivery :
      MATCH_DELIVERY.PENDING,
    callKitId: normalizeString(state.callKitId) || null,
    actionId: normalizeString(state.actionId) || null,
    dispatchId: normalizeString(state.dispatchId) || null,
    dispatchExpiresAt: state.dispatchExpiresAt || null,
    deliveryFailureKind:
      normalizeString(state.deliveryFailureKind) || null,
    surfaceRevision: Math.max(0, Number(state.surfaceRevision) || 0),
    updatedAt: state.updatedAt || null,
  };
}

function buildInitialParticipantStates({
  participantIds = [],
  participantRoles = {},
  callKitIds = {},
} = {}) {
  const states = {};
  participantIds.forEach((participantId) => {
    const normalizedParticipantId = normalizeString(participantId);
    if (!normalizedParticipantId) return;
    const role = normalizeString(participantRoles[normalizedParticipantId]) ||
      "student";
    const teacherUsesCallKit = role === "native_speaker" || role === "teacher";
    states[normalizedParticipantId] = {
      role,
      surface: teacherUsesCallKit ?
        MATCH_SURFACE.CALLKIT :
        MATCH_SURFACE.PENDING,
      decision: MATCH_DECISION.PENDING,
      delivery: teacherUsesCallKit ?
        MATCH_DELIVERY.PENDING :
        MATCH_DELIVERY.PENDING,
      callKitId:
        normalizeString(callKitIds[normalizedParticipantId]) || null,
      actionId: null,
      dispatchId: null,
      dispatchExpiresAt: null,
      deliveryFailureKind: null,
      surfaceRevision: 0,
      updatedAt: null,
    };
  });
  return states;
}

function transitionParticipantState({
  state = {},
  role = "student",
  action = "",
  actionId = "",
  updatedAt = null,
} = {}) {
  const current = normalizeParticipantState(state, role);
  const normalizedAction = normalizeString(action);
  const normalizedActionId = normalizeString(actionId);
  if (
    normalizedActionId &&
    current.actionId === normalizedActionId
  ) {
    return {changed: false, state: current, reason: "duplicate_action"};
  }

  if (normalizedAction === MATCH_ACTION.CLAIM_IN_APP) {
    if (["native_speaker", "teacher"].includes(current.role)) {
      return {changed: false, state: current, reason: "teacher_requires_callkit"};
    }
    if (current.decision === MATCH_DECISION.DECLINED) {
      return {changed: false, state: current, reason: "already_declined"};
    }
    if (
      current.surface === MATCH_SURFACE.IN_APP &&
      current.decision === MATCH_DECISION.ACCEPTED
    ) {
      return {changed: false, state: current, reason: "already_claimed"};
    }
    const failedCallKitCanRecover =
      current.surface === MATCH_SURFACE.CALLKIT &&
      current.delivery === MATCH_DELIVERY.FAILED &&
      current.deliveryFailureKind === "definitive";
    if (current.surface === MATCH_SURFACE.CALLKIT && !failedCallKitCanRecover) {
      return {changed: false, state: current, reason: "surface_locked"};
    }
    return {
      changed: true,
      reason: failedCallKitCanRecover ? "delivery_recovered" : "claimed",
      state: {
        ...current,
        surface: MATCH_SURFACE.IN_APP,
        decision: MATCH_DECISION.ACCEPTED,
        delivery: MATCH_DELIVERY.NOT_REQUIRED,
        actionId: normalizedActionId || current.actionId,
        dispatchId: null,
        updatedAt,
      },
    };
  }

  if (normalizedAction === MATCH_ACTION.ACCEPT) {
    if (current.decision === MATCH_DECISION.ACCEPTED) {
      return {changed: false, state: current, reason: "already_accepted"};
    }
    if (current.surface !== MATCH_SURFACE.CALLKIT) {
      return {changed: false, state: current, reason: "surface_not_callkit"};
    }
    const ambiguousFailureCanAccept =
      current.delivery === MATCH_DELIVERY.FAILED &&
      current.deliveryFailureKind === "unknown";
    if (!ambiguousFailureCanAccept && ![
      MATCH_DELIVERY.DISPATCHING,
      MATCH_DELIVERY.SENT,
    ].includes(current.delivery)) {
      return {changed: false, state: current, reason: "callkit_not_delivered"};
    }
    return {
      changed: true,
      reason: "accepted",
      state: {
        ...current,
        decision: MATCH_DECISION.ACCEPTED,
        actionId: normalizedActionId || current.actionId,
        updatedAt,
      },
    };
  }

  if (normalizedAction === MATCH_ACTION.DECLINE) {
    if (current.decision === MATCH_DECISION.ACCEPTED) {
      return {changed: false, state: current, reason: "already_accepted"};
    }
    if (current.decision === MATCH_DECISION.DECLINED) {
      return {changed: false, state: current, reason: "already_declined"};
    }
    return {
      changed: true,
      reason: "declined",
      state: {
        ...current,
        decision: MATCH_DECISION.DECLINED,
        actionId: normalizedActionId || current.actionId,
        updatedAt,
      },
    };
  }

  if ([MATCH_ACTION.CANCEL, MATCH_ACTION.TIMEOUT].includes(normalizedAction)) {
    if (
      normalizedAction === MATCH_ACTION.TIMEOUT &&
      current.decision === MATCH_DECISION.ACCEPTED
    ) {
      return {changed: false, state: current, reason: "already_accepted"};
    }
    if (current.decision === MATCH_DECISION.DECLINED) {
      return {changed: false, state: current, reason: "already_declined"};
    }
    return {
      changed: true,
      reason: normalizedAction === MATCH_ACTION.TIMEOUT ?
        "timed_out" :
        "cancelled",
      state: {
        ...current,
        decision: MATCH_DECISION.DECLINED,
        actionId: normalizedActionId || current.actionId,
        updatedAt,
      },
    };
  }

  return {changed: false, state: current, reason: "unsupported_action"};
}

function claimCallKitDispatch({
  state = {},
  role = "student",
  dispatchId = "",
  callKitId = "",
  dispatchExpiresAt = null,
  updatedAt = null,
} = {}) {
  const current = normalizeParticipantState(state, role);
  const normalizedDispatchId = normalizeString(dispatchId);
  const normalizedCallKitId = normalizeString(callKitId);
  if (!normalizedDispatchId || !normalizedCallKitId) {
    return {changed: false, state: current, reason: "missing_dispatch_ids"};
  }
  if (current.decision !== MATCH_DECISION.PENDING) {
    return {changed: false, state: current, reason: "decision_locked"};
  }
  if (current.surface === MATCH_SURFACE.IN_APP) {
    return {changed: false, state: current, reason: "surface_in_app"};
  }
  if (
    current.surface === MATCH_SURFACE.CALLKIT &&
    [MATCH_DELIVERY.DISPATCHING, MATCH_DELIVERY.SENT].includes(
      current.delivery,
    )
  ) {
    return {changed: false, state: current, reason: "surface_locked"};
  }
  return {
    changed: true,
    reason: "dispatch_claimed",
    state: {
      ...current,
      surface: MATCH_SURFACE.CALLKIT,
      delivery: MATCH_DELIVERY.DISPATCHING,
      callKitId: normalizedCallKitId,
      dispatchId: normalizedDispatchId,
      dispatchExpiresAt,
      deliveryFailureKind: null,
      updatedAt,
    },
  };
}

function finalizeCallKitDelivery({
  state = {},
  dispatchId = "",
  sent = false,
  failureKind = "unknown",
  updatedAt = null,
} = {}) {
  const current = normalizeParticipantState(state);
  const normalizedDispatchId = normalizeString(dispatchId);
  if (
    !normalizedDispatchId ||
    current.dispatchId !== normalizedDispatchId ||
    current.delivery !== MATCH_DELIVERY.DISPATCHING
  ) {
    return {changed: false, state: current, reason: "dispatch_stale"};
  }
  return {
    changed: true,
    reason: sent ? "sent" : "failed",
    state: {
      ...current,
      delivery: sent ? MATCH_DELIVERY.SENT : MATCH_DELIVERY.FAILED,
      deliveryFailureKind: sent ? null :
        (normalizeString(failureKind) === "definitive" ?
          "definitive" :
          "unknown"),
      dispatchExpiresAt: null,
      updatedAt,
    },
  };
}

function allParticipantsAccepted(participantStates = {}, participantIds = []) {
  const ids = Array.from(new Set(
    participantIds.map(normalizeString).filter(Boolean),
  ));
  return ids.length >= 2 && ids.every((participantId) =>
    normalizeParticipantState(participantStates[participantId]).decision ===
      MATCH_DECISION.ACCEPTED,
  );
}

function allParticipantsReadyForFinalization(
  participantStates = {},
  participantIds = [],
) {
  return allParticipantsAccepted(participantStates, participantIds) &&
    participantIds.every((participantId) => {
      const state = normalizeParticipantState(participantStates[participantId]);
      return state.surface !== MATCH_SURFACE.CALLKIT ||
        state.delivery === MATCH_DELIVERY.SENT ||
        (
          state.delivery === MATCH_DELIVERY.FAILED &&
          state.deliveryFailureKind === "unknown"
        );
    });
}

module.exports = {
  MATCH_ACTION,
  MATCH_DECISION,
  MATCH_DELIVERY,
  MATCH_PROTOCOL_VERSION,
  MATCH_STAGE,
  MATCH_SURFACE,
  allParticipantsAccepted,
  allParticipantsReadyForFinalization,
  buildInitialParticipantStates,
  claimCallKitDispatch,
  finalizeCallKitDelivery,
  normalizeParticipantState,
  normalizeProtocolVersion,
  supportsMatchProtocolV2,
  transitionParticipantState,
};
