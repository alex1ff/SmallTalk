const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildEventPreviewData,
  shouldReplaceEventPreview,
  shortEventDescription,
  timestampMillis,
} = require("./event_public_projection");

test("event preview excludes protected location and chat fields", () => {
  const preview = buildEventPreviewData({
    title: "Meetup",
    description: "A".repeat(300),
    locationName: "Secret address",
    locationGeoPoint: {latitude: 1, longitude: 2},
    chatId: "event-1",
    status: "active",
  });
  assert.equal(preview.title, "Meetup");
  assert.equal(preview.description, `${"A".repeat(160)}…`);
  assert.equal(Object.hasOwn(preview, "locationName"), false);
  assert.equal(Object.hasOwn(preview, "locationGeoPoint"), false);
  assert.equal(Object.hasOwn(preview, "chatId"), false);
});

test("short preview keeps compact descriptions unchanged", () => {
  assert.equal(shortEventDescription("  hello  "), "hello");
});

test("older projection updates cannot replace newer data", () => {
  const older = {updatedAt: {toMillis: () => 10}};
  const newer = {updatedAt: {toMillis: () => 20}};
  assert.equal(shouldReplaceEventPreview(newer, older), false);
  assert.equal(shouldReplaceEventPreview(older, newer), true);
  assert.equal(timestampMillis(newer.updatedAt), 20);
});

test("equal updatedAt values never let a stale projection overwrite", () => {
  const current = {updatedAt: {toMillis: () => 20}};
  const stale = {updatedAt: {toMillis: () => 20}};
  assert.equal(shouldReplaceEventPreview(current, stale), false);
});

test("server snapshot revision wins when event timestamps tie", () => {
  const current = {
    updatedAt: {toMillis: () => 20},
    sourceUpdateTime: {toMillis: () => 200},
  };
  const stale = {
    updatedAt: {toMillis: () => 20},
    sourceUpdateTime: {toMillis: () => 100},
  };
  const newest = {
    updatedAt: {toMillis: () => 20},
    sourceUpdateTime: {toMillis: () => 300},
  };
  assert.equal(shouldReplaceEventPreview(current, stale), false);
  assert.equal(shouldReplaceEventPreview(current, newest), true);
});
