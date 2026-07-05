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
  "loadSameDayRepeatCandidateIds temporarily allows all completed candidates",
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
    assert.equal(result.globalBypassApplied, true);
    assert.equal(result.requesterBypassApplied, false);
    assert.equal(result.testerBypassCandidateCount, 0);
    assert.deepEqual(Array.from(result.excludedCandidateIds), []);
    assert.deepEqual(seenPaths, []);
  },
);

test(
  "loadSameDayRepeatCandidateIds ignores email pair bypass while global bypass is active",
  async () => {
    const requesterId = "uid-elena";
    const repeatAllowedCandidateId = "uid-muratov";
    const regularCompletedCandidateId = "uid-regular";
    const dayKey = "2026-06-15";
    const seenPaths = [];
    const existingPaths = new Set([
      `matchPairDailyCompletions/${dayKey}_uid-elena_uid-muratov`,
      `matchPairDailyCompletions/${dayKey}_uid-elena_uid-regular`,
    ]);
    const db = createFakeRepeatLookupDb(existingPaths, seenPaths);

    const result = await loadSameDayRepeatCandidateIds(
      db,
      requesterId,
      [repeatAllowedCandidateId, regularCompletedCandidateId],
      {
        dayKey,
        requesterEmail: "elena.alpatkina@gmail.com",
        userEmailsById: {
          [repeatAllowedCandidateId]: "nsk.muratov@gmail.com",
          [regularCompletedCandidateId]: "regular@example.com",
        },
      },
    );

    assert.equal(result.globalBypassApplied, true);
    assert.equal(result.emailPairBypassCandidateCount, 0);
    assert.deepEqual(Array.from(result.excludedCandidateIds), []);
    assert.deepEqual(seenPaths, []);
  },
);

test(
  "loadSameDayRepeatCandidateIds ignores uid pair bypass while global bypass is active",
  async () => {
    const requesterId = "XkRxUdqHTiM1MNDTJG4zb0wooay2";
    const repeatAllowedCandidateId = "CI0E2yJBw1P0TicAWVLhHhLX6Yl2";
    const regularCompletedCandidateId = "uid-regular";
    const dayKey = "2026-06-16";
    const seenPaths = [];
    const allowedPairId = [requesterId, repeatAllowedCandidateId]
      .sort()
      .join("_");
    const regularPairId = [requesterId, regularCompletedCandidateId]
      .sort()
      .join("_");
    const existingPaths = new Set([
      `matchPairDailyCompletions/${dayKey}_${allowedPairId}`,
      `matchPairDailyCompletions/${dayKey}_${regularPairId}`,
    ]);
    const db = createFakeRepeatLookupDb(existingPaths, seenPaths);

    const result = await loadSameDayRepeatCandidateIds(
      db,
      requesterId,
      [repeatAllowedCandidateId, regularCompletedCandidateId],
      {dayKey},
    );

    assert.equal(result.globalBypassApplied, true);
    assert.equal(result.userIdPairBypassCandidateCount, 0);
    assert.deepEqual(Array.from(result.excludedCandidateIds), []);
    assert.deepEqual(seenPaths, []);
  },
);

test(
  "loadSameDayRepeatCandidateIds short-circuits before requester allow-list while global bypass is active",
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

      assert.equal(result.globalBypassApplied, true);
      assert.equal(result.requesterBypassApplied, false);
      assert.equal(result.testerBypassCandidateCount, 0);
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
