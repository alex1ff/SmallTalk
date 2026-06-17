import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/event_list_date_bounds.dart';

void main() {
  setUpAll(initializeEventListTimeZones);

  group('computeEventListDateBounds', () {
    test('uses city local midnight and clamps lower bound to now', () {
      final bounds = computeEventListDateBounds(
        timeZoneId: 'America/New_York',
        localDateRange: eventListSingleLocalDateRange(DateTime(2026, 2, 10)),
        nowUtc: DateTime.parse('2026-02-10T14:30:00Z'),
      );

      expect(bounds.lowerBoundUtc, DateTime.parse('2026-02-10T14:30:00Z'));
      expect(bounds.upperBoundUtc, DateTime.parse('2026-02-11T05:00:00Z'));
    });

    test('keeps city local midnight when now is before the selected range', () {
      final bounds = computeEventListDateBounds(
        timeZoneId: 'Europe/Moscow',
        localDateRange: eventListSingleLocalDateRange(DateTime(2026, 6, 18)),
        nowUtc: DateTime.parse('2026-06-17T12:00:00Z'),
      );

      expect(bounds.lowerBoundUtc, DateTime.parse('2026-06-17T21:00:00Z'));
      expect(bounds.upperBoundUtc, DateTime.parse('2026-06-18T21:00:00Z'));
    });

    test('uses an exclusive upper bound at the next local midnight', () {
      final bounds = computeEventListDateBounds(
        timeZoneId: 'Asia/Dubai',
        localDateRange: eventListSingleLocalDateRange(DateTime(2026, 6, 18)),
        nowUtc: DateTime.parse('2026-06-17T00:00:00Z'),
      );

      expect(bounds.lowerBoundUtc, DateTime.parse('2026-06-17T20:00:00Z'));
      expect(bounds.upperBoundUtc, DateTime.parse('2026-06-18T20:00:00Z'));
    });

    test('does not assume every local day is 24 hours at DST start', () {
      final bounds = computeEventListDateBounds(
        timeZoneId: 'America/New_York',
        localDateRange: eventListSingleLocalDateRange(DateTime(2026, 3, 8)),
        nowUtc: DateTime.parse('2026-03-01T00:00:00Z'),
      );

      expect(bounds.lowerBoundUtc, DateTime.parse('2026-03-08T05:00:00Z'));
      expect(bounds.upperBoundUtc, DateTime.parse('2026-03-09T04:00:00Z'));
      expect(
        bounds.upperBoundUtc.difference(bounds.lowerBoundUtc),
        const Duration(hours: 23),
      );
    });

    test('does not assume every local day is 24 hours at DST end', () {
      final bounds = computeEventListDateBounds(
        timeZoneId: 'America/New_York',
        localDateRange: eventListSingleLocalDateRange(DateTime(2026, 11, 1)),
        nowUtc: DateTime.parse('2026-10-25T00:00:00Z'),
      );

      expect(bounds.lowerBoundUtc, DateTime.parse('2026-11-01T04:00:00Z'));
      expect(bounds.upperBoundUtc, DateTime.parse('2026-11-02T05:00:00Z'));
      expect(
        bounds.upperBoundUtc.difference(bounds.lowerBoundUtc),
        const Duration(hours: 25),
      );
    });

    test('supports multi-day local ranges without UTC day arithmetic', () {
      final bounds = computeEventListDateBounds(
        timeZoneId: 'America/New_York',
        localDateRange: EventListLocalDateRange(
          startDate: DateTime(2026, 3, 7),
          exclusiveEndDate: DateTime(2026, 3, 10),
        ),
        nowUtc: DateTime.parse('2026-03-01T00:00:00Z'),
      );

      expect(bounds.lowerBoundUtc, DateTime.parse('2026-03-07T05:00:00Z'));
      expect(bounds.upperBoundUtc, DateTime.parse('2026-03-10T04:00:00Z'));
    });

    test('rejects unknown time zones and non-UTC now', () {
      expect(
        () => computeEventListDateBounds(
          timeZoneId: 'Not/AZone',
          localDateRange: eventListSingleLocalDateRange(DateTime(2026, 6, 18)),
          nowUtc: DateTime.parse('2026-06-17T00:00:00Z'),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => computeEventListDateBounds(
          timeZoneId: 'Europe/Moscow',
          localDateRange: eventListSingleLocalDateRange(DateTime(2026, 6, 18)),
          nowUtc: DateTime(2026, 6, 17),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects ranges that are already exhausted by now', () {
      expect(
        () => computeEventListDateBounds(
          timeZoneId: 'Europe/Moscow',
          localDateRange: eventListSingleLocalDateRange(DateTime(2026, 6, 18)),
          nowUtc: DateTime.parse('2026-06-18T21:00:00Z'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('eventListCityLocalDate', () {
    test('derives selected city local date from a UTC instant', () {
      expect(
        eventListCityLocalDate(
          timeZoneId: 'Europe/Moscow',
          utcInstant: DateTime.parse('2026-06-17T21:30:00Z'),
        ),
        DateTime(2026, 6, 18),
      );
      expect(
        eventListCityLocalDate(
          timeZoneId: 'America/New_York',
          utcInstant: DateTime.parse('2026-06-18T03:30:00Z'),
        ),
        DateTime(2026, 6, 17),
      );
    });
  });

  group('eventListDateFilterLocalDateRange', () {
    test('builds today and tomorrow from the selected city local date', () {
      final today = eventListDateFilterLocalDateRange(
        dateFilter: EventListDateFilter.today,
        timeZoneId: 'Europe/Moscow',
        nowUtc: DateTime.parse('2026-06-17T21:30:00Z'),
      );
      final tomorrow = eventListDateFilterLocalDateRange(
        dateFilter: EventListDateFilter.tomorrow,
        timeZoneId: 'Europe/Moscow',
        nowUtc: DateTime.parse('2026-06-17T21:30:00Z'),
      );

      expect(today.startDate, DateTime(2026, 6, 18));
      expect(today.exclusiveEndDate, DateTime(2026, 6, 19));
      expect(tomorrow.startDate, DateTime(2026, 6, 19));
      expect(tomorrow.exclusiveEndDate, DateTime(2026, 6, 20));
    });

    test('builds the current Monday-start calendar week', () {
      final range = eventListDateFilterLocalDateRange(
        dateFilter: EventListDateFilter.currentWeek,
        timeZoneId: 'Europe/Moscow',
        nowUtc: DateTime.parse('2026-06-17T12:00:00Z'),
      );

      expect(range.startDate, DateTime(2026, 6, 15));
      expect(range.exclusiveEndDate, DateTime(2026, 6, 22));
    });

    test('keeps Sunday in the current week ending the next Monday', () {
      final range = eventListDateFilterLocalDateRange(
        dateFilter: EventListDateFilter.currentWeek,
        timeZoneId: 'Europe/Moscow',
        nowUtc: DateTime.parse('2026-06-21T12:00:00Z'),
      );

      expect(range.startDate, DateTime(2026, 6, 15));
      expect(range.exclusiveEndDate, DateTime(2026, 6, 22));
    });

    test('builds current month range with year rollover', () {
      final range = eventListDateFilterLocalDateRange(
        dateFilter: EventListDateFilter.currentMonth,
        timeZoneId: 'Europe/Moscow',
        nowUtc: DateTime.parse('2026-12-31T12:00:00Z'),
      );

      expect(range.startDate, DateTime(2026, 12));
      expect(range.exclusiveEndDate, DateTime(2027, 1));
    });

    test('lets UTC bounds clamp week and month ranges to now', () {
      final nowUtc = DateTime.parse('2026-06-17T12:00:00Z');
      final weekBounds = computeEventListDateBounds(
        timeZoneId: 'Europe/Moscow',
        localDateRange: eventListDateFilterLocalDateRange(
          dateFilter: EventListDateFilter.currentWeek,
          timeZoneId: 'Europe/Moscow',
          nowUtc: nowUtc,
        ),
        nowUtc: nowUtc,
      );
      final monthBounds = computeEventListDateBounds(
        timeZoneId: 'Europe/Moscow',
        localDateRange: eventListDateFilterLocalDateRange(
          dateFilter: EventListDateFilter.currentMonth,
          timeZoneId: 'Europe/Moscow',
          nowUtc: nowUtc,
        ),
        nowUtc: nowUtc,
      );

      expect(weekBounds.lowerBoundUtc, nowUtc);
      expect(weekBounds.upperBoundUtc, DateTime.parse('2026-06-21T21:00:00Z'));
      expect(monthBounds.lowerBoundUtc, nowUtc);
      expect(
        monthBounds.upperBoundUtc,
        DateTime.parse('2026-06-30T21:00:00Z'),
      );
    });

    test('keeps DST-sensitive week bounds on local midnights', () {
      final nowUtc = DateTime.parse('2026-03-09T12:00:00Z');
      final bounds = computeEventListDateBounds(
        timeZoneId: 'America/New_York',
        localDateRange: eventListDateFilterLocalDateRange(
          dateFilter: EventListDateFilter.currentWeek,
          timeZoneId: 'America/New_York',
          nowUtc: nowUtc,
        ),
        nowUtc: DateTime.parse('2026-03-01T00:00:00Z'),
      );

      expect(bounds.lowerBoundUtc, DateTime.parse('2026-03-09T04:00:00Z'));
      expect(bounds.upperBoundUtc, DateTime.parse('2026-03-16T04:00:00Z'));
    });

    test('rejects unknown time zones and non-UTC now', () {
      expect(
        () => eventListDateFilterLocalDateRange(
          dateFilter: EventListDateFilter.today,
          timeZoneId: 'Not/AZone',
          nowUtc: DateTime.parse('2026-06-17T00:00:00Z'),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => eventListDateFilterLocalDateRange(
          dateFilter: EventListDateFilter.today,
          timeZoneId: 'Europe/Moscow',
          nowUtc: DateTime(2026, 6, 17),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
