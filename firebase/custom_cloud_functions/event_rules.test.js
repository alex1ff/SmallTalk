const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const firebaseCompat = require("firebase/compat/app");

require("firebase/compat/firestore");

const projectId = process.env.GCLOUD_PROJECT || "demo-smalltalk";
const firestoreHostRaw = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const [firestoreHost, firestorePortStr] = firestoreHostRaw.split(":");
const firestorePort = Number.parseInt(firestorePortStr || "8080", 10);
const firestoreRules = fs.readFileSync(
  path.join(__dirname, "..", "firestore.rules"),
  "utf8",
);

let testEnv;

const farFutureStartsAt = new Date("2099-06-20T15:00:00.000Z");
const farFutureEditStartsAt = new Date("2099-06-21T15:00:00.000Z");
const disallowedEventStatuses = [
  "draft",
  "past",
  "completed",
  "deleted",
  "archived",
  "cancelled",
  "unknown",
];

function eventData(overrides = {}) {
  return {
    status: "active",
    countryCode: "RU",
    cityKey: "moscow",
    cityNameRu: "Москва",
    cityNameEn: "Moscow",
    cityDisplayContext: "Россия",
    startsAt: new Date("2026-06-20T15:00:00.000Z"),
    title: "Conversation club",
    description: "Practice English in a small offline group.",
    languageCode: "en",
    languageNameEn: "English",
    languageNameRu: "Английский",
    levelMin: "B1",
    levelMax: "C1",
    locationName: "Starbucks, Arbat",
    locationGeoPoint: null,
    organizerId: "organizer",
    organizerDisplayName: "Organizer",
    organizerPhotoUrl: "https://cdn.example.com/organizer.jpg",
    participantsCount: 1,
    capacity: 10,
    chatId: "event-active-moscow",
    timeZoneId: "Europe/Moscow",
    createdAt: new Date("2026-06-14T10:00:00.000Z"),
    updatedAt: new Date("2026-06-14T10:00:00.000Z"),
    canceledAt: null,
    ...overrides,
  };
}

function directEditPatch(overrides = {}) {
  return {
    title: "Updated conversation club",
    description: "Updated practice plan.",
    levelMin: "A2",
    levelMax: "B2",
    locationName: "Updated cafe",
    locationGeoPoint: new firebaseCompat.firestore.GeoPoint(55.751244, 37.618423),
    startsAt: farFutureEditStartsAt,
    capacity: 3,
    updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    ...overrides,
  };
}

function directCancelPatch(overrides = {}) {
  return {
    status: "canceled",
    canceledAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    ...overrides,
  };
}

function eventChatData(overrides = {}) {
  return {
    eventId: "editable-event",
    readAccessUserIds: ["organizer", "user-a"],
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
    await db.doc("events/editable-event").set(eventData({
      startsAt: farFutureStartsAt,
      participantsCount: 3,
      capacity: 8,
      chatId: "editable-event",
    }));
    await db.doc("events/canceled-editable-event").set(eventData({
      status: "canceled",
      canceledAt: new Date("2099-06-01T10:00:00.000Z"),
      startsAt: farFutureStartsAt,
      participantsCount: 3,
      capacity: 8,
      chatId: "canceled-editable-event",
    }));
    await db.doc("events/past-editable-event").set(eventData({
      startsAt: new Date("2020-06-20T15:00:00.000Z"),
      participantsCount: 3,
      capacity: 8,
      chatId: "past-editable-event",
    }));
    await db.doc("eventChats/editable-event").set(eventChatData());
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

test("clients cannot directly create event documents", async () => {
  const guest = testEnv.unauthenticatedContext();
  const user = testEnv.authenticatedContext("user-a");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});

  await assertFails(
    guest.firestore().doc("events/direct-create-guest").set(eventData({
      chatId: "direct-create-guest",
    })),
  );
  await assertFails(
    user.firestore().doc("events/direct-create-user").set(eventData({
      chatId: "direct-create-user",
    })),
  );
  await assertFails(
    adminClient.firestore().doc("events/direct-create-admin").set(eventData({
      chatId: "direct-create-admin",
    })),
  );
  await assertFails(
    user.firestore().collection("events").add(eventData({
      chatId: "direct-create-auto-id",
    })),
  );
});

test("organizer can directly edit validated safe event fields", async () => {
  const organizer = testEnv.authenticatedContext("organizer");

  await assertSucceeds(
    organizer.firestore().doc("events/editable-event").update(directEditPatch()),
  );
});

test("guest and non-organizer cannot directly edit event fields", async () => {
  const guest = testEnv.unauthenticatedContext();
  const user = testEnv.authenticatedContext("user-a");

  await assertFails(
    guest.firestore().doc("events/editable-event").update(directEditPatch()),
  );
  await assertFails(
    user.firestore().doc("events/editable-event").update(directEditPatch()),
  );
  await assertFails(
    user.firestore().doc("events/editable-event").update({
      ...directEditPatch(),
      organizerId: "user-a",
    }),
  );
});

test("organizer cannot directly edit canceled or past events", async () => {
  const organizer = testEnv.authenticatedContext("organizer");

  await assertFails(
    organizer.firestore()
      .doc("events/canceled-editable-event")
      .update(directEditPatch()),
  );
  await assertFails(
    organizer.firestore()
      .doc("events/past-editable-event")
      .update(directEditPatch()),
  );
});

test("direct organizer edit enforces capacity and server updatedAt", async () => {
  const organizer = testEnv.authenticatedContext("organizer");
  const eventRef = organizer.firestore().doc("events/editable-event");

  await assertSucceeds(eventRef.update(directEditPatch({capacity: 3})));
  await assertFails(eventRef.update(directEditPatch({capacity: 2})));
  await assertFails(eventRef.update(directEditPatch({
    updatedAt: new Date("2099-06-20T10:00:00.000Z"),
  })));
});

test("direct organizer edit cannot mutate protected or catalog-derived fields", async () => {
  const organizer = testEnv.authenticatedContext("organizer");
  const eventRef = organizer.firestore().doc("events/editable-event");
  const protectedSamples = {
    organizerId: "other-organizer",
    organizerDisplayName: "Other Organizer",
    organizerPhotoUrl: "https://cdn.example.com/other.jpg",
    participantsCount: 4,
    chatId: "other-chat",
    status: "canceled",
    createdAt: new Date("2099-06-20T10:00:00.000Z"),
    canceledAt: new Date("2099-06-20T10:00:00.000Z"),
    languageCode: "it",
    languageNameEn: "Italian",
    languageNameRu: "Итальянский",
    countryCode: "IT",
    cityKey: "rome",
    cityNameRu: "Рим",
    cityNameEn: "Rome",
    cityDisplayContext: "Италия",
    timeZoneId: "Europe/Rome",
  };

  for (const [field, value] of Object.entries(protectedSamples)) {
    await assertFails(eventRef.update({
      ...directEditPatch(),
      [field]: value,
    }));
  }
});

test("direct organizer edit rejects unknown fields and field deletion", async () => {
  const organizer = testEnv.authenticatedContext("organizer");
  const eventRef = organizer.firestore().doc("events/editable-event");

  await assertFails(eventRef.update({
    ...directEditPatch(),
    unexpectedField: true,
  }));
  await assertFails(eventRef.update({
    title: firebaseCompat.firestore.FieldValue.delete(),
    updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));
});

test("direct organizer edit validates editable field values", async () => {
  const organizer = testEnv.authenticatedContext("organizer");
  const eventRef = organizer.firestore().doc("events/editable-event");
  const invalidPatches = [
    {title: ""},
    {title: "x".repeat(71)},
    {description: ""},
    {description: "x".repeat(1001)},
    {levelMin: "C1", levelMax: "B1"},
    {levelMin: "A0"},
    {locationName: ""},
    {locationName: "x".repeat(201)},
    {locationGeoPoint: "not-a-geopoint"},
    {startsAt: new Date("2020-06-20T15:00:00.000Z")},
    {capacity: 51},
  ];

  for (const patch of invalidPatches) {
    await assertFails(eventRef.update(directEditPatch(patch)));
  }

  await assertSucceeds(eventRef.update(directEditPatch({
    locationGeoPoint: null,
  })));
});

test("clients cannot directly cancel event documents", async () => {
  const guest = testEnv.unauthenticatedContext();
  const user = testEnv.authenticatedContext("user-a");
  const organizer = testEnv.authenticatedContext("organizer");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});

  await assertFails(
    guest.firestore().doc("events/editable-event").update(directCancelPatch()),
  );
  await assertFails(
    user.firestore().doc("events/editable-event").update(directCancelPatch()),
  );
  await assertFails(
    adminClient.firestore().doc("events/editable-event").update(directCancelPatch()),
  );
  await assertFails(
    organizer.firestore().doc("events/editable-event").update(directCancelPatch()),
  );
  await assertFails(
    organizer.firestore().doc("events/editable-event").update({
      ...directEditPatch(),
      ...directCancelPatch(),
    }),
  );
});

test("client cancel cannot be paired with event chat access snapshot writes", async () => {
  const organizer = testEnv.authenticatedContext("organizer");
  const db = organizer.firestore();
  const batch = db.batch();

  await assertFails(db.doc("eventChats/editable-event").update({
    readAccessUserIds: ["organizer", "user-a"],
    updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));

  batch.update(db.doc("events/editable-event"), directCancelPatch());
  batch.update(db.doc("eventChats/editable-event"), {
    readAccessUserIds: ["organizer", "user-a"],
    updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  });

  await assertFails(batch.commit());
});

test("clients cannot hard delete active or canceled event documents", async () => {
  const contexts = [
    testEnv.unauthenticatedContext(),
    testEnv.authenticatedContext("user-a"),
    testEnv.authenticatedContext("organizer"),
    testEnv.authenticatedContext("admin-user", {admin: true}),
  ];
  const eventPaths = [
    "events/editable-event",
    "events/canceled-editable-event",
  ];

  for (const context of contexts) {
    for (const eventPath of eventPaths) {
      await assertFails(context.firestore().doc(eventPath).delete());
    }
  }
});

test("client hard delete cannot be batched with event chat deletion", async () => {
  const organizer = testEnv.authenticatedContext("organizer");
  const db = organizer.firestore();
  const batch = db.batch();

  batch.delete(db.doc("events/editable-event"));
  batch.delete(db.doc("eventChats/editable-event"));

  await assertFails(batch.commit());
});

test("client-created event statuses outside MVP allowlist are denied", async () => {
  const user = testEnv.authenticatedContext("user-a");

  for (const status of disallowedEventStatuses) {
    await assertFails(
      user.firestore().doc(`events/direct-create-${status}`).set(eventData({
        status,
        chatId: `direct-create-${status}`,
      })),
    );
  }
});

test("client updates cannot set event status outside MVP allowlist", async () => {
  const organizer = testEnv.authenticatedContext("organizer");
  const eventRef = organizer.firestore().doc("events/editable-event");

  for (const status of disallowedEventStatuses) {
    await assertFails(eventRef.update(directEditPatch({status})));
  }
  await assertFails(eventRef.update(directEditPatch({status: null})));
  await assertFails(eventRef.update({
    ...directEditPatch(),
    status: firebaseCompat.firestore.FieldValue.delete(),
  }));
});

test("client updates cannot restore canceled events to active", async () => {
  const organizer = testEnv.authenticatedContext("organizer");

  await assertFails(
    organizer.firestore().doc("events/canceled-editable-event").update({
      status: "active",
      canceledAt: null,
      updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    }),
  );
});
