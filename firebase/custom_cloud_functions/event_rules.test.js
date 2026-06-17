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

function eventData(overrides = {}) {
  return {
    status: "active",
    countryCode: "RU",
    cityKey: "moscow",
    startsAt: new Date("2026-06-20T15:00:00.000Z"),
    title: "Conversation club",
    description: "Practice English in a small offline group.",
    languageCode: "en",
    languageNameEn: "English",
    languageNameRu: "Английский",
    levelMin: "B1",
    levelMax: "C1",
    locationName: "Starbucks, Arbat",
    organizerId: "organizer",
    organizerDisplayName: "Organizer",
    organizerPhotoUrl: "https://cdn.example.com/organizer.jpg",
    participantsCount: 1,
    capacity: 10,
    chatId: "event-active-moscow",
    createdAt: new Date("2026-06-14T10:00:00.000Z"),
    updatedAt: new Date("2026-06-14T10:00:00.000Z"),
    ...overrides,
  };
}

function eventListQuery(db) {
  return db.collection("events")
    .where("status", "==", "active")
    .where("countryCode", "==", "RU")
    .where("cityKey", "==", "moscow")
    .where("startsAt", ">=", new Date("2026-06-20T00:00:00.000Z"))
    .where("startsAt", "<", new Date("2026-06-21T00:00:00.000Z"))
    .orderBy("startsAt", "asc")
    .limit(20);
}

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
    await db.doc("events/active-moscow").set(eventData());
    await db.doc("events/active-other-city").set(eventData({
      cityKey: "saint_petersburg",
      chatId: "event-active-other-city",
    }));
    await db.doc("events/active-outside-date").set(eventData({
      startsAt: new Date("2026-06-22T15:00:00.000Z"),
      chatId: "event-active-outside-date",
    }));
    await db.doc("events/canceled-moscow").set(eventData({
      status: "canceled",
      canceledAt: new Date("2026-06-15T10:00:00.000Z"),
      chatId: "event-canceled-moscow",
    }));
  });
});

test("authorized user can list active event discovery data", async () => {
  const user = testEnv.authenticatedContext("user-a");

  const snapshot = await assertSucceeds(
    eventListQuery(user.firestore()).get(),
  );

  assert.deepEqual(snapshot.docs.map((doc) => doc.id), ["active-moscow"]);
});

test("unauthenticated user cannot list active event discovery data", async () => {
  const guest = testEnv.unauthenticatedContext();

  await assertFails(eventListQuery(guest.firestore()).get());
});

test("authorized user cannot list events without an active status predicate", async () => {
  const db = testEnv.authenticatedContext("user-a").firestore();

  await assertFails(db.collection("events").get());
  await assertFails(
    db.collection("events")
      .where("countryCode", "==", "RU")
      .where("cityKey", "==", "moscow")
      .get(),
  );
});

test("authorized user cannot list non-active event statuses", async () => {
  const db = testEnv.authenticatedContext("user-a").firestore();

  await assertFails(
    db.collection("events")
      .where("status", "==", "canceled")
      .get(),
  );
  await assertFails(
    db.collection("events")
      .where("status", "!=", "canceled")
      .get(),
  );
  await assertFails(
    db.collection("events")
      .where("status", "in", ["active", "canceled"])
      .get(),
  );
});

test("direct event detail get remains separate from event list reads", async () => {
  const db = testEnv.authenticatedContext("user-a").firestore();

  await assertFails(db.doc("events/active-moscow").get());
  await assertFails(db.doc("events/canceled-moscow").get());
});
