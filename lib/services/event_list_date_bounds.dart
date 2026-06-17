import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class EventListLocalDateRange {
  const EventListLocalDateRange({
    required this.startDate,
    required this.exclusiveEndDate,
  });

  final DateTime startDate;
  final DateTime exclusiveEndDate;
}

class EventListDateBounds {
  const EventListDateBounds({
    required this.lowerBoundUtc,
    required this.upperBoundUtc,
  });

  final DateTime lowerBoundUtc;
  final DateTime upperBoundUtc;
}

enum EventListDateFilter {
  today,
  tomorrow,
  currentWeek,
  currentMonth,
}

EventListDateBounds computeEventListDateBounds({
  required String timeZoneId,
  required EventListLocalDateRange localDateRange,
  required DateTime nowUtc,
}) {
  return computeEventListDateBoundsForLocation(
    location: eventListTimeZoneLocation(timeZoneId),
    localDateRange: localDateRange,
    nowUtc: nowUtc,
  );
}

EventListDateBounds computeEventListDateBoundsForLocation({
  required timezone.Location location,
  required EventListLocalDateRange localDateRange,
  required DateTime nowUtc,
}) {
  if (!nowUtc.isUtc) {
    throw ArgumentError.value(
      nowUtc,
      'nowUtc',
      'Expected a UTC DateTime.',
    );
  }

  final range = _normalizeLocalDateRange(localDateRange);
  final rangeStartUtc = _localMidnightUtc(location, range.startDate);
  final rangeEndUtc = _localMidnightUtc(location, range.exclusiveEndDate);
  if (!rangeStartUtc.isBefore(rangeEndUtc)) {
    throw ArgumentError.value(
      localDateRange,
      'localDateRange',
      'Expected the exclusive end date to be after the start date.',
    );
  }

  final lowerBoundUtc = nowUtc.isAfter(rangeStartUtc) ? nowUtc : rangeStartUtc;
  if (!lowerBoundUtc.isBefore(rangeEndUtc)) {
    throw ArgumentError.value(
      nowUtc,
      'nowUtc',
      'Expected nowUtc to be before the exclusive upper bound.',
    );
  }

  return EventListDateBounds(
    lowerBoundUtc: lowerBoundUtc,
    upperBoundUtc: rangeEndUtc,
  );
}

EventListLocalDateRange eventListDateFilterLocalDateRange({
  required EventListDateFilter dateFilter,
  required String timeZoneId,
  required DateTime nowUtc,
}) {
  return eventListDateFilterLocalDateRangeForLocation(
    dateFilter: dateFilter,
    location: eventListTimeZoneLocation(timeZoneId),
    nowUtc: nowUtc,
  );
}

EventListLocalDateRange eventListDateFilterLocalDateRangeForLocation({
  required EventListDateFilter dateFilter,
  required timezone.Location location,
  required DateTime nowUtc,
}) {
  final today = eventListCityLocalDateForLocation(
    location: location,
    utcInstant: nowUtc,
  );

  return switch (dateFilter) {
    EventListDateFilter.today => eventListSingleLocalDateRange(today),
    EventListDateFilter.tomorrow => eventListSingleLocalDateRange(
        DateTime(today.year, today.month, today.day + 1),
      ),
    EventListDateFilter.currentWeek => EventListLocalDateRange(
        startDate: DateTime(
          today.year,
          today.month,
          today.day - (today.weekday - DateTime.monday),
        ),
        exclusiveEndDate: DateTime(
          today.year,
          today.month,
          today.day + (DateTime.daysPerWeek - today.weekday + 1),
        ),
      ),
    EventListDateFilter.currentMonth => EventListLocalDateRange(
        startDate: DateTime(today.year, today.month),
        exclusiveEndDate: DateTime(today.year, today.month + 1),
      ),
  };
}

DateTime eventListCityLocalDate({
  required String timeZoneId,
  required DateTime utcInstant,
}) {
  return eventListCityLocalDateForLocation(
    location: eventListTimeZoneLocation(timeZoneId),
    utcInstant: utcInstant,
  );
}

DateTime eventListCityLocalDateForLocation({
  required timezone.Location location,
  required DateTime utcInstant,
}) {
  if (!utcInstant.isUtc) {
    throw ArgumentError.value(
      utcInstant,
      'utcInstant',
      'Expected a UTC DateTime.',
    );
  }

  final cityInstant = timezone.TZDateTime.from(utcInstant, location);
  return DateTime(cityInstant.year, cityInstant.month, cityInstant.day);
}

void initializeEventListTimeZones() {
  timezone_data.initializeTimeZones();
}

timezone.Location eventListTimeZoneLocation(String timeZoneId) {
  final normalizedTimeZoneId = timeZoneId.trim();
  if (normalizedTimeZoneId.isEmpty) {
    throw ArgumentError.value(
      timeZoneId,
      'timeZoneId',
      'Expected an IANA time zone id.',
    );
  }

  try {
    return timezone.getLocation(normalizedTimeZoneId);
  } on timezone.LocationNotFoundException {
    throw ArgumentError.value(
      timeZoneId,
      'timeZoneId',
      'Expected an IANA time zone id.',
    );
  }
}

EventListLocalDateRange eventListSingleLocalDateRange(DateTime localDate) {
  final startDate = _normalizeLocalDate(localDate, 'localDate');
  return EventListLocalDateRange(
    startDate: startDate,
    exclusiveEndDate: DateTime(
      startDate.year,
      startDate.month,
      startDate.day + 1,
    ),
  );
}

EventListLocalDateRange _normalizeLocalDateRange(
  EventListLocalDateRange range,
) {
  final startDate = _normalizeLocalDate(range.startDate, 'startDate');
  final exclusiveEndDate = _normalizeLocalDate(
    range.exclusiveEndDate,
    'exclusiveEndDate',
  );
  if (!startDate.isBefore(exclusiveEndDate)) {
    throw ArgumentError.value(
      range,
      'localDateRange',
      'Expected the exclusive end date to be after the start date.',
    );
  }
  return EventListLocalDateRange(
    startDate: startDate,
    exclusiveEndDate: exclusiveEndDate,
  );
}

DateTime _normalizeLocalDate(DateTime value, String name) {
  if (value.hour != 0 ||
      value.minute != 0 ||
      value.second != 0 ||
      value.millisecond != 0 ||
      value.microsecond != 0) {
    throw ArgumentError.value(
      value,
      name,
      'Expected a local calendar date at midnight.',
    );
  }
  return DateTime(value.year, value.month, value.day);
}

DateTime _localMidnightUtc(timezone.Location location, DateTime localDate) {
  final utcInstant = timezone.TZDateTime(
    location,
    localDate.year,
    localDate.month,
    localDate.day,
  ).toUtc();
  return DateTime.fromMicrosecondsSinceEpoch(
    utcInstant.microsecondsSinceEpoch,
    isUtc: true,
  );
}
