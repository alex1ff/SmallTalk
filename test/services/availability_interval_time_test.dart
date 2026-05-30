import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/availability_interval_time.dart';

void main() {
  group('availability interval time rules', () {
    test('rounds minutes up to the five-minute picker step', () {
      expect(roundAvailabilityIntervalMinutesUpToStep(9 * 60), 9 * 60);
      expect(
          roundAvailabilityIntervalMinutesUpToStep((9 * 60) + 1), 9 * 60 + 5);
      expect(roundAvailabilityIntervalMinutesUpToStep((9 * 60) + 59), 10 * 60);
    });

    test('builds initial one-hour interval from current time', () {
      final start = buildInitialAvailabilityIntervalStartTime(
        DateTime(2026, 5, 12, 9, 2),
      );
      final end = buildInitialAvailabilityIntervalEndTime(start);

      expect(start, DateTime(2026, 5, 12, 9, 5));
      expect(end, DateTime(2026, 5, 12, 10, 5));
    });

    test('clamps initial interval near the end of the day', () {
      final start = buildInitialAvailabilityIntervalStartTime(
        DateTime(2026, 5, 12, 23, 53),
      );
      final end = buildInitialAvailabilityIntervalEndTime(start);

      expect(start, DateTime(2026, 5, 12, 23, 50));
      expect(end, DateTime(2026, 5, 12, 23, 55));
    });

    test('parses and formats HH:mm values using the fallback day', () {
      final fallback = DateTime(2026, 5, 12, 9, 5);

      final parsed = parseAvailabilityIntervalTime(
        '7:03',
        fallback: fallback,
      );

      expect(parsed, DateTime(2026, 5, 12, 7, 3));
      expect(formatAvailabilityIntervalTime(parsed), '07:03');
    });

    test('returns fallback for invalid time strings', () {
      final fallback = DateTime(2026, 5, 12, 9, 5);

      expect(
        parseAvailabilityIntervalTime('24:00', fallback: fallback),
        fallback,
      );
      expect(
        parseAvailabilityIntervalTime('09:60', fallback: fallback),
        fallback,
      );
      expect(
        parseAvailabilityIntervalTime('bad', fallback: fallback),
        fallback,
      );
    });

    test('moves end after start when selected start crosses current end', () {
      final draft = updateAvailabilityIntervalDraft(
        field: AvailabilityIntervalField.start,
        selectedMinutes: 12 * 60,
        currentStartMinutes: 9 * 60,
        currentEndMinutes: 10 * 60,
      );

      expect(draft.startMinutes, 12 * 60);
      expect(draft.endMinutes, 12 * 60 + kAvailabilityIntervalMinuteStep);
    });

    test('keeps selected end at least one step after start', () {
      final draft = updateAvailabilityIntervalDraft(
        field: AvailabilityIntervalField.end,
        selectedMinutes: 9 * 60,
        currentStartMinutes: 10 * 60,
        currentEndMinutes: 11 * 60,
      );

      expect(draft.startMinutes, 10 * 60);
      expect(draft.endMinutes, 10 * 60 + kAvailabilityIntervalMinuteStep);
    });
  });
}
