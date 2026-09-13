const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __private__: {
    buildDailyRoomDeletePatch,
  },
} = require("./daily_room_cleanup");
const {
  __private__: {
    buildSkippedFailedDailyRoomDeletePatch,
    cleanupFailedDailyRoomDeleteDocs,
    normalizeDailyRoomName,
    resolveFailedDailyRoomDeleteName,
  },
} = require("./cleanup_failed_daily_room_deletes");

function isDeleteSentinel(value) {
  return value?.constructor?.name === "DeleteTransform";
}

test("Daily room cleanup status records success and clears retry fields", () => {
  const patch = buildDailyRoomDeletePatch({
    source: "endSession",
    roomName: "session_123",
    deleted: true,
  });

  assert.equal(patch["sessionMetadata.dailyRoomDeleteSource"], "endSession");
  assert.equal(patch["sessionMetadata.dailyRoomDeleteRoomName"], "session_123");
  assert.ok(patch["sessionMetadata.dailyRoomDeleteAttemptedAt"]);
  assert.ok(patch["sessionMetadata.dailyRoomDeletedAt"]);
  assert.ok(isDeleteSentinel(patch["sessionMetadata.dailyRoomDeleteFailedAt"]));
  assert.ok(isDeleteSentinel(patch["sessionMetadata.dailyRoomDeleteError"]));
});

test("Daily room cleanup status records retry signal on failure", () => {
  const patch = buildDailyRoomDeletePatch({
    source: "cancelCall",
    roomName: "session_failed",
    deleted: false,
  });

  assert.equal(patch["sessionMetadata.dailyRoomDeleteSource"], "cancelCall");
  assert.equal(
    patch["sessionMetadata.dailyRoomDeleteError"],
    "Daily room deletion failed; retry required",
  );
  assert.ok(patch["sessionMetadata.dailyRoomDeleteFailedAt"]);
  assert.equal(patch["sessionMetadata.dailyRoomDeletedAt"], undefined);
});

test("failed Daily room delete retry accepts only safe Daily room names", () => {
  assert.equal(normalizeDailyRoomName("room-123_ok"), "room-123_ok");
  assert.equal(normalizeDailyRoomName("bad/room"), null);
  assert.equal(normalizeDailyRoomName("bad room"), null);
  assert.equal(normalizeDailyRoomName(""), null);
});

test("failed Daily room delete retry resolves the recorded room first", () => {
  assert.equal(
    resolveFailedDailyRoomDeleteName({
      dailyRoomName: "current_room",
      sessionMetadata: {
        dailyRoomDeleteRoomName: "failed_room",
      },
    }),
    "failed_room",
  );
  assert.equal(
    resolveFailedDailyRoomDeleteName({
      dailyRoomName: "current_room",
      status: "ended",
    }),
    "current_room",
  );
  assert.equal(
    resolveFailedDailyRoomDeleteName({
      dailyRoomUrl: "https://smalltalk.daily.co/url_room",
      status: "cancelled",
    }),
    "url_room",
  );
  assert.equal(
    resolveFailedDailyRoomDeleteName({
      dailyRoomName: "current_room",
      status: "active",
    }),
    null,
  );
  assert.equal(
    resolveFailedDailyRoomDeleteName({
      dailyRoomName: "current_room",
      sessionMetadata: {
        dailyRoomDeleteRoomName: "bad/room",
      },
      status: "ended",
    }),
    null,
  );
  assert.equal(resolveFailedDailyRoomDeleteName({}), null);
});

test("failed Daily room delete retry skip patch quarantines unsafe docs", () => {
  const patch = buildSkippedFailedDailyRoomDeletePatch();

  assert.equal(
    patch["sessionMetadata.dailyRoomDeleteSource"],
    "cleanupFailedDailyRoomDeletes",
  );
  assert.ok(patch["sessionMetadata.dailyRoomDeleteSkippedAt"]);
  assert.ok(isDeleteSentinel(patch["sessionMetadata.dailyRoomDeleteFailedAt"]));
  assert.equal(
    patch["sessionMetadata.dailyRoomDeleteError"],
    "Daily room deletion retry skipped; room name missing or unsafe",
  );
});

test("failed Daily room delete retry uses existing session cleanup helper", async () => {
  const calls = [];
  const skippedPatches = [];
  const docs = [
    {
      id: "session-a",
      data: () => ({
        sessionMetadata: {
          dailyRoomDeleteRoomName: "room-a",
        },
      }),
    },
    {
      id: "session-b",
      data: () => ({
        dailyRoomName: "room-b",
        status: "ended",
      }),
    },
    {
      id: "session-c",
      data: () => ({}),
      ref: {
        update: async (patch) => {
          skippedPatches.push(patch);
        },
      },
    },
  ];

  const result = await cleanupFailedDailyRoomDeleteDocs({
    db: { marker: "db" },
    docs,
    logger: {
      warn() {},
      error() {},
    },
    deleteRoomForSession: async (args) => {
      calls.push(args);
      return args.roomName === "room-a";
    },
  });

  assert.deepEqual(
    calls.map(({ sessionId, roomName, source }) => ({
      sessionId,
      roomName,
      source,
    })),
    [
      {
        sessionId: "session-a",
        roomName: "room-a",
        source: "cleanupFailedDailyRoomDeletes",
      },
      {
        sessionId: "session-b",
        roomName: "room-b",
        source: "cleanupFailedDailyRoomDeletes",
      },
    ],
  );
  assert.deepEqual(result, {
    scanned: 3,
    attempted: 2,
    deleted: 1,
    failed: 1,
    skipped: 1,
    quarantined: 1,
  });
  assert.equal(skippedPatches.length, 1);
  assert.ok(
    isDeleteSentinel(
      skippedPatches[0]["sessionMetadata.dailyRoomDeleteFailedAt"],
    ),
  );
});
