const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const {
  getUtcDayKey,
} = require("./match_repeat_prevention");
const {
  __private__: {
    buildExpiredSessionCleanupPayload,
    queueExpiredSessionCleanup,
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
