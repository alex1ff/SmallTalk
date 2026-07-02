const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_FIELD,
  SEARCH_REQUEST_STATUS,
  SEARCH_REQUEST_TIMING,
} = require("./search_requests");
const {
  __private__: {
    buildCurrentMatchedStartSearchResponse,
    buildStudentPairRequesterInfo,
    buildStudentPairResponderCallData,
    buildStudentPairResponderFcmMessage,
    buildStudentPairResponderPushPayload,
    buildStartSearchAccessDecision,
    buildStartSearchFailureUpdate,
    buildStartSearchFilters,
    buildMatchedStartSearchResponse,
    buildStartSearchRequestData,
    buildStartSearchResponse,
    buildStudentPairSessionData,
    cancelBackgroundStudentResponderNotification,
    cancelTeacherResponderNotification,
    canAttemptStudentPairForSearchRequest,
    canReuseSearchRequestForUser,
    hasCurrentMatchedSession,
    hasSearchRequestSessionBinding,
    isFirestoreIndexUnavailableError,
    isFreshBackgroundSearchRequest,
    isSessionResponseWindowOpen,
    isStudentResponderSession,
    isTeacherResponderSession,
    isReusableSearchRequest,
    maybeNotifyBackgroundStudentResponder,
    maybeNotifyTeacherResponder,
    normalizeStartSearchInput,
    readErrorMessage,
    recordBackgroundStudentResponderPushFailure,
    recordBackgroundStudentResponderPushSuccess,
    releaseBackgroundStudentResponderMatchForRetry,
    recordTeacherResponderPushResult,
    releaseTeacherResponderMatchForRetry,
    runBackgroundStudentResponderPushSender,
    searchRequestBelongsToResponder,
    searchRequestBelongsToUser,
    searchRequestMatchesSession,
    sendVoipPushToStudentResponder,
    shouldCreateBackgroundStudentResponderIncomingCall,
    shouldCreateTeacherResponderIncomingCall,
    shouldFailUnboundStartSearchRequest,
    shouldRetryBackgroundStudentMatchAfterNotifyResult,
    shouldRetryTeacherMatchAfterNotifyResult,
    shouldUseTeacherResponderForIncomingCall,
    startSearchCallable,
    teacherResponderPushStillCurrent,
    tryReadCurrentMatchedStartSearchResponse,
  },
} = require("./start_search");
const {
  buildCallKitIdForSession,
} = require("./call_notifications");
const {
  MATCH_PAIR_LOCK_TTL_SECONDS,
} = require("./match_pair_lock");

const fixedNowMillis = Date.parse("2026-06-21T10:00:00.000Z");
const serverTimestamp = Symbol("serverTimestamp");
const fieldDelete = Symbol("fieldDelete");

function timestampFromMillis(millis) {
  return {
    toMillis: () => millis,
    toDate: () => new Date(millis),
  };
}

function futureTimestamp(minutes = 60) {
  return timestampFromMillis(fixedNowMillis + minutes * 60 * 1000);
}

function timestampFromDate(date) {
  return timestampFromMillis(date.getTime());
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
  for (const directAlias of [
    "directTutorId",
    "directUserId",
    "targetUserId",
    "targetTutorId",
    "teacherId",
    "tutorId",
  ]) {
    assert.throws(
      () => normalizeStartSearchInput({[directAlias]: "teacher-a"}),
      (error) =>
        error.code === "invalid-argument" &&
        error.details?.reason === "direct_call_not_supported",
      directAlias,
    );
  }
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

test("start search source avoids unsafe error.message reads", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "start_search.js"),
    "utf8",
  );
  const unsafeMessageReads = source
    .split("\n")
    .filter((line) => /\berror\??\.message\b/.test(line))
    .filter((line) => !line.includes("normalizeString(error.message)"));
  const unsafeStringFallbacks = source
    .split("\n")
    .filter((line) => /readErrorMessage\([^,]+,\s*String\(/.test(line));

  assert.deepEqual(unsafeMessageReads, []);
  assert.deepEqual(unsafeStringFallbacks, []);
});

test("start search source keeps teachers in unified candidate loop", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "start_search.js"),
    "utf8",
  );

  assert.doesNotMatch(source, /includeTeachers:\s*false/);
  assert.match(source, /const matchCandidates = candidatePool\.candidates/);
  assert.match(source, /MATCH_CANDIDATE_SOURCE\.TEACHER_AVAILABILITY/);
  assert.match(source, /maybeNotifyTeacherResponder/);
});

test("start search error message helper never throws", () => {
  const throwingMessage = {};
  Object.defineProperty(throwingMessage, "message", {
    get: () => {
      throw new Error("getter failed");
    },
  });
  const throwingToString = {
    toString: () => {
      throw new Error("stringify failed");
    },
  };

  assert.equal(
    readErrorMessage(new Error("plain failure"), "fallback"),
    "plain failure",
  );
  assert.equal(readErrorMessage("text failure", "fallback"), "text failure");
  assert.equal(readErrorMessage(throwingMessage, "fallback"), "fallback");
  assert.equal(readErrorMessage(throwingToString, "fallback"), "fallback");
});

test("start search keeps request active when matcher index is unavailable", () => {
  const buildingIndexError = new Error(
    "9 FAILED_PRECONDITION: The query requires an index. " +
      "That index is currently building and cannot be used yet.",
  );
  buildingIndexError.code = 9;
  buildingIndexError.details = "The query requires an index.";

  const missingIndexError = new Error(
    "The query requires an index. See its status in Firestore indexes.",
  );
  missingIndexError.code = "failed-precondition";

  const unrelatedPrecondition = new Error("Active call must finish first");
  unrelatedPrecondition.code = 9;

  assert.equal(isFirestoreIndexUnavailableError(buildingIndexError), true);
  assert.equal(isFirestoreIndexUnavailableError(missingIndexError), true);
  assert.equal(isFirestoreIndexUnavailableError(unrelatedPrecondition), false);
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

test("start search filters are built only from explicit payload filters", () => {
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
    {},
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

test("matched start search response exposes created pair session", () => {
  assert.deepEqual(
    buildMatchedStartSearchResponse({
      userId: "student-a",
      requestData: {
        status: SEARCH_REQUEST_STATUS.ACTIVE,
        requestId: "request-a",
        expiresAt: futureTimestamp(3),
      },
      matchResult: {
        sessionId: "session-ab",
        pairAttemptId: "pair-ab",
        responderId: "student-b",
        responderRole: "student",
      },
      reused: false,
    }),
    {
      status: "matched",
      searchRequestId: "student-a",
      requestId: "request-a",
      sessionId: "session-ab",
      pairAttemptId: "pair-ab",
      expiresAt: "2026-06-21T10:03:00.000Z",
      errorCode: null,
      reused: false,
      matchedUserId: "student-b",
      matchedRole: "student",
      scenario: "student_student",
    },
  );
  assert.deepEqual(
    buildMatchedStartSearchResponse({
      userId: "student-a",
      requestData: {
        status: SEARCH_REQUEST_STATUS.ACTIVE,
        requestId: "request-a",
        expiresAt: futureTimestamp(3),
      },
      matchResult: {
        sessionId: "session-at",
        pairAttemptId: "pair-at",
        responderId: "teacher-a",
        responderRole: "native_speaker",
      },
      reused: false,
    }),
    {
      status: "matched",
      searchRequestId: "student-a",
      requestId: "request-a",
      sessionId: "session-at",
      pairAttemptId: "pair-at",
      expiresAt: "2026-06-21T10:03:00.000Z",
      errorCode: null,
      reused: false,
      matchedUserId: "teacher-a",
      matchedRole: "native_speaker",
      scenario: "student_teacher",
    },
  );
});

test("current matched search response can be rebuilt after match race", async () => {
  const requestData = {
    status: SEARCH_REQUEST_STATUS.MATCHED,
    requestId: "request-a",
    userId: "student-a",
    currentSessionId: "session-ab",
    matchedSessionId: "session-ab",
    matchedUserId: "student-b",
    matchedResponderId: "student-a",
    matchedRole: "student",
    pairAttemptId: "pair-ab",
    expiresAt: futureTimestamp(3),
  };
  const fakeDb = {
    collection: (collectionName) => {
      assert.equal(collectionName, "searchRequests");
      return {
        doc: (docId) => {
          assert.equal(docId, "student-a");
          return {
            get: async () => ({
              exists: true,
              data: () => requestData,
            }),
          };
        },
      };
    },
  };

  assert.equal(hasCurrentMatchedSession(requestData), true);
  assert.deepEqual(
    buildCurrentMatchedStartSearchResponse({
      userId: "student-a",
      requestData,
      reused: true,
    }),
    {
      status: "matched",
      searchRequestId: "student-a",
      requestId: "request-a",
      sessionId: "session-ab",
      pairAttemptId: "pair-ab",
      expiresAt: "2026-06-21T10:03:00.000Z",
      errorCode: null,
      reused: true,
      matchedUserId: "student-b",
      matchedRole: "student",
      scenario: "student_student",
    },
  );
  assert.deepEqual(
    await tryReadCurrentMatchedStartSearchResponse({
      db: fakeDb,
      userId: "student-a",
      reused: true,
    }),
    buildCurrentMatchedStartSearchResponse({
      userId: "student-a",
      requestData,
      reused: true,
    }),
  );
  assert.equal(hasCurrentMatchedSession({
    ...requestData,
    status: SEARCH_REQUEST_STATUS.ACTIVE,
  }), false);
});

test("current matched search response maps teacher scenario", () => {
  assert.deepEqual(
    buildCurrentMatchedStartSearchResponse({
      userId: "student-a",
      requestData: {
        status: SEARCH_REQUEST_STATUS.MATCHED,
        requestId: "request-a",
        currentSessionId: "session-at",
        matchedUserId: "teacher-a",
        matchedResponderId: "teacher-a",
        matchedRole: "native_speaker",
        pairAttemptId: "pair-at",
        expiresAt: futureTimestamp(3),
      },
      reused: true,
    }),
    {
      status: "matched",
      searchRequestId: "student-a",
      requestId: "request-a",
      sessionId: "session-at",
      pairAttemptId: "pair-at",
      expiresAt: "2026-06-21T10:03:00.000Z",
      errorCode: null,
      reused: true,
      matchedUserId: "teacher-a",
      matchedRole: "native_speaker",
      scenario: "student_teacher",
    },
  );
  assert.equal(
    buildCurrentMatchedStartSearchResponse({
      userId: "student-a",
      requestData: {
        status: SEARCH_REQUEST_STATUS.MATCHED,
        requestId: "request-a",
        currentSessionId: "session-at",
        matchedUserId: "teacher-a",
        matchedRole: "Teacher",
      },
      reused: true,
    }).scenario,
    "student_teacher",
  );
  assert.equal(
    buildCurrentMatchedStartSearchResponse({
      userId: "student-a",
      requestData: {
        status: SEARCH_REQUEST_STATUS.MATCHED,
        requestId: "request-a",
        currentSessionId: "session-at",
        matchedUserId: "teacher-a",
        matchedRole: "Teacher",
      },
      reused: true,
    }).matchedRole,
    "native_speaker",
  );
});

test("student pair session data carries matching context", () => {
  const sessionData = buildStudentPairSessionData({
    requesterId: "student-a",
    requestData: {
      language: "en",
      filters: {preferredLevel: "B1", levelRank: 3},
    },
    selectedCandidate: {
      userId: "student-b",
      source: "active_student_queue",
      searchRequestId: "request-b",
    },
    studentCandidates: [
      {userId: "student-b"},
      {userId: "student-c"},
    ],
    candidateStats: {
      studentRequestsScanned: 2,
      studentCandidates: 2,
      teacherUsersScanned: 0,
      teacherCandidates: 0,
      totalCandidates: 2,
    },
    nowMillis: fixedNowMillis,
    timestampFromDate,
  });

  assert.equal(sessionData.language, "en");
  assert.equal(
    sessionData.expiresAt.toMillis(),
    Date.parse("2026-06-21T10:05:00.000Z"),
  );
  assert.equal(sessionData.sessionPolicy.baseLimitSeconds, 300);
  assert.equal(sessionData.sessionPolicy.warningLeadSeconds, 60);
  assert.equal(sessionData.sessionPolicy.maxExtensionCount, 1);
  assert.equal(sessionData.sessionPolicy.extensionSeconds, 300);
  assert.equal(sessionData.sessionPolicy.effectiveLimitSeconds, 300);
  assert.equal(sessionData.studentHasReviewed, false);
  assert.equal(sessionData.tutorHasReviewed, false);
  assert.deepEqual(sessionData.availableTutors, ["student-b", "student-c"]);
  assert.deepEqual(sessionData.triedTutors, ["student-b"]);
  assert.deepEqual(sessionData.matchContext.filters, {
    preferredLevel: "B1",
    levelRank: 3,
  });
  assert.equal(sessionData.matchContext.requesterId, "student-a");
  assert.equal(sessionData.matchContext.selectedResponderId, "student-b");
  assert.equal(sessionData.matchContext.selectedResponderRole, "student");
  assert.equal(
    sessionData.matchContext.selectedResponderSearchRequestId,
    "request-b",
  );
  assert.equal(sessionData.matchContext.candidatePoolSize, 2);

  const teacherSessionData = buildStudentPairSessionData({
    requesterId: "student-a",
    requestData: {
      language: "en",
      filters: {preferredLevel: "B1", levelRank: 3},
    },
    selectedCandidate: {
      userId: "teacher-a",
      role: "native_speaker",
      source: "teacher_availability",
    },
    matchCandidates: [
      {userId: "teacher-a", role: "native_speaker"},
      {userId: "student-b", role: "student"},
    ],
    candidateStats: {
      studentRequestsScanned: 1,
      studentCandidates: 1,
      teacherUsersScanned: 1,
      teacherCandidates: 1,
      totalCandidates: 2,
    },
    nowMillis: fixedNowMillis,
    timestampFromDate,
  });

  assert.deepEqual(teacherSessionData.availableTutors, [
    "teacher-a",
    "student-b",
  ]);
  assert.deepEqual(teacherSessionData.triedTutors, ["teacher-a"]);
  assert.equal(
    teacherSessionData.matchContext.selectedResponderRole,
    "native_speaker",
  );
  assert.equal(
    teacherSessionData.matchContext.selectedResponderSource,
    "teacher_availability",
  );
});

test("student pair creation is attempted only for open search requests", () => {
  assert.equal(
    canAttemptStudentPairForSearchRequest({
      status: SEARCH_REQUEST_STATUS.ACTIVE,
    }),
    true,
  );
  assert.equal(
    canAttemptStudentPairForSearchRequest({status: "searching"}),
    false,
  );
  assert.equal(
    canAttemptStudentPairForSearchRequest({
      status: SEARCH_REQUEST_STATUS.MATCHING,
    }),
    false,
  );
  assert.equal(
    canAttemptStudentPairForSearchRequest({
      status: SEARCH_REQUEST_STATUS.MATCHED,
    }),
    false,
  );
});

test("background responder incoming call requires fresh background request", () => {
  const pendingSessionData = {
    status: "pending_confirmation",
    currentResponderId: "student-b",
    currentTutorId: "student-b",
    currentResponderRole: "student",
    responderRole: "student",
    scenario: "student_student",
    participantRoles: {
      "student-a": "student",
      "student-b": "student",
    },
    responseExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
    confirmationExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
  };
  const freshBackgroundRequest = {
    status: SEARCH_REQUEST_STATUS.MATCHED,
    userId: "student-b",
    appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
    backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 60_000),
    currentSessionId: "session-ab",
  };

  assert.equal(
    isFreshBackgroundSearchRequest(freshBackgroundRequest, fixedNowMillis),
    true,
  );
  assert.equal(
    isFreshBackgroundSearchRequest({
      ...freshBackgroundRequest,
      status: SEARCH_REQUEST_STATUS.ACTIVE,
    }, fixedNowMillis),
    false,
  );
  assert.equal(
    isSessionResponseWindowOpen(pendingSessionData, fixedNowMillis),
    true,
  );
  assert.equal(
    searchRequestMatchesSession(freshBackgroundRequest, "session-ab"),
    true,
  );
  assert.equal(
    searchRequestBelongsToResponder(freshBackgroundRequest, "student-b"),
    true,
  );
  assert.equal(
    searchRequestBelongsToResponder({
      ...freshBackgroundRequest,
      userId: "student-c",
    }, "student-b"),
    false,
  );
  assert.equal(
    isStudentResponderSession(pendingSessionData, "student-b"),
    true,
  );
  assert.equal(
    isStudentResponderSession({
      ...pendingSessionData,
      scenario: "",
    }, "student-b"),
    false,
  );
  assert.equal(
    isStudentResponderSession({
      ...pendingSessionData,
      currentResponderRole: "",
    }, "student-b"),
    false,
  );
  assert.equal(
    isStudentResponderSession({
      ...pendingSessionData,
      responderRole: "",
    }, "student-b"),
    false,
  );
  assert.equal(
    isStudentResponderSession({
      ...pendingSessionData,
      participantRoles: {
        "student-a": "student",
      },
    }, "student-b"),
    false,
  );
  assert.equal(
    isStudentResponderSession({
      ...pendingSessionData,
      participantRoles: {
        "student-a": "student",
        "student-b": "native_speaker",
      },
    }, "student-b"),
    false,
  );
  assert.deepEqual(
    shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData: {
        ...pendingSessionData,
        participantRoles: {
          "student-a": "student",
          "student-b": "native_speaker",
        },
      },
      sessionId: "session-ab",
      responderId: "student-b",
      responderSearchRequestData: freshBackgroundRequest,
      nowMillis: fixedNowMillis,
    }),
    {shouldNotify: false, reason: "responder_not_student"},
  );
  assert.equal(
    searchRequestMatchesSession(freshBackgroundRequest, ""),
    false,
  );
  assert.equal(
    searchRequestMatchesSession({
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 60_000),
    }, "session-ab"),
    false,
  );
  assert.deepEqual(
    shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData: pendingSessionData,
      sessionId: "session-ab",
      responderId: "student-b",
      responderSearchRequestData: freshBackgroundRequest,
      nowMillis: fixedNowMillis,
    }),
    {shouldNotify: true, reason: "background_responder"},
  );
  assert.deepEqual(
    shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData: pendingSessionData,
      sessionId: "session-ab",
      responderId: "student-b",
      responderSearchRequestData: {
        status: SEARCH_REQUEST_STATUS.MATCHED,
        userId: "student-b",
        appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
        backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 60_000),
        currentSessionId: "session-ab",
      },
      nowMillis: fixedNowMillis,
    }),
    {shouldNotify: false, reason: "responder_not_background"},
  );
  assert.deepEqual(
    shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData: pendingSessionData,
      sessionId: "session-ab",
      responderId: "student-b",
      responderSearchRequestData: {
        status: SEARCH_REQUEST_STATUS.MATCHED,
        userId: "student-b",
        appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
        backgroundExpiresAt: timestampFromMillis(fixedNowMillis),
        currentSessionId: "session-ab",
      },
      nowMillis: fixedNowMillis,
    }),
    {shouldNotify: false, reason: "responder_not_background"},
  );
  assert.deepEqual(
    shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData: {
        ...pendingSessionData,
        status: "connecting",
      },
      sessionId: "session-ab",
      responderId: "student-b",
      responderSearchRequestData: freshBackgroundRequest,
      nowMillis: fixedNowMillis,
    }),
    {shouldNotify: false, reason: "session_connecting"},
  );
  assert.deepEqual(
    shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData: {
        ...pendingSessionData,
        currentResponderRole: "native_speaker",
        responderRole: "native_speaker",
        scenario: "student_teacher",
        participantRoles: {
          "student-a": "student",
          "student-b": "native_speaker",
        },
      },
      sessionId: "session-ab",
      responderId: "student-b",
      responderSearchRequestData: freshBackgroundRequest,
      nowMillis: fixedNowMillis,
    }),
    {shouldNotify: false, reason: "responder_not_student"},
  );
  assert.deepEqual(
    shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData: {
        ...pendingSessionData,
        acceptingTutorId: "student-b",
        acceptingAt: timestampFromMillis(fixedNowMillis),
      },
      sessionId: "session-ab",
      responderId: "student-b",
      responderSearchRequestData: freshBackgroundRequest,
      nowMillis: fixedNowMillis,
    }),
    {shouldNotify: false, reason: "accept_in_progress"},
  );
  assert.deepEqual(
    shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData: {
        ...pendingSessionData,
        responseExpiresAt: timestampFromMillis(fixedNowMillis),
        confirmationExpiresAt: timestampFromMillis(fixedNowMillis),
      },
      sessionId: "session-ab",
      responderId: "student-b",
      responderSearchRequestData: freshBackgroundRequest,
      nowMillis: fixedNowMillis,
    }),
    {shouldNotify: false, reason: "response_window_closed"},
  );
  assert.deepEqual(
    shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData: pendingSessionData,
      sessionId: "session-ab",
      responderId: "student-b",
      responderSearchRequestData: {
        ...freshBackgroundRequest,
        userId: "student-c",
      },
      nowMillis: fixedNowMillis,
    }),
    {shouldNotify: false, reason: "search_request_owner_mismatch"},
  );
  assert.deepEqual(
    shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData: pendingSessionData,
      sessionId: "session-ab",
      responderId: "student-b",
      responderSearchRequestData: {
        ...freshBackgroundRequest,
        currentSessionId: "session-other",
      },
      nowMillis: fixedNowMillis,
    }),
    {shouldNotify: false, reason: "search_request_session_mismatch"},
  );
  assert.deepEqual(
    shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData: pendingSessionData,
      sessionId: "session-ab",
      responderId: "student-b",
      responderSearchRequestData: {
        status: SEARCH_REQUEST_STATUS.ACTIVE,
        appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
        backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 60_000),
        currentSessionId: "session-ab",
      },
      nowMillis: fixedNowMillis,
    }),
    {shouldNotify: false, reason: "responder_not_background"},
  );
  assert.deepEqual(
    shouldCreateBackgroundStudentResponderIncomingCall({
      sessionData: pendingSessionData,
      sessionId: "session-ab",
      responderId: "student-b",
      responderSearchRequestData: {
        status: SEARCH_REQUEST_STATUS.MATCHED,
        userId: "student-b",
        appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
        backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 60_000),
      },
      nowMillis: fixedNowMillis,
    }),
    {shouldNotify: false, reason: "search_request_session_mismatch"},
  );
});

function fakeStoreDb(store, hooks = {}) {
  return {
    collection: (collectionName) => ({
      doc: (docId) => ({
        path: `${collectionName}/${docId}`,
        id: docId,
        get: async () => ({
          exists: store.has(`${collectionName}/${docId}`),
          data: () => store.get(`${collectionName}/${docId}`),
        }),
      }),
    }),
    runTransaction: async (callback) => callback({
      get: async (ref) => ({
        exists: store.has(ref.path),
        data: () => store.get(ref.path),
      }),
      set: (ref, data) => {
        store.set(ref.path, data);
        hooks.onSet?.(ref, data, store);
      },
      update: (ref, update) => {
        store.set(ref.path, {
          ...store.get(ref.path),
          ...update,
        });
        hooks.onUpdate?.(ref, update, store);
      },
    }),
  };
}

test("teacher responder incoming call creates notification and push", async () => {
  const teacherNowMillis = Date.now();
  const pendingSessionData = {
    sessionId: "session-at",
    status: "pending_confirmation",
    language: "en",
    studentId: "student-a",
    studentInfo: {name: "Ana", photo: "photo"},
    currentResponderId: "teacher-a",
    currentTutorId: "teacher-a",
    currentResponderRole: "native_speaker",
    responderRole: "native_speaker",
    scenario: "student_teacher",
    participantRoles: {
      "student-a": "student",
      "teacher-a": "native_speaker",
    },
    responseExpiresAt: timestampFromMillis(teacherNowMillis + 45_000),
    confirmationExpiresAt: timestampFromMillis(teacherNowMillis + 45_000),
  };
  const teacherData = {
    role: "native_speaker",
    language_instruction_NS: {code: "en"},
    verif_NS: true,
    isAvailable: true,
    currentSessionId: "session-at",
  };
  const tokenState = {
    hasUsableToken: true,
    hasFcmToken: false,
    hasVoipPushToken: true,
  };

  assert.equal(
    isTeacherResponderSession(pendingSessionData, "teacher-a"),
    true,
  );
  assert.deepEqual(
    shouldCreateTeacherResponderIncomingCall({
      sessionData: pendingSessionData,
      responderId: "teacher-a",
      nowMillis: teacherNowMillis,
    }),
    {shouldNotify: true, reason: "teacher_responder"},
  );
  assert.deepEqual(
    shouldUseTeacherResponderForIncomingCall({
      teacherData,
      responderId: "teacher-a",
      sessionId: "session-at",
      sessionData: pendingSessionData,
      tokenState,
      now: new Date(teacherNowMillis),
    }),
    {valid: true, reason: "teacher_current"},
  );
  assert.deepEqual(
    shouldUseTeacherResponderForIncomingCall({
      teacherData: {
        ...teacherData,
        currentSessionId: "",
      },
      responderId: "teacher-a",
      sessionId: "session-at",
      sessionData: pendingSessionData,
      tokenState,
      now: new Date(teacherNowMillis),
    }),
    {valid: false, reason: "teacher_session_mismatch"},
  );
  assert.deepEqual(
    shouldCreateTeacherResponderIncomingCall({
      sessionData: {
        ...pendingSessionData,
        currentTutorId: "teacher-b",
      },
      responderId: "teacher-a",
      nowMillis: teacherNowMillis,
    }),
    {shouldNotify: false, reason: "responder_mismatch"},
  );
  assert.deepEqual(
    shouldCreateTeacherResponderIncomingCall({
      sessionData: {
        ...pendingSessionData,
        scenario: "student_student",
      },
      responderId: "teacher-a",
      nowMillis: teacherNowMillis,
    }),
    {shouldNotify: false, reason: "responder_not_teacher"},
  );
  assert.deepEqual(
    shouldCreateTeacherResponderIncomingCall({
      sessionData: {
        ...pendingSessionData,
        acceptingTutorId: "teacher-a",
        acceptingAt: timestampFromMillis(teacherNowMillis),
      },
      responderId: "teacher-a",
      nowMillis: teacherNowMillis,
    }),
    {shouldNotify: false, reason: "accept_in_progress"},
  );

  const store = new Map([
    ["videoSessions/session-at", pendingSessionData],
    ["users/teacher-a", teacherData],
    ["userPrivateTokens/teacher-a", {voipPushToken: "push-token"}],
  ]);
  const fakeDb = fakeStoreDb(store);
  let pushSendCount = 0;
  const result = await maybeNotifyTeacherResponder({
    db: fakeDb,
    sessionId: "session-at",
    responderId: "teacher-a",
    requesterData: {
      display_name: "Ana",
      photo_url: "photo",
    },
    nowMillis: teacherNowMillis,
    tokenReader: async () => tokenState,
    pushSender: async (responderId, callData) => {
      pushSendCount += 1;
      assert.equal(responderId, "teacher-a");
      assert.equal(callData.sessionId, "session-at");
      assert.equal(callData.callerName, "Ana");
      assert.equal(callData.callerId, "student-a");
      assert.equal(callData.callerPhoto, "photo");
      assert.equal(callData.language, "en");
      assert.equal(callData.scenario, "student_teacher");
      assert.equal(callData.requesterId, "student-a");
      assert.equal(callData.responderId, "teacher-a");
      assert.equal(callData.requesterRole, "student");
      assert.equal(callData.responderRole, "native_speaker");
      assert.equal(callData.navRole, "tutor");
      assert.equal(callData.acceptMode, "responder_accepts");
      assert.equal(
        callData.callKitId,
        buildCallKitIdForSession("session-at"),
      );
      assert.equal(callData.notificationId, "session-at_teacher-a");
      assert.equal(callData.searchRequestId, "");
      assert.ok(callData.expiresAt);
      assert.equal(callData.roomUrl, "");
      assert.equal(callData.roomName, "");
      assert.equal(callData.tokenStrategy, "accept_call");
      assert.equal(Object.hasOwn(callData, "meetingToken"), false);
      return {sent: true, channel: "apns_voip"};
    },
  });
  const notification =
    store.get("notifications/session-at_teacher-a");

  assert.equal(result.shouldNotify, true);
  assert.deepEqual(result.pushResult, {
    sent: true,
    channel: "apns_voip",
  });
  assert.equal(pushSendCount, 1);
  assert.equal(notification.type, "incoming_call");
  assert.equal(notification.status, "sent");
  assert.equal(notification.recipientId, "teacher-a");
  assert.equal(notification.sessionId, "session-at");
  assert.equal(notification.studentInfo.name, "Ana");
  assert.equal(notification.pushChannel, "apns_voip");
});

test("teacher responder incoming call cancels stale state before push", async () => {
  const nowMillis = Date.now();
  const pendingSessionData = {
    sessionId: "session-at",
    status: "pending_confirmation",
    language: "en",
    studentId: "student-a",
    studentInfo: {name: "Ana", photo: "photo"},
    currentResponderId: "teacher-a",
    currentTutorId: "teacher-a",
    currentResponderRole: "native_speaker",
    responderRole: "native_speaker",
    scenario: "student_teacher",
    participantRoles: {
      "student-a": "student",
      "teacher-a": "native_speaker",
    },
    responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
    confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
  };
  const teacherData = {
    role: "native_speaker",
    language_instruction_NS: {code: "en"},
    verif_NS: true,
    isAvailable: true,
    currentSessionId: "session-at",
  };
  const store = new Map([
    ["videoSessions/session-at", pendingSessionData],
    ["users/teacher-a", teacherData],
    ["userPrivateTokens/teacher-a", {voipPushToken: "push-token"}],
  ]);
  const fakeDb = fakeStoreDb(store, {
    onSet: (ref) => {
      if (ref.path === "notifications/session-at_teacher-a") {
        store.set("videoSessions/session-at", {
          ...pendingSessionData,
          responseExpiresAt: timestampFromMillis(Date.now() - 1),
          confirmationExpiresAt: timestampFromMillis(Date.now() - 1),
        });
      }
    },
  });
  let pushSendCount = 0;
  const result = await maybeNotifyTeacherResponder({
    db: fakeDb,
    sessionId: "session-at",
    responderId: "teacher-a",
    requesterData: {display_name: "Ana"},
    nowMillis,
    tokenReader: async () => ({
      hasUsableToken: true,
      hasFcmToken: false,
      hasVoipPushToken: true,
    }),
    pushSender: async () => {
      pushSendCount += 1;
      return {sent: true, channel: "apns_voip"};
    },
  });
  const notification =
    store.get("notifications/session-at_teacher-a");

  assert.equal(result.shouldNotify, false);
  assert.equal(result.reason, "stale_before_push");
  assert.equal(result.staleReason, "response_window_closed");
  assert.equal(pushSendCount, 0);
  assert.equal(notification.status, "cancelled");
  assert.equal(notification.cancelReason, "stale_before_push");
  assert.equal(notification.staleReason, "response_window_closed");
});

test("teacher responder incoming call records push failure metadata", async () => {
  const nowMillis = Date.now();
  const pendingSessionData = {
    sessionId: "session-at",
    status: "pending_confirmation",
    language: "en",
    studentId: "student-a",
    studentInfo: {name: "Ana", photo: "photo"},
    currentResponderId: "teacher-a",
    currentTutorId: "teacher-a",
    currentResponderRole: "native_speaker",
    responderRole: "native_speaker",
    scenario: "student_teacher",
    participantRoles: {
      "student-a": "student",
      "teacher-a": "native_speaker",
    },
    responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
    confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
  };
  const teacherData = {
    role: "native_speaker",
    language_instruction_NS: {code: "en"},
    verif_NS: true,
    isAvailable: true,
    currentSessionId: "session-at",
  };
  const store = new Map([
    ["videoSessions/session-at", pendingSessionData],
    ["users/teacher-a", teacherData],
    ["userPrivateTokens/teacher-a", {voipPushToken: "push-token"}],
  ]);
  const result = await maybeNotifyTeacherResponder({
    db: fakeStoreDb(store),
    sessionId: "session-at",
    responderId: "teacher-a",
    requesterData: {display_name: "Ana"},
    nowMillis,
    tokenReader: async () => ({
      hasUsableToken: true,
      hasFcmToken: false,
      hasVoipPushToken: true,
    }),
    pushSender: async () => ({
      sent: false,
      reason: "missing_tokens",
      error: "missing_tokens",
    }),
  });
  const notification =
    store.get("notifications/session-at_teacher-a");

  assert.equal(result.shouldNotify, true);
  assert.deepEqual(result.pushResult, {
    sent: false,
    reason: "missing_tokens",
    error: "missing_tokens",
  });
  assert.equal(notification.status, "sent");
  assert.equal(notification.lastPushError, "missing_tokens");
  assert.ok(notification.lastPushFailedAt);
});

test("teacher responder finalization failure keeps notification id for retry", async () => {
  const nowMillis = Date.now();
  const pendingSessionData = {
    sessionId: "session-at",
    status: "pending_confirmation",
    language: "en",
    studentId: "student-a",
    studentInfo: {name: "Ana", photo: "photo"},
    currentResponderId: "teacher-a",
    currentTutorId: "teacher-a",
    currentResponderRole: "native_speaker",
    responderRole: "native_speaker",
    scenario: "student_teacher",
    participantRoles: {
      "student-a": "student",
      "teacher-a": "native_speaker",
    },
    responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
    confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
  };
  const store = new Map([
    ["videoSessions/session-at", pendingSessionData],
    ["users/teacher-a", {
      role: "native_speaker",
      language_instruction_NS: {code: "en"},
      verif_NS: true,
      isAvailable: true,
      currentSessionId: "session-at",
    }],
    ["userPrivateTokens/teacher-a", {voipPushToken: "push-token"}],
  ]);
  const fakeDb = fakeStoreDb(store, {
    onUpdate: (ref, update) => {
      if (ref.path === "notifications/session-at_teacher-a" &&
          update.pushSentAt) {
        throw new Error("finalization_down");
      }
    },
  });
  let pushSendCount = 0;

  const originalConsoleError = console.error;
  let result;
  try {
    console.error = () => {};
    result = await maybeNotifyTeacherResponder({
      db: fakeDb,
      sessionId: "session-at",
      responderId: "teacher-a",
      requesterData: {display_name: "Ana"},
      nowMillis,
      tokenReader: async () => ({
        hasUsableToken: true,
        hasFcmToken: false,
        hasVoipPushToken: true,
      }),
      pushSender: async () => {
        pushSendCount += 1;
        return {sent: true, channel: "apns_voip"};
      },
    });
  } finally {
    console.error = originalConsoleError;
  }

  assert.equal(pushSendCount, 1);
  assert.equal(result.shouldNotify, false);
  assert.equal(result.reason, "push_finalization_failed");
  assert.equal(result.staleReason, "finalization_down");
  assert.equal(result.notificationId, "session-at_teacher-a");
  assert.deepEqual(result.pushResult, {
    sent: true,
    channel: "apns_voip",
  });
  assert.equal(shouldRetryTeacherMatchAfterNotifyResult(result), true);
});

test("teacher responder incoming call cancels stale state after push", async () => {
  const nowMillis = Date.now();
  const pendingSessionData = {
    sessionId: "session-at",
    status: "pending_confirmation",
    language: "en",
    studentId: "student-a",
    studentInfo: {name: "Ana", photo: "photo"},
    currentResponderId: "teacher-a",
    currentTutorId: "teacher-a",
    currentResponderRole: "native_speaker",
    responderRole: "native_speaker",
    scenario: "student_teacher",
    participantRoles: {
      "student-a": "student",
      "teacher-a": "native_speaker",
    },
    responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
    confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
  };
  const teacherData = {
    role: "native_speaker",
    language_instruction_NS: {code: "en"},
    verif_NS: true,
    isAvailable: true,
    currentSessionId: "session-at",
  };
  const store = new Map([
    ["videoSessions/session-at", pendingSessionData],
    ["users/teacher-a", teacherData],
  ]);
  const result = await maybeNotifyTeacherResponder({
    db: fakeStoreDb(store),
    sessionId: "session-at",
    responderId: "teacher-a",
    requesterData: {display_name: "Ana"},
    nowMillis,
    tokenReader: async () => ({
      hasUsableToken: true,
      hasFcmToken: false,
      hasVoipPushToken: true,
    }),
    pushSender: async () => {
      store.set("videoSessions/session-at", {
        ...pendingSessionData,
        responseExpiresAt: timestampFromMillis(Date.now() - 1),
        confirmationExpiresAt: timestampFromMillis(Date.now() - 1),
      });
      return {sent: true, channel: "apns_voip"};
    },
  });
  const notification =
    store.get("notifications/session-at_teacher-a");

  assert.equal(result.shouldNotify, false);
  assert.equal(result.reason, "stale_after_push");
  assert.equal(result.staleReason, "response_window_closed");
  assert.equal(shouldRetryTeacherMatchAfterNotifyResult(result), true);
  assert.equal(notification.status, "cancelled");
  assert.equal(notification.cancelReason, "stale_after_push");
  assert.equal(notification.pushChannel, "apns_voip");
});

test("teacher responder push finalization cancels when token disappears", async () => {
  const nowMillis = Date.now();
  const pendingSessionData = {
    sessionId: "session-at",
    status: "pending_confirmation",
    language: "en",
    studentId: "student-a",
    currentResponderId: "teacher-a",
    currentTutorId: "teacher-a",
    currentResponderRole: "native_speaker",
    responderRole: "native_speaker",
    scenario: "student_teacher",
    participantRoles: {
      "student-a": "student",
      "teacher-a": "native_speaker",
    },
    responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
    confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
  };
  const store = new Map([
    ["videoSessions/session-at", pendingSessionData],
    ["users/teacher-a", {
      role: "native_speaker",
      language_instruction_NS: {code: "en"},
      verif_NS: true,
      isAvailable: true,
      currentSessionId: "session-at",
    }],
    ["notifications/session-at_teacher-a", {
      status: "sent",
      type: "incoming_call",
      sessionId: "session-at",
      recipientId: "teacher-a",
    }],
  ]);

  const result = await recordTeacherResponderPushResult({
    db: fakeStoreDb(store),
    notificationId: "session-at_teacher-a",
    sessionId: "session-at",
    responderId: "teacher-a",
    pushResult: {sent: true, channel: "apns_voip"},
    nowMillis,
  });
  const notification =
    store.get("notifications/session-at_teacher-a");

  assert.equal(result.stillCurrent, false);
  assert.equal(result.reason, "stale_after_push");
  assert.equal(result.staleReason, "teacher_missing_tokens");
  assert.equal(notification.status, "cancelled");
  assert.equal(notification.cancelReason, "stale_after_push");
  assert.equal(notification.staleReason, "teacher_missing_tokens");
  assert.equal(notification.pushChannel, "apns_voip");
});

test("teacher responder push finalization preserves accept race", async () => {
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-at", {
      sessionId: "session-at",
      status: "pending_confirmation",
      language: "en",
      studentId: "student-a",
      currentResponderId: "teacher-a",
      currentTutorId: "teacher-a",
      currentResponderRole: "native_speaker",
      responderRole: "native_speaker",
      scenario: "student_teacher",
      participantRoles: {
        "student-a": "student",
        "teacher-a": "native_speaker",
      },
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
      acceptingTutorId: "teacher-a",
      acceptingAt: timestampFromMillis(nowMillis),
    }],
    ["users/teacher-a", {
      role: "native_speaker",
      language_instruction_NS: {code: "en"},
      verif_NS: true,
      isAvailable: true,
      currentSessionId: "session-at",
    }],
    ["userPrivateTokens/teacher-a", {voipPushToken: "push-token"}],
    ["notifications/session-at_teacher-a", {
      status: "sent",
      type: "incoming_call",
      sessionId: "session-at",
      recipientId: "teacher-a",
    }],
  ]);

  const result = await recordTeacherResponderPushResult({
    db: fakeStoreDb(store),
    notificationId: "session-at_teacher-a",
    sessionId: "session-at",
    responderId: "teacher-a",
    pushResult: {sent: true, channel: "apns_voip"},
    nowMillis,
  });

  assert.equal(result.stillCurrent, false);
  assert.equal(result.reason, "accept_finalization_in_progress");
  assert.equal(result.staleReason, "accept_in_progress");
  assert.equal(store.get("notifications/session-at_teacher-a").status, "sent");
});

test("teacher responder notification failure releases match for retry", async () => {
  const nowMillis = Date.now();
  const pendingSessionData = {
    sessionId: "session-at",
    status: "pending_confirmation",
    pairStatus: "pending_confirmation",
    language: "en",
    requesterId: "student-a",
    responderId: "teacher-a",
    studentId: "student-a",
    currentResponderId: "teacher-a",
    currentTutorId: "teacher-a",
    currentResponderRole: "native_speaker",
    responderRole: "native_speaker",
    scenario: "student_teacher",
    pairAttemptId: "pair-at",
    participantIds: ["student-a", "teacher-a"],
    participantRoles: {
      "student-a": "student",
      "teacher-a": "native_speaker",
    },
    searchRequestIds: {
      requester: "request-a",
      responder: null,
    },
    responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
    confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
  };
  const store = new Map([
    ["videoSessions/session-at", pendingSessionData],
    ["users/student-a", {
      role: "student",
      currentSessionId: "session-at",
    }],
    ["users/teacher-a", {
      role: "native_speaker",
      currentSessionId: "session-at",
    }],
    ["searchRequests/student-a", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      requestId: "request-a",
      userId: "student-a",
      currentSessionId: "session-at",
      matchedSessionId: "session-at",
      matchedUserId: "teacher-a",
      matchedResponderId: "teacher-a",
      matchedRole: "native_speaker",
      pairAttemptId: "pair-at",
      excludedCandidateIds: ["teacher-old"],
      attemptExcludedCandidateIds: ["teacher-a"],
      lockOwner: "pair-at",
      lockExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["notifications/session-at_teacher-a", {
      status: "sent",
      type: "incoming_call",
      sessionId: "session-at",
      recipientId: "teacher-a",
    }],
  ]);

  assert.equal(
    shouldRetryTeacherMatchAfterNotifyResult({
      shouldNotify: true,
      pushResult: {sent: false, reason: "missing_tokens"},
    }),
    true,
  );
  assert.equal(
    shouldRetryTeacherMatchAfterNotifyResult({
      shouldNotify: false,
      reason: "responder_mismatch",
    }),
    true,
  );
  assert.equal(
    shouldRetryTeacherMatchAfterNotifyResult({
      shouldNotify: true,
      pushResult: {sent: true, channel: "apns_voip"},
    }),
    false,
  );
  assert.equal(
    shouldRetryTeacherMatchAfterNotifyResult({
      shouldNotify: false,
      reason: "accept_finalization_in_progress",
    }),
    false,
  );

  const result = await releaseTeacherResponderMatchForRetry({
    db: fakeStoreDb(store),
    sessionId: "session-at",
    responderId: "teacher-a",
    requesterId: "student-a",
    notificationId: "session-at_teacher-a",
    pairAttemptId: "pair-at",
    stopReason: "teacher_push_failed",
  });
  const requestData = store.get("searchRequests/student-a");
  const notification = store.get("notifications/session-at_teacher-a");
  const sessionData = store.get("videoSessions/session-at");

  assert.equal(result.released, true);
  assert.equal(requestData.status, SEARCH_REQUEST_STATUS.ACTIVE);
  assert.equal(requestData.currentSessionId, null);
  assert.equal(requestData.matchedUserId, null);
  assert.notEqual(
    store.get("users/student-a").currentSessionId,
    "session-at",
  );
  assert.notEqual(
    store.get("users/teacher-a").currentSessionId,
    "session-at",
  );
  assert.deepEqual(
    requestData.excludedCandidateIds.slice().sort(),
    ["teacher-a", "teacher-old"],
  );
  assert.deepEqual(requestData.attemptExcludedCandidateIds, []);
  assert.equal(notification.status, "cancelled");
  assert.equal(notification.cancelReason, "teacher_push_failed");
  assert.equal(sessionData.status, "cancelled");
  assert.equal(sessionData.cancelReason, "teacher_push_failed");
});

test("teacher responder retry release preserves accept race", async () => {
  const nowMillis = Date.now();
  const pendingSessionData = {
    sessionId: "session-at",
    status: "pending_confirmation",
    language: "en",
    requesterId: "student-a",
    responderId: "teacher-a",
    studentId: "student-a",
    currentResponderId: "teacher-a",
    currentTutorId: "teacher-a",
    currentResponderRole: "native_speaker",
    responderRole: "native_speaker",
    scenario: "student_teacher",
    pairAttemptId: "pair-at",
    participantIds: ["student-a", "teacher-a"],
    participantRoles: {
      "student-a": "student",
      "teacher-a": "native_speaker",
    },
    responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
    confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    acceptingTutorId: "teacher-a",
    acceptingAt: timestampFromMillis(nowMillis),
  };
  const store = new Map([
    ["videoSessions/session-at", pendingSessionData],
    ["users/student-a", {
      role: "student",
      currentSessionId: "session-at",
    }],
    ["users/teacher-a", {
      role: "native_speaker",
      currentSessionId: "session-at",
    }],
    ["searchRequests/student-a", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      requestId: "request-a",
      userId: "student-a",
      currentSessionId: "session-at",
      matchedSessionId: "session-at",
    }],
    ["notifications/session-at_teacher-a", {
      status: "sent",
      type: "incoming_call",
      sessionId: "session-at",
      recipientId: "teacher-a",
    }],
  ]);

  const result = await releaseTeacherResponderMatchForRetry({
    db: fakeStoreDb(store),
    sessionId: "session-at",
    responderId: "teacher-a",
    requesterId: "student-a",
    notificationId: "session-at_teacher-a",
    pairAttemptId: "pair-at",
    stopReason: "teacher_push_failed",
  });

  assert.equal(result.released, false);
  assert.equal(result.reason, "accept_finalization_in_progress");
  assert.equal(store.get("notifications/session-at_teacher-a").status, "sent");
  assert.equal(
    store.get("searchRequests/student-a").status,
    SEARCH_REQUEST_STATUS.MATCHED,
  );
});

test("teacher responder retry release requires pair attempt and unified responder", async () => {
  const nowMillis = Date.now();
  const baseSessionData = {
    sessionId: "session-at",
    status: "pending_confirmation",
    language: "en",
    requesterId: "student-a",
    responderId: "teacher-a",
    studentId: "student-a",
    currentResponderId: "teacher-a",
    currentTutorId: "teacher-a",
    currentResponderRole: "native_speaker",
    responderRole: "native_speaker",
    scenario: "student_teacher",
    pairAttemptId: "pair-at",
    participantIds: ["student-a", "teacher-a"],
    participantRoles: {
      "student-a": "student",
      "teacher-a": "native_speaker",
    },
    responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
    confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
  };
  const buildStore = (sessionData = baseSessionData) => new Map([
    ["videoSessions/session-at", sessionData],
    ["users/student-a", {
      role: "student",
      currentSessionId: "session-at",
    }],
    ["users/teacher-a", {
      role: "native_speaker",
      currentSessionId: "session-at",
    }],
    ["searchRequests/student-a", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      requestId: "request-a",
      userId: "student-a",
      currentSessionId: "session-at",
      matchedSessionId: "session-at",
    }],
  ]);

  const missingPairResult = await releaseTeacherResponderMatchForRetry({
    db: fakeStoreDb(buildStore()),
    sessionId: "session-at",
    responderId: "teacher-a",
    requesterId: "student-a",
    stopReason: "teacher_push_failed",
  });
  const splitStore = buildStore({
    ...baseSessionData,
    currentTutorId: "teacher-b",
  });
  const splitResult = await releaseTeacherResponderMatchForRetry({
    db: fakeStoreDb(splitStore),
    sessionId: "session-at",
    responderId: "teacher-a",
    requesterId: "student-a",
    pairAttemptId: "pair-at",
    stopReason: "teacher_push_failed",
  });

  assert.equal(missingPairResult.released, false);
  assert.equal(missingPairResult.reason, "missing_pair_attempt");
  assert.equal(splitResult.released, false);
  assert.equal(splitResult.reason, "responder_mismatch");
  assert.equal(
    splitStore.get("videoSessions/session-at").currentTutorId,
    "teacher-b",
  );
  assert.equal(
    splitStore.get("searchRequests/student-a").status,
    SEARCH_REQUEST_STATUS.MATCHED,
  );
});

test("teacher responder retry release preserves mismatched session", async () => {
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-at", {
      sessionId: "session-at",
      status: "pending_confirmation",
      language: "en",
      requesterId: "student-a",
      responderId: "teacher-a",
      studentId: "student-a",
      currentResponderId: "teacher-b",
      currentTutorId: "teacher-b",
      currentResponderRole: "native_speaker",
      responderRole: "native_speaker",
      scenario: "student_teacher",
      pairAttemptId: "pair-other",
      participantIds: ["student-a", "teacher-b"],
      participantRoles: {
        "student-a": "student",
        "teacher-b": "native_speaker",
      },
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["users/student-a", {
      role: "student",
      currentSessionId: "session-at",
    }],
    ["users/teacher-a", {
      role: "native_speaker",
      currentSessionId: "",
    }],
    ["searchRequests/student-a", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      requestId: "request-a",
      userId: "student-a",
      currentSessionId: "session-at",
      matchedSessionId: "session-at",
    }],
    ["notifications/session-at_teacher-a", {
      status: "sent",
      type: "incoming_call",
      sessionId: "session-at",
      recipientId: "teacher-a",
    }],
  ]);

  const result = await releaseTeacherResponderMatchForRetry({
    db: fakeStoreDb(store),
    sessionId: "session-at",
    responderId: "teacher-a",
    requesterId: "student-a",
    notificationId: "session-at_teacher-a",
    pairAttemptId: "pair-at",
    stopReason: "teacher_push_failed",
  });

  assert.equal(result.released, false);
  assert.equal(result.reason, "pair_attempt_mismatch");
  assert.equal(
    store.get("videoSessions/session-at").currentResponderId,
    "teacher-b",
  );
  assert.equal(
    store.get("searchRequests/student-a").status,
    SEARCH_REQUEST_STATUS.MATCHED,
  );
  assert.equal(store.get("notifications/session-at_teacher-a").status, "sent");
});

test("background student retry decision follows notification outcome", () => {
  assert.equal(shouldRetryBackgroundStudentMatchAfterNotifyResult(null), true);
  assert.equal(
    shouldRetryBackgroundStudentMatchAfterNotifyResult({
      reason: "accept_finalization_in_progress",
    }),
    false,
  );
  assert.equal(
    shouldRetryBackgroundStudentMatchAfterNotifyResult({
      shouldNotify: false,
      reason: "accept_in_progress",
    }),
    false,
  );
  assert.equal(
    shouldRetryBackgroundStudentMatchAfterNotifyResult({
      shouldNotify: false,
      reason: "responder_not_background",
    }),
    false,
  );
  assert.equal(
    shouldRetryBackgroundStudentMatchAfterNotifyResult({
      shouldNotify: false,
      reason: "stale_before_push",
      staleReason: "responder_not_background",
    }),
    false,
  );
  assert.equal(
    shouldRetryBackgroundStudentMatchAfterNotifyResult({
      shouldNotify: false,
      reason: "stale_after_push",
      staleReason: "responder_not_background",
      pushResult: {sent: false, reason: "fcm_failed"},
    }),
    false,
  );
  assert.equal(
    shouldRetryBackgroundStudentMatchAfterNotifyResult({
      shouldNotify: false,
      reason: "stale_before_push",
    }),
    true,
  );
  assert.equal(
    shouldRetryBackgroundStudentMatchAfterNotifyResult({
      shouldNotify: true,
      pushResult: {sent: false, reason: "missing_tokens"},
    }),
    true,
  );
  assert.equal(
    shouldRetryBackgroundStudentMatchAfterNotifyResult({
      shouldNotify: true,
      pushResult: {sent: true, channel: "apns_voip"},
    }),
    false,
  );
});

test("background student notification failure releases match for retry", async () => {
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      sessionId: "session-ab",
      status: "pending_confirmation",
      language: "en",
      requesterId: "student-a",
      responderId: "student-b",
      studentId: "student-a",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      pairAttemptId: "pair-ab",
      participantIds: ["student-a", "student-b"],
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["users/student-a", {
      role: "student",
      currentSessionId: "session-ab",
    }],
    ["users/student-b", {
      role: "student",
      currentSessionId: "session-ab",
    }],
    ["searchRequests/student-a", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      requestId: "request-a",
      userId: "student-a",
      currentSessionId: "session-ab",
      matchedSessionId: "session-ab",
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      requestId: "request-b",
      userId: "student-b",
      currentSessionId: "session-ab",
      matchedSessionId: "session-ab",
    }],
    ["notifications/session-ab_student-b", {
      status: "sent",
      type: "incoming_call",
      sessionId: "session-ab",
      recipientId: "student-b",
      lastPushError: "missing_tokens",
    }],
  ]);

  const result = await releaseBackgroundStudentResponderMatchForRetry({
    db: fakeStoreDb(store),
    sessionId: "session-ab",
    responderId: "student-b",
    requesterId: "student-a",
    notificationId: "session-ab_student-b",
    pairAttemptId: "pair-ab",
    stopReason: "background_student_push_failed",
  });

  assert.deepEqual(result, {released: true, reason: "released"});
  assert.equal(store.get("videoSessions/session-ab").status, "cancelled");
  assert.equal(
    store.get("videoSessions/session-ab").cancelReason,
    "background_student_push_failed",
  );
  assert.equal(store.get("searchRequests/student-a").status, "active");
  assert.deepEqual(
    store.get("searchRequests/student-a").excludedCandidateIds,
    ["student-b"],
  );
  assert.equal(store.get("searchRequests/student-b").status, "cancelled");
  assert.equal(store.get("notifications/session-ab_student-b").status, "cancelled");
  assert.equal(
    store.get("notifications/session-ab_student-b").cancelReason,
    "background_student_push_failed",
  );
});

test("background student retry release preserves accept race", async () => {
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      sessionId: "session-ab",
      status: "pending_confirmation",
      language: "en",
      requesterId: "student-a",
      responderId: "student-b",
      studentId: "student-a",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      pairAttemptId: "pair-ab",
      participantIds: ["student-a", "student-b"],
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
      acceptingTutorId: "student-b",
      acceptingAt: timestampFromMillis(nowMillis),
    }],
    ["users/student-a", {
      role: "student",
      currentSessionId: "session-ab",
    }],
    ["users/student-b", {
      role: "student",
      currentSessionId: "session-ab",
    }],
    ["searchRequests/student-a", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      requestId: "request-a",
      userId: "student-a",
      currentSessionId: "session-ab",
      matchedSessionId: "session-ab",
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      requestId: "request-b",
      userId: "student-b",
      currentSessionId: "session-ab",
      matchedSessionId: "session-ab",
    }],
    ["notifications/session-ab_student-b", {
      status: "sent",
      type: "incoming_call",
      sessionId: "session-ab",
      recipientId: "student-b",
    }],
  ]);

  const result = await releaseBackgroundStudentResponderMatchForRetry({
    db: fakeStoreDb(store),
    sessionId: "session-ab",
    responderId: "student-b",
    requesterId: "student-a",
    notificationId: "session-ab_student-b",
    pairAttemptId: "pair-ab",
    stopReason: "background_student_push_failed",
  });

  assert.equal(result.released, false);
  assert.equal(result.reason, "accept_finalization_in_progress");
  assert.equal(store.get("notifications/session-ab_student-b").status, "sent");
  assert.equal(
    store.get("searchRequests/student-a").status,
    SEARCH_REQUEST_STATUS.MATCHED,
  );
  assert.equal(
    store.get("videoSessions/session-ab").acceptingTutorId,
    "student-b",
  );
});

test("background student retry release preserves mismatched session", async () => {
  const store = new Map([
    ["videoSessions/session-ab", {
      sessionId: "session-ab",
      status: "pending_confirmation",
      requesterId: "student-a",
      responderId: "student-c",
      studentId: "student-a",
      currentResponderId: "student-c",
      currentTutorId: "student-c",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      pairAttemptId: "pair-other",
      participantIds: ["student-a", "student-c"],
      participantRoles: {
        "student-a": "student",
        "student-c": "student",
      },
    }],
    ["notifications/session-ab_student-b", {
      status: "sent",
      type: "incoming_call",
      sessionId: "session-ab",
      recipientId: "student-b",
    }],
  ]);

  const result = await releaseBackgroundStudentResponderMatchForRetry({
    db: fakeStoreDb(store),
    sessionId: "session-ab",
    responderId: "student-b",
    requesterId: "student-a",
    notificationId: "session-ab_student-b",
    pairAttemptId: "pair-ab",
    stopReason: "background_student_push_failed",
  });

  assert.equal(result.released, false);
  assert.equal(result.reason, "pair_attempt_mismatch");
  assert.equal(
    store.get("videoSessions/session-ab").currentResponderId,
    "student-c",
  );
  assert.equal(store.get("notifications/session-ab_student-b").status, "sent");
});

test("student pair responder call data omits room credentials", () => {
  assert.deepEqual(
    buildStudentPairRequesterInfo({
      displayName: "Ana",
      photoUrl: "photo-url",
    }),
    {
      name: "Ana",
      photo: "photo-url",
    },
  );

  const callData = buildStudentPairResponderCallData({
    sessionId: " session-ab ",
    pushPayload: {
      studentName: " Ana ",
      studentId: " student-a ",
      studentPhoto: " photo ",
      language: " en ",
      scenario: " student_student ",
      requesterId: " student-a ",
      responderId: " student-b ",
      requesterRole: " student ",
      responderRole: " student ",
      navRole: " student ",
      acceptMode: " responder_accepts ",
      callKitId: " callkit-id ",
      notificationId: " notification-id ",
      searchRequestId: " search-request-id ",
      expiresAt: " 2026-06-21T10:00:45.000Z ",
      roomUrl: "https://daily.example/room",
      roomName: " room-a ",
      tokenStrategy: " accept_call ",
      meetingToken: "token",
    },
  });

  assert.deepEqual(callData, {
    sessionId: "session-ab",
    callerName: "Ana",
    callerId: "student-a",
    callerPhoto: "photo",
    language: "en",
    scenario: "student_student",
    recipientId: "student-b",
    requesterId: "student-a",
    responderId: "student-b",
    requesterRole: "student",
    responderRole: "student",
    navRole: "student",
    acceptMode: "responder_accepts",
    callKitId: "callkit-id",
    notificationId: "notification-id",
    searchRequestId: "search-request-id",
    expiresAt: "2026-06-21T10:00:45.000Z",
    roomUrl: "",
    roomName: "room-a",
    tokenStrategy: "accept_call",
  });
  assert.equal(Object.hasOwn(callData, "meetingToken"), false);

  const pushPayload = buildStudentPairResponderPushPayload({
    ...callData,
    roomUrl: "https://daily.example/room",
    meetingToken: "token",
  });
  assert.deepEqual(pushPayload, {
    type: "incoming_call",
    sessionId: "session-ab",
    callerName: "Ana",
    callerId: "student-a",
    callerPhoto: "photo",
    language: "en",
    scenario: "student_student",
    recipientId: "student-b",
    requesterId: "student-a",
    responderId: "student-b",
    requesterRole: "student",
    responderRole: "student",
    navRole: "student",
    acceptMode: "responder_accepts",
    callKitId: "callkit-id",
    notificationId: "notification-id",
    searchRequestId: "search-request-id",
    expiresAt: "2026-06-21T10:00:45.000Z",
    roomUrl: "",
    roomName: "room-a",
    tokenStrategy: "accept_call",
  });
  assert.equal(Object.hasOwn(pushPayload, "meetingToken"), false);

  const fcmMessage = buildStudentPairResponderFcmMessage({
    fcmToken: "fcm-token",
    payload: pushPayload,
    bundleId: "com.example.app",
  });
  assert.equal(fcmMessage.token, "fcm-token");
  assert.equal(fcmMessage.android.priority, "high");
  assert.deepEqual(fcmMessage.data, pushPayload);
  assert.equal(fcmMessage.data.roomUrl, "");
  assert.equal(Object.hasOwn(fcmMessage.data, "meetingToken"), false);
});

test("student responder APNS failure is preserved when FCM is missing", async () => {
  let fcmSendCount = 0;
  const result = await sendVoipPushToStudentResponder(
    "student-b",
    {
      sessionId: "session-ab",
      callerName: "Ana",
      callerId: "student-a",
      callerPhoto: "photo",
      language: "en",
    },
    {
      firestore: {
        collection: () => ({
          doc: () => ({
            get: async () => ({
              exists: true,
              data: () => ({displayName: "Waiting Student"}),
            }),
          }),
        }),
      },
      getUserVoipTokens: async () => ({
        voipPushToken: "apns-token",
        voipToken: "",
      }),
      sendApnsVoip: async () => {
        throw new Error("apns unavailable");
      },
      messaging: {
        send: async () => {
          fcmSendCount += 1;
        },
      },
      logger: {
        error: () => {},
      },
    },
  );

  assert.deepEqual(result, {
    sent: false,
    reason: "missing_fcm_token",
    error: "apns unavailable",
  });
  assert.equal(fcmSendCount, 0);
});

test("student responder APNS success skips FCM fallback", async () => {
  let apnsSendCount = 0;
  let fcmSendCount = 0;
  const controller = new AbortController();
  const result = await sendVoipPushToStudentResponder(
    "student-b",
    {
      sessionId: "session-ab",
      callerName: "Ana",
      callerId: "student-a",
      callerPhoto: "photo",
      language: "en",
    },
    {
      firestore: {
        collection: () => ({
          doc: () => ({
            get: async () => ({
              exists: true,
              data: () => ({displayName: "Waiting Student"}),
            }),
          }),
        }),
      },
      getUserVoipTokens: async () => ({
        voipPushToken: "apns-token",
        voipToken: "fcm-token",
      }),
      sendApnsVoip: async ({signal}) => {
        assert.equal(signal?.aborted, false);
        apnsSendCount += 1;
      },
      messaging: {
        send: async () => {
          fcmSendCount += 1;
        },
      },
      logger: {
        error: () => {},
      },
      signal: controller.signal,
    },
  );

  assert.deepEqual(result, {
    sent: true,
    channel: "apns_voip",
  });
  assert.equal(apnsSendCount, 1);
  assert.equal(fcmSendCount, 0);
});

test("student responder falls back to FCM after APNS timeout", async () => {
  let fcmSendCount = 0;
  let apnsAbortReason = "";
  const controller = new AbortController();
  const result = await sendVoipPushToStudentResponder(
    "student-b",
    {
      sessionId: "session-ab",
      callerName: "Ana",
      callerId: "student-a",
      callerPhoto: "photo",
      language: "en",
    },
    {
      firestore: {
        collection: () => ({
          doc: () => ({
            get: async () => ({
              exists: true,
              data: () => ({displayName: "Waiting Student"}),
            }),
          }),
        }),
      },
      getUserVoipTokens: async () => ({
        voipPushToken: "apns-token",
        voipToken: "fcm-token",
      }),
      sendApnsVoip: async ({signal}) => new Promise((resolve, reject) => {
        signal.addEventListener("abort", () => {
          apnsAbortReason = signal.reason?.message || "";
          reject(signal.reason);
        }, {once: true});
      }),
      messaging: {
        send: async (message) => {
          fcmSendCount += 1;
          assert.equal(message.token, "fcm-token");
          assert.equal(message.data.sessionId, "session-ab");
        },
      },
      logger: {
        error: () => {},
      },
      apnsTimeoutMs: 1,
      signal: controller.signal,
    },
  );

  assert.deepEqual(result, {
    sent: true,
    channel: "fcm",
  });
  assert.equal(apnsAbortReason, "apns_voip_timeout");
  assert.equal(controller.signal.aborted, false);
  assert.equal(fcmSendCount, 1);
});

test("student responder falls back to FCM after APNS error response", async () => {
  let fcmSendCount = 0;
  const result = await sendVoipPushToStudentResponder(
    "student-b",
    {
      sessionId: "session-ab",
      callerName: "Ana",
      callerId: "student-a",
      callerPhoto: "photo",
      language: "en",
    },
    {
      firestore: {
        collection: () => ({
          doc: () => ({
            get: async () => ({
              exists: true,
              data: () => ({displayName: "Waiting Student"}),
            }),
          }),
        }),
      },
      getUserVoipTokens: async () => ({
        voipPushToken: "apns-token",
        voipToken: "fcm-token",
      }),
      sendApnsVoip: async () => {
        throw new Error("APNs error 410: {\"reason\":\"Unregistered\"}");
      },
      messaging: {
        send: async (message) => {
          fcmSendCount += 1;
          assert.equal(message.token, "fcm-token");
          assert.equal(message.data.sessionId, "session-ab");
        },
      },
      logger: {
        error: () => {},
      },
    },
  );

  assert.deepEqual(result, {
    sent: true,
    channel: "fcm",
  });
  assert.equal(fcmSendCount, 1);
});

test("student responder push result preserves APNS and FCM failures", async () => {
  const result = await sendVoipPushToStudentResponder(
    "student-b",
    {
      sessionId: "session-ab",
      callerName: "Ana",
      callerId: "student-a",
      callerPhoto: "photo",
      language: "en",
    },
    {
      firestore: {
        collection: () => ({
          doc: () => ({
            get: async () => ({
              exists: true,
              data: () => ({displayName: "Waiting Student"}),
            }),
          }),
        }),
      },
      getUserVoipTokens: async () => ({
        voipPushToken: "apns-token",
        voipToken: "fcm-token",
      }),
      sendApnsVoip: async () => {
        throw new Error("apns unavailable");
      },
      messaging: {
        send: async () => {
          throw new Error("fcm unavailable");
        },
      },
      logger: {
        error: () => {},
      },
    },
  );

  assert.deepEqual(result, {
    sent: false,
    reason: "fcm_failed",
    error: "apns: apns unavailable; fcm: fcm unavailable",
  });
});

test("background responder push sender aborts slow sends", async () => {
  let signalWasAborted = false;
  await assert.rejects(
    () => runBackgroundStudentResponderPushSender({
      pushSender: async (responderId, callData, {signal}) =>
        new Promise((resolve, reject) => {
          signal.addEventListener("abort", () => {
            signalWasAborted = true;
            reject(signal.reason);
          }, {once: true});
        }),
      responderId: "student-b",
      callData: {sessionId: "session-ab"},
      timeoutMs: 1,
    }),
    /push_timeout/,
  );
  assert.equal(signalWasAborted, true);
});

test("stale background responder notification is cancelled safely", async () => {
  const store = new Map([
    ["notifications/notification-ab", {
      status: "sent",
      sessionId: "session-ab",
      recipientId: "student-b",
    }],
    ["notifications/accepted-notification", {
      status: "accepted",
      sessionId: "session-ab",
      recipientId: "student-b",
    }],
  ]);
  const fakeDb = {
    collection: (collectionName) => ({
      doc: (docId) => ({
        path: `${collectionName}/${docId}`,
        id: docId,
      }),
    }),
    runTransaction: async (callback) => callback({
      get: async (ref) => ({
        exists: store.has(ref.path),
        data: () => store.get(ref.path),
      }),
      update: (ref, update) => {
        store.set(ref.path, {
          ...store.get(ref.path),
          ...update,
        });
      },
    }),
  };

  assert.deepEqual(
    await cancelBackgroundStudentResponderNotification({
      db: fakeDb,
      notificationId: "notification-ab",
      sessionId: "session-ab",
      responderId: "student-b",
      reason: "stale_before_push",
    }),
    {
      cancelled: true,
      reason: "stale_before_push",
      staleReason: "session_or_search_missing",
      leaveForAccept: false,
    },
  );
  assert.equal(
    store.get("notifications/notification-ab").status,
    "cancelled",
  );
  assert.equal(
    store.get("notifications/notification-ab").cancelReason,
    "stale_before_push",
  );
  assert.ok(store.get("notifications/notification-ab").cancelledAt);
  assert.deepEqual(
    await cancelBackgroundStudentResponderNotification({
      db: fakeDb,
      notificationId: "accepted-notification",
      sessionId: "session-ab",
      responderId: "student-b",
    }),
    {
      cancelled: false,
      reason: "notification_not_current",
      leaveForAccept: false,
    },
  );
  assert.equal(
    store.get("notifications/accepted-notification").status,
    "accepted",
  );
});

test("background responder stale-before-push flow cancels notification", async () => {
  const notificationPath = "notifications/session-ab_student-b";
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      status: "pending_confirmation",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      studentId: "student-a",
      language: "en",
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      userId: "student-b",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(nowMillis + 60_000),
      currentSessionId: "session-ab",
    }],
  ]);
  let transactionCount = 0;
  const fakeDb = {
    collection: (collectionName) => ({
      doc: (docId) => ({
        path: `${collectionName}/${docId}`,
        id: docId,
        get: async () => ({
          exists: store.has(`${collectionName}/${docId}`),
          data: () => store.get(`${collectionName}/${docId}`),
        }),
      }),
    }),
    runTransaction: async (callback) => {
      transactionCount += 1;
      const result = await callback({
        get: async (ref) => ({
          exists: store.has(ref.path),
          data: () => store.get(ref.path),
        }),
        set: (ref, value) => {
          store.set(ref.path, value);
        },
        update: (ref, update) => {
          store.set(ref.path, {
            ...store.get(ref.path),
            ...update,
          });
        },
      });
      if (transactionCount === 1) {
        store.set("searchRequests/student-b", {
          ...store.get("searchRequests/student-b"),
          appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
          backgroundExpiresAt: null,
        });
      }
      return result;
    },
  };

  const result = await maybeNotifyBackgroundStudentResponder({
    db: fakeDb,
    sessionId: "session-ab",
    responderId: "student-b",
    responderSearchRequestDocId: "student-b",
    requesterData: {
      displayName: "Joining Student",
      photoUrl: "joining-photo",
    },
  });

  assert.equal(result.shouldNotify, false);
  assert.equal(result.reason, "stale_before_push");
  assert.equal(store.get(notificationPath).status, "cancelled");
  assert.equal(
    store.get(notificationPath).cancelReason,
    "stale_before_push",
  );
  assert.equal(store.get(notificationPath).sessionId, "session-ab");
  assert.equal(store.get(notificationPath).recipientId, "student-b");
});

test("background responder stale-before-push preserves accept race", async () => {
  const notificationPath = "notifications/session-ab_student-b";
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      status: "pending_confirmation",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      studentId: "student-a",
      language: "en",
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      userId: "student-b",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(nowMillis + 60_000),
      currentSessionId: "session-ab",
    }],
  ]);
  let transactionCount = 0;
  const fakeDb = {
    collection: (collectionName) => ({
      doc: (docId) => ({
        path: `${collectionName}/${docId}`,
        id: docId,
        get: async () => ({
          exists: store.has(`${collectionName}/${docId}`),
          data: () => store.get(`${collectionName}/${docId}`),
        }),
      }),
    }),
    runTransaction: async (callback) => {
      transactionCount += 1;
      const result = await callback({
        get: async (ref) => ({
          exists: store.has(ref.path),
          data: () => store.get(ref.path),
        }),
        set: (ref, value) => {
          store.set(ref.path, value);
        },
        update: (ref, update) => {
          store.set(ref.path, {
            ...store.get(ref.path),
            ...update,
          });
        },
      });
      if (transactionCount === 1) {
        store.set("videoSessions/session-ab", {
          ...store.get("videoSessions/session-ab"),
          acceptingTutorId: "student-b",
          acceptingAt: timestampFromMillis(nowMillis),
        });
      }
      return result;
    },
  };

  const result = await maybeNotifyBackgroundStudentResponder({
    db: fakeDb,
    sessionId: "session-ab",
    responderId: "student-b",
    responderSearchRequestDocId: "student-b",
    requesterData: {displayName: "Joining Student"},
  });

  assert.equal(result.shouldNotify, false);
  assert.equal(result.reason, "accept_finalization_in_progress");
  assert.equal(result.staleReason, "accept_in_progress");
  assert.equal(store.get(notificationPath).status, "sent");
  assert.equal(
    Object.hasOwn(store.get(notificationPath), "cancelledAt"),
    false,
  );
});

test("background responder stale-before-push cancel preserves accept race", async () => {
  const notificationPath = "notifications/session-ab_student-b";
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      status: "pending_confirmation",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      studentId: "student-a",
      language: "en",
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      userId: "student-b",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(nowMillis + 60_000),
      currentSessionId: "session-ab",
    }],
  ]);
  let transactionCount = 0;
  const fakeDb = {
    collection: (collectionName) => ({
      doc: (docId) => ({
        path: `${collectionName}/${docId}`,
        id: docId,
        get: async () => ({
          exists: store.has(`${collectionName}/${docId}`),
          data: () => store.get(`${collectionName}/${docId}`),
        }),
      }),
    }),
    runTransaction: async (callback) => {
      transactionCount += 1;
      if (transactionCount === 2) {
        store.set("videoSessions/session-ab", {
          ...store.get("videoSessions/session-ab"),
          acceptingTutorId: "student-b",
          acceptingAt: timestampFromMillis(nowMillis),
        });
      }
      const result = await callback({
        get: async (ref) => ({
          exists: store.has(ref.path),
          data: () => store.get(ref.path),
        }),
        set: (ref, value) => {
          store.set(ref.path, value);
        },
        update: (ref, update) => {
          store.set(ref.path, {
            ...store.get(ref.path),
            ...update,
          });
        },
      });
      if (transactionCount === 1) {
        store.set("searchRequests/student-b", {
          ...store.get("searchRequests/student-b"),
          appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
          backgroundExpiresAt: null,
        });
      }
      return result;
    },
  };

  const result = await maybeNotifyBackgroundStudentResponder({
    db: fakeDb,
    sessionId: "session-ab",
    responderId: "student-b",
    responderSearchRequestDocId: "student-b",
    requesterData: {displayName: "Joining Student"},
  });

  assert.equal(result.shouldNotify, false);
  assert.equal(result.reason, "accept_finalization_in_progress");
  assert.equal(result.staleReason, "accept_in_progress");
  assert.equal(store.get(notificationPath).status, "sent");
  assert.equal(
    Object.hasOwn(store.get(notificationPath), "cancelledAt"),
    false,
  );
});

test("background responder notify flow creates notification and sends push", async () => {
  const notificationPath = "notifications/session-ab_student-b";
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      status: "pending_confirmation",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      studentId: "student-a",
      language: "en",
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      userId: "student-b",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(nowMillis + 60_000),
      currentSessionId: "session-ab",
    }],
  ]);
  const fakeDb = {
    collection: (collectionName) => ({
      doc: (docId) => ({
        path: `${collectionName}/${docId}`,
        id: docId,
        get: async () => ({
          exists: store.has(`${collectionName}/${docId}`),
          data: () => store.get(`${collectionName}/${docId}`),
        }),
      }),
    }),
    runTransaction: async (callback) => callback({
      get: async (ref) => ({
        exists: store.has(ref.path),
        data: () => store.get(ref.path),
      }),
      set: (ref, value) => {
        store.set(ref.path, value);
      },
      update: (ref, update) => {
        store.set(ref.path, {
          ...store.get(ref.path),
          ...update,
        });
      },
    }),
  };
  const pushCalls = [];

  const result = await maybeNotifyBackgroundStudentResponder({
    db: fakeDb,
    sessionId: "session-ab",
    responderId: "student-b",
    responderSearchRequestDocId: "student-b",
    requesterData: {
      displayName: "Joining Student",
      photoUrl: "joining-photo",
    },
    pushSender: async (responderId, callData) => {
      pushCalls.push({responderId, callData});
      return {sent: true, channel: "test"};
    },
  });

  assert.equal(result.shouldNotify, true);
  assert.equal(result.reason, "background_responder");
  assert.equal(result.pushResult.sent, true);
  assert.equal(pushCalls.length, 1);
  assert.equal(pushCalls[0].responderId, "student-b");
  assert.equal(pushCalls[0].callData.sessionId, "session-ab");
  assert.equal(pushCalls[0].callData.callerName, "Joining Student");
  assert.equal(pushCalls[0].callData.callerId, "student-a");
  assert.equal(pushCalls[0].callData.callerPhoto, "joining-photo");
  assert.equal(pushCalls[0].callData.language, "en");
  assert.equal(pushCalls[0].callData.scenario, "student_student");
  assert.equal(pushCalls[0].callData.requesterId, "student-a");
  assert.equal(pushCalls[0].callData.responderId, "student-b");
  assert.equal(pushCalls[0].callData.requesterRole, "student");
  assert.equal(pushCalls[0].callData.responderRole, "student");
  assert.equal(pushCalls[0].callData.navRole, "student");
  assert.equal(pushCalls[0].callData.acceptMode, "responder_accepts");
  assert.equal(
    pushCalls[0].callData.callKitId,
    buildCallKitIdForSession("session-ab"),
  );
  assert.equal(pushCalls[0].callData.notificationId, "session-ab_student-b");
  assert.equal(pushCalls[0].callData.searchRequestId, "");
  assert.ok(pushCalls[0].callData.expiresAt);
  assert.equal(pushCalls[0].callData.roomUrl, "");
  assert.equal(pushCalls[0].callData.roomName, "");
  assert.equal(pushCalls[0].callData.tokenStrategy, "accept_call");
  assert.equal(Object.hasOwn(pushCalls[0].callData, "meetingToken"), false);
  assert.equal(store.get(notificationPath).status, "sent");
  assert.equal(store.get(notificationPath).recipientId, "student-b");
  assert.equal(store.get(notificationPath).sessionId, "session-ab");
  assert.ok(store.get(notificationPath).pushSentAt);
  assert.equal(store.get(notificationPath).pushChannel, "test");
  assert.ok(store.get(notificationPath).updatedAt);
  assert.deepEqual(store.get(notificationPath).studentInfo, {
    name: "Joining Student",
    photo: "joining-photo",
  });
});

test("background responder finalization failure keeps notification id for retry", async () => {
  const notificationPath = "notifications/session-ab_student-b";
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      status: "pending_confirmation",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      studentId: "student-a",
      language: "en",
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      userId: "student-b",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(nowMillis + 60_000),
      currentSessionId: "session-ab",
    }],
  ]);
  const fakeDb = fakeStoreDb(store, {
    onUpdate: (ref, update) => {
      if (ref.path === notificationPath && update.pushSentAt) {
        throw new Error("finalization_down");
      }
    },
  });
  let pushSendCount = 0;

  const originalConsoleError = console.error;
  let result;
  try {
    console.error = () => {};
    result = await maybeNotifyBackgroundStudentResponder({
      db: fakeDb,
      sessionId: "session-ab",
      responderId: "student-b",
      responderSearchRequestDocId: "student-b",
      requesterData: {
        displayName: "Joining Student",
        photoUrl: "joining-photo",
      },
      pushSender: async () => {
        pushSendCount += 1;
        return {sent: true, channel: "test"};
      },
    });
  } finally {
    console.error = originalConsoleError;
  }

  assert.equal(pushSendCount, 1);
  assert.equal(result.shouldNotify, false);
  assert.equal(result.reason, "push_finalization_failed");
  assert.equal(result.staleReason, "finalization_down");
  assert.equal(result.notificationId, "session-ab_student-b");
  assert.deepEqual(result.pushResult, {
    sent: true,
    channel: "test",
  });
  assert.equal(
    shouldRetryBackgroundStudentMatchAfterNotifyResult(result),
    true,
  );
  assert.equal(store.get(notificationPath).status, "sent");
});

test("background responder notify flow cancels stale state after push", async () => {
  const notificationPath = "notifications/session-ab_student-b";
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      status: "pending_confirmation",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      studentId: "student-a",
      language: "en",
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      userId: "student-b",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(nowMillis + 60_000),
      currentSessionId: "session-ab",
    }],
  ]);
  const fakeDb = {
    collection: (collectionName) => ({
      doc: (docId) => ({
        path: `${collectionName}/${docId}`,
        id: docId,
        get: async () => ({
          exists: store.has(`${collectionName}/${docId}`),
          data: () => store.get(`${collectionName}/${docId}`),
        }),
      }),
    }),
    runTransaction: async (callback) => callback({
      get: async (ref) => ({
        exists: store.has(ref.path),
        data: () => store.get(ref.path),
      }),
      set: (ref, value) => {
        store.set(ref.path, value);
      },
      update: (ref, update) => {
        store.set(ref.path, {
          ...store.get(ref.path),
          ...update,
        });
      },
    }),
  };

  const result = await maybeNotifyBackgroundStudentResponder({
    db: fakeDb,
    sessionId: "session-ab",
    responderId: "student-b",
    responderSearchRequestDocId: "student-b",
    requesterData: {displayName: "Joining Student"},
    pushSender: async () => {
      store.set("searchRequests/student-b", {
        ...store.get("searchRequests/student-b"),
        appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
        backgroundExpiresAt: null,
      });
      return {sent: true, channel: "test"};
    },
  });

  assert.equal(result.shouldNotify, false);
  assert.equal(result.reason, "stale_after_push");
  assert.equal(result.pushResult.sent, true);
  assert.equal(store.get(notificationPath).status, "cancelled");
  assert.equal(store.get(notificationPath).cancelReason, "stale_after_push");
  assert.ok(store.get(notificationPath).pushSentAt);
  assert.equal(store.get(notificationPath).pushChannel, "test");
  assert.ok(store.get(notificationPath).cancelledAt);
});

test("background responder push success preserves terminal notifications", async () => {
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      status: "pending_confirmation",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      studentId: "student-a",
      language: "en",
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      userId: "student-b",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(nowMillis + 60_000),
      currentSessionId: "session-ab",
    }],
    ["notifications/accepted-notification", {
      status: "accepted",
      sessionId: "session-ab",
      recipientId: "student-b",
    }],
    ["notifications/cancelled-notification", {
      status: "cancelled",
      sessionId: "session-ab",
      recipientId: "student-b",
    }],
  ]);
  const fakeDb = {
    collection: (collectionName) => ({
      doc: (docId) => ({
        path: `${collectionName}/${docId}`,
        id: docId,
      }),
    }),
    runTransaction: async (callback) => callback({
      get: async (ref) => ({
        exists: store.has(ref.path),
        data: () => store.get(ref.path),
      }),
      update: (ref, update) => {
        store.set(ref.path, {
          ...store.get(ref.path),
          ...update,
        });
      },
    }),
  };

  for (const notificationId of [
    "accepted-notification",
    "cancelled-notification",
  ]) {
    assert.deepEqual(
      await recordBackgroundStudentResponderPushSuccess({
        db: fakeDb,
        notificationId,
        sessionId: "session-ab",
        responderId: "student-b",
        responderSearchRequestDocId: "student-b",
        pushResult: {sent: true, channel: "test"},
        nowMillis,
      }),
      {
        stillCurrent: false,
        reason: "notification_not_current",
        updated: false,
      },
    );
    assert.equal(
      Object.hasOwn(store.get(`notifications/${notificationId}`), "pushSentAt"),
      false,
    );
    assert.equal(
      Object.hasOwn(store.get(`notifications/${notificationId}`), "pushChannel"),
      false,
    );
  }
  assert.equal(
    store.get("notifications/accepted-notification").status,
    "accepted",
  );
  assert.equal(
    store.get("notifications/cancelled-notification").status,
    "cancelled",
  );
});

test("background responder push failure preserves terminal notifications", async () => {
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      status: "pending_confirmation",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      studentId: "student-a",
      language: "en",
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      userId: "student-b",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(nowMillis + 60_000),
      currentSessionId: "session-ab",
    }],
    ["notifications/accepted-notification", {
      status: "accepted",
      sessionId: "session-ab",
      recipientId: "student-b",
    }],
    ["notifications/cancelled-notification", {
      status: "cancelled",
      sessionId: "session-ab",
      recipientId: "student-b",
    }],
  ]);
  const fakeDb = {
    collection: (collectionName) => ({
      doc: (docId) => ({
        path: `${collectionName}/${docId}`,
        id: docId,
      }),
    }),
    runTransaction: async (callback) => callback({
      get: async (ref) => ({
        exists: store.has(ref.path),
        data: () => store.get(ref.path),
      }),
      update: (ref, update) => {
        store.set(ref.path, {
          ...store.get(ref.path),
          ...update,
        });
      },
    }),
  };

  for (const notificationId of [
    "accepted-notification",
    "cancelled-notification",
  ]) {
    assert.deepEqual(
      await recordBackgroundStudentResponderPushFailure({
        db: fakeDb,
        notificationId,
        sessionId: "session-ab",
        responderId: "student-b",
        responderSearchRequestDocId: "student-b",
        error: {message: "network unavailable"},
        nowMillis,
      }),
      {
        stillCurrent: false,
        reason: "notification_not_current",
        updated: false,
      },
    );
    assert.equal(
      Object.hasOwn(
        store.get(`notifications/${notificationId}`),
        "lastPushError",
      ),
      false,
    );
    assert.equal(
      Object.hasOwn(
        store.get(`notifications/${notificationId}`),
        "lastPushFailedAt",
      ),
      false,
    );
  }
  assert.equal(
    store.get("notifications/accepted-notification").status,
    "accepted",
  );
  assert.equal(
    store.get("notifications/cancelled-notification").status,
    "cancelled",
  );
});

test("background responder post-push finalization preserves accept race", async () => {
  const nowMillis = Date.now();
  const baseSessionData = {
    status: "pending_confirmation",
    currentResponderId: "student-b",
    currentTutorId: "student-b",
    currentResponderRole: "student",
    responderRole: "student",
    scenario: "student_student",
    participantRoles: {
      "student-a": "student",
      "student-b": "student",
    },
    studentId: "student-a",
    language: "en",
    responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
    confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
  };
  const searchRequestData = {
    status: SEARCH_REQUEST_STATUS.MATCHED,
    userId: "student-b",
    appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
    backgroundExpiresAt: timestampFromMillis(nowMillis + 60_000),
    currentSessionId: "session-ab",
  };

  for (const {notificationId, sessionData, finalize} of [
    {
      notificationId: "accept-lock-success",
      sessionData: {
        ...baseSessionData,
        acceptingTutorId: "student-b",
        acceptingAt: timestampFromMillis(nowMillis),
      },
      finalize: () => recordBackgroundStudentResponderPushSuccess,
    },
    {
      notificationId: "connecting-success",
      sessionData: {
        ...baseSessionData,
        status: "connecting",
      },
      finalize: () => recordBackgroundStudentResponderPushSuccess,
    },
    {
      notificationId: "active-success",
      sessionData: {
        ...baseSessionData,
        status: "active",
      },
      finalize: () => recordBackgroundStudentResponderPushSuccess,
    },
    {
      notificationId: "accept-lock-failure",
      sessionData: {
        ...baseSessionData,
        acceptingTutorId: "student-b",
        acceptingAt: timestampFromMillis(nowMillis),
      },
      finalize: () => recordBackgroundStudentResponderPushFailure,
    },
    {
      notificationId: "connecting-failure",
      sessionData: {
        ...baseSessionData,
        status: "connecting",
      },
      finalize: () => recordBackgroundStudentResponderPushFailure,
    },
    {
      notificationId: "active-failure",
      sessionData: {
        ...baseSessionData,
        status: "active",
      },
      finalize: () => recordBackgroundStudentResponderPushFailure,
    },
  ]) {
    const store = new Map([
      ["videoSessions/session-ab", sessionData],
      ["searchRequests/student-b", searchRequestData],
      [`notifications/${notificationId}`, {
        status: "sent",
        sessionId: "session-ab",
        recipientId: "student-b",
      }],
    ]);
    const fakeDb = {
      collection: (collectionName) => ({
        doc: (docId) => ({
          path: `${collectionName}/${docId}`,
          id: docId,
        }),
      }),
      runTransaction: async (callback) => callback({
        get: async (ref) => ({
          exists: store.has(ref.path),
          data: () => store.get(ref.path),
        }),
        update: (ref, update) => {
          store.set(ref.path, {
            ...store.get(ref.path),
            ...update,
          });
        },
      }),
    };

    const result = await finalize()({
      db: fakeDb,
      notificationId,
      sessionId: "session-ab",
      responderId: "student-b",
      responderSearchRequestDocId: "student-b",
      pushResult: {sent: true, channel: "test"},
      error: {message: "network unavailable"},
      nowMillis,
    });

    assert.equal(result.reason, "accept_finalization_in_progress");
    assert.equal(result.updated, false);
    assert.equal(
      result.staleReason,
      sessionData.status === "connecting" || sessionData.status === "active" ?
        `session_${sessionData.status}` :
        "accept_in_progress",
    );
    assert.equal(
      store.get(`notifications/${notificationId}`).status,
      "sent",
    );
    assert.equal(
      Object.hasOwn(
        store.get(`notifications/${notificationId}`),
        "cancelledAt",
      ),
      false,
    );
  }
});

test("background responder notify flow records push failure metadata", async () => {
  const notificationPath = "notifications/session-ab_student-b";
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      status: "pending_confirmation",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      studentId: "student-a",
      language: "en",
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      userId: "student-b",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(nowMillis + 60_000),
      currentSessionId: "session-ab",
    }],
  ]);
  const fakeDb = {
    collection: (collectionName) => ({
      doc: (docId) => ({
        path: `${collectionName}/${docId}`,
        id: docId,
        get: async () => ({
          exists: store.has(`${collectionName}/${docId}`),
          data: () => store.get(`${collectionName}/${docId}`),
        }),
      }),
    }),
    runTransaction: async (callback) => callback({
      get: async (ref) => ({
        exists: store.has(ref.path),
        data: () => store.get(ref.path),
      }),
      set: (ref, value) => {
        store.set(ref.path, value);
      },
      update: (ref, update) => {
        store.set(ref.path, {
          ...store.get(ref.path),
          ...update,
        });
      },
    }),
  };

  const result = await maybeNotifyBackgroundStudentResponder({
    db: fakeDb,
    sessionId: "session-ab",
    responderId: "student-b",
    responderSearchRequestDocId: "student-b",
    requesterData: {displayName: "Joining Student"},
    pushSender: async () => {
      throw new Error("network unavailable");
    },
  });

  assert.equal(result.shouldNotify, true);
  assert.equal(result.pushResult.sent, false);
  assert.equal(result.pushResult.reason, "push_failed");
  assert.equal(result.pushResult.error, "network unavailable");
  assert.equal(store.get(notificationPath).status, "sent");
  assert.equal(
    store.get(notificationPath).lastPushError,
    "network unavailable",
  );
  assert.ok(store.get(notificationPath).lastPushFailedAt);
  assert.ok(store.get(notificationPath).updatedAt);
});

test("background responder notify flow cancels stale state after push failure", async () => {
  const notificationPath = "notifications/session-ab_student-b";
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      status: "pending_confirmation",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      studentId: "student-a",
      language: "en",
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      userId: "student-b",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(nowMillis + 60_000),
      currentSessionId: "session-ab",
    }],
  ]);
  const fakeDb = {
    collection: (collectionName) => ({
      doc: (docId) => ({
        path: `${collectionName}/${docId}`,
        id: docId,
        get: async () => ({
          exists: store.has(`${collectionName}/${docId}`),
          data: () => store.get(`${collectionName}/${docId}`),
        }),
      }),
    }),
    runTransaction: async (callback) => callback({
      get: async (ref) => ({
        exists: store.has(ref.path),
        data: () => store.get(ref.path),
      }),
      set: (ref, value) => {
        store.set(ref.path, value);
      },
      update: (ref, update) => {
        store.set(ref.path, {
          ...store.get(ref.path),
          ...update,
        });
      },
    }),
  };

  const result = await maybeNotifyBackgroundStudentResponder({
    db: fakeDb,
    sessionId: "session-ab",
    responderId: "student-b",
    responderSearchRequestDocId: "student-b",
    requesterData: {displayName: "Joining Student"},
    pushSender: async () => {
      store.set("searchRequests/student-b", {
        ...store.get("searchRequests/student-b"),
        appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
        backgroundExpiresAt: null,
      });
      return {
        sent: false,
        reason: "fcm_failed",
        error: "network unavailable",
      };
    },
  });

  assert.equal(result.shouldNotify, false);
  assert.equal(result.reason, "stale_after_push");
  assert.equal(result.pushResult.sent, false);
  assert.equal(store.get(notificationPath).status, "cancelled");
  assert.equal(store.get(notificationPath).cancelReason, "stale_after_push");
  assert.equal(
    store.get(notificationPath).staleReason,
    "responder_not_background",
  );
  assert.equal(store.get(notificationPath).lastPushError, "network unavailable");
  assert.ok(store.get(notificationPath).lastPushFailedAt);
});

test("background responder timeout ignores late push success", async () => {
  const notificationPath = "notifications/session-ab_student-b";
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      status: "pending_confirmation",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      studentId: "student-a",
      language: "en",
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      userId: "student-b",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(nowMillis + 60_000),
      currentSessionId: "session-ab",
    }],
  ]);
  const fakeDb = {
    collection: (collectionName) => ({
      doc: (docId) => ({
        path: `${collectionName}/${docId}`,
        id: docId,
        get: async () => ({
          exists: store.has(`${collectionName}/${docId}`),
          data: () => store.get(`${collectionName}/${docId}`),
        }),
      }),
    }),
    runTransaction: async (callback) => callback({
      get: async (ref) => ({
        exists: store.has(ref.path),
        data: () => store.get(ref.path),
      }),
      set: (ref, value) => {
        store.set(ref.path, value);
      },
      update: (ref, update) => {
        store.set(ref.path, {
          ...store.get(ref.path),
          ...update,
        });
      },
    }),
  };

  const result = await maybeNotifyBackgroundStudentResponder({
    db: fakeDb,
    sessionId: "session-ab",
    responderId: "student-b",
    responderSearchRequestDocId: "student-b",
    requesterData: {displayName: "Joining Student"},
    pushTimeoutMs: 1,
    pushSender: async () => new Promise((resolve) => {
      setTimeout(() => {
        resolve({sent: true, channel: "late_success"});
      }, 15);
    }),
  });
  await new Promise((resolve) => {
    setTimeout(resolve, 25);
  });

  assert.equal(result.shouldNotify, true);
  assert.equal(result.pushResult.sent, false);
  assert.equal(result.pushResult.reason, "push_failed");
  assert.equal(result.pushResult.error, "push_timeout");
  assert.equal(store.get(notificationPath).status, "sent");
  assert.equal(store.get(notificationPath).lastPushError, "push_timeout");
  assert.equal(Object.hasOwn(store.get(notificationPath), "pushSentAt"), false);
  assert.equal(Object.hasOwn(store.get(notificationPath), "pushChannel"), false);
});

test("background responder notify flow records unsent push result", async () => {
  const notificationPath = "notifications/session-ab_student-b";
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      status: "pending_confirmation",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      studentId: "student-a",
      language: "en",
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      userId: "student-b",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(nowMillis + 60_000),
      currentSessionId: "session-ab",
    }],
  ]);
  const fakeDb = {
    collection: (collectionName) => ({
      doc: (docId) => ({
        path: `${collectionName}/${docId}`,
        id: docId,
        get: async () => ({
          exists: store.has(`${collectionName}/${docId}`),
          data: () => store.get(`${collectionName}/${docId}`),
        }),
      }),
    }),
    runTransaction: async (callback) => callback({
      get: async (ref) => ({
        exists: store.has(ref.path),
        data: () => store.get(ref.path),
      }),
      set: (ref, value) => {
        store.set(ref.path, value);
      },
      update: (ref, update) => {
        store.set(ref.path, {
          ...store.get(ref.path),
          ...update,
        });
      },
    }),
  };

  const result = await maybeNotifyBackgroundStudentResponder({
    db: fakeDb,
    sessionId: "session-ab",
    responderId: "student-b",
    responderSearchRequestDocId: "student-b",
    requesterData: {displayName: "Joining Student"},
    pushSender: async () => ({
      sent: false,
      reason: "missing_tokens",
    }),
  });

  assert.equal(result.shouldNotify, true);
  assert.equal(result.pushResult.sent, false);
  assert.equal(result.pushResult.reason, "missing_tokens");
  assert.equal(store.get(notificationPath).status, "sent");
  assert.equal(store.get(notificationPath).lastPushError, "missing_tokens");
  assert.ok(store.get(notificationPath).lastPushFailedAt);
  assert.ok(store.get(notificationPath).updatedAt);
});

test("background responder notify flow records unexpected push result", async () => {
  const notificationPath = "notifications/session-ab_student-b";
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      status: "pending_confirmation",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      studentId: "student-a",
      language: "en",
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      userId: "student-b",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(nowMillis + 60_000),
      currentSessionId: "session-ab",
    }],
  ]);
  const fakeDb = {
    collection: (collectionName) => ({
      doc: (docId) => ({
        path: `${collectionName}/${docId}`,
        id: docId,
        get: async () => ({
          exists: store.has(`${collectionName}/${docId}`),
          data: () => store.get(`${collectionName}/${docId}`),
        }),
      }),
    }),
    runTransaction: async (callback) => callback({
      get: async (ref) => ({
        exists: store.has(ref.path),
        data: () => store.get(ref.path),
      }),
      set: (ref, value) => {
        store.set(ref.path, value);
      },
      update: (ref, update) => {
        store.set(ref.path, {
          ...store.get(ref.path),
          ...update,
        });
      },
    }),
  };

  const result = await maybeNotifyBackgroundStudentResponder({
    db: fakeDb,
    sessionId: "session-ab",
    responderId: "student-b",
    responderSearchRequestDocId: "student-b",
    requesterData: {displayName: "Joining Student"},
    pushSender: async () => ({reason: "empty_result"}),
  });

  assert.equal(result.shouldNotify, true);
  assert.equal(result.pushResult.sent, false);
  assert.equal(result.pushResult.reason, "empty_result");
  assert.equal(result.pushResult.error, "empty_result");
  assert.equal(store.get(notificationPath).status, "sent");
  assert.equal(store.get(notificationPath).lastPushError, "empty_result");
  assert.ok(store.get(notificationPath).lastPushFailedAt);
});

test("background responder notify flow records combined push errors", async () => {
  const notificationPath = "notifications/session-ab_student-b";
  const nowMillis = Date.now();
  const store = new Map([
    ["videoSessions/session-ab", {
      status: "pending_confirmation",
      currentResponderId: "student-b",
      currentTutorId: "student-b",
      currentResponderRole: "student",
      responderRole: "student",
      scenario: "student_student",
      participantRoles: {
        "student-a": "student",
        "student-b": "student",
      },
      studentId: "student-a",
      language: "en",
      responseExpiresAt: timestampFromMillis(nowMillis + 45_000),
      confirmationExpiresAt: timestampFromMillis(nowMillis + 45_000),
    }],
    ["searchRequests/student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      userId: "student-b",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(nowMillis + 60_000),
      currentSessionId: "session-ab",
    }],
  ]);
  const fakeDb = {
    collection: (collectionName) => ({
      doc: (docId) => ({
        path: `${collectionName}/${docId}`,
        id: docId,
        get: async () => ({
          exists: store.has(`${collectionName}/${docId}`),
          data: () => store.get(`${collectionName}/${docId}`),
        }),
      }),
    }),
    runTransaction: async (callback) => callback({
      get: async (ref) => ({
        exists: store.has(ref.path),
        data: () => store.get(ref.path),
      }),
      set: (ref, value) => {
        store.set(ref.path, value);
      },
      update: (ref, update) => {
        store.set(ref.path, {
          ...store.get(ref.path),
          ...update,
        });
      },
    }),
  };

  const result = await maybeNotifyBackgroundStudentResponder({
    db: fakeDb,
    sessionId: "session-ab",
    responderId: "student-b",
    responderSearchRequestDocId: "student-b",
    requesterData: {displayName: "Joining Student"},
    pushSender: async () => ({
      sent: false,
      reason: "fcm_failed",
      error: "apns: apns unavailable; fcm: fcm unavailable",
    }),
  });

  assert.equal(result.shouldNotify, true);
  assert.equal(result.pushResult.sent, false);
  assert.equal(result.pushResult.reason, "fcm_failed");
  assert.equal(
    store.get(notificationPath).lastPushError,
    "apns: apns unavailable; fcm: fcm unavailable",
  );
  assert.ok(store.get(notificationPath).lastPushFailedAt);
  assert.ok(store.get(notificationPath).updatedAt);
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
      heartbeatAt: timestampFromMillis(fixedNowMillis - 30 * 1000),
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 1),
      expiresAt: futureTimestamp(3),
    }, fixedNowMillis),
    true,
  );
});

test("background active search request is not reusable with stale heartbeat", () => {
  assert.equal(
    isReusableSearchRequest({
      status: SEARCH_REQUEST_STATUS.ACTIVE,
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      heartbeatAt: timestampFromMillis(
        fixedNowMillis -
          (SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS + 1) * 1000,
      ),
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 60 * 1000),
      expiresAt: futureTimestamp(3),
    }, fixedNowMillis),
    false,
  );
});

test("background active search request is reusable at heartbeat cutoff", () => {
  assert.equal(
    isReusableSearchRequest({
      status: SEARCH_REQUEST_STATUS.ACTIVE,
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      heartbeatAt: timestampFromMillis(
        fixedNowMillis -
          SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS * 1000,
      ),
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 60 * 1000),
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

test("start search failure update makes unbound request terminal", () => {
  const update = buildStartSearchFailureUpdate({
    error: new Error("matcher unavailable"),
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(update.status, SEARCH_REQUEST_STATUS.ERROR);
  assert.equal(update.stopReason, "start_search_failed");
  assert.equal(update.stoppedAt, serverTimestamp);
  assert.equal(update.updatedAt, serverTimestamp);
  assert.equal(update.currentSessionId, null);
  assert.equal(update.activeSessionId, fieldDelete);
  assert.equal(update.matchedSessionId, fieldDelete);
  assert.equal(update.matchedResponderId, fieldDelete);
  assert.equal(update.matchedUserId, null);
  assert.equal(update.matchedRole, null);
  assert.equal(update.pairAttemptId, null);
  assert.deepEqual(update.attemptExcludedCandidateIds, []);
  assert.equal(update.lockOwner, null);
  assert.equal(update.lockExpiresAt, null);
  assert.deepEqual(update.lastError, {
    code: "start_search_failed",
    message: "matcher unavailable",
  });
  assert.equal(update.errorCode, "start_search_failed");
  assert.equal(update.errorMessage, "matcher unavailable");
});

test("start search failure cleanup targets only same unbound live request", () => {
  const activeRequest = {
    status: SEARCH_REQUEST_STATUS.ACTIVE,
    requestId: "request-a",
    userId: "student-a",
    currentSessionId: null,
    matchedSessionId: null,
    activeSessionId: null,
  };

  assert.equal(hasSearchRequestSessionBinding(activeRequest), false);
  assert.equal(shouldFailUnboundStartSearchRequest({
    requestData: activeRequest,
    userId: "student-a",
    requestId: "request-a",
  }), true);
  assert.equal(shouldFailUnboundStartSearchRequest({
    requestData: {
      ...activeRequest,
      currentSessionId: "session-a",
    },
    userId: "student-a",
    requestId: "request-a",
  }), false);
  assert.equal(shouldFailUnboundStartSearchRequest({
    requestData: activeRequest,
    userId: "student-a",
    requestId: "request-b",
  }), false);
  assert.equal(shouldFailUnboundStartSearchRequest({
    requestData: {
      ...activeRequest,
      status: SEARCH_REQUEST_STATUS.STOPPED,
    },
    userId: "student-a",
    requestId: "request-a",
  }), false);
  assert.equal(shouldFailUnboundStartSearchRequest({
    requestData: {
      ...activeRequest,
      userId: "student-b",
    },
    userId: "student-a",
    requestId: "request-a",
  }), false);
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
  const axios = require("axios");
  const functionsTest = require("firebase-functions-test");
  const {acceptCall} = require("./accept_call");
  const {createVideoSession} = require("./create_video_session");
  const {declineCall} = require("./decline_call");
  const {
    processExpiredNotifications,
  } = require("./process_expired_notifications");
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
  const wrappedAcceptCall = testEnv.wrap(acceptCall);
  const wrappedCreateVideoSession = testEnv.wrap(createVideoSession);
  const wrappedDeclineCall = testEnv.wrap(declineCall);
  const wrappedProcessExpiredNotifications =
    testEnv.wrap(processExpiredNotifications);
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

  function cityKeyForUid(uid) {
    return `city_${uid}`
      .toLowerCase()
      .replace(/[^a-z0-9_-]/g, "_")
      .slice(0, 80);
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

  async function assertNoSearchRequestForUser(uid) {
    assert.equal((await searchRequestRef(uid).get()).exists, false);
    assert.equal(
      await db.collection("searchRequests").where("userId", "==", uid).get()
        .then((query) => query.size),
      0,
    );
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
      profileCity: {key: cityKeyForUid(uid)},
      giftMinutes: {
        minutes: 10,
        expiresAt: emulatorFutureTimestamp(60),
      },
      isInCall: false,
      currentSessionId: "",
      ...overrides,
    });
  }

  async function seedTeacher(uid, overrides = {}) {
    await userRef(uid).set({
      role: "native_speaker",
      display_name: "Teacher",
      language_instruction_NS: {code: "en"},
      level: "B1",
      Country_NS: {code: "US"},
      profileCity: {key: cityKeyForUid(uid)},
      verif_NS: true,
      isAvailable: true,
      isInCall: false,
      currentSessionId: "",
      availableSince: admin.firestore.Timestamp.now(),
      ...overrides,
    });
    await db.collection("userPrivateTokens").doc(uid).set({
      voipToken: `voip-${uid}`,
    });
  }

  async function withMockDailyApi(callback) {
    const originalPost = axios.post;
    const originalDelete = axios.delete;
    const dailyCalls = [];
    axios.post = async (url, body, config) => {
      dailyCalls.push({method: "post", url, body, config});
      if (url === "https://api.daily.co/v1/rooms") {
        const roomName = body?.name || `room-${dailyCalls.length}`;
        return {
          data: {
            name: roomName,
            url: `https://smalltalk.daily.co/${roomName}`,
            privacy: "private",
            config: body?.properties || {},
            created_at: new Date().toISOString(),
          },
        };
      }
      if (url === "https://api.daily.co/v1/meeting-tokens") {
        return {
          data: {
            token:
              `token-${body?.properties?.room_name || "room"}` +
              `-${body?.properties?.user_id || "user"}`,
          },
        };
      }
      return originalPost(url, body, config);
    };
    axios.delete = async (url, config) => {
      dailyCalls.push({method: "delete", url, config});
      return {data: {deleted: true}};
    };

    const previousDailyApiKey = process.env.DAILY_API_KEY;
    const previousDailyDomain = process.env.DAILY_DOMAIN;
    process.env.DAILY_API_KEY = "test-daily-api-key";
    process.env.DAILY_DOMAIN = "smalltalk";

    try {
      return await callback(dailyCalls);
    } finally {
      axios.post = originalPost;
      axios.delete = originalDelete;
      if (previousDailyApiKey === undefined) {
        delete process.env.DAILY_API_KEY;
      } else {
        process.env.DAILY_API_KEY = previousDailyApiKey;
      }
      if (previousDailyDomain === undefined) {
        delete process.env.DAILY_DOMAIN;
      } else {
        process.env.DAILY_DOMAIN = previousDailyDomain;
      }
    }
  }

  async function createBackgroundStudentPair(prefix) {
    const waitingUid = uniqueId(`${prefix}-waiting`);
    const joiningUid = uniqueId(`${prefix}-joining`);
    const cityKey = cityKeyForUid(`${waitingUid}-${joiningUid}`);
    await deleteDoc(userRef(waitingUid));
    await deleteDoc(userRef(joiningUid));
    await deleteDoc(searchRequestRef(waitingUid));
    await deleteDoc(searchRequestRef(joiningUid));
    await seedStudent(waitingUid, {
      display_name: "Waiting Student",
      photo_url: "waiting-photo",
      profileCity: {key: cityKey},
    });
    await seedStudent(joiningUid, {
      display_name: "Joining Student",
      photo_url: "joining-photo",
      profileCity: {key: cityKey},
    });

    const waitingResponse = await wrappedStartSearch({
      preferredPartnerLevel: "B1",
      appState: "background",
      platform: "ios",
    }, authContext(waitingUid));
    let pushedCallData = null;
    const joiningResponse = await startSearchCallable({
      preferredPartnerLevel: "B1",
      appState: "foreground",
      platform: "ios",
    }, authContext(joiningUid), {
      backgroundStudentResponderPushSender: async (responderId, callData) => {
        pushedCallData = callData;
        assert.equal(responderId, waitingUid);
        assert.equal(callData.searchRequestId, waitingResponse.requestId);
        return {sent: true, channel: "test_voip"};
      },
    });
    const notificationQuery = await db
      .collection("notifications")
      .where("recipientId", "==", waitingUid)
      .get();
    const matchingNotifications = notificationQuery.docs
      .map((doc) => ({id: doc.id, ref: doc.ref, data: doc.data()}))
      .filter((item) => item.data.sessionId === joiningResponse.sessionId);

    assert.equal(waitingResponse.status, "active");
    assert.equal(joiningResponse.status, "matched");
    assert.equal(joiningResponse.matchedUserId, waitingUid);
    assert.ok(pushedCallData);
    assert.equal(pushedCallData.sessionId, joiningResponse.sessionId);
    assert.equal(matchingNotifications.length, 1);
    assert.equal(matchingNotifications[0].data.status, "sent");

    await Promise.all([
      searchRequestRef(waitingUid).update({
        activeSessionId: joiningResponse.sessionId,
      }),
      searchRequestRef(joiningUid).update({
        activeSessionId: joiningResponse.sessionId,
      }),
    ]);

    return {
      waitingUid,
      joiningUid,
      joiningResponse,
      notification: matchingNotifications[0],
    };
  }

  function assertSearchRequestRestoredToActive(requestData, excludedUid) {
    assert.equal(requestData.status, SEARCH_REQUEST_STATUS.ACTIVE);
    assert.equal(Object.hasOwn(requestData, "activeSessionId"), false);
    assert.equal(requestData.currentSessionId, null);
    assert.equal(Object.hasOwn(requestData, "matchedSessionId"), false);
    assert.equal(requestData.matchedUserId, null);
    assert.equal(Object.hasOwn(requestData, "matchedResponderId"), false);
    assert.equal(requestData.matchedRole, null);
    assert.equal(requestData.pairAttemptId, null);
    assert.equal(requestData.lockOwner, null);
    assert.equal(requestData.lockExpiresAt, null);
    assert.deepEqual(requestData.attemptExcludedCandidateIds, []);
    assert.deepEqual(requestData.excludedCandidateIds, [excludedUid]);
    assert.equal(requestData.stopReason, null);
  }

  function assertSearchRequestStopped(requestData, status, stopReason) {
    assert.equal(requestData.status, status);
    assert.equal(requestData.stopReason, stopReason);
    assert.equal(Object.hasOwn(requestData, "activeSessionId"), false);
    assert.equal(requestData.currentSessionId, null);
    assert.equal(Object.hasOwn(requestData, "matchedSessionId"), false);
    assert.equal(requestData.matchedUserId, null);
    assert.equal(Object.hasOwn(requestData, "matchedResponderId"), false);
    assert.equal(requestData.matchedRole, null);
    assert.equal(requestData.pairAttemptId, null);
    assert.equal(requestData.lockOwner, null);
    assert.equal(requestData.lockExpiresAt, null);
    assert.deepEqual(requestData.attemptExcludedCandidateIds, []);
  }

  function assertUsersReleasedFromSession({
    waitingUser,
    joiningUser,
  }) {
    assert.equal(Object.hasOwn(waitingUser, "currentSessionId"), false);
    assert.equal(Object.hasOwn(joiningUser, "currentSessionId"), false);
    assert.equal(waitingUser.isInCall, false);
    assert.equal(joiningUser.isInCall, false);
  }

  function assertTerminalSessionPairAudit(
    sessionData,
    response,
    participantIds,
  ) {
    assert.equal(sessionData.pairAttemptId, response.pairAttemptId);
    assert.equal(sessionData.matchLock.owner, response.pairAttemptId);
    assert.equal(typeof sessionData.matchLock.expiresAt.toMillis, "function");
    assert.deepEqual(
      sessionData.matchLock.participantIds.slice().sort(),
      participantIds.slice().sort(),
    );
  }

  test("startSearch callable creates one active request document", async () => {
    const uid = uniqueId("student");
    const cityKey = cityKeyForUid(uid);
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
      cityKey,
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
    const cityKey = cityKeyForUid(uid);
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
      cityKey,
    });
  });

  test("startSearch callable creates student-student session", async () => {
    const waitingUid = uniqueId("student-waiting");
    const joiningUid = uniqueId("student-joining");
    const cityKey = cityKeyForUid(`${waitingUid}-${joiningUid}`);
    await deleteDoc(userRef(waitingUid));
    await deleteDoc(userRef(joiningUid));
    await deleteDoc(searchRequestRef(waitingUid));
    await deleteDoc(searchRequestRef(joiningUid));
    await seedStudent(waitingUid, {
      display_name: "Waiting Student",
      photo_url: "waiting-photo",
      profileCity: {key: cityKey},
    });
    await seedStudent(joiningUid, {
      display_name: "Joining Student",
      photo_url: "joining-photo",
      profileCity: {key: cityKey},
    });

    const waitingResponse = await wrappedStartSearch({
      preferredPartnerLevel: "B1",
    }, authContext(waitingUid));
    const joiningResponse = await wrappedStartSearch({
      preferredPartnerLevel: "B1",
    }, authContext(joiningUid));

    assert.equal(waitingResponse.status, "active");
    assert.equal(waitingResponse.sessionId, null);
    assert.equal(joiningResponse.status, "matched");
    assert.equal(joiningResponse.reused, false);
    assert.equal(joiningResponse.matchedUserId, waitingUid);
    assert.equal(joiningResponse.matchedRole, "student");
    assert.equal(joiningResponse.scenario, "student_student");
    assert.equal(typeof joiningResponse.sessionId, "string");
    assert.equal(typeof joiningResponse.pairAttemptId, "string");

    const sessionSnapshot = await db
      .collection("videoSessions")
      .doc(joiningResponse.sessionId)
      .get();
    const sessionData = sessionSnapshot.data();
    const waitingRequest = (await searchRequestRef(waitingUid).get()).data();
    const joiningRequest = (await searchRequestRef(joiningUid).get()).data();
    const waitingUser = (await userRef(waitingUid).get()).data();
    const joiningUser = (await userRef(joiningUid).get()).data();
    const waitingNotifications = await db
      .collection("notifications")
      .where("recipientId", "==", waitingUid)
      .get();

    assert.equal(sessionSnapshot.exists, true);
    assert.equal(sessionData.status, "pending_confirmation");
    assert.equal(sessionData.pairStatus, "pending_confirmation");
    assert.equal(sessionData.scenario, "student_student");
    assert.equal(sessionData.requesterId, joiningUid);
    assert.equal(sessionData.requesterRole, "student");
    assert.equal(sessionData.responderId, waitingUid);
    assert.equal(sessionData.responderRole, "student");
    assert.equal(sessionData.currentResponderId, waitingUid);
    assert.equal(sessionData.currentResponderRole, "student");
    assert.equal(sessionData.currentTutorId, waitingUid);
    assert.equal(sessionData.studentId, joiningUid);
    assert.equal(sessionData.tutorId, null);
    assert.equal(typeof sessionData.expiresAt.toMillis, "function");
    assert.equal(typeof sessionData.responseExpiresAt.toMillis, "function");
    assert.equal(typeof sessionData.confirmationExpiresAt.toMillis, "function");
    assert.equal(sessionData.sessionPolicy.baseLimitSeconds, 300);
    assert.equal(sessionData.sessionPolicy.warningLeadSeconds, 60);
    assert.equal(sessionData.sessionPolicy.maxExtensionCount, 1);
    assert.equal(sessionData.sessionPolicy.extensionSeconds, 300);
    assert.equal(sessionData.sessionPolicy.effectiveLimitSeconds, 300);
    assert.equal(sessionData.studentHasReviewed, false);
    assert.equal(sessionData.tutorHasReviewed, false);
    assert.deepEqual(
      sessionData.participantIds.slice().sort(),
      [joiningUid, waitingUid].sort(),
    );
    assert.deepEqual(sessionData.participantRoles, {
      [joiningUid]: "student",
      [waitingUid]: "student",
    });
    assert.deepEqual(sessionData.participantInfos, {
      [joiningUid]: {
        displayName: "Joining Student",
        photoUrl: "joining-photo",
      },
      [waitingUid]: {
        displayName: "Waiting Student",
        photoUrl: "waiting-photo",
      },
    });
    assert.deepEqual(sessionData.requesterInfo, {
      displayName: "Joining Student",
      photoUrl: "joining-photo",
    });
    assert.deepEqual(sessionData.responderInfo, {
      displayName: "Waiting Student",
      photoUrl: "waiting-photo",
    });
    assert.deepEqual(sessionData.studentInfo, {
      name: "Joining Student",
      photo: "joining-photo",
    });
    assert.deepEqual(sessionData.tutorInfo, {
      name: "Waiting Student",
      photo: "waiting-photo",
    });
    assert.deepEqual(sessionData.searchRequestIds, {
      requester: joiningResponse.requestId,
      responder: waitingResponse.requestId,
    });
    assert.equal(sessionData.matchLock.owner, joiningResponse.pairAttemptId);
    assert.equal(typeof sessionData.matchLock.expiresAt.toMillis, "function");
    assert.deepEqual(
      sessionData.matchLock.participantIds.slice().sort(),
      [joiningUid, waitingUid].sort(),
    );
    assert.equal(sessionData.matchContext.requesterId, joiningUid);
    assert.equal(sessionData.matchContext.requesterRole, "student");
    assert.equal(sessionData.matchContext.selectedResponderId, waitingUid);
    assert.equal(sessionData.matchContext.selectedResponderRole, "student");
    assert.equal(
      sessionData.matchContext.selectedResponderSource,
      "active_student_queue",
    );
    assert.equal(
      sessionData.matchContext.selectedResponderSearchRequestId,
      waitingResponse.requestId,
    );
    assert.deepEqual(
      sessionData.matchContext.candidateIds,
      [waitingUid],
    );
    assert.deepEqual(sessionData.availableTutors, [waitingUid]);
    assert.deepEqual(sessionData.triedTutors, [waitingUid]);

    assert.equal(waitingRequest.status, "matched");
    assert.equal(waitingRequest.currentSessionId, joiningResponse.sessionId);
    assert.equal(waitingRequest.matchedSessionId, joiningResponse.sessionId);
    assert.equal(waitingRequest.matchedUserId, joiningUid);
    assert.equal(waitingRequest.matchedResponderId, waitingUid);
    assert.equal(waitingRequest.matchedRole, "student");
    assert.equal(waitingRequest.pairAttemptId, joiningResponse.pairAttemptId);
    assert.equal(waitingRequest.lockOwner, joiningResponse.pairAttemptId);
    assert.equal(typeof waitingRequest.lockExpiresAt.toMillis, "function");
    assert.equal(joiningRequest.status, "matched");
    assert.equal(joiningRequest.currentSessionId, joiningResponse.sessionId);
    assert.equal(joiningRequest.matchedSessionId, joiningResponse.sessionId);
    assert.equal(joiningRequest.matchedUserId, waitingUid);
    assert.equal(joiningRequest.matchedResponderId, waitingUid);
    assert.equal(joiningRequest.matchedRole, "student");
    assert.equal(joiningRequest.pairAttemptId, joiningResponse.pairAttemptId);
    assert.equal(joiningRequest.lockOwner, joiningResponse.pairAttemptId);
    assert.equal(typeof joiningRequest.lockExpiresAt.toMillis, "function");
    assert.equal(waitingUser.currentSessionId, joiningResponse.sessionId);
    assert.equal(waitingUser.isInCall, false);
    assert.equal(joiningUser.currentSessionId, joiningResponse.sessionId);
    assert.equal(joiningUser.isInCall, false);
    assert.equal(waitingNotifications.empty, true);
  });

  test("startSearch callable notifies background student responder", async () => {
    const waitingUid = uniqueId("student-background-waiting");
    const joiningUid = uniqueId("student-background-joining");
    const cityKey = cityKeyForUid(`${waitingUid}-${joiningUid}`);
    await deleteDoc(userRef(waitingUid));
    await deleteDoc(userRef(joiningUid));
    await deleteDoc(searchRequestRef(waitingUid));
    await deleteDoc(searchRequestRef(joiningUid));
    await seedStudent(waitingUid, {
      display_name: "Waiting Student",
      photo_url: "waiting-photo",
      profileCity: {key: cityKey},
    });
    await seedStudent(joiningUid, {
      display_name: "Joining Student",
      photo_url: "joining-photo",
      profileCity: {key: cityKey},
    });

    const waitingResponse = await wrappedStartSearch({
      preferredPartnerLevel: "B1",
      appState: "background",
      platform: "ios",
    }, authContext(waitingUid));
    let pushSendCount = 0;
    let pushedCallData = null;
    const joiningResponse = await startSearchCallable({
      preferredPartnerLevel: "B1",
      appState: "foreground",
      platform: "ios",
    }, authContext(joiningUid), {
      backgroundStudentResponderPushSender: async (responderId, callData) => {
        pushSendCount += 1;
        pushedCallData = callData;
        assert.equal(responderId, waitingUid);
        assert.equal(callData.callerId, joiningUid);
        assert.equal(callData.callerName, "Joining Student");
        assert.equal(callData.callerPhoto, "joining-photo");
        assert.equal(callData.language, "en");
        assert.equal(callData.scenario, "student_student");
        assert.equal(callData.recipientId, waitingUid);
        assert.equal(callData.requesterId, joiningUid);
        assert.equal(callData.responderId, waitingUid);
        assert.equal(callData.requesterRole, "student");
        assert.equal(callData.responderRole, "student");
        assert.equal(callData.navRole, "student");
        assert.equal(callData.acceptMode, "responder_accepts");
        assert.equal(callData.searchRequestId, waitingResponse.requestId);
        assert.ok(callData.callKitId);
        assert.ok(callData.notificationId);
        assert.ok(callData.expiresAt);
        assert.equal(callData.roomUrl, "");
        assert.equal(typeof callData.roomName, "string");
        assert.equal(callData.tokenStrategy, "accept_call");
        assert.equal(Object.hasOwn(callData, "meetingToken"), false);
        return {sent: true, channel: "test_voip"};
      },
    });
    const notificationQuery = await db
      .collection("notifications")
      .where("recipientId", "==", waitingUid)
      .get();
    const matchingNotifications = notificationQuery.docs
      .map((doc) => ({id: doc.id, data: doc.data()}))
      .filter((item) => item.data.sessionId === joiningResponse.sessionId);

    assert.equal(waitingResponse.status, "active");
    assert.equal(joiningResponse.status, "matched");
    assert.equal(joiningResponse.matchedUserId, waitingUid);
    assert.equal(matchingNotifications.length, 1);
    assert.equal(matchingNotifications[0].data.type, "incoming_call");
    assert.equal(matchingNotifications[0].data.status, "sent");
    assert.equal(matchingNotifications[0].data.recipientId, waitingUid);
    assert.equal(matchingNotifications[0].data.scenario, "student_student");
    assert.equal(matchingNotifications[0].data.requesterId, joiningUid);
    assert.equal(matchingNotifications[0].data.responderId, waitingUid);
    assert.equal(matchingNotifications[0].data.requesterRole, "student");
    assert.equal(matchingNotifications[0].data.responderRole, "student");
    assert.equal(matchingNotifications[0].data.navRole, "student");
    assert.equal(matchingNotifications[0].data.acceptMode, "responder_accepts");
    assert.equal(
      matchingNotifications[0].data.searchRequestId,
      waitingResponse.requestId,
    );
    assert.equal(
      matchingNotifications[0].data.callKitId,
      pushedCallData.callKitId,
    );
    assert.equal(
      matchingNotifications[0].data.notificationId,
      matchingNotifications[0].id,
    );
    assert.equal(
      matchingNotifications[0].data.tokenStrategy,
      "accept_call",
    );
    assert.equal(
      matchingNotifications[0].data.payloadExpiresAt,
      pushedCallData.expiresAt,
    );
    assert.equal(
      typeof matchingNotifications[0].data.expiresAt.toMillis,
      "function",
    );
    assert.equal(
      matchingNotifications[0].data.roomName,
      pushedCallData.roomName,
    );
    assert.equal(pushSendCount, 1);
    assert.equal(pushedCallData.sessionId, joiningResponse.sessionId);
    assert.equal(pushedCallData.notificationId, matchingNotifications[0].id);
    assert.equal(matchingNotifications[0].data.pushChannel, "test_voip");
    assert.ok(matchingNotifications[0].data.pushSentAt);
    assert.equal(
      matchingNotifications[0].data.studentInfo.name,
      "Joining Student",
    );
    assert.equal(
      matchingNotifications[0].data.studentInfo.photo,
      "joining-photo",
    );
    assert.equal(matchingNotifications[0].data.roomUrl, "");
    assert.equal(
      Object.hasOwn(matchingNotifications[0].data, "meetingToken"),
      false,
    );
  });

  test("declineCall restores student requester search", async () => {
    const {
      waitingUid,
      joiningUid,
      joiningResponse,
      notification,
    } = await createBackgroundStudentPair("student-decline-restore");

    const response = await wrappedDeclineCall({
      sessionId: joiningResponse.sessionId,
    }, authContext(waitingUid));

    const joiningRequest = (await searchRequestRef(joiningUid).get()).data();
    const waitingRequest = (await searchRequestRef(waitingUid).get()).data();
    const joiningUser = (await userRef(joiningUid).get()).data();
    const waitingUser = (await userRef(waitingUid).get()).data();
    const sessionData = (await db
      .collection("videoSessions")
      .doc(joiningResponse.sessionId)
      .get()).data();
    const notificationData = (await notification.ref.get()).data();

    assert.equal(response.status, "declined");
    assertSearchRequestRestoredToActive(joiningRequest, waitingUid);
    assertSearchRequestStopped(
      waitingRequest,
      SEARCH_REQUEST_STATUS.CANCELLED,
      "student_pair_declined",
    );
    assertUsersReleasedFromSession({waitingUser, joiningUser});
    assert.equal(sessionData.status, "cancelled");
    assert.equal(sessionData.pairStatus, "cancelled");
    assert.equal(sessionData.cancelReason, "student_pair_declined");
    assert.equal(sessionData.cancelledBy, waitingUid);
    assertTerminalSessionPairAudit(sessionData, joiningResponse, [
      joiningUid,
      waitingUid,
    ]);
    assert.equal(Object.hasOwn(sessionData, "currentResponderId"), false);
    assert.equal(Object.hasOwn(sessionData, "currentResponderRole"), false);
    assert.equal(Object.hasOwn(sessionData, "currentTutorId"), false);
    assert.ok(sessionData.triedTutors.includes(waitingUid));
    assert.equal(notificationData.status, "declined");
    assert.equal(typeof notificationData.declinedAt.toMillis, "function");
  });

  test("expired student responder notification restores requester search", async () => {
    const {
      waitingUid,
      joiningUid,
      joiningResponse,
      notification,
    } = await createBackgroundStudentPair("student-timeout-restore");

    await notification.ref.update({
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() - 1000),
    });
    await wrappedProcessExpiredNotifications();

    const joiningRequest = (await searchRequestRef(joiningUid).get()).data();
    const waitingRequest = (await searchRequestRef(waitingUid).get()).data();
    const joiningUser = (await userRef(joiningUid).get()).data();
    const waitingUser = (await userRef(waitingUid).get()).data();
    const sessionData = (await db
      .collection("videoSessions")
      .doc(joiningResponse.sessionId)
      .get()).data();
    const notificationData = (await notification.ref.get()).data();

    assertSearchRequestRestoredToActive(joiningRequest, waitingUid);
    assertSearchRequestStopped(
      waitingRequest,
      SEARCH_REQUEST_STATUS.EXPIRED,
      "student_pair_response_timeout",
    );
    assertUsersReleasedFromSession({waitingUser, joiningUser});
    assert.equal(sessionData.status, "expired");
    assert.equal(sessionData.pairStatus, "expired");
    assert.equal(sessionData.expireReason, "student_pair_response_timeout");
    assertTerminalSessionPairAudit(sessionData, joiningResponse, [
      joiningUid,
      waitingUid,
    ]);
    assert.equal(Object.hasOwn(sessionData, "currentResponderId"), false);
    assert.equal(Object.hasOwn(sessionData, "currentResponderRole"), false);
    assert.equal(Object.hasOwn(sessionData, "currentTutorId"), false);
    assert.ok(sessionData.triedTutors.includes(waitingUid));
    assert.equal(notificationData.status, "expired");
    assert.equal(typeof notificationData.expiredAt.toMillis, "function");
  });

  test("startSearch callable retries when background student push fails", async () => {
    const waitingUid = uniqueId("student-background-push-fail-waiting");
    const joiningUid = uniqueId("student-background-push-fail-joining");
    const cityKey = cityKeyForUid(`${waitingUid}-${joiningUid}`);
    await deleteDoc(userRef(waitingUid));
    await deleteDoc(userRef(joiningUid));
    await deleteDoc(searchRequestRef(waitingUid));
    await deleteDoc(searchRequestRef(joiningUid));
    await seedStudent(waitingUid, {
      display_name: "Waiting Student",
      profileCity: {key: cityKey},
    });
    await seedStudent(joiningUid, {
      display_name: "Joining Student",
      profileCity: {key: cityKey},
    });

    const waitingResponse = await wrappedStartSearch({
      preferredPartnerLevel: "B1",
      appState: "background",
      platform: "ios",
    }, authContext(waitingUid));
    let pushSendCount = 0;
    const joiningResponse = await startSearchCallable({
      preferredPartnerLevel: "B1",
      appState: "foreground",
      platform: "ios",
    }, authContext(joiningUid), {
      backgroundStudentResponderPushSender: async (responderId, callData) => {
        pushSendCount += 1;
        assert.equal(responderId, waitingUid);
        assert.equal(callData.callerId, joiningUid);
        return {
          sent: false,
          reason: "missing_tokens",
          error: "missing_tokens",
        };
      },
    });
    const joiningRequest = (await searchRequestRef(joiningUid).get()).data();
    const waitingRequest = (await searchRequestRef(waitingUid).get()).data();
    const notificationQuery = await db
      .collection("notifications")
      .where("recipientId", "==", waitingUid)
      .get();
    const matchingNotifications = notificationQuery.docs
      .map((doc) => ({id: doc.id, data: doc.data()}))
      .filter((item) => item.data.studentInfo?.name === "Joining Student");
    assert.equal(matchingNotifications.length, 1);
    const notification = matchingNotifications[0].data;
    const sessionSnapshot = await db
      .collection("videoSessions")
      .doc(notification.sessionId)
      .get();
    const sessionData = sessionSnapshot.data();

    assert.equal(waitingResponse.status, "active");
    assert.equal(joiningResponse.status, "active");
    assert.equal(joiningResponse.matchedUserId, undefined);
    assert.equal(pushSendCount, 1);
    assert.equal(joiningRequest.status, SEARCH_REQUEST_STATUS.ACTIVE);
    assert.deepEqual(joiningRequest.excludedCandidateIds, [waitingUid]);
    assert.equal(joiningRequest.currentSessionId, null);
    assert.equal(waitingRequest.status, SEARCH_REQUEST_STATUS.CANCELLED);
    assert.equal(notification.status, "cancelled");
    assert.equal(notification.cancelReason, "background_student_push_failed");
    assert.equal(notification.lastPushError, "missing_tokens");
    assert.equal(sessionSnapshot.exists, true);
    assert.equal(sessionData.status, "cancelled");
    assert.equal(sessionData.cancelReason, "background_student_push_failed");
  });

  test("startSearch callable matches teacher and creates incoming call", async () => {
    const studentUid = uniqueId("student-teacher-match");
    const teacherUid = uniqueId("teacher-start-search-match");
    const cityKey = cityKeyForUid(`${studentUid}-${teacherUid}`);
    await deleteDoc(userRef(studentUid));
    await deleteDoc(userRef(teacherUid));
    await deleteDoc(searchRequestRef(studentUid));
    await deleteDoc(searchRequestRef(teacherUid));
    await deleteDoc(db.collection("userPrivateTokens").doc(teacherUid));
    await seedStudent(studentUid, {
      display_name: "Student",
      photo_url: "student-photo",
      profileCity: {key: cityKey},
    });
    await seedTeacher(teacherUid, {
      display_name: "Teacher",
      photo_url: "teacher-photo",
      profileCity: {key: cityKey},
    });
    await db.collection("userPrivateTokens").doc(teacherUid).set({
      voipPushToken: `push-${teacherUid}`,
    });

    let teacherPushSendCount = 0;
    let teacherPushCallData = null;
    const response = await startSearchCallable({
      preferredPartnerLevel: "B1",
    }, authContext(studentUid), {
      teacherResponderPushSender: async (responderId, callData) => {
        teacherPushSendCount += 1;
        teacherPushCallData = callData;
        assert.equal(responderId, teacherUid);
        assert.equal(callData.callerId, studentUid);
        assert.equal(callData.callerName, "Student");
        assert.equal(callData.callerPhoto, "student-photo");
        assert.equal(callData.language, "en");
        assert.equal(callData.scenario, "student_teacher");
        assert.equal(callData.recipientId, teacherUid);
        assert.equal(callData.requesterId, studentUid);
        assert.equal(callData.responderId, teacherUid);
        assert.equal(callData.requesterRole, "student");
        assert.equal(callData.responderRole, "native_speaker");
        assert.equal(callData.navRole, "tutor");
        assert.equal(callData.acceptMode, "responder_accepts");
        assert.equal(callData.searchRequestId, "");
        assert.ok(callData.callKitId);
        assert.ok(callData.notificationId);
        assert.ok(callData.expiresAt);
        assert.equal(callData.roomUrl, "");
        assert.equal(typeof callData.roomName, "string");
        assert.equal(callData.tokenStrategy, "accept_call");
        assert.equal(Object.hasOwn(callData, "meetingToken"), false);
        return {sent: true, channel: "test"};
      },
    });
    const requestData = (await searchRequestRef(studentUid).get()).data();
    const teacherSearchSnapshot = await searchRequestRef(teacherUid).get();
    const sessionSnapshot = await db
      .collection("videoSessions")
      .doc(response.sessionId)
      .get();
    const sessionData = sessionSnapshot.data();
    const studentUser = (await userRef(studentUid).get()).data();
    const teacherUser = (await userRef(teacherUid).get()).data();
    const notificationQuery = await db
      .collection("notifications")
      .where("recipientId", "==", teacherUid)
      .get();
    const matchingNotifications = notificationQuery.docs
      .map((doc) => ({id: doc.id, data: doc.data()}))
      .filter((item) => item.data.sessionId === response.sessionId);
    const studentNotificationQuery = await db
      .collection("notifications")
      .where("recipientId", "==", studentUid)
      .get();

    assert.equal(response.status, "matched");
    assert.equal(response.matchedUserId, teacherUid);
    assert.equal(response.matchedRole, "native_speaker");
    assert.equal(response.scenario, "student_teacher");
    assert.equal(typeof response.sessionId, "string");
    assert.equal(typeof response.pairAttemptId, "string");
    assert.ok(response.requestId);
    assert.equal(typeof response.requestId, "string");
    assert.equal(requestData.requestId, response.requestId);
    assert.equal(requestData.status, "matched");
    assert.equal(requestData.currentSessionId, response.sessionId);
    assert.equal(requestData.matchedSessionId, response.sessionId);
    assert.equal(requestData.matchedUserId, teacherUid);
    assert.equal(requestData.matchedResponderId, teacherUid);
    assert.equal(requestData.matchedRole, "native_speaker");
    assert.equal(requestData.pairAttemptId, response.pairAttemptId);
    assert.equal(requestData.lockOwner, response.pairAttemptId);
    assert.equal(typeof requestData.lockExpiresAt.toMillis, "function");
    assert.equal(teacherSearchSnapshot.exists, false);
    assert.equal(sessionSnapshot.exists, true);
    assert.equal(sessionData.status, "pending_confirmation");
    assert.equal(sessionData.pairStatus, "pending_confirmation");
    assert.equal(sessionData.scenario, "student_teacher");
    assert.equal(sessionData.requesterId, studentUid);
    assert.equal(sessionData.requesterRole, "student");
    assert.equal(sessionData.studentId, studentUid);
    assert.equal(sessionData.responderId, teacherUid);
    assert.equal(sessionData.responderRole, "native_speaker");
    assert.equal(sessionData.currentResponderId, teacherUid);
    assert.equal(sessionData.currentTutorId, teacherUid);
    assert.equal(sessionData.currentResponderRole, "native_speaker");
    assert.equal(sessionData.tutorId, teacherUid);
    assert.equal(typeof sessionData.responseExpiresAt.toMillis, "function");
    assert.equal(typeof sessionData.confirmationExpiresAt.toMillis, "function");
    assert.deepEqual(
      sessionData.participantIds.slice().sort(),
      [studentUid, teacherUid].sort(),
    );
    assert.deepEqual(sessionData.participantRoles, {
      [studentUid]: "student",
      [teacherUid]: "native_speaker",
    });
    assert.deepEqual(sessionData.participantInfos, {
      [studentUid]: {
        displayName: "Student",
        photoUrl: "student-photo",
      },
      [teacherUid]: {
        displayName: "Teacher",
        photoUrl: "teacher-photo",
      },
    });
    assert.deepEqual(sessionData.requesterInfo, {
      displayName: "Student",
      photoUrl: "student-photo",
    });
    assert.deepEqual(sessionData.responderInfo, {
      displayName: "Teacher",
      photoUrl: "teacher-photo",
    });
    assert.deepEqual(sessionData.studentInfo, {
      name: "Student",
      photo: "student-photo",
    });
    assert.deepEqual(sessionData.tutorInfo, {
      name: "Teacher",
      photo: "teacher-photo",
    });
    assert.deepEqual(sessionData.searchRequestIds, {
      requester: response.requestId,
      responder: null,
    });
    assert.deepEqual(sessionData.availableTutors, [teacherUid]);
    assert.deepEqual(sessionData.triedTutors, [teacherUid]);
    assert.equal(sessionData.matchLock.owner, response.pairAttemptId);
    assert.equal(typeof sessionData.matchLock.expiresAt.toMillis, "function");
    assert.deepEqual(
      sessionData.matchLock.participantIds.slice().sort(),
      [studentUid, teacherUid].sort(),
    );
    assert.equal(sessionData.matchContext.requesterId, studentUid);
    assert.equal(sessionData.matchContext.requesterRole, "student");
    assert.equal(sessionData.matchContext.selectedResponderId, teacherUid);
    assert.equal(
      sessionData.matchContext.selectedResponderRole,
      "native_speaker",
    );
    assert.equal(
      sessionData.matchContext.selectedResponderSource,
      "teacher_availability",
    );
    assert.equal(
      sessionData.matchContext.selectedResponderSearchRequestId,
      null,
    );
    assert.deepEqual(
      sessionData.matchContext.candidateIds,
      [teacherUid],
    );
    assert.equal(matchingNotifications.length, 1);
    assert.equal(matchingNotifications[0].data.type, "incoming_call");
    assert.equal(matchingNotifications[0].data.status, "sent");
    assert.equal(matchingNotifications[0].data.recipientId, teacherUid);
    assert.equal(matchingNotifications[0].data.scenario, "student_teacher");
    assert.equal(matchingNotifications[0].data.requesterId, studentUid);
    assert.equal(matchingNotifications[0].data.responderId, teacherUid);
    assert.equal(matchingNotifications[0].data.requesterRole, "student");
    assert.equal(
      matchingNotifications[0].data.responderRole,
      "native_speaker",
    );
    assert.equal(matchingNotifications[0].data.navRole, "tutor");
    assert.equal(matchingNotifications[0].data.acceptMode, "responder_accepts");
    assert.equal(matchingNotifications[0].data.searchRequestId, "");
    assert.equal(
      matchingNotifications[0].data.callKitId,
      buildCallKitIdForSession(response.sessionId),
    );
    assert.equal(
      matchingNotifications[0].data.callKitId,
      teacherPushCallData.callKitId,
    );
    assert.equal(
      matchingNotifications[0].data.notificationId,
      matchingNotifications[0].id,
    );
    assert.equal(
      matchingNotifications[0].data.tokenStrategy,
      "accept_call",
    );
    assert.equal(
      matchingNotifications[0].data.payloadExpiresAt,
      teacherPushCallData.expiresAt,
    );
    assert.equal(
      typeof matchingNotifications[0].data.expiresAt.toMillis,
      "function",
    );
    assert.equal(
      matchingNotifications[0].data.roomName,
      teacherPushCallData.roomName,
    );
    assert.equal(teacherPushSendCount, 1);
    assert.equal(teacherPushCallData.sessionId, response.sessionId);
    assert.equal(teacherPushCallData.notificationId, matchingNotifications[0].id);
    assert.equal(matchingNotifications[0].data.pushChannel, "test");
    assert.equal(
      typeof matchingNotifications[0].data.pushSentAt.toMillis,
      "function",
    );
    assert.equal(
      matchingNotifications[0].data.studentInfo.name,
      "Student",
    );
    assert.equal(
      matchingNotifications[0].data.studentInfo.photo,
      "student-photo",
    );
    assert.equal(matchingNotifications[0].data.roomUrl, "");
    assert.equal(
      Object.hasOwn(matchingNotifications[0].data, "meetingToken"),
      false,
    );
    assert.equal(studentNotificationQuery.empty, true);
    assert.equal(studentUser.currentSessionId, response.sessionId);
    assert.equal(studentUser.isInCall, false);
    assert.equal(teacherUser.currentSessionId, response.sessionId);
    assert.equal(teacherUser.isInCall, false);
  });

  test("teacher responder accepts startSearch session", async () => {
    const studentUid = uniqueId("student-teacher-accept");
    const teacherUid = uniqueId("teacher-start-search-accept");
    const cityKey = cityKeyForUid(`${studentUid}-${teacherUid}`);
    await deleteDoc(userRef(studentUid));
    await deleteDoc(userRef(teacherUid));
    await deleteDoc(searchRequestRef(studentUid));
    await deleteDoc(searchRequestRef(teacherUid));
    await deleteDoc(db.collection("userPrivateTokens").doc(teacherUid));
    await seedStudent(studentUid, {
      display_name: "Student",
      photo_url: "student-photo",
      profileCity: {key: cityKey},
    });
    await seedTeacher(teacherUid, {
      display_name: "Teacher",
      photo_url: "teacher-photo",
      profileCity: {key: cityKey},
    });
    await db.collection("userPrivateTokens").doc(teacherUid).set({
      voipPushToken: `push-${teacherUid}`,
    });

    const response = await startSearchCallable({
      preferredPartnerLevel: "B1",
    }, authContext(studentUid), {
      teacherResponderPushSender: async (responderId) => {
        assert.equal(responderId, teacherUid);
        return {sent: true, channel: "test"};
      },
    });

    const acceptResponse = await withMockDailyApi(async (dailyCalls) => {
      const result = await wrappedAcceptCall({
        sessionId: response.sessionId,
      }, authContext(teacherUid));
      assert.equal(dailyCalls.length, 2);
      assert.equal(dailyCalls[0].url, "https://api.daily.co/v1/rooms");
      assert.equal(
        dailyCalls[1].url,
        "https://api.daily.co/v1/meeting-tokens",
      );
      return result;
    });

    const sessionSnapshot = await db
      .collection("videoSessions")
      .doc(response.sessionId)
      .get();
    const sessionData = sessionSnapshot.data();
    const studentUser = (await userRef(studentUid).get()).data();
    const teacherUser = (await userRef(teacherUid).get()).data();
    const requestData = (await searchRequestRef(studentUid).get()).data();
    const teacherNotifications = await db
      .collection("notifications")
      .where("recipientId", "==", teacherUid)
      .where("sessionId", "==", response.sessionId)
      .get();

    assert.equal(response.status, "matched");
    assert.equal(response.scenario, "student_teacher");
    assert.equal(response.matchedUserId, teacherUid);
    assert.equal(response.matchedRole, "native_speaker");
    assert.equal(acceptResponse.status, "connected");
    assert.equal(acceptResponse.sessionId, response.sessionId);
    assert.equal(
      acceptResponse.roomUrl,
      `https://smalltalk.daily.co/${acceptResponse.roomName}`,
    );
    assert.equal(
      acceptResponse.meetingToken,
      `token-${acceptResponse.roomName}-${teacherUid}`,
    );
    assert.equal(sessionSnapshot.exists, true);
    assert.equal(sessionData.status, "connecting");
    assert.equal(sessionData.tutorId, teacherUid);
    assert.equal(sessionData.responderId, teacherUid);
    assert.equal(sessionData.responderRole, "native_speaker");
    assert.equal(Object.hasOwn(sessionData, "currentResponderId"), false);
    assert.equal(Object.hasOwn(sessionData, "currentTutorId"), false);
    assert.equal(Object.hasOwn(sessionData, "currentResponderRole"), false);
    assert.equal(typeof sessionData.joinDeadlineAt.toMillis, "function");
    assert.equal(sessionData.dailyRoomUrl, acceptResponse.roomUrl);
    assert.equal(sessionData.dailyRoomName, acceptResponse.roomName);
    assert.deepEqual(
      sessionData.participantIds.slice().sort(),
      [studentUid, teacherUid].sort(),
    );
    assert.equal(
      sessionData.matchContext.acceptedResponderId,
      teacherUid,
    );
    assert.equal(
      sessionData.matchContext.acceptedResponderRole,
      "native_speaker",
    );
    assert.deepEqual(
      sessionData.matchContext.acceptedResponderInfo,
      {
        name: "Teacher",
        photo: "teacher-photo",
      },
    );
    assert.equal(studentUser.isInCall, true);
    assert.equal(studentUser.currentSessionId, response.sessionId);
    assert.equal(teacherUser.isInCall, true);
    assert.equal(teacherUser.currentSessionId, response.sessionId);
    assert.equal(requestData.status, "matched");
    assert.equal(requestData.currentSessionId, response.sessionId);
    assert.equal(teacherNotifications.size, 1);
    assert.equal(teacherNotifications.docs[0].data().status, "accepted");
  });

  test("direct teacher call accepts into connecting session", async () => {
    const studentUid = uniqueId("student-direct-accept");
    const teacherUid = uniqueId("teacher-direct-accept");
    const cityKey = cityKeyForUid(`${studentUid}-${teacherUid}`);
    await deleteDoc(userRef(studentUid));
    await deleteDoc(userRef(teacherUid));
    await deleteDoc(searchRequestRef(studentUid));
    await deleteDoc(searchRequestRef(teacherUid));
    await deleteDoc(db.collection("userPrivateTokens").doc(studentUid));
    await deleteDoc(db.collection("userPrivateTokens").doc(teacherUid));
    await seedStudent(studentUid, {
      display_name: "Student",
      photo_url: "student-photo",
      profileCity: {key: cityKey},
    });
    await seedTeacher(teacherUid, {
      display_name: "Teacher",
      photo_url: "teacher-photo",
      profileCity: {key: cityKey},
    });
    await db.collection("userPrivateTokens").doc(studentUid).set({
      voipToken: `fcm-${studentUid}`,
    });
    await db.collection("userPrivateTokens").doc(teacherUid).set({
      voipToken: `fcm-${teacherUid}`,
    });

    const sentPushes = [];
    const messaging = admin.messaging();
    const originalMessagingSend = messaging.send;
    messaging.send = async (message) => {
      sentPushes.push(message);
      return `mock-message-${sentPushes.length}`;
    };

    let createResponse = null;
    let acceptResponse = null;
    let pendingSessionData = null;
    try {
      await withMockDailyApi(async (dailyCalls) => {
        createResponse = await wrappedCreateVideoSession({
          directUserId: teacherUid,
        }, authContext(studentUid));
        const pendingSessionSnapshot = await db
          .collection("videoSessions")
          .doc(createResponse.sessionId)
          .get();
        pendingSessionData = pendingSessionSnapshot.data();
        const pendingStudentUser = (await userRef(studentUid).get()).data();
        const pendingTeacherUser = (await userRef(teacherUid).get()).data();
        const teacherNotifications = await db
          .collection("notifications")
          .where("recipientId", "==", teacherUid)
          .where("sessionId", "==", createResponse.sessionId)
          .get();

        assert.equal(createResponse.status, "calling");
        assert.equal(createResponse.matchedTutors, 1);
        assert.equal(typeof createResponse.sessionId, "string");
        assert.equal(dailyCalls.length, 1);
        assert.equal(dailyCalls[0].url, "https://api.daily.co/v1/rooms");
        assert.equal(pendingSessionSnapshot.exists, true);
        assert.equal(pendingSessionData.status, "pending_confirmation");
        assert.equal(pendingSessionData.pairStatus, "pending_confirmation");
        assert.equal(pendingSessionData.scenario, "student_teacher");
        assert.equal(pendingSessionData.requesterId, studentUid);
        assert.equal(pendingSessionData.responderId, teacherUid);
        assert.equal(pendingSessionData.responderRole, "native_speaker");
        assert.equal(pendingSessionData.currentResponderId, teacherUid);
        assert.equal(pendingSessionData.currentTutorId, teacherUid);
        assert.equal(
          pendingSessionData.currentResponderRole,
          "native_speaker",
        );
        assert.equal(pendingSessionData.matchContext.matchMode, "direct");
        assert.equal(pendingSessionData.matchContext.matcher, "directCall");
        assert.equal(pendingSessionData.matchContext.directTutorId, teacherUid);
        assert.equal(
          pendingSessionData.matchContext.directCandidateId,
          teacherUid,
        );
        assert.deepEqual(pendingSessionData.searchRequestIds, {
          requester: null,
          responder: null,
        });
        assert.equal(
          typeof pendingSessionData.responseExpiresAt.toMillis,
          "function",
        );
        assert.equal(
          typeof pendingSessionData.confirmationExpiresAt.toMillis,
          "function",
        );
        assert.equal(
          pendingStudentUser.currentSessionId,
          createResponse.sessionId,
        );
        assert.equal(pendingStudentUser.isInCall, false);
        assert.equal(
          pendingTeacherUser.currentSessionId,
          createResponse.sessionId,
        );
        assert.equal(pendingTeacherUser.isInCall, false);
        await assertNoSearchRequestForUser(studentUid);
        await assertNoSearchRequestForUser(teacherUid);
        assert.equal(teacherNotifications.size, 1);
        const teacherNotificationData = teacherNotifications.docs[0].data();
        assert.equal(teacherNotificationData.status, "sent");
        assert.equal(
          teacherNotificationData.acceptMode,
          "responder_accepts",
        );
        assert.equal(
          teacherNotificationData.tokenStrategy,
          "accept_call",
        );
        assert.equal(teacherNotificationData.searchRequestId, "");
        assert.equal(sentPushes.length, 1);
        const teacherPush = sentPushes[0];
        assert.equal(teacherPush.token, `fcm-${teacherUid}`);
        assert.equal(teacherPush.data.type, "incoming_call");
        assert.equal(teacherPush.data.sessionId, createResponse.sessionId);
        assert.equal(teacherPush.data.recipientId, teacherUid);
        assert.equal(teacherPush.data.callerId, studentUid);
        assert.equal(teacherPush.data.requesterId, studentUid);
        assert.equal(teacherPush.data.responderId, teacherUid);
        assert.equal(teacherPush.data.requesterRole, "student");
        assert.equal(teacherPush.data.responderRole, "native_speaker");
        assert.equal(teacherPush.data.navRole, "tutor");
        assert.equal(teacherPush.data.acceptMode, "responder_accepts");
        assert.equal(teacherPush.data.tokenStrategy, "accept_call");
        assert.equal(
          teacherPush.data.callKitId,
          buildCallKitIdForSession(createResponse.sessionId),
        );
        assert.equal(
          teacherPush.data.notificationId,
          teacherNotifications.docs[0].id,
        );
        assert.equal(teacherPush.data.searchRequestId, "");
        assert.equal(teacherPush.data.roomUrl, "");

        acceptResponse = await wrappedAcceptCall({
          sessionId: createResponse.sessionId,
        }, authContext(teacherUid));
        assert.equal(dailyCalls.length, 2);
        assert.equal(
          dailyCalls[1].url,
          "https://api.daily.co/v1/meeting-tokens",
        );
      });
    } finally {
      messaging.send = originalMessagingSend;
    }

    const sessionSnapshot = await db
      .collection("videoSessions")
      .doc(createResponse.sessionId)
      .get();
    const sessionData = sessionSnapshot.data();
    const studentUser = (await userRef(studentUid).get()).data();
    const teacherUser = (await userRef(teacherUid).get()).data();
    const teacherNotifications = await db
      .collection("notifications")
      .where("recipientId", "==", teacherUid)
      .where("sessionId", "==", createResponse.sessionId)
      .get();

    assert.equal(acceptResponse.status, "connected");
    assert.equal(acceptResponse.sessionId, createResponse.sessionId);
    assert.equal(acceptResponse.roomUrl, pendingSessionData.dailyRoomUrl);
    assert.equal(acceptResponse.roomName, pendingSessionData.dailyRoomName);
    assert.equal(
      acceptResponse.meetingToken,
      `token-${acceptResponse.roomName}-${teacherUid}`,
    );
    assert.equal(sessionSnapshot.exists, true);
    assert.equal(sessionData.status, "connecting");
    assert.equal(sessionData.tutorId, teacherUid);
    assert.equal(sessionData.responderId, teacherUid);
    assert.equal(sessionData.responderRole, "native_speaker");
    assert.equal(Object.hasOwn(sessionData, "currentResponderId"), false);
    assert.equal(Object.hasOwn(sessionData, "currentTutorId"), false);
    assert.equal(Object.hasOwn(sessionData, "currentResponderRole"), false);
    assert.equal(typeof sessionData.joinDeadlineAt.toMillis, "function");
    assert.equal(sessionData.dailyRoomUrl, acceptResponse.roomUrl);
    assert.equal(sessionData.dailyRoomName, acceptResponse.roomName);
    assert.deepEqual(
      sessionData.participantIds.slice().sort(),
      [studentUid, teacherUid].sort(),
    );
    assert.deepEqual(sessionData.searchRequestIds, {
      requester: null,
      responder: null,
    });
    assert.equal(sessionData.matchContext.matchMode, "direct");
    assert.equal(sessionData.matchContext.acceptedResponderId, teacherUid);
    assert.equal(
      sessionData.matchContext.acceptedResponderRole,
      "native_speaker",
    );
    assert.deepEqual(sessionData.matchContext.acceptedResponderInfo, {
      name: "Teacher",
      photo: "teacher-photo",
    });
    assert.equal(studentUser.isInCall, true);
    assert.equal(studentUser.currentSessionId, createResponse.sessionId);
    assert.equal(teacherUser.isInCall, true);
    assert.equal(teacherUser.currentSessionId, createResponse.sessionId);
    assert.equal(teacherNotifications.size, 1);
    assert.equal(teacherNotifications.docs[0].data().status, "accepted");
    assert.equal(
      typeof teacherNotifications.docs[0].data().acceptedAt.toMillis,
      "function",
    );
    await assertNoSearchRequestForUser(studentUid);
    await assertNoSearchRequestForUser(teacherUid);
    assert.equal(sentPushes.length, 2);
    const studentPush = sentPushes[1];
    assert.equal(studentPush.token, `fcm-${studentUid}`);
    assert.equal(studentPush.data.type, "incoming_call");
    assert.equal(studentPush.data.sessionId, createResponse.sessionId);
    assert.equal(studentPush.data.recipientId, studentUid);
    assert.equal(studentPush.data.callerId, teacherUid);
    assert.equal(studentPush.data.scenario, "student_teacher");
    assert.equal(studentPush.data.requesterId, studentUid);
    assert.equal(studentPush.data.responderId, teacherUid);
    assert.equal(studentPush.data.requesterRole, "student");
    assert.equal(studentPush.data.responderRole, "native_speaker");
    assert.equal(studentPush.data.navRole, "student");
    assert.equal(studentPush.data.acceptMode, "open_session");
    assert.equal(
      studentPush.data.callKitId,
      buildCallKitIdForSession(createResponse.sessionId),
    );
    assert.equal(studentPush.data.searchRequestId, "");
    assert.equal(studentPush.data.roomUrl, acceptResponse.roomUrl);
    assert.equal(studentPush.data.roomName, acceptResponse.roomName);
    assert.equal(studentPush.data.meetingToken, "");
    assert.equal(studentPush.data.tokenStrategy, "payload_room");
  });

  test("direct teacher call decline cancels without search restore", async () => {
    const studentUid = uniqueId("student-direct-decline");
    const teacherUid = uniqueId("teacher-direct-decline");
    const otherTeacherUid = uniqueId("teacher-direct-decline-other");
    const cityKey = cityKeyForUid(
      `${studentUid}-${teacherUid}-${otherTeacherUid}`,
    );
    await deleteDoc(userRef(studentUid));
    await deleteDoc(userRef(teacherUid));
    await deleteDoc(userRef(otherTeacherUid));
    await deleteDoc(searchRequestRef(studentUid));
    await deleteDoc(searchRequestRef(teacherUid));
    await deleteDoc(searchRequestRef(otherTeacherUid));
    await deleteDoc(db.collection("userPrivateTokens").doc(studentUid));
    await deleteDoc(db.collection("userPrivateTokens").doc(teacherUid));
    await deleteDoc(db.collection("userPrivateTokens").doc(otherTeacherUid));
    await seedStudent(studentUid, {
      display_name: "Student",
      photo_url: "student-photo",
      profileCity: {key: cityKey},
    });
    await seedTeacher(teacherUid, {
      display_name: "Teacher",
      photo_url: "teacher-photo",
      profileCity: {key: cityKey},
    });
    await seedTeacher(otherTeacherUid, {
      display_name: "Other Teacher",
      photo_url: "other-teacher-photo",
      profileCity: {key: cityKey},
      availableSince: admin.firestore.Timestamp.fromMillis(Date.now() - 1000),
    });
    await db.collection("userPrivateTokens").doc(studentUid).set({
      voipToken: `fcm-${studentUid}`,
    });
    await db.collection("userPrivateTokens").doc(teacherUid).set({
      voipToken: `fcm-${teacherUid}`,
    });
    await db.collection("userPrivateTokens").doc(otherTeacherUid).set({
      voipToken: `fcm-${otherTeacherUid}`,
    });

    const sentPushes = [];
    const messaging = admin.messaging();
    const originalMessagingSend = messaging.send;
    messaging.send = async (message) => {
      sentPushes.push(message);
      return `mock-message-${sentPushes.length}`;
    };

    let createResponse = null;
    let declineResponse = null;
    let pendingSessionData = null;
    try {
      await withMockDailyApi(async (dailyCalls) => {
        createResponse = await wrappedCreateVideoSession({
          directUserId: teacherUid,
        }, authContext(studentUid));
        const pendingSessionSnapshot = await db
          .collection("videoSessions")
          .doc(createResponse.sessionId)
          .get();
        pendingSessionData = pendingSessionSnapshot.data();
        const pendingStudentUser = (await userRef(studentUid).get()).data();
        const pendingTeacherUser = (await userRef(teacherUid).get()).data();
        const teacherNotifications = await db
          .collection("notifications")
          .where("recipientId", "==", teacherUid)
          .where("sessionId", "==", createResponse.sessionId)
          .get();

        assert.equal(createResponse.status, "calling");
        assert.equal(createResponse.matchedTutors, 1);
        assert.equal(dailyCalls.length, 1);
        assert.equal(dailyCalls[0].method, "post");
        assert.equal(dailyCalls[0].url, "https://api.daily.co/v1/rooms");
        const createdRoomName = dailyCalls[0].body?.name;
        assert.equal(typeof createdRoomName, "string");
        assert.notEqual(createdRoomName, "");
        assert.equal(pendingSessionSnapshot.exists, true);
        assert.equal(pendingSessionData.status, "pending_confirmation");
        assert.equal(pendingSessionData.pairStatus, "pending_confirmation");
        assert.equal(pendingSessionData.scenario, "student_teacher");
        assert.equal(pendingSessionData.requesterId, studentUid);
        assert.equal(pendingSessionData.responderId, teacherUid);
        assert.equal(pendingSessionData.responderRole, "native_speaker");
        assert.equal(pendingSessionData.dailyRoomName, createdRoomName);
        assert.equal(
          pendingSessionData.dailyRoomUrl,
          `https://smalltalk.daily.co/${createdRoomName}`,
        );
        assert.equal(pendingSessionData.currentResponderId, teacherUid);
        assert.equal(pendingSessionData.currentTutorId, teacherUid);
        assert.equal(
          pendingSessionData.currentResponderRole,
          "native_speaker",
        );
        assert.equal(pendingSessionData.matchContext.matchMode, "direct");
        assert.equal(pendingSessionData.matchContext.matcher, "directCall");
        assert.deepEqual(pendingSessionData.searchRequestIds, {
          requester: null,
          responder: null,
        });
        assert.equal(
          pendingStudentUser.currentSessionId,
          createResponse.sessionId,
        );
        assert.equal(pendingStudentUser.isInCall, false);
        assert.equal(
          pendingTeacherUser.currentSessionId,
          createResponse.sessionId,
        );
        assert.equal(pendingTeacherUser.isInCall, false);
        await assertNoSearchRequestForUser(studentUid);
        await assertNoSearchRequestForUser(teacherUid);
        assert.equal(teacherNotifications.size, 1);
        const teacherNotificationData = teacherNotifications.docs[0].data();
        assert.equal(teacherNotificationData.status, "sent");
        assert.equal(
          teacherNotificationData.acceptMode,
          "responder_accepts",
        );
        assert.equal(
          teacherNotificationData.tokenStrategy,
          "accept_call",
        );
        assert.equal(sentPushes.length, 1);
        const teacherPush = sentPushes[0];
        assert.equal(teacherPush.token, `fcm-${teacherUid}`);
        assert.equal(teacherPush.data.sessionId, createResponse.sessionId);
        assert.equal(teacherPush.data.recipientId, teacherUid);
        assert.equal(teacherPush.data.callerId, studentUid);
        assert.equal(teacherPush.data.acceptMode, "responder_accepts");
        assert.equal(teacherPush.data.tokenStrategy, "accept_call");

        declineResponse = await wrappedDeclineCall({
          sessionId: createResponse.sessionId,
        }, authContext(teacherUid));
        assert.equal(dailyCalls.length, 2);
        assert.equal(dailyCalls[1].method, "delete");
        assert.equal(
          dailyCalls[1].url,
          `https://api.daily.co/v1/rooms/${
            encodeURIComponent(createdRoomName)
          }`,
        );
      });
    } finally {
      messaging.send = originalMessagingSend;
    }

    const sessionSnapshot = await db
      .collection("videoSessions")
      .doc(createResponse.sessionId)
      .get();
    const sessionData = sessionSnapshot.data();
    const studentUser = (await userRef(studentUid).get()).data();
    const teacherUser = (await userRef(teacherUid).get()).data();
    const otherTeacherUser = (await userRef(otherTeacherUid).get()).data();
    const teacherNotifications = await db
      .collection("notifications")
      .where("recipientId", "==", teacherUid)
      .where("sessionId", "==", createResponse.sessionId)
      .get();
    const sessionNotifications = await db
      .collection("notifications")
      .where("sessionId", "==", createResponse.sessionId)
      .get();
    const otherTeacherNotifications = await db
      .collection("notifications")
      .where("recipientId", "==", otherTeacherUid)
      .where("sessionId", "==", createResponse.sessionId)
      .get();

    assert.equal(declineResponse.status, "declined");
    assert.equal(sessionSnapshot.exists, true);
    assert.equal(sessionData.status, "cancelled");
    assert.equal(sessionData.pairStatus, "cancelled");
    assert.equal(sessionData.cancelledBy, teacherUid);
    assert.equal(sessionData.cancelReason, "direct_call_declined");
    assert.equal(typeof sessionData.cancelledAt.toMillis, "function");
    assert.equal(typeof sessionData.endedAt.toMillis, "function");
    assert.equal(Object.hasOwn(sessionData, "currentResponderId"), false);
    assert.equal(Object.hasOwn(sessionData, "currentTutorId"), false);
    assert.equal(Object.hasOwn(sessionData, "currentResponderRole"), false);
    assert.deepEqual(sessionData.triedTutors, [teacherUid]);
    assert.deepEqual(sessionData.searchRequestIds, {
      requester: null,
      responder: null,
    });
    assert.equal(sessionData.matchContext.matchMode, "direct");
    assert.equal(sessionData.matchContext.directTutorId, teacherUid);
    assert.equal(
      sessionData.sessionMetadata.dailyRoomDeleteSource,
      "declineCall_no_tutors",
    );
    assert.equal(
      sessionData.sessionMetadata.dailyRoomDeleteRoomName,
      pendingSessionData.dailyRoomName,
    );
    assert.equal(
      typeof sessionData.sessionMetadata.dailyRoomDeletedAt.toMillis,
      "function",
    );
    assert.equal(Object.hasOwn(studentUser, "currentSessionId"), false);
    assert.equal(Object.hasOwn(teacherUser, "currentSessionId"), false);
    assert.equal(studentUser.isInCall, false);
    assert.equal(teacherUser.isInCall, false);
    assert.equal(otherTeacherUser.currentSessionId, "");
    assert.equal(otherTeacherUser.isInCall, false);
    await assertNoSearchRequestForUser(studentUid);
    await assertNoSearchRequestForUser(teacherUid);
    await assertNoSearchRequestForUser(otherTeacherUid);
    assert.equal(sessionNotifications.size, 1);
    assert.equal(teacherNotifications.size, 1);
    assert.equal(otherTeacherNotifications.size, 0);
    assert.equal(teacherNotifications.docs[0].data().status, "declined");
    assert.equal(
      typeof teacherNotifications.docs[0].data().declinedAt.toMillis,
      "function",
    );
    assert.equal(sentPushes.length, 1);
  });

  test("direct teacher call timeout expires without search restore", async () => {
    const studentUid = uniqueId("student-direct-timeout");
    const teacherUid = uniqueId("teacher-direct-timeout");
    const otherTeacherUid = uniqueId("teacher-direct-timeout-other");
    const cityKey = cityKeyForUid(
      `${studentUid}-${teacherUid}-${otherTeacherUid}`,
    );
    await deleteDoc(userRef(studentUid));
    await deleteDoc(userRef(teacherUid));
    await deleteDoc(userRef(otherTeacherUid));
    await deleteDoc(searchRequestRef(studentUid));
    await deleteDoc(searchRequestRef(teacherUid));
    await deleteDoc(searchRequestRef(otherTeacherUid));
    await deleteDoc(db.collection("userPrivateTokens").doc(studentUid));
    await deleteDoc(db.collection("userPrivateTokens").doc(teacherUid));
    await deleteDoc(db.collection("userPrivateTokens").doc(otherTeacherUid));
    await seedStudent(studentUid, {
      display_name: "Student",
      photo_url: "student-photo",
      profileCity: {key: cityKey},
    });
    await seedTeacher(teacherUid, {
      display_name: "Teacher",
      photo_url: "teacher-photo",
      profileCity: {key: cityKey},
    });
    await seedTeacher(otherTeacherUid, {
      display_name: "Other Teacher",
      photo_url: "other-teacher-photo",
      profileCity: {key: cityKey},
      availableSince: admin.firestore.Timestamp.fromMillis(Date.now() - 1000),
    });
    await db.collection("userPrivateTokens").doc(studentUid).set({
      voipToken: `fcm-${studentUid}`,
    });
    await db.collection("userPrivateTokens").doc(teacherUid).set({
      voipToken: `fcm-${teacherUid}`,
    });
    await db.collection("userPrivateTokens").doc(otherTeacherUid).set({
      voipToken: `fcm-${otherTeacherUid}`,
    });

    const sentPushes = [];
    const messaging = admin.messaging();
    const originalMessagingSend = messaging.send;
    messaging.send = async (message) => {
      sentPushes.push(message);
      return `mock-message-${sentPushes.length}`;
    };

    let createResponse = null;
    let pendingSessionData = null;
    let createdRoomName = null;
    try {
      await withMockDailyApi(async (dailyCalls) => {
        createResponse = await wrappedCreateVideoSession({
          directUserId: teacherUid,
        }, authContext(studentUid));
        const teacherNotifications = await db
          .collection("notifications")
          .where("recipientId", "==", teacherUid)
          .where("sessionId", "==", createResponse.sessionId)
          .get();
        assert.equal(teacherNotifications.size, 1);
        const teacherNotificationRef = teacherNotifications.docs[0].ref;
        const pendingNotificationData = teacherNotifications.docs[0].data();
        const pendingSessionSnapshot = await db
          .collection("videoSessions")
          .doc(createResponse.sessionId)
          .get();
        pendingSessionData = pendingSessionSnapshot.data();
        const pendingStudentUser = (await userRef(studentUid).get()).data();
        const pendingTeacherUser = (await userRef(teacherUid).get()).data();

        assert.equal(createResponse.status, "calling");
        assert.equal(createResponse.matchedTutors, 1);
        assert.equal(dailyCalls.length, 1);
        assert.equal(dailyCalls[0].method, "post");
        assert.equal(dailyCalls[0].url, "https://api.daily.co/v1/rooms");
        createdRoomName = dailyCalls[0].body?.name;
        assert.equal(typeof createdRoomName, "string");
        assert.notEqual(createdRoomName, "");
        assert.equal(pendingSessionSnapshot.exists, true);
        assert.equal(pendingSessionData.status, "pending_confirmation");
        assert.equal(pendingSessionData.pairStatus, "pending_confirmation");
        assert.equal(pendingSessionData.scenario, "student_teacher");
        assert.equal(pendingSessionData.requesterId, studentUid);
        assert.equal(pendingSessionData.responderId, teacherUid);
        assert.equal(pendingSessionData.responderRole, "native_speaker");
        assert.equal(pendingSessionData.dailyRoomName, createdRoomName);
        assert.equal(
          pendingSessionData.dailyRoomUrl,
          `https://smalltalk.daily.co/${createdRoomName}`,
        );
        assert.equal(pendingSessionData.currentResponderId, teacherUid);
        assert.equal(pendingSessionData.currentTutorId, teacherUid);
        assert.equal(
          pendingSessionData.currentResponderRole,
          "native_speaker",
        );
        assert.equal(pendingSessionData.matchContext.matchMode, "direct");
        assert.equal(pendingSessionData.matchContext.matcher, "directCall");
        assert.deepEqual(pendingSessionData.searchRequestIds, {
          requester: null,
          responder: null,
        });
        assert.equal(
          typeof pendingSessionData.responseExpiresAt.toMillis,
          "function",
        );
        assert.equal(
          pendingSessionData.responseExpiresAt.toMillis(),
          pendingSessionData.confirmationExpiresAt.toMillis(),
        );
        assert.ok(
          Math.abs(
            pendingNotificationData.expiresAt.toMillis() -
              pendingSessionData.responseExpiresAt.toMillis(),
          ) < 1000,
        );
        assert.equal(
          pendingStudentUser.currentSessionId,
          createResponse.sessionId,
        );
        assert.equal(pendingStudentUser.isInCall, false);
        assert.equal(
          pendingTeacherUser.currentSessionId,
          createResponse.sessionId,
        );
        assert.equal(pendingTeacherUser.isInCall, false);
        await assertNoSearchRequestForUser(studentUid);
        await assertNoSearchRequestForUser(teacherUid);
        await assertNoSearchRequestForUser(otherTeacherUid);
        assert.equal(pendingNotificationData.status, "sent");
        assert.equal(
          pendingNotificationData.acceptMode,
          "responder_accepts",
        );
        assert.equal(
          pendingNotificationData.tokenStrategy,
          "accept_call",
        );
        assert.equal(sentPushes.length, 1);
        const teacherPush = sentPushes[0];
        assert.equal(teacherPush.token, `fcm-${teacherUid}`);
        assert.equal(teacherPush.data.sessionId, createResponse.sessionId);
        assert.equal(teacherPush.data.recipientId, teacherUid);
        assert.equal(teacherPush.data.callerId, studentUid);
        assert.equal(teacherPush.data.acceptMode, "responder_accepts");
        assert.equal(teacherPush.data.tokenStrategy, "accept_call");

        await teacherNotificationRef.update({
          expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() - 1000),
        });
        await wrappedProcessExpiredNotifications();
        assert.equal(dailyCalls.length, 2);
        assert.equal(dailyCalls[1].method, "delete");
        assert.equal(
          dailyCalls[1].url,
          `https://api.daily.co/v1/rooms/${
            encodeURIComponent(createdRoomName)
          }`,
        );
      });
    } finally {
      messaging.send = originalMessagingSend;
    }

    const sessionSnapshot = await db
      .collection("videoSessions")
      .doc(createResponse.sessionId)
      .get();
    const sessionData = sessionSnapshot.data();
    const studentUser = (await userRef(studentUid).get()).data();
    const teacherUser = (await userRef(teacherUid).get()).data();
    const otherTeacherUser = (await userRef(otherTeacherUid).get()).data();
    const teacherNotifications = await db
      .collection("notifications")
      .where("recipientId", "==", teacherUid)
      .where("sessionId", "==", createResponse.sessionId)
      .get();
    const sessionNotifications = await db
      .collection("notifications")
      .where("sessionId", "==", createResponse.sessionId)
      .get();
    const otherTeacherNotifications = await db
      .collection("notifications")
      .where("recipientId", "==", otherTeacherUid)
      .where("sessionId", "==", createResponse.sessionId)
      .get();

    assert.equal(sessionSnapshot.exists, true);
    assert.equal(sessionData.status, "expired");
    assert.equal(sessionData.pairStatus, "expired");
    assert.equal(sessionData.expireReason, "direct_call_timeout");
    assert.equal(typeof sessionData.expiredAt.toMillis, "function");
    assert.equal(typeof sessionData.endedAt.toMillis, "function");
    assert.equal(Object.hasOwn(sessionData, "currentResponderId"), false);
    assert.equal(Object.hasOwn(sessionData, "currentTutorId"), false);
    assert.equal(Object.hasOwn(sessionData, "currentResponderRole"), false);
    assert.deepEqual(sessionData.triedTutors, [teacherUid]);
    assert.deepEqual(sessionData.searchRequestIds, {
      requester: null,
      responder: null,
    });
    assert.equal(sessionData.matchContext.matchMode, "direct");
    assert.equal(sessionData.matchContext.directTutorId, teacherUid);
    assert.equal(
      sessionData.sessionMetadata.dailyRoomDeleteSource,
      "processExpiredNotifications",
    );
    assert.equal(
      sessionData.sessionMetadata.dailyRoomDeleteRoomName,
      createdRoomName,
    );
    assert.equal(
      typeof sessionData.sessionMetadata.dailyRoomDeletedAt.toMillis,
      "function",
    );
    assert.equal(Object.hasOwn(studentUser, "currentSessionId"), false);
    assert.equal(Object.hasOwn(teacherUser, "currentSessionId"), false);
    assert.equal(studentUser.isInCall, false);
    assert.equal(teacherUser.isInCall, false);
    assert.equal(otherTeacherUser.currentSessionId, "");
    assert.equal(otherTeacherUser.isInCall, false);
    await assertNoSearchRequestForUser(studentUid);
    await assertNoSearchRequestForUser(teacherUid);
    await assertNoSearchRequestForUser(otherTeacherUid);
    assert.equal(sessionNotifications.size, 1);
    assert.equal(teacherNotifications.size, 1);
    assert.equal(otherTeacherNotifications.size, 0);
    assert.equal(teacherNotifications.docs[0].data().status, "expired");
    assert.equal(
      typeof teacherNotifications.docs[0].data().expiredAt.toMillis,
      "function",
    );
    assert.equal(sentPushes.length, 1);
  });

  test("teacher responder decline restores student search", async () => {
    const studentUid = uniqueId("student-teacher-decline");
    const teacherUid = uniqueId("teacher-start-search-decline");
    const cityKey = cityKeyForUid(`${studentUid}-${teacherUid}`);
    await deleteDoc(userRef(studentUid));
    await deleteDoc(userRef(teacherUid));
    await deleteDoc(searchRequestRef(studentUid));
    await deleteDoc(searchRequestRef(teacherUid));
    await deleteDoc(db.collection("userPrivateTokens").doc(teacherUid));
    await seedStudent(studentUid, {
      display_name: "Student",
      photo_url: "student-photo",
      profileCity: {key: cityKey},
    });
    await seedTeacher(teacherUid, {
      display_name: "Teacher",
      photo_url: "teacher-photo",
      profileCity: {key: cityKey},
    });
    await db.collection("userPrivateTokens").doc(teacherUid).set({
      voipPushToken: `push-${teacherUid}`,
    });

    const response = await startSearchCallable({
      preferredPartnerLevel: "B1",
    }, authContext(studentUid), {
      teacherResponderPushSender: async (responderId) => {
        assert.equal(responderId, teacherUid);
        return {sent: true, channel: "test"};
      },
    });
    const declineResponse = await wrappedDeclineCall({
      sessionId: response.sessionId,
    }, authContext(teacherUid));

    const sessionSnapshot = await db
      .collection("videoSessions")
      .doc(response.sessionId)
      .get();
    const sessionData = sessionSnapshot.data();
    const requestData = (await searchRequestRef(studentUid).get()).data();
    const studentUser = (await userRef(studentUid).get()).data();
    const teacherUser = (await userRef(teacherUid).get()).data();
    const teacherNotifications = await db
      .collection("notifications")
      .where("recipientId", "==", teacherUid)
      .where("sessionId", "==", response.sessionId)
      .get();

    assert.equal(response.status, "matched");
    assert.equal(response.scenario, "student_teacher");
    assert.equal(response.matchedUserId, teacherUid);
    assert.equal(response.matchedRole, "native_speaker");
    assert.equal(declineResponse.status, "declined");
    assert.equal(sessionSnapshot.exists, true);
    assert.equal(sessionData.status, "cancelled");
    assert.equal(sessionData.pairStatus, "cancelled");
    assert.equal(sessionData.cancelledBy, teacherUid);
    assert.equal(sessionData.cancelReason, "no_available_responder_after_decline");
    assert.equal(Object.hasOwn(sessionData, "currentResponderId"), false);
    assert.equal(Object.hasOwn(sessionData, "currentTutorId"), false);
    assert.equal(Object.hasOwn(sessionData, "currentResponderRole"), false);
    assert.deepEqual(sessionData.triedTutors, [teacherUid]);
    assertSearchRequestRestoredToActive(requestData, teacherUid);
    assert.equal(requestData.stoppedAt, null);
    assert.equal(Object.hasOwn(requestData, "stoppedBy"), false);
    assert.equal(Object.hasOwn(studentUser, "currentSessionId"), false);
    assert.equal(Object.hasOwn(teacherUser, "currentSessionId"), false);
    assert.equal(studentUser.isInCall, false);
    assert.equal(teacherUser.isInCall, false);
    assert.equal(teacherNotifications.size, 1);
    assert.equal(teacherNotifications.docs[0].data().status, "declined");
    assert.equal(
      typeof teacherNotifications.docs[0].data().declinedAt.toMillis,
      "function",
    );
  });

  test(
    "expired teacher responder notification restores student search",
    async () => {
      const studentUid = uniqueId("student-teacher-timeout");
      const teacherUid = uniqueId("teacher-start-search-timeout");
      const cityKey = cityKeyForUid(`${studentUid}-${teacherUid}`);
      await deleteDoc(userRef(studentUid));
      await deleteDoc(userRef(teacherUid));
      await deleteDoc(searchRequestRef(studentUid));
      await deleteDoc(searchRequestRef(teacherUid));
      await deleteDoc(db.collection("userPrivateTokens").doc(teacherUid));
      await seedStudent(studentUid, {
        display_name: "Student",
        photo_url: "student-photo",
        profileCity: {key: cityKey},
      });
      await seedTeacher(teacherUid, {
        display_name: "Teacher",
        photo_url: "teacher-photo",
        profileCity: {key: cityKey},
      });
      await db.collection("userPrivateTokens").doc(teacherUid).set({
        voipPushToken: `push-${teacherUid}`,
      });

      const startSearchStartedAtMillis = Date.now();
      const response = await startSearchCallable({
        preferredPartnerLevel: "B1",
      }, authContext(studentUid), {
        teacherResponderPushSender: async (responderId) => {
          assert.equal(responderId, teacherUid);
          return {sent: true, channel: "test"};
        },
      });
      const startSearchCompletedAtMillis = Date.now();
      const teacherNotifications = await db
        .collection("notifications")
        .where("recipientId", "==", teacherUid)
        .where("sessionId", "==", response.sessionId)
        .get();
      assert.equal(teacherNotifications.size, 1);
      const teacherNotificationRef = teacherNotifications.docs[0].ref;
      const pendingNotificationData = teacherNotifications.docs[0].data();
      const pendingSessionData = (
        await db.collection("videoSessions").doc(response.sessionId).get()
      ).data();
      const responseWindowMillis = MATCH_PAIR_LOCK_TTL_SECONDS * 1000;
      const notificationExpiresAtMillis =
        pendingNotificationData.expiresAt.toMillis();
      const sessionResponseExpiresAtMillis =
        pendingSessionData.responseExpiresAt.toMillis();
      assert.equal(
        sessionResponseExpiresAtMillis,
        pendingSessionData.confirmationExpiresAt.toMillis(),
      );
      assert.equal(
        sessionResponseExpiresAtMillis,
        pendingSessionData.matchLock.expiresAt.toMillis(),
      );
      assert.ok(
        sessionResponseExpiresAtMillis >=
          startSearchStartedAtMillis + responseWindowMillis,
      );
      assert.ok(
        sessionResponseExpiresAtMillis <=
          startSearchCompletedAtMillis + responseWindowMillis,
      );
      assert.ok(
        notificationExpiresAtMillis >=
          startSearchStartedAtMillis + responseWindowMillis,
      );
      assert.ok(
        notificationExpiresAtMillis <=
          startSearchCompletedAtMillis + responseWindowMillis,
      );
      await teacherNotificationRef.update({
        expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() - 1000),
      });
      await wrappedProcessExpiredNotifications();

      const sessionSnapshot = await db
        .collection("videoSessions")
        .doc(response.sessionId)
        .get();
      const sessionData = sessionSnapshot.data();
      const requestData = (await searchRequestRef(studentUid).get()).data();
      const studentUser = (await userRef(studentUid).get()).data();
      const teacherUser = (await userRef(teacherUid).get()).data();
      const notificationData = (await teacherNotificationRef.get()).data();

      assert.equal(response.status, "matched");
      assert.equal(response.scenario, "student_teacher");
      assert.equal(response.matchedUserId, teacherUid);
      assert.equal(response.matchedRole, "native_speaker");
      assert.equal(sessionSnapshot.exists, true);
      assert.equal(sessionData.status, "expired");
      assert.equal(sessionData.pairStatus, "expired");
      assert.equal(
        sessionData.expireReason,
        "no_available_responder_after_timeout",
      );
      assert.equal(Object.hasOwn(sessionData, "currentResponderId"), false);
      assert.equal(Object.hasOwn(sessionData, "currentTutorId"), false);
      assert.equal(Object.hasOwn(sessionData, "currentResponderRole"), false);
      assert.deepEqual(sessionData.triedTutors, [teacherUid]);
      assertSearchRequestRestoredToActive(requestData, teacherUid);
      assert.equal(requestData.stoppedAt, null);
      assert.equal(Object.hasOwn(requestData, "stoppedBy"), false);
      assert.equal(Object.hasOwn(studentUser, "currentSessionId"), false);
      assert.equal(Object.hasOwn(teacherUser, "currentSessionId"), false);
      assert.equal(studentUser.isInCall, false);
      assert.equal(teacherUser.isInCall, false);
      assert.equal(notificationData.status, "expired");
      assert.equal(typeof notificationData.expiredAt.toMillis, "function");
    },
  );

  test("startSearch callable uses one role-neutral candidate pool", async () => {
    async function runRoleNeutralScenario({
      prefix,
      teacherAvailableMinutesAgo,
      studentCreatedMinutesAgo,
      expectedResponderRole,
    }) {
      const requesterUid = uniqueId(`${prefix}-requester`);
      const waitingUid = uniqueId(`${prefix}-waiting-student`);
      const teacherUid = uniqueId(`${prefix}-teacher`);
      const cityKey = cityKeyForUid(
        `${requesterUid}-${waitingUid}-${teacherUid}`,
      );
      const participantRefs = [
        userRef(requesterUid),
        userRef(waitingUid),
        userRef(teacherUid),
        searchRequestRef(requesterUid),
        searchRequestRef(waitingUid),
        searchRequestRef(teacherUid),
        db.collection("userPrivateTokens").doc(teacherUid),
      ];
      let sessionId = "";

      try {
        await Promise.all(participantRefs.map(deleteDoc));
        await seedStudent(waitingUid, {
          display_name: "Waiting Student",
          profileCity: {key: cityKey},
        });
        await seedStudent(requesterUid, {
          display_name: "Requester Student",
          profileCity: {key: cityKey},
        });

        const waitingResponse = await wrappedStartSearch({
          preferredPartnerLevel: "B1",
          appState: "foreground",
        }, authContext(waitingUid));
        const waitingCreatedAt = admin.firestore.Timestamp.fromMillis(
          Date.now() - studentCreatedMinutesAgo * 60 * 1000,
        );
        await searchRequestRef(waitingUid).update({
          createdAt: waitingCreatedAt,
          updatedAt: admin.firestore.Timestamp.now(),
          heartbeatAt: admin.firestore.Timestamp.now(),
        });
        await seedTeacher(teacherUid, {
          profileCity: {key: cityKey},
          availableSince: admin.firestore.Timestamp.fromMillis(
            Date.now() - teacherAvailableMinutesAgo * 60 * 1000,
          ),
        });
        await db.collection("userPrivateTokens").doc(teacherUid).set({
          voipPushToken: `push-${teacherUid}`,
        });

        let teacherPushSendCount = 0;
        const response = await startSearchCallable({
          preferredPartnerLevel: "B1",
          appState: "foreground",
        }, authContext(requesterUid), {
          teacherResponderPushSender: async (responderId, callData) => {
            teacherPushSendCount += 1;
            assert.equal(responderId, teacherUid);
            assert.equal(callData.callerId, requesterUid);
            return {sent: true, channel: "test"};
          },
        });
        sessionId = response.sessionId;
        const sessionSnapshot = await db
          .collection("videoSessions")
          .doc(response.sessionId)
          .get();
        const sessionData = sessionSnapshot.data();
        const waitingRequest =
          (await searchRequestRef(waitingUid).get()).data();

        assert.equal(waitingResponse.status, "active");
        assert.equal(response.status, "matched");
        assert.equal(response.matchedRole, expectedResponderRole);
        assert.equal(sessionSnapshot.exists, true);
        assert.deepEqual(sessionData.availableTutors, expectedResponderRole ===
          "native_speaker" ?
            [teacherUid, waitingUid] :
            [waitingUid, teacherUid]);
        assert.deepEqual(sessionData.matchContext.candidateIds,
          sessionData.availableTutors);
        assert.ok(
          sessionData.matchContext.candidateStats.studentCandidates >= 1,
        );
        assert.equal(
          sessionData.matchContext.candidateStats.teacherCandidates,
          1,
        );
        assert.equal(sessionData.matchContext.candidateStats.totalCandidates, 2);

        if (expectedResponderRole === "native_speaker") {
          assert.equal(response.matchedUserId, teacherUid);
          assert.equal(response.scenario, "student_teacher");
          assert.equal(sessionData.currentResponderId, teacherUid);
          assert.equal(sessionData.currentResponderRole, "native_speaker");
          assert.equal(teacherPushSendCount, 1);
          assert.equal(waitingRequest.status, SEARCH_REQUEST_STATUS.ACTIVE);
          assert.equal(waitingRequest.currentSessionId, null);
        } else {
          assert.equal(response.matchedUserId, waitingUid);
          assert.equal(response.scenario, "student_student");
          assert.equal(sessionData.currentResponderId, waitingUid);
          assert.equal(sessionData.currentResponderRole, "student");
          assert.equal(teacherPushSendCount, 0);
          assert.equal(waitingRequest.status, SEARCH_REQUEST_STATUS.MATCHED);
          assert.equal(waitingRequest.currentSessionId, response.sessionId);
        }
      } finally {
        if (sessionId) {
          await deleteDoc(db.collection("videoSessions").doc(sessionId));
        }
        await Promise.all(participantRefs.map(deleteDoc));
      }
    }

    await runRoleNeutralScenario({
      prefix: "teacher-older",
      teacherAvailableMinutesAgo: 8,
      studentCreatedMinutesAgo: 3,
      expectedResponderRole: "native_speaker",
    });
    await runRoleNeutralScenario({
      prefix: "student-older",
      teacherAvailableMinutesAgo: 3,
      studentCreatedMinutesAgo: 8,
      expectedResponderRole: "student",
    });
  });

  test("startSearch callable chooses exact level before adjacent", async () => {
    const requesterUid = uniqueId("exact-level-requester");
    const adjacentStudentUid = uniqueId("adjacent-level-student");
    const exactTeacherUid = uniqueId("exact-level-teacher");
    const cityKey = cityKeyForUid(
      `${requesterUid}-${adjacentStudentUid}-${exactTeacherUid}`,
    );
    const refsToDelete = [
      userRef(requesterUid),
      userRef(adjacentStudentUid),
      userRef(exactTeacherUid),
      searchRequestRef(requesterUid),
      searchRequestRef(adjacentStudentUid),
      searchRequestRef(exactTeacherUid),
      db.collection("userPrivateTokens").doc(exactTeacherUid),
    ];
    let sessionId = "";

    try {
      await Promise.all(refsToDelete.map(deleteDoc));
      await seedStudent(adjacentStudentUid, {
        display_name: "Adjacent Student",
        level: "A2",
        profileCity: {key: cityKey},
      });
      await seedStudent(requesterUid, {
        display_name: "Requester Student",
        level: "B1",
        profileCity: {key: cityKey},
      });

      const adjacentStudentResponse = await wrappedStartSearch({
        preferredPartnerLevel: "B1",
        appState: "foreground",
      }, authContext(adjacentStudentUid));
      await searchRequestRef(adjacentStudentUid).update({
        createdAt: admin.firestore.Timestamp.fromMillis(
          Date.now() - 10 * 60 * 1000,
        ),
        updatedAt: admin.firestore.Timestamp.now(),
        heartbeatAt: admin.firestore.Timestamp.now(),
      });
      await seedTeacher(exactTeacherUid, {
        display_name: "Exact Teacher",
        level: "B1",
        profileCity: {key: cityKey},
        availableSince: admin.firestore.Timestamp.fromMillis(
          Date.now() - 2 * 60 * 1000,
        ),
      });
      await db.collection("userPrivateTokens").doc(exactTeacherUid).set({
        voipPushToken: `push-${exactTeacherUid}`,
      });

      let teacherPushSendCount = 0;
      const response = await startSearchCallable({
        preferredPartnerLevel: "B1",
        appState: "foreground",
      }, authContext(requesterUid), {
        teacherResponderPushSender: async (responderId, callData) => {
          teacherPushSendCount += 1;
          assert.equal(responderId, exactTeacherUid);
          assert.equal(callData.callerId, requesterUid);
          return {sent: true, channel: "test"};
        },
      });
      sessionId = response.sessionId;
      const sessionSnapshot = await db
        .collection("videoSessions")
        .doc(response.sessionId)
        .get();
      const sessionData = sessionSnapshot.data();
      const adjacentStudentRequest =
        (await searchRequestRef(adjacentStudentUid).get()).data();

      assert.equal(adjacentStudentResponse.status, "active");
      assert.equal(response.status, "matched");
      assert.equal(response.matchedUserId, exactTeacherUid);
      assert.equal(response.matchedRole, "native_speaker");
      assert.equal(response.scenario, "student_teacher");
      assert.equal(sessionSnapshot.exists, true);
      assert.deepEqual(sessionData.availableTutors, [
        exactTeacherUid,
        adjacentStudentUid,
      ]);
      assert.deepEqual(
        sessionData.matchContext.candidateIds,
        sessionData.availableTutors,
      );
      assert.equal(sessionData.matchContext.selectedResponderId, exactTeacherUid);
      assert.equal(
        sessionData.matchContext.selectedResponderRole,
        "native_speaker",
      );
      assert.equal(sessionData.currentResponderId, exactTeacherUid);
      assert.equal(sessionData.currentResponderRole, "native_speaker");
      assert.equal(teacherPushSendCount, 1);
      assert.equal(adjacentStudentRequest.status, SEARCH_REQUEST_STATUS.ACTIVE);
      assert.equal(adjacentStudentRequest.currentSessionId, null);
    } finally {
      if (sessionId) {
        await deleteDoc(db.collection("videoSessions").doc(sessionId));
      }
      await Promise.all(refsToDelete.map(deleteDoc));
    }
  });

  test("startSearch callable accepts only one-step adjacent level", async () => {
    const requesterUid = uniqueId("one-step-requester");
    const adjacentStudentUid = uniqueId("one-step-adjacent-student");
    const farStudentUid = uniqueId("one-step-far-student");
    const cityKey = cityKeyForUid(
      `${requesterUid}-${adjacentStudentUid}-${farStudentUid}`,
    );
    const refsToDelete = [
      userRef(requesterUid),
      userRef(adjacentStudentUid),
      userRef(farStudentUid),
      searchRequestRef(requesterUid),
      searchRequestRef(adjacentStudentUid),
      searchRequestRef(farStudentUid),
    ];
    let sessionId = "";

    try {
      await Promise.all(refsToDelete.map(deleteDoc));
      await seedStudent(farStudentUid, {
        display_name: "Far Student",
        level: "A1",
        profileCity: {key: cityKey},
      });
      await seedStudent(adjacentStudentUid, {
        display_name: "Adjacent Student",
        level: "B2",
        profileCity: {key: cityKey},
      });
      await seedStudent(requesterUid, {
        display_name: "Requester Student",
        level: "B1",
        profileCity: {key: cityKey},
      });

      const farResponse = await wrappedStartSearch({
        preferredPartnerLevel: "B1",
        appState: "foreground",
      }, authContext(farStudentUid));
      await searchRequestRef(farStudentUid).update({
        createdAt: admin.firestore.Timestamp.fromMillis(
          Date.now() - 10 * 60 * 1000,
        ),
        updatedAt: admin.firestore.Timestamp.now(),
        heartbeatAt: admin.firestore.Timestamp.now(),
      });
      const adjacentResponse = await wrappedStartSearch({
        preferredPartnerLevel: "B1",
        appState: "foreground",
      }, authContext(adjacentStudentUid));
      await searchRequestRef(adjacentStudentUid).update({
        createdAt: admin.firestore.Timestamp.fromMillis(
          Date.now() - 2 * 60 * 1000,
        ),
        updatedAt: admin.firestore.Timestamp.now(),
        heartbeatAt: admin.firestore.Timestamp.now(),
      });

      const response = await wrappedStartSearch({
        preferredPartnerLevel: "B1",
        appState: "foreground",
      }, authContext(requesterUid));
      sessionId = response.sessionId;
      assert.equal(typeof response.sessionId, "string");
      const sessionSnapshot = await db
        .collection("videoSessions")
        .doc(response.sessionId)
        .get();
      const sessionData = sessionSnapshot.data();
      const farRequest = (await searchRequestRef(farStudentUid).get()).data();
      const adjacentRequest =
        (await searchRequestRef(adjacentStudentUid).get()).data();

      assert.equal(farResponse.status, "active");
      assert.equal(adjacentResponse.status, "active");
      assert.equal(response.status, "matched");
      assert.equal(response.matchedUserId, adjacentStudentUid);
      assert.equal(response.matchedRole, "student");
      assert.equal(response.scenario, "student_student");
      assert.equal(sessionSnapshot.exists, true);
      assert.deepEqual(sessionData.availableTutors, [adjacentStudentUid]);
      assert.deepEqual(
        sessionData.matchContext.candidateIds,
        [adjacentStudentUid],
      );
      assert.equal(
        sessionData.matchContext.selectedResponderId,
        adjacentStudentUid,
      );
      assert.equal(sessionData.currentResponderId, adjacentStudentUid);
      assert.equal(sessionData.currentResponderRole, "student");
      assert.equal(adjacentRequest.status, SEARCH_REQUEST_STATUS.MATCHED);
      assert.equal(adjacentRequest.currentSessionId, response.sessionId);
      assert.equal(farRequest.status, SEARCH_REQUEST_STATUS.ACTIVE);
      assert.equal(farRequest.currentSessionId, null);
    } finally {
      if (sessionId) {
        await deleteDoc(db.collection("videoSessions").doc(sessionId));
      }
      await Promise.all(refsToDelete.map(deleteDoc));
    }
  });

  test("startSearch callable filters blocklists in both directions", async () => {
    const requesterUid = uniqueId("blocklist-requester");
    const requesterBlockedUid = uniqueId("blocklist-requester-blocked");
    const candidateBlockedUid = uniqueId("blocklist-candidate-blocked");
    const validUid = uniqueId("blocklist-valid");
    const cityKey = cityKeyForUid([
      requesterUid,
      requesterBlockedUid,
      candidateBlockedUid,
      validUid,
    ].join("-"));
    const refsToDelete = [
      userRef(requesterUid),
      userRef(requesterBlockedUid),
      userRef(candidateBlockedUid),
      userRef(validUid),
      searchRequestRef(requesterUid),
      searchRequestRef(requesterBlockedUid),
      searchRequestRef(candidateBlockedUid),
      searchRequestRef(validUid),
    ];
    const now = admin.firestore.Timestamp.now();
    let sessionId = "";

    async function seedActiveStudentSearchRequest(uid, createdMinutesAgo) {
      await searchRequestRef(uid).set({
        requestId: `request-${uid}`,
        userId: uid,
        userRef: userRef(uid),
        role: "student",
        language: "en",
        filters: {
          preferredLevel: "B1",
          levelRank: 3,
          countryCode: "US",
          cityKey,
        },
        status: SEARCH_REQUEST_STATUS.ACTIVE,
        appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
        appStateUpdatedAt: now,
        platform: "test",
        createdAt: admin.firestore.Timestamp.fromMillis(
          Date.now() - createdMinutesAgo * 60 * 1000,
        ),
        updatedAt: now,
        heartbeatAt: now,
        expiresAt: emulatorFutureTimestamp(10),
        backgroundExpiresAt: null,
        activeSessionId: null,
        currentSessionId: null,
        matchedSessionId: null,
        matchedUserId: null,
        matchedResponderId: null,
        matchedRole: null,
        pairAttemptId: null,
        excludedCandidateIds: [],
        attemptExcludedCandidateIds: [],
        lockOwner: null,
        lockExpiresAt: null,
        version: 1,
        stopReason: null,
        stoppedAt: null,
        stoppedBy: null,
        lastError: null,
        errorCode: null,
        errorMessage: null,
      });
    }

    try {
      await Promise.all(refsToDelete.map(deleteDoc));
      await seedStudent(requesterUid, {
        display_name: "Requester Student",
        profileCity: {key: cityKey},
        blockedUsers: [`users/${requesterBlockedUid}`],
      });
      await seedStudent(requesterBlockedUid, {
        display_name: "Blocked By Requester",
        profileCity: {key: cityKey},
      });
      await seedStudent(candidateBlockedUid, {
        display_name: "Candidate Blocked Requester",
        profileCity: {key: cityKey},
        blockedUsers: [{id: requesterUid}],
      });
      await seedStudent(validUid, {
        display_name: "Valid Student",
        profileCity: {key: cityKey},
      });
      await seedActiveStudentSearchRequest(requesterBlockedUid, 9);
      await seedActiveStudentSearchRequest(candidateBlockedUid, 8);
      await seedActiveStudentSearchRequest(validUid, 7);

      const response = await wrappedStartSearch({
        preferredPartnerLevel: "B1",
        appState: "foreground",
      }, authContext(requesterUid));
      sessionId = response.sessionId;
      assert.equal(typeof response.sessionId, "string");
      const sessionSnapshot = await db
        .collection("videoSessions")
        .doc(response.sessionId)
        .get();
      const sessionData = sessionSnapshot.data();
      const requesterBlockedRequest =
        (await searchRequestRef(requesterBlockedUid).get()).data();
      const candidateBlockedRequest =
        (await searchRequestRef(candidateBlockedUid).get()).data();
      const validRequest = (await searchRequestRef(validUid).get()).data();
      const requesterRequest = (await searchRequestRef(requesterUid).get())
        .data();

      assert.equal(response.status, "matched");
      assert.equal(response.matchedUserId, validUid);
      assert.equal(response.matchedRole, "student");
      assert.equal(response.scenario, "student_student");
      assert.equal(sessionSnapshot.exists, true);
      assert.deepEqual(sessionData.availableTutors, [validUid]);
      assert.deepEqual(sessionData.matchContext.candidateIds, [validUid]);
      assert.equal(sessionData.matchContext.selectedResponderId, validUid);
      assert.equal(sessionData.currentResponderId, validUid);
      assert.equal(sessionData.currentResponderRole, "student");
      assert.equal(requesterRequest.status, SEARCH_REQUEST_STATUS.MATCHED);
      assert.equal(requesterRequest.currentSessionId, response.sessionId);
      assert.equal(validRequest.status, SEARCH_REQUEST_STATUS.MATCHED);
      assert.equal(validRequest.currentSessionId, response.sessionId);
      assert.equal(
        requesterBlockedRequest.status,
        SEARCH_REQUEST_STATUS.ACTIVE,
      );
      assert.equal(requesterBlockedRequest.currentSessionId, null);
      assert.equal(requesterBlockedRequest.activeSessionId, null);
      assert.equal(requesterBlockedRequest.matchedSessionId, null);
      assert.equal(
        candidateBlockedRequest.status,
        SEARCH_REQUEST_STATUS.ACTIVE,
      );
      assert.equal(candidateBlockedRequest.currentSessionId, null);
      assert.equal(candidateBlockedRequest.activeSessionId, null);
      assert.equal(candidateBlockedRequest.matchedSessionId, null);
    } finally {
      if (sessionId) {
        await deleteDoc(db.collection("videoSessions").doc(sessionId));
      }
      await Promise.all(refsToDelete.map(deleteDoc));
    }
  });

  test("startSearch callable filters teacher blocklists in both directions",
    async () => {
      const requesterUid = uniqueId("teacher-blocklist-requester");
      const requesterBlockedUid =
        uniqueId("teacher-blocklist-requester-blocked");
      const teacherBlockedUid =
        uniqueId("teacher-blocklist-teacher-blocked");
      const validUid = uniqueId("teacher-blocklist-valid");
      const cityKey = cityKeyForUid([
        requesterUid,
        requesterBlockedUid,
        teacherBlockedUid,
        validUid,
      ].join("-"));
      const refsToDelete = [
        userRef(requesterUid),
        userRef(requesterBlockedUid),
        userRef(teacherBlockedUid),
        userRef(validUid),
        searchRequestRef(requesterUid),
        searchRequestRef(requesterBlockedUid),
        searchRequestRef(teacherBlockedUid),
        searchRequestRef(validUid),
        db.collection("userPrivateTokens").doc(requesterBlockedUid),
        db.collection("userPrivateTokens").doc(teacherBlockedUid),
        db.collection("userPrivateTokens").doc(validUid),
      ];
      let sessionId = "";

      async function setTeacherPushToken(uid) {
        await db.collection("userPrivateTokens").doc(uid).set({
          voipPushToken: `push-${uid}`,
        });
      }

      try {
        await Promise.all(refsToDelete.map(deleteDoc));
        await seedStudent(requesterUid, {
          display_name: "Requester Student",
          profileCity: {key: cityKey},
          blockedUsers: [`users/${requesterBlockedUid}`],
        });
        await seedTeacher(requesterBlockedUid, {
          display_name: "Blocked By Requester",
          profileCity: {key: cityKey},
          availableSince: admin.firestore.Timestamp.fromMillis(
            Date.now() - 9 * 60 * 1000,
          ),
        });
        await seedTeacher(teacherBlockedUid, {
          display_name: "Teacher Blocked Requester",
          profileCity: {key: cityKey},
          blockedUsers: [`users/${requesterUid}`],
          availableSince: admin.firestore.Timestamp.fromMillis(
            Date.now() - 8 * 60 * 1000,
          ),
        });
        await seedTeacher(validUid, {
          display_name: "Valid Teacher",
          profileCity: {key: cityKey},
          availableSince: admin.firestore.Timestamp.fromMillis(
            Date.now() - 7 * 60 * 1000,
          ),
        });
        await Promise.all([
          setTeacherPushToken(requesterBlockedUid),
          setTeacherPushToken(teacherBlockedUid),
          setTeacherPushToken(validUid),
        ]);

        const teacherResponderIds = [];
        const response = await startSearchCallable({
          preferredPartnerLevel: "B1",
          appState: "foreground",
        }, authContext(requesterUid), {
          teacherResponderPushSender: async (responderId, callData) => {
            teacherResponderIds.push(responderId);
            assert.equal(callData.callerId, requesterUid);
            return {sent: true, channel: "test"};
          },
        });
        sessionId = response.sessionId;
        assert.equal(typeof response.sessionId, "string");
        const sessionSnapshot = await db
          .collection("videoSessions")
          .doc(response.sessionId)
          .get();
        const sessionData = sessionSnapshot.data();
        const requesterRequest = (await searchRequestRef(requesterUid).get())
          .data();
        const requesterBlockedTeacher =
          (await userRef(requesterBlockedUid).get()).data();
        const teacherBlockedRequester =
          (await userRef(teacherBlockedUid).get()).data();
        const notificationQuery = await db
          .collection("notifications")
          .where("recipientId", "in", [
            requesterBlockedUid,
            teacherBlockedUid,
            validUid,
          ])
          .get();
        const matchingNotifications = notificationQuery.docs
          .map((doc) => doc.data())
          .filter((item) => item.sessionId === response.sessionId);
        const blockedTeacherNotifications = notificationQuery.docs
          .map((doc) => doc.data())
          .filter((item) =>
            item.sessionId === response.sessionId &&
              [
                requesterBlockedUid,
                teacherBlockedUid,
              ].includes(item.recipientId),
          );
        const notificationRecipients = Array.from(new Set(
          matchingNotifications.map((item) => item.recipientId),
        ));

        assert.equal(response.status, "matched");
        assert.equal(response.matchedUserId, validUid);
        assert.equal(response.matchedRole, "native_speaker");
        assert.equal(response.scenario, "student_teacher");
        assert.equal(sessionSnapshot.exists, true);
        assert.deepEqual(sessionData.availableTutors, [validUid]);
        assert.deepEqual(sessionData.matchContext.candidateIds, [validUid]);
        assert.equal(sessionData.matchContext.selectedResponderId, validUid);
        assert.equal(
          sessionData.matchContext.selectedResponderRole,
          "native_speaker",
        );
        assert.equal(sessionData.currentResponderId, validUid);
        assert.equal(sessionData.currentResponderRole, "native_speaker");
        assert.equal(requesterRequest.status, SEARCH_REQUEST_STATUS.MATCHED);
        assert.equal(requesterRequest.currentSessionId, response.sessionId);
        assert.notEqual(
          requesterBlockedTeacher.currentSessionId,
          response.sessionId,
        );
        assert.notEqual(
          teacherBlockedRequester.currentSessionId,
          response.sessionId,
        );
        assert.equal(requesterBlockedTeacher.isInCall, false);
        assert.equal(teacherBlockedRequester.isInCall, false);
        assert.equal(blockedTeacherNotifications.length, 0);
        assert.equal(matchingNotifications.length, 1);
        assert.deepEqual(notificationRecipients, [validUid]);
        assert.equal(
          matchingNotifications.some((item) =>
            item.recipientId === validUid && item.type === "incoming_call"),
          true,
        );
        assert.deepEqual(teacherResponderIds, [validUid]);
      } finally {
        if (sessionId) {
          await deleteDoc(db.collection("videoSessions").doc(sessionId));
        }
        await Promise.all(refsToDelete.map(deleteDoc));
      }
    });

  test("startSearch callable excludes teachers without active call token",
    async () => {
      const requesterUid = uniqueId("teacher-token-requester");
      const tokenlessTeacherUid = uniqueId("teacher-tokenless");
      const validTeacherUid = uniqueId("teacher-token-valid");
      const cityKey = cityKeyForUid([
        requesterUid,
        tokenlessTeacherUid,
        validTeacherUid,
      ].join("-"));
      const tokenlessTeacherAvailableMinutesAgo = 9;
      const validTeacherAvailableMinutesAgo = 7;
      const refsToDelete = [
        userRef(requesterUid),
        userRef(tokenlessTeacherUid),
        userRef(validTeacherUid),
        searchRequestRef(requesterUid),
        searchRequestRef(tokenlessTeacherUid),
        searchRequestRef(validTeacherUid),
        db.collection("userPrivateTokens").doc(tokenlessTeacherUid),
        db.collection("userPrivateTokens").doc(validTeacherUid),
      ];
      let sessionId = "";
      let notificationRefsToDelete = [];

      try {
        await Promise.all(refsToDelete.map(deleteDoc));
        await seedStudent(requesterUid, {
          display_name: "Requester Student",
          profileCity: {key: cityKey},
        });
        await seedTeacher(tokenlessTeacherUid, {
          display_name: "Tokenless Teacher",
          profileCity: {key: cityKey},
          availableSince: admin.firestore.Timestamp.fromMillis(
            Date.now() -
              tokenlessTeacherAvailableMinutesAgo * 60 * 1000,
          ),
        });
        await seedTeacher(validTeacherUid, {
          display_name: "Valid Teacher",
          profileCity: {key: cityKey},
          availableSince: admin.firestore.Timestamp.fromMillis(
            Date.now() -
              validTeacherAvailableMinutesAgo * 60 * 1000,
          ),
        });
        await db
          .collection("userPrivateTokens")
          .doc(tokenlessTeacherUid)
          .delete();
        await db.collection("userPrivateTokens").doc(validTeacherUid).set({
          voipPushToken: `push-${validTeacherUid}`,
        });
        const tokenlessPrivateToken = await db
          .collection("userPrivateTokens")
          .doc(tokenlessTeacherUid)
          .get();
        assert.equal(tokenlessPrivateToken.exists, false);

        const teacherResponderIds = [];
        const response = await startSearchCallable({
          preferredPartnerLevel: "B1",
          appState: "foreground",
        }, authContext(requesterUid), {
          teacherResponderPushSender: async (responderId, callData) => {
            teacherResponderIds.push(responderId);
            assert.equal(callData.callerId, requesterUid);
            return {sent: true, channel: "test"};
          },
        });
        sessionId = response.sessionId;
        assert.equal(typeof response.sessionId, "string");
        const sessionSnapshot = await db
          .collection("videoSessions")
          .doc(response.sessionId)
          .get();
        const sessionData = sessionSnapshot.data();
        const requesterRequest = (await searchRequestRef(requesterUid).get())
          .data();
        const tokenlessTeacher =
          (await userRef(tokenlessTeacherUid).get()).data();
        const notificationQuery = await db
          .collection("notifications")
          .where("recipientId", "in", [
            tokenlessTeacherUid,
            validTeacherUid,
          ])
          .get();
        notificationRefsToDelete = notificationQuery.docs
          .map((doc) => doc.ref);
        const matchingNotifications = notificationQuery.docs
          .map((doc) => doc.data())
          .filter((item) => item.sessionId === response.sessionId);
        const tokenlessNotifications = notificationQuery.docs
          .map((doc) => doc.data())
          .filter((item) => item.recipientId === tokenlessTeacherUid);
        const notificationRecipients = Array.from(new Set(
          matchingNotifications.map((item) => item.recipientId),
        ));
        const tokenlessParticipantSessions = await db
          .collection("videoSessions")
          .where("participantIds", "array-contains", tokenlessTeacherUid)
          .get();
        const tokenlessResponderSessions = await db
          .collection("videoSessions")
          .where("currentResponderId", "==", tokenlessTeacherUid)
          .get();
        const tokenlessTutorSessions = await db
          .collection("videoSessions")
          .where("currentTutorId", "==", tokenlessTeacherUid)
          .get();
        const tokenlessLegacyTutorSessions = await db
          .collection("videoSessions")
          .where("tutorId", "==", tokenlessTeacherUid)
          .get();
        const tokenlessSessionIds = new Set([
          ...tokenlessParticipantSessions.docs,
          ...tokenlessResponderSessions.docs,
          ...tokenlessTutorSessions.docs,
          ...tokenlessLegacyTutorSessions.docs,
        ].map((doc) => doc.id));

        assert.equal(response.status, "matched");
        assert.equal(response.matchedUserId, validTeacherUid);
        assert.equal(response.matchedRole, "native_speaker");
        assert.equal(response.scenario, "student_teacher");
        assert.equal(sessionSnapshot.exists, true);
        assert.deepEqual(sessionData.availableTutors, [validTeacherUid]);
        assert.deepEqual(
          sessionData.matchContext.candidateIds,
          [validTeacherUid],
        );
        assert.equal(
          sessionData.matchContext.selectedResponderId,
          validTeacherUid,
        );
        assert.equal(sessionData.currentResponderId, validTeacherUid);
        assert.equal(sessionData.currentTutorId, validTeacherUid);
        assert.equal(sessionData.tutorId, validTeacherUid);
        assert.equal(requesterRequest.status, SEARCH_REQUEST_STATUS.MATCHED);
        assert.equal(requesterRequest.currentSessionId, response.sessionId);
        assert.notEqual(tokenlessTeacher.currentSessionId, response.sessionId);
        assert.equal(tokenlessTeacher.isInCall, false);
        assert.equal(tokenlessNotifications.length, 0);
        assert.equal(tokenlessSessionIds.size, 0);
        assert.equal(matchingNotifications.length, 1);
        assert.deepEqual(notificationRecipients, [validTeacherUid]);
        assert.deepEqual(teacherResponderIds, [validTeacherUid]);
      } finally {
        if (sessionId) {
          await deleteDoc(db.collection("videoSessions").doc(sessionId));
        }
        await Promise.all(notificationRefsToDelete.map(deleteDoc));
        await Promise.all(refsToDelete.map(deleteDoc));
      }
    });

  test("startSearch callable creates one session under concurrent starts", async () => {
    const firstUid = uniqueId("student-concurrent-a");
    const secondUid = uniqueId("student-concurrent-b");
    const cityKey = cityKeyForUid(`${firstUid}-${secondUid}`);
    await deleteDoc(userRef(firstUid));
    await deleteDoc(userRef(secondUid));
    await deleteDoc(searchRequestRef(firstUid));
    await deleteDoc(searchRequestRef(secondUid));
    await seedStudent(firstUid, {
      display_name: "First Student",
      profileCity: {key: cityKey},
    });
    await seedStudent(secondUid, {
      display_name: "Second Student",
      profileCity: {key: cityKey},
    });

    const responses = await Promise.all([
      wrappedStartSearch({preferredPartnerLevel: "B1"}, authContext(firstUid)),
      wrappedStartSearch({preferredPartnerLevel: "B1"}, authContext(secondUid)),
    ]);
    const firstRequest = (await searchRequestRef(firstUid).get()).data();
    const secondRequest = (await searchRequestRef(secondUid).get()).data();
    const firstUser = (await userRef(firstUid).get()).data();
    const secondUser = (await userRef(secondUid).get()).data();
    const sessionIds = new Set([
      ...responses.map((response) => response.sessionId),
      firstRequest.currentSessionId,
      secondRequest.currentSessionId,
      firstUser.currentSessionId,
      secondUser.currentSessionId,
    ].filter(Boolean));

    assert.equal(sessionIds.size, 1);
    const [sessionId] = Array.from(sessionIds);
    assert.equal(firstRequest.status, "matched");
    assert.equal(secondRequest.status, "matched");
    assert.equal(firstRequest.currentSessionId, sessionId);
    assert.equal(secondRequest.currentSessionId, sessionId);
    assert.equal(firstUser.currentSessionId, sessionId);
    assert.equal(secondUser.currentSessionId, sessionId);
    assert.equal(
      responses.filter((response) => response.status === "matched").length >= 1,
      true,
    );
  });

  test("startSearch callable prevents double session for one requester", async () => {
    const waitingUid = uniqueId("student-double-session-waiting");
    const joiningUid = uniqueId("student-double-session-joining");
    const cityKey = cityKeyForUid(`${waitingUid}-${joiningUid}`);
    await deleteDoc(userRef(waitingUid));
    await deleteDoc(userRef(joiningUid));
    await deleteDoc(searchRequestRef(waitingUid));
    await deleteDoc(searchRequestRef(joiningUid));
    await seedStudent(waitingUid, {
      display_name: "Waiting Student",
      profileCity: {key: cityKey},
    });
    await seedStudent(joiningUid, {
      display_name: "Joining Student",
      profileCity: {key: cityKey},
    });

    const waitingResponse = await wrappedStartSearch({
      preferredPartnerLevel: "B1",
    }, authContext(waitingUid));
    const results = await Promise.allSettled(
      Array.from({length: 5}, () => wrappedStartSearch({
        preferredPartnerLevel: "B1",
      }, authContext(joiningUid))),
    );
    const rejectedResult = results.find((result) =>
      result.status === "rejected",
    );
    if (rejectedResult) {
      throw rejectedResult.reason;
    }

    const responses = results.map((result) => result.value);
    const waitingRequest = (await searchRequestRef(waitingUid).get()).data();
    const joiningRequest = (await searchRequestRef(joiningUid).get()).data();
    const waitingUser = (await userRef(waitingUid).get()).data();
    const joiningUser = (await userRef(joiningUid).get()).data();
    const responseSessionIds = Array.from(new Set(
      responses.map((response) => response.sessionId).filter(Boolean),
    ));
    const finalSessionIds = Array.from(new Set([
      ...responseSessionIds,
      waitingRequest.currentSessionId,
      waitingRequest.activeSessionId,
      waitingRequest.matchedSessionId,
      joiningRequest.currentSessionId,
      joiningRequest.activeSessionId,
      joiningRequest.matchedSessionId,
      waitingUser.currentSessionId,
      joiningUser.currentSessionId,
    ].filter(Boolean)));

    assert.equal(waitingResponse.status, "active");
    assert.equal(responseSessionIds.length, 1);
    assert.equal(finalSessionIds.length, 1);
    const [sessionId] = finalSessionIds;
    const sessionSnapshot = await db
      .collection("videoSessions")
      .doc(sessionId)
      .get();
    const sessionData = sessionSnapshot.data();
    const waitingParticipantSessions = await db
      .collection("videoSessions")
      .where("participantIds", "array-contains", waitingUid)
      .get();
    const joiningParticipantSessions = await db
      .collection("videoSessions")
      .where("participantIds", "array-contains", joiningUid)
      .get();
    const participantSessionIds = new Set([
      ...waitingParticipantSessions.docs,
      ...joiningParticipantSessions.docs,
    ].map((doc) => doc.id));

    assert.equal(sessionSnapshot.exists, true);
    assert.equal(sessionData.status, "pending_confirmation");
    assert.equal(sessionData.pairStatus, "pending_confirmation");
    assert.deepEqual(
      sessionData.participantIds.slice().sort(),
      [joiningUid, waitingUid].sort(),
    );
    assert.equal(participantSessionIds.size, 1);
    assert.deepEqual(Array.from(participantSessionIds), [sessionId]);
    assert.equal(waitingRequest.status, SEARCH_REQUEST_STATUS.MATCHED);
    assert.equal(joiningRequest.status, SEARCH_REQUEST_STATUS.MATCHED);
    assert.equal(waitingRequest.currentSessionId, sessionId);
    assert.equal(waitingRequest.matchedSessionId, sessionId);
    assert.equal(joiningRequest.currentSessionId, sessionId);
    assert.equal(joiningRequest.matchedSessionId, sessionId);
    assert.equal(typeof joiningRequest.pairAttemptId, "string");
    assert.ok(joiningRequest.pairAttemptId);
    assert.equal(waitingRequest.pairAttemptId, joiningRequest.pairAttemptId);
    assert.equal(waitingRequest.lockOwner, waitingRequest.pairAttemptId);
    assert.equal(joiningRequest.lockOwner, joiningRequest.pairAttemptId);
    assert.equal(sessionData.pairAttemptId, joiningRequest.pairAttemptId);
    assert.equal(sessionData.matchLock.owner, joiningRequest.pairAttemptId);
    assert.equal(waitingUser.currentSessionId, sessionId);
    assert.equal(joiningUser.currentSessionId, sessionId);
    assert.equal(
      responses.every((response) =>
        response.status === "matched" && response.sessionId === sessionId),
      true,
    );
  });

  test("startSearch callable keeps a single active request under concurrency", async () => {
    for (let round = 0; round < 3; round += 1) {
      const uid = uniqueId(`student-concurrent-${round}`);
      await deleteDoc(userRef(uid));
      await deleteDoc(searchRequestRef(uid));
      await seedStudent(uid);

      try {
        const results = await Promise.allSettled(
          Array.from({length: 5}, (_, index) => wrappedStartSearch({
            preferredPartnerLevel: index % 2 === 0 ? "B1" : "C2",
          }, authContext(uid))),
        );
        const rejectedResult = results.find((result) =>
          result.status === "rejected",
        );
        if (rejectedResult) {
          throw rejectedResult.reason;
        }
        const responses = results.map((result) => result.value);
        const snapshot = await searchRequestRef(uid).get();
        const requestIds = new Set(
          responses.map((response) => response.requestId),
        );

        assert.equal(snapshot.exists, true, `round ${round}: request exists`);
        assert.equal(
          requestIds.size,
          1,
          `round ${round}: one response requestId`,
        );
        assert.ok(
          responses[0].requestId,
          `round ${round}: response requestId present`,
        );
        assert.equal(
          snapshot.data().status,
          SEARCH_REQUEST_STATUS.ACTIVE,
          `round ${round}: stored request stays active`,
        );
        assert.equal(
          snapshot.data().requestId,
          responses[0].requestId,
          `round ${round}: stored requestId matches responses`,
        );
        assert.equal(snapshot.ref.id, uid, `round ${round}: document id is uid`);
        assert.equal(
          responses.filter((response) => response.reused === false).length,
          1,
          `round ${round}: exactly one create response`,
        );
        assert.equal(
          responses.filter((response) => response.reused === true).length,
          4,
          `round ${round}: remaining responses reuse request`,
        );
        assert.equal(
          await db.collection("searchRequests").where("userId", "==", uid).get()
            .then((query) => query.size),
          1,
          `round ${round}: one stored request by userId`,
        );
      } catch (error) {
        throw new Error(`round ${round}: concurrent start failed`, {
          cause: error,
        });
      } finally {
        await deleteDoc(searchRequestRef(uid));
        await deleteDoc(userRef(uid));
      }
    }
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
      const cityKey = cityKeyForUid(uid);
      await deleteDoc(userRef(uid));
      await deleteDoc(searchRequestRef(uid));
      await seedStudent(uid);
      await searchRequestRef(uid).set({
        requestId: `request-${status}`,
        userId: uid,
        userRef: userRef(uid),
        role: "student",
        language: "en",
        filters: {
          preferredLevel: "A2",
          levelRank: 2,
          countryCode: "US",
          cityKey,
        },
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
      if (status === "matched") {
        assert.equal(response.sessionId, "session-a");
        assert.equal(response.matchedUserId, "peer-a");
        assert.equal(response.matchedRole, "student");
        assert.equal(response.scenario, "student_student");
      } else {
        assert.equal(response.sessionId, null);
        assert.equal(response.matchedUserId, undefined);
        assert.equal(response.matchedRole, undefined);
        assert.equal(response.scenario, undefined);
      }
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
