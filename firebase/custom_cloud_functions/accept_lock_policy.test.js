const test = require("node:test");
const assert = require("node:assert/strict");
const {
  ACCEPT_LOCK_WINDOW_MS,
  assertAcceptAttemptCanFinalizeOrThrow,
  assertAcceptLockOwnedByAttemptOrThrow,
  assertAcceptLockOwnedByResponderOrThrow,
  assertNoActiveAcceptLockForResponderOrThrow,
  hasActiveAcceptLockForResponder,
  isAcceptLockOwnedByAttempt,
  isAcceptLockOwnedByResponder,
} = require("./accept_lock_policy");

function timestampFromMillis(millis) {
  return {
    toMillis: () => millis,
    toDate: () => new Date(millis),
  };
}

test("accept lock ownership is strict by responder id", () => {
  assert.equal(
    isAcceptLockOwnedByResponder(
      {acceptingTutorId: "student-b"},
      "student-b",
    ),
    true,
  );
  assert.equal(
    isAcceptLockOwnedByResponder(
      {acceptingTutorId: "student-c"},
      "student-b",
    ),
    false,
  );
  assert.throws(
    () => assertAcceptLockOwnedByResponderOrThrow(
      {acceptingTutorId: "student-c"},
      "student-b",
    ),
    (error) => error.code === "failed-precondition",
  );
});

test("accept lock ownership is strict by attempt id", () => {
  const sessionData = {
    acceptingTutorId: "student-b",
    acceptAttemptId: "attempt-current",
  };

  assert.equal(
    isAcceptLockOwnedByAttempt(
      sessionData,
      "student-b",
      "attempt-current",
    ),
    true,
  );
  assert.equal(
    isAcceptLockOwnedByAttempt(
      sessionData,
      "student-b",
      "attempt-old",
    ),
    false,
  );
  assert.throws(
    () => assertAcceptLockOwnedByAttemptOrThrow(
      sessionData,
      "student-b",
      "attempt-old",
    ),
    (error) => error.code === "failed-precondition",
  );
});

test("accept lock is active only inside the lock window", () => {
  const nowMillis = Date.parse("2026-06-21T10:00:30Z");
  const freshSession = {
    acceptingTutorId: "student-b",
    acceptingAt: timestampFromMillis(nowMillis - ACCEPT_LOCK_WINDOW_MS + 1),
  };
  const staleSession = {
    acceptingTutorId: "student-b",
    acceptingAt: timestampFromMillis(nowMillis - ACCEPT_LOCK_WINDOW_MS - 1),
  };

  assert.equal(
    hasActiveAcceptLockForResponder({
      sessionData: freshSession,
      responderId: "student-b",
      nowMillis,
    }),
    true,
  );
  assert.equal(
    hasActiveAcceptLockForResponder({
      sessionData: staleSession,
      responderId: "student-b",
      nowMillis,
    }),
    false,
  );
  assert.throws(
    () => assertNoActiveAcceptLockForResponderOrThrow({
      sessionData: freshSession,
      responderId: "student-b",
      nowMillis,
    }),
    (error) => error.code === "failed-precondition",
  );
  assert.doesNotThrow(
    () => assertNoActiveAcceptLockForResponderOrThrow({
      sessionData: staleSession,
      responderId: "student-b",
      nowMillis,
    }),
  );
});

test("accept attempt finalization uses lock start instead of final deadline", () => {
  const acceptingAtMillis = Date.parse("2026-06-21T10:00:10Z");
  const responseDeadlineMillis = acceptingAtMillis + 1_000;
  const finalizationMillis = responseDeadlineMillis + 10_000;
  const sessionData = {
    acceptingTutorId: "student-b",
    acceptAttemptId: "attempt-current",
    acceptingAt: timestampFromMillis(acceptingAtMillis),
    responseExpiresAt: timestampFromMillis(responseDeadlineMillis),
  };

  assert.doesNotThrow(() => assertAcceptAttemptCanFinalizeOrThrow({
    sessionData,
    responderId: "student-b",
    acceptAttemptId: "attempt-current",
    nowMillis: finalizationMillis,
  }));
  assert.throws(
    () => assertAcceptAttemptCanFinalizeOrThrow({
      sessionData: {
        ...sessionData,
        acceptAttemptId: "attempt-newer",
      },
      responderId: "student-b",
      acceptAttemptId: "attempt-current",
      nowMillis: finalizationMillis,
    }),
    (error) => error.code === "failed-precondition",
  );
  assert.throws(
    () => assertAcceptAttemptCanFinalizeOrThrow({
      sessionData,
      responderId: "student-b",
      acceptAttemptId: "attempt-current",
      nowMillis: acceptingAtMillis + ACCEPT_LOCK_WINDOW_MS + 1,
    }),
    (error) => error.code === "failed-precondition",
  );
  assert.throws(
    () => assertAcceptAttemptCanFinalizeOrThrow({
      sessionData: {
        ...sessionData,
        acceptingAt: timestampFromMillis(responseDeadlineMillis),
      },
      responderId: "student-b",
      acceptAttemptId: "attempt-current",
      nowMillis: responseDeadlineMillis + 1,
    }),
    (error) => error.code === "invalid-argument",
  );
  assert.doesNotThrow(() => assertAcceptAttemptCanFinalizeOrThrow({
    sessionData: {
      ...sessionData,
      acceptingAt: timestampFromMillis(responseDeadlineMillis),
    },
    responderId: "student-b",
    acceptAttemptId: "attempt-current",
    nowMillis: responseDeadlineMillis + 1,
    skipResponseDeadline: true,
  }));
  assert.throws(
    () => assertAcceptAttemptCanFinalizeOrThrow({
      sessionData: {
        acceptingTutorId: "student-b",
        acceptAttemptId: "attempt-current",
      },
      responderId: "student-b",
      acceptAttemptId: "attempt-current",
      nowMillis: finalizationMillis,
    }),
    (error) => error.code === "failed-precondition",
  );
});
