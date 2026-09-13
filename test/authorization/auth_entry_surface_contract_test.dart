import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('auth entry and recovery do not expose Native Speaker choice', () {
    final login = source('lib/authorization/login/login_widget.dart');
    final registration =
        source('lib/authorization/registration/registration_widget.dart');
    final loading = source('lib/authorization/loading/loading_widget.dart');

    for (final authSource in <String>[login, registration, loading]) {
      expect(authSource, isNot(contains('NativeSpeakerEntryToggle(')));
      expect(authSource, isNot(contains("native_speaker_entry_toggle.dart")));
    }
    for (final authSource in <String>[login, registration]) {
      expect(authSource, contains('nativeSpeakerIntent: false'));
    }
    expect(registration, isNot(contains('role: UserRole.native_speaker')));
    expect(registration, contains('role: UserRole.student'));
  });

  test('auth models no longer carry the removed toggle state', () {
    final loginModel = source('lib/authorization/login/login_model.dart');
    final registrationModel =
        source('lib/authorization/registration/registration_model.dart');

    expect(loginModel, isNot(contains('switchValue')));
    expect(registrationModel, isNot(contains('switchValue')));
  });

  test('loading recovery always exposes retry and sign out actions', () {
    final loading = source('lib/authorization/loading/loading_widget.dart');

    expect(loading, contains('_retryResolution'));
    expect(loading, contains('_signOutAndReturnToLogin'));
    expect(loading, contains("enText: 'Try again'"));
    expect(loading, contains("enText: 'Sign out'"));
    expect(loading, contains('Could not determine the profile type.'));
    expect(loading, contains('Could not load your profile.'));
    expect(loading, contains('VoIP cleanup before sign-out failed'));
    expect(loading, contains('.timeout(const Duration(seconds: 2))'));
    expect(
      loading.indexOf('unawaited('),
      lessThan(loading.indexOf('await authManager.signOut()')),
    );
  });

  test('RevenueCat auth synchronization catches fire-and-forget failures', () {
    final provider =
        source('lib/auth/firebase_auth/firebase_user_provider.dart');

    expect(provider, contains('logInUser(user.uid).catchError'));
    expect(provider, contains('logOutUser().catchError'));
  });

  test('shared location source exposes exactly the four product locations', () {
    final sourceText = source('lib/flutter_flow/custom_functions.dart');
    final referenceStart = sourceText.indexOf('const referenceCountryCodes');
    final returnStart = sourceText.indexOf('return [', referenceStart);
    final referenceBlock = sourceText.substring(referenceStart, returnStart);

    expect(
      referenceBlock,
      contains("'US',\n    'ID',\n    'AE',\n    'TH',"),
    );
    expect(referenceBlock, isNot(contains("'DE'")));
  });
}
