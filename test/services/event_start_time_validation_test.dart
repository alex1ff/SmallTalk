import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/event_list_date_bounds.dart';
import 'package:small_talk/services/event_start_time_validation.dart';

void main() {
  setUpAll(initializeEventListTimeZones);

  group('eventStartTimeUtc', () {
    test('converts city local wall time to UTC', () {
      expect(
        eventStartTimeUtc(
          localDate: DateTime(2026, 6, 18),
          localTime: const TimeOfDay(hour: 18, minute: 30),
          timeZoneId: 'Europe/Moscow',
        ),
        DateTime.parse('2026-06-18T15:30:00Z'),
      );
      expect(
        eventStartTimeUtc(
          localDate: DateTime(2026, 6, 18),
          localTime: const TimeOfDay(hour: 18, minute: 30),
          timeZoneId: 'America/New_York',
        ),
        DateTime.parse('2026-06-18T22:30:00Z'),
      );
      expect(
        eventStartTimeUtc(
          localDate: DateTime(2026, 6, 18),
          localTime: const TimeOfDay(hour: 18, minute: 30),
          timeZoneId: 'Europe/Rome',
        ),
        DateTime.parse('2026-06-18T16:30:00Z'),
      );
    });

    test('uses city timezone instead of device timezone for same wall time',
        () {
      final moscowStartsAt = eventStartTimeUtc(
        localDate: DateTime(2026, 11, 1),
        localTime: const TimeOfDay(hour: 9, minute: 0),
        timeZoneId: 'Europe/Moscow',
      );
      final newYorkStartsAt = eventStartTimeUtc(
        localDate: DateTime(2026, 11, 1),
        localTime: const TimeOfDay(hour: 9, minute: 0),
        timeZoneId: 'America/New_York',
      );

      expect(moscowStartsAt, isNot(newYorkStartsAt));
      expect(moscowStartsAt, DateTime.parse('2026-11-01T06:00:00Z'));
      expect(newYorkStartsAt, DateTime.parse('2026-11-01T14:00:00Z'));
    });
  });

  group('validateEventStartTime', () {
    test('accepts only startsAt values strictly after trusted now', () {
      final future = validateEventStartTime(
        localDate: DateTime(2026, 6, 18),
        localTime: const TimeOfDay(hour: 18, minute: 1),
        timeZoneId: 'Europe/Moscow',
        nowUtc: DateTime.parse('2026-06-18T15:00:00Z'),
      );
      final equal = validateEventStartTime(
        localDate: DateTime(2026, 6, 18),
        localTime: const TimeOfDay(hour: 18, minute: 0),
        timeZoneId: 'Europe/Moscow',
        nowUtc: DateTime.parse('2026-06-18T15:00:00Z'),
      );
      final past = validateEventStartTime(
        localDate: DateTime(2026, 6, 18),
        localTime: const TimeOfDay(hour: 17, minute: 59),
        timeZoneId: 'Europe/Moscow',
        nowUtc: DateTime.parse('2026-06-18T15:00:00Z'),
      );

      expect(future.isFuture, isTrue);
      expect(future.reason, isNull);
      expect(equal.isFuture, isFalse);
      expect(equal.reason, eventStartTimePastReason);
      expect(past.isFuture, isFalse);
      expect(past.reason, eventStartTimePastReason);
    });

    test('rejects non-UTC trusted now and unknown timezone ids', () {
      expect(
        () => validateEventStartTime(
          localDate: DateTime(2026, 6, 18),
          localTime: const TimeOfDay(hour: 18, minute: 0),
          timeZoneId: 'Europe/Moscow',
          nowUtc: DateTime(2026, 6, 18, 15),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => validateEventStartTime(
          localDate: DateTime(2026, 6, 18),
          localTime: const TimeOfDay(hour: 18, minute: 0),
          timeZoneId: 'Not/AZone',
          nowUtc: DateTime.parse('2026-06-18T15:00:00Z'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
