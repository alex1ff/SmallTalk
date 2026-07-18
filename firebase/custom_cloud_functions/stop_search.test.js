const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    buildManualStopPairLockReleaseOptions,
    buildCallCancellationPayload,
    buildResponse,
    buildStopSearchDecision,
    buildStopSessionDecision,
    canStopSessionAfterSearchDecision,
    getAssignedResponderId,
    normalizeRequestId,
    normalizeSessionId,
    requestBelongsToUser,
    requestMatchesSearchRequestId,
    requestMatchesSession,
    resolveStopSessionId,
    sendCallCancellationToResponder,
  },
} = require("./stop_search");

const serverTimestamp = Symbol("serverTimestamp");
const fieldDelete = Symbol("fieldDelete");

function stopSearchDecision(overrides = {}) {
  return buildStopSearchDecision({
    requestExists: true,
    requestData: {
      status: "searching",
      userId: "student-a",
      activeSessionId: "session-a",
      requestId: "request-a",
    },
    userId: "student-a",
    sessionId: "session-a",
    requestId: "request-a",
    serverTimestamp,
    fieldDelete,
    ...overrides,
  });
}

function stopSessionDecision(overrides = {}) {
  return buildStopSessionDecision({
    sessionExists: true,
    sessionData: {
      status: "searching",
      studentId: "student-a",
      currentTutorId: "teacher-a",
      dailyRoomName: "room-a",
    },
    userId: "student-a",
    sessionId: "session-a",
    requesterCurrentSessionId: "session-a",
    responderCurrentSessionId: "session-a",
    serverTimestamp,
    fieldDelete,
    ...overrides,
  });
}

test("normalize ids trim valid ids and reject invalid paths", () => {
  assert.equal(normalizeSessionId("  session-a  "), "session-a");
  assert.equal(normalizeSessionId("videoSessions/session-a"), "");
  assert.equal(normalizeSessionId("__bad__"), "");
  assert.equal(normalizeSessionId("."), "");
  assert.equal(normalizeSessionId(".."), "");
  assert.equal(normalizeSessionId(123), "");
  assert.equal(normalizeSessionId(null), "");
  assert.equal(normalizeRequestId(" request-a "), "request-a");
  assert.equal(normalizeRequestId("requests/request-a"), "");
});

test("call cancellation payload targets the exact CallKit session", () => {
  const payload = buildCallCancellationPayload({
    sessionId: " session-a ",
    responderUserId: " teacher-a ",
  });

  assert.equal(payload.type, "call_cancelled");
  assert.equal(payload.sessionId, "session-a");
  assert.equal(payload.recipientId, "teacher-a");
  assert.match(
    payload.callKitId,
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
  );
});

test("stop cancellation sends a VoIP end event to the responder", async () => {
  let sentRequest = null;
  const result = await sendCallCancellationToResponder({
    db: {
      collection: () => ({
        doc: () => ({
          get: async () => ({
            exists: true,
            data: () => ({role: "native_speaker"}),
          }),
        }),
      }),
    },
    sessionId: "session-a",
    responderUserId: "teacher-a",
    tokenReader: async () => ({
      voipPushToken: "push-token",
      voipToken: null,
    }),
    apnsSender: async (request) => {
      sentRequest = request;
    },
    messaging: {send: async () => assert.fail("FCM fallback not expected")},
  });

  assert.deepEqual(result, {sent: true, channel: "apns_voip"});
  assert.equal(sentRequest.deviceToken, "push-token");
  assert.equal(sentRequest.payload.type, "call_cancelled");
  assert.equal(sentRequest.payload.sessionId, "session-a");
  assert.equal(sentRequest.payload.recipientId, "teacher-a");
});

test("request owner can be stored as ids, refs, or omitted for uid doc", () => {
  assert.equal(requestBelongsToUser({userId: "student-a"}, "student-a"), true);
  assert.equal(requestBelongsToUser({studentId: "student-a"}, "student-a"), true);
  assert.equal(
      requestBelongsToUser({userRef: {id: "student-a"}}, "student-a"),
      true,
  );
  assert.equal(requestBelongsToUser({}, "student-a"), true);
  assert.equal(requestBelongsToUser({userId: "student-b"}, "student-a"), false);
  assert.equal(
      requestBelongsToUser({
        userId: "student-a",
        userRef: {id: "student-b"},
      }, "student-a"),
      false,
  );
});

test("requestMatchesSession requires an explicit match when session is provided", () => {
  assert.equal(requestMatchesSession({}, "session-a"), false);
  assert.equal(
      requestMatchesSession({activeSessionId: "session-a"}, "session-a"),
      true,
  );
  assert.equal(
      requestMatchesSession({currentSessionId: "session-a"}, "session-a"),
      true,
  );
  assert.equal(
      requestMatchesSession({activeSessionId: "session-b"}, "session-a"),
      false,
  );
  assert.equal(requestMatchesSession({activeSessionId: "session-b"}, ""), true);
});

test("requestMatchesSearchRequestId protects sessionless requests", () => {
  assert.equal(requestMatchesSearchRequestId({}, "request-a"), false);
  assert.equal(
      requestMatchesSearchRequestId({requestId: "request-a"}, "request-a"),
      true,
  );
  assert.equal(
      requestMatchesSearchRequestId(
          {clientSearchId: "request-a"},
          "request-a",
      ),
      true,
  );
  assert.equal(
      requestMatchesSearchRequestId(
          {searchRequestId: "student-a", requestId: "request-a"},
          "student-a",
      ),
      false,
  );
  assert.equal(
      requestMatchesSearchRequestId({requestId: "request-b"}, "request-a"),
      false,
  );
  assert.equal(requestMatchesSearchRequestId({requestId: "request-b"}, ""), true);
});

test("resolveStopSessionId prefers explicit, then request, then user session", () => {
  assert.equal(
      resolveStopSessionId({
        explicitSessionId: "session-explicit",
        requestData: {activeSessionId: "session-request"},
        requesterCurrentSessionId: "session-user",
      }),
      "session-explicit",
  );
  assert.equal(
      resolveStopSessionId({
        requestData: {activeSessionId: "session-request"},
        requesterCurrentSessionId: "session-user",
      }),
      "session-request",
  );
  assert.equal(
      resolveStopSessionId({
        requestData: {},
        requesterCurrentSessionId: "session-user",
      }),
      "session-user",
  );
});

test("missing active request is an idempotent noop", () => {
  const decision = stopSearchDecision({
    requestExists: false,
    requestData: {},
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update, null);
  assert.deepEqual(decision.response, {
    status: "noop",
    stopped: false,
    reason: "not_found",
  });
});

test("active request is marked stopped and transient match fields are cleared", () => {
  const decision = stopSearchDecision();

  assert.equal(decision.ok, true);
  assert.deepEqual(decision.response, {
    status: "stopped",
    stopped: true,
    reason: "manual",
    pairAttemptId: null,
    expiresAt: null,
    errorCode: null,
  });
  assert.equal(decision.update.status, "stopped");
  assert.equal(decision.update.stopReason, "manual");
  assert.equal(decision.update.stoppedBy, "student-a");
  assert.equal(decision.update.stoppedAt, serverTimestamp);
  assert.equal(decision.update.updatedAt, serverTimestamp);
  assert.equal(decision.update.activeSessionId, fieldDelete);
  assert.equal(decision.update.currentSessionId, null);
  assert.equal(decision.update.matchedSessionId, fieldDelete);
  assert.equal(decision.update.matchedResponderId, fieldDelete);
  assert.equal(decision.update.matchedUserId, null);
  assert.equal(decision.update.matchedRole, null);
  assert.equal(decision.update.pairAttemptId, null);
  assert.deepEqual(decision.update.excludedCandidateIds, []);
  assert.deepEqual(decision.update.attemptExcludedCandidateIds, []);
  assert.equal(decision.update.candidateLockOwner, fieldDelete);
  assert.equal(decision.update.candidateLockExpiresAt, fieldDelete);
  assert.equal(decision.update.lockOwner, null);
  assert.equal(decision.update.lockExpiresAt, null);
  assert.equal(decision.update.lastError, null);
  assert.equal(decision.update.errorCode, fieldDelete);
  assert.equal(decision.update.errorMessage, fieldDelete);
});

test("sessionless request stop requires lifecycle requestId", () => {
  const decision = stopSearchDecision({
    requestData: {
      status: "active",
      userId: "student-a",
      requestId: "request-a",
      currentSessionId: null,
    },
    sessionId: "",
    requestId: "",
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update, null);
  assert.deepEqual(decision.response, {
    status: "noop",
    stopped: false,
    reason: "request_id_required",
  });
});

test("matched request stop clears transient match state", () => {
  const decision = stopSearchDecision({
    requestData: {
      status: "matched",
      userId: "student-a",
      activeSessionId: "session-a",
      requestId: "request-a",
    },
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update.status, "stopped");
  assert.equal(decision.update.matchedSessionId, fieldDelete);
  assert.equal(decision.update.matchedResponderId, fieldDelete);
  assert.equal(decision.update.matchedUserId, null);
  assert.equal(decision.update.matchedRole, null);
  assert.equal(decision.update.pairAttemptId, null);
  assert.equal(decision.update.lockOwner, null);
  assert.deepEqual(decision.response, {
    status: "stopped",
    stopped: true,
    reason: "manual",
    pairAttemptId: null,
    expiresAt: null,
    errorCode: null,
  });
});

test("terminal request stop is idempotent and does not overwrite state", () => {
  const decision = stopSearchDecision({
    requestData: {
      status: "completed",
      userId: "student-a",
      activeSessionId: "session-a",
      requestId: "request-a",
    },
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update, null);
  assert.deepEqual(decision.response, {
    status: "noop",
    stopped: false,
    reason: "already_inactive",
  });
});

test("different session id does not stop a newer request", () => {
  const decision = stopSearchDecision({
    requestData: {
      status: "searching",
      userId: "student-a",
      activeSessionId: "session-b",
      requestId: "request-a",
    },
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update, null);
  assert.deepEqual(decision.response, {
    status: "noop",
    stopped: false,
    reason: "session_mismatch",
  });
});

test("different request id does not stop a newer sessionless request", () => {
  const decision = stopSearchDecision({
    requestData: {
      status: "searching",
      userId: "student-a",
      requestId: "request-b",
    },
    sessionId: "",
    requestId: "request-a",
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update, null);
  assert.deepEqual(decision.response, {
    status: "noop",
    stopped: false,
    reason: "request_mismatch",
  });
});

test("request owned by another user is rejected", () => {
  const decision = stopSearchDecision({
    requestData: {
      status: "searching",
      userId: "student-b",
      activeSessionId: "session-a",
      requestId: "request-a",
    },
  });

  assert.equal(decision.ok, false);
  assert.equal(decision.code, "permission-denied");
});

test("searching video session is cancelled and user pointers are cleared", () => {
  const decision = stopSessionDecision();

  assert.equal(decision.ok, true);
  assert.deepEqual(decision.response, {
    status: "cancelled",
    stopped: true,
    reason: "manual",
    dailyRoomName: "room-a",
    responderUserId: "teacher-a",
  });
  assert.equal(decision.sessionUpdate.status, "cancelled");
  assert.equal(decision.sessionUpdate.cancelReason, "manual_stop_search");
  assert.equal(decision.sessionUpdate.currentTutorId, fieldDelete);
  assert.equal(decision.sessionUpdate.acceptingTutorId, fieldDelete);
  assert.equal(decision.sessionUpdate.acceptingAt, fieldDelete);
  assert.equal(decision.sessionUpdate.acceptAttemptId, fieldDelete);
  assert.equal(decision.requesterUpdate.currentSessionId, fieldDelete);
  assert.equal(decision.responderUpdate.currentSessionId, fieldDelete);
});

test("active video session is not cancelled by stopSearch", () => {
  const decision = stopSessionDecision({
    sessionData: {
      status: "active",
      studentId: "student-a",
      tutorId: "teacher-a",
    },
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.sessionUpdate, null);
  assert.deepEqual(decision.response, {
    status: "noop",
    stopped: false,
    reason: "session_not_searching",
  });
});

test("connecting video session is not cancelled by stopSearch", () => {
  const decision = stopSessionDecision({
    sessionData: {
      status: "connecting",
      studentId: "student-a",
      tutorId: "teacher-a",
      dailyRoomName: "room-a",
    },
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.sessionUpdate, null);
  assert.deepEqual(decision.response, {
    status: "noop",
    stopped: false,
    reason: "session_not_searching",
  });
});

test("assigned responder lookup supports legacy and neutral fields", () => {
  assert.equal(getAssignedResponderId({currentTutorId: "teacher-a"}), "teacher-a");
  assert.equal(getAssignedResponderId({tutorId: "teacher-b"}), "teacher-b");
  assert.equal(
      getAssignedResponderId({currentResponderId: "student-b"}),
      "student-b",
  );
  assert.equal(getAssignedResponderId({responderId: "student-c"}), "student-c");
  assert.equal(
      getAssignedResponderId({
        matchContext: {acceptedResponderId: "student-d"},
      }),
      "student-d",
  );
});

test("video session owned by another requester is rejected", () => {
  const decision = stopSessionDecision({
    sessionData: {
      status: "searching",
      studentId: "student-b",
      currentTutorId: "teacher-a",
    },
  });

  assert.equal(decision.ok, false);
  assert.equal(decision.code, "permission-denied");
});

test("combined response succeeds when either request or session is stopped", () => {
  const response = buildResponse({
    userId: "student-a",
    sessionId: "session-a",
    requestId: "request-a",
    searchDecision: {
      response: {
        status: "noop",
        stopped: false,
        reason: "not_found",
      },
    },
    sessionDecision: stopSessionDecision(),
  });

  assert.equal(response.status, "cancelled");
  assert.equal(response.stopped, true);
  assert.equal(response.reason, "manual");
  assert.equal(response.cancelledSessionId, "session-a");
  assert.equal(response.pairAttemptId, null);
  assert.equal(response.expiresAt, null);
  assert.equal(response.errorCode, null);
});

test("derived session is not stopped when request guard mismatches", () => {
  const requestMismatchDecision = stopSearchDecision({
    requestData: {
      status: "searching",
      userId: "student-a",
      activeSessionId: "session-b",
      requestId: "request-b",
    },
  });

  assert.equal(requestMismatchDecision.response.reason, "session_mismatch");
  assert.equal(
      canStopSessionAfterSearchDecision({
        explicitSessionId: "",
        searchDecision: requestMismatchDecision,
      }),
      false,
  );
  assert.equal(
      canStopSessionAfterSearchDecision({
        explicitSessionId: "session-a",
        searchDecision: requestMismatchDecision,
      }),
      true,
  );
});

test("stopSearch is exported and included in readiness deploy target", () => {
  const indexSource = fs.readFileSync(path.join(__dirname, "index.js"), "utf8");
  const packageJson = JSON.parse(fs.readFileSync(
      path.join(__dirname, "package.json"),
      "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];

  assert.match(indexSource, /exports\.stopSearch\b/);
  assert.match(deployScript, /functions:custom_cloud_functions:stopSearch\b/);
});

test("manual stop closes pair locks without restoring participants", () => {
  const db = Symbol("db");
  const transaction = Symbol("transaction");
  const sessionData = {status: "pending_confirmation"};

  const options = buildManualStopPairLockReleaseOptions({
    db,
    transaction,
    sessionId: "session-manual-stop",
    sessionData,
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(options.db, db);
  assert.equal(options.transaction, transaction);
  assert.equal(options.sessionId, "session-manual-stop");
  assert.equal(options.sessionData, sessionData);
  assert.equal(options.serverTimestamp, serverTimestamp);
  assert.equal(options.fieldDelete, fieldDelete);
  assert.equal(options.searchRequestStatus, "stopped");
  assert.equal(options.stopReason, "manual_stop_search");
  assert.equal(options.releaseCallState, true);
  assert.equal(options.restoreSearchParticipantIds, undefined);
  assert.equal(
    options.restoreSearchExcludedCandidateIdsByParticipantId,
    undefined,
  );
});

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

if (!hasFirestoreEmulator) {
  test(
    "stopSearch callable Firestore coverage requires emulator",
    {skip: "run with firebase emulators:exec --only firestore"},
    () => {},
  );
} else {
  const admin = require("firebase-admin");
  const functionsTest = require("firebase-functions-test");
  const {stopSearch} = require("./stop_search");

  const projectId =
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    "demo-smalltalk";
  process.env.GCLOUD_PROJECT = projectId;
  process.env.GOOGLE_CLOUD_PROJECT = projectId;

  if (!admin.apps.length) {
    admin.initializeApp({projectId});
  }

  const testEnv = functionsTest({projectId});
  const db = admin.firestore();
  const wrappedStopSearch = testEnv.wrap(stopSearch);
  let uidCounter = 0;

  test.after(() => {
    testEnv.cleanup();
  });

  function uniqueId(prefix) {
    uidCounter += 1;
    return [
      prefix,
      process.pid,
      Date.now(),
      uidCounter,
    ].join("-");
  }

  function authContext(uid) {
    return {
      auth: {
        uid,
        token: {
          firebase: {
            sign_in_provider: "custom",
          },
        },
      },
    };
  }

  function userRef(uid) {
    return db.collection("users").doc(uid);
  }

  function searchRequestRef(uid) {
    return db.collection("searchRequests").doc(uid);
  }

  function sessionRef(sessionId) {
    return db.collection("videoSessions").doc(sessionId);
  }

  function futureTimestamp(minutes = 10) {
    return admin.firestore.Timestamp.fromMillis(
      Date.now() + minutes * 60 * 1000,
    );
  }

  async function deleteDoc(ref) {
    const snapshot = await ref.get();
    if (snapshot.exists) {
      await ref.delete();
    }
  }

  async function seedUser(uid, overrides = {}) {
    await userRef(uid).set({
      role: "student",
      isInCall: false,
      currentSessionId: "",
      ...overrides,
    });
  }

  async function seedActiveRequest(uid, overrides = {}) {
    await searchRequestRef(uid).set({
      requestId: "request-active",
      userId: uid,
      userRef: userRef(uid),
      role: "student",
      language: "en",
      filters: {preferredLevel: "B1", levelRank: 3},
      status: "active",
      appState: "foreground",
      appStateUpdatedAt: admin.firestore.Timestamp.now(),
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      heartbeatAt: admin.firestore.Timestamp.now(),
      expiresAt: futureTimestamp(10),
      backgroundExpiresAt: null,
      currentSessionId: null,
      matchedUserId: null,
      matchedRole: null,
      pairAttemptId: null,
      excludedCandidateIds: ["old-candidate"],
      attemptExcludedCandidateIds: ["attempt-candidate"],
      lockOwner: "matcher-a",
      lockExpiresAt: futureTimestamp(1),
      version: 2,
      stopReason: null,
      stoppedAt: null,
      lastError: {code: "old"},
      ...overrides,
    });
  }

  test("stopSearch callable stops request and preserves contract fields", async () => {
    const uid = uniqueId("student-stop");
    await deleteDoc(userRef(uid));
    await deleteDoc(searchRequestRef(uid));
    await seedUser(uid);

    try {
      await seedActiveRequest(uid, {
        activeSessionId: "session-a",
        currentSessionId: "session-a",
        matchedSessionId: "session-a",
        matchedResponderId: "teacher-a",
        matchedTeacherId: "teacher-a",
        matchedUserId: "teacher-a",
        matchedRole: "native_speaker",
        pairAttemptId: "pair-a",
        candidateLockOwner: "candidate-lock-a",
        candidateLockExpiresAt: futureTimestamp(1),
        expiresAt: futureTimestamp(10),
        errorCode: "old_error",
        errorMessage: "old message",
      });

      const response = await wrappedStopSearch({
        requestId: "request-active",
      }, authContext(uid));
      const snapshot = await searchRequestRef(uid).get();
      const requestData = snapshot.data();

      assert.equal(snapshot.exists, true);
      assert.equal(response.status, "stopped");
      assert.equal(response.stopped, true);
      assert.equal(response.reason, "manual");
      assert.equal(response.searchRequestId, uid);
      assert.equal(response.requestId, "request-active");
      assert.equal(response.sessionId, "session-a");
      assert.equal(response.pairAttemptId, null);
      assert.equal(response.expiresAt, null);
      assert.equal(response.errorCode, null);
      assert.equal(response.cancelledSessionId, null);
      assert.equal(response.notificationCleanupStatus, "skipped");
      assert.equal(response.dailyRoomCleanupStatus, "skipped");
      assert.equal(response.searchRequest.status, "stopped");
      assert.equal(response.searchRequest.stopped, true);
      assert.equal(response.searchRequest.reason, "manual");
      assert.equal(response.videoSession.status, "noop");
      assert.equal(requestData.status, "stopped");
      assert.equal(requestData.stopReason, "manual");
      assert.equal(requestData.stoppedBy, uid);
      assert.ok(requestData.stoppedAt);
      assert.ok(requestData.updatedAt);
      assert.equal(requestData.activeSessionId, undefined);
      assert.equal(requestData.currentSessionId, null);
      assert.equal(requestData.matchedSessionId, undefined);
      assert.equal(requestData.matchedResponderId, undefined);
      assert.equal(requestData.matchedTeacherId, undefined);
      assert.equal(requestData.matchedUserId, null);
      assert.equal(requestData.matchedRole, null);
      assert.equal(requestData.pairAttemptId, null);
      assert.deepEqual(requestData.excludedCandidateIds, []);
      assert.deepEqual(requestData.attemptExcludedCandidateIds, []);
      assert.equal(requestData.candidateLockOwner, undefined);
      assert.equal(requestData.candidateLockExpiresAt, undefined);
      assert.equal(requestData.lockOwner, null);
      assert.equal(requestData.lockExpiresAt, null);
      assert.equal(requestData.lastError, null);
      assert.equal(requestData.errorCode, undefined);
      assert.equal(requestData.errorMessage, undefined);
    } finally {
      await deleteDoc(searchRequestRef(uid));
      await deleteDoc(userRef(uid));
    }
  });

  test("stopSearch callable ignores stale requestId", async () => {
    const uid = uniqueId("student-stale-stop");
    await deleteDoc(userRef(uid));
    await deleteDoc(searchRequestRef(uid));
    await seedUser(uid);
    await seedActiveRequest(uid, {requestId: "request-new"});

    const response = await wrappedStopSearch({
      requestId: "request-old",
    }, authContext(uid));
    const snapshot = await searchRequestRef(uid).get();

    assert.equal(response.status, "noop");
    assert.equal(response.reason, "request_mismatch");
    assert.equal(snapshot.data().status, "active");
    assert.equal(snapshot.data().requestId, "request-new");
  });

  test("stopSearch callable does not cancel active video session", async () => {
    const uid = uniqueId("student-active-session");
    const sessionId = uniqueId("session-active");
    await deleteDoc(userRef(uid));
    await deleteDoc(searchRequestRef(uid));
    await deleteDoc(sessionRef(sessionId));
    await seedUser(uid, {currentSessionId: sessionId});
    await seedActiveRequest(uid, {
      requestId: "request-active",
      currentSessionId: sessionId,
    });
    await sessionRef(sessionId).set({
      status: "active",
      studentId: uid,
      tutorId: "teacher-a",
      participantIds: [uid, "teacher-a"],
    });

    const response = await wrappedStopSearch({
      requestId: "request-active",
    }, authContext(uid));
    const searchSnapshot = await searchRequestRef(uid).get();
    const sessionSnapshot = await sessionRef(sessionId).get();

    assert.equal(response.status, "stopped");
    assert.equal(searchSnapshot.data().status, "stopped");
    assert.equal(sessionSnapshot.data().status, "active");
  });

  test("stopSearch callable cancels own explicit legacy searching session", async () => {
    const uid = uniqueId("student-legacy-session");
    const teacherId = uniqueId("teacher-legacy-session");
    const sessionId = uniqueId("session-legacy");
    await deleteDoc(userRef(uid));
    await deleteDoc(userRef(teacherId));
    await deleteDoc(searchRequestRef(uid));
    await deleteDoc(sessionRef(sessionId));
    await seedUser(uid, {currentSessionId: sessionId});
    await seedUser(teacherId, {role: "native_speaker", currentSessionId: sessionId});
    await sessionRef(sessionId).set({
      status: "searching",
      studentId: uid,
      currentTutorId: teacherId,
    });

    const response = await wrappedStopSearch({
      sessionId,
    }, authContext(uid));
    const sessionSnapshot = await sessionRef(sessionId).get();
    const userSnapshot = await userRef(uid).get();
    const teacherSnapshot = await userRef(teacherId).get();

    assert.equal(response.status, "cancelled");
    assert.equal(response.cancelledSessionId, sessionId);
    assert.equal(sessionSnapshot.data().status, "cancelled");
    assert.equal(userSnapshot.data().currentSessionId, undefined);
    assert.equal(teacherSnapshot.data().currentSessionId, undefined);
  });
}
