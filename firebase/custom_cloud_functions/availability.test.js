const test = require("node:test");
const assert = require("node:assert/strict");
const {
  evaluateTutorAvailabilityWindow,
} = require("./availability");

test("structured daily availability disables stale top-level availability", () => {
  const result = evaluateTutorAvailabilityWindow({
    isAvailable: true,
    availabilityToday: {
      enabled: false,
      intervals: [{start: "09:00", end: "18:00"}],
    },
  });

  assert.equal(result.isAvailable, false);
  assert.equal(result.reason, "disabled");
});

test("top-level availability remains the fallback for legacy profiles", () => {
  const result = evaluateTutorAvailabilityWindow({
    isAvailable: false,
    availabilityToday: {
      intervals: [{start: "09:00", end: "18:00"}],
    },
  });

  assert.equal(result.isAvailable, false);
  assert.equal(result.reason, "disabled");
});
