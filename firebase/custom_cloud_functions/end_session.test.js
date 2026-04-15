const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
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

test("endSession source keeps the ignored_expired_end wrapper path", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "end_session.js"),
    "utf8",
  );

  assert.match(source, /shouldProcessExpiredEndReason\(\{/);
  assert.match(source, /status:\s*"ignored_expired_end"/);
});
