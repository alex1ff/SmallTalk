import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/students_pages/favorite/favorite_widget.dart';

void main() {
  group('formatFavoriteInboxTimestamp', () {
    test('formats today as 24-hour time', () {
      expect(
        formatFavoriteInboxTimestamp(
          DateTime(2026, 7, 5, 16, 59),
          now: DateTime(2026, 7, 5, 23),
        ),
        '16:59',
      );
    });

    test('formats older chats in the current year as month and day', () {
      expect(
        formatFavoriteInboxTimestamp(
          DateTime(2026, 6, 28, 17, 4),
          now: DateTime(2026, 7, 5),
        ),
        '06/28',
      );
    });

    test('formats chats from previous years with a short year', () {
      expect(
        formatFavoriteInboxTimestamp(
          DateTime(2025, 8, 11, 17, 32),
          now: DateTime(2026, 7, 5),
        ),
        '08/11/25',
      );
    });
  });
}
