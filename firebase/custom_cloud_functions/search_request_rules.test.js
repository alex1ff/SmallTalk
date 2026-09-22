const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");

const projectId = process.env.GCLOUD_PROJECT || "demo-smalltalk";
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
    await db.doc("searchRequests/student-a").set({
      requestId: "request-a",
      userId: "student-a",
      userRef: db.doc("users/student-a"),
      role: "student",
      language: "en",
      filters: {
        preferredLevel: "B1",
        levelRank: 3,
        countryCode: "US",
        cityKey: "new_york",
      },
      status: "active",
      appState: "foreground",
      appStateUpdatedAt: new Date("2026-06-20T10:00:00.000Z"),
      createdAt: new Date("2026-06-20T10:00:00.000Z"),
      updatedAt: new Date("2026-06-20T10:00:00.000Z"),
      heartbeatAt: new Date("2026-06-20T10:00:00.000Z"),
      expiresAt: new Date("2026-06-20T10:10:00.000Z"),
      backgroundExpiresAt: null,
      currentSessionId: null,
      matchedUserId: null,
      matchedRole: null,
      pairAttemptId: null,
      excludedCandidateIds: [],
      attemptExcludedCandidateIds: [],
      lockOwner: null,
      lockExpiresAt: null,
      version: 1,
      stopReason: null,
      stoppedAt: null,
      lastError: null,
    });
  });
});

test("search request owner can get only their own active request", async () => {
  const owner = testEnv.authenticatedContext("student-a");
  const other = testEnv.authenticatedContext("student-b");
  const guest = testEnv.unauthenticatedContext();

  await assertSucceeds(owner.firestore().doc("searchRequests/student-a").get());
  await assertFails(other.firestore().doc("searchRequests/student-a").get());
  await assertFails(guest.firestore().doc("searchRequests/student-a").get());
});

test("search requests cannot be listed by clients or admin fallback", async () => {
  const owner = testEnv.authenticatedContext("student-a");
  const admin = testEnv.authenticatedContext("admin-user", {admin: true});

  await assertFails(owner.firestore().collection("searchRequests").get());
  await assertFails(admin.firestore().collection("searchRequests").get());
});

test("search requests are server-owned and cannot be written by clients", async () => {
  const owner = testEnv.authenticatedContext("student-a");
  const admin = testEnv.authenticatedContext("admin-user", {admin: true});
  const ownerRef = owner.firestore().doc("searchRequests/student-a");
  const newOwnerRef = owner.firestore().doc("searchRequests/student-new");

  await assertFails(newOwnerRef.set({status: "active"}));
  await assertFails(ownerRef.update({status: "stopped"}));
  await assertFails(ownerRef.delete());
  await assertFails(admin.firestore().doc("searchRequests/student-a").update({
    status: "stopped",
  }));
});

test("admin can get an individual search request for support diagnostics", async () => {
  const admin = testEnv.authenticatedContext("admin-user", {admin: true});

  await assertSucceeds(admin.firestore().doc("searchRequests/student-a").get());
});

test("passive queue permits only owner get; consent and deliveries stay server-only", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("passiveSearches/student-a").set({userId: "student-a", status: "waiting"});
    await db.doc("passiveSearchOperations/consent-a").set({userId: "student-a"});
    await db.doc("passiveSearchDeliveries/delivery-a").set({recipientId: "student-a"});
  });
  const owner = testEnv.authenticatedContext("student-a").firestore();
  const other = testEnv.authenticatedContext("student-b").firestore();
  const adminClient = testEnv.authenticatedContext("admin", {admin: true}).firestore();
  await assertSucceeds(owner.doc("passiveSearches/student-a").get());
  await assertFails(other.doc("passiveSearches/student-a").get());
  await assertFails(testEnv.unauthenticatedContext().firestore().doc("passiveSearches/student-a").get());
  for (const db of [owner, other, adminClient]) {
    await assertFails(db.collection("passiveSearches").get());
    await assertFails(db.doc("passiveSearches/student-a").set({userId: "student-b"}));
    await assertFails(db.doc("passiveSearches/student-a").update({status: "matched"}));
    await assertFails(db.doc("passiveSearches/student-a").delete());
    for (const path of ["passiveSearchOperations/consent-a", "passiveSearchDeliveries/delivery-a"]) {
      await assertFails(db.doc(path).get());
      await assertFails(db.doc(path).set({status: "matched"}));
      await assertFails(db.doc(path).update({status: "matched"}));
      await assertFails(db.doc(path).delete());
    }
  }
});
