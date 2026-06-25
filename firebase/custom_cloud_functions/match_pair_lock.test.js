const test = require("node:test");
const assert = require("node:assert/strict");
const {
  SEARCH_REQUEST_STATUS,
} = require("./search_requests");
const {
  applyPreparedPairLockWrites,
  buildPairAttemptId,
  buildSearchRequestActiveRestoreUpdate,
  canRestoreSearchRequestToActive,
  prepareExistingSessionNextResponderPairLockInTransaction,
  releaseSessionPairLocksInTransaction,
  reserveDirectPairInTransaction,
  reserveMatchPair,
  stopSessionSearchRequestsInTransaction,
  validateSearchRequestForPairLock,
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

function activeSearchRequest(userId, overrides = {}) {
  return {
    requestId: `request-${userId}`,
    userId,
    userRef: {id: userId, path: `users/${userId}`},
    role: "student",
    language: "en",
    filters: {preferredLevel: "B1", levelRank: 3},
    status: SEARCH_REQUEST_STATUS.ACTIVE,
    appState: "foreground",
    heartbeatAt: timestampFromMillis(fixedNowMillis - 30 * 1000),
    expiresAt: timestampFromMillis(fixedNowMillis + 10 * 60 * 1000),
    backgroundExpiresAt: null,
    currentSessionId: null,
    activeSessionId: null,
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
    ...overrides,
  };
}

function studentUser(overrides = {}) {
  return {
    role: "student",
    isInCall: false,
    currentSessionId: "",
    display_name: "Student",
    photo_url: "student-photo",
    ...overrides,
  };
}

function namedStudentUser(name, photoUrl, overrides = {}) {
  return studentUser({
    display_name: name,
    photo_url: photoUrl,
    ...overrides,
  });
}

function teacherUser(overrides = {}) {
  return {
    role: "native_speaker",
    isInCall: false,
    currentSessionId: "",
    display_name: "Teacher",
    photo_url: "teacher-photo",
    ...overrides,
  };
}

function namedTeacherUser(name, photoUrl, overrides = {}) {
  return teacherUser({
    display_name: name,
    photo_url: photoUrl,
    ...overrides,
  });
}

function createFakeFirestore(seed = {}, {
  maxTransactionAttempts = 5,
  onBeforeCommit = null,
  retryOnConcurrentModification = false,
} = {}) {
  const store = new Map(Object.entries(seed));
  const versions = new Map(Array.from(store.keys(), (path) => [path, 0]));
  const reads = [];
  const writes = [];
  let autoId = 0;

  const makeRef = (path) => ({
    path,
    id: path.split("/").pop(),
    async get() {
      const data = store.get(path);
      return {
        exists: data !== undefined,
        data: () => data,
        ref: makeRef(path),
      };
    },
  });

  const makeCollection = (path) => ({
    doc(id) {
      const documentId = id || `auto-${autoId += 1}`;
      return makeRef(`${path}/${documentId}`);
    },
  });

  const db = {
    collection(name) {
      return makeCollection(name);
    },
    async runTransaction(callback) {
      for (let attempt = 1; attempt <= maxTransactionAttempts; attempt += 1) {
        let hasWrites = false;
        const pendingWrites = [];
        const attemptWrites = [];
        const readVersions = new Map();
        const writeLog = retryOnConcurrentModification ? attemptWrites : writes;
        const transaction = {
          async get(ref) {
            if (hasWrites) {
              throw new Error("Firestore transactions require reads first");
            }
            reads.push(ref.path);
            if (!readVersions.has(ref.path)) {
              readVersions.set(ref.path, versions.get(ref.path) || 0);
            }
            return ref.get();
          },
          create(ref, data) {
            hasWrites = true;
            if (
              store.has(ref.path) ||
              pendingWrites.some((write) => write.path === ref.path)
            ) {
              throw new Error(`Document already exists: ${ref.path}`);
            }
            writeLog.push({type: "create", path: ref.path, data});
            pendingWrites.push({type: "create", path: ref.path, data});
          },
          update(ref, data) {
            hasWrites = true;
            if (!store.has(ref.path)) {
              throw new Error(`Document does not exist: ${ref.path}`);
            }
            writeLog.push({type: "update", path: ref.path, data});
            pendingWrites.push({type: "update", path: ref.path, data});
          },
        };
        const result = await callback(transaction);
        if (onBeforeCommit) {
          await onBeforeCommit({attempt, store, versions});
        }
        if (retryOnConcurrentModification) {
          const staleRead = Array.from(readVersions).some(
            ([path, version]) => (versions.get(path) || 0) !== version,
          );
          if (staleRead) {
            continue;
          }
          writes.push(...attemptWrites);
        }
        for (const write of pendingWrites) {
          if (write.type === "create") {
            store.set(write.path, write.data);
          } else {
            store.set(write.path, {...store.get(write.path), ...write.data});
          }
          versions.set(write.path, (versions.get(write.path) || 0) + 1);
        }
        return result;
      }
      throw new Error("Simulated transaction retry limit exceeded");
    },
  };

  return {db, reads, store, versions, writes};
}

function seedStudentPair() {
  return {
    "users/student-a": studentUser(),
    "users/student-b": studentUser(),
    "searchRequests/student-a": activeSearchRequest("student-a"),
    "searchRequests/student-b": activeSearchRequest("student-b"),
  };
}

function existingSearchingSession(overrides = {}) {
  return {
    status: "searching",
    language: "en",
    studentId: "student-a",
    requesterId: "student-a",
    requesterRole: "student",
    currentTutorId: "student-b",
    currentResponderId: "student-b",
    currentResponderRole: "student",
    responderId: "student-b",
    responderRole: "student",
    participantIds: ["student-a", "student-b"],
    searchRequestIds: {
      requester: "request-student-a",
      responder: "request-student-b",
    },
    triedTutors: [],
    availableTutors: ["student-b", "student-c"],
    participantRoles: {
      "student-a": "student",
      "student-b": "student",
    },
    participantInfos: {},
    ...overrides,
  };
}

function seedExistingStudentSession() {
  return {
    "users/student-a": studentUser({currentSessionId: "session-ab"}),
    "users/student-b": studentUser({currentSessionId: "session-ab"}),
    "users/student-c": studentUser(),
    "searchRequests/student-a": activeSearchRequest("student-a", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      currentSessionId: "session-ab",
      matchedSessionId: "session-ab",
      matchedUserId: "student-b",
      matchedResponderId: "student-b",
      matchedRole: "student",
      pairAttemptId: "pair-session-ab-student-a-student-b",
      lockOwner: "pair-session-ab-student-a-student-b",
      lockExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
    }),
    "searchRequests/student-b": activeSearchRequest("student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      currentSessionId: "session-ab",
      matchedSessionId: "session-ab",
      matchedUserId: "student-a",
      matchedResponderId: "student-b",
      matchedRole: "student",
      pairAttemptId: "pair-session-ab-student-a-student-b",
      lockOwner: "pair-session-ab-student-a-student-b",
      lockExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
    }),
    "searchRequests/student-c": activeSearchRequest("student-c"),
    "videoSessions/session-ab": existingSearchingSession(),
  };
}

test("pair attempt id is stable and document safe", () => {
  assert.equal(
    buildPairAttemptId({
      sessionId: "session-ab",
      requesterId: "student-a",
      responderId: "student-b",
    }),
    "pair_session-ab_student-a_student-b",
  );
});

test("live request lock blocks pair reservation", () => {
  assert.deepEqual(
    validateSearchRequestForPairLock({
      requestExists: true,
      requestData: activeSearchRequest("student-b", {
        lockOwner: "pair-old",
        lockExpiresAt: timestampFromMillis(fixedNowMillis + 1000),
      }),
      userId: "student-b",
      nowMillis: fixedNowMillis,
      participantKey: "responder",
    }),
    {ok: false, reason: "responder_search_locked"},
  );
});

test("invalid request id cannot bypass request guard", () => {
  assert.deepEqual(
    validateSearchRequestForPairLock({
      requestExists: true,
      requestData: activeSearchRequest("student-b"),
      userId: "student-b",
      requestId: "requests/request-student-b",
      nowMillis: fixedNowMillis,
      participantKey: "responder",
    }),
    {ok: false, reason: "responder_search_request_mismatch"},
  );
});

test("stale search request cannot be reserved", () => {
  assert.deepEqual(
    validateSearchRequestForPairLock({
      requestExists: true,
      requestData: activeSearchRequest("student-b", {
        heartbeatAt: timestampFromMillis(fixedNowMillis - 91 * 1000),
      }),
      userId: "student-b",
      nowMillis: fixedNowMillis,
      participantKey: "responder",
    }),
    {ok: false, reason: "responder_search_stale"},
  );
  assert.deepEqual(
    validateSearchRequestForPairLock({
      requestExists: true,
      requestData: activeSearchRequest("student-b", {
        expiresAt: timestampFromMillis(fixedNowMillis),
      }),
      userId: "student-b",
      nowMillis: fixedNowMillis,
      participantKey: "responder",
    }),
    {ok: false, reason: "responder_search_stale"},
  );
  assert.deepEqual(
    validateSearchRequestForPairLock({
      requestExists: true,
      requestData: activeSearchRequest("student-b", {
        appState: "background",
        heartbeatAt: timestampFromMillis(fixedNowMillis - 91 * 1000),
        backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 60 * 1000),
      }),
      userId: "student-b",
      nowMillis: fixedNowMillis,
      participantKey: "responder",
    }),
    {ok: false, reason: "responder_search_stale"},
  );
});

test("expired request lock without session can be reserved again", () => {
  assert.deepEqual(
    validateSearchRequestForPairLock({
      requestExists: true,
      requestData: activeSearchRequest("student-b", {
        status: SEARCH_REQUEST_STATUS.MATCHING,
        lockOwner: "pair-old",
        lockExpiresAt: timestampFromMillis(fixedNowMillis - 1000),
      }),
      userId: "student-b",
      nowMillis: fixedNowMillis,
      participantKey: "responder",
    }),
    {ok: true, reason: "ready"},
  );
});

test("matched search request cannot be reserved as a new candidate", () => {
  assert.deepEqual(
    validateSearchRequestForPairLock({
      requestExists: true,
      requestData: activeSearchRequest("student-b", {
        status: SEARCH_REQUEST_STATUS.MATCHED,
      }),
      userId: "student-b",
      nowMillis: fixedNowMillis,
      participantKey: "responder",
    }),
    {ok: false, reason: "responder_search_status_matched"},
  );
  assert.deepEqual(
    validateSearchRequestForPairLock({
      requestExists: true,
      requestData: activeSearchRequest("student-b", {
        status: SEARCH_REQUEST_STATUS.MATCHED,
        currentSessionId: "session-existing",
        matchedSessionId: "session-existing",
      }),
      userId: "student-b",
      nowMillis: fixedNowMillis,
      participantKey: "responder",
    }),
    {ok: false, reason: "responder_search_in_session"},
  );
});

test("reserveMatchPair requires fresh lifecycle request ids", async () => {
  const {db, writes} = createFakeFirestore(seedStudentPair());

  const result = await reserveMatchPair({
    db,
    requesterId: "student-a",
    responderId: "student-b",
    responderRole: "student",
    sessionId: "session-ab",
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.deepEqual(result, {
    locked: false,
    reason: "requester_search_request_id_required",
  });
  assert.equal(writes.length, 0);
});

test("reserveMatchPair rejects active request language mismatch", async () => {
  const {db, writes} = createFakeFirestore({
    ...seedStudentPair(),
    "searchRequests/student-b": activeSearchRequest("student-b", {
      language: "es",
    }),
  });

  const result = await reserveMatchPair({
    db,
    requesterId: "student-a",
    responderId: "student-b",
    responderRole: "student",
    requesterSearchRequestId: "request-student-a",
    responderSearchRequestId: "request-student-b",
    expectedLanguage: "en",
    sessionId: "session-ab",
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.deepEqual(result, {
    locked: false,
    reason: "responder_search_language_mismatch",
  });
  assert.equal(writes.length, 0);
});

test("existing session handoff rejects active request language mismatch", async () => {
  const {db, store, writes} = createFakeFirestore({
    ...seedExistingStudentSession(),
    "searchRequests/student-c": activeSearchRequest("student-c", {
      language: "es",
    }),
  });

  const result = await db.runTransaction((transaction) =>
    prepareExistingSessionNextResponderPairLockInTransaction({
      db,
      transaction,
      sessionId: "session-ab",
      sessionData: store.get("videoSessions/session-ab"),
      currentResponderId: "student-b",
      responderId: "student-c",
      responderRole: "student",
      expectedLanguage: "en",
      triedTutors: ["student-b"],
      nowMillis: fixedNowMillis,
      serverTimestamp,
      lockExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
      fieldDelete,
    }));

  assert.deepEqual(result, {
    locked: false,
    reason: "responder_search_language_mismatch",
  });
  assert.equal(writes.length, 0);
});

test("invalid pairAttemptId cannot be used for a lock", async () => {
  const {db, writes} = createFakeFirestore(seedStudentPair());

  const result = await reserveMatchPair({
    db,
    requesterId: "student-a",
    responderId: "student-b",
    responderRole: "student",
    sessionId: "session-ab",
    pairAttemptId: "pairs/pair-ab",
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.deepEqual(result, {
    locked: false,
    reason: "invalid_pair_lock_input",
  });
  assert.equal(writes.length, 0);
});

test("invalid explicit session id does not create an auto session", async () => {
  const {db, store, writes} = createFakeFirestore(seedStudentPair());

  const result = await reserveMatchPair({
    db,
    requesterId: "student-a",
    responderId: "student-b",
    responderRole: "student",
    requesterSearchRequestId: "request-student-a",
    responderSearchRequestId: "request-student-b",
    sessionId: "videoSessions/session-ab",
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.deepEqual(result, {
    locked: false,
    reason: "invalid_pair_lock_input",
  });
  assert.equal(writes.length, 0);
  assert.equal(store.get("videoSessions/session-ab"), undefined);
});

test("reserveMatchPair atomically locks two student participants", async () => {
  const {db, reads, store, writes} = createFakeFirestore({
    ...seedStudentPair(),
    "users/student-a": namedStudentUser("Ana", "ana-photo"),
    "users/student-b": namedStudentUser("Ben", "ben-photo"),
  });

  const result = await reserveMatchPair({
    db,
    requesterId: "student-a",
    responderId: "student-b",
    responderRole: "student",
    requesterSearchRequestId: "request-student-a",
    responderSearchRequestId: "request-student-b",
    sessionId: "session-ab",
    sessionData: {language: "en"},
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.equal(result.locked, true);
  assert.equal(result.sessionId, "session-ab");
  assert.equal(result.pairAttemptId, "pair_session-ab_student-a_student-b");
  assert.deepEqual(reads, [
    "videoSessions/session-ab",
    "users/student-a",
    "users/student-b",
    "searchRequests/student-a",
    "searchRequests/student-b",
  ]);
  assert.deepEqual(
    writes.map((write) => write.path),
    [
      "videoSessions/session-ab",
      "searchRequests/student-a",
      "users/student-a",
      "users/student-b",
      "searchRequests/student-b",
    ],
  );

  const session = store.get("videoSessions/session-ab");
  assert.equal(session.status, "pending_confirmation");
  assert.equal(session.pairStatus, "pending_confirmation");
  assert.equal(session.scenario, "student_student");
  assert.deepEqual(session.participantIds, ["student-a", "student-b"]);
  assert.deepEqual(session.participantRoles, {
    "student-a": "student",
    "student-b": "student",
  });
  assert.equal(session.matchLock.owner, result.pairAttemptId);
  assert.equal(session.currentResponderId, "student-b");
  assert.equal(session.currentResponderRole, "student");
  assert.equal(session.currentTutorId, "student-b");
  assert.equal(session.tutorId, null);
  assert.equal(session.responseExpiresAt.toMillis(), fixedNowMillis + 45_000);
  assert.deepEqual(session.searchRequestIds, {
    requester: "request-student-a",
    responder: "request-student-b",
  });
  assert.deepEqual(session.participantInfos, {
    "student-a": {
      displayName: "Ana",
      photoUrl: "ana-photo",
    },
    "student-b": {
      displayName: "Ben",
      photoUrl: "ben-photo",
    },
  });
  assert.deepEqual(session.requesterInfo, {
    displayName: "Ana",
    photoUrl: "ana-photo",
  });
  assert.deepEqual(session.responderInfo, {
    displayName: "Ben",
    photoUrl: "ben-photo",
  });
  assert.deepEqual(session.studentInfo, {
    name: "Ana",
    photo: "ana-photo",
  });
  assert.deepEqual(session.tutorInfo, {
    name: "Ben",
    photo: "ben-photo",
  });
  assert.equal(session.language, "en");

  const requesterRequest = store.get("searchRequests/student-a");
  assert.equal(requesterRequest.status, SEARCH_REQUEST_STATUS.MATCHED);
  assert.equal(requesterRequest.currentSessionId, "session-ab");
  assert.equal(requesterRequest.matchedUserId, "student-b");
  assert.equal(requesterRequest.matchedRole, "student");
  assert.equal(requesterRequest.lockOwner, result.pairAttemptId);

  const responderRequest = store.get("searchRequests/student-b");
  assert.equal(responderRequest.status, SEARCH_REQUEST_STATUS.MATCHED);
  assert.equal(responderRequest.currentSessionId, "session-ab");
  assert.equal(responderRequest.matchedUserId, "student-a");
  assert.equal(responderRequest.matchedResponderId, "student-b");
  assert.equal(responderRequest.matchedRole, "student");
  assert.equal(store.get("users/student-a").currentSessionId, "session-ab");
  assert.equal(store.get("users/student-b").currentSessionId, "session-ab");
});

test("reserveMatchPair locks teacher through user document", async () => {
  const {db, store, writes} = createFakeFirestore({
    "users/student-a": studentUser(),
    "users/teacher-a": teacherUser(),
    "searchRequests/student-a": activeSearchRequest("student-a"),
  });

  const result = await reserveMatchPair({
    db,
    requesterId: "student-a",
    responderId: "teacher-a",
    responderRole: "native_speaker",
    requesterSearchRequestId: "request-student-a",
    sessionId: "session-at",
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.equal(result.locked, true);
  assert.deepEqual(
    writes.map((write) => write.path),
    [
      "videoSessions/session-at",
      "searchRequests/student-a",
      "users/student-a",
      "users/teacher-a",
    ],
  );
  assert.equal(store.get("videoSessions/session-at").scenario, "student_teacher");
  assert.equal(store.get("videoSessions/session-at").tutorId, "teacher-a");
  assert.equal(store.get("videoSessions/session-at").currentTutorId, "teacher-a");
  assert.equal(store.get("videoSessions/session-at").responderId, "teacher-a");
  assert.equal(
    store.get("videoSessions/session-at").responderRole,
    "native_speaker",
  );
  assert.equal(
    store.get("videoSessions/session-at").currentResponderId,
    "teacher-a",
  );
  assert.equal(
    store.get("videoSessions/session-at").currentResponderRole,
    "native_speaker",
  );
  assert.deepEqual(store.get("videoSessions/session-at").participantIds, [
    "student-a",
    "teacher-a",
  ]);
  assert.deepEqual(store.get("videoSessions/session-at").participantRoles, {
    "student-a": "student",
    "teacher-a": "native_speaker",
  });
  assert.deepEqual(store.get("videoSessions/session-at").participantInfos, {
    "student-a": {
      displayName: "Student",
      photoUrl: "student-photo",
    },
    "teacher-a": {
      displayName: "Teacher",
      photoUrl: "teacher-photo",
    },
  });
  assert.deepEqual(store.get("videoSessions/session-at").requesterInfo, {
    displayName: "Student",
    photoUrl: "student-photo",
  });
  assert.deepEqual(store.get("videoSessions/session-at").responderInfo, {
    displayName: "Teacher",
    photoUrl: "teacher-photo",
  });
  assert.deepEqual(store.get("videoSessions/session-at").studentInfo, {
    name: "Student",
    photo: "student-photo",
  });
  assert.deepEqual(store.get("videoSessions/session-at").tutorInfo, {
    name: "Teacher",
    photo: "teacher-photo",
  });
  assert.deepEqual(store.get("videoSessions/session-at").searchRequestIds, {
    requester: "request-student-a",
    responder: null,
  });
  assert.equal(
    store.get("searchRequests/student-a").currentSessionId,
    "session-at",
  );
  assert.equal(
    store.get("searchRequests/student-a").matchedSessionId,
    "session-at",
  );
  assert.equal(store.get("searchRequests/student-a").matchedUserId, "teacher-a");
  assert.equal(
    store.get("searchRequests/student-a").matchedResponderId,
    "teacher-a",
  );
  assert.equal(
    store.get("searchRequests/student-a").matchedRole,
    "native_speaker",
  );
  assert.equal(
    store.get("searchRequests/student-a").pairAttemptId,
    result.pairAttemptId,
  );
  assert.equal(
    store.get("searchRequests/student-a").lockOwner,
    result.pairAttemptId,
  );
  assert.equal(
    store.get("searchRequests/student-a").lockExpiresAt.toMillis(),
    fixedNowMillis + 45_000,
  );
  assert.equal(
    store.get("searchRequests/student-a").status,
    SEARCH_REQUEST_STATUS.MATCHED,
  );
  assert.equal(store.get("searchRequests/student-a").updatedAt, serverTimestamp);
  assert.equal(store.get("searchRequests/student-a").lastError, null);
  assert.equal(store.get("users/teacher-a").currentSessionId, "session-at");
});

test("reserveDirectPair locks requester and teacher without search requests", async () => {
  const {db, store, writes} = createFakeFirestore({
    "users/student-a": studentUser(),
    "users/teacher-a": teacherUser(),
  });
  const result = await db.runTransaction((transaction) =>
    reserveDirectPairInTransaction({
      db,
      transaction,
      requesterId: "student-a",
      responderId: "teacher-a",
      responderRole: "native_speaker",
      sessionRef: db.collection("videoSessions").doc("session-direct"),
      sessionData: {
        language: "en",
        status: "searching",
        availableTutors: ["teacher-a"],
      },
      nowMillis: fixedNowMillis,
      serverTimestamp,
      lockExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
    }));

  assert.equal(result.locked, true);
  assert.deepEqual(
    writes.map((write) => write.path),
    [
      "videoSessions/session-direct",
      "users/student-a",
      "users/teacher-a",
    ],
  );
  assert.equal(store.get("videoSessions/session-direct").currentTutorId, "teacher-a");
  assert.equal(store.get("videoSessions/session-direct").tutorId, "teacher-a");
  assert.equal(store.get("videoSessions/session-direct").scenario, "student_teacher");
  assert.equal(store.get("videoSessions/session-direct").responderId, "teacher-a");
  assert.equal(
    store.get("videoSessions/session-direct").responderRole,
    "native_speaker",
  );
  assert.equal(
    store.get("videoSessions/session-direct").currentResponderId,
    "teacher-a",
  );
  assert.equal(
    store.get("videoSessions/session-direct").currentResponderRole,
    "native_speaker",
  );
  assert.deepEqual(store.get("videoSessions/session-direct").participantIds, [
    "student-a",
    "teacher-a",
  ]);
  assert.deepEqual(store.get("videoSessions/session-direct").participantRoles, {
    "student-a": "student",
    "teacher-a": "native_speaker",
  });
  assert.deepEqual(store.get("videoSessions/session-direct").participantInfos, {
    "student-a": {
      displayName: "Student",
      photoUrl: "student-photo",
    },
    "teacher-a": {
      displayName: "Teacher",
      photoUrl: "teacher-photo",
    },
  });
  assert.deepEqual(store.get("videoSessions/session-direct").requesterInfo, {
    displayName: "Student",
    photoUrl: "student-photo",
  });
  assert.deepEqual(store.get("videoSessions/session-direct").responderInfo, {
    displayName: "Teacher",
    photoUrl: "teacher-photo",
  });
  assert.deepEqual(store.get("videoSessions/session-direct").studentInfo, {
    name: "Student",
    photo: "student-photo",
  });
  assert.deepEqual(store.get("videoSessions/session-direct").tutorInfo, {
    name: "Teacher",
    photo: "teacher-photo",
  });
  assert.deepEqual(store.get("videoSessions/session-direct").searchRequestIds, {
    requester: null,
    responder: null,
  });
  assert.equal(
    store.get("videoSessions/session-direct").status,
    "pending_confirmation",
  );
  assert.equal(store.get("users/student-a").currentSessionId, "session-direct");
  assert.equal(store.get("users/teacher-a").currentSessionId, "session-direct");
});

test("reserveDirectPair refuses student responder without search requests", async () => {
  const {db, store, writes} = createFakeFirestore({
    "users/student-a": studentUser(),
    "users/student-b": studentUser(),
  });
  const result = await db.runTransaction((transaction) =>
    reserveDirectPairInTransaction({
      db,
      transaction,
      requesterId: "student-a",
      responderId: "student-b",
      responderRole: "student",
      sessionRef: db.collection("videoSessions").doc("session-direct"),
      sessionData: {language: "en"},
      nowMillis: fixedNowMillis,
      serverTimestamp,
      lockExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
    }));

  assert.deepEqual(result, {
    locked: false,
    reason: "invalid_pair_lock_input",
  });
  assert.equal(writes.length, 0);
  assert.equal(store.get("videoSessions/session-direct"), undefined);
});

test("reserveDirectPair refuses locked direct responder", async () => {
  const {db, store, writes} = createFakeFirestore({
    "users/student-a": studentUser(),
    "users/teacher-a": teacherUser({currentSessionId: "session-existing"}),
  });
  const result = await db.runTransaction((transaction) =>
    reserveDirectPairInTransaction({
      db,
      transaction,
      requesterId: "student-a",
      responderId: "teacher-a",
      responderRole: "native_speaker",
      sessionRef: db.collection("videoSessions").doc("session-direct"),
      sessionData: {language: "en"},
      nowMillis: fixedNowMillis,
      serverTimestamp,
      lockExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
    }));

  assert.deepEqual(result, {
    locked: false,
    reason: "responder_in_session",
  });
  assert.equal(writes.length, 0);
  assert.equal(store.get("videoSessions/session-direct"), undefined);
});

test("reserveMatchPair returns without writes when responder is locked", async () => {
  const {db, store, writes} = createFakeFirestore({
    ...seedStudentPair(),
    "searchRequests/student-b": activeSearchRequest("student-b", {
      lockOwner: "pair-old",
      lockExpiresAt: timestampFromMillis(fixedNowMillis + 1000),
    }),
  });

  const result = await reserveMatchPair({
    db,
    requesterId: "student-a",
    responderId: "student-b",
    responderRole: "student",
    requesterSearchRequestId: "request-student-a",
    responderSearchRequestId: "request-student-b",
    sessionId: "session-ab",
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.deepEqual(result, {
    locked: false,
    reason: "responder_search_locked",
  });
  assert.equal(writes.length, 0);
  assert.equal(store.get("videoSessions/session-ab"), undefined);
  assert.equal(store.get("users/student-a").currentSessionId, "");
  assert.equal(store.get("users/student-b").currentSessionId, "");
});

test("transaction retry prevents double session for same responder", async () => {
  let injected = false;
  const {db, store, versions, writes} = createFakeFirestore(seedStudentPair(), {
    retryOnConcurrentModification: true,
    onBeforeCommit: async ({attempt, store: currentStore}) => {
      if (attempt !== 1 || injected) {
        return;
      }
      injected = true;
      currentStore.set("users/student-b", {
        ...currentStore.get("users/student-b"),
        currentSessionId: "session-existing",
      });
      currentStore.set("searchRequests/student-b", {
        ...currentStore.get("searchRequests/student-b"),
        status: SEARCH_REQUEST_STATUS.MATCHING,
        currentSessionId: "session-existing",
        lockOwner: "pair-existing",
        lockExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
      });
      versions.set(
        "users/student-b",
        (versions.get("users/student-b") || 0) + 1,
      );
      versions.set(
        "searchRequests/student-b",
        (versions.get("searchRequests/student-b") || 0) + 1,
      );
    },
  });

  const result = await reserveMatchPair({
    db,
    requesterId: "student-a",
    responderId: "student-b",
    responderRole: "student",
    requesterSearchRequestId: "request-student-a",
    responderSearchRequestId: "request-student-b",
    sessionId: "session-ab",
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.deepEqual(result, {
    locked: false,
    reason: "responder_in_session",
  });
  assert.equal(writes.length, 0);
  assert.equal(store.get("videoSessions/session-ab"), undefined);
  assert.equal(store.get("users/student-a").currentSessionId, "");
  assert.equal(store.get("users/student-b").currentSessionId, "session-existing");
});

test("transaction retry prevents double session for same requester", async () => {
  let injected = false;
  const {db, store, versions, writes} = createFakeFirestore({
    ...seedStudentPair(),
    "users/student-c": studentUser(),
    "searchRequests/student-c": activeSearchRequest("student-c"),
  }, {
    retryOnConcurrentModification: true,
    onBeforeCommit: async ({attempt, store: currentStore}) => {
      if (attempt !== 1 || injected) {
        return;
      }
      injected = true;
      currentStore.set("users/student-a", {
        ...currentStore.get("users/student-a"),
        currentSessionId: "session-existing",
      });
      currentStore.set("searchRequests/student-a", {
        ...currentStore.get("searchRequests/student-a"),
        status: SEARCH_REQUEST_STATUS.MATCHING,
        currentSessionId: "session-existing",
        lockOwner: "pair-existing",
        lockExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
      });
      versions.set(
        "users/student-a",
        (versions.get("users/student-a") || 0) + 1,
      );
      versions.set(
        "searchRequests/student-a",
        (versions.get("searchRequests/student-a") || 0) + 1,
      );
    },
  });

  const result = await reserveMatchPair({
    db,
    requesterId: "student-a",
    responderId: "student-c",
    responderRole: "student",
    requesterSearchRequestId: "request-student-a",
    responderSearchRequestId: "request-student-c",
    sessionId: "session-ac",
    nowMillis: fixedNowMillis,
    serverTimestamp,
    timestampFromMillis,
  });

  assert.deepEqual(result, {
    locked: false,
    reason: "requester_in_session",
  });
  assert.equal(writes.length, 0);
  assert.equal(store.get("videoSessions/session-ac"), undefined);
  assert.equal(store.get("users/student-a").currentSessionId, "session-existing");
  assert.equal(store.get("users/student-c").currentSessionId, "");
});

test("existing session handoff refuses an already locked responder", async () => {
  const {db, store, writes} = createFakeFirestore({
    ...seedExistingStudentSession(),
    "users/student-c": studentUser({currentSessionId: "session-existing"}),
    "searchRequests/student-c": activeSearchRequest("student-c", {
      status: SEARCH_REQUEST_STATUS.MATCHING,
      currentSessionId: "session-existing",
      lockOwner: "pair-existing",
      lockExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
    }),
  });

  const result = await db.runTransaction((transaction) =>
    prepareExistingSessionNextResponderPairLockInTransaction({
      db,
      transaction,
      sessionId: "session-ab",
      sessionData: store.get("videoSessions/session-ab"),
      currentResponderId: "student-b",
      responderId: "student-c",
      responderRole: "student",
      triedTutors: ["student-b"],
      nowMillis: fixedNowMillis,
      serverTimestamp,
      lockExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
      fieldDelete,
    }));

  assert.deepEqual(result, {
    locked: false,
    reason: "responder_in_session",
  });
  assert.equal(writes.length, 0);
  assert.equal(store.get("users/student-b").currentSessionId, "session-ab");
});

test("existing session handoff refuses requester matched to another session", async () => {
  const {db, store, writes} = createFakeFirestore({
    "users/student-a": studentUser({currentSessionId: "session-at"}),
    "users/teacher-a": teacherUser({currentSessionId: "session-at"}),
    "users/teacher-b": teacherUser(),
    "searchRequests/student-a": activeSearchRequest("student-a", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      currentSessionId: "session-other",
      matchedSessionId: "session-other",
      matchedUserId: "teacher-a",
      matchedResponderId: "teacher-a",
      matchedRole: "native_speaker",
      pairAttemptId: "pair-session-other-student-a-teacher-a",
      lockOwner: "pair-session-other-student-a-teacher-a",
      lockExpiresAt: timestampFromMillis(fixedNowMillis + 10_000),
    }),
    "videoSessions/session-at": existingSearchingSession({
      currentTutorId: "teacher-a",
      currentResponderId: "teacher-a",
      currentResponderRole: "native_speaker",
      responderId: "teacher-a",
      responderRole: "native_speaker",
      tutorId: "teacher-a",
      scenario: "student_teacher",
      participantIds: ["student-a", "teacher-a"],
      searchRequestIds: {
        requester: "request-student-a",
        responder: null,
      },
    }),
  });

  const result = await db.runTransaction((transaction) =>
    prepareExistingSessionNextResponderPairLockInTransaction({
      db,
      transaction,
      sessionId: "session-at",
      sessionData: store.get("videoSessions/session-at"),
      currentResponderId: "teacher-a",
      responderId: "teacher-b",
      responderRole: "native_speaker",
      triedTutors: ["teacher-a"],
      nowMillis: fixedNowMillis,
      serverTimestamp,
      lockExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
      fieldDelete,
      currentResponderStopReason: "declined",
    }));

  assert.deepEqual(result, {
    locked: false,
    reason: "requester_search_in_other_session",
  });
  assert.equal(writes.length, 0);
  assert.equal(store.get("searchRequests/student-a").currentSessionId, "session-other");
  assert.equal(store.get("users/teacher-b").currentSessionId, "");
});

test("existing session handoff releases old responder and locks next", async () => {
  const {db, store, writes} = createFakeFirestore({
    ...seedExistingStudentSession(),
    "users/student-a": namedStudentUser("Ana", "ana-photo"),
    "users/student-b": namedStudentUser("Ben", "ben-photo", {
      currentSessionId: "session-ab",
    }),
    "users/student-c": namedStudentUser("Cara", "cara-photo"),
    "videoSessions/session-ab": existingSearchingSession({
      acceptingTutorId: "student-b",
      acceptingAt: timestampFromMillis(fixedNowMillis - 5_000),
      acceptAttemptId: "attempt-old",
    }),
  });

  const result = await db.runTransaction(async (transaction) => {
    const prepared =
      await prepareExistingSessionNextResponderPairLockInTransaction({
        db,
        transaction,
        sessionId: "session-ab",
        sessionData: store.get("videoSessions/session-ab"),
        currentResponderId: "student-b",
        responderId: "student-c",
        responderRole: "student",
        triedTutors: ["student-b"],
        nowMillis: fixedNowMillis,
        serverTimestamp,
        lockExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
        fieldDelete,
        currentResponderSearchRequestStatus: SEARCH_REQUEST_STATUS.CANCELLED,
        currentResponderStopReason: "declined",
      });
    applyPreparedPairLockWrites(transaction, prepared);
    return prepared;
  });

  assert.equal(result.locked, true);
  assert.equal(result.responderId, "student-c");
  assert.equal(store.get("videoSessions/session-ab").currentTutorId, "student-c");
  assert.equal(store.get("videoSessions/session-ab").responderId, "student-c");
  assert.equal(store.get("videoSessions/session-ab").scenario, "student_student");
  assert.equal(store.get("videoSessions/session-ab").tutorId, null);
  assert.equal(store.get("videoSessions/session-ab").acceptingTutorId, fieldDelete);
  assert.equal(store.get("videoSessions/session-ab").acceptingAt, fieldDelete);
  assert.equal(store.get("videoSessions/session-ab").acceptAttemptId, fieldDelete);
  assert.deepEqual(store.get("videoSessions/session-ab").participantRoles, {
    "student-a": "student",
    "student-c": "student",
  });
  assert.deepEqual(store.get("videoSessions/session-ab").participantInfos, {
    "student-a": {
      displayName: "Ana",
      photoUrl: "ana-photo",
    },
    "student-c": {
      displayName: "Cara",
      photoUrl: "cara-photo",
    },
  });
  assert.deepEqual(store.get("videoSessions/session-ab").requesterInfo, {
    displayName: "Ana",
    photoUrl: "ana-photo",
  });
  assert.deepEqual(store.get("videoSessions/session-ab").responderInfo, {
    displayName: "Cara",
    photoUrl: "cara-photo",
  });
  assert.deepEqual(store.get("videoSessions/session-ab").studentInfo, {
    name: "Ana",
    photo: "ana-photo",
  });
  assert.deepEqual(store.get("videoSessions/session-ab").tutorInfo, {
    name: "Cara",
    photo: "cara-photo",
  });
  assert.deepEqual(store.get("videoSessions/session-ab").participantIds, [
    "student-a",
    "student-c",
  ]);
  assert.equal(store.get("users/student-b").currentSessionId, fieldDelete);
  assert.equal(store.get("users/student-c").currentSessionId, "session-ab");
  assert.equal(
    store.get("searchRequests/student-b").status,
    SEARCH_REQUEST_STATUS.CANCELLED,
  );
  assert.equal(store.get("searchRequests/student-b").currentSessionId, null);
  assert.equal(
    store.get("searchRequests/student-c").currentSessionId,
    "session-ab",
  );
  assert.deepEqual(store.get("videoSessions/session-ab").searchRequestIds, {
    requester: "request-student-a",
    responder: "request-student-c",
  });
  assert.equal(store.get("searchRequests/student-c").matchedUserId, "student-a");
  assert.deepEqual(
    writes.map((write) => write.path),
    [
      "users/student-b",
      "searchRequests/student-b",
      "videoSessions/session-ab",
      "searchRequests/student-a",
      "users/student-a",
      "users/student-c",
      "searchRequests/student-c",
    ],
  );
});

test("existing session handoff reuses session for next teacher", async () => {
  const {db, store, writes} = createFakeFirestore({
    "users/student-a": namedStudentUser("Ana", "ana-photo", {
      currentSessionId: "session-at",
    }),
    "users/teacher-a": namedTeacherUser("Tia", "tia-photo", {
      currentSessionId: "session-at",
    }),
    "users/teacher-b": namedTeacherUser("Bea", "bea-photo"),
    "searchRequests/student-a": activeSearchRequest("student-a", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      currentSessionId: "session-at",
      matchedSessionId: "session-at",
      matchedUserId: "teacher-a",
      matchedResponderId: "teacher-a",
      matchedRole: "native_speaker",
      pairAttemptId: "pair-session-at-student-a-teacher-a",
      lockOwner: "pair-session-at-student-a-teacher-a",
      lockExpiresAt: timestampFromMillis(fixedNowMillis + 10_000),
      excludedCandidateIds: ["teacher-old"],
    }),
    "videoSessions/session-at": existingSearchingSession({
      currentTutorId: "teacher-a",
      currentResponderId: "teacher-a",
      currentResponderRole: "native_speaker",
      responderId: "teacher-a",
      responderRole: "native_speaker",
      tutorId: "teacher-a",
      scenario: "student_teacher",
      participantIds: ["student-a", "teacher-a"],
      participantRoles: {
        "student-a": "student",
        "teacher-a": "native_speaker",
      },
      searchRequestIds: {
        requester: "request-student-a",
        responder: null,
      },
      triedTutors: ["teacher-a"],
      availableTutors: ["teacher-a", "teacher-b"],
    }),
  });

  const result = await db.runTransaction(async (transaction) => {
    const prepared =
      await prepareExistingSessionNextResponderPairLockInTransaction({
        db,
        transaction,
        sessionId: "session-at",
        sessionData: store.get("videoSessions/session-at"),
        currentResponderId: "teacher-a",
        responderId: "teacher-b",
        responderRole: "native_speaker",
        triedTutors: ["teacher-a"],
        nowMillis: fixedNowMillis,
        serverTimestamp,
        lockExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
        fieldDelete,
        currentResponderStopReason: "declined",
        requesterExcludedCandidateIds: ["teacher-a"],
      });
    applyPreparedPairLockWrites(transaction, prepared);
    return prepared;
  });

  const session = store.get("videoSessions/session-at");
  assert.equal(result.locked, true);
  assert.equal(result.responderId, "teacher-b");
  assert.equal(result.responderRole, "native_speaker");
  assert.equal(session.scenario, "student_teacher");
  assert.equal(session.currentTutorId, "teacher-b");
  assert.equal(session.currentResponderId, "teacher-b");
  assert.equal(session.currentResponderRole, "native_speaker");
  assert.equal(session.responderId, "teacher-b");
  assert.equal(session.responderRole, "native_speaker");
  assert.equal(session.tutorId, "teacher-b");
  assert.deepEqual(session.participantIds, ["student-a", "teacher-b"]);
  assert.deepEqual(session.participantRoles, {
    "student-a": "student",
    "teacher-b": "native_speaker",
  });
  assert.deepEqual(session.participantInfos, {
    "student-a": {
      displayName: "Ana",
      photoUrl: "ana-photo",
    },
    "teacher-b": {
      displayName: "Bea",
      photoUrl: "bea-photo",
    },
  });
  assert.deepEqual(session.requesterInfo, {
    displayName: "Ana",
    photoUrl: "ana-photo",
  });
  assert.deepEqual(session.responderInfo, {
    displayName: "Bea",
    photoUrl: "bea-photo",
  });
  assert.deepEqual(session.studentInfo, {
    name: "Ana",
    photo: "ana-photo",
  });
  assert.deepEqual(session.tutorInfo, {
    name: "Bea",
    photo: "bea-photo",
  });
  assert.deepEqual(session.searchRequestIds, {
    requester: "request-student-a",
    responder: null,
  });
  assert.equal(store.get("users/teacher-a").currentSessionId, fieldDelete);
  assert.equal(store.get("users/teacher-b").currentSessionId, "session-at");
  assert.equal(
    store.get("searchRequests/student-a").currentSessionId,
    "session-at",
  );
  assert.equal(
    store.get("searchRequests/student-a").matchedSessionId,
    "session-at",
  );
  assert.equal(store.get("searchRequests/student-a").matchedUserId, "teacher-b");
  assert.equal(
    store.get("searchRequests/student-a").matchedResponderId,
    "teacher-b",
  );
  assert.equal(
    store.get("searchRequests/student-a").matchedRole,
    "native_speaker",
  );
  assert.equal(
    store.get("searchRequests/student-a").pairAttemptId,
    result.pairAttemptId,
  );
  assert.equal(
    store.get("searchRequests/student-a").lockOwner,
    result.pairAttemptId,
  );
  assert.equal(
    store.get("searchRequests/student-a").lockExpiresAt.toMillis(),
    fixedNowMillis + 45_000,
  );
  assert.equal(
    store.get("searchRequests/student-a").status,
    SEARCH_REQUEST_STATUS.MATCHED,
  );
  assert.deepEqual(
    store.get("searchRequests/student-a").excludedCandidateIds,
    ["teacher-a", "teacher-old"],
  );
  assert.equal(store.get("searchRequests/teacher-b"), undefined);
  assert.deepEqual(
    writes.map((write) => write.path),
    [
      "users/teacher-a",
      "videoSessions/session-at",
      "searchRequests/student-a",
      "users/student-a",
      "users/teacher-b",
    ],
  );
});

test("existing session timeout handoff excludes timed-out teacher", async () => {
  const {db, store} = createFakeFirestore({
    "users/student-a": namedStudentUser("Ana", "ana-photo", {
      currentSessionId: "session-at",
    }),
    "users/teacher-a": namedTeacherUser("Tia", "tia-photo", {
      currentSessionId: "session-at",
    }),
    "users/teacher-b": namedTeacherUser("Bea", "bea-photo"),
    "searchRequests/student-a": activeSearchRequest("student-a", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      currentSessionId: "session-at",
      matchedSessionId: "session-at",
      matchedUserId: "teacher-a",
      matchedResponderId: "teacher-a",
      matchedRole: "native_speaker",
      pairAttemptId: "pair-session-at-student-a-teacher-a",
      lockOwner: "pair-session-at-student-a-teacher-a",
      lockExpiresAt: timestampFromMillis(fixedNowMillis + 10_000),
      excludedCandidateIds: ["teacher-old"],
    }),
    "videoSessions/session-at": existingSearchingSession({
      currentTutorId: "teacher-a",
      currentResponderId: "teacher-a",
      currentResponderRole: "native_speaker",
      responderId: "teacher-a",
      responderRole: "native_speaker",
      tutorId: "teacher-a",
      scenario: "student_teacher",
      participantIds: ["student-a", "teacher-a"],
      participantRoles: {
        "student-a": "student",
        "teacher-a": "native_speaker",
      },
      searchRequestIds: {
        requester: "request-student-a",
        responder: null,
      },
      triedTutors: ["teacher-a"],
      availableTutors: ["teacher-a", "teacher-b"],
    }),
  });

  const result = await db.runTransaction(async (transaction) => {
    const prepared =
      await prepareExistingSessionNextResponderPairLockInTransaction({
        db,
        transaction,
        sessionId: "session-at",
        sessionData: store.get("videoSessions/session-at"),
        currentResponderId: "teacher-a",
        responderId: "teacher-b",
        responderRole: "native_speaker",
        triedTutors: ["teacher-a"],
        nowMillis: fixedNowMillis,
        serverTimestamp,
        lockExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
        fieldDelete,
        currentResponderSearchRequestStatus: SEARCH_REQUEST_STATUS.EXPIRED,
        currentResponderStopReason: "response_timeout",
        requesterExcludedCandidateIds: ["teacher-a"],
      });
    applyPreparedPairLockWrites(transaction, prepared);
    return prepared;
  });

  const requesterSearch = store.get("searchRequests/student-a");
  assert.equal(result.locked, true);
  assert.equal(store.get("users/teacher-a").currentSessionId, fieldDelete);
  assert.equal(store.get("users/teacher-b").currentSessionId, "session-at");
  assert.equal(requesterSearch.status, SEARCH_REQUEST_STATUS.MATCHED);
  assert.equal(requesterSearch.matchedResponderId, "teacher-b");
  assert.deepEqual(requesterSearch.excludedCandidateIds, [
    "teacher-a",
    "teacher-old",
  ]);
});

test("existing session handoff reuses student session for next teacher", async () => {
  const existingStudentSessionSeed = seedExistingStudentSession();
  const {db, store, writes} = createFakeFirestore({
    ...existingStudentSessionSeed,
    "users/student-a": namedStudentUser("Ana", "ana-photo", {
      currentSessionId: "session-ab",
    }),
    "users/student-b": namedStudentUser("Ben", "ben-photo", {
      currentSessionId: "session-ab",
    }),
    "users/teacher-b": namedTeacherUser("Bea", "bea-photo"),
    "searchRequests/student-a": {
      ...existingStudentSessionSeed["searchRequests/student-a"],
      lockExpiresAt: timestampFromMillis(fixedNowMillis + 10_000),
    },
    "videoSessions/session-ab": existingSearchingSession({
      availableTutors: ["student-b", "teacher-b"],
    }),
  });

  const result = await db.runTransaction(async (transaction) => {
    const prepared =
      await prepareExistingSessionNextResponderPairLockInTransaction({
        db,
        transaction,
        sessionId: "session-ab",
        sessionData: store.get("videoSessions/session-ab"),
        currentResponderId: "student-b",
        responderId: "teacher-b",
        responderRole: "native_speaker",
        triedTutors: ["student-b"],
        nowMillis: fixedNowMillis,
        serverTimestamp,
        lockExpiresAt: timestampFromMillis(fixedNowMillis + 45_000),
        fieldDelete,
        currentResponderSearchRequestStatus: SEARCH_REQUEST_STATUS.CANCELLED,
        currentResponderStopReason: "declined",
      });
    applyPreparedPairLockWrites(transaction, prepared);
    return prepared;
  });

  const session = store.get("videoSessions/session-ab");
  assert.equal(result.locked, true);
  assert.equal(result.responderId, "teacher-b");
  assert.equal(result.responderRole, "native_speaker");
  assert.equal(session.scenario, "student_teacher");
  assert.equal(session.currentTutorId, "teacher-b");
  assert.equal(session.currentResponderId, "teacher-b");
  assert.equal(session.currentResponderRole, "native_speaker");
  assert.equal(session.responderId, "teacher-b");
  assert.equal(session.responderRole, "native_speaker");
  assert.equal(session.tutorId, "teacher-b");
  assert.deepEqual(session.participantIds, ["student-a", "teacher-b"]);
  assert.deepEqual(session.participantRoles, {
    "student-a": "student",
    "teacher-b": "native_speaker",
  });
  assert.deepEqual(session.participantInfos, {
    "student-a": {
      displayName: "Ana",
      photoUrl: "ana-photo",
    },
    "teacher-b": {
      displayName: "Bea",
      photoUrl: "bea-photo",
    },
  });
  assert.deepEqual(session.requesterInfo, {
    displayName: "Ana",
    photoUrl: "ana-photo",
  });
  assert.deepEqual(session.responderInfo, {
    displayName: "Bea",
    photoUrl: "bea-photo",
  });
  assert.deepEqual(session.studentInfo, {
    name: "Ana",
    photo: "ana-photo",
  });
  assert.deepEqual(session.tutorInfo, {
    name: "Bea",
    photo: "bea-photo",
  });
  assert.deepEqual(session.searchRequestIds, {
    requester: "request-student-a",
    responder: null,
  });
  assert.equal(store.get("users/student-b").currentSessionId, fieldDelete);
  assert.equal(store.get("users/teacher-b").currentSessionId, "session-ab");
  assert.equal(
    store.get("searchRequests/student-b").status,
    SEARCH_REQUEST_STATUS.CANCELLED,
  );
  assert.equal(store.get("searchRequests/student-b").stopReason, "declined");
  assert.equal(store.get("searchRequests/student-b").stoppedAt, serverTimestamp);
  assert.equal(store.get("searchRequests/student-b").updatedAt, serverTimestamp);
  assert.equal(
    store.get("searchRequests/student-b").activeSessionId,
    fieldDelete,
  );
  assert.equal(store.get("searchRequests/student-b").currentSessionId, null);
  assert.equal(
    store.get("searchRequests/student-b").matchedSessionId,
    fieldDelete,
  );
  assert.equal(store.get("searchRequests/student-b").matchedUserId, null);
  assert.equal(
    store.get("searchRequests/student-b").matchedResponderId,
    fieldDelete,
  );
  assert.equal(store.get("searchRequests/student-b").matchedRole, null);
  assert.equal(store.get("searchRequests/student-b").pairAttemptId, null);
  assert.deepEqual(
    store.get("searchRequests/student-b").attemptExcludedCandidateIds,
    [],
  );
  assert.equal(store.get("searchRequests/student-b").lockOwner, null);
  assert.equal(store.get("searchRequests/student-b").lockExpiresAt, null);
  assert.equal(store.get("searchRequests/student-b").lastError, null);
  assert.equal(store.get("searchRequests/student-b").errorCode, fieldDelete);
  assert.equal(store.get("searchRequests/student-b").errorMessage, fieldDelete);
  assert.equal(
    store.get("searchRequests/student-a").currentSessionId,
    "session-ab",
  );
  assert.equal(
    store.get("searchRequests/student-a").matchedSessionId,
    "session-ab",
  );
  assert.equal(store.get("searchRequests/student-a").matchedUserId, "teacher-b");
  assert.equal(
    store.get("searchRequests/student-a").matchedResponderId,
    "teacher-b",
  );
  assert.equal(
    store.get("searchRequests/student-a").matchedRole,
    "native_speaker",
  );
  assert.equal(
    store.get("searchRequests/student-a").pairAttemptId,
    result.pairAttemptId,
  );
  assert.equal(
    store.get("searchRequests/student-a").lockOwner,
    result.pairAttemptId,
  );
  assert.equal(
    store.get("searchRequests/student-a").lockExpiresAt.toMillis(),
    fixedNowMillis + 45_000,
  );
  assert.equal(
    store.get("searchRequests/student-a").status,
    SEARCH_REQUEST_STATUS.MATCHED,
  );
  assert.equal(store.get("searchRequests/teacher-b"), undefined);
  assert.deepEqual(
    writes.map((write) => write.path),
    [
      "users/student-b",
      "searchRequests/student-b",
      "videoSessions/session-ab",
      "searchRequests/student-a",
      "users/student-a",
      "users/teacher-b",
    ],
  );
});

test("releaseSessionPairLocks clears users and search requests for session", async () => {
  const {db, store} = createFakeFirestore({
    ...seedExistingStudentSession(),
    "users/student-a": studentUser({
      currentSessionId: "session-ab",
      isInCall: true,
      isAvailable: false,
    }),
    "users/student-b": studentUser({
      currentSessionId: "session-ab",
      isInCall: true,
      isAvailable: false,
    }),
  });

  const result = await db.runTransaction((transaction) =>
    releaseSessionPairLocksInTransaction({
      db,
      transaction,
      sessionId: "session-ab",
      sessionData: store.get("videoSessions/session-ab"),
      serverTimestamp,
      fieldDelete,
      searchRequestStatus: SEARCH_REQUEST_STATUS.STOPPED,
      stopReason: "session_ended",
      releaseCallState: true,
      restoreLegacyAvailability: true,
    }));

  assert.equal(result.released, true);
  assert.deepEqual(result.participantIds, ["student-a", "student-b"]);
  assert.equal(store.get("users/student-a").currentSessionId, fieldDelete);
  assert.equal(store.get("users/student-a").isInCall, false);
  assert.equal(store.get("users/student-a").isAvailable, true);
  assert.equal(store.get("users/student-b").currentSessionId, fieldDelete);
  assert.equal(store.get("searchRequests/student-a").status, SEARCH_REQUEST_STATUS.STOPPED);
  assert.equal(store.get("searchRequests/student-a").currentSessionId, null);
  assert.equal(store.get("searchRequests/student-a").lockOwner, null);
  assert.equal(store.get("searchRequests/student-b").status, SEARCH_REQUEST_STATUS.STOPPED);
  assert.equal(store.get("searchRequests/student-b").matchedUserId, null);
});

test("releaseSessionPairLocks restores selected search participant", async () => {
  const seed = seedExistingStudentSession();
  const requesterExpiresAt = timestampFromMillis(fixedNowMillis + 9 * 60_000);
  const requesterBackgroundExpiresAt =
    timestampFromMillis(fixedNowMillis + 8 * 60_000);
  const {db, store} = createFakeFirestore({
    ...seed,
    "searchRequests/student-a": {
      ...seed["searchRequests/student-a"],
      excludedCandidateIds: ["teacher-old"],
      expiresAt: requesterExpiresAt,
      backgroundExpiresAt: requesterBackgroundExpiresAt,
    },
    "users/student-a": studentUser({
      currentSessionId: "session-ab",
    }),
    "users/student-b": studentUser({
      currentSessionId: "session-ab",
    }),
  });

  const result = await db.runTransaction((transaction) =>
    releaseSessionPairLocksInTransaction({
      db,
      transaction,
      sessionId: "session-ab",
      sessionData: store.get("videoSessions/session-ab"),
      serverTimestamp,
      fieldDelete,
      searchRequestStatus: SEARCH_REQUEST_STATUS.CANCELLED,
      stopReason: "declined",
      restoreSearchParticipantIds: ["student-a"],
      restoreSearchExcludedCandidateIdsByParticipantId: {
        "student-a": ["student-b"],
      },
    }));

  const restoredRequest = store.get("searchRequests/student-a");
  const declinedRequest = store.get("searchRequests/student-b");
  assert.equal(result.released, true);
  assert.equal(restoredRequest.status, SEARCH_REQUEST_STATUS.ACTIVE);
  assert.equal(restoredRequest.heartbeatAt, serverTimestamp);
  assert.equal(restoredRequest.updatedAt, serverTimestamp);
  assert.equal(restoredRequest.activeSessionId, fieldDelete);
  assert.equal(restoredRequest.currentSessionId, null);
  assert.equal(restoredRequest.matchedSessionId, fieldDelete);
  assert.equal(restoredRequest.matchedUserId, null);
  assert.equal(restoredRequest.matchedResponderId, fieldDelete);
  assert.equal(restoredRequest.matchedRole, null);
  assert.equal(restoredRequest.pairAttemptId, null);
  assert.deepEqual(restoredRequest.excludedCandidateIds, [
    "student-b",
    "teacher-old",
  ]);
  assert.deepEqual(restoredRequest.attemptExcludedCandidateIds, []);
  assert.equal(restoredRequest.lockOwner, null);
  assert.equal(restoredRequest.lockExpiresAt, null);
  assert.equal(restoredRequest.stopReason, null);
  assert.equal(restoredRequest.stoppedAt, null);
  assert.equal(restoredRequest.stoppedBy, fieldDelete);
  assert.equal(restoredRequest.expiresAt, requesterExpiresAt);
  assert.equal(
    restoredRequest.backgroundExpiresAt,
    requesterBackgroundExpiresAt,
  );
  assert.equal(declinedRequest.status, SEARCH_REQUEST_STATUS.CANCELLED);
  assert.equal(declinedRequest.stopReason, "declined");
  assert.equal(declinedRequest.activeSessionId, fieldDelete);
  assert.equal(declinedRequest.currentSessionId, null);
  assert.equal(declinedRequest.matchedSessionId, fieldDelete);
  assert.equal(declinedRequest.matchedUserId, null);
  assert.equal(declinedRequest.matchedResponderId, fieldDelete);
  assert.equal(declinedRequest.matchedRole, null);
  assert.equal(declinedRequest.pairAttemptId, null);
  assert.deepEqual(declinedRequest.attemptExcludedCandidateIds, []);
  assert.equal(declinedRequest.lockOwner, null);
  assert.equal(declinedRequest.lockExpiresAt, null);
  assert.equal(declinedRequest.updatedAt, serverTimestamp);
  assert.equal(declinedRequest.stoppedAt, serverTimestamp);
});

test("releaseSessionPairLocks expires unresponsive student and restores requester", async () => {
  const seed = seedExistingStudentSession();
  const requesterExpiresAt = timestampFromMillis(fixedNowMillis + 9 * 60_000);
  const requesterBackgroundExpiresAt =
    timestampFromMillis(fixedNowMillis + 8 * 60_000);
  const {db, store} = createFakeFirestore({
    ...seed,
    "searchRequests/student-a": {
      ...seed["searchRequests/student-a"],
      excludedCandidateIds: ["student-old"],
      expiresAt: requesterExpiresAt,
      backgroundExpiresAt: requesterBackgroundExpiresAt,
    },
  });

  const result = await db.runTransaction((transaction) =>
    releaseSessionPairLocksInTransaction({
      db,
      transaction,
      sessionId: "session-ab",
      sessionData: store.get("videoSessions/session-ab"),
      serverTimestamp,
      fieldDelete,
      searchRequestStatus: SEARCH_REQUEST_STATUS.EXPIRED,
      stopReason: "student_pair_response_timeout",
      restoreSearchParticipantIds: ["student-a"],
      restoreSearchExcludedCandidateIdsByParticipantId: {
        "student-a": ["student-b"],
      },
    }));

  const restoredRequest = store.get("searchRequests/student-a");
  const expiredRequest = store.get("searchRequests/student-b");
  assert.equal(result.released, true);
  assert.deepEqual(result.participantIds, ["student-a", "student-b"]);
  assert.equal(restoredRequest.status, SEARCH_REQUEST_STATUS.ACTIVE);
  assert.deepEqual(restoredRequest.excludedCandidateIds, [
    "student-b",
    "student-old",
  ]);
  assert.equal(restoredRequest.activeSessionId, fieldDelete);
  assert.equal(restoredRequest.currentSessionId, null);
  assert.equal(restoredRequest.matchedSessionId, fieldDelete);
  assert.equal(restoredRequest.matchedUserId, null);
  assert.equal(restoredRequest.matchedResponderId, fieldDelete);
  assert.equal(restoredRequest.matchedRole, null);
  assert.equal(restoredRequest.pairAttemptId, null);
  assert.deepEqual(restoredRequest.attemptExcludedCandidateIds, []);
  assert.equal(restoredRequest.lockOwner, null);
  assert.equal(restoredRequest.lockExpiresAt, null);
  assert.equal(restoredRequest.stopReason, null);
  assert.equal(restoredRequest.stoppedAt, null);
  assert.equal(restoredRequest.updatedAt, serverTimestamp);
  assert.equal(restoredRequest.heartbeatAt, serverTimestamp);
  assert.equal(restoredRequest.expiresAt, requesterExpiresAt);
  assert.equal(
    restoredRequest.backgroundExpiresAt,
    requesterBackgroundExpiresAt,
  );
  assert.equal(expiredRequest.status, SEARCH_REQUEST_STATUS.EXPIRED);
  assert.equal(expiredRequest.stopReason, "student_pair_response_timeout");
  assert.equal(expiredRequest.currentSessionId, null);
  assert.equal(expiredRequest.matchedSessionId, fieldDelete);
  assert.equal(expiredRequest.matchedUserId, null);
  assert.equal(expiredRequest.matchedResponderId, fieldDelete);
  assert.equal(expiredRequest.matchedRole, null);
  assert.equal(expiredRequest.pairAttemptId, null);
  assert.deepEqual(expiredRequest.attemptExcludedCandidateIds, []);
  assert.equal(expiredRequest.lockOwner, null);
  assert.equal(expiredRequest.lockExpiresAt, null);
  assert.equal(expiredRequest.updatedAt, serverTimestamp);
  assert.equal(expiredRequest.stoppedAt, serverTimestamp);
});

test("releaseSessionPairLocks does not reactivate terminal requests", async () => {
  const seed = seedExistingStudentSession();
  const {db, store} = createFakeFirestore({
    ...seed,
    "searchRequests/student-a": {
      ...seed["searchRequests/student-a"],
      status: SEARCH_REQUEST_STATUS.STOPPED,
    },
  });

  await db.runTransaction((transaction) =>
    releaseSessionPairLocksInTransaction({
      db,
      transaction,
      sessionId: "session-ab",
      sessionData: store.get("videoSessions/session-ab"),
      serverTimestamp,
      fieldDelete,
      searchRequestStatus: SEARCH_REQUEST_STATUS.CANCELLED,
      stopReason: "declined",
      restoreSearchParticipantIds: ["student-a"],
      restoreSearchExcludedCandidateIdsByParticipantId: {
        "student-a": ["student-b"],
      },
    }));

  assert.equal(
    store.get("searchRequests/student-a").status,
    SEARCH_REQUEST_STATUS.CANCELLED,
  );
  assert.equal(store.get("searchRequests/student-a").stopReason, "declined");
});

test("active restore helper keeps lifecycle fields and clears match state", () => {
  const update = buildSearchRequestActiveRestoreUpdate({
    requestData: activeSearchRequest("student-a", {
      excludedCandidateIds: ["old-peer"],
    }),
    excludedCandidateIds: ["student-b", "old-peer"],
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(update.status, SEARCH_REQUEST_STATUS.ACTIVE);
  assert.equal(update.heartbeatAt, serverTimestamp);
  assert.deepEqual(update.excludedCandidateIds, ["old-peer", "student-b"]);
  assert.deepEqual(update.attemptExcludedCandidateIds, []);
  assert.equal(update.currentSessionId, null);
  assert.equal(update.matchedUserId, null);
  assert.equal(update.pairAttemptId, null);
  assert.equal(update.stopReason, null);
  assert.equal(update.stoppedAt, null);
  assert.equal(update.stoppedBy, fieldDelete);
  assert.equal(
    canRestoreSearchRequestToActive({status: SEARCH_REQUEST_STATUS.MATCHED}),
    true,
  );
  assert.equal(
    canRestoreSearchRequestToActive({status: SEARCH_REQUEST_STATUS.STOPPED}),
    false,
  );
});

test("stopSessionSearchRequests stops search without clearing active call users", async () => {
  const {db, store} = createFakeFirestore({
    ...seedExistingStudentSession(),
    "users/student-a": studentUser({
      currentSessionId: "session-ab",
      isInCall: true,
    }),
    "users/student-b": studentUser({
      currentSessionId: "session-ab",
      isInCall: true,
    }),
  });

  const result = await db.runTransaction((transaction) =>
    stopSessionSearchRequestsInTransaction({
      db,
      transaction,
      sessionId: "session-ab",
      sessionData: store.get("videoSessions/session-ab"),
      serverTimestamp,
      fieldDelete,
    }));

  assert.equal(result.stopped, true);
  assert.deepEqual(result.stoppedParticipantIds, ["student-a", "student-b"]);
  assert.equal(store.get("users/student-a").currentSessionId, "session-ab");
  assert.equal(store.get("users/student-a").isInCall, true);
  assert.equal(store.get("users/student-b").currentSessionId, "session-ab");
  assert.equal(store.get("users/student-b").isInCall, true);
  assert.equal(store.get("searchRequests/student-a").status, SEARCH_REQUEST_STATUS.STOPPED);
  assert.equal(store.get("searchRequests/student-a").stopReason, "call_started");
  assert.equal(store.get("searchRequests/student-a").currentSessionId, null);
  assert.equal(store.get("searchRequests/student-a").matchedSessionId, fieldDelete);
  assert.equal(store.get("searchRequests/student-a").matchedUserId, null);
  assert.equal(store.get("searchRequests/student-b").status, SEARCH_REQUEST_STATUS.STOPPED);
  assert.equal(store.get("searchRequests/student-b").stopReason, "call_started");
});

test("stopSessionSearchRequests uses accepted match context participant fallback", async () => {
  const {db, store} = createFakeFirestore({
    "searchRequests/student-a": activeSearchRequest("student-a", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      currentSessionId: "session-ab",
      matchedSessionId: "session-ab",
      matchedUserId: "student-b",
      matchedResponderId: "student-b",
      matchedRole: "student",
    }),
    "searchRequests/student-b": activeSearchRequest("student-b", {
      status: SEARCH_REQUEST_STATUS.MATCHED,
      currentSessionId: "session-ab",
      matchedSessionId: "session-ab",
      matchedUserId: "student-a",
      matchedResponderId: "student-b",
      matchedRole: "student",
    }),
    "videoSessions/session-ab": {
      status: "active",
      matchContext: {
        requesterId: "student-a",
        acceptedResponderId: "student-b",
      },
    },
  });

  const result = await db.runTransaction((transaction) =>
    stopSessionSearchRequestsInTransaction({
      db,
      transaction,
      sessionId: "session-ab",
      sessionData: store.get("videoSessions/session-ab"),
      serverTimestamp,
      fieldDelete,
    }));

  assert.deepEqual(result.stoppedParticipantIds, ["student-a", "student-b"]);
  assert.equal(store.get("searchRequests/student-a").status, SEARCH_REQUEST_STATUS.STOPPED);
  assert.equal(store.get("searchRequests/student-b").status, SEARCH_REQUEST_STATUS.STOPPED);
});
