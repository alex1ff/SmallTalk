const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    buildCancelRestoreSearchExcludedCandidateIdsByParticipantId,
    getCancelRestoreSearchParticipantIds,
    readSessionParticipantIds,
  },
} = require("./cancel_call");

test("cancelCall restore targets every participant except cancelling requester", () => {
  const sessionData = {
    studentId: "student-a",
    requesterId: "student-a",
    currentTutorId: "student-b",
    currentResponderId: "student-b",
    responderId: "student-b",
    participantIds: ["student-b", "student-a"],
    matchContext: {
      requesterId: "student-a",
      acceptedResponderId: "student-b",
    },
  };

  const restoreParticipantIds = getCancelRestoreSearchParticipantIds({
    sessionData,
    cancellingUserId: "student-a",
  });

  assert.deepEqual(readSessionParticipantIds(sessionData), [
    "student-a",
    "student-b",
  ]);
  assert.deepEqual(restoreParticipantIds, ["student-b"]);
  assert.deepEqual(
    buildCancelRestoreSearchExcludedCandidateIdsByParticipantId({
      restoreParticipantIds,
      cancellingUserId: "student-a",
    }),
    {"student-b": ["student-a"]},
  );
});

test("cancelCall restore is skipped after connected call evidence", () => {
  const baseSessionData = {
    status: "connecting",
    studentId: "student-a",
    currentTutorId: "student-b",
    participantIds: ["student-a", "student-b"],
  };

  assert.deepEqual(
    getCancelRestoreSearchParticipantIds({
      sessionData: {
        ...baseSessionData,
        sessionMetadata: {
          callConnectedAt: {toMillis: () => Date.parse("2026-06-21T10:00:00Z")},
        },
      },
      cancellingUserId: "student-a",
    }),
    [],
  );
  assert.deepEqual(
    getCancelRestoreSearchParticipantIds({
      sessionData: {
        ...baseSessionData,
        sessionMetadata: {
          callConnectedAtTimestamp: Date.parse("2026-06-21T10:00:00Z"),
        },
      },
      cancellingUserId: "student-a",
    }),
    [],
  );
});

test("cancelCall passes restore options into pair-lock release", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "cancel_call.js"),
    "utf8",
  );

  assert.match(source, /getCancelRestoreSearchParticipantIds\(\{/);
  assert.match(source, /restoreSearchParticipantIds,/);
  assert.match(source, /restoreSearchExcludedCandidateIdsByParticipantId:/);
  assert.match(source, /buildCancelRestoreSearchExcludedCandidateIdsByParticipantId\(\{/);
});
