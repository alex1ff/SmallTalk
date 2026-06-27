const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_TIMING,
} = require("./search_requests");
const {
  __private__: {
    buildHeartbeatResponse,
    buildHeartbeatSearchDecision,
    normalizeHeartbeatInput,
    normalizeRequestId,
  },
} = require("./heartbeat_search");

const fixedNowMillis = Date.parse("2026-06-21T10:00:00.000Z");
const serverTimestamp = Symbol("serverTimestamp");

function timestampFromMillis(millis) {
  return {
    toMillis: () => millis,
    toDate: () => new Date(millis),
  };
}

function activeRequest(overrides = {}) {
  return {
    status: "active",
    requestId: "request-a",
    userId: "student-a",
    language: "en",
    heartbeatAt: timestampFromMillis(fixedNowMillis - 30 * 1000),
    expiresAt: timestampFromMillis(fixedNowMillis + 5 * 60 * 1000),
    backgroundExpiresAt: null,
    currentSessionId: null,
    pairAttemptId: null,
    ...overrides,
  };
}

test("heartbeat input requires lifecycle requestId", () => {
  assert.equal(normalizeRequestId(" request-a "), "request-a");
  assert.equal(normalizeRequestId("requests/request-a"), "");
  assert.throws(
    () => normalizeHeartbeatInput({}),
    (error) =>
      error.code === "invalid-argument" &&
      error.details?.reason === "request_id_required",
  );
  assert.deepEqual(normalizeHeartbeatInput({
    requestId: " request-a ",
    appState: "background",
  }), {
    requestId: "request-a",
    appState: "background",
  });
});

test("active heartbeat updates liveness fields without extending search expiry", () => {
  const decision = buildHeartbeatSearchDecision({
    requestExists: true,
    requestData: activeRequest(),
    userId: "student-a",
    requestId: "request-a",
    appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.equal(decision.ok, true);
  assert.deepEqual(decision.response, {
    status: "active",
    searchRequestId: "student-a",
    heartbeat: true,
    reason: "updated",
    requestId: "request-a",
    sessionId: null,
    pairAttemptId: null,
    expiresAt: "2026-06-21T10:05:00.000Z",
    errorCode: null,
  });
  assert.equal(decision.update.heartbeatAt, serverTimestamp);
  assert.equal(decision.update.updatedAt, serverTimestamp);
  assert.equal(decision.update.appState, "background");
  assert.equal(decision.update.appStateUpdatedAt, serverTimestamp);
  assert.deepEqual(Object.keys(decision.update).sort(), [
    "appState",
    "appStateUpdatedAt",
    "backgroundExpiresAt",
    "heartbeatAt",
    "updatedAt",
  ]);
  assert.equal(
    decision.update.backgroundExpiresAt.toMillis(),
    fixedNowMillis +
      SEARCH_REQUEST_TIMING.BACKGROUND_MAX_SEARCH_SECONDS * 1000,
  );
});

test("foreground heartbeat clears background expiry", () => {
  const decision = buildHeartbeatSearchDecision({
    requestExists: true,
    requestData: activeRequest({backgroundExpiresAt: timestampFromMillis(
      fixedNowMillis + 60 * 1000,
    )}),
    userId: "student-a",
    requestId: "request-a",
    appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.equal(decision.update.backgroundExpiresAt, null);
});

test("background heartbeat keeps first background expiry deadline", () => {
  const existingBackgroundExpiresAt = timestampFromMillis(
    fixedNowMillis + 5 * 60 * 1000,
  );

  const decision = buildHeartbeatSearchDecision({
    requestExists: true,
    requestData: activeRequest({
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: existingBackgroundExpiresAt,
      heartbeatAt: timestampFromMillis(fixedNowMillis - 30 * 1000),
    }),
    userId: "student-a",
    requestId: "request-a",
    appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update.backgroundExpiresAt, existingBackgroundExpiresAt);
});

test("foreground heartbeat resumes background request before deadline", () => {
  const decision = buildHeartbeatSearchDecision({
    requestExists: true,
    requestData: activeRequest({
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 5 * 60 * 1000),
      heartbeatAt: timestampFromMillis(fixedNowMillis - 30 * 1000),
    }),
    userId: "student-a",
    requestId: "request-a",
    appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.update.appState, "foreground");
  assert.equal(decision.update.backgroundExpiresAt, null);
});

test("heartbeat ignores stale requestId and terminal state", () => {
  const mismatch = buildHeartbeatSearchDecision({
    requestExists: true,
    requestData: activeRequest({requestId: "request-b"}),
    userId: "student-a",
    requestId: "request-a",
    appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });
  const terminal = buildHeartbeatSearchDecision({
    requestExists: true,
    requestData: activeRequest({status: "stopped"}),
    userId: "student-a",
    requestId: "request-a",
    appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.equal(mismatch.update, null);
  assert.equal(mismatch.response.reason, "request_mismatch");
  assert.equal(terminal.update, null);
  assert.equal(terminal.response.reason, "inactive");
});

test("heartbeat does not revive stale or expired requests", () => {
  const stale = buildHeartbeatSearchDecision({
    requestExists: true,
    requestData: activeRequest({
      heartbeatAt: timestampFromMillis(
        fixedNowMillis -
          (SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS + 1) * 1000,
      ),
    }),
    userId: "student-a",
    requestId: "request-a",
    appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });
  const expired = buildHeartbeatSearchDecision({
    requestExists: true,
    requestData: activeRequest({
      expiresAt: timestampFromMillis(fixedNowMillis - 1),
    }),
    userId: "student-a",
    requestId: "request-a",
    appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });
  const backgroundExpired = buildHeartbeatSearchDecision({
    requestExists: true,
    requestData: activeRequest({
      appState: "background",
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis - 1),
    }),
    userId: "student-a",
    requestId: "request-a",
    appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });
  const closedBackgroundStale = buildHeartbeatSearchDecision({
    requestExists: true,
    requestData: activeRequest({
      appState: "background",
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 5 * 60 * 1000),
      heartbeatAt: timestampFromMillis(
        fixedNowMillis -
          (SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS + 1) * 1000,
      ),
    }),
    userId: "student-a",
    requestId: "request-a",
    appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.equal(stale.update, null);
  assert.equal(stale.response.reason, "stale");
  assert.equal(expired.update, null);
  assert.equal(expired.response.reason, "expired");
  assert.equal(backgroundExpired.update, null);
  assert.equal(backgroundExpired.response.reason, "background_expired");
  assert.equal(closedBackgroundStale.update, null);
  assert.equal(closedBackgroundStale.response.reason, "stale");
});

test("heartbeat does not mutate matched request state", () => {
  const decision = buildHeartbeatSearchDecision({
    requestExists: true,
    requestData: activeRequest({
      status: "matched",
      currentSessionId: "session-a",
      pairAttemptId: "pair-a",
    }),
    userId: "student-a",
    requestId: "request-a",
    appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.equal(decision.update, null);
  assert.equal(decision.response.reason, "matched");
  assert.equal(decision.response.sessionId, "session-a");
  assert.equal(decision.response.pairAttemptId, "pair-a");
});

test("heartbeat response keeps queue API shape", () => {
  assert.deepEqual(
    buildHeartbeatResponse({
      userId: "student-a",
      requestData: activeRequest({
        currentSessionId: "session-a",
        pairAttemptId: "pair-a",
      }),
      heartbeat: true,
      reason: "updated",
    }),
    {
      status: "active",
      searchRequestId: "student-a",
      requestId: "request-a",
      sessionId: "session-a",
      pairAttemptId: "pair-a",
      expiresAt: "2026-06-21T10:05:00.000Z",
      errorCode: null,
      heartbeat: true,
      reason: "updated",
    },
  );
});

test("heartbeatSearch is exported and included in readiness deploy target", () => {
  const indexSource = fs.readFileSync(path.join(__dirname, "index.js"), "utf8");
  const packageJson = JSON.parse(fs.readFileSync(
      path.join(__dirname, "package.json"),
      "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];

  assert.match(indexSource, /exports\.heartbeatSearch\b/);
  assert.match(deployScript, /functions:custom_cloud_functions:heartbeatSearch\b/);
});

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

if (!hasFirestoreEmulator) {
  test(
    "heartbeatSearch callable Firestore coverage requires emulator",
    {skip: "run with firebase emulators:exec --only firestore"},
    () => {},
  );
} else {
  const admin = require("firebase-admin");
  const functionsTest = require("firebase-functions-test");
  const {heartbeatSearch} = require("./heartbeat_search");

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
  const wrappedHeartbeatSearch = testEnv.wrap(heartbeatSearch);
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

  function futureTimestamp(minutes = 10) {
    return admin.firestore.Timestamp.fromMillis(
      Date.now() + minutes * 60 * 1000,
    );
  }

  function pastTimestamp(seconds = 30) {
    return admin.firestore.Timestamp.fromMillis(Date.now() - seconds * 1000);
  }

  async function deleteDoc(ref) {
    const snapshot = await ref.get();
    if (snapshot.exists) {
      await ref.delete();
    }
  }

  async function seedRequest(uid, overrides = {}) {
    await searchRequestRef(uid).set({
      requestId: "request-active",
      userId: uid,
      userRef: userRef(uid),
      role: "student",
      language: "en",
      filters: {preferredLevel: "B1", levelRank: 3},
      status: "active",
      appState: "foreground",
      appStateUpdatedAt: pastTimestamp(30),
      createdAt: pastTimestamp(60),
      updatedAt: pastTimestamp(30),
      heartbeatAt: pastTimestamp(30),
      expiresAt: futureTimestamp(10),
      backgroundExpiresAt: null,
      currentSessionId: null,
      matchedUserId: null,
      matchedRole: null,
      pairAttemptId: null,
      excludedCandidateIds: [],
      attemptExcludedCandidateIds: [],
      lockOwner: null,
      lockExpiresAt: null,
      version: 1,
      stopReason: null,
      stoppedAt: null,
      lastError: null,
      ...overrides,
    });
  }

  test("heartbeatSearch callable updates active request liveness", async () => {
    const uid = uniqueId("student-heartbeat");
    await deleteDoc(searchRequestRef(uid));

    try {
      await seedRequest(uid);
      const beforeSnapshot = await searchRequestRef(uid).get();
      const beforeData = beforeSnapshot.data();
      const beforeHeartbeatAt = beforeData.heartbeatAt.toMillis();
      const beforeUpdatedAt = beforeData.updatedAt.toMillis();
      const beforeAppStateUpdatedAt = beforeData.appStateUpdatedAt.toMillis();
      const beforeExpiresAt = beforeData.expiresAt.toMillis();

      const response = await wrappedHeartbeatSearch({
        requestId: "request-active",
        appState: "background",
      }, authContext(uid));
      const snapshot = await searchRequestRef(uid).get();
      const requestData = snapshot.data();

      assert.equal(response.status, "active");
      assert.equal(response.heartbeat, true);
      assert.equal(response.reason, "updated");
      assert.equal(response.searchRequestId, uid);
      assert.equal(response.requestId, "request-active");
      assert.equal(response.expiresAt, new Date(beforeExpiresAt).toISOString());
      assert.equal(requestData.status, "active");
      assert.equal(requestData.requestId, "request-active");
      assert.equal(requestData.appState, "background");
      assert.ok(
        requestData.heartbeatAt.toMillis() > beforeHeartbeatAt,
        "heartbeatAt should move forward",
      );
      assert.ok(
        requestData.updatedAt.toMillis() > beforeUpdatedAt,
        "updatedAt should move forward",
      );
      assert.ok(
        requestData.appStateUpdatedAt.toMillis() > beforeAppStateUpdatedAt,
        "appStateUpdatedAt should move forward",
      );
      assert.equal(requestData.expiresAt.toMillis(), beforeExpiresAt);
      assert.notEqual(requestData.backgroundExpiresAt, null);
      assert.ok(
        requestData.backgroundExpiresAt.toMillis() >
          requestData.heartbeatAt.toMillis(),
        "background deadline should be after heartbeat",
      );
      assert.ok(
        requestData.backgroundExpiresAt.toMillis() -
          requestData.heartbeatAt.toMillis() <=
          SEARCH_REQUEST_TIMING.BACKGROUND_MAX_SEARCH_SECONDS * 1000,
        "background deadline should stay within max background search time",
      );
    } finally {
      await deleteDoc(searchRequestRef(uid));
    }
  });

  test("heartbeatSearch callable clears background expiry in foreground", async () => {
    const uid = uniqueId("student-heartbeat-foreground");
    await deleteDoc(searchRequestRef(uid));
    await seedRequest(uid, {
      appState: "background",
      backgroundExpiresAt: futureTimestamp(5),
    });

    await wrappedHeartbeatSearch({
      requestId: "request-active",
      appState: "foreground",
    }, authContext(uid));
    const snapshot = await searchRequestRef(uid).get();

    assert.equal(snapshot.data().appState, "foreground");
    assert.equal(snapshot.data().backgroundExpiresAt, null);
  });

  test("heartbeatSearch callable ignores stale lifecycle id", async () => {
    const uid = uniqueId("student-heartbeat-stale");
    await deleteDoc(searchRequestRef(uid));
    await seedRequest(uid, {requestId: "request-new"});

    const response = await wrappedHeartbeatSearch({
      requestId: "request-old",
      appState: "foreground",
    }, authContext(uid));
    const snapshot = await searchRequestRef(uid).get();

    assert.equal(response.heartbeat, false);
    assert.equal(response.reason, "request_mismatch");
    assert.equal(snapshot.data().requestId, "request-new");
  });

  test("heartbeatSearch callable does not update terminal request", async () => {
    const uid = uniqueId("student-heartbeat-terminal");
    await deleteDoc(searchRequestRef(uid));
    await seedRequest(uid, {
      status: "stopped",
      heartbeatAt: pastTimestamp(30),
    });
    const beforeSnapshot = await searchRequestRef(uid).get();
    const beforeHeartbeat = beforeSnapshot.data().heartbeatAt.toMillis();

    const response = await wrappedHeartbeatSearch({
      requestId: "request-active",
      appState: "foreground",
    }, authContext(uid));
    const snapshot = await searchRequestRef(uid).get();

    assert.equal(response.heartbeat, false);
    assert.equal(response.reason, "inactive");
    assert.equal(snapshot.data().heartbeatAt.toMillis(), beforeHeartbeat);
  });
}
