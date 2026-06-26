const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");
const {
  getUtcDayKey,
} = require("./match_repeat_prevention");
const {
  __private__: {
    buildRestoreSearchExcludedCandidateIdsByParticipantId,
    buildExpiredSessionCleanupPayload,
    getCleanupRestoreSearchParticipantIds,
    hasConnectedCallEvidence,
    queueExpiredSessionCleanup,
    readConnectedSignalParticipantIds,
  },
} = require("./cleanup_expired_sessions");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "demo-smalltalk" });
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
  assert.equal(payload.pairHistoryWrite, null);
});

test("cleanup restore targets only participants with pre-active join signals", () => {
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

  const restoreParticipantIds = readConnectedSignalParticipantIds(sessionData);

  assert.deepEqual(restoreParticipantIds, ["student-a"]);
  assert.deepEqual(
    getCleanupRestoreSearchParticipantIds(sessionData),
    ["student-a"],
  );
  assert.deepEqual(
    buildRestoreSearchExcludedCandidateIdsByParticipantId({
      sessionData,
      restoreParticipantIds,
    }),
    {"student-a": ["student-b"]},
  );
});

test("cleanup restore targets include Daily webhook join signals", () => {
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

  const restoreParticipantIds = getCleanupRestoreSearchParticipantIds(
    sessionData,
  );

  assert.deepEqual(restoreParticipantIds, ["student-b"]);
  assert.deepEqual(
    buildRestoreSearchExcludedCandidateIdsByParticipantId({
      sessionData,
      restoreParticipantIds,
    }),
    {"student-b": ["student-a"]},
  );
});

test("cleanup restore targets include room join signals", () => {
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

  const restoreParticipantIds = getCleanupRestoreSearchParticipantIds(
    sessionData,
  );

  assert.deepEqual(restoreParticipantIds, ["student-a"]);
});

test("cleanup restore is skipped after connected call evidence", () => {
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
  assert.deepEqual(getCleanupRestoreSearchParticipantIds(sessionData), []);
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
  assert.match(source, /dailyRoomName:\s*resolveDailyRoomName\(freshData\)/);
  assert.match(source, /await deleteDailyRoomForSession\(\{/);
  assert.match(source, /source:\s*"cleanupExpiredSessions"/);
});
