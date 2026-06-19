import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/event_level_helper.dart';

void main() {
  group('eventLevelRange', () {
    test('keeps all six canonical levels in rank order', () {
      expect(eventLevelRanks.keys.toList(growable: false), [
        'A1',
        'A2',
        'B1',
        'B2',
        'C1',
        'C2',
      ]);

      for (final entry in eventLevelRanks.entries) {
        final range = eventLevelRange(
          levelMin: entry.key,
          levelMax: entry.key,
        );

        expect(range.levelMin, entry.key);
        expect(range.levelMax, entry.key);
        expect(range.minRank, entry.value);
        expect(range.maxRank, entry.value);
      }
    });

    test('normalizes canonical levels and checks inclusive overlap', () {
      final range = eventLevelRange(levelMin: ' b1 ', levelMax: ' c1 ');

      expect(range.levelMin, 'B1');
      expect(range.levelMax, 'C1');
      expect(range.minRank, eventLevelRanks['B1']);
      expect(range.maxRank, eventLevelRanks['C1']);
      expect(
        range.overlaps(eventLevelRange(levelMin: 'A2', levelMax: 'B1')),
        isTrue,
      );
      expect(
        range.overlaps(eventLevelRange(levelMin: 'C2', levelMax: 'C2')),
        isFalse,
      );
    });

    test('matches each selected level against event ranges by rank overlap',
        () {
      const cases = <({
        String selectedLevel,
        String eventMin,
        String eventMax,
        bool overlaps,
      })>[
        (selectedLevel: 'A1', eventMin: 'A1', eventMax: 'A1', overlaps: true),
        (selectedLevel: 'A1', eventMin: 'A2', eventMax: 'C2', overlaps: false),
        (selectedLevel: 'A2', eventMin: 'A1', eventMax: 'A2', overlaps: true),
        (selectedLevel: 'A2', eventMin: 'B1', eventMax: 'C2', overlaps: false),
        (selectedLevel: 'B1', eventMin: 'A2', eventMax: 'B1', overlaps: true),
        (selectedLevel: 'B1', eventMin: 'B2', eventMax: 'C2', overlaps: false),
        (selectedLevel: 'B2', eventMin: 'B2', eventMax: 'B2', overlaps: true),
        (selectedLevel: 'B2', eventMin: 'A1', eventMax: 'B1', overlaps: false),
        (selectedLevel: 'C1', eventMin: 'B2', eventMax: 'C1', overlaps: true),
        (selectedLevel: 'C1', eventMin: 'A1', eventMax: 'B2', overlaps: false),
        (selectedLevel: 'C2', eventMin: 'C2', eventMax: 'C2', overlaps: true),
        (selectedLevel: 'C2', eventMin: 'A1', eventMax: 'C1', overlaps: false),
      ];

      for (final currentCase in cases) {
        final selectedRange = selectedEventLevelRange(
          currentCase.selectedLevel,
        )!;
        final eventRange = eventLevelRange(
          levelMin: currentCase.eventMin,
          levelMax: currentCase.eventMax,
        );

        expect(
          eventRange.overlaps(selectedRange),
          currentCase.overlaps,
          reason: '${currentCase.eventMin}-${currentCase.eventMax} against '
              '${currentCase.selectedLevel}',
        );
      }
    });

    test('returns null selected range for no selected level', () {
      expect(selectedEventLevelRange(null), isNull);
      expect(selectedEventLevelRange(' '), isNull);
      expect(selectedEventLevelRange('b2')?.levelMin, 'B2');
      expect(selectedEventLevelRange('b2')?.levelMax, 'B2');
    });

    test('rejects invalid and reversed ranges', () {
      expect(
        () => eventLevelRange(levelMin: 'D1', levelMax: 'D1'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => eventLevelRange(levelMin: 'C1', levelMax: 'B1'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => selectedEventLevelRange('D1'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns null for invalid event ranges in tolerant parse mode', () {
      expect(
        tryEventLevelRange(levelMin: 'D1', levelMax: 'D1'),
        isNull,
      );
      expect(
        tryEventLevelRange(levelMin: 'C1', levelMax: 'B1'),
        isNull,
      );
      expect(
        tryEventLevelRange(levelMin: 'A1', levelMax: 'A1')?.levelMin,
        'A1',
      );
    });
  });
}
