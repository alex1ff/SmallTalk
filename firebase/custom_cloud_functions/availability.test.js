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

test("structured daily availability uses teacher timezone intervals", () => {
  const result = evaluateTutorAvailabilityWindow(
    {
      role: "native_speaker",
      timezoneOffsetMinutes: 180,
      availabilityToday: {
        enabled: true,
        intervals: [{start: "14:00", end: "15:00"}],
      },
    },
    new Date("2026-05-26T11:30:00.000Z"),
  );

  assert.equal(result.isAvailable, true);
  assert.equal(result.reason, "within_interval");
  assert.equal(result.localTime, "14:30");
  assert.deepEqual(result.matchedInterval, {start: "14:00", end: "15:00"});
});

test("structured daily availability rejects outside and supports overnight windows", () => {
  const outside = evaluateTutorAvailabilityWindow(
    {
      role: "native_speaker",
      timezoneOffsetMinutes: 0,
      availabilityToday: {
        enabled: true,
        intervals: [{start: "09:00", end: "10:00"}],
      },
    },
    new Date("2026-05-26T10:00:00.000Z"),
  );
  const overnight = evaluateTutorAvailabilityWindow(
    {
      role: "native_speaker",
      timezoneOffsetMinutes: 0,
      availabilityToday: {
        enabled: true,
        intervals: [{start: "22:00", end: "02:00"}],
      },
    },
    new Date("2026-05-26T01:30:00.000Z"),
  );

  assert.equal(outside.isAvailable, false);
  assert.equal(outside.reason, "outside_interval");
  assert.equal(overnight.isAvailable, true);
  assert.equal(overnight.reason, "within_interval");
  assert.deepEqual(overnight.matchedInterval, {start: "22:00", end: "02:00"});
});
