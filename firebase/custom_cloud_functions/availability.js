function normalizeOffsetMinutes(rawValue) {
  if (typeof rawValue === "number" && Number.isFinite(rawValue)) {
    return Math.trunc(rawValue);
  }

  if (typeof rawValue === "string" && rawValue.trim().length > 0) {
    const parsed = Number.parseInt(rawValue.trim(), 10);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }

  return null;
}

function parseTimeBoundary(rawValue) {
  if (typeof rawValue !== "string") {
    return null;
  }

  const match = rawValue.trim().match(/^(\d{1,2}):(\d{2})$/);
  if (!match) {
    return null;
  }

  const hours = Number.parseInt(match[1], 10);
  const minutes = Number.parseInt(match[2], 10);
  if (
    !Number.isInteger(hours) ||
    !Number.isInteger(minutes) ||
    hours < 0 ||
    hours > 23 ||
    minutes < 0 ||
    minutes > 59
  ) {
    return null;
  }

  return hours * 60 + minutes;
}

function normalizeIntervals(rawIntervals) {
  if (!Array.isArray(rawIntervals)) {
    return [];
  }

  return rawIntervals
    .map((interval) => {
      const start = interval && typeof interval === "object" ? interval.start : null;
      const end = interval && typeof interval === "object" ? interval.end : null;
      const startMinutes = parseTimeBoundary(start);
      const endMinutes = parseTimeBoundary(end);
      if (startMinutes === null || endMinutes === null) {
        return null;
      }

      return {
        start,
        end,
        startMinutes,
        endMinutes,
      };
    })
    .filter(Boolean);
}

function intervalContains(localMinutes, startMinutes, endMinutes) {
  if (startMinutes === endMinutes) {
    return false;
  }

  if (startMinutes < endMinutes) {
    return localMinutes >= startMinutes && localMinutes < endMinutes;
  }

  return localMinutes >= startMinutes || localMinutes < endMinutes;
}

function pad2(value) {
  return String(value).padStart(2, "0");
}

function evaluateTutorAvailabilityWindow(tutorData, now = new Date()) {
  const availabilityToday =
    tutorData && typeof tutorData.availabilityToday === "object"
      ? tutorData.availabilityToday
      : {};
  const enabled =
    tutorData && tutorData.isAvailable !== undefined
      ? Boolean(tutorData.isAvailable)
      : (availabilityToday.enabled ?? true);

  if (!enabled) {
    return {
      isAvailable: false,
      reason: "disabled",
      intervalCount: Array.isArray(availabilityToday.intervals)
        ? availabilityToday.intervals.length
        : 0,
    };
  }

  const intervals = normalizeIntervals(availabilityToday.intervals);
  if (intervals.length === 0) {
    return {
      isAvailable: true,
      reason: "enabled_without_intervals",
      intervalCount: 0,
    };
  }

  const timezoneOffsetMinutes = normalizeOffsetMinutes(
    tutorData?.timezoneOffsetMinutes ?? availabilityToday?.timezoneOffsetMinutes,
  );
  if (timezoneOffsetMinutes === null) {
    return {
      isAvailable: true,
      reason: "missing_timezone_offset",
      intervalCount: intervals.length,
    };
  }

  const shiftedNow = new Date(now.getTime() + timezoneOffsetMinutes * 60 * 1000);
  const localHours = shiftedNow.getUTCHours();
  const localMinutes = shiftedNow.getUTCMinutes();
  const localTotalMinutes = localHours * 60 + localMinutes;
  const matchedInterval = intervals.find((interval) =>
    intervalContains(
      localTotalMinutes,
      interval.startMinutes,
      interval.endMinutes,
    ),
  );

  return {
    isAvailable: Boolean(matchedInterval),
    reason: matchedInterval ? "within_interval" : "outside_interval",
    intervalCount: intervals.length,
    timezoneOffsetMinutes,
    localTime: `${pad2(localHours)}:${pad2(localMinutes)}`,
    matchedInterval: matchedInterval
      ? {
          start: matchedInterval.start,
          end: matchedInterval.end,
        }
      : null,
  };
}

module.exports = {
  evaluateTutorAvailabilityWindow,
};
