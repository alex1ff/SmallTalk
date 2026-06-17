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
const eventCreateRequestId = "550e8400-e29b-41d4-a716-446655440000";
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

function participantData(overrides = {}) {
  return {
    userId: "user-a",
    displayName: "User A",
    photoUrl: "https://cdn.example.com/user-a.jpg",
    role: "participant",
    status: "active",
    joinedAt: new Date("2026-06-14T10:00:00.000Z"),
    leftAt: null,
    createdAt: new Date("2026-06-14T10:00:00.000Z"),
    updatedAt: new Date("2026-06-14T10:00:00.000Z"),
    ...overrides,
  };
}

function eventCreationCounterData(overrides = {}) {
  return {
    userId: "user-a",
    dayKeyUtc: "2026-06-16",
    count: 1,
    eventIds: ["editable-event"],
    requestEventIds: {
      [eventCreateRequestId]: "editable-event",
    },
    requestPayloadHashes: {
      [eventCreateRequestId]: "payload-hash",
    },
    windowStartAt: new Date("2026-06-16T00:00:00.000Z"),
    windowEndAt: new Date("2026-06-17T00:00:00.000Z"),
    createdAt: new Date("2026-06-16T10:00:00.000Z"),
    updatedAt: new Date("2026-06-16T10:00:00.000Z"),
    ...overrides,
  };
}

function eventCreateRequestData(overrides = {}) {
  return {
    userId: "user-a",
    createRequestId: eventCreateRequestId,
    eventId: "editable-event",
    payloadHash: "payload-hash",
    counterPath: "eventCreationCounters/user-a/days/20260616",
    dayKeyUtc: "2026-06-16",
    dailyCreation: {
      count: 1,
      dayKeyUtc: "2026-06-16",
      remaining: 4,
      resetAtUtc: "2026-06-17T00:00:00.000Z",
    },
    status: "created",
    createdAt: new Date("2026-06-16T10:00:00.000Z"),
    updatedAt: new Date("2026-06-16T10:00:00.000Z"),
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
    await db.doc("eventChats/canceled-editable-event").set(eventChatData({
      eventId: "canceled-editable-event",
    }));
    await db.doc("events/editable-event/participants/organizer").set(
      participantData({
        userId: "organizer",
        displayName: "Organizer",
        photoUrl: "https://cdn.example.com/organizer.jpg",
        role: "organizer",
      }),
    );
    await db.doc("events/editable-event/participants/user-a").set(
      participantData(),
    );
    await db.doc("events/editable-event/participants/user-left").set(
      participantData({
        userId: "user-left",
        displayName: "Left User",
        status: "left",
        leftAt: new Date("2026-06-15T10:00:00.000Z"),
      }),
    );
    await db.doc("events/editable-event/participants/malformed-owner").set(
      participantData({
        userId: "malformed-owner",
        displayName: "",
        status: "left",
        leftAt: new Date("2026-06-15T10:00:00.000Z"),
        privateEmail: "malformed-owner@example.com",
      }),
    );
    await db.doc("events/canceled-editable-event/participants/user-a").set(
      participantData(),
    );
    await db.doc("eventCreationCounters/user-a/days/20260616").set(
      eventCreationCounterData(),
    );
    await db.doc(
      `eventCreateRequests/user-a/requests/${eventCreateRequestId}`,
    ).set(eventCreateRequestData());
    await db.doc("adminFallbackProbe/probe").set({
      visibleToAdminFallback: true,
    });
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

test("authorized user can list active event participants for roster UI", async () => {
  const db = testEnv.authenticatedContext("viewer").firestore();

  const snapshot = await assertSucceeds(
    db.collection("events/editable-event/participants")
      .where("status", "==", "active")
      .limit(50)
      .get(),
  );

  assert.deepEqual(
    snapshot.docs.map((doc) => doc.id).sort(),
    ["organizer", "user-a"],
  );
});

test("participant roster queries must be scoped to active participant status", async () => {
  const db = testEnv.authenticatedContext("viewer").firestore();

  await assertFails(
    db.collection("events/editable-event/participants")
      .where("status", "==", "active")
      .get(),
  );
  await assertFails(
    db.collection("events/editable-event/participants")
      .where("status", "==", "active")
      .limit(51)
      .get(),
  );
  await assertFails(
    db.collection("events/editable-event/participants").get(),
  );
  await assertFails(
    db.collection("events/editable-event/participants")
      .where("role", "==", "participant")
      .limit(50)
      .get(),
  );
  await assertFails(
    db.collection("events/editable-event/participants")
      .where("status", "==", "left")
      .limit(50)
      .get(),
  );
});

test("participant get is limited to active roster docs and own membership state", async () => {
  const viewer = testEnv.authenticatedContext("viewer");
  const activeUser = testEnv.authenticatedContext("user-a");
  const leftUser = testEnv.authenticatedContext("user-left");
  const malformedOwner = testEnv.authenticatedContext("malformed-owner");
  const missingUser = testEnv.authenticatedContext("missing-user");

  await assertSucceeds(
    viewer.firestore().doc("events/editable-event/participants/user-a").get(),
  );
  await assertFails(
    viewer.firestore().doc("events/editable-event/participants/user-left").get(),
  );
  await assertSucceeds(
    activeUser.firestore().doc("events/editable-event/participants/user-a").get(),
  );
  await assertSucceeds(
    leftUser.firestore().doc("events/editable-event/participants/user-left").get(),
  );
  await assertFails(
    malformedOwner.firestore()
      .doc("events/editable-event/participants/malformed-owner")
      .get(),
  );

  const missingSnapshot = await assertSucceeds(
    missingUser.firestore()
      .doc("events/editable-event/participants/missing-user")
      .get(),
  );
  assert.equal(missingSnapshot.exists, false);
});

test("participant reads require auth and an active parent event", async () => {
  const guest = testEnv.unauthenticatedContext();
  const db = testEnv.authenticatedContext("user-a").firestore();

  await assertFails(
    guest.firestore().doc("events/editable-event/participants/user-a").get(),
  );
  await assertFails(
    guest.firestore()
      .collection("events/editable-event/participants")
      .where("status", "==", "active")
      .limit(50)
      .get(),
  );
  await assertFails(
    db.collection("events/canceled-editable-event/participants")
      .where("status", "==", "active")
      .limit(50)
      .get(),
  );
  await assertFails(
    db.doc("events/canceled-editable-event/participants/user-a").get(),
  );
});

test("active event chat metadata get is limited to active participants", async () => {
  const guest = testEnv.unauthenticatedContext();
  const participant = testEnv.authenticatedContext("user-a");
  const organizer = testEnv.authenticatedContext("organizer");
  const leftUser = testEnv.authenticatedContext("user-left");
  const otherUser = testEnv.authenticatedContext("other-user");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});
  const chatPath = "eventChats/editable-event";

  await assertSucceeds(participant.firestore().doc(chatPath).get());
  await assertSucceeds(organizer.firestore().doc(chatPath).get());
  await assertFails(guest.firestore().doc(chatPath).get());
  await assertFails(leftUser.firestore().doc(chatPath).get());
  await assertFails(otherUser.firestore().doc(chatPath).get());
  await assertFails(adminClient.firestore().doc(chatPath).get());
});

test("active event chat metadata cannot be listed or queried", async () => {
  const contexts = [
    testEnv.authenticatedContext("user-a"),
    testEnv.authenticatedContext("organizer"),
    testEnv.authenticatedContext("admin-user", {admin: true}),
  ];

  for (const context of contexts) {
    const db = context.firestore();
    await assertFails(db.collection("eventChats").get());
    await assertFails(
      db.collection("eventChats")
        .where("eventId", "==", "editable-event")
        .get(),
    );
  }
});

test("event chat message paths are not opened by metadata or admin fallback rules", async () => {
  const participant = testEnv.authenticatedContext("user-a");
  const nonparticipant = testEnv.authenticatedContext("other-user");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});
  const messagePath = "eventChats/editable-event/messages/message-1";

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(messagePath).set({
      senderId: "user-a",
      senderDisplayName: "User A",
      senderPhotoUrl: "https://cdn.example.com/user-a.jpg",
      text: "Hello",
      createdAt: new Date("2026-06-14T10:00:00.000Z"),
      deletedAt: null,
    });
  });

  await assertFails(participant.firestore().doc(messagePath).get());
  await assertFails(nonparticipant.firestore().doc(messagePath).get());
  await assertFails(adminClient.firestore().doc(messagePath).get());
});

test("active event chat metadata reads fail closed for invalid state", async () => {
  const user = testEnv.authenticatedContext("user-a");

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("events/missing-chat-event").set(eventData({
      chatId: "missing-chat-event",
    }));
    await db.doc("events/missing-chat-event/participants/user-a").set(
      participantData(),
    );

    await db.doc("events/mismatched-chat-metadata").set(eventData({
      chatId: "mismatched-chat-metadata",
    }));
    await db.doc("events/mismatched-chat-metadata/participants/user-a").set(
      participantData(),
    );
    await db.doc("eventChats/mismatched-chat-metadata").set(eventChatData({
      eventId: "other-event",
    }));

    await db.doc("events/mismatched-event-chat-id").set(eventData({
      chatId: "other-chat",
    }));
    await db.doc("events/mismatched-event-chat-id/participants/user-a").set(
      participantData(),
    );
    await db.doc("eventChats/mismatched-event-chat-id").set(eventChatData({
      eventId: "mismatched-event-chat-id",
    }));

    await db.doc("eventChats/orphan-chat").set(eventChatData({
      eventId: "orphan-chat",
    }));

    await db.doc("events/no-participant-chat").set(eventData({
      chatId: "no-participant-chat",
    }));
    await db.doc("eventChats/no-participant-chat").set(eventChatData({
      eventId: "no-participant-chat",
    }));
  });

  await assertFails(user.firestore().doc("eventChats/missing-chat-event").get());
  await assertFails(
    user.firestore().doc("eventChats/mismatched-chat-metadata").get(),
  );
  await assertFails(
    user.firestore().doc("eventChats/mismatched-event-chat-id").get(),
  );
  await assertFails(user.firestore().doc("eventChats/orphan-chat").get());
  await assertFails(
    user.firestore().doc("eventChats/no-participant-chat").get(),
  );
  await assertFails(
    user.firestore().doc("eventChats/canceled-editable-event").get(),
  );
});

test("clients cannot directly create event participant documents", async () => {
  const guest = testEnv.unauthenticatedContext();
  const user = testEnv.authenticatedContext("user-new");
  const organizer = testEnv.authenticatedContext("organizer");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});

  await assertFails(
    guest.firestore()
      .doc("events/editable-event/participants/guest-user")
      .set(participantData({userId: "guest-user"})),
  );
  await assertFails(
    user.firestore()
      .doc("events/editable-event/participants/user-new")
      .set(participantData({userId: "user-new"})),
  );
  await assertFails(
    user.firestore()
      .doc("events/editable-event/participants/other-user")
      .set(participantData({userId: "other-user"})),
  );
  await assertFails(
    organizer.firestore()
      .doc("events/editable-event/participants/organizer-extra")
      .set(participantData({
        userId: "organizer-extra",
        role: "organizer",
      })),
  );
  await assertFails(
    adminClient.firestore()
      .doc("events/editable-event/participants/admin-user")
      .set(participantData({userId: "admin-user"})),
  );
});

test("clients cannot directly update or replace event participant documents", async () => {
  const user = testEnv.authenticatedContext("user-a");
  const leftUser = testEnv.authenticatedContext("user-left");
  const organizer = testEnv.authenticatedContext("organizer");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});
  const participantRef = user.firestore()
    .doc("events/editable-event/participants/user-a");
  const leftParticipantRef = leftUser.firestore()
    .doc("events/editable-event/participants/user-left");

  await assertFails(participantRef.update({
    status: "left",
    leftAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));
  await assertFails(leftParticipantRef.update({
    status: "active",
    leftAt: null,
    joinedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));
  await assertFails(participantRef.set(participantData({
    displayName: "Replaced User",
  })));
  await assertFails(participantRef.set({
    photoUrl: null,
  }, {merge: true}));
  await assertFails(
    organizer.firestore()
      .doc("events/editable-event/participants/user-a")
      .update({role: "organizer"}),
  );
  await assertFails(
    adminClient.firestore()
      .doc("events/editable-event/participants/user-a")
      .update({displayName: "Admin Edited"}),
  );
});

test("clients cannot directly delete event participant documents", async () => {
  const user = testEnv.authenticatedContext("user-a");
  const leftUser = testEnv.authenticatedContext("user-left");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});

  await assertFails(
    user.firestore().doc("events/editable-event/participants/user-a").delete(),
  );
  await assertFails(
    leftUser.firestore()
      .doc("events/editable-event/participants/user-left")
      .delete(),
  );
  await assertFails(
    adminClient.firestore()
      .doc("events/editable-event/participants/user-a")
      .delete(),
  );
});

test("participant writes fail even when batched with allowed event edits", async () => {
  const organizer = testEnv.authenticatedContext("organizer");
  const db = organizer.firestore();
  const batch = db.batch();

  batch.update(db.doc("events/editable-event"), directEditPatch());
  batch.update(db.doc("events/editable-event/participants/user-a"), {
    status: "left",
    leftAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  });

  await assertFails(batch.commit());
});

test("clients cannot directly read event creation counters", async () => {
  const contexts = [
    testEnv.unauthenticatedContext(),
    testEnv.authenticatedContext("user-a"),
    testEnv.authenticatedContext("other-user"),
    testEnv.authenticatedContext("admin-user", {admin: true}),
  ];

  for (const context of contexts) {
    const db = context.firestore();
    await assertFails(
      db.doc("eventCreationCounters/user-a").get(),
    );
    await assertFails(
      db.doc("eventCreationCounters/user-a/days/20260616").get(),
    );
    await assertFails(
      db.doc(
        "eventCreationCounters/user-a/days/20260616/audit/log-entry",
      ).get(),
    );
    await assertFails(
      db.collection("eventCreationCounters/user-a/days").get(),
    );
    await assertFails(
      db.collection("eventCreationCounters").get(),
    );
    await assertFails(
      db.collectionGroup("days").get(),
    );
  }

  await assertFails(
    testEnv.authenticatedContext("admin-user", {admin: true})
      .firestore()
      .doc("eventCreationCounters/user-a/days/20990101")
      .get(),
  );
});

test("clients cannot directly write event creation counters", async () => {
  const guest = testEnv.unauthenticatedContext();
  const user = testEnv.authenticatedContext("user-a");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});
  const counterRef = user.firestore()
    .doc("eventCreationCounters/user-a/days/20260616");
  const adminDb = adminClient.firestore();

  await assertFails(
    guest.firestore()
      .doc("eventCreationCounters/user-a/days/20260617")
      .set(eventCreationCounterData({dayKeyUtc: "2026-06-17"})),
  );
  await assertFails(
    user.firestore()
      .doc("eventCreationCounters/user-a/days/20260617")
      .set(eventCreationCounterData({dayKeyUtc: "2026-06-17"})),
  );
  await assertFails(
    user.firestore()
      .collection("eventCreationCounters/user-a/days")
      .add(eventCreationCounterData({dayKeyUtc: "2026-06-17"})),
  );
  await assertFails(counterRef.update({
    count: 2,
    updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));
  await assertFails(counterRef.set({
    count: 2,
  }, {merge: true}));
  await assertFails(
    user.firestore()
      .doc("eventCreationCounters/user-a")
      .set({
        userId: "user-a",
      }),
  );
  await assertFails(
    user.firestore()
      .doc("eventCreationCounters/user-a/days/20260616/audit/log-entry")
      .set({
        count: 3,
      }),
  );
  await assertFails(
    adminDb.doc("eventCreationCounters/user-a/days/20260618")
      .set(eventCreationCounterData({dayKeyUtc: "2026-06-18"})),
  );
  await assertFails(adminDb
    .doc("eventCreationCounters/user-a/days/20260616")
    .set({
      count: 3,
    }, {merge: true}),
  );
  await assertFails(adminDb
    .doc("eventCreationCounters/user-a/days/20260616")
    .update({
      count: 3,
      updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    }),
  );
  await assertFails(
    adminDb.doc("eventCreationCounters/user-a/days/20260616").delete(),
  );
});

test("clients cannot directly read event create request markers", async () => {
  const markerPath =
    `eventCreateRequests/user-a/requests/${eventCreateRequestId}`;
  const contexts = [
    testEnv.unauthenticatedContext(),
    testEnv.authenticatedContext("user-a"),
    testEnv.authenticatedContext("other-user"),
    testEnv.authenticatedContext("admin-user", {admin: true}),
  ];

  for (const context of contexts) {
    const db = context.firestore();
    await assertFails(db.doc("eventCreateRequests/user-a").get());
    await assertFails(db.doc(markerPath).get());
    await assertFails(
      db.doc(`${markerPath}/audit/log-entry`).get(),
    );
    await assertFails(
      db.collection("eventCreateRequests/user-a/requests").get(),
    );
    await assertFails(
      db.collection("eventCreateRequests").get(),
    );
    await assertFails(
      db.collectionGroup("requests").get(),
    );
  }

  await assertFails(
    testEnv.authenticatedContext("admin-user", {admin: true})
      .firestore()
      .doc("eventCreateRequests/user-a/requests/00000000-0000-4000-8000-000000000000")
      .get(),
  );
});

test("clients cannot directly write event create request markers", async () => {
  const guest = testEnv.unauthenticatedContext();
  const user = testEnv.authenticatedContext("user-a");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});
  const markerPath =
    `eventCreateRequests/user-a/requests/${eventCreateRequestId}`;
  const markerRef = user.firestore().doc(markerPath);
  const adminDb = adminClient.firestore();
  const nextRequestId = "650e8400-e29b-41d4-a716-446655440001";
  const adminRequestId = "750e8400-e29b-41d4-a716-446655440002";

  await assertFails(
    guest.firestore()
      .doc(`eventCreateRequests/user-a/requests/${nextRequestId}`)
      .set(eventCreateRequestData({createRequestId: nextRequestId})),
  );
  await assertFails(
    user.firestore()
      .doc(`eventCreateRequests/user-a/requests/${nextRequestId}`)
      .set(eventCreateRequestData({createRequestId: nextRequestId})),
  );
  await assertFails(
    user.firestore()
      .collection("eventCreateRequests/user-a/requests")
      .add(eventCreateRequestData({createRequestId: nextRequestId})),
  );
  await assertFails(markerRef.update({
    status: "conflict",
    updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));
  await assertFails(markerRef.set({
    payloadHash: "changed-hash",
  }, {merge: true}));
  await assertFails(
    user.firestore()
      .doc("eventCreateRequests/user-a")
      .set({
        userId: "user-a",
      }),
  );
  await assertFails(
    user.firestore()
      .doc(`${markerPath}/audit/log-entry`)
      .set({
        status: "created",
      }),
  );
  await assertFails(
    adminDb.doc(`eventCreateRequests/user-a/requests/${adminRequestId}`)
      .set(eventCreateRequestData({createRequestId: adminRequestId})),
  );
  await assertFails(adminDb.doc(markerPath).set({
    payloadHash: "changed-hash",
  }, {merge: true}));
  await assertFails(adminDb.doc(markerPath).update({
    status: "conflict",
    updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));
  await assertFails(
    adminDb.doc(markerPath).delete(),
  );
});

test("event create bookkeeping writes fail inside otherwise allowed batches", async () => {
  const organizer = testEnv.authenticatedContext("organizer");
  const db = organizer.firestore();
  const batch = db.batch();

  batch.update(db.doc("events/editable-event"), directEditPatch());
  batch.update(db.doc("eventCreationCounters/user-a/days/20260616"), {
    count: 2,
    updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  });

  await assertFails(batch.commit());
});

test("event create request marker writes fail inside otherwise allowed batches", async () => {
  const organizer = testEnv.authenticatedContext("organizer");
  const db = organizer.firestore();
  const batch = db.batch();

  batch.update(db.doc("events/editable-event"), directEditPatch());
  batch.update(
    db.doc(`eventCreateRequests/user-a/requests/${eventCreateRequestId}`),
    {
      status: "conflict",
      updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    },
  );

  await assertFails(batch.commit());
});

test("event bookkeeping exclusions preserve unrelated admin fallback reads", async () => {
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});
  const regularUser = testEnv.authenticatedContext("user-a");

  await assertSucceeds(
    adminClient.firestore().doc("adminFallbackProbe/probe").get(),
  );
  await assertFails(
    regularUser.firestore().doc("adminFallbackProbe/probe").get(),
  );
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
  for (const field of Object.keys(protectedSamples)) {
    await assertFails(eventRef.update({
      ...directEditPatch(),
      [field]: firebaseCompat.firestore.FieldValue.delete(),
    }));
  }
  await assertFails(eventRef.update({
    ...directEditPatch(),
    createdAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));
  await assertFails(eventRef.update({
    ...directEditPatch(),
    canceledAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));
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
  await assertFails(eventRef.update({
    title: "Updated without timestamp",
  }));
  await assertFails(eventRef.update({
    title: "Updated without valid timestamp",
    updatedAt: firebaseCompat.firestore.FieldValue.delete(),
  }));
  await assertFails(eventRef.update({
    updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  }));
});

test("admin claim client cannot bypass protected event edit rules", async () => {
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});
  const organizerAdminClient = testEnv.authenticatedContext("organizer", {admin: true});

  await assertFails(
    adminClient.firestore().doc("events/editable-event").update(directEditPatch()),
  );
  await assertFails(
    organizerAdminClient.firestore().doc("events/editable-event").update({
      ...directEditPatch(),
      participantsCount: 4,
    }),
  );
});

test("client set cannot replace existing event with protected field changes", async () => {
  const organizer = testEnv.authenticatedContext("organizer");
  const eventRef = organizer.firestore().doc("events/editable-event");
  const replacement = eventData({
    startsAt: farFutureStartsAt,
    participantsCount: 4,
    capacity: 8,
    chatId: "replaced-chat",
    updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
  });

  await assertFails(
    eventRef.set(replacement),
  );
  await assertFails(
    eventRef.set({
      ...directEditPatch({
        startsAt: farFutureStartsAt,
      }),
    }),
  );
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
