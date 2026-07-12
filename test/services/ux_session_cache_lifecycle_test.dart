import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/auth/firebase_auth/firebase_user_provider.dart';
import 'package:small_talk/services/ux_session_cache_lifecycle.dart';

void main() {
  setUp(UxSessionCacheLifecycle.debugResetForTesting);
  tearDown(UxSessionCacheLifecycle.debugResetForTesting);

  test('clears registered session caches only when auth identity changes', () {
    var clearCalls = 0;
    void clearCache() {
      clearCalls += 1;
    }

    UxSessionCacheLifecycle.register(clearCache);

    UxSessionCacheLifecycle.updateAuthenticatedUser('user-a');
    expect(clearCalls, 1);

    UxSessionCacheLifecycle.updateAuthenticatedUser('user-a');
    expect(clearCalls, 1);

    UxSessionCacheLifecycle.updateAuthenticatedUser(' user-a ');
    expect(clearCalls, 2);

    UxSessionCacheLifecycle.updateAuthenticatedUser('user-b');
    expect(clearCalls, 3);

    UxSessionCacheLifecycle.updateAuthenticatedUser(null);
    expect(clearCalls, 4);

    UxSessionCacheLifecycle.updateAuthenticatedUser('');
    expect(clearCalls, 5);

    UxSessionCacheLifecycle.unregister(clearCache);
    UxSessionCacheLifecycle.updateAuthenticatedUser('user-c');
    expect(clearCalls, 5);
  });

  test('auth stream clears session caches on identity changes', () async {
    final authStates = StreamController<String?>(sync: true);
    final emittedStates = <String?>[];
    var clearCalls = 0;
    UxSessionCacheLifecycle.register(() => clearCalls += 1);
    final subscription = withUxSessionCacheLifecycle<String?>(
      authStates.stream,
      (userId) => userId,
    ).listen(emittedStates.add);

    try {
      authStates.add('user-a');
      expect(clearCalls, 1);
      authStates.add('user-a');
      expect(clearCalls, 1);
      authStates.add(' user-a ');
      expect(clearCalls, 2);
      authStates.add('user-b');
      expect(clearCalls, 3);
      authStates.add(null);
      expect(clearCalls, 4);
      expect(
        emittedStates,
        ['user-a', 'user-a', ' user-a ', 'user-b', null],
      );
    } finally {
      await subscription.cancel();
      await authStates.close();
    }
  });
}
