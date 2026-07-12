import 'dart:collection';

typedef UxSessionCacheClearer = void Function();

final class UxSessionCacheLifecycle {
  const UxSessionCacheLifecycle._();

  static final LinkedHashSet<UxSessionCacheClearer> _clearers =
      LinkedHashSet<UxSessionCacheClearer>();
  static String? _activeUserId;
  static bool _hasObservedAuthState = false;

  static void register(UxSessionCacheClearer clearer) {
    _clearers.add(clearer);
  }

  static void unregister(UxSessionCacheClearer clearer) {
    _clearers.remove(clearer);
  }

  static String sessionUserIdOrFallback(String fallbackUserId) {
    if (!_hasObservedAuthState) {
      return fallbackUserId;
    }
    return _activeUserId ?? '';
  }

  static void updateAuthenticatedUser(String? userId) {
    if (_hasObservedAuthState && _activeUserId == userId) {
      return;
    }
    _hasObservedAuthState = true;
    _activeUserId = userId;
    for (final clearer in List<UxSessionCacheClearer>.of(_clearers)) {
      clearer();
    }
  }

  static void debugResetForTesting() {
    _clearers.clear();
    _activeUserId = null;
    _hasObservedAuthState = false;
  }
}
