const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const {
  __private__: {
    buildLeaseDecision,
    buildRateLimitDecision,
    deliveryErrorDisposition,
    hmacIdentity,
    processPasswordResetRequestHandler,
    requestPasswordResetHandler,
    retryDelayMillis,
    sendPasswordResetEmail,
  },
} = require("./password_reset.js");

test("password reset callable requires App Check", async () => {
  await assert.rejects(
      () => requestPasswordResetHandler(
          {email: "user@example.com", locale: "en"},
          {},
          {enqueueRequest: async () => ({queued: true})},
      ),
      (error) => error?.code === "unauthenticated",
  );
});

test("password reset callable is neutral and normalizes input", async () => {
  const calls = [];
  const result = await requestPasswordResetHandler(
      {email: " User@Example.COM ", locale: "en-US"},
      {app: {appId: "com.appwave.expatlio"}},
      {
        db: {},
        hmacKey: "test-key",
        ipAddress: "203.0.113.5",
        now: new Date("2026-08-28T00:00:00Z"),
        enqueueRequest: async (input) => {
          calls.push(input);
          return {queued: false};
        },
      },
  );

  assert.deepEqual(result, {accepted: true});
  assert.equal(calls.length, 1);
  assert.equal(calls[0].email, "user@example.com");
  assert.equal(calls[0].locale, "en");
  assert.equal(calls[0].ipAddress, "203.0.113.5");
});

test("rate limit identities do not contain the original email", () => {
  const hash = hmacIdentity("private@example.com", "server-secret");
  assert.match(hash, /^[a-f0-9]{64}$/);
  assert.doesNotMatch(hash, /private|example/);
});

test("rate limit rejects excess requests without hot-counter writes", () => {
  assert.deepEqual(buildRateLimitDecision(2, 11), {
    allowed: true,
    incrementEmail: true,
    incrementIp: true,
  });
  assert.deepEqual(buildRateLimitDecision(3, 12), {
    allowed: false,
    incrementEmail: false,
    incrementIp: false,
  });
});

test("delivery lease becomes terminal after the bounded retry count", () => {
  const now = Date.parse("2026-08-28T12:00:00Z");
  assert.deepEqual(
      buildLeaseDecision({
        status: "retry",
        attemptCount: 4,
        expiresAt: new Date(now + 1000),
      }, now),
      {action: "discard", reason: "max_attempts"},
  );
});

test("delivery lease rejects active duplicates and expired requests", () => {
  const now = Date.parse("2026-08-28T12:00:00Z");
  assert.deepEqual(
      buildLeaseDecision({
        status: "processing",
        attemptCount: 1,
        leaseExpiresAt: new Date(now + 1000),
        expiresAt: new Date(now + 2000),
      }, now),
      {action: "leased"},
  );
  assert.deepEqual(
      buildLeaseDecision({
        status: "retry",
        attemptCount: 1,
        retryAt: new Date(now + 1000),
        expiresAt: new Date(now + 2000),
      }, now),
      {action: "retry_wait"},
  );
  assert.deepEqual(
      buildLeaseDecision({
        status: "retry",
        attemptCount: 1,
        expiresAt: new Date(now - 1),
      }, now),
      {action: "discard", reason: "expired"},
  );
});

test("password reset email uses stable Resend idempotency key", async () => {
  const calls = [];
  const result = await sendPasswordResetEmail({
    email: "user@example.com",
    resetLink: "https://example.com/auth/action?mode=resetPassword&oobCode=abc",
    locale: "en",
    requestId: "request-123",
    config: {
      resendApiKey: "re_test",
      emailFrom: "noreply@example.com",
      emailReplyTo: "support@example.com",
    },
    resendClient: {
      async post(url, payload, options) {
        calls.push({url, payload, options});
        return {data: {id: "email-123"}};
      },
    },
  });

  assert.deepEqual(result, {id: "email-123"});
  assert.equal(calls[0].options.headers["Idempotency-Key"], "request-123");
  assert.equal(calls[0].payload.from, "Expatlio <noreply@example.com>");
  assert.deepEqual(calls[0].payload.to, ["user@example.com"]);
  assert.match(calls[0].payload.html, /Choose new password/);
});

test("delivery errors distinguish permanent configuration from retryable outages", () => {
  assert.deepEqual(
      deliveryErrorDisposition({code: "password_reset_not_configured"}),
      {action: "fail", code: "password_reset_not_configured"},
  );
  assert.deepEqual(
      deliveryErrorDisposition({response: {status: 403}}),
      {action: "fail", code: "http_403"},
  );
  assert.deepEqual(
      deliveryErrorDisposition({response: {status: 429}}),
      {action: "retry", code: "http_429"},
  );
  assert.equal(retryDelayMillis(1), 60 * 1000);
  assert.equal(retryDelayMillis(4), 8 * 60 * 1000);
});

test("processor discards unknown accounts without sending email", async () => {
  const updates = [];
  let sendCalls = 0;
  await processPasswordResetRequestHandler(
      {id: "request-1", ref: {path: "passwordResetRequests/request-1"}},
      {params: {requestId: "request-1"}},
      {
        db: {},
        randomId: () => "lease-1",
        acquireLease: async () => ({
          action: "acquire",
          attemptCount: 1,
          request: {email: "missing@example.com", locale: "ru"},
        }),
        authClient: {
          async getUserByEmail() {
            const error = new Error("missing");
            error.code = "auth/user-not-found";
            throw error;
          },
        },
        sendEmail: async () => {
          sendCalls += 1;
        },
        updateLease: async (input) => {
          updates.push(input.update);
          return true;
        },
      },
  );

  assert.equal(sendCalls, 0);
  assert.equal(updates.length, 1);
  assert.equal(updates[0].status, "discarded");
  assert.equal(updates[0].discardReason, "account_not_found");
});

test("processor keeps platform retries alive while another lease is active", async () => {
  await assert.rejects(
      () => processPasswordResetRequestHandler(
          {id: "request-leased", ref: {}},
          {params: {requestId: "request-leased"}},
          {
            db: {},
            randomId: () => "lease-duplicate",
            acquireLease: async () => ({action: "leased"}),
          },
      ),
      (error) => error?.code === "delivery_lease_active",
  );
});

test("processor sends a canonical link and removes queued email", async () => {
  const sendCalls = [];
  const updates = [];
  await processPasswordResetRequestHandler(
      {id: "request-success", ref: {}},
      {params: {requestId: "request-success"}},
      {
        db: {},
        randomId: () => "lease-success",
        acquireLease: async () => ({
          action: "acquire",
          attemptCount: 1,
          request: {email: "user@example.com", locale: "en"},
        }),
        authClient: {
          async getUserByEmail() {
            return {uid: "user-1"};
          },
          async generatePasswordResetLink() {
            return "https://smalltalk-2109b.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=code_1&apiKey=key_1&continueUrl=https://evil.example";
          },
        },
        env: {
          RESEND_API_KEY: "re_test",
          EMAIL_FROM: "noreply@example.com",
        },
        sendEmail: async (input) => {
          sendCalls.push(input);
          return {id: "email-success"};
        },
        updateLease: async (input) => {
          updates.push(input.update);
          return true;
        },
      },
  );

  assert.equal(sendCalls.length, 1);
  assert.equal(sendCalls[0].requestId, "request-success");
  const link = new URL(sendCalls[0].resetLink);
  assert.equal(link.searchParams.get("mode"), "resetPassword");
  assert.equal(link.searchParams.get("continueUrl"),
      "smalltalk://smalltalk.com/?passwordReset=1");
  assert.equal(link.searchParams.get("unexpected"), null);
  assert.equal(updates.length, 1);
  assert.equal(updates[0].status, "sent");
  assert.equal(updates[0].providerMessageId, "email-success");
  assert.ok(updates[0].email);
});

test("processor retries transient delivery errors", async () => {
  const updates = [];
  await assert.rejects(
      () => processPasswordResetRequestHandler(
          {id: "request-2", ref: {}},
          {params: {requestId: "request-2"}},
          {
            db: {},
            now: new Date("2026-08-28T00:00:00Z"),
            randomId: () => "lease-2",
            acquireLease: async () => ({
              action: "acquire",
              attemptCount: 1,
              request: {email: "user@example.com", locale: "en"},
            }),
            authClient: {
              async getUserByEmail() {
                return {uid: "user-1"};
              },
              async generatePasswordResetLink() {
                return "https://smalltalk-2109b.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=code_1&apiKey=key_1&unexpected=secret";
              },
            },
            env: {
              RESEND_API_KEY: "re_test",
              EMAIL_FROM: "noreply@example.com",
            },
            sendEmail: async (input) => {
              const link = new URL(input.resetLink);
              assert.equal(link.searchParams.get("mode"), "resetPassword");
              assert.equal(link.searchParams.get("unexpected"), null);
              throw new Error("provider unavailable");
            },
            updateLease: async (input) => {
              updates.push(input.update);
              return true;
            },
          },
      ),
      (error) => error?.code === "delivery_failed" &&
        !String(error?.message).includes("provider unavailable"),
  );

  assert.equal(updates.length, 1);
  assert.equal(updates[0].status, "retry");
  assert.equal(
      updates[0].retryAt.getTime(),
      Date.parse("2026-08-28T00:01:00Z"),
  );
});

test("processor discards permanent provider errors without retrying", async () => {
  const updates = [];
  const result = await processPasswordResetRequestHandler(
      {id: "request-permanent", ref: {}},
      {params: {requestId: "request-permanent"}},
      {
        db: {},
        now: new Date("2026-08-28T00:00:00Z"),
        randomId: () => "lease-permanent",
        acquireLease: async () => ({
          action: "acquire",
          attemptCount: 1,
          request: {email: "user@example.com", locale: "en"},
        }),
        authClient: {
          async getUserByEmail() {
            return {uid: "user-1"};
          },
          async generatePasswordResetLink() {
            return "https://smalltalk-2109b.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=code_1&apiKey=key_1";
          },
        },
        sendEmail: async () => {
          const error = new Error("provider included a private URL");
          error.response = {status: 403};
          throw error;
        },
        updateLease: async (input) => {
          updates.push(input.update);
          return true;
        },
      },
  );

  assert.equal(result, null);
  assert.equal(updates.length, 1);
  assert.equal(updates[0].status, "discarded");
  assert.equal(updates[0].discardReason, "permanent_http_403");
});

test("hosted action page verifies and confirms password reset codes", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "..", "public", "auth", "action", "index.html"),
      "utf8",
  );

  assert.match(source, /verifyPasswordResetCode\(actionCode\)/);
  assert.match(source, /confirmPasswordReset\(actionCode, password\.value\)/);
  assert.match(source, /mode === "resetPassword"/);
  assert.match(source, /smalltalk:\/\/smalltalk\.com\/\?passwordReset=1/);
});

test("hosted action page completes the reset-password flow", async () => {
  const harness = runHostedActionPage({
    search: "?mode=resetPassword&oobCode=code_1&apiKey=key_1&lang=en",
  });
  await flushPromises();

  assert.deepEqual(harness.verifyCalls, ["code_1"]);
  assert.equal(harness.elements.resetForm.hidden, false);
  assert.equal(harness.elements.title.textContent, "New password");

  harness.elements.password.value = "new-password";
  harness.elements.passwordConfirm.value = "new-password";
  harness.elements.resetForm.listeners.submit({preventDefault() {}});
  await flushPromises();

  assert.deepEqual(harness.confirmCalls, [
    {code: "code_1", password: "new-password"},
  ]);
  assert.equal(harness.elements.title.textContent, "Password changed");
});

test("hosted action page offers retry after a transient verification error",
    async () => {
      let attempts = 0;
      const harness = runHostedActionPage({
        search: "?mode=resetPassword&oobCode=code_2&apiKey=key_1&lang=en",
        verifyPasswordResetCode: async () => {
          attempts += 1;
          if (attempts === 1) {
            const error = new Error("offline");
            error.code = "auth/network-request-failed";
            throw error;
          }
          return "user@example.com";
        },
      });
      await flushPromises();

      assert.equal(harness.elements.retryButton.hidden, false);
      assert.equal(
          harness.elements.title.textContent,
          "Could not check the link",
      );

      harness.elements.retryButton.listeners.click();
      await flushPromises();
      assert.equal(attempts, 2);
      assert.equal(harness.elements.resetForm.hidden, false);
    });

function runHostedActionPage({
  search,
  verifyPasswordResetCode = async () => "user@example.com",
}) {
  const source = fs.readFileSync(
      path.join(__dirname, "..", "public", "auth", "action", "index.html"),
      "utf8",
  );
  const scriptMatches = [...source.matchAll(/<script>([\s\S]*?)<\/script>/g)];
  const script = scriptMatches.at(-1)[1];
  const ids = [
    "title",
    "message",
    "statusIcon",
    "openAppButton",
    "retryButton",
    "resetForm",
    "password",
    "passwordConfirm",
    "fieldError",
    "resetButton",
    "passwordLabel",
    "passwordConfirmLabel",
  ];
  const elements = Object.fromEntries(ids.map((id) => [id, fakeElement()]));
  elements.openAppButton.hidden = true;
  elements.retryButton.hidden = true;
  elements.resetForm.hidden = true;
  const verifyCalls = [];
  const confirmCalls = [];
  const authClient = {
    verifyPasswordResetCode(code) {
      verifyCalls.push(code);
      return verifyPasswordResetCode(code);
    },
    async confirmPasswordReset(code, password) {
      confirmCalls.push({code, password});
    },
    async applyActionCode() {},
  };
  const sandbox = {
    Array,
    URL,
    URLSearchParams,
    firebase: {
      initializeApp() {},
      auth: () => authClient,
    },
    document: {
      documentElement: {lang: ""},
      getElementById: (id) => elements[id],
    },
    navigator: {userAgent: "node-test"},
    setTimeout,
    window: {
      location: {
        search,
        assign() {},
      },
      setTimeout,
    },
  };
  vm.runInNewContext(script, sandbox);
  return {confirmCalls, elements, verifyCalls};
}

function fakeElement() {
  return {
    dataset: {},
    hidden: false,
    innerHTML: "",
    listeners: {},
    textContent: "",
    value: "",
    addEventListener(name, listener) {
      this.listeners[name] = listener;
    },
    focus() {},
  };
}

async function flushPromises() {
  await new Promise((resolve) => {
    setImmediate(resolve);
  });
  await new Promise((resolve) => {
    setImmediate(resolve);
  });
}
