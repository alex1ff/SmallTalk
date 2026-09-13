const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  REPAIR_PAGE_SIZE,
  nextRepairCursor,
  repairCursorValue,
  repairPassMatches,
  shouldRepairEventPreview,
  sourceRevisionData,
  triggerProjectionAction,
} = require("./sync_event_public_projection").__private__;

test("repair pagination is bounded and advances only full pages", () => {
  const fullPage = {
    empty: false,
    size: REPAIR_PAGE_SIZE,
    docs: [{id: "event-last"}],
  };
  const shortPage = {empty: false, size: 2, docs: [{id: "event-2"}]};
  assert.equal(nextRepairCursor(fullPage, REPAIR_PAGE_SIZE), "event-last");
  assert.equal(nextRepairCursor(shortPage, REPAIR_PAGE_SIZE), null);
  assert.equal(nextRepairCursor({empty: true, size: 0, docs: []}, 10), null);
});

test("repair cursor accepts only non-empty document ids", () => {
  assert.equal(repairCursorValue("event-1"), "event-1");
  assert.equal(repairCursorValue(""), null);
  assert.equal(repairCursorValue(null), null);
  assert.equal(repairCursorValue(1), null);
});

test("a reset pass rejects cursor commits from older workers", () => {
  assert.equal(repairPassMatches("new-pass", "old-pass"), false);
  assert.equal(repairPassMatches("new-pass", "new-pass"), true);
  assert.equal(repairPassMatches(null, "legacy"), true);
});

test("projection repair uses the server snapshot revision", () => {
  const updateTime = {toMillis: () => 123};
  assert.deepEqual(sourceRevisionData({updateTime}), {sourceUpdateTime: updateTime});
  assert.deepEqual(sourceRevisionData({}), {});
});

test("missing authoritative source always deletes the projection", () => {
  assert.equal(triggerProjectionAction({
    sourceExists: false,
    currentData: {sourceUpdateTime: {toMillis: () => 999}},
    incomingData: {sourceUpdateTime: {toMillis: () => 100}},
  }), "delete");
});

test("repair replaces poisoned revision markers", () => {
  assert.equal(shouldRepairEventPreview(
      {title: "Stale", sourceUpdateTime: 999},
      {title: "Current", sourceUpdateTime: 100},
  ), true);
  assert.equal(shouldRepairEventPreview(
      {title: "Current", sourceUpdateTime: 100},
      {title: "Current", sourceUpdateTime: 100},
  ), false);
});

test("repair deletes orphan projections and enforces a page limit", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "sync_event_public_projection.js"),
    "utf8",
  );
  assert.match(source, /collection\("events_public"\)/);
  assert.match(source, /transaction\.get\(eventRef\)/);
  assert.match(source, /transaction\.delete\(projectionDoc\.ref\)/);
  assert.match(source, /\.limit\(pageSize\)/);
});
