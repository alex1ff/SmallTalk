const CALL_LIFECYCLE_LOG_EVENT = "call_lifecycle_event";

const STRING_FIELDS = [
  "event",
  "source",
  "scenario",
  "sessionId",
  "notificationId",
  "searchRequestId",
  "pairAttemptId",
  "requesterId",
  "responderId",
  "nextResponderId",
  "statusBefore",
  "statusAfter",
  "reason",
  "result",
  "errorCode",
  "skipReason",
];

function normalizeLogString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function sanitizeLogCounts(counts = {}) {
  if (!counts || typeof counts !== "object") {
    return null;
  }
  const sanitized = {};
  for (const [key, value] of Object.entries(counts)) {
    if (typeof key !== "string" || !key.trim()) {
      continue;
    }
    const numberValue = Number(value);
    if (Number.isFinite(numberValue)) {
      sanitized[key.trim()] = numberValue;
    }
  }
  return Object.keys(sanitized).length > 0 ? sanitized : null;
}

function buildCallLifecycleLogPayload(input = {}) {
  const payload = {};
  for (const field of STRING_FIELDS) {
    const normalizedValue = normalizeLogString(input[field]);
    if (normalizedValue) {
      payload[field] = normalizedValue;
    }
  }

  const counts = sanitizeLogCounts(input.counts);
  if (counts) {
    payload.counts = counts;
  }

  return payload;
}

function logCallLifecycleEvent(input = {}, logger = console) {
  const payload = buildCallLifecycleLogPayload(input);
  logger.log(CALL_LIFECYCLE_LOG_EVENT, payload);
  return payload;
}

function logCallLifecycleError(input = {}, logger = console) {
  const payload = buildCallLifecycleLogPayload({
    ...input,
    result: "error",
  });
  logger.error(CALL_LIFECYCLE_LOG_EVENT, payload);
  return payload;
}

module.exports = {
  CALL_LIFECYCLE_LOG_EVENT,
  buildCallLifecycleLogPayload,
  logCallLifecycleError,
  logCallLifecycleEvent,
  sanitizeLogCounts,
};
