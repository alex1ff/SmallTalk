const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const firebaseCompat = require("firebase/compat/app");

require("firebase/compat/firestore");

const projectId = process.env.GCLOUD_PROJECT || "demo-smalltalk-access-rules";
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
    await db.doc("users/user-a/trialAccess/current").set({status: "active"});
    await db.doc("users/user-a/trialAccess/history").set({status: "expired"});
    await db.doc("subscriptionTrialGrants/grant-a").set({userId: "user-a"});
    await db.doc("userPrivateTokens/user-a").set({voipToken: "private-token"});
    await db.doc("transactions/transaction-a").set({
      userId: db.doc("users/user-a"),
      type: "call_charge",
      status: "completed",
    });
    await db.doc("promoCodes/TEST").set({
      code: "TEST",
      usageCount: 0,
      usageLimit: 5,
      isActive: true,
    });
    await db.doc("internalDiagnostics/root-a").set({status: "ready"});
    await db.doc("internalDiagnostics/root-a/private/child-a").set({
      secret: "server-only",
    });
    await db.doc("translationCache/cache-a").set({status: "ready"});
  });
});

test("trial access exposes only the owner's current document", async () => {
  const owner = testEnv.authenticatedContext("user-a").firestore();
  const other = testEnv.authenticatedContext("user-b").firestore();
  const current = owner.doc("users/user-a/trialAccess/current");

  await assertSucceeds(current.get());
  await assertFails(other.doc("users/user-a/trialAccess/current").get());
  await assertFails(owner.doc("users/user-a/trialAccess/history").get());
  await assertFails(owner.collection("users/user-a/trialAccess").get());
  await assertFails(current.set({status: "active"}));
  await assertFails(current.update({status: "expired"}));
  await assertFails(current.delete());
});

test("transactions are server-written and readable only by owner or admin", async () => {
  const owner = testEnv.authenticatedContext("user-a").firestore();
  const other = testEnv.authenticatedContext("user-b").firestore();
  const admin = testEnv.authenticatedContext("admin-user", {admin: true})
    .firestore();
  const transaction = owner.doc("transactions/transaction-a");

  await assertSucceeds(transaction.get());
  await assertFails(other.doc("transactions/transaction-a").get());
  await assertSucceeds(admin.doc("transactions/transaction-a").get());
  await assertFails(owner.doc("transactions/client-created").set({
    userId: owner.doc("users/user-a"),
    type: "bonus",
  }));
  await assertFails(transaction.update({status: "reversed"}));
  await assertFails(transaction.delete());
});

test("promo redemption cannot add or remove unrelated fields", async () => {
  const user = testEnv.authenticatedContext("user-a").firestore();
  const promo = user.doc("promoCodes/TEST");

  await assertFails(promo.update({
    usageCount: 1,
    usageLimit: firebaseCompat.firestore.FieldValue.delete(),
  }));
  await assertFails(promo.update({
    usageCount: 1,
    injectedAccessField: true,
  }));
});

test("promo counter updates are server-only", async () => {
  const user = testEnv.authenticatedContext("user-a").firestore();

  await assertFails(user.doc("promoCodes/TEST").update({usageCount: 1}));
});

test("support admin fallback is explicit for locally denied operational reads", async () => {
  const user = testEnv.authenticatedContext("user-a").firestore();
  const admin = testEnv.authenticatedContext("admin-user", {admin: true})
    .firestore();
  const paths = [
    "users/user-a/trialAccess/current",
    "subscriptionTrialGrants/grant-a",
    "userPrivateTokens/user-a",
  ];

  await assertFails(user.doc("subscriptionTrialGrants/grant-a").get());
  await assertFails(user.doc("userPrivateTokens/user-a").get());
  for (const documentPath of paths) {
    await assertSucceeds(admin.doc(documentPath).get());
    await assertFails(admin.doc(documentPath).update({tampered: true}));
  }
});

test("catch-all keeps unknown data private and preserves support admin reads", async () => {
  const guest = testEnv.unauthenticatedContext().firestore();
  const user = testEnv.authenticatedContext("user-a").firestore();
  const admin = testEnv.authenticatedContext("admin-user", {admin: true})
    .firestore();
  const paths = [
    "internalDiagnostics/root-a",
    "internalDiagnostics/root-a/private/child-a",
  ];

  for (const documentPath of paths) {
    await assertFails(guest.doc(documentPath).get());
    await assertFails(user.doc(documentPath).get());
    await assertSucceeds(admin.doc(documentPath).get());
    await assertFails(user.doc(documentPath).set({tampered: true}));
    await assertFails(admin.doc(documentPath).update({tampered: true}));
    await assertFails(admin.doc(documentPath).delete());
  }
  await assertFails(admin.doc("internalDiagnostics/new-root").set({
    tampered: true,
  }));
});

test("protected provider data remains unreadable even with an admin claim", async () => {
  const admin = testEnv.authenticatedContext("admin-user", {admin: true})
    .firestore();

  await assertFails(admin.doc("translationCache/cache-a").get());
});
