import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/authorization/shared/pending_social_auth_context.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';

void main() {
  group('PendingSocialAuthContext', () {
    test('stays valid for the same uid within max age', () {
      final context = PendingSocialAuthContext(
        providerId: 'google.com',
        sourceScreen: 'Login',
        roleIntent: UserRole.student,
        createdAt: DateTime(2026, 3, 17, 12, 0, 0),
        authUid: 'uid-1',
      );

      expect(
        context.isValidFor(
          currentAuthUid: 'uid-1',
          now: DateTime(2026, 3, 17, 12, 5, 0),
        ),
        isTrue,
      );
    });

    test('expires after the max age window', () {
      final context = PendingSocialAuthContext(
        providerId: 'google.com',
        sourceScreen: 'Registration',
        roleIntent: UserRole.native_speaker,
        createdAt: DateTime(2026, 3, 17, 12, 0, 0),
      );

      expect(
        context.isValidFor(
          now: DateTime(2026, 3, 17, 12, 11, 0),
        ),
        isFalse,
      );
    });

    test('becomes invalid when stored uid mismatches current uid', () {
      final context = PendingSocialAuthContext(
        providerId: 'apple.com',
        sourceScreen: 'Login',
        roleIntent: UserRole.student,
        createdAt: DateTime(2026, 3, 17, 12, 0, 0),
        authUid: 'uid-1',
      );

      expect(
        context.isValidFor(
          currentAuthUid: 'uid-2',
          now: DateTime(2026, 3, 17, 12, 2, 0),
        ),
        isFalse,
      );
    });
  });
}
