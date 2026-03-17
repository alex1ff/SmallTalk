import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';

void main() {
  group('resolveAuthenticatedUserIdFromSources', () {
    test('prefers explicit auth uid from sign-in result', () {
      expect(
        resolveAuthenticatedUserIdFromSources(
          preferredUid: 'social-user',
          firebaseAuthUid: 'firebase-user',
          currentUserUid: 'stream-user',
        ),
        'social-user',
      );
    });

    test('falls back to FirebaseAuth uid when currentUser is delayed', () {
      expect(
        resolveAuthenticatedUserIdFromSources(
          preferredUid: null,
          firebaseAuthUid: 'firebase-user',
          currentUserUid: null,
        ),
        'firebase-user',
      );
    });

    test('falls back to currentUser uid when Firebase user is unavailable', () {
      expect(
        resolveAuthenticatedUserIdFromSources(
          preferredUid: null,
          firebaseAuthUid: null,
          currentUserUid: 'stream-user',
        ),
        'stream-user',
      );
    });

    test('returns null when every source is empty', () {
      expect(
        resolveAuthenticatedUserIdFromSources(
          preferredUid: '  ',
          firebaseAuthUid: '',
          currentUserUid: null,
        ),
        isNull,
      );
    });
  });

  group('resolveAuthenticatedUserIdResolutionFromSources', () {
    test('tracks preferred uid as source', () {
      final resolution = resolveAuthenticatedUserIdResolutionFromSources(
        preferredUid: 'social-user',
        firebaseAuthUid: 'firebase-user',
        currentUserUid: 'stream-user',
      );

      expect(resolution.uid, 'social-user');
      expect(resolution.source, AuthenticatedUserIdSource.preferred);
    });

    test('tracks firebase auth uid as source when globals lag', () {
      final resolution = resolveAuthenticatedUserIdResolutionFromSources(
        preferredUid: null,
        firebaseAuthUid: 'firebase-user',
        currentUserUid: null,
      );

      expect(resolution.uid, 'firebase-user');
      expect(resolution.source, AuthenticatedUserIdSource.firebaseAuth);
    });

    test('marks resolution unavailable when no uid source exists', () {
      final resolution = resolveAuthenticatedUserIdResolutionFromSources(
        preferredUid: null,
        firebaseAuthUid: null,
        currentUserUid: null,
      );

      expect(resolution.uid, isNull);
      expect(resolution.source, AuthenticatedUserIdSource.unavailable);
    });
  });
}
