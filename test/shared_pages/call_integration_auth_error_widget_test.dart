import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/services/call_feedback_repository.dart';
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

FirebaseFunctionsException _unauthenticatedFailure() {
  return FirebaseFunctionsException(
    code: 'unauthenticated',
    message: 'Callable request verification failed',
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

  setUp(() {
    currentUser = _TestAuthUser('user-a');
    currentUserDocument = null;
  });

  tearDown(() {
    currentUser = null;
    currentUserDocument = null;
  });

  testWidgets('translation maps authenticated 401 to App Check copy',
      (tester) async {
    final repository = TranslationRepository(
      invoker: (_, __) async => throw _unauthenticatedFailure(),
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
    await tester.enterText(find.byType(TextField), 'как жизнь');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      find.text('Не удалось подтвердить приложение. Перезапустите его.'),
      findsOneWidget,
    );
    expect(find.text('Войдите в аккаунт и повторите.'), findsNothing);
  });

  testWidgets('translation maps signed-out 401 to auth copy', (tester) async {
    currentUser = null;
    final repository = TranslationRepository(
      invoker: (_, __) async => throw _unauthenticatedFailure(),
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
    await tester.enterText(find.byType(TextField), 'как жизнь');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Войдите в аккаунт и повторите.'), findsOneWidget);
  });

  testWidgets('translation detects direction and renders compact actions',
      (tester) async {
    Map<String, dynamic>? translatedPayload;
    final repository = TranslationRepository(
      invoker: (functionName, payload) async {
        if (functionName == 'translateTerm') {
          translatedPayload = payload;
          return <String, dynamic>{
            'sourceText': 'привет',
            'translatedText': 'Hello',
            'sourceLang': 'ru',
            'targetLang': 'en',
            'lookupId': 'lookup-a',
            'cacheHit': false,
          };
        }
        return <String, dynamic>{
          'wordPath': 'users/user-a/userWords/translation-a',
          'alreadyExisted': false,
        };
      },
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

    expect(find.text('Русский → English · авто'), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
    expect(find.text('Копировать'), findsNothing);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    expect(find.text('English → Русский · авто'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'привет');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(translatedPayload?['sourceLang'], 'ru');
    expect(translatedPayload?['targetLang'], 'en');
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('В словарь'), findsOneWidget);
    expect(find.text('Копировать'), findsNothing);
  });

  testWidgets('translation ignores a completion after the input changes',
      (tester) async {
    final firstResponse = Completer<Object?>();
    var translateCalls = 0;
    Map<String, dynamic>? latestPayload;
    final repository = TranslationRepository(
      invoker: (functionName, payload) async {
        if (functionName != 'translateTerm') {
          return <String, dynamic>{
            'wordPath': 'users/user-a/userWords/translation-a',
            'alreadyExisted': false,
          };
        }
        translateCalls += 1;
        latestPayload = payload;
        if (translateCalls == 1) return firstResponse.future;
        return <String, dynamic>{
          'sourceText': 'hello',
          'translatedText': 'Привет',
          'sourceLang': 'en',
          'targetLang': 'ru',
          'lookupId': 'lookup-b',
          'cacheHit': false,
        };
      },
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
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(translateCalls, 1);

    firstResponse.complete(<String, dynamic>{
      'sourceText': 'привет',
      'translatedText': 'Hello',
      'sourceLang': 'ru',
      'targetLang': 'en',
      'lookupId': 'lookup-a',
      'cacheHit': false,
    });
    await tester.pumpAndSettle();

    expect(find.text('English → Русский · авто'), findsOneWidget);
    expect(find.text('Hello'), findsNothing);
    expect(find.text('В словарь'), findsNothing);

    await tester.tap(find.text('Перевести'));
    await tester.pumpAndSettle();
    expect(translateCalls, 2);
    expect(latestPayload?['sourceLang'], 'en');
    expect(latestPayload?['targetLang'], 'ru');
    expect(find.text('Привет'), findsOneWidget);
    expect(find.text('В словарь'), findsOneWidget);
  });

  testWidgets('feedback shows non-retry App Check state for authenticated 401',
      (tester) async {
    final repository = CallFeedbackRepository(
      invoker: (_, __, {required timeout}) async =>
          throw _unauthenticatedFailure(),
      watcher: ({required sessionRef, required userId}) {
        return Stream<CallFeedbackResponse?>.value(null);
      },
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

    expect(
      find.text('Не удалось подтвердить приложение. Перезапустите его.'),
      findsOneWidget,
    );
    expect(find.text('Повторить'), findsNothing);
  });

  testWidgets('feedback maps signed-out 401 to auth copy without retry',
      (tester) async {
    currentUser = null;
    final repository = CallFeedbackRepository(
      invoker: (_, __, {required timeout}) async =>
          throw _unauthenticatedFailure(),
      watcher: ({required sessionRef, required userId}) {
        return Stream<CallFeedbackResponse?>.value(null);
      },
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

    expect(find.text('Войдите в аккаунт и повторите.'), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
  });

  testWidgets('feedback pending copy differs between summary and details',
      (tester) async {
    final repository = CallFeedbackRepository(
      watcher: ({required sessionRef, required userId}) =>
          Stream<CallFeedbackResponse?>.value(
        const CallFeedbackResponse(
          status: CallFeedbackStatus.pending,
          generationVersion: 3,
        ),
      ),
    );

    await tester.pumpWidget(
      _testApp(
        CallFeedbackCard(
          sessionRef: VideoSessionsRecord.collection.doc('session-a'),
          repository: repository,
          presentation: CallFeedbackPresentation.summary,
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text(
        'AI-разбор готовится. Ждать не нужно — он появится на странице информации о звонке.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _testApp(
        CallFeedbackCard(
          sessionRef: VideoSessionsRecord.collection.doc('session-a'),
          repository: repository,
          presentation: CallFeedbackPresentation.details,
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text(
        'AI-разбор готовится. Он появится на этой странице автоматически.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('legacy recovery is one-shot and current terminal never invokes',
      (tester) async {
    var calls = 0;
    final recoveryCompleter = Completer<Object?>();
    final legacyResponses = StreamController<CallFeedbackResponse?>();
    final repository = CallFeedbackRepository(
      invoker: (_, __, {required timeout}) async {
        calls += 1;
        return recoveryCompleter.future;
      },
      watcher: ({required sessionRef, required userId}) =>
          legacyResponses.stream,
    );
    const legacyFailure = CallFeedbackResponse(
      status: CallFeedbackStatus.terminalFailure,
      errorCode: 'feedback_generation_failed',
    );

    await tester.pumpWidget(
      _testApp(
        CallFeedbackCard(
          sessionRef: VideoSessionsRecord.collection.doc('session-a'),
          repository: repository,
        ),
      ),
    );
    legacyResponses
      ..add(legacyFailure)
      ..add(legacyFailure)
      ..add(legacyFailure);
    await tester.pump();
    expect(calls, 1);
    expect(
      find.text(
        'AI-разбор готовится. Ждать не нужно — он появится на странице информации о звонке.',
      ),
      findsOneWidget,
    );

    recoveryCompleter.complete(<String, dynamic>{
      'status': 'ready',
      'generationVersion': 3,
      'feedback': <String, dynamic>{
        'summary': 'Разбор восстановлен.',
        'score': 80,
        'strengths': <String>['Хорошая структура.'],
        'corrections': <Map<String, dynamic>>[
          <String, dynamic>{
            'original': 'I go yesterday.',
            'better': 'I went yesterday.',
            'explanation': 'Нужна прошедшая форма.',
          },
        ],
        'vocabulary': <Map<String, dynamic>>[],
        'nextPractice': 'Повторите прошедшее время.',
      },
    });
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Разбор восстановлен.'), findsOneWidget);
    legacyResponses.add(legacyFailure);
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Разбор восстановлен.'), findsOneWidget);
    expect(
      find.text('Не удалось подготовить разбор этого звонка.'),
      findsNothing,
    );
    await legacyResponses.close();

    var currentCalls = 0;
    final currentResponses = StreamController<CallFeedbackResponse?>();
    final currentRepository = CallFeedbackRepository(
      invoker: (_, __, {required timeout}) async {
        currentCalls += 1;
        return const <String, dynamic>{'status': 'pending'};
      },
      watcher: ({required sessionRef, required userId}) =>
          currentResponses.stream,
    );
    await tester.pumpWidget(
      _testApp(
        CallFeedbackCard(
          sessionRef: VideoSessionsRecord.collection.doc('session-b'),
          repository: currentRepository,
        ),
      ),
    );
    currentResponses.add(
      const CallFeedbackResponse(
        status: CallFeedbackStatus.terminalFailure,
        errorCode: 'feedback_generation_failed',
        generationVersion: 3,
      ),
    );
    await tester.pump();
    expect(currentCalls, 0);
    expect(
      find.text('Не удалось подготовить разбор этого звонка.'),
      findsOneWidget,
    );
    await currentResponses.close();
  });
}
