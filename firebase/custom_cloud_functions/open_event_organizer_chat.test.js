const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __private__: {
    executeOpenEventOrganizerChatTransaction,
    openEventOrganizerChatHandler,
    normalizeOpenEventOrganizerChatPayload,
  },
} = require("./open_event_organizer_chat");

function assertHttpsError(fn, code, domainCode, field, reason) {
  assert.throws(fn, (err) => {
    assert.equal(err.code, code);
    assert.equal(err.details?.domainCode, domainCode);
    if (field) {
      assert.equal(err.details?.field, field);
    }
    if (reason) {
      assert.equal(err.details?.reason, reason);
    }
    return true;
  });
}

async function assertRejectsHttpsError(promiseFactory, code, domainCode) {
  await assert.rejects(promiseFactory, (err) => {
    assert.equal(err.code, code);
    assert.equal(err.details?.domainCode, domainCode);
    return true;
  });
}

function createFakeFirestore(seed = {}) {
  const store = new Map(Object.entries(seed));
  const reads = [];
  const writes = [];

  const makeRef = (path) => ({
    path,
    id: path.split("/").pop(),
    collection(name) {
      return makeCollection(`${path}/${name}`);
    },
    async get() {
      const data = store.get(path);
      return {
        exists: data !== undefined,
        data: () => data,
        ref: makeRef(path),
      };
    },
  });

  const makeCollection = (path) => ({
    doc(id) {
      return makeRef(`${path}/${id}`);
    },
  });

  const db = {
    collection(name) {
      return makeCollection(name);
    },
    doc(path) {
      return makeRef(path);
    },
    async runTransaction(callback) {
      let hasWrites = false;
      const pendingWrites = [];
      const tx = {
        async get(ref) {
          if (hasWrites) {
            throw new Error("Firestore transactions require reads first");
          }
          reads.push(ref.path);
          return ref.get();
        },
        set(ref, data, options = {}) {
          hasWrites = true;
          pendingWrites.push({
            type: "set",
            path: ref.path,
            data,
            merge: options.merge === true,
          });
        },
      };
      const result = await callback(tx);
      for (const write of pendingWrites) {
        writes.push(write);
        store.set(
            write.path,
            write.merge ? {...store.get(write.path), ...write.data} : write.data,
        );
      }
      return result;
    },
  };

  return {db, reads, store, writes};
}

function activeEvent(overrides = {}) {
  return {
    organizerId: "organizer-1",
    status: "active",
    ...overrides,
  };
}

test("normalizeOpenEventOrganizerChatPayload validates exact event id", () => {
  assert.deepEqual(
      normalizeOpenEventOrganizerChatPayload({eventId: " event-1 "}),
      {eventId: "event-1"},
  );

  assertHttpsError(
      () => normalizeOpenEventOrganizerChatPayload({eventId: ""}),
      "invalid-argument",
      "invalid_event_organizer_chat_request",
      "eventId",
      "invalid_format",
  );
  assertHttpsError(
      () => normalizeOpenEventOrganizerChatPayload({
        eventId: "event-1",
        extra: true,
      }),
      "invalid-argument",
      "invalid_event_organizer_chat_request",
      "extra",
      "unknown_key",
  );
});

test("executeOpenEventOrganizerChatTransaction creates unlocked conversation",
    async () => {
      const {db, reads, store, writes} = createFakeFirestore({
        "events/event-1": activeEvent(),
        "userPublicProfiles/organizer-1": {
          display_name: "Organizer",
          photo_url: "https://img/organizer",
          email: "must-not-copy@example.com",
        },
        "userPublicProfiles/student-1": {
          display_name: "Student",
          photo_url: null,
        },
      });

      const result = await executeOpenEventOrganizerChatTransaction({
        db,
        eventId: "event-1",
        requesterId: "student-1",
      });

      assert.deepEqual(reads, [
        "events/event-1",
        "conversations/organizer-1_student-1",
        "userPublicProfiles/organizer-1",
        "userPublicProfiles/student-1",
      ]);
      assert.equal(result.conversationId, "organizer-1_student-1");
      assert.equal(
          result.conversationPath,
          "conversations/organizer-1_student-1",
      );
      assert.equal(writes.length, 1);

      const conversation = store.get("conversations/organizer-1_student-1");
      assert.equal(conversation.pairId, "organizer-1_student-1");
      assert.deepEqual(conversation.participantIds, [
        "organizer-1",
        "student-1",
      ]);
      assert.deepEqual(conversation.participantMap, {
        "organizer-1": true,
        "student-1": true,
      });
      assert.deepEqual(conversation.participantInfoByUserId, {
        "organizer-1": {
          displayName: "Organizer",
          photoUrl: "https://img/organizer",
        },
        "student-1": {displayName: "Student", photoUrl: null},
      });
      assert.deepEqual(
          conversation.participantRefs.map((ref) => ref.path),
          ["users/organizer-1", "users/student-1"],
      );
      assert.equal(conversation.isUnlocked, true);
    });

test("executeOpenEventOrganizerChatTransaction reuses unlocked conversation",
    async () => {
      const existingConversation = {
        pairId: "organizer-1_student-1",
        participantIds: ["organizer-1", "student-1"],
        participantMap: {"organizer-1": true, "student-1": true},
        participantInfoByUserId: {
          "organizer-1": {
            displayName: "Old organizer",
            photoUrl: "https://old/organizer",
          },
        },
        isUnlocked: true,
      };
      const {db, store, writes} = createFakeFirestore({
        "events/event-1": activeEvent(),
        "conversations/organizer-1_student-1": existingConversation,
        "userPublicProfiles/organizer-1": {
          display_name: "Current organizer",
          photo_url: null,
        },
        "userPublicProfiles/student-1": {
          display_name: "Student",
          photo_url: "https://img/student",
        },
      });

      const result = await executeOpenEventOrganizerChatTransaction({
        db,
        eventId: "event-1",
        requesterId: "student-1",
      });

      assert.equal(result.conversationPath, "conversations/organizer-1_student-1");
      assert.deepEqual(
          store.get("conversations/organizer-1_student-1")
              .participantInfoByUserId,
          {
            "organizer-1": {
              displayName: "Current organizer",
              photoUrl: null,
            },
            "student-1": {
              displayName: "Student",
              photoUrl: "https://img/student",
            },
          },
      );
      assert.equal(writes.length, 1);
    });

test("executeOpenEventOrganizerChatTransaction unlocks existing conversation",
    async () => {
      const {db, store, writes} = createFakeFirestore({
        "events/event-1": activeEvent(),
        "conversations/organizer-1_student-1": {
          pairId: "organizer-1_student-1",
          participantIds: ["organizer-1", "student-1"],
          participantMap: {"organizer-1": true, "student-1": true},
          isUnlocked: false,
        },
      });

      await executeOpenEventOrganizerChatTransaction({
        db,
        eventId: "event-1",
        requesterId: "student-1",
      });

      assert.equal(writes.length, 1);
      assert.equal(
          store.get("conversations/organizer-1_student-1").isUnlocked,
          true,
      );
    });

test("openEventOrganizerChat rejects missing auth", async () => {
  const {db} = createFakeFirestore({"events/event-1": activeEvent()});

  await assertRejectsHttpsError(
      () => openEventOrganizerChatHandler(
          {eventId: "event-1"},
          {},
          {db},
      ),
      "unauthenticated",
      "event_organizer_chat_requires_auth",
  );
});

test("executeOpenEventOrganizerChatTransaction rejects invalid events",
    async () => {
      await assertRejectsHttpsError(
          () => executeOpenEventOrganizerChatTransaction({
            db: createFakeFirestore({}).db,
            eventId: "event-1",
            requesterId: "student-1",
          }),
          "not-found",
          "event_not_found",
      );

      await assertRejectsHttpsError(
          () => executeOpenEventOrganizerChatTransaction({
            db: createFakeFirestore({
              "events/event-1": activeEvent({status: "canceled"}),
            }).db,
            eventId: "event-1",
            requesterId: "student-1",
          }),
          "failed-precondition",
          "event_not_active",
      );

      await assertRejectsHttpsError(
          () => executeOpenEventOrganizerChatTransaction({
            db: createFakeFirestore({
              "events/event-1": activeEvent({organizerId: ""}),
            }).db,
            eventId: "event-1",
            requesterId: "student-1",
          }),
          "failed-precondition",
          "event_organizer_missing",
      );

      await assertRejectsHttpsError(
          () => executeOpenEventOrganizerChatTransaction({
            db: createFakeFirestore({"events/event-1": activeEvent()}).db,
            eventId: "event-1",
            requesterId: "organizer-1",
          }),
          "failed-precondition",
          "event_organizer_chat_self",
      );
    });
