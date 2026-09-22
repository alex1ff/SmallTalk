const test = require("node:test");
const assert = require("node:assert/strict");

const {
  DAILY_ROOM_CONFIG_VERSION,
  isDailyRoomConfigCompatible,
  resolveDailyRoomName,
  __private__: {
    DAILY_ROOM_ENFORCE_UNIQUE_USER_IDS,
    DAILY_ROOM_MAX_PARTICIPANTS,
    buildRoomConfig,
    dailyPresenceHasAcceptedParticipants,
    dailyPresenceHasUser,
    isDailyRoomAlreadyDeletedError,
    readDailyPresenceParticipants,
  },
} = require("./daily_room");

test("Daily rooms keep retry headroom while staying private", () => {
  const config = buildRoomConfig({
    name: "session-test",
    language: "en",
    expSeconds: 900,
  });

  assert.equal(config.privacy, "private");
  assert.equal(config.properties.max_participants, DAILY_ROOM_MAX_PARTICIPANTS);
  assert.equal(config.properties.max_participants, 4);
  assert.equal(
    config.properties.enforce_unique_user_ids,
    DAILY_ROOM_ENFORCE_UNIQUE_USER_IDS,
  );
  assert.equal(config.properties.enforce_unique_user_ids, true);
  assert.equal(config.properties.enable_knocking, false);
  assert.equal(config.properties.geo, "eu-central-1");
});

test("Daily room compatibility rejects legacy two-seat rooms", () => {
  assert.equal(
    isDailyRoomConfigCompatible({
      config: {
        max_participants: 2,
        enforce_unique_user_ids: false,
      },
    }),
    false,
  );
});

test("Daily room compatibility accepts current room config", () => {
  const config = buildRoomConfig({
    name: "session-test",
    language: "en",
    expSeconds: 900,
  });

  assert.equal(DAILY_ROOM_CONFIG_VERSION, 2);
  assert.equal(isDailyRoomConfigCompatible({ config: config.properties }), true);
});

test("resolveDailyRoomName falls back to room URL", () => {
  assert.equal(
    resolveDailyRoomName({
      dailyRoomName: "",
      dailyRoomUrl: "https://smalltalk.daily.co/session_123",
    }),
    "session_123",
  );
  assert.equal(
    resolveDailyRoomName({
      dailyRoomName: " session_named ",
      dailyRoomUrl: "https://smalltalk.daily.co/session_ignored",
    }),
    "session_named",
  );
});

test("Daily room deletion treats missing rooms as already cleaned", () => {
  assert.equal(
    isDailyRoomAlreadyDeletedError({ response: { status: 404 } }),
    true,
  );
  assert.equal(
    isDailyRoomAlreadyDeletedError({
      response: { status: 400, data: { deleted: true } },
    }),
    true,
  );
  assert.equal(
    isDailyRoomAlreadyDeletedError({ response: { status: 500 } }),
    false,
  );
});

test("Daily presence helpers accept documented user id shapes", () => {
  const presenceData = {
    "session_room_a": [
      {user_id: "student-a", room: "session_room_a"},
      {userId: "teacher-b", room: "session_room_a"},
      null,
      "bad",
    ],
  };

  assert.equal(
    readDailyPresenceParticipants(presenceData, "session_room_a").length,
    2,
  );
  assert.equal(
    dailyPresenceHasUser(presenceData, "student-a", "session_room_a"),
    true,
  );
  assert.equal(
    dailyPresenceHasUser(presenceData, "teacher-b", "session_room_a"),
    true,
  );
  assert.equal(
    dailyPresenceHasUser(presenceData, "stranger", "session_room_a"),
    false,
  );
  assert.equal(
    dailyPresenceHasAcceptedParticipants({
      presenceData,
      roomName: "session_room_a",
      participantIds: ["student-a", "teacher-b"],
    }),
    true,
  );
  assert.equal(
    dailyPresenceHasAcceptedParticipants({
      presenceData,
      roomName: "session_room_a",
      participantIds: ["student-a", "stranger"],
    }),
    false,
  );
  assert.deepEqual(readDailyPresenceParticipants({participants: "bad"}), []);
});
