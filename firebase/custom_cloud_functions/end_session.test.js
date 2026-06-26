const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    buildPreActiveSessionPairLockReleaseOptions,
    buildStudentCallCharge,
    hasConnectedCallEvidence,
    hasActiveSubscription,
    isExpiredEndReason,
    resolveTeacherEarningUserId,
    shouldProcessExpiredEndReason,
  },
} = require("./end_session");

test("expired end reasons are ignored when policy expiry moved into the future", () => {
  const shouldProcess = shouldProcessExpiredEndReason({
    sessionData: {
      expiresAt: {
        toMillis: () => Date.parse("2026-04-14T10:10:00Z"),
      },
      sessionPolicy: {
        effectiveLimitSeconds: 600,
      },
    },
    endReason: "expired",
    requestTimestamp: Date.parse("2026-04-14T10:05:01Z"),
  });

  assert.equal(shouldProcess, false);
});

test("expired end reasons are honored once the stored limit is reached", () => {
  const shouldProcess = shouldProcessExpiredEndReason({
    sessionData: {
      expiresAt: {
        toMillis: () => Date.parse("2026-04-14T10:05:00Z"),
      },
      sessionPolicy: {
        effectiveLimitSeconds: 300,
      },
    },
    endReason: "expired",
    requestTimestamp: Date.parse("2026-04-14T10:05:00Z"),
  });

  assert.equal(shouldProcess, true);
});

test("manual end reasons bypass the expiry guard", () => {
  const shouldProcess = shouldProcessExpiredEndReason({
    sessionData: {
      expiresAt: {
        toMillis: () => Date.parse("2026-04-14T10:10:00Z"),
      },
      sessionPolicy: {
        effectiveLimitSeconds: 600,
      },
    },
    endReason: "user_ended",
    requestTimestamp: Date.parse("2026-04-14T10:05:01Z"),
  });

  assert.equal(shouldProcess, true);
});

test("pre-active session helper requires connected call evidence", () => {
  assert.equal(hasConnectedCallEvidence({}), false);
  assert.equal(hasConnectedCallEvidence({
    sessionMetadata: {
      callConnectedAtTimestamp: Date.parse("2026-04-14T10:00:00Z"),
    },
  }), true);
  assert.equal(isExpiredEndReason("expired"), true);
  assert.equal(isExpiredEndReason("user_ended"), false);
});

test("pre-active end closes search without restoring participants", () => {
  const db = Symbol("db");
  const transaction = Symbol("transaction");
  const sessionData = {status: "connecting"};
  const serverTimestamp = Symbol("serverTimestamp");
  const fieldDelete = Symbol("fieldDelete");

  const options = buildPreActiveSessionPairLockReleaseOptions({
    db,
    transaction,
    sessionId: "session-pre-active-test",
    sessionData,
    serverTimestamp,
    fieldDelete,
    searchRequestStatus: "expired",
    stopReason: "pre_active_expired",
  });

  assert.equal(options.db, db);
  assert.equal(options.transaction, transaction);
  assert.equal(options.sessionId, "session-pre-active-test");
  assert.equal(options.sessionData, sessionData);
  assert.equal(options.serverTimestamp, serverTimestamp);
  assert.equal(options.fieldDelete, fieldDelete);
  assert.equal(options.searchRequestStatus, "expired");
  assert.equal(options.stopReason, "pre_active_expired");
  assert.equal(options.releaseCallState, true);
  assert.equal(options.restoreLegacyAvailability, true);
  assert.equal(options.restoreSearchParticipantIds, undefined);
  assert.equal(
    options.restoreSearchExcludedCandidateIdsByParticipantId,
    undefined,
  );
});

test("buildStudentCallCharge debits gift minutes for non-subscribers", () => {
  // 3-minute call against a 10-minute gift bucket → 7 minutes left.
  const charge = buildStudentCallCharge({
    userId: "student-a",
    duration: 180,
    formattedDuration: "3:00",
    giftRemainingMinutes: 10,
  });

  assert.equal(charge.subscriptionActive, false);
  assert.equal(charge.giftCovered, true);
  assert.equal(charge.giftMinutesUsed, 3);
  assert.equal(charge.newGiftMinutes, 7);
  assert.equal(charge.amountST, 0);
});

test("buildStudentCallCharge handles call longer than gift bucket", () => {
  // 5-minute call against 2-minute gift bucket → bucket drained to 0,
  // remainder is unbilled (the gate already let them in).
  const charge = buildStudentCallCharge({
    userId: "student-b",
    duration: 300,
    formattedDuration: "5:00",
    giftRemainingMinutes: 2,
  });

  assert.equal(charge.giftCovered, true);
  assert.equal(charge.giftMinutesUsed, 2);
  assert.equal(charge.newGiftMinutes, 0);
});

test("buildStudentCallCharge marks call uncovered when no gift bucket", () => {
  const charge = buildStudentCallCharge({
    userId: "student-c",
    duration: 120,
    formattedDuration: "2:00",
    giftRemainingMinutes: 0,
  });

  assert.equal(charge.subscriptionActive, false);
  assert.equal(charge.giftCovered, false);
  assert.equal(charge.giftMinutesUsed, 0);
});

test("resolveTeacherEarningUserId pays the teacher regardless of call direction", () => {
  assert.equal(
    resolveTeacherEarningUserId({
      requesterId: "student-a",
      requesterRole: "student",
      responderId: "teacher-b",
      acceptedResponderRole: "native_speaker",
    }),
    "teacher-b",
  );
  assert.equal(
    resolveTeacherEarningUserId({
      requesterId: "teacher-a",
      requesterRole: "native_speaker",
      responderId: "student-b",
      acceptedResponderRole: "student",
    }),
    "teacher-a",
  );
  assert.equal(
    resolveTeacherEarningUserId({
      requesterId: "student-a",
      requesterRole: "student",
      responderId: "student-b",
      acceptedResponderRole: "student",
    }),
    null,
  );
});

test("buildStudentCallCharge skips debit when subscription is active", () => {
  const charge = buildStudentCallCharge({
    userId: "student-a",
    duration: 1800, // 30 minutes
    formattedDuration: "30:00",
    subscriptionActive: true,
    giftRemainingMinutes: 10,
  });

  assert.equal(charge.subscriptionActive, true);
  assert.equal(charge.billableMinutes, 0);
  assert.equal(charge.amountST, 0);
  assert.equal(charge.giftCovered, false);
  // Gift bucket is preserved — subscription wins.
  assert.equal(charge.newGiftMinutes, 10);
  assert.equal(charge.giftMinutesUsed, 0);
});

test("hasActiveSubscription compares expiresAt against the current millis", () => {
  const now = Date.parse("2026-05-11T12:00:00Z");
  const futureTs = {
    toMillis: () => Date.parse("2026-05-15T00:00:00Z"),
  };
  const pastTs = {
    toMillis: () => Date.parse("2026-05-01T00:00:00Z"),
  };

  assert.equal(
      hasActiveSubscription({subscription: {expiresAt: futureTs}}, now),
      true,
  );
  assert.equal(
      hasActiveSubscription({subscription: {expiresAt: pastTs}}, now),
      false,
  );
  assert.equal(
      hasActiveSubscription({subscription: {}}, now),
      false,
  );
  assert.equal(hasActiveSubscription({}, now), false);
  assert.equal(hasActiveSubscription(null, now), false);
});

test("endSession source keeps the ignored_expired_end wrapper path", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "end_session.js"),
    "utf8",
  );

  assert.match(source, /shouldProcessExpiredEndReason\(\{/);
  assert.match(source, /status:\s*"ignored_expired_end"/);
  assert.match(source, /isPreActiveConnecting/);
  assert.match(source, /status:\s*terminalStatus/);
  assert.match(source, /source:\s*"endSession_pre_active_terminal"/);
  assert.match(source, /acceptedResponderRole === "student"/);
  assert.match(source, /acceptedResponderRole === "native_speaker"/);
  assert.match(source, /teacherEarningUserId/);
  assert.match(source, /txResult\.teacherEligibleForPayout/);
  assert.match(source, /getConnectedCallStartMillis\(sessionData\)/);
  assert.match(source, /acceptAttemptId: admin\.firestore\.FieldValue\.delete\(\)/);
  assert.doesNotMatch(source, /serverConnectedAt/);
  assert.match(source, /\.runWith\(\{\s*secrets:\s*dailySecrets\s*\}\)/);
  assert.match(source, /dailyRoomName:\s*resolveDailyRoomName\(sessionData\)/);
  assert.match(
    source,
    /backgroundTasks\.push\(deleteDailyRoomForSession\(\{/,
  );
  assert.match(source, /source:\s*"endSession_already_ended"/);
  assert.doesNotMatch(source, /serverConnectedAt/);
  assert.doesNotMatch(source, /startedAt\s*>\s*0/);
});
