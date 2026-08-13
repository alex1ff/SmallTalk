import 'ux_session_cache_lifecycle.dart';

/// Provides a confirmed-empty inbox seed for an account created in the
/// current authenticated session. Live inbox sources still subscribe and
/// replace the seed as soon as data arrives.
final class NewAccountInboxBootstrap {
  const NewAccountInboxBootstrap._();

  static String? _newAccountUid;
  static bool _lifecycleRegistered = false;

  static void markAccountCreated(String uid) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return;
    }

    _ensureLifecycleRegistered();
    UxSessionCacheLifecycle.updateAuthenticatedUser(normalizedUid);
    _newAccountUid = normalizedUid;
  }

  static bool shouldSeedEmptyInbox(String uid) =>
      _newAccountUid == uid.trim() && uid.trim().isNotEmpty;

  static void _ensureLifecycleRegistered() {
    if (_lifecycleRegistered) {
      return;
    }
    _lifecycleRegistered = true;
    UxSessionCacheLifecycle.register(_clear);
  }

  static void _clear() {
    _newAccountUid = null;
  }

  static void debugResetForTesting() {
    _clear();
    if (_lifecycleRegistered) {
      UxSessionCacheLifecycle.unregister(_clear);
      _lifecycleRegistered = false;
    }
  }
}
