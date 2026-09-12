import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/services/call_feedback_repository.dart';
import 'package:small_talk/services/error_reporting/error_reporter.dart';
import 'package:small_talk/services/translation_repository.dart';
import 'package:small_talk/shared_pages/call_summary/call_feedback_card.dart';
import 'package:small_talk/shared_pages/translation/in_call_translation_sheet.dart';

class _TestAuthUser extends BaseAuthUser {
  _TestAuthUser(this._uid);

  final String _uid;

  @override
  bool get loggedIn => true;

  @override
  bool get emailVerified => true;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(uid: _uid);

  @override
  Future? delete() => null;

  @override
  Future? sendEmailVerification() => null;

  @override
  Future? updateEmail(String email) => null;

  @override
  Future? updatePassword(String newPassword) => null;
}

class _RecordingSink implements ErrorReportSink {
  final List<SafeErrorReport> reports = <SafeErrorReport>[];

  @override
  Future<void> record(SafeErrorReport report) async => reports.add(report);
}

Widget _testApp(Widget home) {
  return MaterialApp(
    locale: const Locale('ru'),
    supportedLocales: const <Locale>[Locale('ru'), Locale('en')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      FFLocalizationsDelegate(),
      FallbackMaterialLocalizationDelegate(),
      FallbackCupertinoLocalizationDelegate(),
    ],
    home: Scaffold(body: home),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    setupFirebaseCoreMocks();
    await FFLocalizations.initialize();
    await Firebase.initializeApp();
  });

  late AppErrorReporter reporter;
  late _RecordingSink sink;

  setUp(() {
    currentUser = _TestAuthUser('user-a');
    currentUserDocument = null;
    sink = _RecordingSink();
    reporter = AppErrorReporter(environment: AppEnvironment.test)
      ..attachSink(sink);
    ErrorReporting.replaceReporterForTesting(reporter);
  });

  tearDown(() async {
    await reporter.drainForTesting();
    ErrorReporting.replaceReporterForTesting(
      AppErrorReporter(environment: AppEnvironment.test),
    );
    currentUser = null;
    currentUserDocument = null;
  });

  testWidgets('translation reports malformed responses and keeps safe fallback',
      (tester) async {
    final repository = TranslationRepository(
      invoker: (_, __) async => <String, dynamic>{'sourceText': 'missing'},
    );

    await tester.pumpWidget(
      _testApp(
        InCallTranslationSheet(
          sessionId: 'session-a',
          practicedLanguageCode: 'en',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'привет');
    await tester.pump();
    await tester.tap(find.text('Перевести'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    await reporter.drainForTesting();

    expect(find.text('Не удалось перевести. Проверьте интернет и повторите.'),
        findsOneWidget);
    expect(sink.reports.map((report) => report.code),
        contains(AppErrorCode.translationInvalidResponse));
  });

  testWidgets('AI feedback reports malformed responses and keeps safe fallback',
      (tester) async {
    final repository = CallFeedbackRepository(
      invoker: (_, __, {required timeout}) async =>
          <String, dynamic>{'status': 'ready'},
      watcher: ({required sessionRef, required userId}) =>
          Stream<CallFeedbackResponse?>.value(null),
    );

    await tester.pumpWidget(
      _testApp(
        CallFeedbackCard(
          sessionRef: VideoSessionsRecord.collection.doc('session-a'),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await reporter.drainForTesting();

    expect(find.text('Не удалось загрузить AI-разбор.'), findsOneWidget);
    expect(sink.reports.map((report) => report.code),
        contains(AppErrorCode.aiFeedbackInvalidResponse));
  });
}
