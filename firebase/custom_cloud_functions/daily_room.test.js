const test = require("node:test");
const assert = require("node:assert/strict");

const {
  DAILY_ROOM_CONFIG_VERSION,
  isDailyRoomConfigCompatible,
  __private__: {
    DAILY_ROOM_ENFORCE_UNIQUE_USER_IDS,
    DAILY_ROOM_MAX_PARTICIPANTS,
    buildRoomConfig,
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
