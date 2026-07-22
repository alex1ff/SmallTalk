const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");
const {
  MATCH_ACTION,
  MATCH_DECISION,
  MATCH_DELIVERY,
  MATCH_SURFACE,
  buildInitialParticipantStates,
  transitionParticipantState,
} = require("./match_protocol_v2");
const {
  CALLKIT_DISPATCH_LEASE_MS,
  claimProtocolV2CallKitDispatch,
  isDefinitiveDeliveryFailure,
  routeProtocolV2Participant,
  waitForForegroundMatchClaim,
} = require("./match_delivery_v2");
const {
  routeProtocolV2InitialMatch,
} = require("./start_search").__private__;
const {
  buildLateTerminalSearchSuppression,
  isMatchTimeoutReached,
  respondToMatchCallable,
} = require("./respond_to_match").__private__;

function createFakeFirestore(seed = {}) {
  const store = new Map(Object.entries(seed));
  const makeSnapshot = (ref) => ({
    exists: store.has(ref.path),
    data: () => store.get(ref.path),
    ref,
  });
  const updatePath = (path, update) => {
    if (!store.has(path)) throw new Error(`missing document ${path}`);
    store.set(path, {...store.get(path), ...update});
  };
  const makeRef = (path) => ({
    path,
    id: path.split("/").pop(),
    get: async () => makeSnapshot(makeRef(path)),
  });
  const makeCollection = (path) => ({
    doc: (id) => makeRef(`${path}/${id}`),
  });
  const db = {
    collection: makeCollection,
    runTransaction: async (callback) => callback({
      get: async (ref) => makeSnapshot(ref),
      update: (ref, update) => updatePath(ref.path, update),
      set: (ref, data) => store.set(ref.path, data),
    }),
  };
  return {db, store};
}

function timestampFromMillis(millis) {
  return admin.firestore.Timestamp.fromMillis(millis);
}

function v2Session({scenario = "student_student"} = {}) {
  const teacherMatch = scenario === "student_teacher";
  const responderId = teacherMatch ? "teacher-a" : "student-b";
  const responderRole = teacherMatch ? "native_speaker" : "student";
  const participantIds = ["student-a", responderId];
  const participantRoles = {
    "student-a": "student",
    [responderId]: responderRole,
  };
  return {
    matchProtocolVersion: 2,
    status: "pending_confirmation",
    pairStatus: "pending_confirmation",
    pairAttemptId: "pair-a",
    requesterId: "student-a",
    responderId,
    currentResponderId: responderId,
    currentTutorId: responderId,
    requesterRole: "student",
    responderRole,
    currentResponderRole: responderRole,
    scenario,
    language: "fr",
    participantIds,
    participantRoles,
    participantInfos: {
      "student-a": {displayName: "Ana", photoUrl: "ana.jpg"},
      [responderId]: {displayName: "Bob", photoUrl: "bob.jpg"},
    },
    participantStates: buildInitialParticipantStates({
      participantIds,
      participantRoles,
      callKitIds: {
        "student-a": "call-student-a",
        [responderId]: `call-${responderId}`,
      },
    }),
    responseExpiresAt: timestampFromMillis(Date.now() + 30_000),
    confirmationExpiresAt: timestampFromMillis(Date.now() + 30_000),
    matchLock: {owner: "pair-a"},
    searchRequestIds: {requester: "student-a", responder: responderId},
  };
}

function seedForSession(session) {
  const seed = {"videoSessions/session-a": session};
  Object.entries(session.participantRoles).forEach(([participantId, role]) => {
    if (role === "student") {
      seed[`searchRequests/${participantId}`] = {
        userId: participantId,
        status: "matched",
        pairAttemptId: "pair-a",
        currentSessionId: "session-a",
        matchedSessionId: "session-a",
        appState: "foreground",
        appStateUpdatedAt: timestampFromMillis(Date.now()),
        heartbeatAt: timestampFromMillis(Date.now()),
      };
    }
  });
  return seed;
}

test("dispatch claim publishes preparing notification with other caller id", async () => {
  const session = v2Session();
  const {db, store} = createFakeFirestore(seedForSession(session));
  const before = Date.now();
  const result = await claimProtocolV2CallKitDispatch({
    db,
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    participantId: "student-a",
    dispatchId: "dispatch-a",
    nowMillis: before,
  });

  assert.equal(result.shouldNotify, true);
  assert.equal(result.pushPayload.studentId, "student-b");
  assert.equal(result.pushPayload.matchProtocolVersion, "2");
  assert.equal(result.pushPayload.pairAttemptId, "pair-a");
  const notification = store.get(`notifications/${result.notificationId}`);
  assert.equal(notification.status, "preparing");
  assert.equal(notification.callKitId, "call-student-a");
  assert.ok(notification.payloadExpiresAt);
  const updatedSession = store.get("videoSessions/session-a");
  assert.equal(
    updatedSession.participantStates["student-a"].delivery,
    MATCH_DELIVERY.DISPATCHING,
  );
  assert.ok(updatedSession.responseExpiresAt.toMillis() >= before + 45_000);
  assert.equal(
    notification.payloadExpiresAt,
    updatedSession.responseExpiresAt.toDate().toISOString(),
  );
});

test("successful route finalizes preparing notification as sent", async () => {
  const session = v2Session();
  const {db, store} = createFakeFirestore(seedForSession(session));
  const result = await routeProtocolV2Participant({
    db,
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    participantId: "student-b",
    preDispatchWait: async () => {},
    pushSender: async () => ({sent: true, channel: "apns_voip"}),
  });
  assert.equal(result.pushResult.sent, true);
  assert.equal(
    store.get("videoSessions/session-a")
      .participantStates["student-b"].delivery,
    MATCH_DELIVERY.SENT,
  );
  assert.equal(
    store.get(`notifications/${result.notificationId}`).status,
    "sent",
  );
});

test("in-flight dispatch keeps durable stage until its lease can be reclaimed", async () => {
  const now = Date.now();
  const session = v2Session();
  session.matchStage = "awaiting_initial_dispatch";
  const claimedPeer = transitionParticipantState({
    state: session.participantStates["student-b"],
    action: MATCH_ACTION.CLAIM_IN_APP,
    actionId: "claim-peer",
  });
  session.participantStates["student-b"] = claimedPeer.state;
  const {db, store} = createFakeFirestore(seedForSession(session));
  const firstClaim = await claimProtocolV2CallKitDispatch({
    db,
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    participantId: "student-a",
    dispatchId: "dispatch-crashed",
    nowMillis: now,
  });
  assert.equal(firstClaim.shouldNotify, true);

  const routeResult = await routeProtocolV2InitialMatch({
    db,
    lockResult: {
      sessionId: "session-a",
      pairAttemptId: "pair-a",
      responderId: "student-b",
    },
    requesterId: "student-a",
    responderRole: "student",
    studentPreDispatchWait: async () => {},
    studentPushSender: async () => {
      throw new Error("must not duplicate an active dispatch");
    },
  });
  assert.equal(routeResult.retryPending, true);
  assert.equal(
    store.get("videoSessions/session-a").matchStage,
    "awaiting_initial_dispatch",
  );

  const reclaimed = await claimProtocolV2CallKitDispatch({
    db,
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    participantId: "student-a",
    dispatchId: "dispatch-recovered",
    nowMillis: now + CALLKIT_DISPATCH_LEASE_MS + 1,
  });
  assert.equal(reclaimed.shouldNotify, true);
  assert.equal(reclaimed.dispatchId, "dispatch-recovered");
});

test("definitive failure allows bounded foreground recovery", async () => {
  const session = v2Session();
  const {db, store} = createFakeFirestore(seedForSession(session));
  const result = await routeProtocolV2Participant({
    db,
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    participantId: "student-b",
    preDispatchWait: async () => {},
    pushSender: async () => ({sent: false, reason: "missing_tokens"}),
    definitiveRecoveryWait: async () => {
      const latest = store.get("videoSessions/session-a");
      const recovered = transitionParticipantState({
        state: latest.participantStates["student-b"],
        action: MATCH_ACTION.CLAIM_IN_APP,
        actionId: "foreground-recovery",
      });
      store.set("videoSessions/session-a", {
        ...latest,
        participantStates: {
          ...latest.participantStates,
          "student-b": recovered.state,
        },
      });
    },
  });
  assert.equal(result.recoveredAfterDeliveryFailure, true);
  assert.equal(
    store.get("videoSessions/session-a")
      .participantStates["student-b"].surface,
    MATCH_SURFACE.IN_APP,
  );
});

test("missing FCM fallback after ambiguous APNs failure stays unknown", () => {
  assert.equal(isDefinitiveDeliveryFailure({
    sent: false,
    reason: "missing_fcm_token",
    apnsFailureKind: "unknown",
  }), false);
});

test("no call tokens is a definitive delivery failure", () => {
  assert.equal(isDefinitiveDeliveryFailure({
    sent: false,
    reason: "missing_tokens",
  }), true);
  assert.equal(isDefinitiveDeliveryFailure({
    sent: false,
    reason: "missing_fcm_token",
    apnsFailureKind: "definitive",
  }), true);
});

test("fresh foreground student gets the full claim window", async () => {
  const session = v2Session();
  const now = Date.now();
  const seed = seedForSession(session);
  seed["searchRequests/student-b"] = {
    ...seed["searchRequests/student-b"],
    appState: "foreground",
    appStateUpdatedAt: timestampFromMillis(now),
    heartbeatAt: timestampFromMillis(now),
  };
  const {db, store} = createFakeFirestore(seed);
  let currentMillis = now;
  let sleeps = 0;
  const result = await waitForForegroundMatchClaim({
    db,
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    participantId: "student-b",
    clock: () => currentMillis,
    maxWaitMillis: 4500,
    pollMillis: 250,
    sleep: async (millis) => {
      currentMillis += millis;
      sleeps += 1;
      if (sleeps === 8) {
        const latest = store.get("videoSessions/session-a");
        const claimed = transitionParticipantState({
          state: latest.participantStates["student-b"],
          action: MATCH_ACTION.CLAIM_IN_APP,
          actionId: "slow-foreground-claim",
        });
        store.set("videoSessions/session-a", {
          ...latest,
          participantStates: {
            ...latest.participantStates,
            "student-b": claimed.state,
          },
        });
      }
    },
  });

  assert.equal(result.reason, "participant_resolved");
  assert.equal(sleeps, 8);
  assert.equal(currentMillis - now, 2000);
});

test("background student dispatch wait returns immediately", async () => {
  const session = v2Session();
  const now = Date.now();
  const seed = seedForSession(session);
  seed["searchRequests/student-b"] = {
    ...seed["searchRequests/student-b"],
    appState: "background",
    appStateUpdatedAt: timestampFromMillis(now),
    heartbeatAt: timestampFromMillis(now),
  };
  const {db} = createFakeFirestore(seed);
  let sleeps = 0;
  const result = await waitForForegroundMatchClaim({
    db,
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    participantId: "student-b",
    clock: () => now,
    sleep: async () => {
      sleeps += 1;
    },
  });

  assert.equal(result.reason, "participant_not_foreground");
  assert.equal(sleeps, 0);
});

test("foreground wait exits as soon as app moves to background", async () => {
  const session = v2Session();
  const now = Date.now();
  const seed = seedForSession(session);
  seed["searchRequests/student-b"] = {
    ...seed["searchRequests/student-b"],
    appState: "foreground",
    appStateUpdatedAt: timestampFromMillis(now),
    heartbeatAt: timestampFromMillis(now),
  };
  const {db, store} = createFakeFirestore(seed);
  let currentMillis = now;
  let sleeps = 0;
  const result = await waitForForegroundMatchClaim({
    db,
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    participantId: "student-b",
    clock: () => currentMillis,
    sleep: async (millis) => {
      currentMillis += millis;
      sleeps += 1;
      store.set("searchRequests/student-b", {
        ...store.get("searchRequests/student-b"),
        appState: "background",
        appStateUpdatedAt: timestampFromMillis(currentMillis),
      });
    },
  });

  assert.equal(result.reason, "participant_left_foreground");
  assert.equal(sleeps, 1);
});

test("cancel during deferred push cannot resurrect notification", async () => {
  const session = v2Session();
  const {db, store} = createFakeFirestore(seedForSession(session));
  const cancellations = [];
  const result = await routeProtocolV2Participant({
    db,
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    participantId: "student-b",
    preDispatchWait: async () => {},
    pushSender: async (_participantId, callData) => {
      store.set("videoSessions/session-a", {
        ...store.get("videoSessions/session-a"),
        status: "cancelled",
      });
      const notificationPath = `notifications/${callData.notificationId}`;
      store.set(notificationPath, {
        ...store.get(notificationPath),
        status: "cancelled",
      });
      return {sent: true, channel: "apns_voip"};
    },
    cancellationSender: async (payload) => {
      cancellations.push(payload);
      return {sent: true};
    },
  });
  assert.equal(result.finalization.reason, "session_not_pending");
  assert.equal(
    store.get(`notifications/${result.notificationId}`).status,
    "cancelled",
  );
  assert.equal(cancellations.length, 1);
  assert.equal(cancellations[0].pairAttemptId, "pair-a");
  assert.equal(cancellations[0].callKitId, "call-student-b");
});

test("accept while push is in flight preserves accepted notification", async () => {
  const session = v2Session();
  const {db, store} = createFakeFirestore(seedForSession(session));
  const cancellations = [];
  const result = await routeProtocolV2Participant({
    db,
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    participantId: "student-b",
    preDispatchWait: async () => {},
    pushSender: async (_participantId, callData) => {
      const latest = store.get("videoSessions/session-a");
      const accepted = transitionParticipantState({
        state: latest.participantStates["student-b"],
        action: MATCH_ACTION.ACCEPT,
        actionId: "accept-during-push",
      });
      store.set("videoSessions/session-a", {
        ...latest,
        participantStates: {
          ...latest.participantStates,
          "student-b": accepted.state,
        },
      });
      const notificationPath = `notifications/${callData.notificationId}`;
      store.set(notificationPath, {
        ...store.get(notificationPath),
        status: "accepted",
      });
      return {sent: true, channel: "apns_voip"};
    },
    cancellationSender: async (payload) => {
      cancellations.push(payload);
      return {sent: true};
    },
  });

  assert.equal(result.finalization.reason, "sent");
  assert.equal(cancellations.length, 0);
  assert.equal(
    store.get("videoSessions/session-a")
      .participantStates["student-b"].delivery,
    MATCH_DELIVERY.SENT,
  );
  assert.equal(
    store.get(`notifications/${result.notificationId}`).status,
    "accepted",
  );
});

test("accept can finish before push finalizer observes connecting", async () => {
  const session = v2Session();
  const {db, store} = createFakeFirestore(seedForSession(session));
  const cancellations = [];
  const result = await routeProtocolV2Participant({
    db,
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    participantId: "student-b",
    preDispatchWait: async () => {},
    pushSender: async (_participantId, callData) => {
      const latest = store.get("videoSessions/session-a");
      const accepted = transitionParticipantState({
        state: latest.participantStates["student-b"],
        action: MATCH_ACTION.ACCEPT,
        actionId: "accept-and-connect-during-push",
      });
      store.set("videoSessions/session-a", {
        ...latest,
        status: "connecting",
        participantStates: {
          ...latest.participantStates,
          "student-b": accepted.state,
        },
      });
      const notificationPath = `notifications/${callData.notificationId}`;
      store.set(notificationPath, {
        ...store.get(notificationPath),
        status: "accepted",
      });
      return {sent: true, channel: "apns_voip"};
    },
    cancellationSender: async (payload) => {
      cancellations.push(payload);
      return {sent: true};
    },
  });

  assert.equal(result.finalization.reason, "accepted_before_finalization");
  assert.equal(cancellations.length, 0);
  assert.equal(
    store.get("videoSessions/session-a")
      .participantStates["student-b"].delivery,
    MATCH_DELIVERY.SENT,
  );
});

test("stale pair attempt cannot claim a CallKit surface", async () => {
  const session = v2Session();
  const {db} = createFakeFirestore(seedForSession(session));
  const result = await claimProtocolV2CallKitDispatch({
    db,
    sessionId: "session-a",
    pairAttemptId: "pair-stale",
    participantId: "student-a",
  });
  assert.equal(result.shouldNotify, false);
  assert.equal(result.reason, "pair_attempt_mismatch");
});

for (const [firstActor, lateActor] of [
  ["student-a", "student-b"],
  ["student-b", "student-a"],
]) {
  test(`${firstActor} terminal restore is suppressed by late ${lateActor} cancel`, () => {
    const update = buildLateTerminalSearchSuppression({
      searchData: {
        status: "active",
        currentSessionId: null,
        restoredFromSessionId: "session-a",
        restoredFromPairAttemptId: "pair-a",
      },
      sessionId: "session-a",
      pairAttemptId: "pair-a",
      participantId: lateActor,
      action: MATCH_ACTION.CANCEL,
      serverTimestamp: "server-now",
      fieldDelete: "delete",
    });
    assert.equal(update.status, "cancelled");
    assert.equal(update.stoppedBy, lateActor);
  });
}

test("late terminal action cannot stop a participant rematched elsewhere", () => {
  assert.equal(buildLateTerminalSearchSuppression({
    searchData: {
      status: "matched",
      currentSessionId: "session-new",
      restoredFromSessionId: null,
      restoredFromPairAttemptId: null,
    },
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    participantId: "student-b",
    action: MATCH_ACTION.DECLINE,
  }), null);
});

test("CallKit timeout accepts small client/server clock skew", () => {
  const nowMillis = Date.now();
  assert.equal(isMatchTimeoutReached({
    deadlineMillis: nowMillis + 1500,
    nowMillis,
  }), true);
  assert.equal(isMatchTimeoutReached({
    deadlineMillis: nowMillis + 2500,
    nowMillis,
  }), false);
});

test("teacher accept stages the student CallKit route without connecting early", async () => {
  const session = v2Session({scenario: "student_teacher"});
  session.participantStates["teacher-a"] = {
    ...session.participantStates["teacher-a"],
    delivery: MATCH_DELIVERY.SENT,
    dispatchId: "dispatch-teacher",
  };
  const {db, store} = createFakeFirestore(seedForSession(session));
  const pushedParticipants = [];
  const response = await respondToMatchCallable({
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    action: MATCH_ACTION.ACCEPT,
    actionId: "accept-teacher",
  }, {auth: {uid: "teacher-a"}}, {
    db,
    studentPreDispatchWait: async () => {},
    participantPushSender: async (participantId) => {
      pushedParticipants.push(participantId);
      return {sent: true, channel: "apns_voip"};
    },
  });
  assert.equal(response.status, "pending_confirmation");
  assert.deepEqual(pushedParticipants, ["student-a"]);
  const updated = store.get("videoSessions/session-a");
  assert.equal(updated.matchStage, "awaiting_acceptance");
  assert.equal(
    updated.participantStates["teacher-a"].decision,
    MATCH_DECISION.ACCEPTED,
  );
  assert.equal(
    updated.participantStates["student-a"].delivery,
    MATCH_DELIVERY.SENT,
  );
});

test("student cannot claim teacher match before teacher accepts", async () => {
  const session = v2Session({scenario: "student_teacher"});
  session.matchStage = "awaiting_teacher_response";
  const {db, store} = createFakeFirestore(seedForSession(session));
  const response = await respondToMatchCallable({
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    action: MATCH_ACTION.CLAIM_IN_APP,
    actionId: "early-student-claim",
  }, {auth: {uid: "student-a"}}, {db});

  assert.equal(response.reason, "student_stage_not_ready");
  assert.equal(response.ok, false);
  assert.equal(
    store.get("videoSessions/session-a")
      .participantStates["student-a"].decision,
    MATCH_DECISION.PENDING,
  );
});

test("student can claim teacher match after staged dispatch begins", async () => {
  const session = v2Session({scenario: "student_teacher"});
  session.matchStage = "awaiting_student_dispatch";
  const {db, store} = createFakeFirestore(seedForSession(session));
  const response = await respondToMatchCallable({
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    action: MATCH_ACTION.CLAIM_IN_APP,
    actionId: "staged-student-claim",
  }, {auth: {uid: "student-a"}}, {db});

  assert.equal(response.decision, MATCH_DECISION.ACCEPTED);
  assert.equal(
    store.get("videoSessions/session-a")
      .participantStates["student-a"].surface,
    MATCH_SURFACE.IN_APP,
  );
});

test("last in-app accept queues durable finalization without inline accept", async () => {
  const session = v2Session();
  session.matchStage = "awaiting_acceptance";
  session.participantStates["student-a"] = {
    role: "student",
    surface: MATCH_SURFACE.IN_APP,
    decision: MATCH_DECISION.ACCEPTED,
    delivery: MATCH_DELIVERY.NOT_REQUIRED,
  };
  const {db, store} = createFakeFirestore(seedForSession(session));

  const response = await respondToMatchCallable({
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    action: MATCH_ACTION.CLAIM_IN_APP,
    actionId: "accept-student-b",
  }, {auth: {uid: "student-b"}}, {db});

  assert.equal(response.reason, "finalization_in_progress");
  const updated = store.get("videoSessions/session-a");
  assert.equal(updated.matchStage, "finalization_requested");
  assert.equal(updated.matchFinalization.status, "requested");
  assert.equal(
    updated.participantStates["student-b"].decision,
    MATCH_DECISION.ACCEPTED,
  );

  const source = fs.readFileSync(
    path.join(__dirname, "respond_to_match.js"),
    "utf8",
  );
  assert.doesNotMatch(source, /acceptCallCallable/);
});

test("delayed in-app claim cannot override a background heartbeat", async () => {
  const session = v2Session();
  const seed = seedForSession(session);
  seed["searchRequests/student-a"] = {
    ...seed["searchRequests/student-a"],
    appState: "background",
    appStateUpdatedAt: timestampFromMillis(Date.now()),
  };
  const {db, store} = createFakeFirestore(seed);

  const response = await respondToMatchCallable({
    sessionId: "session-a",
    pairAttemptId: "pair-a",
    action: MATCH_ACTION.CLAIM_IN_APP,
    actionId: "delayed-foreground-claim",
  }, {auth: {uid: "student-a"}}, {db});

  assert.equal(response.ok, false);
  assert.equal(response.reason, "claim_requires_fresh_foreground");
  assert.equal(
    store.get("videoSessions/session-a")
      .participantStates["student-a"].decision,
    MATCH_DECISION.PENDING,
  );
});
