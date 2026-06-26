const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");
const {
  getUtcDayKey,
} = require("./match_repeat_prevention");
const {
  SEARCH_REQUEST_STATUS,
} = require("./search_requests");
const {
  releaseSessionPairLocksInTransaction,
} = require("./match_pair_lock");
const {
  __private__: {
    buildExpiredSessionReleaseOptions,
    buildJoinTimeoutParticipantState,
    buildExpiredSessionCleanupPayload,
    getSessionCleanupDeadlineMillis,
    hasConnectedCallEvidence,
    queueExpiredSessionCleanup,
    readConnectedSignalParticipantIds,
    timestampToMillis,
  },
} = require("./cleanup_expired_sessions");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "demo-smalltalk" });
}

function timestampFromMillis(millis) {
  return {
    toMillis: () => millis,
    toDate: () => new Date(millis),
  };
}

function createFakeFirestore(seed = {}) {
  const store = new Map(Object.entries(seed));

  const makeRef = (pathValue) => ({
    path: pathValue,
    id: pathValue.split("/").pop(),
    async get() {
      const data = store.get(pathValue);
      return {
        exists: data !== undefined,
        data: () => data,
        ref: makeRef(pathValue),
      };
    },
  });

  return {
    db: {
      collection(name) {
        return {
          doc(id) {
            return makeRef(`${name}/${id}`);
          },
        };
      },
      async runTransaction(callback) {
        const transaction = {
          async get(ref) {
            return ref.get();
          },
          update(ref, data) {
            if (!store.has(ref.path)) {
              throw new Error(`Document does not exist: ${ref.path}`);
            }
            store.set(ref.path, {...store.get(ref.path), ...data});
          },
        };
        return callback(transaction);
      },
    },
    store,
  };
}

function matchedSearchRequest(userId, otherUserId, overrides = {}) {
  return {
    requestId: `request-${userId}`,
    userId,
    status: SEARCH_REQUEST_STATUS.MATCHED,
    activeSessionId: null,
    currentSessionId: "session-ab",
    matchedSessionId: "session-ab",
    matchedUserId: otherUserId,
    matchedResponderId: otherUserId,
    matchedRole: "student",
    pairAttemptId: "pair-session-ab-student-a-student-b",
    excludedCandidateIds: [],
    attemptExcludedCandidateIds: [],
    lockOwner: "pair-session-ab-student-a-student-b",
    lockExpiresAt: timestampFromMillis(Date.parse("2026-04-14T12:00:45Z")),
    ...overrides,
  };
}

test("connected expired sessions write same-day repeat history", () => {
  const db = admin.firestore();
  const endedAtMillis = Date.parse("2026-04-14T10:15:00Z");
  const sessionRef = db.collection("videoSessions").doc("connected-session");
  const sessionData = {
    studentId: "student-a",
    tutorId: "teacher-b",
    createdAt: admin.firestore.Timestamp.fromMillis(
      endedAtMillis - 10 * 60 * 1000,
    ),
    startedAt: admin.firestore.Timestamp.fromMillis(
      endedAtMillis - 5 * 60 * 1000,
    ),
    matchContext: {
      requesterId: "student-a",
    },
    sessionMetadata: {
      callConnectedAt: admin.firestore.Timestamp.fromMillis(
        endedAtMillis - 5 * 60 * 1000,
      ),
    },
  };

  const payload = buildExpiredSessionCleanupPayload({
    db,
    sessionId: sessionRef.id,
    sessionRef,
    sessionData,
    endedAtMillis,
  });

  assert.equal(payload.tutorId, "teacher-b");
  assert.equal(payload.duration, 300);
  assert.equal(payload.sessionUpdate.status, "ended");
  assert.notEqual(payload.sessionUpdate.acceptAttemptId, undefined);
  assert.equal(payload.sessionUpdate.sessionMetadata.endReason, "expired");
  assert.equal(
    payload.sessionUpdate["matchContext.completedPairId"],
    "student-a_teacher-b",
  );
  assert.equal(
    payload.sessionUpdate["matchContext.completedDayKey"],
    getUtcDayKey(endedAtMillis),
  );
  assert.ok(payload.pairHistoryWrite);
  assert.equal(payload.pairHistoryWrite.pairId, "student-a_teacher-b");
  assert.equal(payload.pairHistoryWrite.dayKey, getUtcDayKey(endedAtMillis));
  assert.deepEqual(
    payload.pairHistoryWrite.data.participantIds,
    ["student-a", "teacher-b"],
  );
  assert.equal(
    payload.pairHistoryWrite.data.latestCompletedAtMillis,
    endedAtMillis,
  );
});

test("never-connected expired sessions do not write same-day repeat history", () => {
  const db = admin.firestore();
  const endedAtMillis = Date.parse("2026-04-14T11:00:00Z");
  const sessionRef = db.collection("videoSessions").doc("never-connected");
  const sessionData = {
    studentId: "student-a",
    tutorId: "teacher-b",
    createdAt: admin.firestore.Timestamp.fromMillis(
      endedAtMillis - 45 * 1000,
    ),
    matchContext: {
      requesterId: "student-a",
    },
  };

  const payload = buildExpiredSessionCleanupPayload({
    db,
    sessionId: sessionRef.id,
    sessionRef,
    sessionData,
    endedAtMillis,
  });

  assert.equal(payload.duration, 45);
  assert.equal(payload.sessionUpdate.status, "ended");
  assert.equal(payload.sessionUpdate.sessionMetadata.endReason, "expired");
  assert.equal(
    payload.sessionUpdate["matchContext.completedPairId"],
    undefined,
  );
  assert.equal(payload.pairHistoryWrite, null);
});

test("never-connected connecting sessions expire instead of ending", () => {
  const db = admin.firestore();
  const endedAtMillis = Date.parse("2026-04-14T11:05:00Z");
  const sessionRef = db.collection("videoSessions").doc("connecting-timeout");
  const sessionData = {
    status: "connecting",
    studentId: "student-a",
    tutorId: "teacher-b",
    createdAt: admin.firestore.Timestamp.fromMillis(
      endedAtMillis - 60 * 1000,
    ),
    matchContext: {
      requesterId: "student-a",
    },
  };

  const payload = buildExpiredSessionCleanupPayload({
    db,
    sessionId: sessionRef.id,
    sessionRef,
    sessionData,
    endedAtMillis,
  });

  assert.equal(payload.sessionUpdate.status, "expired");
  assert.notEqual(payload.sessionUpdate.acceptAttemptId, undefined);
  assert.equal(payload.sessionUpdate.expireReason, "join_timeout");
  assert.equal(payload.sessionUpdate.sessionMetadata.endReason, "join_timeout");
  assert.deepEqual(
    payload.sessionUpdate.sessionMetadata.joinTimeoutParticipantIds,
    ["student-a", "teacher-b"],
  );
  assert.deepEqual(
    payload.sessionUpdate.sessionMetadata.joinTimeoutJoinedParticipantIds,
    [],
  );
  assert.deepEqual(
    payload.sessionUpdate.sessionMetadata.joinTimeoutMissingParticipantIds,
    ["student-a", "teacher-b"],
  );
  assert.equal(payload.pairHistoryWrite, null);
});

test("one-sided room join timeout expires the pair without repeat history", () => {
  const db = admin.firestore();
  const endedAtMillis = Date.parse("2026-04-14T11:05:00Z");
  const sessionRef = db.collection("videoSessions").doc("one-sided-timeout");
  const sessionData = {
    status: "connecting",
    requesterId: "student-a",
    responderId: "student-b",
    participantIds: ["student-a", "student-b"],
    createdAt: admin.firestore.Timestamp.fromMillis(
      endedAtMillis - 60 * 1000,
    ),
    sessionMetadata: {
      roomJoinParticipantSignals: {
        "student-a": {
          source: "dailyWebhook",
          joinedAt: admin.firestore.Timestamp.fromMillis(
            endedAtMillis - 30 * 1000,
          ),
        },
      },
      roomJoinedParticipantIds: ["student-a"],
      roomJoinSignalsComplete: false,
    },
  };

  const payload = buildExpiredSessionCleanupPayload({
    db,
    sessionId: sessionRef.id,
    sessionRef,
    sessionData,
    endedAtMillis,
  });

  assert.equal(payload.sessionUpdate.status, "expired");
  assert.equal(payload.sessionUpdate.expireReason, "join_timeout");
  assert.equal(payload.sessionUpdate.sessionMetadata.endReason, "join_timeout");
  assert.deepEqual(
    payload.sessionUpdate.sessionMetadata.joinTimeoutParticipantIds,
    ["student-a", "student-b"],
  );
  assert.deepEqual(
    payload.sessionUpdate.sessionMetadata.joinTimeoutJoinedParticipantIds,
    ["student-a"],
  );
  assert.deepEqual(
    payload.sessionUpdate.sessionMetadata.joinTimeoutMissingParticipantIds,
    ["student-b"],
  );
  assert.equal(payload.pairHistoryWrite, null);
});

test("join timeout participant state ignores nonparticipants", () => {
  const state = buildJoinTimeoutParticipantState({
    status: "connecting",
    requesterId: "student-a",
    responderId: "student-b",
    participantIds: ["student-a", "student-b"],
    sessionMetadata: {
      roomJoinParticipantSignals: {
        "student-a": {source: "markSessionConnected"},
        "unknown-user": {source: "dailyWebhook"},
      },
    },
  });

  assert.deepEqual(state, {
    participantIds: ["student-a", "student-b"],
    joinedParticipantIds: ["student-a"],
    missingParticipantIds: ["student-b"],
  });
});

test("cleanup deadline uses join deadline for connecting sessions", () => {
  const nowMillis = Date.parse("2026-04-14T11:05:00Z");
  const joinDeadlineAt = admin.firestore.Timestamp.fromMillis(nowMillis - 1);
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    nowMillis + 5 * 60 * 1000,
  );

  assert.equal(
    getSessionCleanupDeadlineMillis({
      status: "connecting",
      joinDeadlineAt,
      expiresAt,
    }),
    joinDeadlineAt.toMillis(),
  );
});

test("cleanup deadline keeps active sessions on session expiry", () => {
  const nowMillis = Date.parse("2026-04-14T11:05:00Z");
  const joinDeadlineAt = admin.firestore.Timestamp.fromMillis(nowMillis - 1);
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    nowMillis + 5 * 60 * 1000,
  );

  assert.equal(
    getSessionCleanupDeadlineMillis({
      status: "active",
      joinDeadlineAt,
      expiresAt,
    }),
    expiresAt.toMillis(),
  );
});

test("cleanup deadline falls back for legacy connecting sessions", () => {
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    Date.parse("2026-04-14T11:05:00Z"),
  );

  assert.equal(
    getSessionCleanupDeadlineMillis({
      status: "connecting",
      expiresAt,
    }),
    expiresAt.toMillis(),
  );
  assert.equal(timestampToMillis("bad"), 0);
});

test("join timeout state includes only valid joined participants", () => {
  const sessionData = {
    status: "connecting",
    participantIds: ["student-a", "student-b"],
    studentId: "student-a",
    currentTutorId: "student-b",
    sessionMetadata: {
      connectedParticipantSignals: {
        "student-a": {source: "markSessionConnected"},
        "unknown-user": {source: "markSessionConnected"},
      },
    },
  };

  const participantState = buildJoinTimeoutParticipantState(sessionData);

  assert.deepEqual(readConnectedSignalParticipantIds(sessionData), [
    "student-a",
  ]);
  assert.deepEqual(participantState.participantIds, [
    "student-a",
    "student-b",
  ]);
  assert.deepEqual(participantState.joinedParticipantIds, ["student-a"]);
  assert.deepEqual(participantState.missingParticipantIds, ["student-b"]);
});

test("join timeout state includes Daily webhook join signals", () => {
  const sessionData = {
    status: "connecting",
    participantIds: ["student-a", "student-b"],
    studentId: "student-a",
    currentTutorId: "student-b",
    sessionMetadata: {
      dailyWebhookParticipantSignals: {
        "student-b": {source: "dailyWebhook"},
        "unknown-user": {source: "dailyWebhook"},
      },
    },
  };

  const participantState = buildJoinTimeoutParticipantState(sessionData);

  assert.deepEqual(participantState.joinedParticipantIds, ["student-b"]);
  assert.deepEqual(participantState.missingParticipantIds, ["student-a"]);
});

test("join timeout state includes room join signals", () => {
  const sessionData = {
    status: "connecting",
    participantIds: ["student-a", "student-b"],
    studentId: "student-a",
    currentTutorId: "student-b",
    sessionMetadata: {
      roomJoinParticipantSignals: {
        "student-a": {source: "markSessionConnected"},
        "unknown-user": {source: "markSessionConnected"},
      },
    },
  };

  const participantState = buildJoinTimeoutParticipantState(sessionData);

  assert.deepEqual(participantState.joinedParticipantIds, ["student-a"]);
  assert.deepEqual(participantState.missingParticipantIds, ["student-b"]);
});

test("expired connecting release clears call state without restoring joined search", () => {
  const sessionData = {
    status: "connecting",
    participantIds: ["student-a", "student-b"],
    requesterId: "student-a",
    responderId: "student-b",
    sessionMetadata: {
      roomJoinParticipantSignals: {
        "student-a": {source: "markSessionConnected"},
      },
    },
  };
  const serverTimestamp = Symbol("serverTimestamp");
  const fieldDelete = Symbol("fieldDelete");

  const options = buildExpiredSessionReleaseOptions({
    sessionId: "session-ab",
    sessionData,
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(options.sessionId, "session-ab");
  assert.equal(options.sessionData, sessionData);
  assert.equal(options.serverTimestamp, serverTimestamp);
  assert.equal(options.fieldDelete, fieldDelete);
  assert.equal(options.searchRequestStatus, SEARCH_REQUEST_STATUS.EXPIRED);
  assert.equal(options.stopReason, "session_expired");
  assert.equal(options.releaseCallState, true);
  assert.equal(options.restoreLegacyAvailability, true);
  assert.equal(options.restoreSearchParticipantIds, undefined);
  assert.equal(
    options.restoreSearchExcludedCandidateIdsByParticipantId,
    undefined,
  );
});

test("expired connecting release options clear users in transaction", async () => {
  const serverTimestamp = Symbol("serverTimestamp");
  const fieldDelete = Symbol("fieldDelete");
  const sessionData = {
    status: "connecting",
    participantIds: ["student-a", "student-b"],
    requesterId: "student-a",
    responderId: "student-b",
    sessionMetadata: {
      roomJoinParticipantSignals: {
        "student-a": {source: "markSessionConnected"},
      },
    },
  };
  const {db, store} = createFakeFirestore({
    "users/student-a": {
      role: "student",
      currentSessionId: "session-ab",
      isInCall: true,
      isAvailable: false,
      availableAfter: timestampFromMillis(Date.parse("2026-04-14T12:01:00Z")),
    },
    "users/student-b": {
      role: "student",
      currentSessionId: "session-ab",
      isInCall: true,
      isAvailable: false,
      availableAfter: timestampFromMillis(Date.parse("2026-04-14T12:01:00Z")),
    },
    "searchRequests/student-a": matchedSearchRequest(
      "student-a",
      "student-b",
      {excludedCandidateIds: ["student-old"]},
    ),
    "searchRequests/student-b": matchedSearchRequest("student-b", "student-a"),
  });

  await db.runTransaction((transaction) =>
    releaseSessionPairLocksInTransaction({
      db,
      transaction,
      ...buildExpiredSessionReleaseOptions({
        sessionId: "session-ab",
        sessionData,
        serverTimestamp,
        fieldDelete,
      }),
    }));

  assert.equal(store.get("users/student-a").currentSessionId, fieldDelete);
  assert.equal(store.get("users/student-a").isInCall, false);
  assert.equal(store.get("users/student-a").isAvailable, true);
  assert.equal(store.get("users/student-a").availableAfter, fieldDelete);
  assert.equal(store.get("users/student-a").lastCallEndedAt, serverTimestamp);
  assert.equal(store.get("users/student-b").currentSessionId, fieldDelete);
  assert.equal(store.get("users/student-b").isInCall, false);
  assert.equal(store.get("users/student-b").isAvailable, true);
  assert.equal(store.get("users/student-b").availableAfter, fieldDelete);
  assert.equal(store.get("users/student-b").lastCallEndedAt, serverTimestamp);
  assert.equal(
    store.get("searchRequests/student-a").status,
    SEARCH_REQUEST_STATUS.EXPIRED,
  );
  assert.equal(
    store.get("searchRequests/student-a").stopReason,
    "session_expired",
  );
  assert.equal(
    store.get("searchRequests/student-b").status,
    SEARCH_REQUEST_STATUS.EXPIRED,
  );
  assert.equal(
    store.get("searchRequests/student-b").stopReason,
    "session_expired",
  );
});

test("connected call evidence still reports joined participants", () => {
  const sessionData = {
    status: "connecting",
    participantIds: ["student-a", "student-b"],
    studentId: "student-a",
    currentTutorId: "student-b",
    sessionMetadata: {
      callConnectedAt: admin.firestore.Timestamp.fromMillis(
        Date.parse("2026-04-14T12:05:00Z"),
      ),
      connectedParticipantSignals: {
        "student-a": {source: "markSessionConnected"},
      },
      dailyWebhookParticipantSignals: {
        "student-b": {source: "dailyWebhook"},
      },
    },
  };

  assert.equal(hasConnectedCallEvidence(sessionData), true);
  assert.deepEqual(
    readConnectedSignalParticipantIds(sessionData),
    ["student-a", "student-b"],
  );
});

test("client-signal-only expired sessions do not write repeat history", () => {
  const db = admin.firestore();
  const endedAtMillis = Date.parse("2026-04-14T11:30:00Z");
  const sessionRef = db.collection("videoSessions").doc("client-signaled");
  const sessionData = {
    studentId: "student-a",
    tutorId: "teacher-b",
    createdAt: admin.firestore.Timestamp.fromMillis(
      endedAtMillis - 10 * 60 * 1000,
    ),
    startedAt: admin.firestore.Timestamp.fromMillis(
      endedAtMillis - 5 * 60 * 1000,
    ),
    sessionMetadata: {
      connectedParticipantSignals: {
        "student-a": {source: "markSessionConnected"},
        "teacher-b": {source: "markSessionConnected"},
      },
      connectedParticipantSignalsComplete: true,
    },
  };

  const payload = buildExpiredSessionCleanupPayload({
    db,
    sessionId: sessionRef.id,
    sessionRef,
    sessionData,
    endedAtMillis,
  });

  assert.equal(payload.duration, 300);
  assert.equal(payload.sessionUpdate.status, "ended");
  assert.equal(payload.pairHistoryWrite, null);
  assert.equal(
    payload.sessionUpdate["matchContext.completedPairId"],
    undefined,
  );
});

test("Daily-verified expired sessions write repeat history", () => {
  const db = admin.firestore();
  const endedAtMillis = Date.parse("2026-04-14T11:45:00Z");
  const sessionRef = db.collection("videoSessions").doc("daily-verified");
  const sessionData = {
    studentId: "student-a",
    tutorId: "teacher-b",
    createdAt: admin.firestore.Timestamp.fromMillis(
      endedAtMillis - 10 * 60 * 1000,
    ),
    startedAt: admin.firestore.Timestamp.fromMillis(
      endedAtMillis - 5 * 60 * 1000,
    ),
    sessionMetadata: {
      callConnectedAt: admin.firestore.Timestamp.fromMillis(
        endedAtMillis - 5 * 60 * 1000,
      ),
      callConnectedAtSource: "dailyWebhookTwoParty",
    },
  };

  const payload = buildExpiredSessionCleanupPayload({
    db,
    sessionId: sessionRef.id,
    sessionRef,
    sessionData,
    endedAtMillis,
  });

  assert.ok(payload.pairHistoryWrite);
  assert.equal(payload.pairHistoryWrite.pairId, "student-a_teacher-b");
});

test("legacy connected timestamp keeps connecting cleanup as ended", () => {
  const db = admin.firestore();
  const endedAtMillis = Date.parse("2026-04-14T11:50:00Z");
  const sessionRef = db.collection("videoSessions").doc("legacy-connected");
  const sessionData = {
    status: "connecting",
    studentId: "student-a",
    tutorId: "teacher-b",
    createdAt: admin.firestore.Timestamp.fromMillis(
      endedAtMillis - 10 * 60 * 1000,
    ),
    startedAt: admin.firestore.Timestamp.fromMillis(
      endedAtMillis - 5 * 60 * 1000,
    ),
    sessionMetadata: {
      callConnectedAtTimestamp: endedAtMillis - 5 * 60 * 1000,
    },
  };

  const payload = buildExpiredSessionCleanupPayload({
    db,
    sessionId: sessionRef.id,
    sessionRef,
    sessionData,
    endedAtMillis,
  });

  assert.equal(payload.sessionUpdate.status, "ended");
  assert.equal(payload.sessionUpdate.sessionMetadata.endReason, "expired");
});

test("queueExpiredSessionCleanup writes repeat history and release updates", () => {
  const endedAtMillis = Date.parse("2026-04-14T12:00:00Z");
  const historyDocId = `${getUtcDayKey(endedAtMillis)}_student-a_teacher-b`;
  const writerOperations = [];

  const fakeDb = {
    collection(name) {
      return {
        doc(id) {
          return {
            id,
            path: `${name}/${id}`,
          };
        },
      };
    },
  };

  const writer = {
    update(ref, data) {
      writerOperations.push({ type: "update", ref, data });
    },
    set(ref, data, options) {
      writerOperations.push({ type: "set", ref, data, options });
    },
  };
  const doc = {
    id: "expired-connected",
    ref: {
      id: "expired-connected",
      path: "videoSessions/expired-connected",
    },
    data() {
      return {
        studentId: "student-a",
        tutorId: "teacher-b",
        createdAt: { toMillis: () => endedAtMillis - 10 * 60 * 1000 },
        startedAt: { toMillis: () => endedAtMillis - 5 * 60 * 1000 },
        expiresAt: { toMillis: () => endedAtMillis },
        sessionMetadata: {
          callConnectedAt: {
            toMillis: () => endedAtMillis - 5 * 60 * 1000,
          },
        },
      };
    },
  };

  const payload = queueExpiredSessionCleanup({
    writer,
    db: fakeDb,
    doc,
    endedAtMillis,
  });

  assert.equal(
    writerOperations.find((operation) => operation.type === "set")?.ref?.path,
    `matchPairDailyCompletions/${historyDocId}`,
  );
  assert.equal(
    writerOperations.find((operation) => operation.type === "set")?.options?.merge,
    true,
  );
  assert.equal(
    writerOperations.find((operation) => operation.ref.path === "videoSessions/expired-connected")?.data?.[
      "matchContext.completedPairId"
    ],
    "student-a_teacher-b",
  );
  assert.equal(payload.sessionUpdate.sessionMetadata.endedAtTimestamp, endedAtMillis);
  assert.equal(
    writerOperations.find((operation) => operation.ref.path === "users/teacher-b")?.type,
    "update",
  );
});

test("cleanupExpiredSessions runs every minute as an expiry backstop", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "cleanup_expired_sessions.js"),
    "utf8",
  );

  assert.match(source, /\.schedule\("every 1 minutes"\)/);
  assert.match(
    source,
    /\.where\("status", "==", VIDEO_SESSION_STATUS\.ACTIVE\)[\s\S]*\.where\("expiresAt", "<=", now\)/,
  );
  assert.match(
    source,
    /\.where\("status", "==", VIDEO_SESSION_STATUS\.CONNECTING\)[\s\S]*\.where\("joinDeadlineAt", "<=", now\)/,
  );
  assert.match(source, /expiredLegacyConnectingSessionsQuery/);
  assert.match(
    source,
    /\.where\("status", "==", VIDEO_SESSION_STATUS\.CONNECTING\)[\s\S]*\.where\("expiresAt", "<=", now\)/,
  );
  assert.match(source, /getSessionCleanupDeadlineMillis\(freshData\)/);
  assert.match(
    source,
    /releaseSessionPairLocksInTransaction\(\{[\s\S]*buildExpiredSessionReleaseOptions\(\{/,
  );
  assert.match(source, /dailyRoomName:\s*resolveDailyRoomName\(freshData\)/);
  assert.match(source, /await deleteDailyRoomForSession\(\{/);
  assert.match(source, /source:\s*"cleanupExpiredSessions"/);
});
