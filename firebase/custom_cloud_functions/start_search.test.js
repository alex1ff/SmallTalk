const test = require("node:test");
const assert = require("node:assert/strict");
const {
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_FIELD,
  SEARCH_REQUEST_STATUS,
  SEARCH_REQUEST_TIMING,
} = require("./search_requests");
const {
  __private__: {
    buildStartSearchAccessDecision,
    buildStartSearchFilters,
    buildStartSearchRequestData,
    buildStartSearchResponse,
    canReuseSearchRequestForUser,
    isReusableSearchRequest,
    normalizeStartSearchInput,
    searchRequestBelongsToUser,
  },
} = require("./start_search");

const fixedNowMillis = Date.parse("2026-06-21T10:00:00.000Z");
const serverTimestamp = Symbol("serverTimestamp");

function timestampFromMillis(millis) {
  return {
    toMillis: () => millis,
    toDate: () => new Date(millis),
  };
}

function futureTimestamp(minutes = 60) {
  return timestampFromMillis(fixedNowMillis + minutes * 60 * 1000);
}

function studentData(overrides = {}) {
  return {
    role: "student",
    learningLanguage: {code: "en"},
    level: "B1",
    Country_NS: {code: "US"},
    profileCity: {key: "new_york"},
    giftMinutes: {
      minutes: 10,
      expiresAt: futureTimestamp(60),
    },
    isInCall: false,
    currentSessionId: "",
    ...overrides,
  };
}

test("start search input rejects direct-call payload", () => {
  assert.throws(
    () => normalizeStartSearchInput({directTutorId: "teacher-a"}),
    (error) =>
      error.code === "invalid-argument" &&
      error.details?.reason === "direct_call_not_supported",
  );
  assert.throws(
    () => normalizeStartSearchInput({directUserId: "student-b"}),
    (error) =>
      error.code === "invalid-argument" &&
      error.details?.reason === "direct_call_not_supported",
  );
  assert.throws(
    () => normalizeStartSearchInput({targetUserId: "teacher-a"}),
    (error) =>
      error.code === "invalid-argument" &&
      error.details?.reason === "direct_call_not_supported",
  );
  assert.equal(
    normalizeStartSearchInput({
      language: " EN ",
      preferredPartnerLevel: " b1 ",
      preferredCountry: " us ",
      cityKey: " New_York ",
      appState: "background",
      platform: "ios",
    }).language,
    "EN",
  );
});

test("start search access decision blocks invalid callers server-side", () => {
  assert.deepEqual(
    buildStartSearchAccessDecision({
      requesterRole: "native_speaker",
      requesterData: studentData({role: "native_speaker"}),
      nowMillis: fixedNowMillis,
    }),
    {
      allowed: false,
      code: "permission-denied",
      reason: "student_required",
      message: "Only students can start search",
    },
  );
  assert.equal(
    buildStartSearchAccessDecision({
      requesterRole: "student",
      requesterData: studentData({giftMinutes: null, subscription: null}),
      nowMillis: fixedNowMillis,
    }).reason,
    "no_active_access",
  );
  assert.equal(
    buildStartSearchAccessDecision({
      requesterRole: "student",
      requesterData: studentData({isInCall: true}),
      nowMillis: fixedNowMillis,
    }).reason,
    "active_call",
  );
  assert.equal(
    buildStartSearchAccessDecision({
      requesterRole: "student",
      requesterData: studentData({
        giftMinutes: null,
        subscription: {expiresAt: futureTimestamp(60)},
      }),
      usageData: {
        dayKey: "2026-06-21",
        dayDurationSeconds: 60 * 60,
        weekKey: "2026-W25",
        weekDurationSeconds: 60 * 60,
      },
      nowMillis: fixedNowMillis,
    }).code,
    "resource-exhausted",
  );
  assert.equal(
    buildStartSearchAccessDecision({
      requesterRole: "student",
      requesterData: studentData(),
      nowMillis: fixedNowMillis,
    }).allowed,
    true,
  );
});

test("start search filters are built from payload and profile defaults", () => {
  assert.deepEqual(
    buildStartSearchFilters({
      input: {
        preferredPartnerLevel: " c1 ",
        preferredCountry: " ca ",
        cityKey: " Toronto ",
      },
      requesterData: studentData(),
    }),
    {
      preferredLevel: "C1",
      levelRank: 5,
      countryCode: "CA",
      cityKey: "toronto",
    },
  );
  assert.deepEqual(
    buildStartSearchFilters({
      input: {},
      requesterData: studentData(),
    }),
    {
      preferredLevel: "B1",
      levelRank: 3,
      countryCode: "US",
      cityKey: "new_york",
    },
  );
});

test("active unexpired search request is reusable and returned unchanged", () => {
  const existingRequest = {
    status: SEARCH_REQUEST_STATUS.MATCHING,
    requestId: "request-existing",
    currentSessionId: "session-a",
    pairAttemptId: "pair-a",
    heartbeatAt: timestampFromMillis(fixedNowMillis - 30 * 1000),
    expiresAt: futureTimestamp(3),
    filters: {preferredLevel: "B1"},
  };

  assert.equal(isReusableSearchRequest(existingRequest, fixedNowMillis), true);
  assert.deepEqual(
    buildStartSearchResponse({
      userId: "student-a",
      requestData: existingRequest,
      reused: true,
    }),
    {
      status: "matching",
      searchRequestId: "student-a",
      requestId: "request-existing",
      sessionId: "session-a",
      pairAttemptId: "pair-a",
      expiresAt: "2026-06-21T10:03:00.000Z",
      errorCode: null,
      reused: true,
    },
  );
});

test("expired active and terminal requests are not reusable", () => {
  assert.equal(
    isReusableSearchRequest({
      status: SEARCH_REQUEST_STATUS.ACTIVE,
      expiresAt: timestampFromMillis(fixedNowMillis - 1),
    }, fixedNowMillis),
    false,
  );
  assert.equal(
    isReusableSearchRequest({
      status: SEARCH_REQUEST_STATUS.STOPPED,
      expiresAt: futureTimestamp(3),
    }, fixedNowMillis),
    false,
  );
});

test("stale active search request is not reusable", () => {
  assert.equal(
    isReusableSearchRequest({
      status: SEARCH_REQUEST_STATUS.ACTIVE,
      heartbeatAt: timestampFromMillis(
        fixedNowMillis -
          (SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS + 1) * 1000,
      ),
      expiresAt: futureTimestamp(3),
    }, fixedNowMillis),
    false,
  );
});

test("background expired active search request is not reusable", () => {
  assert.equal(
    isReusableSearchRequest({
      status: SEARCH_REQUEST_STATUS.ACTIVE,
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      heartbeatAt: timestampFromMillis(fixedNowMillis - 30 * 1000),
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis),
      expiresAt: futureTimestamp(3),
    }, fixedNowMillis),
    false,
  );
});

test("background active search request is reusable before background deadline", () => {
  assert.equal(
    isReusableSearchRequest({
      status: SEARCH_REQUEST_STATUS.ACTIVE,
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      heartbeatAt: timestampFromMillis(
        fixedNowMillis -
          (SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS + 1) * 1000,
      ),
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 1),
      expiresAt: futureTimestamp(3),
    }, fixedNowMillis),
    true,
  );
});

test("matched search request is reusable without fresh heartbeat", () => {
  assert.equal(
    isReusableSearchRequest({
      status: SEARCH_REQUEST_STATUS.MATCHED,
      expiresAt: futureTimestamp(3),
    }, fixedNowMillis),
    true,
  );
});

test("search request reuse requires current user ownership", () => {
  const requestData = {
    status: SEARCH_REQUEST_STATUS.ACTIVE,
    requestId: "request-a",
    userId: "student-b",
    userRef: {id: "student-b"},
    heartbeatAt: timestampFromMillis(fixedNowMillis - 30 * 1000),
    expiresAt: futureTimestamp(3),
  };

  assert.equal(searchRequestBelongsToUser(requestData, "student-a"), false);
  assert.equal(
    canReuseSearchRequestForUser({
      requestData,
      userId: "student-a",
      nowMillis: fixedNowMillis,
    }),
    false,
  );
  assert.equal(
    canReuseSearchRequestForUser({
      requestData: {...requestData, userId: "student-a"},
      userId: "student-a",
      nowMillis: fixedNowMillis,
    }),
    false,
  );
  assert.equal(
    canReuseSearchRequestForUser({
      requestData: {
        ...requestData,
        userId: "student-a",
        userRef: {id: "student-a"},
      },
      userId: "student-a",
      nowMillis: fixedNowMillis,
    }),
    true,
  );
});

test("new start search request data resets lifecycle fields", () => {
  const data = buildStartSearchRequestData({
    userId: "student-a",
    userRef: {path: "users/student-a"},
    requestId: "request-new",
    requesterData: studentData(),
    input: normalizeStartSearchInput({
      language: "fr",
      preferredPartnerLevel: "C2",
      appState: "background",
      platform: "ios",
    }),
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.equal(data[SEARCH_REQUEST_FIELD.REQUEST_ID], "request-new");
  assert.equal(data[SEARCH_REQUEST_FIELD.USER_ID], "student-a");
  assert.equal(data[SEARCH_REQUEST_FIELD.ROLE], "student");
  assert.equal(data[SEARCH_REQUEST_FIELD.LANGUAGE], "en");
  assert.equal(data[SEARCH_REQUEST_FIELD.STATUS], "active");
  assert.equal(data[SEARCH_REQUEST_FIELD.APP_STATE], "background");
  assert.deepEqual(data[SEARCH_REQUEST_FIELD.FILTERS], {
    preferredLevel: "C2",
    levelRank: 6,
    countryCode: "US",
    cityKey: "new_york",
  });
  assert.equal(data[SEARCH_REQUEST_FIELD.CURRENT_SESSION_ID], null);
  assert.equal(data[SEARCH_REQUEST_FIELD.PAIR_ATTEMPT_ID], null);
  assert.deepEqual(data[SEARCH_REQUEST_FIELD.EXCLUDED_CANDIDATE_IDS], []);
  assert.deepEqual(
    data[SEARCH_REQUEST_FIELD.ATTEMPT_EXCLUDED_CANDIDATE_IDS],
    [],
  );
  assert.equal(data[SEARCH_REQUEST_FIELD.LOCK_OWNER], null);
  assert.equal(data[SEARCH_REQUEST_FIELD.LOCK_EXPIRES_AT], null);
  assert.equal(data[SEARCH_REQUEST_FIELD.VERSION], 1);
  assert.equal(data[SEARCH_REQUEST_FIELD.STOP_REASON], null);
  assert.equal(data[SEARCH_REQUEST_FIELD.LAST_ERROR], null);
  assert.equal(
    data[SEARCH_REQUEST_FIELD.EXPIRES_AT].toMillis(),
    fixedNowMillis + SEARCH_REQUEST_TIMING.MAX_SEARCH_SECONDS * 1000,
  );
  assert.equal(
    data[SEARCH_REQUEST_FIELD.BACKGROUND_EXPIRES_AT].toMillis(),
    fixedNowMillis + SEARCH_REQUEST_TIMING.BACKGROUND_MAX_SEARCH_SECONDS * 1000,
  );
});

test("foreground start keeps background expiry null", () => {
  const data = buildStartSearchRequestData({
    userId: "student-a",
    userRef: {path: "users/student-a"},
    requestId: "request-new",
    requesterData: studentData(),
    input: normalizeStartSearchInput({
      language: "en",
      appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
    }),
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.equal(data[SEARCH_REQUEST_FIELD.BACKGROUND_EXPIRES_AT], null);
});

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

if (!hasFirestoreEmulator) {
  test(
    "startSearch callable Firestore coverage requires emulator",
    {skip: "run with firebase emulators:exec --only firestore"},
    () => {},
  );
} else {
  const admin = require("firebase-admin");
  const functionsTest = require("firebase-functions-test");
  const {startSearch} = require("./start_search");

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
  const wrappedStartSearch = testEnv.wrap(startSearch);
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

  function emulatorFutureTimestamp(minutes = 60) {
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

  async function seedStudent(uid, overrides = {}) {
    await userRef(uid).set({
      role: "student",
      learningLanguage: {code: "en"},
      level: "B1",
      Country_NS: {code: "US"},
      profileCity: {key: "new_york"},
      giftMinutes: {
        minutes: 10,
        expiresAt: emulatorFutureTimestamp(60),
      },
      isInCall: false,
      currentSessionId: "",
      ...overrides,
    });
  }

  test("startSearch callable creates one active request document", async () => {
    const uid = uniqueId("student");
    await deleteDoc(userRef(uid));
    await deleteDoc(searchRequestRef(uid));
    await seedStudent(uid);

    const startedAtMillis = Date.now();
    const response = await wrappedStartSearch({
      preferredPartnerLevel: "B2",
      appState: "foreground",
      platform: "ios",
    }, authContext(uid));
    const snapshot = await searchRequestRef(uid).get();
    const requestData = snapshot.data();

    assert.equal(response.status, "active");
    assert.equal(response.searchRequestId, uid);
    assert.equal(response.sessionId, null);
    assert.equal(response.pairAttemptId, null);
    assert.equal(response.reused, false);
    assert.equal(snapshot.exists, true);
    assert.equal(requestData.requestId, response.requestId);
    assert.equal(requestData.userRef.path, `users/${uid}`);
    assert.equal(requestData.status, "active");
    assert.equal(requestData.userId, uid);
    assert.equal(requestData.role, "student");
    assert.equal(requestData.language, "en");
    assert.equal(requestData.appState, "foreground");
    assert.equal(requestData.backgroundExpiresAt, null);
    assert.deepEqual(requestData.filters, {
      preferredLevel: "B2",
      levelRank: 4,
      countryCode: "US",
      cityKey: "new_york",
    });
    assert.equal(typeof requestData.createdAt.toMillis, "function");
    assert.equal(typeof requestData.updatedAt.toMillis, "function");
    assert.equal(typeof requestData.heartbeatAt.toMillis, "function");
    assert.equal(typeof requestData.appStateUpdatedAt.toMillis, "function");
    assert.equal(typeof requestData.expiresAt.toMillis, "function");
    assert.ok(requestData.createdAt.toMillis() >= startedAtMillis - 5000);
    assert.ok(requestData.heartbeatAt.toMillis() >= startedAtMillis - 5000);
    assert.ok(
      requestData.expiresAt.toMillis() >=
        startedAtMillis + SEARCH_REQUEST_TIMING.MAX_SEARCH_SECONDS * 1000 -
          5000,
    );
    assert.deepEqual(requestData.excludedCandidateIds, []);
    assert.equal(requestData.currentSessionId, null);
  });

  test("startSearch callable returns active request idempotently", async () => {
    const uid = uniqueId("student-idempotent");
    await deleteDoc(userRef(uid));
    await deleteDoc(searchRequestRef(uid));
    await seedStudent(uid);

    const first = await wrappedStartSearch({
      preferredPartnerLevel: "B1",
    }, authContext(uid));
    const second = await wrappedStartSearch({
      preferredPartnerLevel: "C2",
    }, authContext(uid));
    const snapshot = await searchRequestRef(uid).get();

    assert.equal(second.reused, true);
    assert.equal(second.requestId, first.requestId);
    assert.deepEqual(snapshot.data().filters, {
      preferredLevel: "B1",
      levelRank: 3,
      countryCode: "US",
      cityKey: "new_york",
    });
  });

  test("startSearch callable keeps a single active request under concurrency", async () => {
    const uid = uniqueId("student-concurrent");
    await deleteDoc(userRef(uid));
    await deleteDoc(searchRequestRef(uid));
    await seedStudent(uid);

    const responses = await Promise.all(
      Array.from({length: 5}, (_, index) => wrappedStartSearch({
        preferredPartnerLevel: index % 2 === 0 ? "B1" : "C2",
      }, authContext(uid))),
    );
    const snapshot = await searchRequestRef(uid).get();
    const requestIds = new Set(responses.map((response) => response.requestId));

    assert.equal(snapshot.exists, true);
    assert.equal(requestIds.size, 1);
    assert.equal(snapshot.data().requestId, responses[0].requestId);
    assert.equal(snapshot.ref.id, uid);
    assert.equal(
      await db.collection("searchRequests").where("userId", "==", uid).get()
        .then((query) => query.size),
      1,
    );
  });

  test("startSearch callable does not reuse request owned by another user", async () => {
    const uid = uniqueId("student-owner-guard");
    const otherUid = uniqueId("student-owner-other");
    await deleteDoc(userRef(uid));
    await deleteDoc(userRef(otherUid));
    await deleteDoc(searchRequestRef(uid));
    await seedStudent(uid);
    await searchRequestRef(uid).set({
      requestId: "request-other-owner",
      userId: otherUid,
      userRef: userRef(otherUid),
      role: "student",
      language: "en",
      filters: {preferredLevel: "B1", levelRank: 3},
      status: "active",
      appState: "foreground",
      appStateUpdatedAt: admin.firestore.Timestamp.now(),
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      heartbeatAt: admin.firestore.Timestamp.now(),
      expiresAt: emulatorFutureTimestamp(10),
      backgroundExpiresAt: null,
      currentSessionId: "foreign-session",
      matchedUserId: "foreign-peer",
      matchedRole: "student",
      pairAttemptId: "foreign-pair",
      excludedCandidateIds: ["foreign-peer"],
      attemptExcludedCandidateIds: ["foreign-peer"],
      lockOwner: "foreign-lock",
      lockExpiresAt: emulatorFutureTimestamp(1),
      version: 1,
      stopReason: null,
      stoppedAt: null,
      lastError: null,
    });

    const response = await wrappedStartSearch({}, authContext(uid));
    const snapshot = await searchRequestRef(uid).get();

    assert.equal(response.reused, false);
    assert.notEqual(response.requestId, "request-other-owner");
    assert.equal(response.sessionId, null);
    assert.equal(snapshot.data().userId, uid);
    assert.equal(snapshot.data().currentSessionId, null);
    assert.equal(snapshot.data().matchedUserId, null);
    assert.equal(snapshot.data().pairAttemptId, null);
  });

  test(
    "startSearch callable reuses active request even if access changed",
    async () => {
      const uid = uniqueId("student-retry-no-access");
      await deleteDoc(userRef(uid));
      await deleteDoc(searchRequestRef(uid));
      await seedStudent(uid, {
        giftMinutes: null,
        subscription: null,
      });
      await searchRequestRef(uid).set({
        requestId: "request-active",
        userId: uid,
        userRef: userRef(uid),
        role: "student",
        language: "en",
        filters: {preferredLevel: "B1", levelRank: 3},
        status: "matching",
        appState: "foreground",
        appStateUpdatedAt: admin.firestore.Timestamp.now(),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
        heartbeatAt: admin.firestore.Timestamp.now(),
        expiresAt: emulatorFutureTimestamp(10),
        backgroundExpiresAt: null,
        currentSessionId: "session-active",
        matchedUserId: "teacher-a",
        matchedRole: "native_speaker",
        pairAttemptId: "pair-active",
        excludedCandidateIds: ["old-candidate"],
        attemptExcludedCandidateIds: ["teacher-a"],
        lockOwner: "matcher-a",
        lockExpiresAt: emulatorFutureTimestamp(1),
        version: 3,
        stopReason: null,
        stoppedAt: null,
        lastError: null,
      });

      const response = await wrappedStartSearch({
        preferredPartnerLevel: "C2",
      }, authContext(uid));
      const snapshot = await searchRequestRef(uid).get();

      assert.equal(response.reused, true);
      assert.equal(response.status, "matching");
      assert.equal(response.requestId, "request-active");
      assert.equal(response.sessionId, "session-active");
      assert.equal(response.pairAttemptId, "pair-active");
      assert.deepEqual(snapshot.data().filters, {
        preferredLevel: "B1",
        levelRank: 3,
      });
      assert.deepEqual(snapshot.data().excludedCandidateIds, ["old-candidate"]);
    },
  );

  test("startSearch callable reuses matched and legacy searching statuses", async () => {
    const statuses = ["matched", "searching"];

    for (const status of statuses) {
      const uid = uniqueId(`student-${status}`);
      await deleteDoc(userRef(uid));
      await deleteDoc(searchRequestRef(uid));
      await seedStudent(uid);
      await searchRequestRef(uid).set({
        requestId: `request-${status}`,
        userId: uid,
        userRef: userRef(uid),
        role: "student",
        language: "en",
        filters: {preferredLevel: "A2", levelRank: 2},
        status,
        appState: "foreground",
        appStateUpdatedAt: admin.firestore.Timestamp.now(),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
        heartbeatAt: admin.firestore.Timestamp.now(),
        expiresAt: emulatorFutureTimestamp(10),
        backgroundExpiresAt: null,
        currentSessionId: status === "matched" ? "session-a" : null,
        matchedUserId: status === "matched" ? "peer-a" : null,
        matchedRole: status === "matched" ? "student" : null,
        pairAttemptId: status === "matched" ? "pair-a" : null,
        excludedCandidateIds: ["kept-candidate"],
        attemptExcludedCandidateIds: [],
        lockOwner: null,
        lockExpiresAt: null,
        version: 1,
        stopReason: null,
        stoppedAt: null,
        lastError: null,
      });

      const response = await wrappedStartSearch({}, authContext(uid));
      const snapshot = await searchRequestRef(uid).get();

      assert.equal(response.reused, true);
      assert.equal(response.status, status);
      assert.equal(response.requestId, `request-${status}`);
      assert.deepEqual(snapshot.data().excludedCandidateIds, [
        "kept-candidate",
      ]);
    }
  });

  test("startSearch callable replaces terminal request lifecycle", async () => {
    const uid = uniqueId("student-terminal");
    await deleteDoc(userRef(uid));
    await deleteDoc(searchRequestRef(uid));
    await seedStudent(uid);
    await searchRequestRef(uid).set({
      requestId: "old-request",
      userId: uid,
      userRef: userRef(uid),
      role: "student",
      language: "en",
      filters: {preferredLevel: "A1", levelRank: 1},
      status: "stopped",
      appState: "foreground",
      appStateUpdatedAt: admin.firestore.Timestamp.now(),
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      heartbeatAt: admin.firestore.Timestamp.now(),
      expiresAt: emulatorFutureTimestamp(10),
      backgroundExpiresAt: null,
      currentSessionId: "old-session",
      matchedUserId: "old-peer",
      matchedRole: "student",
      pairAttemptId: "old-pair",
      excludedCandidateIds: ["old-peer"],
      attemptExcludedCandidateIds: ["old-peer"],
      lockOwner: "old-lock",
      lockExpiresAt: emulatorFutureTimestamp(1),
      version: 99,
      stopReason: "manual",
      stoppedAt: admin.firestore.Timestamp.now(),
      lastError: {code: "old"},
    });

    const response = await wrappedStartSearch({}, authContext(uid));
    const snapshot = await searchRequestRef(uid).get();
    const requestData = snapshot.data();

    assert.equal(response.reused, false);
    assert.notEqual(response.requestId, "old-request");
    assert.equal(requestData.status, "active");
    assert.equal(requestData.currentSessionId, null);
    assert.equal(requestData.matchedUserId, null);
    assert.equal(requestData.pairAttemptId, null);
    assert.deepEqual(requestData.excludedCandidateIds, []);
    assert.deepEqual(requestData.attemptExcludedCandidateIds, []);
    assert.equal(requestData.lockOwner, null);
    assert.equal(requestData.stopReason, null);
    assert.equal(requestData.lastError, null);
    assert.equal(requestData.version, 1);
  });

  test("startSearch callable rejects callers without access", async () => {
    const uid = uniqueId("student-no-access");
    await deleteDoc(userRef(uid));
    await deleteDoc(searchRequestRef(uid));
    await seedStudent(uid, {
      giftMinutes: null,
      subscription: null,
    });

    await assert.rejects(
      () => wrappedStartSearch({}, authContext(uid)),
      (error) =>
        error.code === "failed-precondition" &&
        error.details?.reason === "no_active_access",
    );
  });
}
