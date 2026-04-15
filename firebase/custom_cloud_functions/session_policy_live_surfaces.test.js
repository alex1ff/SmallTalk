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
