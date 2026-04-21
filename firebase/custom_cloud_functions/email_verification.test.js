const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  __private__: {
    buildVerificationEmailHtml,
    formatSenderAddress,
    sendCustomEmailVerificationHandler,
  },
} = require("./email_verification");

test("custom email verification rejects unauthenticated calls", async () => {
  await assert.rejects(
    () =>
      sendCustomEmailVerificationHandler(
        {},
        {},
        {
          authClient: {},
          resendClient: {},
          env: {},
        },
      ),
    (error) => error?.code === "unauthenticated",
  );
});

test("custom email verification no-ops for verified email users", async () => {
  let generatedLink = false;
  let sentEmail = false;

  const result = await sendCustomEmailVerificationHandler(
    {},
    {auth: {uid: "user-1"}},
    {
      authClient: {
        async getUser(uid) {
          assert.equal(uid, "user-1");
          return {
            email: "verified@example.com",
            emailVerified: true,
          };
        },
        async generateEmailVerificationLink() {
          generatedLink = true;
        },
      },
      resendClient: {
        async post() {
          sentEmail = true;
        },
      },
      env: {},
    },
  );

  assert.deepEqual(result, {
    sent: false,
    alreadyVerified: true,
  });
  assert.equal(generatedLink, false);
  assert.equal(sentEmail, false);
});

test("custom email verification sends a Russian branded Resend email", async () => {
  const postCalls = [];

  const result = await sendCustomEmailVerificationHandler(
    {},
    {auth: {uid: "user-2"}},
    {
      authClient: {
        async getUser(uid) {
          assert.equal(uid, "user-2");
          return {
            email: "new@example.com",
            emailVerified: false,
            displayName: "Аня",
          };
        },
        async generateEmailVerificationLink(email) {
          assert.equal(email, "new@example.com");
          return "https://smalltalk.example/verify?code=abc";
        },
      },
      resendClient: {
        async post(url, payload, options) {
          postCalls.push({url, payload, options});
          return {
            data: {
              id: "email_123",
            },
          };
        },
      },
      env: {
        RESEND_API_KEY: "re_test",
        EMAIL_FROM: "noreply@example.com",
        EMAIL_REPLY_TO: "support@example.com",
      },
    },
  );

  assert.equal(result.sent, true);
  assert.equal(result.providerMessageId, "email_123");
  assert.equal(postCalls.length, 1);
  assert.equal(postCalls[0].url, "https://api.resend.com/emails");
  assert.equal(postCalls[0].payload.from, "SmallTalk <noreply@example.com>");
  assert.deepEqual(postCalls[0].payload.to, ["new@example.com"]);
  assert.equal(postCalls[0].payload.reply_to, "support@example.com");
  assert.equal(
    postCalls[0].payload.subject,
    "Подтвердите email для SmallTalk",
  );
  assert.match(postCalls[0].payload.html, /Аня, подтвердите email/);
  assert.match(postCalls[0].payload.html, /Подтвердить email/);
  assert.match(
    postCalls[0].payload.text,
    /https:\/\/smalltalk\.example\/verify\?code=abc/,
  );
  assert.equal(
    postCalls[0].options.headers.Authorization,
    "Bearer re_test",
  );
});

test("custom email verification returns controlled config errors", async () => {
  await assert.rejects(
    () =>
      sendCustomEmailVerificationHandler(
        {},
        {auth: {uid: "user-3"}},
        {
          authClient: {
            async getUser() {
              return {
                email: "new@example.com",
                emailVerified: false,
              };
            },
            async generateEmailVerificationLink() {
              return "https://smalltalk.example/verify?code=abc";
            },
          },
          resendClient: {
            async post() {
              throw new Error("should not send without config");
            },
          },
          env: {},
        },
      ),
    (error) =>
      error?.code === "failed-precondition" &&
      error?.details?.reason === "missing_resend_config",
  );
});

test("custom email verification escapes display name in HTML", () => {
  const html = buildVerificationEmailHtml({
    displayName: "<script>alert(1)</script>",
    verificationLink: "https://smalltalk.example/verify?code=abc&x=1",
  });

  assert.match(html, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
  assert.doesNotMatch(html, /<script>alert/);
  assert.match(html, /code=abc&amp;x=1/);
});

test("custom email verification keeps friendly sender when already provided", () => {
  assert.equal(
    formatSenderAddress("SmallTalk Team <hello@example.com>"),
    "SmallTalk Team <hello@example.com>",
  );
});

test("sendCustomEmailVerification is exported from the functions index", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "index.js"),
    "utf8",
  );

  assert.match(
    source,
    /const emailVerification = require\("\.\/email_verification\.js"\);/,
  );
  assert.match(
    source,
    /exports\.sendCustomEmailVerification\s*=\s*emailVerification\.sendCustomEmailVerification;/,
  );
});
