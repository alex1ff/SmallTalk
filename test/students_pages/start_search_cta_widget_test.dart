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
import 'package:small_talk/flutter_flow/nav/nav.dart';
import 'package:small_talk/shared_pages/video_call_page/video_call_page_widget.dart';
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
Object? _checkPermissionStatusError;

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

Widget _buildDashboardRouterTestApp(
  GoRouter router, {
  double textScaleFactor = 1.0,
}) {
  return MaterialApp.router(
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
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
      child: child ?? const SizedBox.shrink(),
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
    _checkPermissionStatusError = null;
    StudentsDashboardWidget.debugUsageLimitReachedChecker = (_) async {
      return false;
    };
    StudentsDashboardWidget.debugActiveSessionReader = (_) async => null;
    StudentsDashboardWidget.debugStartSearchRequest = (_) async {
      return <String, dynamic>{'requestId': 'request-debug'};
    };
    StudentsDashboardWidget.debugHeartbeatSearchRequest = (_) async {};
    StudentsDashboardWidget.debugStopSearchRequest = (_) async {};
    StudentsDashboardWidget.debugAcceptCallRequest = null;
    StudentsDashboardWidget.debugGetSessionTokensRequest = null;
    StudentsDashboardWidget.debugAutoOpenSessionNavigator = null;
    StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation = true;

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
          final error = _checkPermissionStatusError;
          if (error != null) {
            throw error;
          }
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
    StudentsDashboardWidget.debugUsageLimitReachedChecker = null;
    StudentsDashboardWidget.debugActiveSessionReader = null;
    StudentsDashboardWidget.debugStartSearchRequest = null;
    StudentsDashboardWidget.debugHeartbeatSearchRequest = null;
    StudentsDashboardWidget.debugStopSearchRequest = null;
    StudentsDashboardWidget.debugAcceptCallRequest = null;
    StudentsDashboardWidget.debugGetSessionTokensRequest = null;
    StudentsDashboardWidget.debugAutoOpenSessionNavigator = null;
    StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation = false;
    currentUser = null;
    currentUserDocument = null;
  });

  VideoSessionsRecord sessionFixture(
    String sessionId,
    String status, {
    String? requesterId,
    String? responderId,
    String? dailyRoomUrl,
    String? dailyRoomName,
    String? meetingToken,
  }) {
    return VideoSessionsRecord.getDocumentFromData(
      {
        'status': status,
        'participantIds': [currentUserUid],
        if (requesterId != null) 'requesterId': requesterId,
        if (requesterId != null) 'studentId': requesterId,
        if (responderId != null) 'responderId': responderId,
        if (responderId != null) 'currentResponderId': responderId,
        if (responderId != null) 'currentTutorId': responderId,
        if (requesterId != null || responderId != null)
          'matchContext': {
            if (requesterId != null) 'requesterId': requesterId,
            if (responderId != null) 'responderId': responderId,
            if (responderId != null) 'currentResponderId': responderId,
          },
        if (dailyRoomUrl != null) 'dailyRoomUrl': dailyRoomUrl,
        if (dailyRoomName != null) 'dailyRoomName': dailyRoomName,
        if (meetingToken != null) 'meetingToken': meetingToken,
      },
      VideoSessionsRecord.collection.doc(sessionId),
    );
  }

  void setActiveStudent(
    String userId, {
    String? currentSessionId,
    bool isLoggedIn = true,
    bool hasActiveAccess = true,
    bool hasGiftAccess = false,
    bool isInCall = false,
  }) {
    currentUser = _TestAuthUser(
      isLoggedIn: isLoggedIn,
      userId: userId,
    );
    currentUserDocument = UsersRecord.getDocumentFromData(
      {
        'role': 'student',
        'display_name': 'Student',
        'isInCall': isInCall,
        'learningLanguage': {
          'code': 'en',
          'name': 'English',
        },
        if (hasActiveAccess)
          'subscription': {
            'productId': 'test',
            'expiresAt': DateTime.now().add(const Duration(days: 1)),
          },
        if (hasGiftAccess)
          'giftMinutes': {
            'minutes': 10.0,
            'expiresAt': DateTime.now().add(const Duration(hours: 1)),
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
    expect(_checkPermissionStatusCallCount, 0);
    expect(_requestPermissionsCallCount, 0);

    await tester.pump(const Duration(minutes: 10));
    await tester.pump();

    expect(find.text('Пока никого не нашли'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard requires auth before starting search',
      (tester) async {
    setActiveStudent(
      'student-start-search-auth-required-test',
      isLoggedIn: false,
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(const StudentsDashboardWidget()),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Войдите в аккаунт'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_checkPermissionStatusCallCount, 0);
    expect(_requestPermissionsCallCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard rejects stale auth document before search',
      (tester) async {
    setActiveStudent('student-start-search-stale-doc-old-test');
    currentUser = _TestAuthUser(
      isLoggedIn: true,
      userId: 'student-start-search-stale-doc-new-test',
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(const StudentsDashboardWidget()),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Войдите в аккаунт'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(_checkPermissionStatusCallCount, 0);
    expect(_requestPermissionsCallCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard blocks search during active call flag',
      (tester) async {
    setActiveStudent(
      'student-start-search-in-call-test',
      isInCall: true,
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(const StudentsDashboardWidget()),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Завершите текущий звонок'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_checkPermissionStatusCallCount, 0);
    expect(_requestPermissionsCallCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard blocks search during active call session',
      (tester) async {
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    setActiveStudent(
      'student-start-search-active-session-test',
      currentSessionId: 'session-start-search-active-test',
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
        ),
      ),
    );
    await tester.pump();

    activeSessionController.add(
      sessionFixture('session-start-search-active-test', 'active'),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Завершите текущий звонок'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_checkPermissionStatusCallCount, 0);
    expect(_requestPermissionsCallCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard checks current session before first snapshot',
      (tester) async {
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    const sessionId = 'session-start-search-preflight-active-test';
    setActiveStudent(
      'student-start-search-preflight-active-test',
      currentSessionId: sessionId,
    );
    StudentsDashboardWidget.debugActiveSessionReader = (_) async {
      return sessionFixture(sessionId, 'active');
    };

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Завершите текущий звонок'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(_checkPermissionStatusCallCount, 0);
    expect(_requestPermissionsCallCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard handles current session preflight errors',
      (tester) async {
    const sessionId = 'session-start-search-preflight-error-test';
    setActiveStudent(
      'student-start-search-preflight-error-test',
      currentSessionId: sessionId,
    );
    StudentsDashboardWidget.debugActiveSessionReader = (_) async {
      throw StateError('current session unavailable');
    };

    await tester.pumpWidget(
      _buildDashboardTestApp(const StudentsDashboardWidget()),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Не удалось обновить поиск'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(_checkPermissionStatusCallCount, 0);
    expect(_requestPermissionsCallCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard blocks search when usage limit is reached',
      (tester) async {
    setActiveStudent('student-start-search-usage-limit-test');

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          usageLimitReachedChecker: (_) async => true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Лимит звонков исчерпан'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_checkPermissionStatusCallCount, 0);
    expect(_requestPermissionsCallCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'student dashboard allows gift minutes access without subscription',
      (tester) async {
    setActiveStudent(
      'student-start-search-gift-access-test',
      hasActiveAccess: false,
      hasGiftAccess: true,
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(const StudentsDashboardWidget()),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.byType(NoBalanceWidget), findsNothing);
    expect(_checkPermissionStatusCallCount, greaterThan(0));

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

  testWidgets('student dashboard sends search heartbeat every thirty seconds',
      (tester) async {
    setActiveStudent('student-heartbeat-test');
    final startPayloads = <Map<String, dynamic>>[];
    final heartbeatPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          startSearchRequest: (payload) async {
            startPayloads.add(Map<String, dynamic>.from(payload));
            return <String, dynamic>{'requestId': 'request-heartbeat-test'};
          },
          heartbeatSearchRequest: (payload) async {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(startPayloads, hasLength(1));
    expect(startPayloads.single['appState'], 'foreground');
    expect(startPayloads.single['language'], 'en');
    expect(heartbeatPayloads, isEmpty);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();

    expect(heartbeatPayloads, hasLength(1));
    expect(heartbeatPayloads.single, <String, dynamic>{
      'requestId': 'request-heartbeat-test',
      'appState': 'foreground',
    });

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();

    expect(heartbeatPayloads, hasLength(2));

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();

    expect(heartbeatPayloads, hasLength(2));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard sends app lifecycle search heartbeat',
      (tester) async {
    setActiveStudent('student-heartbeat-lifecycle-test');
    final heartbeatPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          startSearchRequest: (_) async {
            return <String, dynamic>{'requestId': 'request-lifecycle-test'};
          },
          heartbeatSearchRequest: (payload) async {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(heartbeatPayloads, hasLength(1));
    expect(heartbeatPayloads.last, <String, dynamic>{
      'requestId': 'request-lifecycle-test',
      'appState': 'background',
    });

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(heartbeatPayloads, hasLength(2));
    expect(heartbeatPayloads.last, <String, dynamic>{
      'requestId': 'request-lifecycle-test',
      'appState': 'foreground',
    });

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard heartbeats immediately for reused search',
      (tester) async {
    setActiveStudent('student-heartbeat-reused-test');
    final heartbeatPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          startSearchRequest: (_) async {
            return <String, dynamic>{
              'requestId': 'request-reused-test',
              'reused': true,
            };
          },
          heartbeatSearchRequest: (payload) async {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(heartbeatPayloads, hasLength(1));
    expect(heartbeatPayloads.single, <String, dynamic>{
      'requestId': 'request-reused-test',
      'appState': 'foreground',
    });

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'student dashboard queues lifecycle heartbeat while one is active',
      (tester) async {
    setActiveStudent('student-heartbeat-lifecycle-queued-test');
    final firstHeartbeatCompleter = Completer<void>();
    final heartbeatPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          startSearchRequest: (_) async {
            return <String, dynamic>{
              'requestId': 'request-lifecycle-queued-test',
            };
          },
          heartbeatSearchRequest: (payload) {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
            if (heartbeatPayloads.length == 1) {
              return firstHeartbeatCompleter.future;
            }
            return Future<void>.value();
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    await tester.pump(StudentsDashboardWidget.heartbeatSearchInterval);
    await tester.pump();

    expect(heartbeatPayloads, hasLength(1));
    expect(heartbeatPayloads.single['appState'], 'foreground');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(heartbeatPayloads, hasLength(1));

    firstHeartbeatCompleter.complete();
    await tester.pump();

    expect(heartbeatPayloads, hasLength(2));
    expect(heartbeatPayloads.last, <String, dynamic>{
      'requestId': 'request-lifecycle-queued-test',
      'appState': 'background',
    });

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard ignores stale heartbeat response after stop',
      (tester) async {
    setActiveStudent('student-heartbeat-stale-response-test');
    final heartbeatCompleter = Completer<Map<String, dynamic>>();
    final heartbeatPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          startSearchRequest: (_) async {
            return <String, dynamic>{
              'requestId': 'request-stale-response-test',
            };
          },
          heartbeatSearchRequest: (payload) {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
            return heartbeatCompleter.future;
          },
          stopSearchRequest: (_) async => null,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    await tester.pump(StudentsDashboardWidget.heartbeatSearchInterval);
    await tester.pump();

    expect(heartbeatPayloads, hasLength(1));

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    heartbeatCompleter.complete(<String, dynamic>{
      'errorCode': 'expired',
      'reason': 'expired',
    });
    await tester.pump();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Пока никого не нашли'), findsNothing);
    expect(find.text('Остановить поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'student dashboard handles start search response without request id',
      (tester) async {
    setActiveStudent('student-start-search-missing-request-id-test');

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          startSearchRequest: (_) async => <String, dynamic>{},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Не удалось начать поиск'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('active session transition stops search heartbeat',
      (tester) async {
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    setActiveStudent(
      'student-active-session-stops-heartbeat-test',
      currentSessionId: 'session-active-stops-heartbeat-test',
    );
    final heartbeatPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
          startSearchRequest: (_) async {
            return <String, dynamic>{'requestId': 'request-active-test'};
          },
          heartbeatSearchRequest: (payload) async {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Ищем собеседника'), findsOneWidget);

    activeSessionController.add(
      sessionFixture('session-active-stops-heartbeat-test', 'active'),
    );
    await tester.pump();

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();

    expect(heartbeatPayloads, isEmpty);
    expect(find.text('Ищем собеседника'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'student dashboard manual stop calls backend once and stays responsive',
      (tester) async {
    setActiveStudent('student-stop-search-backend-test');
    final stopCompleter = Completer<void>();
    var stopRequestCount = 0;
    final stoppedSessionIds = <String?>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          stopSearchRequest: (sessionId) {
            stopRequestCount += 1;
            stoppedSessionIds.add(sessionId);
            return stopCompleter.future;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    final stopSearchButton = find.ancestor(
      of: find.text('Остановить поиск'),
      matching: find.byType(InkWell),
    );

    await tester.tap(stopSearchButton);
    await tester.tap(stopSearchButton);
    await tester.pump();

    expect(stopRequestCount, 1);
    expect(stoppedSessionIds, [null]);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);

    stopCompleter.complete();
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'student dashboard deduplicates immediate manual stop before rebuild',
      (tester) async {
    setActiveStudent('student-stop-search-immediate-test');
    var stopRequestCount = 0;

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          stopSearchRequest: (_) async {
            stopRequestCount += 1;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    final stopSearchButton = find.ancestor(
      of: find.text('Остановить поиск'),
      matching: find.byType(InkWell),
    );

    await tester.tap(stopSearchButton);
    await tester.tap(stopSearchButton);
    await tester.pump();

    expect(stopRequestCount, 1);
    expect(find.text('Начать поиск'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard restarts after immediate backend stop',
      (tester) async {
    setActiveStudent('student-restart-after-immediate-stop-test');

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          stopSearchRequest: (_) async {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard queues restart while backend stop is pending',
      (tester) async {
    setActiveStudent('student-restart-while-stop-pending-test');
    final stopCompleter = Completer<void>();

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          stopSearchRequest: (_) => stopCompleter.future,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    final permissionChecksAfterStop = _checkPermissionStatusCallCount;
    final permissionRequestsAfterStop = _requestPermissionsCallCount;

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(_checkPermissionStatusCallCount, permissionChecksAfterStop);
    expect(_requestPermissionsCallCount, permissionRequestsAfterStop);

    stopCompleter.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(find.text('Начать поиск'), findsNothing);
    expect(_checkPermissionStatusCallCount,
        greaterThan(permissionChecksAfterStop));
    expect(_requestPermissionsCallCount, permissionRequestsAfterStop);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard drops queued restart when backend stop fails',
      (tester) async {
    setActiveStudent('student-restart-after-stop-failure-test');
    final stopCompleter = Completer<void>();

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          stopSearchRequest: (_) => stopCompleter.future,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    final permissionChecksAfterStop = _checkPermissionStatusCallCount;
    final permissionRequestsAfterStop = _requestPermissionsCallCount;

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    stopCompleter.completeError(StateError('stopSearch failed'));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(_checkPermissionStatusCallCount, permissionChecksAfterStop);
    expect(_requestPermissionsCallCount, permissionRequestsAfterStop);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard drops queued restart when backend stop hangs',
      (tester) async {
    setActiveStudent('student-restart-after-stop-timeout-test');
    final neverCompletes = Completer<void>();

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          stopSearchRequest: (_) => neverCompletes.future,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    final permissionChecksAfterStop = _checkPermissionStatusCallCount;
    final permissionRequestsAfterStop = _requestPermissionsCallCount;

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    await tester.pump(StudentsDashboardWidget.stopSearchRequestTimeout);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(_checkPermissionStatusCallCount, permissionChecksAfterStop);
    expect(_requestPermissionsCallCount, permissionRequestsAfterStop);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard manual stop passes active session id',
      (tester) async {
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    setActiveStudent(
      'student-stop-search-session-test',
      currentSessionId: 'session-stop-search-test',
    );
    String? stoppedSessionId;

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
          stopSearchRequest: (sessionId) async {
            stoppedSessionId = sessionId;
          },
        ),
      ),
    );
    await tester.pump();

    activeSessionController.add(
      sessionFixture('session-stop-search-test', 'searching'),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(stoppedSessionId, 'session-stop-search-test');
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'student dashboard suppresses late active session after local stop',
      (tester) async {
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    setActiveStudent(
      'student-stop-search-late-session-test',
      currentSessionId: 'session-late-stop-search-test',
    );
    String? stoppedSessionId;

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          initialSearchState: StudentDashboardSearchState.searching,
          activeSessionStream: activeSessionController.stream,
          stopSearchRequest: (sessionId) async {
            stoppedSessionId = sessionId;
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsOneWidget);

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    activeSessionController.add(
      sessionFixture('session-late-stop-search-test', 'searching'),
    );
    await tester.pump();

    expect(stoppedSessionId, 'session-late-stop-search-test');
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'student dashboard restores protected connecting session after stop noop',
      (tester) async {
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    setActiveStudent(
      'student-protected-connecting-stop-test',
      currentSessionId: 'session-protected-connecting-stop-test',
    );
    final stopCompleter = Completer<dynamic>();
    String? stoppedSessionId;

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
          stopSearchRequest: (sessionId) {
            stoppedSessionId = sessionId;
            return stopCompleter.future;
          },
        ),
      ),
    );
    await tester.pump();

    activeSessionController.add(
      sessionFixture('session-protected-connecting-stop-test', 'connecting'),
    );
    await tester.pump();

    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Соединяем'), findsOneWidget);

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Соединяем'), findsNothing);

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    stopCompleter.complete({
      'status': 'stopped',
      'stopped': true,
      'reason': 'manual',
      'cancelledSessionId': null,
      'videoSession': {
        'status': 'noop',
        'stopped': false,
        'reason': 'session_not_searching',
      },
    });
    await tester.pump();
    await tester.pump();

    expect(stoppedSessionId, 'session-protected-connecting-stop-test');
    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Соединяем'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard stops a new session while previous stop waits',
      (tester) async {
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    setActiveStudent(
      'student-stop-search-new-session-test',
      currentSessionId: 'session-first-stop-test',
    );
    final firstStopCompleter = Completer<void>();
    final stoppedSessionIds = <String?>[];
    Future<void> stopSearchRequest(String? sessionId) {
      stoppedSessionIds.add(sessionId);
      if (sessionId == 'session-first-stop-test') {
        return firstStopCompleter.future;
      }
      return Future<void>.value();
    }

    final dashboard = StudentsDashboardWidget(
      activeSessionStream: activeSessionController.stream,
      stopSearchRequest: stopSearchRequest,
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(
        dashboard,
      ),
    );
    await tester.pump();

    activeSessionController.add(
      sessionFixture('session-first-stop-test', 'searching'),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    currentUserDocument = UsersRecord.getDocumentFromData(
      {
        'role': 'student',
        'display_name': 'Student',
        'isInCall': false,
        'learningLanguage': {
          'code': 'en',
          'name': 'English',
        },
        'subscription': {
          'productId': 'test',
          'expiresAt': DateTime.now().add(const Duration(days: 1)),
        },
        'currentSessionId': 'session-second-stop-test',
      },
      UsersRecord.collection.doc('student-stop-search-new-session-test'),
    );
    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: Stream<VideoSessionsRecord?>.value(
            sessionFixture('session-second-stop-test', 'searching'),
          ),
          stopSearchRequest: stopSearchRequest,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Остановить поиск'), findsOneWidget);

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(stoppedSessionIds, [
      'session-first-stop-test',
      'session-second-stop-test',
    ]);
    expect(find.text('Начать поиск'), findsOneWidget);

    firstStopCompleter.complete();
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard suppresses late session after user-level stop',
      (tester) async {
    setActiveStudent('student-stop-search-user-key-test');
    final userStopCompleter = Completer<void>();
    final stoppedSessionIds = <String?>[];
    Future<void> stopSearchRequest(String? sessionId) {
      stoppedSessionIds.add(sessionId);
      if (sessionId == null) {
        return userStopCompleter.future;
      }
      return Future<void>.value();
    }

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          stopSearchRequest: stopSearchRequest,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    currentUserDocument = UsersRecord.getDocumentFromData(
      {
        'role': 'student',
        'display_name': 'Student',
        'isInCall': false,
        'learningLanguage': {
          'code': 'en',
          'name': 'English',
        },
        'subscription': {
          'productId': 'test',
          'expiresAt': DateTime.now().add(const Duration(days: 1)),
        },
        'currentSessionId': 'session-user-key-stop-test',
      },
      UsersRecord.collection.doc('student-stop-search-user-key-test'),
    );
    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: Stream<VideoSessionsRecord?>.value(
            sessionFixture('session-user-key-stop-test', 'searching'),
          ),
          stopSearchRequest: stopSearchRequest,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(stoppedSessionIds, [null]);

    userStopCompleter.complete();
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'student dashboard shows new session after user-level stop drains',
      (tester) async {
    setActiveStudent('student-new-session-after-user-stop-test');
    final userStopCompleter = Completer<void>();
    final stoppedSessionIds = <String?>[];
    Future<void> stopSearchRequest(String? sessionId) {
      stoppedSessionIds.add(sessionId);
      if (sessionId == null) {
        return userStopCompleter.future;
      }
      return Future<void>.value();
    }

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          stopSearchRequest: stopSearchRequest,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    userStopCompleter.complete();
    await tester.pump();

    currentUserDocument = UsersRecord.getDocumentFromData(
      {
        'role': 'student',
        'display_name': 'Student',
        'isInCall': false,
        'learningLanguage': {
          'code': 'en',
          'name': 'English',
        },
        'subscription': {
          'productId': 'test',
          'expiresAt': DateTime.now().add(const Duration(days: 1)),
        },
        'currentSessionId': 'session-after-user-stop-test',
      },
      UsersRecord.collection.doc('student-new-session-after-user-stop-test'),
    );
    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: Stream<VideoSessionsRecord?>.value(
            sessionFixture('session-after-user-stop-test', 'searching'),
          ),
          stopSearchRequest: stopSearchRequest,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsOneWidget);

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(stoppedSessionIds, [null, 'session-after-user-stop-test']);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'student dashboard reveals pending session after user stop drains',
      (tester) async {
    setActiveStudent('student-pending-session-after-user-stop-test');
    final userStopCompleter = Completer<void>();
    final stoppedSessionIds = <String?>[];
    Future<void> stopSearchRequest(String? sessionId) {
      stoppedSessionIds.add(sessionId);
      if (sessionId == null) {
        return userStopCompleter.future;
      }
      return Future<void>.value();
    }

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          stopSearchRequest: stopSearchRequest,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    currentUserDocument = UsersRecord.getDocumentFromData(
      {
        'role': 'student',
        'display_name': 'Student',
        'isInCall': false,
        'learningLanguage': {
          'code': 'en',
          'name': 'English',
        },
        'subscription': {
          'productId': 'test',
          'expiresAt': DateTime.now().add(const Duration(days: 1)),
        },
        'currentSessionId': 'session-pending-user-stop-test',
      },
      UsersRecord.collection.doc(
        'student-pending-session-after-user-stop-test',
      ),
    );
    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: Stream<VideoSessionsRecord?>.value(
            sessionFixture('session-pending-user-stop-test', 'searching'),
          ),
          stopSearchRequest: stopSearchRequest,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);

    userStopCompleter.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(stoppedSessionIds, [null]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard suppresses stream error after manual stop',
      (tester) async {
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    setActiveStudent(
      'student-stop-search-stream-error-test',
      currentSessionId: 'session-stop-stream-error-test',
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          initialSearchState: StudentDashboardSearchState.searching,
          activeSessionStream: activeSessionController.stream,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    activeSessionController.addError(
      StateError('stream failed after manual stop'),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Не удалось обновить поиск'), findsNothing);
    expect(find.text('Остановить поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard keeps stopped state when backend stop fails',
      (tester) async {
    setActiveStudent('student-stop-search-failure-test');

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          stopSearchRequest: (_) async {
            throw StateError('stopSearch failed');
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard shows no match state after ten minutes',
      (tester) async {
    setActiveStudent('student-no-match-timeout-test');

    await tester.pumpWidget(
      _buildDashboardTestApp(const StudentsDashboardWidget()),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Ищем собеседника'), findsOneWidget);

    await tester.pump(const Duration(minutes: 10));
    await tester.pump();

    expect(find.text('Пока никого не нашли'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(find.text('Пока никого не нашли'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard stop cancels no match timeout',
      (tester) async {
    setActiveStudent('student-stop-before-timeout-test');

    await tester.pumpWidget(
      _buildDashboardTestApp(const StudentsDashboardWidget()),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    final permissionChecksAfterStart = _checkPermissionStatusCallCount;
    final permissionRequestsAfterStart = _requestPermissionsCallCount;

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(minutes: 10));
    await tester.pump();

    expect(find.text('Пока никого не нашли'), findsNothing);
    expect(find.text('Начать поиск'), findsOneWidget);
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

  testWidgets('foreground responder accepts student pair and opens the call',
      (tester) async {
    StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation = false;
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    const sessionId = 'session-foreground-responder-test';
    const requesterId = 'student-foreground-requester-test';
    const responderId = 'student-foreground-responder-test';
    final acceptedSessionIds = <String>[];
    final openedSessions = <Map<String, String?>>[];
    StudentsDashboardWidget.debugAcceptCallRequest = (sessionId) async {
      acceptedSessionIds.add(sessionId);
      return <String, dynamic>{
        'status': 'connected',
        'sessionId': sessionId,
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    StudentsDashboardWidget.debugAutoOpenSessionNavigator = (
      context,
      videoDocRef, {
      roomUrl,
      meetingToken,
      roomName,
    }) {
      openedSessions.add({
        'sessionId': videoDocRef.id,
        'roomUrl': roomUrl,
        'meetingToken': meetingToken,
        'roomName': roomName,
      });
    };
    setActiveStudent(responderId, currentSessionId: sessionId);

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
        ),
      ),
    );
    await tester.pump();

    activeSessionController.add(
      sessionFixture(
        sessionId,
        'pending_confirmation',
        requesterId: requesterId,
        responderId: responderId,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(acceptedSessionIds, [sessionId]);
    expect(openedSessions, hasLength(1));
    expect(openedSessions.single['sessionId'], sessionId);
    expect(openedSessions.single['roomUrl'], 'https://daily.test/$sessionId');
    expect(openedSessions.single['meetingToken'], 'token-$sessionId');
    expect(openedSessions.single['roomName'], 'room-$sessionId');

    activeSessionController.add(
      sessionFixture(
        sessionId,
        'pending_confirmation',
        requesterId: requesterId,
        responderId: responderId,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(acceptedSessionIds, [sessionId]);
    expect(openedSessions, hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('foreground requester does not accept pending student pair',
      (tester) async {
    StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation = false;
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    const sessionId = 'session-foreground-requester-pending-test';
    const requesterId = 'student-foreground-requester-pending-test';
    const responderId = 'student-foreground-responder-pending-test';
    final acceptedSessionIds = <String>[];
    StudentsDashboardWidget.debugAcceptCallRequest = (sessionId) async {
      acceptedSessionIds.add(sessionId);
      return <String, dynamic>{
        'status': 'connected',
        'roomUrl': 'https://daily.test/$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    setActiveStudent(requesterId, currentSessionId: sessionId);

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
        ),
      ),
    );
    await tester.pump();

    activeSessionController.add(
      sessionFixture(
        sessionId,
        'pending_confirmation',
        requesterId: requesterId,
        responderId: responderId,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(acceptedSessionIds, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('foreground responder retries accept after transient failure',
      (tester) async {
    StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation = false;
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    const sessionId = 'session-foreground-accept-retry-test';
    const requesterId = 'student-foreground-accept-retry-requester-test';
    const responderId = 'student-foreground-accept-retry-responder-test';
    var acceptAttempts = 0;
    final openedSessionIds = <String>[];
    StudentsDashboardWidget.debugAcceptCallRequest = (sessionId) async {
      acceptAttempts += 1;
      if (acceptAttempts == 1) {
        throw StateError('temporary accept failure');
      }
      return <String, dynamic>{
        'status': 'connected',
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    StudentsDashboardWidget.debugAutoOpenSessionNavigator = (
      context,
      videoDocRef, {
      roomUrl,
      meetingToken,
      roomName,
    }) {
      openedSessionIds.add(videoDocRef.id);
    };
    setActiveStudent(responderId, currentSessionId: sessionId);

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
        ),
      ),
    );
    await tester.pump();

    activeSessionController.add(
      sessionFixture(
        sessionId,
        'pending_confirmation',
        requesterId: requesterId,
        responderId: responderId,
      ),
    );
    await tester.pump();
    await tester.pump();

    activeSessionController.add(
      sessionFixture(
        sessionId,
        'pending_confirmation',
        requesterId: requesterId,
        responderId: responderId,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(acceptAttempts, 2);
    expect(openedSessionIds, [sessionId]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('foreground ready student pair session routes to video call once',
      (tester) async {
    StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation = false;
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    const sessionId = 'session-foreground-ready-route-test';
    const requesterId = 'student-foreground-ready-requester-test';
    const responderId = 'student-foreground-ready-responder-test';
    final tokenSessionIds = <String>[];
    StudentsDashboardWidget.debugGetSessionTokensRequest = (sessionId) async {
      tokenSessionIds.add(sessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    setActiveStudent(requesterId, currentSessionId: sessionId);
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => StudentsDashboardWidget(
            activeSessionStream: activeSessionController.stream,
          ),
        ),
        GoRoute(
          name: VideoCallPageWidget.routeName,
          path: VideoCallPageWidget.routePath,
          builder: (context, state) => const SizedBox(
            key: Key('video-call-route'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    activeSessionController.add(
      sessionFixture(
        sessionId,
        'connecting',
        requesterId: requesterId,
        responderId: responderId,
        dailyRoomUrl: 'https://daily.test/$sessionId',
        dailyRoomName: 'room-$sessionId',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      router.getCurrentLocation(),
      startsWith(VideoCallPageWidget.routePath),
    );
    expect(router.getCurrentLocation(), contains('videoDocRef='));
    expect(router.getCurrentLocation(), contains('meetingToken='));
    expect(tokenSessionIds, [sessionId]);

    activeSessionController.add(
      sessionFixture(
        sessionId,
        'connecting',
        requesterId: requesterId,
        responderId: responderId,
        dailyRoomUrl: 'https://daily.test/$sessionId',
        dailyRoomName: 'room-$sessionId',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      router.getCurrentLocation(),
      startsWith(VideoCallPageWidget.routePath),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ready session ignores document token and fetches user token',
      (tester) async {
    StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation = false;
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    const sessionId = 'session-ready-doc-token-test';
    const requesterId = 'student-ready-doc-token-requester-test';
    const responderId = 'student-ready-doc-token-responder-test';
    final openedSessions = <Map<String, String?>>[];
    StudentsDashboardWidget.debugGetSessionTokensRequest = (sessionId) async {
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'callable-token-$sessionId',
      };
    };
    StudentsDashboardWidget.debugAutoOpenSessionNavigator = (
      context,
      videoDocRef, {
      roomUrl,
      meetingToken,
      roomName,
    }) {
      openedSessions.add({
        'sessionId': videoDocRef.id,
        'meetingToken': meetingToken,
      });
    };
    setActiveStudent(requesterId, currentSessionId: sessionId);

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
        ),
      ),
    );
    await tester.pump();

    activeSessionController.add(
      sessionFixture(
        sessionId,
        'connecting',
        requesterId: requesterId,
        responderId: responderId,
        dailyRoomUrl: 'https://daily.test/$sessionId',
        dailyRoomName: 'room-$sessionId',
        meetingToken: 'doc-token-$sessionId',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(openedSessions, hasLength(1));
    expect(
      openedSessions.single['meetingToken'],
      'callable-token-$sessionId',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ready student pair session waits for meeting token',
      (tester) async {
    StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation = false;
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    const sessionId = 'session-ready-no-token-test';
    const requesterId = 'student-ready-no-token-requester-test';
    const responderId = 'student-ready-no-token-responder-test';
    final tokenSessionIds = <String>[];
    StudentsDashboardWidget.debugGetSessionTokensRequest = (sessionId) async {
      tokenSessionIds.add(sessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
      };
    };
    setActiveStudent(requesterId, currentSessionId: sessionId);
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => StudentsDashboardWidget(
            activeSessionStream: activeSessionController.stream,
          ),
        ),
        GoRoute(
          name: VideoCallPageWidget.routeName,
          path: VideoCallPageWidget.routePath,
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    activeSessionController.add(
      sessionFixture(
        sessionId,
        'connecting',
        requesterId: requesterId,
        responderId: responderId,
        dailyRoomUrl: 'https://daily.test/$sessionId',
        dailyRoomName: 'room-$sessionId',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tokenSessionIds, [sessionId]);
    expect(router.getCurrentLocation(), StudentsDashboardWidget.routePath);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('background student pair session does not auto-open',
      (tester) async {
    StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation = false;
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    const sessionId = 'session-background-pair-test';
    const requesterId = 'student-background-requester-test';
    const responderId = 'student-background-responder-test';
    final acceptedSessionIds = <String>[];
    final openedSessionIds = <String>[];
    StudentsDashboardWidget.debugAcceptCallRequest = (sessionId) async {
      acceptedSessionIds.add(sessionId);
      return <String, dynamic>{
        'status': 'connected',
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    StudentsDashboardWidget.debugAutoOpenSessionNavigator = (
      context,
      videoDocRef, {
      roomUrl,
      meetingToken,
      roomName,
    }) {
      openedSessionIds.add(videoDocRef.id);
    };
    setActiveStudent(responderId, currentSessionId: sessionId);

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
        ),
      ),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    activeSessionController.add(
      sessionFixture(
        sessionId,
        'pending_confirmation',
        requesterId: requesterId,
        responderId: responderId,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(acceptedSessionIds, isEmpty);
    expect(openedSessionIds, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(acceptedSessionIds, [sessionId]);
    expect(openedSessionIds, [sessionId]);

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

    activeSessionController.add(
      sessionFixture(
          'session-pending-confirmation-test', 'no_tutors_available'),
    );
    await tester.pump();

    expect(find.text('Пока никого не нашли'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('active session stream errors keep last session search state',
      (tester) async {
    Future<void> verifyCachedState({
      required String userId,
      required String sessionId,
      required String status,
      required String statusText,
      required String buttonText,
    }) async {
      final activeSessionController = StreamController<VideoSessionsRecord?>();
      addTearDown(activeSessionController.close);
      setActiveStudent(userId, currentSessionId: sessionId);

      await tester.pumpWidget(
        _buildDashboardTestApp(
          StudentsDashboardWidget(
            activeSessionStream: activeSessionController.stream,
          ),
        ),
      );
      await tester.pump();

      activeSessionController.add(sessionFixture(sessionId, status));
      await tester.pump();

      expect(find.text(statusText), findsOneWidget);
      expect(find.text(buttonText), findsOneWidget);

      activeSessionController.addError(
        StateError('active session stream failed after $status'),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(statusText), findsOneWidget);
      expect(find.text(buttonText), findsOneWidget);
      expect(find.text('Не удалось обновить поиск'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    }

    await verifyCachedState(
      userId: 'student-stream-error-after-connecting-test',
      sessionId: 'session-error-after-connecting-test',
      status: 'pending_confirmation',
      statusText: 'Соединяем',
      buttonText: 'Остановить поиск',
    );
    await verifyCachedState(
      userId: 'student-stream-error-after-searching-test',
      sessionId: 'session-error-after-searching-test',
      status: 'searching',
      statusText: 'Ищем собеседника',
      buttonText: 'Остановить поиск',
    );
    await verifyCachedState(
      userId: 'student-stream-error-after-no-match-test',
      sessionId: 'session-error-after-no-match-test',
      status: 'no_tutors_available',
      statusText: 'Пока никого не нашли',
      buttonText: 'Начать поиск',
    );
  });

  testWidgets('active session stream error ignores stale cached session',
      (tester) async {
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    const userId = 'student-stream-error-stale-cache-test';
    const oldSessionId = 'session-stream-error-stale-cache-old-test';
    const newSessionId = 'session-stream-error-stale-cache-new-test';
    setActiveStudent(userId, currentSessionId: oldSessionId);

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
        ),
      ),
    );
    await tester.pump();

    activeSessionController.add(sessionFixture(oldSessionId, 'searching'));
    await tester.pump();

    expect(find.text('Ищем собеседника'), findsOneWidget);

    setActiveStudent(userId, currentSessionId: newSessionId);
    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('Начать поиск'), findsOneWidget);

    activeSessionController.addError(
      StateError('new session stream failed after stale cached session'),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Не удалось обновить поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('Начать поиск'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pair session stream clears stale no match timeout',
      (tester) async {
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    setActiveStudent(
      'student-stream-prevents-timeout-test',
      currentSessionId: 'session-prevents-timeout-test',
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(minutes: 9, seconds: 59));

    activeSessionController.add(
      sessionFixture('session-prevents-timeout-test', 'searching'),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Пока никого не нашли'), findsOneWidget);

    activeSessionController.add(
      sessionFixture('session-prevents-timeout-test', 'pending_confirmation'),
    );
    await tester.pump();

    expect(find.text('Соединяем'), findsOneWidget);
    expect(find.text('Пока никого не нашли'), findsNothing);

    activeSessionController.add(
      sessionFixture('session-prevents-timeout-test', 'ended'),
    );
    await tester.pump();

    expect(find.text('Пока никого не нашли'), findsNothing);
    expect(find.text('Начать поиск'), findsOneWidget);

    activeSessionController.add(null);
    await tester.pump();

    expect(find.text('Пока никого не нашли'), findsNothing);
    expect(find.text('Начать поиск'), findsOneWidget);

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

  testWidgets('no match status fits compact dashboard layout', (tester) async {
    tester.view.physicalSize = const Size(360.0, 520.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    setActiveStudent('student-no-match-compact-layout-test');

    await tester.pumpWidget(
      _buildDashboardTestApp(
        const StudentsDashboardWidget(
          initialSearchState: StudentDashboardSearchState.noMatchFound,
        ),
        textScaleFactor: 1.8,
      ),
    );
    await tester.pump();

    expect(find.text('Пока никого не нашли'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
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
    expect(find.text('Разрешите камеру и микрофон'), findsOneWidget);

    await tester.pump(const Duration(minutes: 10));
    await tester.pump();

    expect(find.text('Пока никого не нашли'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard handles permission plugin errors and retries',
      (tester) async {
    _checkPermissionStatusError = PlatformException(
      code: 'permission_error',
      message: 'permission check failed',
    );
    setActiveStudent('student-permission-exception-test');

    await tester.pumpWidget(
      _buildDashboardTestApp(const StudentsDashboardWidget()),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Не удалось начать поиск'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    _checkPermissionStatusError = null;

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(find.text('Не удалось начать поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard handles active session stream errors',
      (tester) async {
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    setActiveStudent(
      'student-stream-error-test',
      currentSessionId: 'session-stream-error-test',
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
        ),
      ),
    );
    await tester.pump();

    activeSessionController.addError(StateError('session stream failed'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Не удалось обновить поиск'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(find.text('Не удалось обновить поиск'), findsNothing);

    await tester.pump();

    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(find.text('Не удалось обновить поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('active session stream recovery clears stream error',
      (tester) async {
    Future<void> pumpStreamDashboard({
      required StreamController<VideoSessionsRecord?> controller,
      required String userId,
      required String sessionId,
    }) async {
      setActiveStudent(userId, currentSessionId: sessionId);
      await tester.pumpWidget(
        _buildDashboardTestApp(
          StudentsDashboardWidget(activeSessionStream: controller.stream),
        ),
      );
      await tester.pump();
    }

    final idleRecoveryController = StreamController<VideoSessionsRecord?>();
    addTearDown(idleRecoveryController.close);
    await pumpStreamDashboard(
      controller: idleRecoveryController,
      userId: 'student-stream-error-idle-recovery-test',
      sessionId: 'session-stream-error-idle-recovery-test',
    );

    idleRecoveryController.addError(StateError('session stream failed'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Не удалось обновить поиск'), findsOneWidget);

    idleRecoveryController.add(null);
    await tester.pump();

    expect(find.text('Не удалось обновить поиск'), findsNothing);
    expect(find.text('Начать поиск'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());

    final activeRecoveryController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeRecoveryController.close);
    const activeRecoverySessionId = 'session-stream-error-active-recovery-test';
    await pumpStreamDashboard(
      controller: activeRecoveryController,
      userId: 'student-stream-error-active-recovery-test',
      sessionId: activeRecoverySessionId,
    );

    activeRecoveryController.addError(StateError('session stream failed'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Не удалось обновить поиск'), findsOneWidget);

    activeRecoveryController.add(
      sessionFixture(activeRecoverySessionId, 'searching'),
    );
    await tester.pump();

    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(find.text('Не удалось обновить поиск'), findsNothing);

    activeRecoveryController.add(
      sessionFixture(activeRecoverySessionId, 'ended'),
    );
    await tester.pump();

    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('Не удалось обновить поиск'), findsNothing);
    expect(find.text('Начать поиск'), findsOneWidget);

    activeRecoveryController.add(null);
    await tester.pump();

    expect(find.text('Не удалось обновить поиск'), findsNothing);
    expect(find.text('Начать поиск'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('search error status fits compact dashboard layout',
      (tester) async {
    tester.view.physicalSize = const Size(360.0, 520.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    _permissionStatus = _permissionDenied;
    setActiveStudent('student-search-error-compact-layout-test');

    await tester.pumpWidget(
      _buildDashboardTestApp(
        const StudentsDashboardWidget(),
        textScaleFactor: 1.8,
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(find.text('Разрешите камеру и микрофон'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

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
