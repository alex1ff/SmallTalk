const {
  buildSafeLogPayload,
  createSafeConsole,
  normalizeEventName,
  sanitizeCounts,
} = require("./safe_log");

const CALL_LIFECYCLE_LOG_EVENT = "call_lifecycle_event";
const safeConsole = createSafeConsole({source: "call_lifecycle"});

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

function sanitizeLogCounts(counts = {}) {
  return sanitizeCounts(counts);
}

function buildCallLifecycleLogPayload(input = {}) {
  const filteredInput = Object.fromEntries(
    Object.entries(input).filter(([field]) =>
      STRING_FIELDS.includes(field) || field === "counts"),
  );
  return {
    ...buildSafeLogPayload(filteredInput),
    event: normalizeEventName(input.event),
  };
}

function logCallLifecycleEvent(input = {}, logger = safeConsole) {
  const payload = buildCallLifecycleLogPayload(input);
  const {event, source: _source, ...details} = payload;
  logger.log(CALL_LIFECYCLE_LOG_EVENT, {
    ...details,
    operation: event,
  });
  return payload;
}

function logCallLifecycleError(input = {}, logger = safeConsole) {
  const payload = buildCallLifecycleLogPayload({
    ...input,
    result: "error",
  });
  const {event, source: _source, ...details} = payload;
  logger.error(CALL_LIFECYCLE_LOG_EVENT, {
    ...details,
    operation: event,
  });
  return payload;
}

module.exports = {
  CALL_LIFECYCLE_LOG_EVENT,
  buildCallLifecycleLogPayload,
  logCallLifecycleError,
  logCallLifecycleEvent,
  sanitizeLogCounts,
};
