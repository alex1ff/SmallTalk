import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _curlyBlockSource(String source, String declaration) {
  final declarationIndex = source.indexOf(declaration);
  if (declarationIndex < 0) return '';
  final openingBrace = source.indexOf('{', declarationIndex);
  if (openingBrace < 0) return '';

  var depth = 0;
  for (var index = openingBrace; index < source.length; index += 1) {
    switch (source[index]) {
      case '{':
        depth += 1;
      case '}':
        depth -= 1;
        if (depth == 0) {
          return source.substring(declarationIndex, index + 1);
        }
    }
  }
  return '';
}

void main() {
  late String mainSource;
  late String appStateSource;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
    appStateSource = File('lib/app_state.dart').readAsStringSync();
  });

  test('local state starts before Firebase wait and both finish before runApp',
      () {
    final mainFunction = _curlyBlockSource(mainSource, 'void main() async {');
    final earlyCallKit =
        mainFunction.indexOf('startEarlyCallKitEventHandling()');
    final firebaseStart = mainFunction.indexOf(
        'final firebaseReadyFuture = _initializeFirebaseForStartup();');
    final localStart = mainFunction.indexOf(
      'final localStateReady = Future.wait([',
      firebaseStart,
    );
    final combinedWait = mainFunction.indexOf(
      'final startupResults = await Future.wait<Object?>([',
      localStart,
    );
    final combinedWaitEnd = mainFunction.indexOf(']);', combinedWait);
    final runApp = mainFunction.indexOf(
      'runApp(ChangeNotifierProvider',
      combinedWait,
    );

    expect(earlyCallKit, greaterThanOrEqualTo(0));
    expect(firebaseStart, greaterThan(earlyCallKit));
    expect(localStart, greaterThan(firebaseStart));
    expect(
      mainFunction.substring(firebaseStart, localStart),
      isNot(contains('await ')),
    );
    expect(combinedWait, greaterThan(localStart));
    expect(combinedWaitEnd, greaterThan(combinedWait));
    final combinedWaitSource =
        mainFunction.substring(combinedWait, combinedWaitEnd);
    expect(combinedWaitSource, contains('firebaseReadyFuture'));
    expect(combinedWaitSource, contains('localStateReady'));
    expect(runApp, greaterThan(combinedWait));
  });

  test('App Check remains a barrier before subscription and runApp', () {
    final firebaseHelper = _curlyBlockSource(
      mainSource,
      'Future<bool> _initializeFirebaseForStartup() async {',
    );
    final firebaseInit = firebaseHelper.indexOf('await initFirebase();');
    final errorReport = firebaseHelper.indexOf(
      '_reportFirebaseInitializationFailure(error, stackTrace);',
    );
    final failedResult = firebaseHelper.indexOf('return false;', errorReport);
    final errorSink = firebaseHelper.indexOf('ErrorReporting.attachSink(');
    final appCheck =
        firebaseHelper.indexOf('await initializeFirebaseAppCheck();');
    final readyResult = firebaseHelper.indexOf('return true;', appCheck);

    final mainFunction = _curlyBlockSource(mainSource, 'void main() async {');
    final firebaseReady = mainFunction.indexOf(
      'final firebaseReady = startupResults.first! as bool;',
    );
    final subscription = mainFunction.indexOf(
      'SubscriptionService.instance',
      firebaseReady,
    );
    final runApp = mainFunction.indexOf(
      'runApp(ChangeNotifierProvider',
      firebaseReady,
    );

    expect(firebaseInit, greaterThanOrEqualTo(0));
    expect(errorReport, greaterThan(firebaseInit));
    expect(failedResult, greaterThan(errorReport));
    expect(errorSink, greaterThan(firebaseInit));
    expect(appCheck, greaterThan(errorSink));
    expect(readyResult, greaterThan(appCheck));
    expect(firebaseReady, greaterThanOrEqualTo(0));
    expect(subscription, greaterThan(firebaseReady));
    expect(runApp, greaterThan(subscription));
  });

  test('preferences and language catalog load in parallel before hydration',
      () {
    final preferencesStart = appStateSource.indexOf(
      'final preferencesFuture = SharedPreferences.getInstance();',
    );
    final catalogStart = appStateSource.indexOf(
      'final languagesCatalogFuture = _loadDefaultLanguagesFromAsset();',
      preferencesStart,
    );
    final preferencesWait = appStateSource.indexOf(
      'prefs = await preferencesFuture;',
      catalogStart,
    );
    final catalogWait = appStateSource.indexOf(
      'await languagesCatalogFuture;',
      preferencesWait,
    );
    final persistedHydration = appStateSource.indexOf(
      ".getStringList('ff_languagesList')",
      catalogWait,
    );

    expect(preferencesStart, greaterThanOrEqualTo(0));
    expect(catalogStart, greaterThan(preferencesStart));
    expect(preferencesWait, greaterThan(catalogStart));
    expect(catalogWait, greaterThan(preferencesWait));
    expect(persistedHydration, greaterThan(catalogWait));
  });
}
