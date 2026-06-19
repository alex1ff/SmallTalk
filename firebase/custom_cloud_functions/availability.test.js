const test = require("node:test");
const assert = require("node:assert/strict");
const {
  evaluateTutorAvailabilityWindow,
} = require("./availability");

test("structured daily availability disables stale top-level availability", () => {
  const result = evaluateTutorAvailabilityWindow({
    role: "native_speaker",
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

test("student role ignores daily and legacy availability fields", () => {
  const result = evaluateTutorAvailabilityWindow({
    role: "student",
    isAvailable: false,
    availabilityToday: {
      enabled: false,
      intervals: [{start: "09:00", end: "18:00"}],
    },
  });

  assert.equal(result.isAvailable, true);
  assert.equal(result.reason, "student_availability_ignored");
});
