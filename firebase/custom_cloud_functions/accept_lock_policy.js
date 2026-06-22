const functions = require("firebase-functions/v1");

const ACCEPT_LOCK_WINDOW_MS = 30 * 1000;

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function timestampToMillis(value) {
  if (!value) {
    return null;
  }
  if (typeof value.toMillis === "function") {
    const millis = Number(value.toMillis());
    return Number.isFinite(millis) ? millis : null;
  }
  if (typeof value.toDate === "function") {
    const millis = value.toDate().getTime();
    return Number.isFinite(millis) ? millis : null;
  }
  if (value instanceof Date) {
    const millis = value.getTime();
    return Number.isFinite(millis) ? millis : null;
  }
  const millis = Number(value);
  return Number.isFinite(millis) ? millis : null;
}

function isAcceptLockOwnedByResponder(sessionData = {}, responderId = "") {
  const acceptingResponderId = normalizeString(sessionData.acceptingTutorId);
  const normalizedResponderId = normalizeString(responderId);
  return Boolean(
    acceptingResponderId &&
      normalizedResponderId &&
      acceptingResponderId === normalizedResponderId,
  );
}

function isAcceptLockOwnedByAttempt(
  sessionData = {},
  responderId = "",
  acceptAttemptId = "",
) {
  const normalizedAttemptId = normalizeString(acceptAttemptId);
  const storedAttemptId = normalizeString(sessionData.acceptAttemptId);
  return Boolean(
    normalizedAttemptId &&
      storedAttemptId &&
      normalizedAttemptId === storedAttemptId &&
      isAcceptLockOwnedByResponder(sessionData, responderId),
  );
}

function hasActiveAcceptLockForResponder({
  sessionData = {},
  responderId = "",
  nowMillis = Date.now(),
  lockWindowMs = ACCEPT_LOCK_WINDOW_MS,
}) {
  if (!isAcceptLockOwnedByResponder(sessionData, responderId)) {
    return false;
  }

  const acceptingAtMillis = timestampToMillis(sessionData.acceptingAt);
  return acceptingAtMillis !== null &&
    nowMillis - acceptingAtMillis <= lockWindowMs;
}

function assertAcceptLockOwnedByAttemptOrThrow(
  sessionData = {},
  responderId = "",
  acceptAttemptId = "",
) {
  if (!isAcceptLockOwnedByAttempt(sessionData, responderId, acceptAttemptId)) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Session accept lock is stale",
    );
  }
}

function assertAcceptAttemptCanFinalizeOrThrow({
  sessionData = {},
  responderId = "",
  acceptAttemptId = "",
  nowMillis = Date.now(),
  lockWindowMs = ACCEPT_LOCK_WINDOW_MS,
}) {
  assertAcceptLockOwnedByAttemptOrThrow(
    sessionData,
    responderId,
    acceptAttemptId,
  );

  const acceptingAtMillis = timestampToMillis(sessionData.acceptingAt);
  if (acceptingAtMillis === null) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Session accept lock is stale",
    );
  }
  if (nowMillis - acceptingAtMillis > lockWindowMs) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Session accept lock has expired",
    );
  }

  const responseDeadlineMillis = timestampToMillis(
    sessionData.responseExpiresAt || sessionData.confirmationExpiresAt,
  );
  if (
    responseDeadlineMillis !== null &&
    acceptingAtMillis >= responseDeadlineMillis
  ) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Session response window has expired",
    );
  }
}

function assertAcceptLockOwnedByResponderOrThrow(
  sessionData = {},
  responderId = "",
) {
  if (!isAcceptLockOwnedByResponder(sessionData, responderId)) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Session accept lock is stale",
    );
  }
}

function assertNoActiveAcceptLockForResponderOrThrow({
  sessionData = {},
  responderId = "",
  nowMillis = Date.now(),
}) {
  if (hasActiveAcceptLockForResponder({sessionData, responderId, nowMillis})) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Session is already being accepted",
    );
  }
}

module.exports = {
  ACCEPT_LOCK_WINDOW_MS,
  assertAcceptAttemptCanFinalizeOrThrow,
  assertAcceptLockOwnedByAttemptOrThrow,
  assertAcceptLockOwnedByResponderOrThrow,
  assertNoActiveAcceptLockForResponderOrThrow,
  hasActiveAcceptLockForResponder,
  isAcceptLockOwnedByAttempt,
  isAcceptLockOwnedByResponder,
  timestampToMillis,
};
