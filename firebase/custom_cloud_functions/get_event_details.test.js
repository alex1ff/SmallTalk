const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeEventId,
  canReturnEventDetail,
  hasFullEventAccess,
  serializeEventData,
} = require("./get_event_details").__private__;

test("event detail request accepts only document-safe ids", () => {
  assert.equal(normalizeEventId(" event-1 "), "event-1");
  assert.equal(normalizeEventId("events/event-1"), "");
});

test("only active events expose previews without an access grant", () => {
  assert.equal(canReturnEventDetail({status: "active"}, false), true);
  assert.equal(canReturnEventDetail({status: "canceled"}, false), false);
  assert.equal(canReturnEventDetail({status: "canceled"}, true), true);
});

test("paid Premium nonparticipants do not receive full canceled details", () => {
  const premiumUser = {
    subscription: {
      productId: "expatlio_1_Month",
      periodType: "NORMAL",
      expiresAt: new Date("2099-01-01T00:00:00.000Z"),
    },
  };
  assert.equal(hasFullEventAccess({status: "active"}, {
    uid: "viewer",
    userData: premiumUser,
    now: Date.parse("2026-01-01T00:00:00.000Z"),
  }), true);
  assert.equal(hasFullEventAccess({status: "canceled"}, {
    uid: "viewer",
    userData: premiumUser,
    now: Date.parse("2026-01-01T00:00:00.000Z"),
  }), false);
});

test("preview serialization strips protected event fields", () => {
  const preview = serializeEventData({
    title: "Meetup",
    description: "Public intro",
    locationName: "Secret place",
    locationGeoPoint: {latitude: 1, longitude: 2},
    chatId: "chat-1",
  });
  assert.equal(preview.title, "Meetup");
  assert.equal(Object.hasOwn(preview, "locationName"), false);
  assert.equal(Object.hasOwn(preview, "locationGeoPoint"), false);
  assert.equal(Object.hasOwn(preview, "chatId"), false);
});

test("full serialization includes protected event fields", () => {
  const full = serializeEventData({
    locationName: "Place",
    locationGeoPoint: {latitude: 1, longitude: 2},
    chatId: "chat-1",
  }, {full: true});
  assert.equal(full.locationName, "Place");
  assert.deepEqual(full.locationGeoPoint, {latitude: 1, longitude: 2});
  assert.equal(full.chatId, "chat-1");
});
