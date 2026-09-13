import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/shared_pages/chat_thread/chat_thread_formatters.dart';

void main() {
  group('chat thread formatters', () {
    test('detects online users from fresh lastSeenAt', () {
      final now = DateTime(2026, 5, 30, 9, 42);

      expect(
        chatPartnerIsOnline(
          DateTime(2026, 5, 30, 9, 40, 1),
          now: now,
        ),
        isTrue,
      );
      expect(
        chatPartnerIsOnline(
          DateTime(2026, 5, 30, 9, 39, 59),
          now: now,
        ),
        isFalse,
      );
    });

    test('formats Russian presence labels without using profile updatedAt', () {
      final today = DateTime(2026, 5, 30, 9, 42);

      expect(
        formatChatPresenceLabel(
          DateTime(2026, 5, 30, 9, 41),
          locale: 'ru',
          now: today,
        ),
        'онлайн',
      );
      expect(
        formatChatPresenceLabel(
          DateTime(2026, 5, 30, 8, 10),
          locale: 'ru',
          now: today,
        ),
        'был(а) сегодня в 08:10',
      );
      expect(
        formatChatPresenceLabel(
          DateTime(2026, 5, 29, 16, 20),
          locale: 'ru',
          now: today,
        ),
        'был(а) вчера в 16:20',
      );
      expect(
        formatChatPresenceLabel(null, locale: 'ru', now: today),
        '',
      );
    });

    test('formats centered date divider labels', () {
      final now = DateTime(2026, 5, 30, 9, 42);

      expect(
        formatChatDateDividerLabel(
          DateTime(2026, 5, 30, 9, 41),
          locale: 'ru',
          now: now,
        ),
        'Сегодня, 09:41',
      );
      expect(
        formatChatDateDividerLabel(
          DateTime(2026, 5, 29, 16, 20),
          locale: 'ru',
          now: now,
        ),
        'Вчера, 16:20',
      );
    });
  });
}
