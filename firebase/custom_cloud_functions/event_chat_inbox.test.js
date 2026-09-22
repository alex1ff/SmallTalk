const test = require("node:test");
const assert = require("node:assert/strict");

const {
  MAX_EVENT_CHAT_INBOX_IDS,
  buildBoundedEventChatInboxEventIds,
  normalizeEventChatInboxEventId,
} = require("./event_chat_inbox");

test("buildBoundedEventChatInboxEventIds normalizes and moves newest last", () => {
  assert.deepEqual(
      buildBoundedEventChatInboxEventIds(
          ["event-a", " event-b ", "event-a", null, "bad/id"],
          "event-a",
      ),
      ["event-b", "event-a"],
  );
});

test("buildBoundedEventChatInboxEventIds keeps the newest bounded ids", () => {
  const eventIds = Array.from({length: 75}, (_, index) => `event-${index}`);

  const result = buildBoundedEventChatInboxEventIds(eventIds, "event-new");

  assert.equal(result.length, MAX_EVENT_CHAT_INBOX_IDS);
  assert.equal(result[0], "event-26");
  assert.equal(result.at(-1), "event-new");
});

test("buildBoundedEventChatInboxEventIds rejects an invalid newest id", () => {
  assert.deepEqual(
      buildBoundedEventChatInboxEventIds(["event-a"], "bad/id"),
      ["event-a"],
  );
});

test("normalizeEventChatInboxEventId matches Firestore segment limits", () => {
  for (const invalidId of [
    "",
    ".",
    "..",
    "events/event-a",
    "__reserved__",
    "ж".repeat(751),
  ]) {
    assert.equal(normalizeEventChatInboxEventId(invalidId), "");
  }
  assert.equal(normalizeEventChatInboxEventId(" event-a "), "event-a");
  assert.equal(normalizeEventChatInboxEventId("ж".repeat(750)).length, 750);
});
