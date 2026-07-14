"use strict";

const MAX_EVENT_CHAT_INBOX_IDS = 50;

function normalizeEventChatInboxEventId(rawEventId) {
  if (typeof rawEventId !== "string") {
    return "";
  }
  const eventId = rawEventId.trim();
  if (!eventId || eventId === "." || eventId === ".." ||
      eventId.includes("/") || /^__.*__$/.test(eventId) ||
      Buffer.byteLength(eventId, "utf8") > 1500) {
    return "";
  }
  return eventId;
}

function buildBoundedEventChatInboxEventIds(rawEventIds, newestEventId) {
  const normalizedNewest = normalizeEventChatInboxEventId(newestEventId);
  const eventIds = [];
  const seen = new Set();

  if (Array.isArray(rawEventIds)) {
    for (const rawEventId of rawEventIds) {
      const eventId = normalizeEventChatInboxEventId(rawEventId);
      if (!eventId || eventId === normalizedNewest ||
          seen.has(eventId)) {
        continue;
      }
      seen.add(eventId);
      eventIds.push(eventId);
    }
  }

  if (normalizedNewest) {
    eventIds.push(normalizedNewest);
  }
  return eventIds.slice(-MAX_EVENT_CHAT_INBOX_IDS);
}

module.exports = {
  MAX_EVENT_CHAT_INBOX_IDS,
  buildBoundedEventChatInboxEventIds,
  normalizeEventChatInboxEventId,
};
