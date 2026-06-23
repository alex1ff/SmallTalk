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
    buildStartSearchFilters,
    buildMatchedStartSearchResponse,
    buildStartSearchRequestData,
    buildStartSearchResponse,
    buildStudentPairSessionData,
    cancelBackgroundStudentResponderNotification,
    canAttemptStudentPairForSearchRequest,
    canReuseSearchRequestForUser,
    hasCurrentMatchedSession,
    isFreshBackgroundSearchRequest,
    isSessionResponseWindowOpen,
    isStudentResponderSession,
    isReusableSearchRequest,
    maybeNotifyBackgroundStudentResponder,
    normalizeStartSearchInput,
    readErrorMessage,
    recordBackgroundStudentResponderPushFailure,
    recordBackgroundStudentResponderPushSuccess,
    runBackgroundStudentResponderPushSender,
    searchRequestBelongsToResponder,
    searchRequestBelongsToUser,
    searchRequestMatchesSession,
    sendVoipPushToStudentResponder,
    shouldCreateBackgroundStudentResponderIncomingCall,
    tryReadCurrentMatchedStartSearchResponse,
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
        matchedRole: "teacher",
      },
      reused: true,
    }).scenario,
    "student_teacher",
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
      roomUrl: "https://daily.example/room",
      meetingToken: "token",
    },
  });

  assert.deepEqual(callData, {
    sessionId: "session-ab",
    callerName: "Ana",
    callerId: "student-a",
    callerPhoto: "photo",
    language: "en",
  });
  assert.equal(Object.hasOwn(callData, "roomUrl"), false);
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
  });
  assert.equal(Object.hasOwn(pushPayload, "roomUrl"), false);
  assert.equal(Object.hasOwn(pushPayload, "meetingToken"), false);

  const fcmMessage = buildStudentPairResponderFcmMessage({
    fcmToken: "fcm-token",
    payload: pushPayload,
    bundleId: "com.example.app",
  });
  assert.equal(fcmMessage.token, "fcm-token");
  assert.equal(fcmMessage.android.priority, "high");
  assert.deepEqual(fcmMessage.data, pushPayload);
  assert.equal(Object.hasOwn(fcmMessage.data, "roomUrl"), false);
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
  assert.deepEqual(pushCalls[0].callData, {
    sessionId: "session-ab",
    callerName: "Joining Student",
    callerId: "student-a",
    callerPhoto: "joining-photo",
    language: "en",
  });
  assert.equal(Object.hasOwn(pushCalls[0].callData, "roomUrl"), false);
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
    assert.equal(sessionData.responderId, waitingUid);
    assert.equal(sessionData.currentResponderId, waitingUid);
    assert.equal(sessionData.currentResponderRole, "student");
    assert.equal(sessionData.currentTutorId, waitingUid);
    assert.equal(sessionData.tutorId, null);
    assert.equal(typeof sessionData.expiresAt.toMillis, "function");
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
    assert.deepEqual(sessionData.searchRequestIds, {
      requester: joiningResponse.requestId,
      responder: waitingResponse.requestId,
    });
    assert.equal(sessionData.matchContext.requesterId, joiningUid);
    assert.equal(sessionData.matchContext.selectedResponderId, waitingUid);
    assert.equal(
      sessionData.matchContext.selectedResponderSearchRequestId,
      waitingResponse.requestId,
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
    assert.equal(joiningRequest.status, "matched");
    assert.equal(joiningRequest.currentSessionId, joiningResponse.sessionId);
    assert.equal(joiningRequest.matchedSessionId, joiningResponse.sessionId);
    assert.equal(joiningRequest.matchedUserId, waitingUid);
    assert.equal(joiningRequest.matchedResponderId, waitingUid);
    assert.equal(joiningRequest.matchedRole, "student");
    assert.equal(joiningRequest.pairAttemptId, joiningResponse.pairAttemptId);
    assert.equal(waitingUser.currentSessionId, joiningResponse.sessionId);
    assert.equal(joiningUser.currentSessionId, joiningResponse.sessionId);
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
    const joiningResponse = await wrappedStartSearch({
      preferredPartnerLevel: "B1",
      appState: "foreground",
      platform: "ios",
    }, authContext(joiningUid));
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
    assert.equal(
      matchingNotifications[0].data.studentInfo.name,
      "Joining Student",
    );
    assert.equal(
      matchingNotifications[0].data.studentInfo.photo,
      "joining-photo",
    );
    assert.equal(
      Object.hasOwn(matchingNotifications[0].data, "roomUrl"),
      false,
    );
    assert.equal(
      Object.hasOwn(matchingNotifications[0].data, "meetingToken"),
      false,
    );
  });

  test("startSearch callable does not match teachers", async () => {
    const studentUid = uniqueId("student-no-teacher-match");
    const teacherUid = uniqueId("teacher-no-start-search-match");
    const cityKey = cityKeyForUid(`${studentUid}-${teacherUid}`);
    await deleteDoc(userRef(studentUid));
    await deleteDoc(userRef(teacherUid));
    await deleteDoc(searchRequestRef(studentUid));
    await deleteDoc(searchRequestRef(teacherUid));
    await deleteDoc(db.collection("userPrivateTokens").doc(teacherUid));
    await seedStudent(studentUid, {profileCity: {key: cityKey}});
    await seedTeacher(teacherUid, {profileCity: {key: cityKey}});

    const response = await wrappedStartSearch({
      preferredPartnerLevel: "B1",
    }, authContext(studentUid));
    const requestData = (await searchRequestRef(studentUid).get()).data();

    assert.equal(response.status, "active");
    assert.equal(response.sessionId, null);
    assert.equal(response.pairAttemptId, null);
    assert.equal(requestData.status, "active");
    assert.equal(requestData.currentSessionId, null);
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
