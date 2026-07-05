import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/session_limit_ui.dart';

void main() {
  const sessionPolicy = <String, dynamic>{
    'warningLeadSeconds': 60,
    'extensionSeconds': 300,
    'extensionRequests': <String, bool>{},
    'extensionApproved': false,
  };

  group('resolveSessionLimitRemainingSeconds', () {
    test('returns zero without expiry', () {
      expect(resolveSessionLimitRemainingSeconds(null), 0);
    });

    test('returns positive remaining seconds until expiry', () {
      final now = DateTime.utc(2026, 4, 14, 12, 0, 0);
      final expiresAt = now.add(const Duration(seconds: 75));

      expect(
        resolveSessionLimitRemainingSeconds(expiresAt, now: now),
        75,
      );
    });

    test('clamps negative values to zero', () {
      final now = DateTime.utc(2026, 4, 14, 12, 0, 0);
      final expiresAt = now.subtract(const Duration(seconds: 5));

      expect(
        resolveSessionLimitRemainingSeconds(expiresAt, now: now),
        0,
      );
    });
  });

  group('shouldUseSessionLimitCountdown', () {
    test('ignores searching session expiry before accept becomes active', () {
      final now = DateTime.utc(2026, 4, 14, 12, 0, 0);

      expect(
        shouldUseSessionLimitCountdown(
          sessionStatus: 'searching',
          expiresAt: now.add(const Duration(seconds: 30)),
          sessionPolicy: sessionPolicy,
        ),
        isFalse,
      );
    });

    test('uses countdown only for active calls with policy', () {
      final now = DateTime.utc(2026, 4, 14, 12, 0, 0);

      expect(
        shouldUseSessionLimitCountdown(
          sessionStatus: 'active',
          expiresAt: now.add(const Duration(minutes: 5)),
          sessionPolicy: sessionPolicy,
        ),
        isTrue,
      );
      expect(
        shouldUseSessionLimitCountdown(
          sessionStatus: 'connecting',
          expiresAt: now.add(const Duration(minutes: 5)),
          sessionPolicy: sessionPolicy,
        ),
        isFalse,
      );
      expect(
        shouldUseSessionLimitCountdown(
          sessionStatus: 'ended',
          expiresAt: now.add(const Duration(minutes: 5)),
          sessionPolicy: sessionPolicy,
        ),
        isFalse,
      );
      expect(
        shouldUseSessionLimitCountdown(
          sessionStatus: 'active',
          expiresAt: now.add(const Duration(minutes: 5)),
          sessionPolicy: const <String, dynamic>{},
        ),
        isFalse,
      );
    });
  });

  group('shouldShowSessionLimitWarning', () {
    test('returns true only inside the warning window', () {
      final now = DateTime.utc(2026, 4, 14, 12, 0, 0);
      final expiresAt = now.add(const Duration(seconds: 45));

      expect(
        shouldShowSessionLimitWarning(
          expiresAt: expiresAt,
          warnedForExpiresAt: null,
          now: now,
        ),
        isTrue,
      );
      expect(
        shouldShowSessionLimitWarning(
          expiresAt: now.add(const Duration(seconds: 90)),
          warnedForExpiresAt: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('returns false when warning already shown for current expiry', () {
      final now = DateTime.utc(2026, 4, 14, 12, 0, 0);
      final expiresAt = now.add(const Duration(seconds: 45));

      expect(
        shouldShowSessionLimitWarning(
          expiresAt: expiresAt,
          warnedForExpiresAt: expiresAt,
          now: now,
        ),
        isFalse,
      );
    });

    test('returns true again when server expiry changes', () {
      final now = DateTime.utc(2026, 4, 14, 12, 0, 0);
      final previousExpiresAt = now.add(const Duration(seconds: 45));
      final extendedExpiresAt = now.add(const Duration(seconds: 300));

      expect(
        shouldShowSessionLimitWarning(
          expiresAt: extendedExpiresAt,
          warnedForExpiresAt: previousExpiresAt,
          now: now.add(const Duration(seconds: 250)),
        ),
        isTrue,
      );
    });
  });

  group('shouldAutoEndSession', () {
    test('returns false without expiry', () {
      expect(
        shouldAutoEndSession(
          expiresAt: null,
          autoEndedForExpiresAt: null,
        ),
        isFalse,
      );
    });

    test('returns false before expiry plus grace window', () {
      final now = DateTime.utc(2026, 4, 14, 12, 0, 0);
      final expiresAt = now.add(const Duration(seconds: 5));

      expect(
        shouldAutoEndSession(
          expiresAt: expiresAt,
          autoEndedForExpiresAt: null,
          now: now.add(const Duration(seconds: 6)),
          graceSeconds: 2,
        ),
        isFalse,
      );
    });

    test('returns true once expiry plus grace is reached', () {
      final now = DateTime.utc(2026, 4, 14, 12, 0, 0);
      final expiresAt = now.add(const Duration(seconds: 5));

      expect(
        shouldAutoEndSession(
          expiresAt: expiresAt,
          autoEndedForExpiresAt: null,
          now: now.add(const Duration(seconds: 7)),
          graceSeconds: 2,
        ),
        isTrue,
      );
    });

    test('returns false after auto-end already triggered for same expiry', () {
      final now = DateTime.utc(2026, 4, 14, 12, 0, 0);
      final expiresAt = now.subtract(const Duration(seconds: 1));

      expect(
        shouldAutoEndSession(
          expiresAt: expiresAt,
          autoEndedForExpiresAt: expiresAt,
          now: now,
        ),
        isFalse,
      );
    });

    test('retains marker when server ignores expired end', () {
      expect(
        shouldRetainAutoEndMarkerForResponseStatus('ignored_expired_end'),
        isTrue,
      );
      expect(
        shouldRetainAutoEndMarkerForResponseStatus('already_ended'),
        isFalse,
      );
      expect(
        shouldRetainAutoEndMarkerForResponseStatus(''),
        isFalse,
      );
    });
  });

  group('session extension helpers', () {
    test('reads normalized extension requests', () {
      expect(
        readSessionExtensionRequests(const <String, dynamic>{
          'extensionRequests': <String, dynamic>{
            ' user-a ': true,
            'user-b': false,
            '': true,
          },
        }),
        <String, bool>{'user-a': true},
      );
    });

    test('detects current and other participant requests', () {
      const policy = <String, dynamic>{
        'extensionRequests': <String, bool>{
          'user-a': true,
        },
      };

      expect(hasUserRequestedSessionExtension(policy, 'user-a'), isTrue);
      expect(
        hasOtherParticipantRequestedSessionExtension(policy, 'user-b'),
        isTrue,
      );
      expect(
        hasOtherParticipantRequestedSessionExtension(policy, 'user-a'),
        isFalse,
      );
    });

    test('shows extension surface only inside active warning window', () {
      final now = DateTime.utc(2026, 4, 14, 12, 0, 0);

      expect(
        shouldShowSessionExtensionSurface(
          sessionPolicy: sessionPolicy,
          expiresAt: now.add(const Duration(seconds: 45)),
          currentUserId: 'user-a',
          now: now,
        ),
        isTrue,
      );
      expect(
        shouldShowSessionExtensionSurface(
          sessionPolicy: sessionPolicy,
          expiresAt: now.add(const Duration(seconds: 90)),
          currentUserId: 'user-a',
          now: now,
        ),
        isFalse,
      );
      expect(
        shouldShowSessionExtensionSurface(
          sessionPolicy: null,
          expiresAt: now.add(const Duration(seconds: 45)),
          currentUserId: 'user-a',
          now: now,
        ),
        isFalse,
      );
      expect(
        shouldShowSessionExtensionSurface(
          sessionPolicy: const <String, dynamic>{
            'extensionApproved': true,
          },
          expiresAt: now.add(const Duration(seconds: 45)),
          currentUserId: 'user-a',
          now: now,
        ),
        isFalse,
      );
    });

    test('allows only users who have not requested yet to tap extension', () {
      final now = DateTime.utc(2026, 4, 14, 12, 0, 0);

      expect(
        canCurrentUserRequestSessionExtension(
          sessionPolicy: sessionPolicy,
          expiresAt: now.add(const Duration(seconds: 45)),
          currentUserId: 'user-a',
          now: now,
        ),
        isTrue,
      );
      expect(
        canCurrentUserRequestSessionExtension(
          sessionPolicy: const <String, dynamic>{
            'warningLeadSeconds': 60,
            'extensionRequests': <String, bool>{'user-a': true},
          },
          expiresAt: now.add(const Duration(seconds: 45)),
          currentUserId: 'user-a',
          now: now,
        ),
        isFalse,
      );
    });
  });
}
