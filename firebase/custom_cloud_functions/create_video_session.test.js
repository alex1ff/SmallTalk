const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  buildNoAvailableResponderSessionUpdate,
} = require("./create_video_session").__private__;

test("no-responder terminal update carries an explicit cancellation reason", () => {
  const triedTutors = ["tutor-a", "tutor-b"];
  const update = buildNoAvailableResponderSessionUpdate(triedTutors);

  assert.deepEqual(update.triedTutors, triedTutors);
  assert.equal(update.status, "cancelled");
  assert.equal(update.cancelReason, "no_available_responder");
  assert.equal(typeof update.endedAt, "object");
  assert.equal(typeof update.cancelledAt, "object");
});

test("no-responder terminal path reconciles trial before cancellation", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "create_video_session.js"),
      "utf8",
  );
  const functionStart = source.indexOf("async function sendNotificationToNextTutor");
  const branchStart = source.indexOf("if (!nextTutor) {", functionStart);
  const branchEnd = source.indexOf("return {", branchStart);
  const branch = source.slice(branchStart, branchEnd);

  assert.match(branch, /reconcileSessionTrialCallsInTransaction/);
  assert.match(branch, /technicalFailure:\s*true/);
  assert.ok(
      branch.indexOf("reconcileSessionTrialCallsInTransaction") <
      branch.indexOf("transaction.update"),
  );
});
