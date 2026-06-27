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

const {
  __private__: {
    EVENT_CHAT_MESSAGE_TOMBSTONE_TEXT,
    tombstoneEventChatMessage,
  },
} = require("./send_event_chat_message");

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
  "rescheduled",
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

function eventChatMessageData(overrides = {}) {
  return {
    senderId: "user-a",
    senderDisplayName: "User A",
    senderPhotoUrl: "https://cdn.example.com/user-a.jpg",
    text: "Hello",
    createdAt: new Date("2026-06-14T10:00:00.000Z"),
    deletedAt: null,
    ...overrides,
  };
}

function boundedEventChatMessagesQuery(db, chatId = "editable-event") {
  return db.collection(`eventChats/${chatId}/messages`)
    .orderBy("createdAt", "desc")
    .orderBy(firebaseCompat.firestore.FieldPath.documentId(), "desc")
    .limit(50);
}

function eventChatWriteActors() {
  return [
    {name: "guest", context: testEnv.unauthenticatedContext()},
    {name: "participant", context: testEnv.authenticatedContext("user-a")},
    {name: "organizer", context: testEnv.authenticatedContext("organizer")},
    {
      name: "left-before-cancel",
      context: testEnv.authenticatedContext("user-left"),
    },
    {
      name: "nonparticipant",
      context: testEnv.authenticatedContext("other-user"),
    },
    {
      name: "admin",
      context: testEnv.authenticatedContext("admin-user", {admin: true}),
    },
  ];
}

async function seedLeftBeforeCancelParticipant(db, eventId) {
  await db.doc(`events/${eventId}/participants/user-left`).set(
    participantData({
      userId: "user-left",
      displayName: "Left User",
      status: "left",
      leftAt: new Date("2099-06-01T09:59:59.000Z"),
    }),
  );
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
    await db.doc("events/capacity-bounds-event").set(eventData({
      startsAt: farFutureStartsAt,
      participantsCount: 2,
      capacity: 8,
      chatId: "capacity-bounds-event",
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
    await db.doc("events/editable-event/participants/invalid-status").set(
      participantData({
        userId: "invalid-status",
        displayName: "Invalid Status",
        status: "pending",
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

test("authorized user can get active event detail directly", async () => {
  const db = testEnv.authenticatedContext("user-a").firestore();

  await assertSucceeds(db.doc("events/active-moscow").get());
});

test("unauthenticated user cannot get event detail directly", async () => {
  const db = testEnv.unauthenticatedContext().firestore();

  await assertFails(db.doc("events/active-moscow").get());
});

test("canceled event detail is limited to organizer and active participants", async () => {
  await assertSucceeds(
    testEnv
      .authenticatedContext("organizer")
      .firestore()
      .doc("events/canceled-editable-event")
      .get(),
  );
  await assertSucceeds(
    testEnv
      .authenticatedContext("user-a")
      .firestore()
      .doc("events/canceled-editable-event")
      .get(),
  );
  await assertFails(
    testEnv
      .authenticatedContext("other-user")
      .firestore()
      .doc("events/canceled-editable-event")
      .get(),
  );
  await assertFails(
    testEnv
      .authenticatedContext("user-left")
      .firestore()
      .doc("events/canceled-editable-event")
      .get(),
  );
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
  const invalidStatusUser = testEnv.authenticatedContext("invalid-status");
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
  await assertFails(
    viewer.firestore()
      .doc("events/editable-event/participants/invalid-status")
      .get(),
  );
  await assertFails(
    invalidStatusUser.firestore()
      .doc("events/editable-event/participants/invalid-status")
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

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(chatPath).update({
      readAccessUserIds: ["organizer", "user-a", "user-left"],
    });
  });

  await assertSucceeds(participant.firestore().doc(chatPath).get());
  await assertSucceeds(organizer.firestore().doc(chatPath).get());
  await assertFails(guest.firestore().doc(chatPath).get());
  await assertFails(leftUser.firestore().doc(chatPath).get());
  await assertFails(otherUser.firestore().doc(chatPath).get());
  await assertFails(adminClient.firestore().doc(chatPath).get());
});

test("canceled event chat metadata get is limited to frozen read access", async () => {
  const guest = testEnv.unauthenticatedContext();
  const participantAtCancel = testEnv.authenticatedContext("user-a");
  const organizer = testEnv.authenticatedContext("organizer");
  const leftBeforeCancel = testEnv.authenticatedContext("user-left");
  const otherUser = testEnv.authenticatedContext("other-user");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});
  const chatPath = "eventChats/canceled-editable-event";

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore()
      .doc("events/canceled-editable-event/participants/user-left")
      .set(participantData({
        userId: "user-left",
        displayName: "Left User",
        status: "left",
        leftAt: new Date("2099-06-01T09:59:59.000Z"),
      }));
  });

  await assertSucceeds(participantAtCancel.firestore().doc(chatPath).get());
  await assertSucceeds(organizer.firestore().doc(chatPath).get());
  await assertFails(guest.firestore().doc(chatPath).get());
  await assertFails(leftBeforeCancel.firestore().doc(chatPath).get());
  await assertFails(otherUser.firestore().doc(chatPath).get());
  await assertFails(adminClient.firestore().doc(chatPath).get());
});

test("canceled event chat stays readable for organizer and cancellation snapshot participants",
  async () => {
    const chatId = "canceled-readable-snapshot";
    const messageId = "message-1";
    const contexts = [
      testEnv.authenticatedContext("organizer"),
      testEnv.authenticatedContext("user-a"),
    ];

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc(`events/${chatId}`).set(eventData({
        status: "canceled",
        canceledAt: new Date("2099-06-01T10:00:00.000Z"),
        chatId,
      }));
      await db.doc(`eventChats/${chatId}`).set(eventChatData({
        eventId: chatId,
        readAccessUserIds: ["organizer", "user-a"],
      }));
      await db.doc(`eventChats/${chatId}/messages/${messageId}`).set(
        eventChatMessageData(),
      );
    });

    for (const context of contexts) {
      const db = context.firestore();
      const chatSnapshot = await assertSucceeds(
        db.doc(`eventChats/${chatId}`).get(),
      );
      const messageSnapshot = await assertSucceeds(
        db.doc(`eventChats/${chatId}/messages/${messageId}`).get(),
      );
      const listSnapshot = await assertSucceeds(
        boundedEventChatMessagesQuery(db, chatId).get(),
      );

      assert.equal(chatSnapshot.exists, true);
      assert.equal(messageSnapshot.exists, true);
      assert.deepEqual(
        listSnapshot.docs.map((snapshot) => snapshot.id),
        [messageId],
      );
    }
  });

test("canceled event chat stays readable after an eligible participant later left",
  async () => {
    const chatId = "canceled-left-after-readable";
    const messageId = "message-1";
    const user = testEnv.authenticatedContext("user-left-after");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc(`events/${chatId}`).set(eventData({
        status: "canceled",
        canceledAt: new Date("2099-06-01T10:00:00.000Z"),
        chatId,
      }));
      await db.doc(`events/${chatId}/participants/user-left-after`).set(
        participantData({
          userId: "user-left-after",
          displayName: "Left After",
          status: "left",
          leftAt: new Date("2099-06-01T10:00:01.000Z"),
        }),
      );
      await db.doc(`eventChats/${chatId}`).set(eventChatData({
        eventId: chatId,
        readAccessUserIds: ["user-left-after"],
      }));
      await db.doc(`eventChats/${chatId}/messages/${messageId}`).set(
        eventChatMessageData(),
      );
    });

    const db = user.firestore();
    const chatSnapshot = await assertSucceeds(
      db.doc(`eventChats/${chatId}`).get(),
    );
    const messageSnapshot = await assertSucceeds(
      db.doc(`eventChats/${chatId}/messages/${messageId}`).get(),
    );
    const listSnapshot = await assertSucceeds(
      boundedEventChatMessagesQuery(db, chatId).get(),
    );

    assert.equal(chatSnapshot.exists, true);
    assert.equal(messageSnapshot.exists, true);
    assert.deepEqual(
      listSnapshot.docs.map((snapshot) => snapshot.id),
      [messageId],
    );
  });

test("canceled event chat reads are not granted to participants added after cancellation",
  async () => {
    const chatId = "canceled-joined-after";
    const messageId = "message-1";
    const canceledAt = new Date("2099-06-01T10:00:00.000Z");
    const joinedAfterCancel = testEnv.authenticatedContext(
      "joined-after-cancel",
    );
    const snapshotReader = testEnv.authenticatedContext("user-a");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc(`events/${chatId}`).set(eventData({
        status: "canceled",
        canceledAt,
        chatId,
      }));
      await db.doc(`events/${chatId}/participants/joined-after-cancel`).set(
        participantData({
          userId: "joined-after-cancel",
          displayName: "Joined After Cancel",
          status: "active",
          joinedAt: new Date("2099-06-01T10:00:01.000Z"),
          leftAt: null,
        }),
      );
      await db.doc(`eventChats/${chatId}`).set(eventChatData({
        eventId: chatId,
        readAccessUserIds: ["user-a"],
      }));
      await db.doc(`eventChats/${chatId}/messages/${messageId}`).set(
        eventChatMessageData(),
      );
    });

    const db = joinedAfterCancel.firestore();
    await assertFails(db.doc(`eventChats/${chatId}`).get());
    await assertFails(
      db.doc(`eventChats/${chatId}/messages/${messageId}`).get(),
    );
    await assertFails(boundedEventChatMessagesQuery(db, chatId).get());

    const listSnapshot = await assertSucceeds(
      boundedEventChatMessagesQuery(snapshotReader.firestore(), chatId).get(),
    );
    assert.deepEqual(
      listSnapshot.docs.map((snapshot) => snapshot.id),
      [messageId],
    );
  });

test("canceled event chat metadata uses frozen access, not current membership", async () => {
  const user = testEnv.authenticatedContext("user-a");
  const leftUser = testEnv.authenticatedContext("user-left");
  const currentOnlyUser = testEnv.authenticatedContext("current-only");

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("events/canceled-editable-event/participants/user-a").set(
      participantData({
        status: "left",
        leftAt: new Date("2099-06-01T10:00:01.000Z"),
      }),
    );
    await db.doc("events/canceled-left-snapshot").set(eventData({
      status: "canceled",
      canceledAt: new Date("2099-06-01T10:00:00.000Z"),
      chatId: "canceled-left-snapshot",
    }));
    await db.doc("events/canceled-left-snapshot/participants/user-left").set(
      participantData({
        userId: "user-left",
        displayName: "Left User",
        status: "left",
        leftAt: new Date("2099-06-01T10:00:01.000Z"),
      }),
    );
    await db.doc("eventChats/canceled-left-snapshot").set(eventChatData({
      eventId: "canceled-left-snapshot",
      readAccessUserIds: ["user-left"],
    }));
    await db.doc("events/canceled-current-only").set(eventData({
      status: "canceled",
      canceledAt: new Date("2099-06-01T10:00:00.000Z"),
      chatId: "canceled-current-only",
    }));
    await db.doc("events/canceled-current-only/participants/current-only").set(
      participantData({
        userId: "current-only",
        displayName: "Current Only",
      }),
    );
    await db.doc("eventChats/canceled-current-only").set(eventChatData({
      eventId: "canceled-current-only",
      readAccessUserIds: ["organizer"],
    }));
  });

  await assertSucceeds(
    user.firestore().doc("eventChats/canceled-editable-event").get(),
  );
  await assertSucceeds(
    leftUser.firestore().doc("eventChats/canceled-left-snapshot").get(),
  );
  await assertFails(
    currentOnlyUser.firestore().doc("eventChats/canceled-current-only").get(),
  );
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

test("active event chat message get is limited to active participants", async () => {
  const guest = testEnv.unauthenticatedContext();
  const participant = testEnv.authenticatedContext("user-a");
  const organizer = testEnv.authenticatedContext("organizer");
  const leftUser = testEnv.authenticatedContext("user-left");
  const nonparticipant = testEnv.authenticatedContext("other-user");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});
  const messagePath = "eventChats/editable-event/messages/message-1";

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("eventChats/editable-event").update({
      readAccessUserIds: ["organizer", "user-a", "user-left"],
    });
    await db.doc(messagePath).set(eventChatMessageData());
  });

  await assertSucceeds(participant.firestore().doc(messagePath).get());
  await assertSucceeds(organizer.firestore().doc(messagePath).get());
  await assertFails(guest.firestore().doc(messagePath).get());
  await assertFails(leftUser.firestore().doc(messagePath).get());
  await assertFails(nonparticipant.firestore().doc(messagePath).get());
  await assertFails(adminClient.firestore().doc(messagePath).get());
});

test("active event chat messages can be listed by active participants", async () => {
  const participant = testEnv.authenticatedContext("user-a");
  const organizer = testEnv.authenticatedContext("organizer");
  const guest = testEnv.unauthenticatedContext();
  const leftUser = testEnv.authenticatedContext("user-left");
  const nonparticipant = testEnv.authenticatedContext("other-user");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore()
      .doc("eventChats/editable-event/messages/message-1")
      .set(eventChatMessageData());
  });

  for (const context of [participant, organizer]) {
    const db = context.firestore();
    await assertSucceeds(
      boundedEventChatMessagesQuery(db).get(),
    );
    await assertFails(db.collection("eventChats/editable-event/messages").get());
  }

  for (const context of [guest, leftUser, nonparticipant, adminClient]) {
    const db = context.firestore();
    await assertFails(boundedEventChatMessagesQuery(db).get());
    await assertFails(db.collection("eventChats/editable-event/messages").get());
    await assertFails(
      db.collection("eventChats/editable-event/messages")
        .where("senderId", "==", "user-a")
        .get(),
    );
  }
});

test("active event chat access is not granted by readAccessUserIds alone",
  async () => {
    const snapshotOnlyUser = testEnv.authenticatedContext("snapshot-only");
    const chatId = "snapshot-only-active-chat";

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc(`events/${chatId}`).set(eventData({chatId}));
      await db.doc(`events/${chatId}/participants/organizer`).set(
        participantData({
          userId: "organizer",
          displayName: "Organizer",
          role: "organizer",
        }),
      );
      await db.doc(`eventChats/${chatId}`).set(eventChatData({
        eventId: chatId,
        readAccessUserIds: ["snapshot-only"],
      }));
      await db.doc(`eventChats/${chatId}/messages/message-1`).set(
        eventChatMessageData(),
      );
    });

    const db = snapshotOnlyUser.firestore();
    await assertFails(db.doc(`eventChats/${chatId}`).get());
    await assertFails(
      db.doc(`eventChats/${chatId}/messages/message-1`).get(),
    );
    await assertFails(boundedEventChatMessagesQuery(db, chatId).get());
  });

test("active event chat message reads fail closed for invalid parent state", async () => {
  const user = testEnv.authenticatedContext("user-a");
  const messagePaths = [
    "eventChats/missing-message-chat/messages/message-1",
    "eventChats/mismatched-message-chat-metadata/messages/message-1",
    "eventChats/mismatched-message-event-chat-id/messages/message-1",
    "eventChats/orphan-message-chat/messages/message-1",
    "eventChats/no-participant-message-chat/messages/message-1",
    "eventChats/invalid-message-chat-metadata/messages/message-1",
  ];

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("events/missing-message-chat").set(eventData({
      chatId: "missing-message-chat",
    }));
    await db.doc("events/missing-message-chat/participants/user-a").set(
      participantData(),
    );

    await db.doc("events/mismatched-message-chat-metadata").set(eventData({
      chatId: "mismatched-message-chat-metadata",
    }));
    await db.doc(
      "events/mismatched-message-chat-metadata/participants/user-a",
    ).set(participantData());
    await db.doc("eventChats/mismatched-message-chat-metadata").set(
      eventChatData({
        eventId: "other-event",
      }),
    );

    await db.doc("events/mismatched-message-event-chat-id").set(eventData({
      chatId: "other-chat",
    }));
    await db.doc(
      "events/mismatched-message-event-chat-id/participants/user-a",
    ).set(participantData());
    await db.doc("eventChats/mismatched-message-event-chat-id").set(
      eventChatData({
        eventId: "mismatched-message-event-chat-id",
      }),
    );

    await db.doc("eventChats/orphan-message-chat").set(eventChatData({
      eventId: "orphan-message-chat",
    }));

    await db.doc("events/no-participant-message-chat").set(eventData({
      chatId: "no-participant-message-chat",
    }));
    await db.doc("eventChats/no-participant-message-chat").set(eventChatData({
      eventId: "no-participant-message-chat",
    }));

    await db.doc("events/invalid-message-chat-metadata").set(eventData({
      chatId: "invalid-message-chat-metadata",
    }));
    await db.doc(
      "events/invalid-message-chat-metadata/participants/user-a",
    ).set(participantData());
    await db.doc("eventChats/invalid-message-chat-metadata").set({
      eventId: "invalid-message-chat-metadata",
      createdAt: new Date("2026-06-14T10:00:00.000Z"),
      updatedAt: new Date("2026-06-14T10:00:00.000Z"),
    });

    for (const messagePath of messagePaths) {
      await db.doc(messagePath).set(eventChatMessageData());
    }
  });

  for (const messagePath of messagePaths) {
    await assertFails(user.firestore().doc(messagePath).get());
  }
});

test("canceled event chat message get uses frozen read access", async () => {
  const guest = testEnv.unauthenticatedContext();
  const participantAtCancel = testEnv.authenticatedContext("user-a");
  const organizer = testEnv.authenticatedContext("organizer");
  const leftBeforeCancel = testEnv.authenticatedContext("user-left");
  const leftAfterCancelSnapshotUser = testEnv.authenticatedContext("user-left");
  const currentOnlyUser = testEnv.authenticatedContext("current-only");
  const otherUser = testEnv.authenticatedContext("other-user");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});
  const canceledMessagePath =
    "eventChats/canceled-editable-event/messages/message-1";
  const leftSnapshotMessagePath =
    "eventChats/canceled-left-message-snapshot/messages/message-1";
  const currentOnlyMessagePath =
    "eventChats/canceled-current-message-only/messages/message-1";

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("events/canceled-editable-event/participants/user-left").set(
      participantData({
        userId: "user-left",
        displayName: "Left User",
        status: "left",
        leftAt: new Date("2099-06-01T09:59:59.000Z"),
      }),
    );
    await db.doc(canceledMessagePath).set(eventChatMessageData());

    await db.doc("events/canceled-left-message-snapshot").set(eventData({
      status: "canceled",
      canceledAt: new Date("2099-06-01T10:00:00.000Z"),
      chatId: "canceled-left-message-snapshot",
    }));
    await db.doc(
      "events/canceled-left-message-snapshot/participants/user-left",
    ).set(participantData({
      userId: "user-left",
      displayName: "Left User",
      status: "left",
      leftAt: new Date("2099-06-01T10:00:01.000Z"),
    }));
    await db.doc("eventChats/canceled-left-message-snapshot").set(
      eventChatData({
        eventId: "canceled-left-message-snapshot",
        readAccessUserIds: ["user-left"],
      }),
    );
    await db.doc(leftSnapshotMessagePath).set(eventChatMessageData());

    await db.doc("events/canceled-current-message-only").set(eventData({
      status: "canceled",
      canceledAt: new Date("2099-06-01T10:00:00.000Z"),
      chatId: "canceled-current-message-only",
    }));
    await db.doc(
      "events/canceled-current-message-only/participants/current-only",
    ).set(participantData({
      userId: "current-only",
      displayName: "Current Only",
    }));
    await db.doc("eventChats/canceled-current-message-only").set(
      eventChatData({
        eventId: "canceled-current-message-only",
        readAccessUserIds: ["organizer"],
      }),
    );
    await db.doc(currentOnlyMessagePath).set(eventChatMessageData());
  });

  await assertSucceeds(participantAtCancel.firestore().doc(canceledMessagePath).get());
  await assertSucceeds(organizer.firestore().doc(canceledMessagePath).get());
  await assertFails(guest.firestore().doc(canceledMessagePath).get());
  await assertFails(leftBeforeCancel.firestore().doc(canceledMessagePath).get());
  await assertFails(otherUser.firestore().doc(canceledMessagePath).get());
  await assertFails(adminClient.firestore().doc(canceledMessagePath).get());
  await assertSucceeds(
    leftAfterCancelSnapshotUser.firestore().doc(leftSnapshotMessagePath).get(),
  );
  await assertFails(
    currentOnlyUser.firestore().doc(currentOnlyMessagePath).get(),
  );
});

test("canceled event chat messages can be listed by frozen readers", async () => {
  const participantAtCancel = testEnv.authenticatedContext("user-a");
  const organizer = testEnv.authenticatedContext("organizer");
  const guest = testEnv.unauthenticatedContext();
  const otherUser = testEnv.authenticatedContext("other-user");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore()
      .doc("eventChats/canceled-editable-event/messages/message-1")
      .set(eventChatMessageData());
  });

  for (const context of [participantAtCancel, organizer]) {
    const db = context.firestore();
    await assertSucceeds(
      db.collection("eventChats/canceled-editable-event/messages")
        .orderBy("createdAt", "desc")
        .orderBy(firebaseCompat.firestore.FieldPath.documentId(), "desc")
        .limit(50)
        .get(),
    );
    await assertFails(
      db.collection("eventChats/canceled-editable-event/messages").get(),
    );
  }

  for (const context of [guest, otherUser, adminClient]) {
    const db = context.firestore();
    await assertFails(
      db.collection("eventChats/canceled-editable-event/messages").get(),
    );
    await assertFails(
      db.collection("eventChats/canceled-editable-event/messages")
        .where("senderId", "==", "user-a")
        .get(),
    );
  }
});

test("canceled event chat messages deny bounded list for nonparticipants and users left before cancellation",
  async () => {
    const guest = testEnv.unauthenticatedContext();
    const leftBeforeCancel = testEnv.authenticatedContext("user-left");
    const otherUser = testEnv.authenticatedContext("other-user");
    const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});
    const chatId = "canceled-editable-event";

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc("events/canceled-editable-event/participants/user-left").set(
        participantData({
          userId: "user-left",
          displayName: "Left User",
          status: "left",
          leftAt: new Date("2099-06-01T09:59:59.000Z"),
        }),
      );
      await db.doc("eventChats/canceled-editable-event/messages/message-1")
        .set(eventChatMessageData());
    });

    for (const context of [
      guest,
      leftBeforeCancel,
      otherUser,
      adminClient,
    ]) {
      await assertFails(
        boundedEventChatMessagesQuery(context.firestore(), chatId).get(),
      );
    }
  });

test("event chat messages cannot be read through collection group queries", async () => {
  const contexts = [
    testEnv.authenticatedContext("user-a"),
    testEnv.authenticatedContext("organizer"),
    testEnv.authenticatedContext("admin-user", {admin: true}),
  ];

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("eventChats/editable-event/messages/message-1")
      .set(eventChatMessageData());
    await db.doc("eventChats/canceled-editable-event/messages/message-1")
      .set(eventChatMessageData());
  });

  for (const context of contexts) {
    const db = context.firestore();
    await assertFails(db.collectionGroup("messages").get());
    await assertFails(
      db.collectionGroup("messages")
        .where("senderId", "==", "user-a")
        .get(),
    );
    await assertFails(
      db.collectionGroup("messages")
        .orderBy("createdAt", "desc")
        .limit(50)
        .get(),
    );
  }
});

test("event chat message tombstones expose only the fixed placeholder",
  async () => {
    const participant = testEnv.authenticatedContext("user-a");
    const organizer = testEnv.authenticatedContext("organizer");
    const activeMessagePath =
      "eventChats/editable-event/messages/tombstone-active";
    const canceledMessagePath =
      "eventChats/canceled-editable-event/messages/tombstone-canceled";
    const activeOriginalText = "Active original user text";
    const canceledOriginalText = "Canceled original user text";
    const deletedTimestamp = firebaseCompat.firestore.Timestamp.fromDate(
      new Date("2026-06-16T11:00:00.000Z"),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc(activeMessagePath).set(eventChatMessageData({
        text: activeOriginalText,
        originalText: activeOriginalText,
      }));
      await tombstoneEventChatMessage({
        db,
        eventId: "editable-event",
        messageId: "tombstone-active",
        deletedTimestamp,
      });
      await db.doc(canceledMessagePath).set(eventChatMessageData({
        text: canceledOriginalText,
        originalText: canceledOriginalText,
      }));
      await tombstoneEventChatMessage({
        db,
        eventId: "canceled-editable-event",
        messageId: "tombstone-canceled",
        deletedTimestamp,
      });
    });

    const activeSnapshot = await assertSucceeds(
      participant.firestore().doc(activeMessagePath).get(),
    );
    assert.equal(activeSnapshot.data().text, EVENT_CHAT_MESSAGE_TOMBSTONE_TEXT);
    assert.equal(activeSnapshot.data().originalText, undefined);
    assert.notEqual(activeSnapshot.data().text, activeOriginalText);

    const activeList = await assertSucceeds(
      boundedEventChatMessagesQuery(
        participant.firestore(),
        "editable-event",
      ).get(),
    );
    const activeListed = activeList.docs
      .find((doc) => doc.id === "tombstone-active");
    assert.ok(activeListed);
    assert.equal(activeListed.data().text, EVENT_CHAT_MESSAGE_TOMBSTONE_TEXT);
    assert.equal(activeListed.data().originalText, undefined);

    const canceledSnapshot = await assertSucceeds(
      organizer.firestore().doc(canceledMessagePath).get(),
    );
    assert.equal(canceledSnapshot.data().text,
      EVENT_CHAT_MESSAGE_TOMBSTONE_TEXT);
    assert.equal(canceledSnapshot.data().originalText, undefined);
    assert.notEqual(canceledSnapshot.data().text, canceledOriginalText);

    const canceledList = await assertSucceeds(
      boundedEventChatMessagesQuery(
        organizer.firestore(),
        "canceled-editable-event",
      ).get(),
    );
    const canceledListed = canceledList.docs
      .find((doc) => doc.id === "tombstone-canceled");
    assert.ok(canceledListed);
    assert.equal(canceledListed.data().text,
      EVENT_CHAT_MESSAGE_TOMBSTONE_TEXT);
    assert.equal(canceledListed.data().originalText, undefined);
  });

test("canceled event chat message reads fail closed for invalid parent state", async () => {
  const user = testEnv.authenticatedContext("user-a");
  const messagePaths = [
    "eventChats/canceled-missing-message-chat/messages/message-1",
    "eventChats/canceled-mismatched-message-chat-metadata/messages/message-1",
    "eventChats/canceled-mismatched-message-event-chat-id/messages/message-1",
    "eventChats/canceled-orphan-message-chat/messages/message-1",
    "eventChats/canceled-null-message-canceled-at/messages/message-1",
    "eventChats/canceled-missing-message-canceled-at/messages/message-1",
    "eventChats/canceled-missing-message-read-access/messages/message-1",
    "eventChats/canceled-wrong-message-read-access-type/messages/message-1",
  ];

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("events/canceled-missing-message-chat").set(eventData({
      status: "canceled",
      canceledAt: new Date("2099-06-01T10:00:00.000Z"),
      chatId: "canceled-missing-message-chat",
    }));

    await db.doc("events/canceled-mismatched-message-chat-metadata").set(
      eventData({
        status: "canceled",
        canceledAt: new Date("2099-06-01T10:00:00.000Z"),
        chatId: "canceled-mismatched-message-chat-metadata",
      }),
    );
    await db.doc("eventChats/canceled-mismatched-message-chat-metadata").set(
      eventChatData({
        eventId: "other-event",
        readAccessUserIds: ["user-a"],
      }),
    );

    await db.doc("events/canceled-mismatched-message-event-chat-id").set(
      eventData({
        status: "canceled",
        canceledAt: new Date("2099-06-01T10:00:00.000Z"),
        chatId: "other-chat",
      }),
    );
    await db.doc("eventChats/canceled-mismatched-message-event-chat-id").set(
      eventChatData({
        eventId: "canceled-mismatched-message-event-chat-id",
        readAccessUserIds: ["user-a"],
      }),
    );

    await db.doc("eventChats/canceled-orphan-message-chat").set(eventChatData({
      eventId: "canceled-orphan-message-chat",
      readAccessUserIds: ["user-a"],
    }));

    await db.doc("events/canceled-null-message-canceled-at").set(eventData({
      status: "canceled",
      canceledAt: null,
      chatId: "canceled-null-message-canceled-at",
    }));
    await db.doc("eventChats/canceled-null-message-canceled-at").set(
      eventChatData({
        eventId: "canceled-null-message-canceled-at",
        readAccessUserIds: ["user-a"],
      }),
    );

    const missingCanceledAtEvent = eventData({
      status: "canceled",
      chatId: "canceled-missing-message-canceled-at",
    });
    delete missingCanceledAtEvent.canceledAt;
    await db.doc("events/canceled-missing-message-canceled-at").set(
      missingCanceledAtEvent,
    );
    await db.doc("eventChats/canceled-missing-message-canceled-at").set(
      eventChatData({
        eventId: "canceled-missing-message-canceled-at",
        readAccessUserIds: ["user-a"],
      }),
    );

    await db.doc("events/canceled-missing-message-read-access").set(eventData({
      status: "canceled",
      canceledAt: new Date("2099-06-01T10:00:00.000Z"),
      chatId: "canceled-missing-message-read-access",
    }));
    await db.doc("eventChats/canceled-missing-message-read-access").set({
      eventId: "canceled-missing-message-read-access",
      createdAt: new Date("2026-06-14T10:00:00.000Z"),
      updatedAt: new Date("2026-06-14T10:00:00.000Z"),
    });

    await db.doc("events/canceled-wrong-message-read-access-type").set(
      eventData({
        status: "canceled",
        canceledAt: new Date("2099-06-01T10:00:00.000Z"),
        chatId: "canceled-wrong-message-read-access-type",
      }),
    );
    await db.doc("eventChats/canceled-wrong-message-read-access-type").set(
      eventChatData({
        eventId: "canceled-wrong-message-read-access-type",
        readAccessUserIds: "user-a",
      }),
    );

    for (const messagePath of messagePaths) {
      await db.doc(messagePath).set(eventChatMessageData());
    }
  });

  for (const messagePath of messagePaths) {
    await assertFails(user.firestore().doc(messagePath).get());
  }
});

test("clients cannot directly write active or canceled event chat message documents",
  async () => {
    const actors = eventChatWriteActors();
    const chatIds = [
      "editable-event",
      "canceled-editable-event",
    ];

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await seedLeftBeforeCancelParticipant(db, "canceled-editable-event");
      for (const chatId of chatIds) {
        await db.doc(`eventChats/${chatId}/messages/existing`)
          .set(eventChatMessageData());
      }
    });

    for (const [index, {context}] of actors.entries()) {
      const db = context.firestore();
      for (const chatId of chatIds) {
        const existingMessagePath = `eventChats/${chatId}/messages/existing`;
        await assertFails(
          db.doc(`eventChats/${chatId}/messages/direct-create-${index}`)
            .set(eventChatMessageData()),
        );
        await assertFails(
          db.doc(existingMessagePath).set(eventChatMessageData({
            text: "Replaced",
          })),
        );
        await assertFails(
          db.doc(existingMessagePath).set({
            text: "Merged",
          }, {merge: true}),
        );
        await assertFails(db.doc(existingMessagePath).update({
          text: "Edited",
        }));
        await assertFails(db.doc(existingMessagePath).delete());
      }
    }
  });

test("event chat message writes fail inside otherwise allowed batches", async () => {
  const organizer = testEnv.authenticatedContext("organizer");
  const db = organizer.firestore();
  const existingMessagePath = "eventChats/editable-event/messages/existing";
  const deniedBatchWrites = [
    (batch) => batch.set(
      db.doc("eventChats/editable-event/messages/batched-create"),
      eventChatMessageData(),
    ),
    (batch) => batch.update(db.doc(existingMessagePath), {
      text: "Edited",
    }),
    (batch) => batch.delete(db.doc(existingMessagePath)),
  ];

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore()
      .doc(existingMessagePath)
      .set(eventChatMessageData());
  });

  for (const applyDeniedWrite of deniedBatchWrites) {
    const batch = db.batch();
    batch.update(db.doc("events/editable-event"), directEditPatch());
    applyDeniedWrite(batch);
    await assertFails(batch.commit());
  }
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

    await db.doc("events/noncanonical-event-chat").set(eventData({
      chatId: "noncanonical-chat",
    }));
    await db.doc("events/noncanonical-event-chat/participants/user-a").set(
      participantData(),
    );
    await db.doc("eventChats/noncanonical-chat").set(eventChatData({
      eventId: "noncanonical-event-chat",
    }));

    const invalidMetadataCases = [
      {
        chatId: "chat-extra-status",
        chatOverrides: {status: "active"},
      },
      {
        chatId: "chat-extra-canceled-at",
        chatOverrides: {canceledAt: null},
      },
      {
        chatId: "chat-missing-updated-at",
        removeFields: ["updatedAt"],
      },
      {
        chatId: "chat-wrong-updated-at-type",
        chatOverrides: {updatedAt: "2026-06-14T10:00:00.000Z"},
      },
    ];
    for (const {
      chatId,
      chatOverrides = {},
      removeFields = [],
    } of invalidMetadataCases) {
      await db.doc(`events/${chatId}`).set(eventData({chatId}));
      await db.doc(`events/${chatId}/participants/user-a`).set(
        participantData(),
      );
      const chatData = eventChatData({eventId: chatId, ...chatOverrides});
      for (const field of removeFields) {
        delete chatData[field];
      }
      await db.doc(`eventChats/${chatId}`).set(chatData);
    }
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
  await assertFails(user.firestore().doc("eventChats/noncanonical-chat").get());
  for (const chatId of [
    "chat-extra-status",
    "chat-extra-canceled-at",
    "chat-missing-updated-at",
    "chat-wrong-updated-at-type",
  ]) {
    await assertFails(user.firestore().doc(`eventChats/${chatId}`).get());
  }
});

test("canceled event chat metadata reads fail closed for invalid state", async () => {
  const user = testEnv.authenticatedContext("user-a");

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("events/canceled-mismatched-chat-metadata").set(eventData({
      status: "canceled",
      canceledAt: new Date("2099-06-01T10:00:00.000Z"),
      chatId: "canceled-mismatched-chat-metadata",
    }));
    await db.doc("eventChats/canceled-mismatched-chat-metadata").set(
      eventChatData({
        eventId: "other-event",
        readAccessUserIds: ["user-a"],
      }),
    );

    await db.doc("events/canceled-mismatched-event-chat-id").set(eventData({
      status: "canceled",
      canceledAt: new Date("2099-06-01T10:00:00.000Z"),
      chatId: "other-chat",
    }));
    await db.doc("eventChats/canceled-mismatched-event-chat-id").set(
      eventChatData({
        eventId: "canceled-mismatched-event-chat-id",
        readAccessUserIds: ["user-a"],
      }),
    );

    await db.doc("eventChats/canceled-orphan-chat").set(eventChatData({
      eventId: "canceled-orphan-chat",
      readAccessUserIds: ["user-a"],
    }));

    await db.doc("events/canceled-null-canceled-at").set(eventData({
      status: "canceled",
      canceledAt: null,
      chatId: "canceled-null-canceled-at",
    }));
    await db.doc("eventChats/canceled-null-canceled-at").set(eventChatData({
      eventId: "canceled-null-canceled-at",
      readAccessUserIds: ["user-a"],
    }));

    const missingCanceledAtEvent = eventData({
      status: "canceled",
      chatId: "canceled-missing-canceled-at",
    });
    delete missingCanceledAtEvent.canceledAt;
    await db.doc("events/canceled-missing-canceled-at").set(
      missingCanceledAtEvent,
    );
    await db.doc("eventChats/canceled-missing-canceled-at").set(eventChatData({
      eventId: "canceled-missing-canceled-at",
      readAccessUserIds: ["user-a"],
    }));

    await db.doc("events/canceled-missing-read-access").set(eventData({
      status: "canceled",
      canceledAt: new Date("2099-06-01T10:00:00.000Z"),
      chatId: "canceled-missing-read-access",
    }));
    await db.doc("eventChats/canceled-missing-read-access").set({
      eventId: "canceled-missing-read-access",
      createdAt: new Date("2026-06-14T10:00:00.000Z"),
      updatedAt: new Date("2026-06-14T10:00:00.000Z"),
    });

    await db.doc("events/canceled-wrong-read-access-type").set(eventData({
      status: "canceled",
      canceledAt: new Date("2099-06-01T10:00:00.000Z"),
      chatId: "canceled-wrong-read-access-type",
    }));
    await db.doc("eventChats/canceled-wrong-read-access-type").set(
      eventChatData({
        eventId: "canceled-wrong-read-access-type",
        readAccessUserIds: "user-a",
      }),
    );

    await db.doc("events/canceled-missing-chat-event").set(eventData({
      status: "canceled",
      canceledAt: new Date("2099-06-01T10:00:00.000Z"),
      chatId: "canceled-missing-chat-event",
    }));

    await db.doc("events/canceled-noncanonical-event-chat").set(eventData({
      status: "canceled",
      canceledAt: new Date("2099-06-01T10:00:00.000Z"),
      chatId: "canceled-noncanonical-chat",
    }));
    await db.doc("eventChats/canceled-noncanonical-chat").set(eventChatData({
      eventId: "canceled-noncanonical-event-chat",
      readAccessUserIds: ["user-a"],
    }));

    const invalidMetadataCases = [
      {
        chatId: "canceled-chat-extra-status",
        chatOverrides: {status: "canceled"},
      },
      {
        chatId: "canceled-chat-extra-canceled-at",
        chatOverrides: {
          canceledAt: new Date("2099-06-01T10:00:00.000Z"),
        },
      },
      {
        chatId: "canceled-chat-missing-updated-at",
        removeFields: ["updatedAt"],
      },
      {
        chatId: "canceled-chat-wrong-updated-at-type",
        chatOverrides: {updatedAt: "2026-06-14T10:00:00.000Z"},
      },
    ];
    for (const {
      chatId,
      chatOverrides = {},
      removeFields = [],
    } of invalidMetadataCases) {
      await db.doc(`events/${chatId}`).set(eventData({
        status: "canceled",
        canceledAt: new Date("2099-06-01T10:00:00.000Z"),
        chatId,
      }));
      const chatData = eventChatData({
        eventId: chatId,
        readAccessUserIds: ["user-a"],
        ...chatOverrides,
      });
      for (const field of removeFields) {
        delete chatData[field];
      }
      await db.doc(`eventChats/${chatId}`).set(chatData);
    }
  });

  await assertFails(
    user.firestore().doc("eventChats/canceled-mismatched-chat-metadata").get(),
  );
  await assertFails(
    user.firestore().doc("eventChats/canceled-mismatched-event-chat-id").get(),
  );
  await assertFails(user.firestore().doc("eventChats/canceled-orphan-chat").get());
  await assertFails(
    user.firestore().doc("eventChats/canceled-null-canceled-at").get(),
  );
  await assertFails(
    user.firestore().doc("eventChats/canceled-missing-canceled-at").get(),
  );
  await assertFails(
    user.firestore().doc("eventChats/canceled-missing-read-access").get(),
  );
  await assertFails(
    user.firestore().doc("eventChats/canceled-wrong-read-access-type").get(),
  );
  await assertFails(
    user.firestore().doc("eventChats/canceled-missing-chat-event").get(),
  );
  await assertFails(
    user.firestore().doc("eventChats/canceled-noncanonical-chat").get(),
  );
  for (const chatId of [
    "canceled-chat-extra-status",
    "canceled-chat-extra-canceled-at",
    "canceled-chat-missing-updated-at",
    "canceled-chat-wrong-updated-at-type",
  ]) {
    await assertFails(user.firestore().doc(`eventChats/${chatId}`).get());
  }
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

test("direct participant writes stay blocked after event starts", async () => {
  const user = testEnv.authenticatedContext("user-a");
  const organizer = testEnv.authenticatedContext("organizer");

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("events/started-event").set(eventData({
      startsAt: new Date("2020-06-20T15:00:00.000Z"),
      chatId: "started-event",
    }));
    await db.doc("events/started-event/participants/user-a").set(
      participantData(),
    );
    await db.doc("events/started-event/participants/organizer").set(
      participantData({
        userId: "organizer",
        displayName: "Organizer",
        role: "organizer",
      }),
    );
  });

  await assertFails(
    user.firestore().doc("events/started-event/participants/user-a").update({
      status: "left",
      leftAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
      updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    }),
  );
  await assertFails(
    user.firestore().doc("events/started-event/participants/user-a").delete(),
  );
  await assertFails(
    organizer.firestore()
      .doc("events/started-event/participants/new-user")
      .set(participantData({userId: "new-user"})),
  );
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
  const otherUser = testEnv.authenticatedContext("other-user");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});
  const contexts = [guest, user, otherUser, adminClient];
  const counterRootPath = "eventCreationCounters/user-a";
  const counterPath = `${counterRootPath}/days/20260616`;
  const counterRef = user.firestore().doc(counterPath);
  const adminDb = adminClient.firestore();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(counterRootPath).set({userId: "user-a"});
  });

  for (const context of contexts) {
    const db = context.firestore();
    await assertFails(
      db.doc("eventCreationCounters/direct-root").set({userId: "user-a"}),
    );
    await assertFails(
      db.doc("eventCreationCounters/user-a/days/20260619")
        .set(eventCreationCounterData({dayKeyUtc: "2026-06-19"})),
    );
    await assertFails(db.doc(counterRootPath).update({userId: "changed"}));
    await assertFails(db.doc(counterRootPath).delete());
    await assertFails(db.doc(counterPath).delete());
  }

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
  const otherUser = testEnv.authenticatedContext("other-user");
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});
  const contexts = [guest, user, otherUser, adminClient];
  const markerRootPath = "eventCreateRequests/user-a";
  const markerPath =
    `${markerRootPath}/requests/${eventCreateRequestId}`;
  const markerRef = user.firestore().doc(markerPath);
  const adminDb = adminClient.firestore();
  const nextRequestId = "650e8400-e29b-41d4-a716-446655440001";
  const adminRequestId = "750e8400-e29b-41d4-a716-446655440002";

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(markerRootPath).set({userId: "user-a"});
  });

  for (const context of contexts) {
    const db = context.firestore();
    await assertFails(
      db.doc("eventCreateRequests/direct-root").set({userId: "user-a"}),
    );
    await assertFails(
      db.doc(`${markerRootPath}/requests/${nextRequestId}`)
        .set(eventCreateRequestData({createRequestId: nextRequestId})),
    );
    await assertFails(db.doc(markerRootPath).update({userId: "changed"}));
    await assertFails(db.doc(markerRootPath).delete());
    await assertFails(db.doc(markerPath).delete());
  }

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

test("event reports are private and server-owned", async () => {
  const reportPath = "eventReports/report-1";
  const contexts = [
    testEnv.unauthenticatedContext(),
    testEnv.authenticatedContext("user-a"),
    testEnv.authenticatedContext("other-user"),
  ];
  const adminClient = testEnv.authenticatedContext("admin-user", {admin: true});

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(reportPath).set({
      eventId: "editable-event",
      reporterId: "user-a",
      organizerId: "organizer",
      reasonCode: "unsafe",
      status: "open",
      createdAt: new Date("2026-06-16T10:00:00.000Z"),
      updatedAt: new Date("2026-06-16T10:00:00.000Z"),
    });
  });

  for (const context of contexts) {
    const db = context.firestore();
    await assertFails(db.doc(reportPath).get());
    await assertFails(db.collection("eventReports").get());
    await assertFails(
      db.doc("eventReports/direct-client-report").set({
        eventId: "editable-event",
        reporterId: "user-a",
        reasonCode: "spam",
      }),
    );
    await assertFails(db.doc(reportPath).update({status: "closed"}));
    await assertFails(db.doc(reportPath).delete());
  }

  const adminDb = adminClient.firestore();
  await assertSucceeds(adminDb.doc(reportPath).get());
  await assertSucceeds(adminDb.collection("eventReports").get());
  await assertFails(
    adminDb.doc("eventReports/direct-admin-report").set({
      eventId: "editable-event",
      reporterId: "admin-user",
      reasonCode: "spam",
    }),
  );
  await assertFails(adminDb.doc(reportPath).update({status: "closed"}));
  await assertFails(adminDb.doc(reportPath).delete());
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

test("clients cannot directly create complete event graph in a batch", async () => {
  const user = testEnv.authenticatedContext("user-a");
  const db = user.firestore();
  const batch = db.batch();
  const eventId = "direct-create-full-graph";
  const requestId = "00000000-0000-4000-8000-000000000001";
  const payloadHash = "a".repeat(64);
  const counterPath = "eventCreationCounters/user-a/days/20260618";
  const dailyCreation = {
    count: 1,
    dayKeyUtc: "2026-06-18",
    remaining: 4,
    resetAtUtc: "2026-06-19T00:00:00.000Z",
  };

  batch.set(db.doc(`events/${eventId}`), eventData({
    organizerId: "user-a",
    organizerDisplayName: "User A",
    organizerPhotoUrl: "https://cdn.example.com/user-a.jpg",
    chatId: eventId,
    participantsCount: 1,
  }));
  batch.set(
    db.doc(`events/${eventId}/participants/user-a`),
    participantData({
      userId: "user-a",
      role: "organizer",
    }),
  );
  batch.set(db.doc(`eventChats/${eventId}`), eventChatData({
    eventId,
    readAccessUserIds: ["user-a"],
  }));
  batch.set(
    db.doc(counterPath),
    eventCreationCounterData({
      dayKeyUtc: "2026-06-18",
      eventIds: [eventId],
      requestEventIds: {
        [requestId]: eventId,
      },
      requestPayloadHashes: {
        [requestId]: payloadHash,
      },
      windowStartAt: new Date("2026-06-18T00:00:00.000Z"),
      windowEndAt: new Date("2026-06-19T00:00:00.000Z"),
    }),
  );
  batch.set(
    db.doc(`eventCreateRequests/user-a/requests/${requestId}`),
    eventCreateRequestData({
      createRequestId: requestId,
      eventId,
      payloadHash,
      counterPath,
      dayKeyUtc: "2026-06-18",
      dailyCreation,
    }),
  );

  await assertFails(batch.commit());
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

test("organizer cannot directly edit active events with canceledAt set", async () => {
  const organizer = testEnv.authenticatedContext("organizer");

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("events/active-with-canceled-at").set(
      eventData({
        startsAt: farFutureStartsAt,
        chatId: "active-with-canceled-at",
        canceledAt: new Date("2099-06-01T10:00:00.000Z"),
      }),
    );
  });

  await assertFails(
    organizer.firestore()
      .doc("events/active-with-canceled-at")
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

test("direct organizer edit validates capacity bounds and type", async () => {
  const organizer = testEnv.authenticatedContext("organizer");
  const eventRef = organizer.firestore().doc("events/capacity-bounds-event");

  await assertSucceeds(eventRef.update(directEditPatch({capacity: 2})));
  await assertSucceeds(eventRef.update(directEditPatch({capacity: 50})));
  await assertFails(eventRef.update(directEditPatch({capacity: 1})));
  await assertFails(eventRef.update(directEditPatch({capacity: 51})));
  await assertFails(eventRef.update(directEditPatch({capacity: 3.5})));
  await assertFails(eventRef.update(directEditPatch({
    capacity: 2,
    participantsCount: 3,
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

test("direct organizer edit cannot persist language struct maps", async () => {
  const organizer = testEnv.authenticatedContext("organizer");
  const eventRef = organizer.firestore().doc("events/editable-event");
  const languageStruct = {
    code: "en",
    alternateCodes: ["en", "en-US"],
    nameEn: "Stale English",
    nameRu: "Stale Russian",
    isPopular: true,
    ss: "client-ui-state",
  };

  await assertFails(eventRef.update({
    ...directEditPatch(),
    language: languageStruct,
  }));
  await assertFails(eventRef.update({
    ...directEditPatch(),
    LanguageStruct: languageStruct,
  }));
  await assertFails(eventRef.set({
    ...eventData({
      startsAt: farFutureStartsAt,
      participantsCount: 3,
      capacity: 8,
      chatId: "editable-event",
    }),
    language: languageStruct,
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
    {startsAt: firebaseCompat.firestore.FieldValue.serverTimestamp()},
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

test("clients cannot directly write event chat metadata documents", async () => {
  const actors = [
    {name: "guest", context: testEnv.unauthenticatedContext()},
    {name: "participant", context: testEnv.authenticatedContext("user-a")},
    {name: "organizer", context: testEnv.authenticatedContext("organizer")},
    {
      name: "nonparticipant",
      context: testEnv.authenticatedContext("other-user"),
    },
    {
      name: "admin",
      context: testEnv.authenticatedContext("admin-user", {admin: true}),
    },
  ];

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const {name} of actors) {
      await db.doc(`events/direct-create-chat-${name}`).set(eventData({
        chatId: `direct-create-chat-${name}`,
      }));
    }
  });

  for (const {name, context} of actors) {
    const db = context.firestore();
    const createPath = `eventChats/direct-create-chat-${name}`;
    const existingChatRef = db.doc("eventChats/editable-event");

    await assertFails(db.doc(createPath).set(eventChatData({
      eventId: `direct-create-chat-${name}`,
    })));
    await assertFails(existingChatRef.set(eventChatData({
      eventId: "editable-event",
    })));
    await assertFails(existingChatRef.set({
      updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    }, {merge: true}));
    await assertFails(existingChatRef.update({
      updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    }));
    await assertFails(existingChatRef.update({
      readAccessUserIds: ["organizer", "user-a", "other-user"],
      updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    }));
    await assertFails(existingChatRef.delete());
  }
});

test("clients cannot directly write canceled event chat metadata documents",
  async () => {
    const actors = eventChatWriteActors();

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      for (const {name} of actors) {
        const chatId = `canceled-direct-create-chat-${name}`;
        await db.doc(`events/${chatId}`).set(eventData({
          status: "canceled",
          canceledAt: new Date("2099-06-01T10:00:00.000Z"),
          chatId,
        }));
        await db.doc(`events/${chatId}/participants/organizer`).set(
          participantData({
            userId: "organizer",
            displayName: "Organizer",
            role: "organizer",
          }),
        );
        await db.doc(`events/${chatId}/participants/user-a`).set(
          participantData(),
        );
        await seedLeftBeforeCancelParticipant(db, chatId);
      }
      await seedLeftBeforeCancelParticipant(db, "canceled-editable-event");
    });

    for (const {name, context} of actors) {
      const db = context.firestore();
      const createChatId = `canceled-direct-create-chat-${name}`;
      const existingChatRef = db.doc("eventChats/canceled-editable-event");

      await assertFails(db.doc(`eventChats/${createChatId}`).set(
        eventChatData({
          eventId: createChatId,
          readAccessUserIds: ["organizer", "user-a"],
        }),
      ));
      await assertFails(existingChatRef.set(eventChatData({
        eventId: "canceled-editable-event",
        readAccessUserIds: ["organizer", "user-a"],
      })));
      await assertFails(existingChatRef.set({
        readAccessUserIds: ["organizer", "user-a", "other-user"],
        updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
      }, {merge: true}));
      await assertFails(existingChatRef.update({
        readAccessUserIds: ["organizer", "user-a", "other-user"],
        updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
      }));
      await assertFails(existingChatRef.delete());
    }
  });

test("clients cannot hard delete active or canceled event chat documents", async () => {
  const contexts = [
    testEnv.unauthenticatedContext(),
    testEnv.authenticatedContext("user-a"),
    testEnv.authenticatedContext("organizer"),
    testEnv.authenticatedContext("admin-user", {admin: true}),
  ];
  const chatPaths = [
    "eventChats/editable-event",
    "eventChats/canceled-editable-event",
  ];

  for (const context of contexts) {
    for (const chatPath of chatPaths) {
      await assertFails(context.firestore().doc(chatPath).delete());
    }
  }
});

test("client cancel cannot be paired with event chat access snapshot writes", async () => {
  const organizer = testEnv.authenticatedContext("organizer");
  const db = organizer.firestore();
  const batch = db.batch();

  await assertFails(db.doc("eventChats/direct-create").set(eventChatData({
    eventId: "direct-create",
  })));
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
  const eventRef = organizer.firestore().doc("events/canceled-editable-event");

  await assertFails(
    eventRef.update({
      status: "active",
      canceledAt: null,
      updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    }),
  );
  await assertFails(
    eventRef.update({
      status: "active",
      updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    }),
  );
  await assertFails(
    eventRef.update({
      canceledAt: null,
      updatedAt: firebaseCompat.firestore.FieldValue.serverTimestamp(),
    }),
  );
  await assertFails(
    eventRef.update(directCancelPatch()),
  );
});
