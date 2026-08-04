const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");

const projectId = process.env.GCLOUD_PROJECT || "demo-smalltalk-integrations";
const firestoreHostRaw = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const [firestoreHost, firestorePortStr] = firestoreHostRaw.split(":");
const firestorePort = Number.parseInt(firestorePortStr || "8080", 10);
const firestoreRules = fs.readFileSync(
  path.join(__dirname, "..", "firestore.rules"),
  "utf8",
);

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: firestoreHost,
      port: firestorePort,
      rules: firestoreRules,
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("videoSessions/session-a").set({
      status: "ended",
      participantIds: ["user-a", "user-b"],
      requesterId: "user-a",
      responderId: "user-b",
    });
    await db.doc("videoSessions/session-a/aiFeedback/user-a").set({
      ownerUid: "user-a",
      status: "ready",
      result: {score: 80},
    });
    await db.doc("users/user-a/translationLookups/lookup-a").set({
      ownerUid: "user-a",
      translatedText: "Hello",
    });
    await db.doc("translationCache/cache-a").set({status: "ready"});
    await db.doc("translationRateLimits/user-a").set({attemptCount: 1});
    await db.doc("aiFeedbackRateLimits/user-a").set({attemptCount: 1});
  });
});

test("feedback owner can get only their own result", async () => {
  const owner = testEnv.authenticatedContext("user-a").firestore();
  const participant = testEnv.authenticatedContext("user-b").firestore();
  const outsider = testEnv.authenticatedContext("user-c").firestore();

  await assertSucceeds(
    owner.doc("videoSessions/session-a/aiFeedback/user-a").get(),
  );
  await assertFails(
    participant.doc("videoSessions/session-a/aiFeedback/user-a").get(),
  );
  await assertFails(
    outsider.doc("videoSessions/session-a/aiFeedback/user-a").get(),
  );
  await assertFails(
    owner.collection("videoSessions/session-a/aiFeedback").get(),
  );
});

test("clients cannot write AI feedback", async () => {
  const owner = testEnv.authenticatedContext("user-a").firestore();
  const ref = owner.doc("videoSessions/session-a/aiFeedback/user-a");

  await assertFails(ref.update({status: "ready", result: {score: 100}}));
  await assertFails(ref.delete());
  await assertFails(
    owner.doc("videoSessions/session-a/aiFeedback/user-new").set({
      ownerUid: "user-a",
      status: "ready",
    }),
  );
});

test("translation lookups are private and server-owned", async () => {
  const owner = testEnv.authenticatedContext("user-a").firestore();
  const other = testEnv.authenticatedContext("user-b").firestore();

  await assertSucceeds(
    owner.doc("users/user-a/translationLookups/lookup-a").get(),
  );
  await assertSucceeds(
    owner.collection("users/user-a/translationLookups").get(),
  );
  await assertFails(
    other.doc("users/user-a/translationLookups/lookup-a").get(),
  );
  await assertFails(
    owner.doc("users/user-a/translationLookups/lookup-a").update({
      translatedText: "Changed",
    }),
  );
});

test("provider caches and rate limits are inaccessible to clients and admins", async () => {
  const owner = testEnv.authenticatedContext("user-a").firestore();
  const admin = testEnv.authenticatedContext("admin-user", {admin: true})
    .firestore();
  const paths = [
    "translationCache/cache-a",
    "translationRateLimits/user-a",
    "aiFeedbackRateLimits/user-a",
  ];

  for (const documentPath of paths) {
    await assertFails(owner.doc(documentPath).get());
    await assertFails(admin.doc(documentPath).get());
    await assertFails(owner.doc(documentPath).set({attemptCount: 99}));
  }
});
