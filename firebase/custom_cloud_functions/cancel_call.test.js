const test = require("node:test");
const assert = require("node:assert/strict");
const {
  __private__: {
    buildCancelCallPairLockReleaseOptions,
    buildCancelCallSessionUpdate,
    resolveCancelCallEventPartnerId,
  },
} = require("./cancel_call");

test("cancelCall closes search without restoring participants", () => {
  const db = Symbol("db");
  const transaction = Symbol("transaction");
  const sessionData = {status: "connecting"};
  const serverTimestamp = Symbol("serverTimestamp");
  const fieldDelete = Symbol("fieldDelete");

  const options = buildCancelCallPairLockReleaseOptions({
    db,
    transaction,
    sessionId: "session-cancel-test",
    sessionData,
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(options.db, db);
  assert.equal(options.transaction, transaction);
  assert.equal(options.sessionId, "session-cancel-test");
  assert.equal(options.sessionData, sessionData);
  assert.equal(options.serverTimestamp, serverTimestamp);
  assert.equal(options.fieldDelete, fieldDelete);
  assert.equal(options.searchRequestStatus, "cancelled");
  assert.equal(options.stopReason, "call_cancelled");
  assert.equal(options.releaseCallState, true);
  assert.equal(options.restoreLegacyAvailability, true);
  assert.equal(options.restoreSearchParticipantIds, undefined);
  assert.equal(
    options.restoreSearchExcludedCandidateIdsByParticipantId,
    undefined,
  );
});

test("cancelCall terminal update clears legacy and neutral responder fields", () => {
  const serverTimestamp = Symbol("serverTimestamp");
  const fieldDelete = Symbol("fieldDelete");

  const update = buildCancelCallSessionUpdate({
    cancelledBy: "student-a",
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(update.status, "cancelled");
  assert.equal(update.endedAt, serverTimestamp);
  assert.equal(update.cancelledAt, serverTimestamp);
  assert.equal(update.cancelledBy, "student-a");
  assert.equal(update.currentTutorId, fieldDelete);
  assert.equal(update.currentResponderId, fieldDelete);
  assert.equal(update.currentResponderRole, fieldDelete);
  assert.equal(update.acceptingTutorId, fieldDelete);
  assert.equal(update.acceptAttemptId, fieldDelete);
  assert.equal(update.tutorNavigationTriggered, false);
  assert.equal(update.studentNavigationTriggered, false);
});

test("cancelCall event partner prefers trimmed neutral responder", () => {
  assert.equal(
    resolveCancelCallEventPartnerId({
      currentResponderId: " student-b ",
      currentTutorId: "teacher-a",
    }),
    "student-b",
  );
  assert.equal(
    resolveCancelCallEventPartnerId({
      currentTutorId: " teacher-a ",
    }),
    "teacher-a",
  );
});
