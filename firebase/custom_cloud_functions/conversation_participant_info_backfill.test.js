const test = require("node:test");
const assert = require("node:assert/strict");

const {
  backfillConversationParticipantInfo,
  buildConversationParticipantInfoBackfillUpdate,
} = require("./scripts/backfill_conversation_participant_info");

function fakeBackfillDb({updateError = null} = {}) {
  const conversations = ["a", "b", "c"].map((id) => ({
    id,
    ref: {id, path: `conversations/${id}`},
    updateTime: `revision-${id}`,
    data: () => ({participantIds: [`user-${id}`]}),
  }));
  const writes = [];
  const state = {writerClosed: false};
  const conversationQuery = (startAfterId = null, pageLimit = 50) => ({
    orderBy: () => conversationQuery(startAfterId, pageLimit),
    limit: (limit) => conversationQuery(startAfterId, limit),
    startAfter: (id) => conversationQuery(id, pageLimit),
    async get() {
      const startIndex = startAfterId ?
        conversations.findIndex((item) => item.id === startAfterId) + 1 :
        0;
      const docs = conversations.slice(startIndex, startIndex + pageLimit);
      return {docs, empty: docs.length === 0, size: docs.length};
    },
  });
  return {
    writes,
    state,
    collection(name) {
      if (name === "conversations") return conversationQuery();
      assert.equal(name, "userPublicProfiles");
      return {doc: (id) => ({id, path: `${name}/${id}`})};
    },
    async getAll(...refs) {
      return refs.map((ref) => ({
        id: ref.id,
        exists: true,
        data: () => ({display_name: `Name ${ref.id}`, photo_url: null}),
      }));
    },
    bulkWriter() {
      return {
        async update(ref, update, precondition) {
          if (updateError) throw updateError;
          writes.push({ref, update, precondition});
        },
        async close() {
          state.writerClosed = true;
        },
      };
    },
  };
}

test("participant identity backfill adds only missing public fields", () => {
  const update = buildConversationParticipantInfoBackfillUpdate(
    {
      participantIds: ["alice", "bob"],
      participantInfoByUserId: {
        alice: {displayName: "Existing Alice", photoUrl: null},
      },
      updatedAt: "must-not-change",
    },
    {
      alice: {display_name: "New Alice", photo_url: "https://img/alice"},
      bob: {
        display_name: "  Bob  ",
        photo_url: " https://img/bob ",
        email: "must-not-copy@example.com",
      },
      outsider: {display_name: "Must not copy"},
    },
  );

  assert.deepEqual(update, {
    participantInfoByUserId: {
      alice: {displayName: "Existing Alice", photoUrl: null},
      bob: {displayName: "Bob", photoUrl: "https://img/bob"},
    },
  });
  assert.equal(Object.hasOwn(update, "updatedAt"), false);
});

test("participant identity backfill closes writer after a fatal write error",
  async () => {
    const db = fakeBackfillDb({updateError: new Error("fatal write")});

    await assert.rejects(
        backfillConversationParticipantInfo({db, apply: true}),
        /fatal write/,
    );
    assert.equal(db.state.writerClosed, true);
  });

test("participant identity backfill is a no-op without missing fields", () => {
  assert.equal(
    buildConversationParticipantInfoBackfillUpdate(
      {
        participantIds: ["alice"],
        participantInfoByUserId: {
          alice: {displayName: "Alice", photoUrl: null},
        },
      },
      {alice: {display_name: "Changed", photo_url: "https://changed"}},
    ),
    null,
  );
});

test("participant identity backfill is bounded, resumable, and revision-safe",
  async () => {
    const dryRunDb = fakeBackfillDb();
    const firstRun = await backfillConversationParticipantInfo({
      db: dryRunDb,
      pageSize: 1,
      maxPages: 2,
    });
    assert.deepEqual(firstRun, {
      apply: false,
      scanned: 2,
      eligible: 2,
      written: 0,
      conflicts: 0,
      pages: 2,
      nextCursor: "b",
    });
    assert.equal(dryRunDb.writes.length, 0);

    const applyDb = fakeBackfillDb();
    const secondRun = await backfillConversationParticipantInfo({
      db: applyDb,
      apply: true,
      pageSize: 1,
      maxPages: 2,
      startAfterId: firstRun.nextCursor,
    });
    assert.equal(secondRun.scanned, 1);
    assert.equal(secondRun.written, 1);
    assert.equal(secondRun.nextCursor, null);
    assert.deepEqual(applyDb.writes[0].precondition, {
      lastUpdateTime: "revision-c",
    });
  });
