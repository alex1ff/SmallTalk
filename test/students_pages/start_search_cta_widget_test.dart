import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/components/no_balance_widget.dart';
import 'package:small_talk/components/student_start_search_button.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/students_pages/students_dashboard/students_dashboard_widget.dart';

const MethodChannel _permissionsChannel =
    MethodChannel('flutter.baseflow.com/permissions/methods');

Widget _buildDashboardTestApp(
  Widget child, {
  double textScaleFactor = 1.0,
}) {
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
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
      child: child,
    ),
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

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionsChannel, (call) async {
      switch (call.method) {
        case 'requestPermissions':
          final permissions = (call.arguments as List<dynamic>).cast<int>();
          return <int, int>{
            for (final permission in permissions) permission: 1,
          };
        case 'checkPermissionStatus':
        case 'checkServiceStatus':
          return 1;
        case 'openAppSettings':
          return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionsChannel, null);
    currentUser = null;
    currentUserDocument = null;
  });

  testWidgets('student dashboard renders and handles the start search CTA',
      (tester) async {
    currentUser = _TestAuthUser(
      isLoggedIn: true,
      userId: 'student-start-search-test',
    );
    currentUserDocument = UsersRecord.getDocumentFromData(
      {
        'role': 'student',
        'display_name': 'Student',
        'learningLanguage': {
          'code': 'en',
          'name': 'English',
        },
      },
      UsersRecord.collection.doc('student-start-search-test'),
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(const StudentsDashboardWidget()),
    );
    await tester.pump();

    final startSearchText = find.text('Начать поиск');
    expect(startSearchText, findsOneWidget);
    final startSearchButton = find.ancestor(
      of: startSearchText,
      matching: find.byType(InkWell),
    );
    expect(startSearchButton, findsOneWidget);
    expect(tester.widget<InkWell>(startSearchButton).onTap, isNotNull);

    await tester.tap(startSearchButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NoBalanceWidget), findsOneWidget);
    expect(find.text('Нет активной подписки'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard toggles search CTA after successful start',
      (tester) async {
    currentUser = _TestAuthUser(
      isLoggedIn: true,
      userId: 'student-stop-search-test',
    );
    currentUserDocument = UsersRecord.getDocumentFromData(
      {
        'role': 'student',
        'display_name': 'Student',
        'learningLanguage': {
          'code': 'en',
          'name': 'English',
        },
        'subscription': {
          'productId': 'test',
          'expiresAt': DateTime.now().add(const Duration(days: 1)),
        },
      },
      UsersRecord.collection.doc('student-stop-search-test'),
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(const StudentsDashboardWidget()),
    );
    await tester.pump();

    final startSearchText = find.text('Начать поиск');
    expect(startSearchText, findsOneWidget);

    await tester.tap(
      find.ancestor(
        of: startSearchText,
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    final stopSearchText = find.text('Остановить поиск');
    expect(stopSearchText, findsOneWidget);
    expect(find.text('Начать поиск'), findsNothing);

    await tester.tap(
      find.ancestor(
        of: stopSearchText,
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('start search button scales label inside fixed CTA width',
      (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      _buildDashboardTestApp(
        Center(
          child: StudentStartSearchButton(
            onTap: () {
              tapped = true;
            },
          ),
        ),
        textScaleFactor: 1.8,
      ),
    );
    await tester.pump();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(StudentStartSearchButton));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('start search button renders stop state', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      _buildDashboardTestApp(
        Center(
          child: StudentStartSearchButton(
            isSearching: true,
            onTap: () {
              tapped = true;
            },
          ),
        ),
        textScaleFactor: 1.8,
      ),
    );
    await tester.pump();

    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Начать поиск'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(StudentStartSearchButton));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
