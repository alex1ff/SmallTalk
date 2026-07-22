const test = require("node:test");
const assert = require("node:assert/strict");
const {
  processMatchProtocolV2State,
  __private__,
} = require("./process_match_protocol_v2_state");
const {
  FIRESTORE_TRIGGER_REGION,
  processProtocolV2SessionState,
  recoverPendingProtocolV2States,
} = __private__;

test("protocol v2 Firestore trigger is colocated with eur3", () => {
  assert.equal(FIRESTORE_TRIGGER_REGION, "europe-west1");
  assert.equal(processMatchProtocolV2State.__endpoint.platform, "gcfv2");
  assert.deepEqual(
    processMatchProtocolV2State.__endpoint.region,
    [FIRESTORE_TRIGGER_REGION],
  );
  assert.equal(
    processMatchProtocolV2State.__endpoint.eventTrigger.retry,
    true,
  );
});

function stagedTeacherSession(overrides = {}) {
  return {
    matchProtocolVersion: 2,
    matchStage: "awaiting_student_dispatch",
    status: "pending_confirmation",
    pairAttemptId: "pair-a",
    requesterId: "student-a",
    responderId: "teacher-a",
    currentResponderId: "teacher-a",
    currentResponderRole: "native_speaker",
    participantIds: ["student-a", "teacher-a"],
    participantRoles: {
      "student-a": "student",
      "teacher-a": "native_speaker",
    },
    participantStates: {
      "student-a": {
        role: "student",
        surface: "pending",
        decision: "pending",
        delivery: "pending",
      },
      "teacher-a": {
        role: "native_speaker",
        surface: "callkit",
        decision: "accepted",
        delivery: "sent",
      },
    },
    ...overrides,
  };
}

test("post-commit teacher accept is recovered by staged student dispatch", async () => {
  const routed = [];
  const advances = [];
  const result = await processProtocolV2SessionState({
    db: {},
    sessionId: "session-a",
    sessionData: stagedTeacherSession(),
    participantRouter: async (options) => {
      routed.push(options.participantId);
      return {
        shouldNotify: true,
        participantId: options.participantId,
        pushResult: {sent: true, channel: "apns_voip"},
      };
    },
    stageAdvancer: async (options) => {
      advances.push(options);
      return {updated: true};
    },
  });

  assert.deepEqual(routed, ["student-a"]);
  assert.equal(advances.length, 1);
  assert.equal(advances[0].nextStage, "awaiting_acceptance");
  assert.equal(result.reason, "student_dispatch_reconciled");
});

test("post-commit second accept is recovered by idempotent finalization", async () => {
  const finalized = [];
  const sessionData = stagedTeacherSession({
    matchStage: "finalization_requested",
    participantStates: {
      "student-a": {
        role: "student",
        surface: "in_app",
        decision: "accepted",
        delivery: "not_required",
      },
      "teacher-a": {
        role: "native_speaker",
        surface: "callkit",
        decision: "accepted",
        delivery: "sent",
      },
    },
  });
  const result = await processProtocolV2SessionState({
    db: {
      collection: () => ({
        doc: () => ({
          get: async () => ({
            exists: true,
            data: () => sessionData,
          }),
        }),
      }),
    },
    sessionId: "session-a",
    sessionData,
    finalizer: async (data, context, options) => {
      finalized.push({data, context, options});
      return {status: "connected"};
    },
  });

  assert.equal(finalized.length, 1);
  assert.deepEqual(finalized[0].data, {
    sessionId: "session-a",
    pairAttemptId: "pair-a",
  });
  assert.equal(finalized[0].options.responderId, "teacher-a");
  assert.equal(result.reason, "finalized");
});

test("initial durable stage retries both-student routing", async () => {
  const calls = [];
  const sessionData = stagedTeacherSession({
    matchStage: "awaiting_initial_dispatch",
    responderId: "student-b",
    currentResponderId: "student-b",
    currentResponderRole: "student",
    participantIds: ["student-a", "student-b"],
    participantRoles: {
      "student-a": "student",
      "student-b": "student",
    },
  });
  const result = await processProtocolV2SessionState({
    db: {},
    sessionId: "session-a",
    sessionData,
    initialRouter: async (options) => {
      calls.push(options);
      return {results: [], failedResult: null};
    },
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].requesterId, "student-a");
  assert.equal(calls[0].lockResult.responderId, "student-b");
  assert.equal(result.reason, "initial_dispatch_reconciled");
});

test("staged route failure terminalizes exact attempt and resumes peer", async () => {
  const released = [];
  const cancelled = [];
  const resumed = [];
  const result = await processProtocolV2SessionState({
    db: {
      collection: () => ({doc: () => ({})}),
      runTransaction: async (callback) => callback({
        get: async () => ({exists: false}),
        update: () => {},
      }),
    },
    sessionId: "session-a",
    sessionData: stagedTeacherSession(),
    participantRouter: async () => ({
      shouldNotify: true,
      participantId: "student-a",
      pushResult: {sent: false, reason: "missing_tokens"},
      participantState: {
        delivery: "failed",
        deliveryFailureKind: "definitive",
        dispatchId: "dispatch-a",
      },
    }),
    releaseMatch: async (options) => {
      released.push(options);
      return {
        released: true,
        participantStates: {},
        restoreParticipantIds: ["student-peer"],
      };
    },
    cancelSurfaces: async (options) => {
      cancelled.push(options);
      return {cancelledSurfaces: 1};
    },
    resumeSearch: async (options) => {
      resumed.push(options.participantId);
      return {resumed: true};
    },
    terminalReconciler: async (options) => {
      await options.cancelSurfaces({
        db: options.db,
        sessionId: options.sessionId,
        sessionData: options.sessionData,
      });
      for (const participantId of
        options.sessionData.matchRecovery.restoreParticipantIds) {
        await options.resumeSearch({
          db: options.db,
          participantId,
          previousSessionId: options.sessionId,
          previousPairAttemptId: options.sessionData.pairAttemptId,
        });
      }
      return {reconciled: true};
    },
  });

  assert.equal(released[0].failedParticipantId, "student-a");
  assert.equal(released[0].expectedDispatchId, "dispatch-a");
  assert.equal(cancelled.length, 1);
  assert.deepEqual(resumed, ["student-peer"]);
  assert.equal(result.reason, "student_delivery_failed");
});

test("recovery stage queries cannot be starved by terminal sessions", async () => {
  const documents = Array.from({length: 101}, (_, index) => ({
    id: `terminal-${index}`,
    data: () => ({
      matchProtocolVersion: 2,
      matchStage: "awaiting_initial_dispatch",
      status: "cancelled",
      pairAttemptId: `terminal-pair-${index}`,
    }),
  }));
  documents.push({
    id: "live-session",
    data: () => ({
      matchProtocolVersion: 2,
      matchStage: "awaiting_initial_dispatch",
      status: "pending_confirmation",
      pairAttemptId: "live-pair",
      requesterId: "student-a",
      currentResponderId: "student-b",
      currentResponderRole: "student",
    }),
  });
  const db = {
    collection: () => {
      const buildQuery = (filters = [], queryLimit = Infinity) => ({
        where(field, operator, value) {
          assert.equal(operator, "==");
          return buildQuery([...filters, {field, value}], queryLimit);
        },
        limit(value) {
          return buildQuery(filters, value);
        },
        async get() {
          return {
            docs: documents.filter((doc) => filters.every((filter) => {
              const data = doc.data();
              const value = filter.field.split(".").reduce(
                (current, key) => current?.[key],
                data,
              );
              return value === filter.value;
            })).slice(0, queryLimit),
          };
        },
      });
      return buildQuery();
    },
  };
  const routed = [];

  const results = await recoverPendingProtocolV2States({
    db,
    initialRouter: async ({lockResult}) => {
      routed.push(lockResult.sessionId);
      return {results: [], failedResult: null};
    },
  });

  assert.deepEqual(routed, ["live-session"]);
  assert.equal(results.length, 1);
  assert.equal(results[0].reason, "initial_dispatch_reconciled");
});
