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

  testWidgets('feedback shows non-retry App Check state for authenticated 401',
      (tester) async {
    final repository = CallFeedbackRepository(
      invoker: (_, __) async => throw _unauthenticatedFailure(),
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
      invoker: (_, __) async => throw _unauthenticatedFailure(),
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
}
