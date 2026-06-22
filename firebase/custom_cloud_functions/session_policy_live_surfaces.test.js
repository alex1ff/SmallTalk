const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");
const {
  __private__: {
    buildCreateSessionPolicyFields,
  },
} = require("./create_video_session");
const {
  __private__: {
    assertAcceptAttemptCanFinalizeOrThrow,
    assertAcceptedSessionStillCurrentOrThrow,
    assertUserCanJoinAcceptedSessionOrThrow,
    assertUserIsInAcceptedSessionOrThrow,
    assertAcceptWindowOpenOrThrow,
    buildAcceptedParticipantUserUpdate,
    buildAcceptCallPolicyUpdateFields,
    buildAcceptCallResponseSessionData,
    normalizeSessionId,
  },
} = require("./accept_call");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "demo-smalltalk" });
}

function readFunctionSource(fileName) {
  return fs.readFileSync(path.join(__dirname, fileName), "utf8");
}

test("createVideoSession policy fields persist the new session contract", () => {
  const fields = buildCreateSessionPolicyFields(
    Date.parse("2026-04-14T10:00:00Z"),
  );

  assert.equal(
    fields.expiresAt.toDate().toISOString(),
    "2026-04-14T10:05:00.000Z",
  );
  assert.deepEqual(fields.sessionPolicy, {
    baseLimitSeconds: 300,
    warningLeadSeconds: 60,
    maxExtensionCount: 1,
    extensionSeconds: 300,
    extensionRequests: {},
    extensionApproved: false,
    effectiveLimitSeconds: 300,
  });
});

test("acceptCall policy update derives active expiry from stored policy", () => {
  const update = buildAcceptCallPolicyUpdateFields(
    {
      sessionPolicy: {
        baseLimitSeconds: 300,
        warningLeadSeconds: 60,
        maxExtensionCount: 1,
        extensionSeconds: 300,
        effectiveLimitSeconds: 600,
      },
    },
    Date.parse("2026-04-14T10:00:00Z"),
  );

  assert.equal(
    update.sessionUpdateFields.expiresAt.toDate().toISOString(),
    "2026-04-14T10:10:00.000Z",
  );
  assert.equal(update.sessionUpdateFields.sessionPolicy.effectiveLimitSeconds, 600);
  assert.equal(update.policyState.maxDurationMs, 600000);
});

test("acceptCall response data uses policy maxDuration when policy exists", () => {
  const startedAt = admin.firestore.Timestamp.fromMillis(
    Date.parse("2026-04-14T10:00:00Z"),
  );
  const responseData = buildAcceptCallResponseSessionData({
    language: "en",
    startedAt,
    sessionPolicy: {
      effectiveLimitSeconds: 300,
    },
  });

  assert.deepEqual(responseData, {
    language: "en",
    startedAt: startedAt.toMillis(),
    maxDuration: 300000,
  });
});

test("acceptCall live helpers preserve legacy fallback without policy", () => {
  const update = buildAcceptCallPolicyUpdateFields(
    {},
    Date.parse("2026-04-14T10:00:00Z"),
  );
  const responseData = buildAcceptCallResponseSessionData({
    language: "ru",
  });

  assert.equal(update.sessionUpdateFields.sessionPolicy, undefined);
  assert.equal(
    update.sessionUpdateFields.expiresAt.toDate().toISOString(),
    "2026-04-14T11:00:00.000Z",
  );
  assert.equal(update.policyState.maxDurationMs, 3600000);
  assert.deepEqual(responseData, {
    language: "ru",
    startedAt: null,
    maxDuration: 3600000,
  });
});

test("acceptCall confirmed participant update marks active call state", () => {
  const serverTimestamp = Symbol("serverTimestamp");

  assert.deepEqual(
    buildAcceptedParticipantUserUpdate({
      sessionId: "session-confirmed",
      serverTimestamp,
    }),
    {
      isInCall: true,
      currentSessionId: "session-confirmed",
      updatedAt: serverTimestamp,
    },
  );
});

test("acceptCall final transaction rejects participants in other sessions", () => {
  assert.equal(normalizeSessionId(" session-a "), "session-a");
  assert.doesNotThrow(() => assertUserCanJoinAcceptedSessionOrThrow(
    {
      isInCall: false,
      currentSessionId: "session-a",
    },
    "student-a",
    "session-a",
  ));
  assert.throws(
    () => assertUserCanJoinAcceptedSessionOrThrow(
      {
        isInCall: false,
        currentSessionId: "session-other",
      },
      "student-a",
      "session-a",
    ),
    (error) =>
      error.code === "failed-precondition" &&
      /assigned to another session/.test(error.message),
  );
  assert.throws(
    () => assertUserCanJoinAcceptedSessionOrThrow(
      {
        isInCall: true,
        currentSessionId: "",
      },
      "student-a",
      "session-a",
    ),
    (error) =>
      error.code === "failed-precondition" &&
      /already in a call/.test(error.message),
  );
});

test("acceptCall post-commit validation rejects stale accepted sessions", () => {
  assert.doesNotThrow(() => assertUserIsInAcceptedSessionOrThrow(
    {
      isInCall: true,
      currentSessionId: "session-a",
    },
    "student-a",
    "session-a",
  ));
  assert.doesNotThrow(() => assertAcceptedSessionStillCurrentOrThrow({
    sessionData: {
      status: "connecting",
      tutorId: "student-b",
      dailyRoomUrl: "https://daily.test/room-a",
    },
    requesterData: {
      isInCall: true,
      currentSessionId: "session-a",
    },
    responderData: {
      isInCall: true,
      currentSessionId: "session-a",
    },
    requesterId: "student-a",
    responderId: "student-b",
    sessionId: "session-a",
  }));
  assert.throws(
    () => assertAcceptedSessionStillCurrentOrThrow({
      sessionData: {
        status: "cancelled",
        tutorId: "student-b",
        dailyRoomUrl: "https://daily.test/room-a",
      },
      requesterData: {
        isInCall: true,
        currentSessionId: "session-a",
      },
      responderData: {
        isInCall: true,
        currentSessionId: "session-a",
      },
      requesterId: "student-a",
      responderId: "student-b",
      sessionId: "session-a",
    }),
    (error) =>
      error.code === "failed-precondition" &&
      /Accepted session changed/.test(error.message),
  );
  assert.throws(
    () => assertAcceptedSessionStillCurrentOrThrow({
      sessionData: {
        status: "connecting",
        tutorId: "student-b",
        dailyRoomUrl: "https://daily.test/room-a",
      },
      requesterData: {
        isInCall: false,
        currentSessionId: "",
      },
      responderData: {
        isInCall: true,
        currentSessionId: "session-a",
      },
      requesterId: "student-a",
      responderId: "student-b",
      sessionId: "session-a",
    }),
    (error) =>
      error.code === "failed-precondition" &&
      /not in the accepted session/.test(error.message),
  );
});

test("acceptCall rejects stale response confirmation windows", () => {
  const nowMillis = Date.parse("2026-04-14T10:00:45Z");
  assert.throws(
    () => assertAcceptWindowOpenOrThrow(
      {
        responseExpiresAt: admin.firestore.Timestamp.fromMillis(nowMillis),
        expiresAt: admin.firestore.Timestamp.fromMillis(nowMillis + 60_000),
      },
      nowMillis,
    ),
    (error) =>
      error.code === "invalid-argument" &&
      /response window has expired/.test(error.message),
  );
  assert.doesNotThrow(() => assertAcceptWindowOpenOrThrow(
    {
      responseExpiresAt: admin.firestore.Timestamp.fromMillis(nowMillis + 1),
      expiresAt: admin.firestore.Timestamp.fromMillis(nowMillis + 60_000),
    },
    nowMillis,
  ));
});

test("acceptCall rejects stale legacy session expiry", () => {
  const nowMillis = Date.parse("2026-04-14T10:05:00Z");
  assert.throws(
    () => assertAcceptWindowOpenOrThrow(
      {
        expiresAt: admin.firestore.Timestamp.fromMillis(nowMillis),
      },
      nowMillis,
    ),
    (error) =>
      error.code === "invalid-argument" &&
      /Session has expired/.test(error.message),
  );
});

test("acceptCall final transaction accepts only a fresh owned attempt", () => {
  const acceptingAtMillis = Date.parse("2026-04-14T10:00:10Z");
  const responseDeadlineMillis = acceptingAtMillis + 1_000;
  const finalizationMillis = responseDeadlineMillis + 10_000;

  assert.doesNotThrow(() => assertAcceptAttemptCanFinalizeOrThrow({
    sessionData: {
      acceptingTutorId: "student-b",
      acceptAttemptId: "attempt-current",
      acceptingAt: admin.firestore.Timestamp.fromMillis(acceptingAtMillis),
      responseExpiresAt: admin.firestore.Timestamp.fromMillis(
        responseDeadlineMillis,
      ),
    },
    responderId: "student-b",
    acceptAttemptId: "attempt-current",
    nowMillis: finalizationMillis,
  }));
  assert.throws(
    () => assertAcceptAttemptCanFinalizeOrThrow({
      sessionData: {
        acceptingTutorId: "student-b",
        acceptAttemptId: "attempt-newer",
        acceptingAt: admin.firestore.Timestamp.fromMillis(acceptingAtMillis),
        responseExpiresAt: admin.firestore.Timestamp.fromMillis(
          responseDeadlineMillis,
        ),
      },
      responderId: "student-b",
      acceptAttemptId: "attempt-current",
      nowMillis: finalizationMillis,
    }),
    (error) =>
      error.code === "failed-precondition" &&
      /accept lock is stale/.test(error.message),
  );
  assert.throws(
    () => assertAcceptAttemptCanFinalizeOrThrow({
      sessionData: {
        acceptingTutorId: "student-b",
        acceptAttemptId: "attempt-current",
        acceptingAt: admin.firestore.Timestamp.fromMillis(
          acceptingAtMillis - 30_001,
        ),
      },
      responderId: "student-b",
      acceptAttemptId: "attempt-current",
      nowMillis: acceptingAtMillis,
    }),
    (error) =>
      error.code === "failed-precondition" &&
      /accept lock has expired/.test(error.message),
  );
});

test("createVideoSession live write path uses policy field builder", () => {
  const source = readFunctionSource("create_video_session.js");

  assert.match(
    source,
    /const sessionPolicyFields = buildCreateSessionPolicyFields\(\);/,
  );
  assert.match(source, /\.\.\.sessionPolicyFields,/);
});

test("createVideoSession validates active accept lock before initial push", () => {
  const source = readFunctionSource("create_video_session.js");
  const creationPushIndex = source.indexOf(
    "if (creation.selectedResponderId && creation.pushPayload)",
  );
  const validationIndex = source.indexOf(
    "hasActiveAcceptLockForResponder({",
    creationPushIndex,
  );
  const pushIndex = source.indexOf(
    "await sendVoipPushToTutor(",
    validationIndex,
  );
  const retryAssignmentIndex = source.indexOf(
    "if (!assignment || !assignment.shouldNotify)",
  );
  const retryValidationIndex = source.indexOf(
    "hasActiveAcceptLockForResponder({",
    retryAssignmentIndex,
  );
  const retryPushIndex = source.indexOf(
    "await sendVoipPushToTutor(nextTutor",
    retryValidationIndex,
  );

  assert.ok(validationIndex > creationPushIndex);
  assert.ok(pushIndex > validationIndex);
  assert.ok(retryValidationIndex > retryAssignmentIndex);
  assert.ok(retryPushIndex > retryValidationIndex);
});

test("acceptCall live response paths use policy-backed response builder", () => {
  const source = readFunctionSource("accept_call.js");

  const responseBuilderUses = source.match(
    /buildAcceptCallResponseSessionData\(/g,
  ) || [];
  assert.ok(responseBuilderUses.length >= 3);
  assert.doesNotMatch(source, /maxDuration:\s*3600000/);
});

test("acceptCall marks requester and responder in-call after confirmation", () => {
  const source = readFunctionSource("accept_call.js");
  const tokenGuardIndex = source.indexOf(
    'console.error("❌ Daily meeting token creation failed");',
  );
  const finalTransactionIndex = source.indexOf(
    "const txnResult = await admin",
    tokenGuardIndex,
  );
  const connectingStatusIndex = source.indexOf(
    "status: VIDEO_SESSION_STATUS.CONNECTING",
    finalTransactionIndex,
  );
  const sessionUpdateIndex = source.indexOf(
    "transaction.update(sessionRef, sessionUpdate);",
    connectingStatusIndex,
  );
  const participantUpdateIndex = source.indexOf(
    "const participantUserUpdate = buildAcceptedParticipantUserUpdate({",
    sessionUpdateIndex,
  );
  const requesterUpdateIndex = source.indexOf(
    "transaction.update(requesterUserRef, participantUserUpdate);",
    participantUpdateIndex,
  );
  const responderUpdateIndex = source.indexOf(
    "transaction.update(responderUserRef, participantUserUpdate);",
    participantUpdateIndex,
  );
  const transactionSuccessIndex = source.indexOf(
    "return { alreadyAccepted: false };",
    participantUpdateIndex,
  );

  assert.notEqual(tokenGuardIndex, -1);
  assert.notEqual(finalTransactionIndex, -1);
  assert.ok(
    finalTransactionIndex > tokenGuardIndex,
    "acceptCall must start the final transaction only after Daily token exists",
  );
  assert.notEqual(connectingStatusIndex, -1);
  assert.ok(
    connectingStatusIndex > finalTransactionIndex,
    "acceptCall must mark the session connecting in the final transaction",
  );
  assert.notEqual(sessionUpdateIndex, -1);
  assert.notEqual(participantUpdateIndex, -1);
  assert.ok(
    participantUpdateIndex > sessionUpdateIndex,
    "participant in-call writes must happen in the same transaction after the session update",
  );
  assert.ok(
    requesterUpdateIndex > participantUpdateIndex &&
      requesterUpdateIndex < transactionSuccessIndex,
    "acceptCall must mark requester in-call after confirmation",
  );
  assert.ok(
    responderUpdateIndex > participantUpdateIndex &&
      responderUpdateIndex < transactionSuccessIndex,
    "acceptCall must mark responder in-call after confirmation",
  );
});

test("acceptCall final transaction reads user locks before participant writes", () => {
  const source = readFunctionSource("accept_call.js");
  const finalTransactionIndex = source.indexOf(
    "const txnResult = await admin",
  );
  const requesterReadIndex = source.indexOf(
    "const requesterUserSnap = await transaction.get(requesterUserRef);",
    finalTransactionIndex,
  );
  const responderReadIndex = source.indexOf(
    "const responderUserSnap = await transaction.get(responderUserRef);",
    finalTransactionIndex,
  );
  const requesterGuardIndex = source.indexOf(
    "assertUserCanJoinAcceptedSessionOrThrow(",
    responderReadIndex,
  );
  const participantUpdateIndex = source.indexOf(
    "const participantUserUpdate = buildAcceptedParticipantUserUpdate({",
    requesterGuardIndex,
  );

  assert.notEqual(finalTransactionIndex, -1);
  assert.ok(requesterReadIndex > finalTransactionIndex);
  assert.ok(responderReadIndex > requesterReadIndex);
  assert.ok(requesterGuardIndex > responderReadIndex);
  assert.ok(participantUpdateIndex > requesterGuardIndex);
});

test("acceptCall validates accepted session before push and response", () => {
  const source = readFunctionSource("accept_call.js");
  const finalTransactionIndex = source.indexOf(
    "const txnResult = await admin",
  );
  const validationIndex = source.indexOf(
    "readAcceptedSessionStillCurrentOrThrow({",
    finalTransactionIndex,
  );
  const pushIndex = source.indexOf(
    "sendVoipPushToStudent(requesterId",
    validationIndex,
  );
  const responseIndex = source.indexOf(
    'status: "connected"',
    pushIndex,
  );

  assert.ok(validationIndex > finalTransactionIndex);
  assert.ok(pushIndex > validationIndex);
  assert.ok(responseIndex > pushIndex);
});

test("acceptCall final transaction rechecks accept attempt ownership", () => {
  const source = readFunctionSource("accept_call.js");
  const finalTransactionIndex = source.indexOf(
    "const txnResult = await admin",
  );
  const lockGuardIndex = source.indexOf(
    "assertAcceptAttemptCanFinalizeOrThrow({",
    finalTransactionIndex,
  );
  const sessionUpdateIndex = source.indexOf(
    "transaction.update(sessionRef, sessionUpdate);",
    finalTransactionIndex,
  );

  assert.notEqual(finalTransactionIndex, -1);
  assert.ok(
    lockGuardIndex > finalTransactionIndex &&
      lockGuardIndex < sessionUpdateIndex,
    "acceptCall must verify accept attempt ownership before final update",
  );
});

test("acceptCall does not replace an active same-responder accept attempt", () => {
  const source = readFunctionSource("accept_call.js");
  const activeLockIndex = source.indexOf("const isActiveAcceptLock =");
  const inactiveLockUpdateIndex = source.indexOf(
    "acceptAttemptId,",
    activeLockIndex,
  );
  const alreadyBeingAcceptedIndex = source.indexOf(
    '"Session is already being accepted"',
    inactiveLockUpdateIndex,
  );
  const sameResponderBranchIndex = source.indexOf(
    "if (acceptingTutorId === tutorId)",
    activeLockIndex,
  );

  assert.notEqual(activeLockIndex, -1);
  assert.ok(inactiveLockUpdateIndex > activeLockIndex);
  assert.ok(alreadyBeingAcceptedIndex > inactiveLockUpdateIndex);
  assert.equal(
    sameResponderBranchIndex,
    -1,
    "active same-responder accept must not overwrite acceptAttemptId",
  );
});

test("acceptCall cleanup releases only its own accept attempt", () => {
  const source = readFunctionSource("accept_call.js");
  const cleanupIndex = source.indexOf(
    "Failed to release accept lock",
  );
  const attemptGuardIndex = source.indexOf(
    "data.acceptAttemptId === acceptAttemptId",
    cleanupIndex - 500,
  );
  const attemptDeleteIndex = source.indexOf(
    "acceptAttemptId: admin.firestore.FieldValue.delete()",
    attemptGuardIndex,
  );

  assert.notEqual(cleanupIndex, -1);
  assert.ok(
    attemptGuardIndex > 0 && attemptGuardIndex < cleanupIndex,
    "acceptCall cleanup must compare acceptAttemptId before deleting lock",
  );
  assert.ok(
    attemptDeleteIndex > attemptGuardIndex,
    "acceptCall cleanup must delete acceptAttemptId with the lock",
  );
});
