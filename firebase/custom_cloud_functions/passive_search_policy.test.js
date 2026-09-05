const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {activeSearchDeadlineMillis} = require("./active_search_deadline");
const {buildReusedSearchRequestRefresh} = require("./start_search_request_policy");
const {passiveExpiryMillis, sourceAllowsPassive, buildPartnerAvailableMessage,
  normalFcmToken} = require("./passive_search_policy");
const at = Date.parse("2026-09-05T12:00:00Z");
test("legacy deadline and reused deadline cap at 120 seconds", () => {
  const original = {createdAt: at, expiresAt: at + 600000};
  assert.equal(activeSearchDeadlineMillis(original), at + 120000);
  const result = buildReusedSearchRequestRefresh({requestData: original,
    nowMillis: at + 60000, input: {}, serverTimestamp: at, timestampFromMillis: (n) => n});
  assert.equal(result.expiresAt, at + 120000);
  const source = {...original, requestId: "s", status: "active"};
  assert.equal(sourceAllowsPassive(source, "s", at + 119999), false);
  assert.equal(sourceAllowsPassive(source, "s", at + 120000), true);
  assert.equal(sourceAllowsPassive({...source, status: "stopped", stopReason: "manual"}, "s", at + 120000), false);
});
test("30/60 minutes and local midnight handle DST and invalid zones", () => {
  assert.equal(passiveExpiryMillis({duration: "30", nowMillis: at}), at + 1800000);
  assert.equal(passiveExpiryMillis({duration: "60", nowMillis: at}), at + 3600000);
  const midnight = (iso, zone) => new Date(passiveExpiryMillis({duration: "day", timeZone: zone,
    nowMillis: Date.parse(iso)})).toISOString();
  assert.equal(midnight("2026-03-08T05:00:00Z", "America/New_York"), "2026-03-09T04:00:00.000Z");
  assert.equal(midnight("2026-11-01T04:00:00Z", "America/New_York"), "2026-11-02T05:00:00.000Z");
  assert.equal(midnight("2026-09-05T12:00:00Z", "Asia/Yekaterinburg"), "2026-09-05T19:00:00.000Z");
  assert.throws(() => passiveExpiryMillis({duration: "day", timeZone: "Invalid/Zone"}));
  assert.throws(() => passiveExpiryMillis({duration: "90"}));
});
test("ordinary notification+data contains exact consent and no native call payload", () => {
  const message = buildPartnerAvailableMessage({token: "fcm", recipientId: "a",
    passive: {locale: "ru", requestId: "p", expiresAt: at + 1800000},
    activeUserId: "b", active: {requestId: "s", createdAt: at, expiresAt: at + 600000},
    activeUser: {display_name: "Маша", profileCity: {label: "New York"}}, nowMillis: at});
  assert.match(message.notification.body, /Маша из New York/);
  assert.deepEqual(message.data, {type: "partner_available", recipientId: "a", requestId: "p",
    activeUserId: "b", activeRequestId: "s", expiresAt: "2026-09-05T12:02:00.000Z"});
  assert.equal(message.apns.headers["apns-push-type"], "alert");
  assert.equal(message.android.ttl, 120000);
  assert.equal(message.android.notification, undefined);
  assert.equal(normalFcmToken({voipPushToken: "pushkit"}), "");
});
test("catch-up notification query has its composite index", () => {
  const indexes = JSON.parse(fs.readFileSync(
      path.join(__dirname, "..", "firestore.indexes.json"), "utf8"));
  assert.ok(indexes.indexes.some((index) =>
    index.collectionGroup === "searchRequests" &&
    index.queryScope === "COLLECTION" &&
    JSON.stringify(index.fields) === JSON.stringify([
      {fieldPath: "status", order: "ASCENDING"},
      {fieldPath: "role", order: "ASCENDING"},
      {fieldPath: "language", order: "ASCENDING"},
      {fieldPath: "createdAt", order: "ASCENDING"},
    ])));
});
