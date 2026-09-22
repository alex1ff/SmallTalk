import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as timezone;

import '/services/event_list_date_bounds.dart';

const String eventStartTimePastReason = 'past_starts_at';

class EventStartTimeValidationResult {
  const EventStartTimeValidationResult({
    required this.startsAtUtc,
    required this.isFuture,
    this.reason,
  });

  final DateTime startsAtUtc;
  final bool isFuture;
  final String? reason;
}

DateTime eventStartTimeUtc({
  required DateTime localDate,
  required TimeOfDay localTime,
  required String timeZoneId,
}) {
  return eventStartTimeUtcForLocation(
    localDate: localDate,
    localTime: localTime,
    location: eventListTimeZoneLocation(timeZoneId),
  );
}

DateTime eventStartTimeUtcForLocation({
  required DateTime localDate,
  required TimeOfDay localTime,
  required timezone.Location location,
}) {
  final localDateOnly = DateTime(
    localDate.year,
    localDate.month,
    localDate.day,
  );
  final startsAt = timezone.TZDateTime(
    location,
    localDateOnly.year,
    localDateOnly.month,
    localDateOnly.day,
    localTime.hour,
    localTime.minute,
  ).toUtc();
  return DateTime.fromMicrosecondsSinceEpoch(
    startsAt.microsecondsSinceEpoch,
    isUtc: true,
  );
}

EventStartTimeValidationResult validateEventStartTime({
  required DateTime localDate,
  required TimeOfDay localTime,
  required String timeZoneId,
  required DateTime nowUtc,
}) {
  if (!nowUtc.isUtc) {
    throw ArgumentError.value(
      nowUtc,
      'nowUtc',
      'Expected a UTC DateTime.',
    );
  }
  final startsAtUtc = eventStartTimeUtc(
    localDate: localDate,
    localTime: localTime,
    timeZoneId: timeZoneId,
  );
  final isFuture = startsAtUtc.isAfter(nowUtc);
  return EventStartTimeValidationResult(
    startsAtUtc: startsAtUtc,
    isFuture: isFuture,
    reason: isFuture ? null : eventStartTimePastReason,
  );
}
