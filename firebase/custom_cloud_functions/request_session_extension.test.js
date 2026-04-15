const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    buildSessionExtensionMutation,
  },
} = require("./request_session_extension");

function buildActivePolicySession(overrides = {}) {
  return {
    status: "active",
    studentId: "user-a",
    tutorId: "user-b",
    participantIds: ["user-a", "user-b"],
    expiresAt: {
      toMillis: () => Date.parse("2026-04-14T10:05:00Z"),
    },
    sessionPolicy: {
      baseLimitSeconds: 300,
      warningLeadSeconds: 60,
      maxExtensionCount: 1,
      extensionSeconds: 300,
      extensionRequests: {},
      extensionApproved: false,
      effectiveLimitSeconds: 300,
    },
    ...overrides,
  };
}

test("first participant consent records pending request without moving expiry", () => {
  const mutation = buildSessionExtensionMutation({
    sessionData: buildActivePolicySession(),
    userId: "user-a",
    nowMillis: Date.parse("2026-04-14T10:04:15Z"),
  });

  assert.equal(mutation.status, "pending_partner");
  assert.equal(mutation.expiresAtMillis, Date.parse("2026-04-14T10:05:00Z"));
  assert.deepEqual(mutation.sessionPolicy.extensionRequests, {
    "user-a": true,
  });
  assert.equal(mutation.sessionPolicy.extensionApproved, false);
  assert.equal(mutation.sessionPolicy.effectiveLimitSeconds, 300);
});

test("second participant consent approves extension and bumps expiry by 5 minutes", () => {
  const mutation = buildSessionExtensionMutation({
    sessionData: buildActivePolicySession({
      sessionPolicy: {
        baseLimitSeconds: 300,
        warningLeadSeconds: 60,
        maxExtensionCount: 1,
        extensionSeconds: 300,
        extensionRequests: { "user-a": true },
        extensionApproved: false,
        effectiveLimitSeconds: 300,
      },
    }),
    userId: "user-b",
    nowMillis: Date.parse("2026-04-14T10:04:30Z"),
  });

  assert.equal(mutation.status, "approved");
  assert.equal(mutation.expiresAtMillis, Date.parse("2026-04-14T10:10:00Z"));
  assert.deepEqual(mutation.sessionPolicy.extensionRequests, {
    "user-a": true,
    "user-b": true,
  });
  assert.equal(mutation.sessionPolicy.extensionApproved, true);
  assert.equal(mutation.sessionPolicy.effectiveLimitSeconds, 600);
});

test("duplicate participant consent is idempotent", () => {
  const mutation = buildSessionExtensionMutation({
    sessionData: buildActivePolicySession({
      sessionPolicy: {
        extensionRequests: { "user-a": true },
      },
    }),
    userId: "user-a",
    nowMillis: Date.parse("2026-04-14T10:04:30Z"),
  });

  assert.equal(mutation.status, "already_requested");
  assert.equal(mutation.expiresAtMillis, Date.parse("2026-04-14T10:05:00Z"));
});

test("already-approved extension stays final", () => {
  const mutation = buildSessionExtensionMutation({
    sessionData: buildActivePolicySession({
      expiresAt: {
        toMillis: () => Date.parse("2026-04-14T10:10:00Z"),
      },
      sessionPolicy: {
        baseLimitSeconds: 300,
        warningLeadSeconds: 60,
        maxExtensionCount: 1,
        extensionSeconds: 300,
        extensionRequests: { "user-a": true, "user-b": true },
        extensionApproved: true,
        effectiveLimitSeconds: 600,
      },
    }),
    userId: "user-a",
    nowMillis: Date.parse("2026-04-14T10:05:30Z"),
  });

  assert.equal(mutation.status, "already_extended");
  assert.equal(mutation.sessionPolicy.effectiveLimitSeconds, 600);
});

test("extension rejects calls outside the warning window", () => {
  assert.throws(
    () =>
      buildSessionExtensionMutation({
        sessionData: buildActivePolicySession(),
        userId: "user-a",
        nowMillis: Date.parse("2026-04-14T10:03:30Z"),
      }),
    (error) =>
      error?.code === "failed-precondition" &&
      /not available yet/i.test(error.message),
  );
});

test("extension rejects expired sessions", () => {
  assert.throws(
    () =>
      buildSessionExtensionMutation({
        sessionData: buildActivePolicySession(),
        userId: "user-a",
        nowMillis: Date.parse("2026-04-14T10:05:00Z"),
      }),
    (error) =>
      error?.code === "failed-precondition" &&
      /window has expired/i.test(error.message),
  );
});

test("requestSessionExtension is exported from the functions index", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "index.js"),
    "utf8",
  );

  assert.match(source, /const requestSessionExtension = require\("\.\/request_session_extension\.js"\);/);
  assert.match(
    source,
    /exports\.requestSessionExtension\s*=\s*requestSessionExtension\.requestSessionExtension;/,
  );
});
