import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/new_account_inbox_bootstrap.dart';
import 'package:small_talk/services/ux_session_cache_lifecycle.dart';

void main() {
  setUp(() {
    NewAccountInboxBootstrap.debugResetForTesting();
    UxSessionCacheLifecycle.debugResetForTesting();
  });

  tearDown(() {
    NewAccountInboxBootstrap.debugResetForTesting();
    UxSessionCacheLifecycle.debugResetForTesting();
  });

  test('seeds only the account created in the active session', () {
    NewAccountInboxBootstrap.markAccountCreated(' user-a ');

    expect(NewAccountInboxBootstrap.shouldSeedEmptyInbox('user-a'), isTrue);
    expect(NewAccountInboxBootstrap.shouldSeedEmptyInbox('user-b'), isFalse);
  });

  test('clears the seed when the authenticated user changes', () {
    NewAccountInboxBootstrap.markAccountCreated('user-a');

    UxSessionCacheLifecycle.updateAuthenticatedUser('user-b');

    expect(NewAccountInboxBootstrap.shouldSeedEmptyInbox('user-a'), isFalse);
    expect(NewAccountInboxBootstrap.shouldSeedEmptyInbox('user-b'), isFalse);
  });

  test('ignores an empty account id', () {
    NewAccountInboxBootstrap.markAccountCreated('   ');

    expect(NewAccountInboxBootstrap.shouldSeedEmptyInbox(''), isFalse);
  });
}
