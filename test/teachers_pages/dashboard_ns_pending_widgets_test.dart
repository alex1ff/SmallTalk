import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/teachers_pages/dashboard_n_s/dashboard_n_s_widget.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ru'),
    supportedLocales: const [
      Locale('ru'),
      Locale('en'),
    ],
    localizationsDelegates: const [
      FFLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      FallbackMaterialLocalizationDelegate(),
      FallbackCupertinoLocalizationDelegate(),
    ],
    home: Scaffold(body: child),
  );
}

class _TestFirebaseAuthPlatform extends FirebaseAuthPlatform {
  _TestFirebaseAuthPlatform({FirebaseApp? app}) : super(appInstance: app);

  UserPlatform? _currentUser;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) {
    return _TestFirebaseAuthPlatform(app: app).._currentUser = _currentUser;
  }

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) {
    this.languageCode = languageCode;
    return this;
  }

  @override
  UserPlatform? get currentUser => _currentUser;

  @override
  set currentUser(UserPlatform? userPlatform) {
    _currentUser = userPlatform;
  }

  @override
  String? languageCode;

  @override
  Stream<UserPlatform?> authStateChanges() =>
      const Stream<UserPlatform?>.empty();

  @override
  Stream<UserPlatform?> idTokenChanges() => const Stream<UserPlatform?>.empty();

  @override
  Stream<UserPlatform?> userChanges() => const Stream<UserPlatform?>.empty();
}

class _TestAuthUser extends BaseAuthUser {
  _TestAuthUser({
    required this.isLoggedIn,
    this.userId,
  });

  final bool isLoggedIn;
  final String? userId;

  @override
  bool get loggedIn => isLoggedIn;

  @override
  bool get emailVerified => true;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(uid: userId);

  @override
  Future<void> delete() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> updateEmail(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    setupFirebaseCoreMocks();
    await FFLocalizations.initialize();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _TestFirebaseAuthPlatform();
  });

  tearDown(() {
    currentUser = null;
    currentUserDocument = null;
  });

  testWidgets('pending review card renders the teacher review copy',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(const PendingTeacherReviewCard()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Заявка на проверке'), findsOneWidget);
    expect(
      find.text(
        'Мы проверяем вашу заявку. Принимать звонки и выходить онлайн пока нельзя.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('pending review bottom sheet renders the blocking copy',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(const PendingTeacherReviewBottomSheet()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Заявка ещё на проверке'), findsOneWidget);
    expect(
      find.text(
        'Пока проверка не завершена, выйти онлайн и принимать звонки нельзя.',
      ),
      findsOneWidget,
    );
    expect(find.text('Заявка на проверке'), findsOneWidget);
    expect(find.text('Понятно'), findsNothing);
  });

  testWidgets('pending availability switch uses blocker tap without toggling',
      (tester) async {
    var pendingTapCount = 0;
    var changedValue = false;

    await tester.pumpWidget(
      _buildTestApp(
        AvailabilitySwitchControl(
          value: false,
          isPendingTeacherReview: true,
          onChanged: (_) {
            changedValue = true;
          },
          onPendingTap: () {
            pendingTapCount += 1;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(AvailabilitySwitchControl));
    await tester.pump();

    expect(pendingTapCount, 1);
    expect(changedValue, isFalse);
  });

  testWidgets('non-pending availability switch delegates toggle intent',
      (tester) async {
    bool? nextValue;

    await tester.pumpWidget(
      _buildTestApp(
        AvailabilitySwitchControl(
          value: false,
          isPendingTeacherReview: false,
          onChanged: (value) {
            nextValue = value;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(AvailabilitySwitchControl));
    await tester.pump();

    expect(nextValue, isTrue);
  });

  testWidgets('pending dashboard switch stays off and opens blocker sheet',
      (tester) async {
    currentUser = _TestAuthUser(
      isLoggedIn: true,
      userId: 'pending-dashboard-test',
    );
    currentUserDocument = UsersRecord.getDocumentFromData(
      {
        'role': 'native_speaker',
        'teacherAccreditationStatus': 'pending',
        'availabilityToday': {
          'enabled': false,
          'intervals': <dynamic>[],
        },
        'isInCall': false,
      },
      UsersRecord.collection.doc('pending-dashboard-test'),
    );

    await tester.pumpWidget(
      _buildTestApp(
        DashboardNSWidget(
          statsStreamOverride: Stream<List<StatsRecord>>.value(
            const <StatsRecord>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Доступен сегодня'), findsOneWidget);
    expect(
      tester
          .widget<AvailabilitySwitchControl>(
            find.byType(AvailabilitySwitchControl),
          )
          .value,
      isFalse,
    );

    await tester.tap(find.byType(AvailabilitySwitchControl));
    await tester.pumpAndSettle();

    expect(find.text('Заявка ещё на проверке'), findsOneWidget);
    expect(
      find.text(
        'Пока проверка не завершена, выйти онлайн и принимать звонки нельзя.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AvailabilitySwitchControl>(
            find.byType(AvailabilitySwitchControl),
          )
          .value,
      isFalse,
    );
  });
}
