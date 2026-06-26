const test = require("node:test");
const assert = require("node:assert/strict");
const {
  __private__: {
    buildCancelCallPairLockReleaseOptions,
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
  assert.equal(options.restoreSearchParticipantIds, undefined);
  assert.equal(
    options.restoreSearchExcludedCandidateIdsByParticipantId,
    undefined,
  );
});
