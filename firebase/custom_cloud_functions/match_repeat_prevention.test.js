const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const {
  MATCH_REPEAT_BYPASS_USER_IDS_ENV,
  buildCompletedPairHistoryWrite,
  getUtcDayKey,
  loadSameDayRepeatCandidateIds,
} = require("./match_repeat_prevention");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "demo-smalltalk" });
}

function createFakeRepeatLookupDb(existingPaths, seenPaths) {
  return {
    collection(name) {
      return {
        doc(id) {
          const path = `${name}/${id}`;
          return {
            id,
            path,
            async get() {
              seenPaths.push(path);
              return { exists: existingPaths.has(path) };
            },
          };
        },
      };
    },
    async getAll(...refs) {
      refs.forEach((ref) => seenPaths.push(ref.path));
      return refs.map((ref) => ({ exists: existingPaths.has(ref.path) }));
    },
  };
}

test(
  "loadSameDayRepeatCandidateIds excludes completed candidates and skips tester bypass candidates",
  async () => {
    const requesterId = "student-a";
    const completedCandidateId = "teacher-b";
    const bypassCandidateId = "qa-user";
    const freshCandidateId = "teacher-c";
    const dayKey = "2026-04-14";
    const seenPaths = [];
    const existingPaths = new Set([
      `matchPairDailyCompletions/${dayKey}_student-a_teacher-b`,
    ]);
    const db = createFakeRepeatLookupDb(existingPaths, seenPaths);

    const result = await loadSameDayRepeatCandidateIds(
      db,
      requesterId,
      [
        completedCandidateId,
        completedCandidateId,
        requesterId,
        bypassCandidateId,
        freshCandidateId,
      ],
      {
        dayKey,
        bypassUserIds: new Set([bypassCandidateId]),
      },
    );

    assert.equal(result.dayKey, dayKey);
    assert.equal(result.requesterBypassApplied, false);
    assert.equal(result.testerBypassCandidateCount, 1);
    assert.deepEqual(
      Array.from(result.excludedCandidateIds).sort(),
      [completedCandidateId],
    );
    assert.deepEqual(seenPaths.sort(), [
      `matchPairDailyCompletions/${dayKey}_student-a_teacher-b`,
      `matchPairDailyCompletions/${dayKey}_student-a_teacher-c`,
    ]);
  },
);

test(
  "loadSameDayRepeatCandidateIds short-circuits when the requester is allow-listed",
  async () => {
    const originalValue = process.env[MATCH_REPEAT_BYPASS_USER_IDS_ENV];
    process.env[MATCH_REPEAT_BYPASS_USER_IDS_ENV] = " requester-a , qa-user ";

    try {
      let getAllCalled = false;
      const db = {
        async getAll() {
          getAllCalled = true;
          return [];
        },
        collection() {
          throw new Error("collection should not be touched for requester bypass");
        },
      };

      const result = await loadSameDayRepeatCandidateIds(
        db,
        "requester-a",
        ["teacher-b", "teacher-c"],
      );

      assert.equal(result.requesterBypassApplied, true);
      assert.equal(result.testerBypassCandidateCount, 2);
      assert.deepEqual(Array.from(result.excludedCandidateIds), []);
      assert.equal(getAllCalled, false);
    } finally {
      if (originalValue == null) {
        delete process.env[MATCH_REPEAT_BYPASS_USER_IDS_ENV];
      } else {
        process.env[MATCH_REPEAT_BYPASS_USER_IDS_ENV] = originalValue;
      }
    }
  },
);

test(
  "buildCompletedPairHistoryWrite uses completion day-key and connected-call metadata",
  () => {
    const db = admin.firestore();
    const completedAtMillis = Date.parse("2026-04-15T00:01:00Z");
    const connectedAtMillis = Date.parse("2026-04-14T23:56:00Z");
    const sessionRef = db.collection("videoSessions").doc("ended-session");

    const payload = buildCompletedPairHistoryWrite({
      db,
      sessionId: sessionRef.id,
      sessionRef,
      sessionData: {
        studentId: "student-a",
        tutorId: "teacher-b",
        matchContext: {
          requesterId: "student-a",
        },
        sessionMetadata: {
          callConnectedAtTimestamp: connectedAtMillis,
        },
      },
      completedAtMillis,
    });

    assert.ok(payload);
    assert.equal(payload.dayKey, getUtcDayKey(completedAtMillis));
    assert.equal(
      payload.ref.path,
      `matchPairDailyCompletions/${getUtcDayKey(completedAtMillis)}_student-a_teacher-b`,
    );
    assert.equal(payload.data.latestConnectedAtMillis, connectedAtMillis);
    assert.equal(payload.data.latestCompletedAtMillis, completedAtMillis);
    assert.deepEqual(payload.data.participantIds, ["student-a", "teacher-b"]);
  },
);

test("buildCompletedPairHistoryWrite ignores startedAt without Daily verification", () => {
  const db = admin.firestore();
  const completedAtMillis = Date.parse("2026-04-15T00:01:00Z");
  const sessionRef = db.collection("videoSessions").doc("client-only-session");

  const payload = buildCompletedPairHistoryWrite({
    db,
    sessionId: sessionRef.id,
    sessionRef,
    sessionData: {
      studentId: "student-a",
      tutorId: "teacher-b",
      startedAt: {
        toMillis: () => Date.parse("2026-04-14T23:56:00Z"),
      },
      sessionMetadata: {
        connectedParticipantSignals: {
          "student-a": {source: "markSessionConnected"},
          "teacher-b": {source: "markSessionConnected"},
        },
        connectedParticipantSignalsComplete: true,
      },
    },
    completedAtMillis,
  });

  assert.equal(payload, null);
});
