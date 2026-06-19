import 'dart:async';

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

const int _permissionDenied = 0;
const int _permissionGranted = 1;

int _permissionStatus = _permissionGranted;
int _checkPermissionStatusCallCount = 0;
int _requestPermissionsCallCount = 0;
Future<Map<int, int>> Function(List<int> permissions)?
    _requestPermissionsHandler;

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
    _permissionStatus = _permissionGranted;
    _checkPermissionStatusCallCount = 0;
    _requestPermissionsCallCount = 0;
    _requestPermissionsHandler = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionsChannel, (call) async {
      switch (call.method) {
        case 'requestPermissions':
          _requestPermissionsCallCount += 1;
          final permissions = (call.arguments as List<dynamic>).cast<int>();
          final handler = _requestPermissionsHandler;
          if (handler != null) {
            return handler(permissions);
          }
          return <int, int>{
            for (final permission in permissions) permission: _permissionStatus,
          };
        case 'checkPermissionStatus':
          _checkPermissionStatusCallCount += 1;
          return _permissionStatus;
        case 'checkServiceStatus':
          return _permissionGranted;
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

  VideoSessionsRecord sessionFixture(String sessionId, String status) {
    return VideoSessionsRecord.getDocumentFromData(
      {
        'status': status,
        'participantIds': [currentUserUid],
      },
      VideoSessionsRecord.collection.doc(sessionId),
    );
  }

  void setActiveStudent(
    String userId, {
    String? currentSessionId,
  }) {
    currentUser = _TestAuthUser(
      isLoggedIn: true,
      userId: userId,
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
        if (currentSessionId != null) 'currentSessionId': currentSessionId,
      },
      UsersRecord.collection.doc(userId),
    );
  }

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
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('Соединяем'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard toggles search CTA after successful start',
      (tester) async {
    setActiveStudent('student-stop-search-test');

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
    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(find.text('Начать поиск'), findsNothing);

    final permissionChecksAfterStart = _checkPermissionStatusCallCount;
    final permissionRequestsAfterStart = _requestPermissionsCallCount;
    final stopSearchButton = find.ancestor(
      of: stopSearchText,
      matching: find.byType(InkWell),
    );

    await tester.tap(stopSearchButton);
    await tester.tap(stopSearchButton);
    await tester.pump();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(_checkPermissionStatusCallCount, permissionChecksAfterStart);
    expect(_requestPermissionsCallCount, permissionRequestsAfterStart);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard renders connecting state and stops locally',
      (tester) async {
    currentUser = _TestAuthUser(
      isLoggedIn: true,
      userId: 'student-connecting-state-test',
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
      UsersRecord.collection.doc('student-connecting-state-test'),
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(
        const StudentsDashboardWidget(
          initialSearchState: StudentDashboardSearchState.connecting,
        ),
      ),
    );
    await tester.pump();

    final stopSearchText = find.text('Остановить поиск');
    expect(stopSearchText, findsOneWidget);
    expect(find.text('Соединяем'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('считаем людей рядом'), findsNothing);
    expect(find.textContaining('рядом с вами'), findsNothing);

    await tester.tap(
      find.ancestor(
        of: stopSearchText,
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Соединяем'), findsNothing);
    expect(find.byType(NoBalanceWidget), findsNothing);
    expect(_checkPermissionStatusCallCount, 0);
    expect(_requestPermissionsCallCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard maps active session stream to connecting',
      (tester) async {
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    setActiveStudent(
      'student-active-session-stream-test',
      currentSessionId: 'session-pending-confirmation-test',
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Соединяем'), findsNothing);

    activeSessionController.add(
      sessionFixture(
          'session-pending-confirmation-test', 'pending_confirmation'),
    );
    await tester.pump();

    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Соединяем'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);

    activeSessionController.add(
      sessionFixture('session-pending-confirmation-test', 'searching'),
    );
    await tester.pump();

    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(find.text('Соединяем'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('searching status fits compact dashboard layout', (tester) async {
    tester.view.physicalSize = const Size(360.0, 520.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    setActiveStudent('student-searching-compact-layout-test');

    await tester.pumpWidget(
      _buildDashboardTestApp(
        const StudentsDashboardWidget(),
        textScaleFactor: 1.8,
      ),
    );
    await tester.pump();

    final startSearchText = find.text('Начать поиск');
    await tester.tap(
      find.ancestor(
        of: startSearchText,
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('connecting status fits compact dashboard layout',
      (tester) async {
    tester.view.physicalSize = const Size(360.0, 520.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    setActiveStudent('student-connecting-compact-layout-test');

    await tester.pumpWidget(
      _buildDashboardTestApp(
        const StudentsDashboardWidget(
          initialSearchState: StudentDashboardSearchState.connecting,
        ),
        textScaleFactor: 1.8,
      ),
    );
    await tester.pump();

    expect(find.text('Соединяем'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard does not start search when permissions denied',
      (tester) async {
    _permissionStatus = _permissionDenied;
    setActiveStudent('student-permission-denied-test');

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

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('Соединяем'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard ignores double tap while search is starting',
      (tester) async {
    _permissionStatus = _permissionDenied;
    final permissionRequestCompleter = Completer<void>();
    _requestPermissionsHandler = (permissions) async {
      await permissionRequestCompleter.future;
      return <int, int>{
        for (final permission in permissions) permission: _permissionGranted,
      };
    };
    setActiveStudent('student-double-tap-search-test');

    await tester.pumpWidget(
      _buildDashboardTestApp(const StudentsDashboardWidget()),
    );
    await tester.pump();

    final startSearchText = find.text('Начать поиск');
    final startSearchButton = find.ancestor(
      of: startSearchText,
      matching: find.byType(InkWell),
    );

    await tester.tap(startSearchButton);
    await tester.pump();
    await tester.tap(startSearchButton);
    await tester.pump();

    expect(_requestPermissionsCallCount, 1);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);

    _permissionStatus = _permissionGranted;
    permissionRequestCompleter.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsOneWidget);

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
            isActive: true,
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
