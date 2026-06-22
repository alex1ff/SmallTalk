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
    assertAcceptWindowOpenOrThrow,
    buildAcceptedParticipantUserUpdate,
    buildAcceptCallPolicyUpdateFields,
    buildAcceptCallResponseSessionData,
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

test("createVideoSession live write path uses policy field builder", () => {
  const source = readFunctionSource("create_video_session.js");

  assert.match(
    source,
    /const sessionPolicyFields = buildCreateSessionPolicyFields\(\);/,
  );
  assert.match(source, /\.\.\.sessionPolicyFields,/);
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
  const requesterUpdate = [
    "transaction.update(",
    '            admin.firestore().collection("users").doc(requesterId),',
    "            participantUserUpdate,",
    "          );",
  ].join("\n");
  const responderUpdate = [
    "transaction.update(",
    '            admin.firestore().collection("users").doc(tutorId),',
    "            participantUserUpdate,",
    "          );",
  ].join("\n");
  const requesterUpdateIndex = source.indexOf(
    requesterUpdate,
    participantUpdateIndex,
  );
  const responderUpdateIndex = source.indexOf(
    responderUpdate,
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
