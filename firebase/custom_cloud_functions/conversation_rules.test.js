const test = require("node:test");
const assert = require("node:assert/strict");
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
    await db.doc("conversations/user-a_user-b").set({
      pairId: "user-a_user-b",
      participantIds: ["user-a", "user-b"],
      participantMap: {
        "user-a": true,
        "user-b": true,
      },
      participantRefs: [
        db.doc("users/user-a"),
        db.doc("users/user-b"),
      ],
      isUnlocked: true,
      lastMessageAt: new Date("2026-05-02T10:00:00.000Z"),
    });
    await db.doc("conversations/user-b_user-c").set({
      pairId: "user-b_user-c",
      participantIds: ["user-b", "user-c"],
      participantMap: {
        "user-b": true,
        "user-c": true,
      },
      participantRefs: [
        db.doc("users/user-b"),
        db.doc("users/user-c"),
      ],
      isUnlocked: true,
      lastMessageAt: new Date("2026-05-02T10:01:00.000Z"),
    });
    await db.doc("conversations/user-a_user-b/messages/message-1").set({
      senderId: "user-a",
      senderRef: db.doc("users/user-a"),
      type: "text",
      text: "hello",
      createdAt: new Date("2026-05-02T10:00:00.000Z"),
    });
  });
});

test("participant can list inbox with participantMap equality query", async () => {
  const user = testEnv.authenticatedContext("user-a");
  const snapshot = await assertSucceeds(
    user.firestore()
      .collection("conversations")
      .where("participantMap.user-a", "==", true)
      .get(),
  );

  assert.equal(snapshot.size, 1);
  assert.equal(snapshot.docs[0].id, "user-a_user-b");
});

test("participant can read messages in an unlocked conversation", async () => {
  const user = testEnv.authenticatedContext("user-a");

  await assertSucceeds(
    user.firestore()
      .collection("conversations/user-a_user-b/messages")
      .get(),
  );
});

test("non-participant cannot get another conversation", async () => {
  const user = testEnv.authenticatedContext("user-a");

  await assertFails(
    user.firestore().doc("conversations/user-b_user-c").get(),
  );
});
