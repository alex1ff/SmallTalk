const assert = require("node:assert/strict");
const test = require("node:test");
const {
  backfillPassComplete,
  parseFirebaseJson,
  runBackfill,
  schedulerTopicName,
  updatedAtValue,
} = require("./scripts/backfill_event_public_projections");

test("backfill recognizes only a fully completed repair pass", () => {
  const state = (eventDone, projectionDone) => ({fields: {
    eventPassComplete: {booleanValue: eventDone},
    projectionPassComplete: {booleanValue: projectionDone},
  }});
  assert.equal(backfillPassComplete(state(true, true)), true);
  assert.equal(backfillPassComplete(state(true, false)), false);
  assert.equal(backfillPassComplete(null), false);
});

test("backfill targets the deployed scheduled repair topic", () => {
  assert.equal(
      schedulerTopicName("us-central1"),
      "firebase-schedule-repairEventPublicProjections-us-central1",
  );
});

test("backfill parses Firebase CLI JSON and repair timestamps", () => {
  assert.deepEqual(parseFirebaseJson("warning\n{\"status\":\"success\"}"), {
    status: "success",
  });
  assert.equal(updatedAtValue({fields: {
    updatedAt: {timestampValue: "2026-08-29T12:00:00Z"},
  }}), "2026-08-29T12:00:00Z");
});

test("backfill always resets partial or completed state before publishing", async () => {
  const completeState = (updatedAt) => ({fields: {
    eventPassComplete: {booleanValue: true},
    projectionPassComplete: {booleanValue: true},
    updatedAt: {timestampValue: updatedAt},
  }});
  var publishCalls = 0;
  var resetCalls = 0;
  const result = await runBackfill({
    resetState: async () => {
      resetCalls += 1;
      return {fields: {
        eventCursorId: {nullValue: null},
        projectionCursorId: {nullValue: null},
        eventPassComplete: {booleanValue: false},
        projectionPassComplete: {booleanValue: false},
        updatedAt: {timestampValue: "reset"},
      }};
    },
    publish: async () => {
      publishCalls += 1;
    },
    wait: async () => completeState("new"),
  });

  assert.equal(resetCalls, 1);
  assert.equal(publishCalls, 1);
  assert.deepEqual(result, {runs: 1});
});
