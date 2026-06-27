import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/components/no_balance_widget.dart';
import 'package:small_talk/components/student_start_search_button.dart';
import 'package:small_talk/custom_code/actions/check_active_session_and_navigate.dart';
import 'package:small_talk/custom_code/actions/start_student_session_listener.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';
import 'package:small_talk/shared_pages/video_call_page/video_call_page_widget.dart';
import 'package:small_talk/students_pages/students_dashboard/students_dashboard_widget.dart';
import 'package:small_talk/students_pages/waiting_for_teacher_page/waiting_for_teacher_page_widget.dart';

const MethodChannel _permissionsChannel =
    MethodChannel('flutter.baseflow.com/permissions/methods');

const int _permissionDenied = 0;
const int _permissionGranted = 1;

int _permissionStatus = _permissionGranted;
Map<int, int> _permissionStatusByPermission = <int, int>{};
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
    _permissionStatusByPermission = <int, int>{};
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
    StudentsDashboardWidget.debugActiveSearchRecoveryReader = null;
    StudentsDashboardWidget.debugStopSearchPayloadObserver = null;
    StudentsDashboardWidget.debugAcceptCallRequest = null;
    StudentsDashboardWidget.debugGetSessionTokensRequest = null;
    StudentsDashboardWidget.debugAutoOpenSessionNavigator = null;
    StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation = true;
    WaitingForTeacherPageWidget.debugCreateVideoSessionRequest = null;
    WaitingForTeacherPageWidget.debugCancelCallRequest = null;
    WaitingForTeacherPageWidget.debugGetSessionTokensRequest = null;
    WaitingForTeacherPageWidget.debugSessionSnapshots = null;
    debugActiveSessionUserSnapshot = null;
    debugActiveNavigationSessionSnapshots = null;
    debugActiveCurrentSessionSnapshot = null;
    debugActiveSearchRequestSnapshot = (_) async => null;
    debugActiveSearchRecoveryObserver = null;
    debugActiveSearchRecoveryNow = null;
    debugActiveSessionTokenRequest = null;
    debugActiveSessionNavigator = null;
    debugStudentSessionSnapshots = null;
    debugStudentSessionTokenRequest = null;
    debugStudentSessionNavigator = null;
    studentNavigationHandled = false;
    studentSessionTokenFetchInProgress = false;

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
            for (final permission in permissions)
              permission: _permissionStatusByPermission[permission] ??
                  _permissionStatus,
          };
        case 'checkPermissionStatus':
          _checkPermissionStatusCallCount += 1;
          final error = _checkPermissionStatusError;
          if (error != null) {
            throw error;
          }
          final permission = call.arguments;
          if (permission is int) {
            return _permissionStatusByPermission[permission] ??
                _permissionStatus;
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
    StudentsDashboardWidget.debugActiveSearchRecoveryReader = null;
    StudentsDashboardWidget.debugStopSearchPayloadObserver = null;
    StudentsDashboardWidget.debugAcceptCallRequest = null;
    StudentsDashboardWidget.debugGetSessionTokensRequest = null;
    StudentsDashboardWidget.debugAutoOpenSessionNavigator = null;
    StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation = false;
    WaitingForTeacherPageWidget.debugCreateVideoSessionRequest = null;
    WaitingForTeacherPageWidget.debugCancelCallRequest = null;
    WaitingForTeacherPageWidget.debugGetSessionTokensRequest = null;
    WaitingForTeacherPageWidget.debugSessionSnapshots = null;
    debugActiveSessionUserSnapshot = null;
    debugActiveNavigationSessionSnapshots = null;
    debugActiveCurrentSessionSnapshot = null;
    debugActiveSearchRequestSnapshot = null;
    debugActiveSearchRecoveryObserver = null;
    debugActiveSearchRecoveryNow = null;
    debugActiveSessionTokenRequest = null;
    debugActiveSessionNavigator = null;
    debugStudentSessionSnapshots = null;
    debugStudentSessionTokenRequest = null;
    debugStudentSessionNavigator = null;
    unawaited(studentSessionSub?.cancel());
    studentSessionSub = null;
    studentNavigationHandled = false;
    studentSessionTokenFetchInProgress = false;
    currentUser = null;
    currentUserDocument = null;
  });

  VideoSessionsRecord sessionFixture(
    String sessionId,
    String status, {
    String? requesterId,
    String? responderId,
    String? scenario,
    String? responderRole,
    String? dailyRoomUrl,
    String? dailyRoomName,
    String? meetingToken,
    List<String>? participantIds,
  }) {
    return VideoSessionsRecord.getDocumentFromData(
      {
        'status': status,
        'participantIds': participantIds ?? [currentUserUid],
        if (requesterId != null) 'requesterId': requesterId,
        if (requesterId != null) 'studentId': requesterId,
        if (responderId != null) 'responderId': responderId,
        if (responderId != null) 'currentResponderId': responderId,
        if (responderId != null) 'currentTutorId': responderId,
        if (scenario != null) 'scenario': scenario,
        if (responderRole != null) 'responderRole': responderRole,
        if (responderRole != null) 'currentResponderRole': responderRole,
        if (requesterId != null || responderId != null)
          'matchContext': {
            if (requesterId != null) 'requesterId': requesterId,
            if (responderId != null) 'responderId': responderId,
            if (responderId != null) 'currentResponderId': responderId,
            if (responderRole != null) 'selectedResponderRole': responderRole,
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

  ActiveSearchRecoveryState activeSearchRecoveryState({
    required String userId,
    required String requestId,
    String status = 'active',
    DateTime? heartbeatAt,
    DateTime? expiresAt,
    String? currentSessionId,
    String? matchedSessionId,
    bool exists = true,
    bool belongsToUser = true,
    bool isExpired = false,
    Map<String, dynamic> extraData = const <String, dynamic>{},
  }) {
    return ActiveSearchRecoveryState(
      userId: userId,
      requestId: requestId,
      data: <String, dynamic>{
        'requestId': requestId,
        'userId': userId,
        'status': status,
        'heartbeatAt': heartbeatAt ?? DateTime.now(),
        'expiresAt':
            expiresAt ?? DateTime.now().add(const Duration(minutes: 5)),
        if (currentSessionId != null) 'currentSessionId': currentSessionId,
        if (matchedSessionId != null) 'matchedSessionId': matchedSessionId,
        ...extraData,
      },
      exists: exists,
      belongsToUser: belongsToUser,
      isLiveStatus: status == 'active' || status == 'matching',
      isExpired: isExpired,
    );
  }

  test('active search recovery connection predicate is narrow', () {
    const userId = 'student-connection-predicate-test';

    expect(
      activeSearchRecoveryState(
        userId: userId,
        requestId: 'request-pending-predicate-test',
        status: 'pending_confirmation',
        currentSessionId: 'session-pending-predicate-test',
      ).canResumeConnection,
      isTrue,
    );
    expect(
      activeSearchRecoveryState(
        userId: userId,
        requestId: 'request-connecting-predicate-test',
        status: 'connecting',
        currentSessionId: 'session-connecting-predicate-test',
      ).canResumeConnection,
      isTrue,
    );
    expect(
      activeSearchRecoveryState(
        userId: userId,
        requestId: 'request-matched-predicate-test',
        status: 'matched',
        matchedSessionId: 'session-matched-predicate-test',
      ).canResumeConnection,
      isTrue,
    );
    expect(
      activeSearchRecoveryState(
        userId: userId,
        requestId: 'request-matching-predicate-test',
        status: 'matching',
        currentSessionId: 'session-matching-predicate-test',
      ).canResumeConnection,
      isTrue,
    );
    final activeState = activeSearchRecoveryState(
      userId: userId,
      requestId: 'request-active-predicate-test',
      status: 'active',
      currentSessionId: 'session-active-predicate-test',
    );
    expect(activeState.canResumeActiveSession, isTrue);
    expect(activeState.canResumeConnection, isTrue);

    for (final status in <String>[
      'unknown',
      'expired',
      'failed',
      'completed',
    ]) {
      expect(
        activeSearchRecoveryState(
          userId: userId,
          requestId: 'request-$status-predicate-test',
          status: status,
          currentSessionId: 'session-$status-predicate-test',
          isExpired: status == 'expired',
        ).canResumeConnection,
        isFalse,
      );
    }
    expect(
      activeSearchRecoveryState(
        userId: userId,
        requestId: 'request-no-session-predicate-test',
        status: 'matched',
      ).canResumeConnection,
      isFalse,
    );
    expect(
      activeSearchRecoveryState(
        userId: userId,
        requestId: 'request-wrong-owner-predicate-test',
        status: 'matched',
        currentSessionId: 'session-wrong-owner-predicate-test',
        belongsToUser: false,
      ).canResumeConnection,
      isFalse,
    );
    expect(
      activeSearchRecoveryState(
        userId: userId,
        requestId: 'request-expired-connecting-predicate-test',
        status: 'connecting',
        currentSessionId: 'session-expired-connecting-predicate-test',
        isExpired: true,
      ).canResumeConnection,
      isFalse,
    );
    expect(
      activeSearchRecoveryState(
        userId: userId,
        requestId: 'request-missing-doc-predicate-test',
        status: 'connecting',
        currentSessionId: 'session-missing-doc-predicate-test',
        exists: false,
      ).canResumeConnection,
      isFalse,
    );
  });

  test('active search recovery ignores terminal call results', () {
    const userId = 'student-terminal-result-predicate-test';

    final endedCallState = activeSearchRecoveryState(
      userId: userId,
      requestId: 'request-ended-call-predicate-test',
      status: 'stopped',
      extraData: const <String, dynamic>{
        'stopReason': 'session_ended',
      },
    );
    expect(endedCallState.hasTerminalResult, isTrue);
    expect(endedCallState.hasActiveSearch, isFalse);
    expect(endedCallState.canResumeSearch, isFalse);
    expect(endedCallState.canResumeUnboundSearch, isFalse);

    final staleLiveEndedCallState = activeSearchRecoveryState(
      userId: userId,
      requestId: 'request-stale-live-ended-call-predicate-test',
      status: 'active',
      extraData: const <String, dynamic>{
        'stopReason': 'session_ended',
      },
    );
    expect(staleLiveEndedCallState.hasTerminalResult, isTrue);
    expect(staleLiveEndedCallState.isLiveStatus, isTrue);
    expect(staleLiveEndedCallState.hasActiveSearch, isFalse);
    expect(staleLiveEndedCallState.canResumeSearch, isFalse);
    expect(staleLiveEndedCallState.canResumeUnboundSearch, isFalse);

    final staleLiveCancelledCallState = activeSearchRecoveryState(
      userId: userId,
      requestId: 'request-stale-live-cancelled-call-predicate-test',
      status: 'matching',
      currentSessionId: 'session-stale-live-cancelled-call-test',
      extraData: const <String, dynamic>{
        'stopReason': 'call_cancelled',
      },
    );
    expect(staleLiveCancelledCallState.hasTerminalResult, isTrue);
    expect(staleLiveCancelledCallState.isLiveStatus, isTrue);
    expect(staleLiveCancelledCallState.hasActiveSearch, isFalse);
    expect(staleLiveCancelledCallState.canResumeConnection, isFalse);

    final futureBackendReasonState = activeSearchRecoveryState(
      userId: userId,
      requestId: 'request-future-backend-reason-predicate-test',
      status: 'active',
      currentSessionId: 'session-future-backend-reason-test',
      extraData: const <String, dynamic>{
        'stopReason': 'future_backend_terminal_reason',
      },
    );
    expect(futureBackendReasonState.hasTerminalResult, isTrue);
    expect(futureBackendReasonState.hasActiveSearch, isFalse);
    expect(futureBackendReasonState.canResumeActiveSession, isFalse);
    expect(futureBackendReasonState.canResumeConnection, isFalse);

    for (final entry in const <Map<String, String>>[
      {
        'status': 'stopped',
        'stopReason': 'session_ended',
      },
      {
        'status': 'cancelled',
        'stopReason': 'call_cancelled',
      },
      {
        'status': 'expired',
        'stopReason': 'session_expired',
      },
      {
        'status': 'expired',
        'stopReason': 'search_timeout',
      },
      {
        'status': 'expired',
        'stopReason': 'background_timeout',
      },
      {
        'status': 'expired',
        'stopReason': 'heartbeat_stale',
      },
      {
        'status': 'cancelled',
        'stopReason': 'student_pair_declined',
      },
      {
        'status': 'expired',
        'stopReason': 'student_pair_response_timeout',
      },
      {
        'status': 'cancelled',
        'stopReason': 'direct_call_declined',
      },
      {
        'status': 'cancelled',
        'stopReason': 'no_available_responder_after_decline',
      },
      {
        'status': 'expired',
        'stopReason': 'direct_call_timeout',
      },
      {
        'status': 'cancelled',
        'stopReason': 'teacher_push_failed',
      },
    ]) {
      final state = activeSearchRecoveryState(
        userId: userId,
        requestId:
            'request-${entry['status']}-${entry['stopReason']}-predicate-test',
        status: entry['status']!,
        extraData: <String, dynamic>{
          'stopReason': entry['stopReason'],
        },
      );
      expect(state.hasTerminalResult, isTrue);
      expect(state.hasActiveSearch, isFalse);
      expect(state.canResumeSearch, isFalse);
    }

    final callStartedState = activeSearchRecoveryState(
      userId: userId,
      requestId: 'request-call-started-predicate-test',
      currentSessionId: 'session-call-started-predicate-test',
      extraData: const <String, dynamic>{
        'stopReason': 'call_started',
      },
    );
    expect(callStartedState.hasTerminalResult, isTrue);
    expect(callStartedState.hasActiveSearch, isFalse);
    expect(callStartedState.canResumeActiveSession, isFalse);
    expect(callStartedState.canResumeConnection, isFalse);

    final restoredActiveState = activeSearchRecoveryState(
      userId: userId,
      requestId: 'request-restored-active-predicate-test',
      extraData: const <String, dynamic>{
        'excludedCandidateIds': ['teacher-push-failed-test'],
        'attemptExcludedCandidateIds': <String>[],
        'stopReason': null,
      },
    );
    expect(restoredActiveState.hasTerminalResult, isFalse);
    expect(restoredActiveState.hasActiveSearch, isTrue);
    expect(restoredActiveState.canResumeUnboundSearch, isTrue);

    final pendingState = activeSearchRecoveryState(
      userId: userId,
      requestId: 'request-pending-live-predicate-test',
      status: 'pending_confirmation',
      currentSessionId: 'session-pending-live-predicate-test',
    );
    expect(pendingState.hasTerminalResult, isFalse);
    expect(pendingState.canResumeConnection, isTrue);

    final connectingState = activeSearchRecoveryState(
      userId: userId,
      requestId: 'request-connecting-live-predicate-test',
      status: 'connecting',
      currentSessionId: 'session-connecting-live-predicate-test',
    );
    expect(connectingState.hasTerminalResult, isFalse);
    expect(connectingState.canResumeConnection, isTrue);

    final matchedState = activeSearchRecoveryState(
      userId: userId,
      requestId: 'request-matched-live-predicate-test',
      status: 'matched',
      matchedSessionId: 'session-matched-live-predicate-test',
    );
    expect(matchedState.hasTerminalResult, isFalse);
    expect(matchedState.canResumeConnection, isTrue);
  });

  Future<ActiveSearchRecoveryState?> runStartupSearchRecoveryTest(
    WidgetTester tester, {
    required String userId,
    required Map<String, dynamic> searchData,
    String? searchDocId,
  }) async {
    ActiveSearchRecoveryState? observedSearchState;
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'isInCall': false,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveSearchRequestSnapshot = (requestedUserId) async {
      return _FakeSessionSnapshot(
        searchDocId ?? requestedUserId,
        searchData,
        FirebaseFirestore.instance
            .collection('searchRequests')
            .doc(searchDocId ?? requestedUserId),
      );
    };
    debugActiveSearchRecoveryObserver = (state) {
      observedSearchState = state;
    };
    setActiveStudent(userId, isInCall: false);
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-startup-search-request'),
            onPressed: () async {
              await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover startup search request'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();
    await tester.tap(find.byKey(const Key('recover-startup-search-request')));
    await tester.pump();
    await tester.idle();
    await tester.pumpWidget(const SizedBox.shrink());
    return observedSearchState;
  }

  testWidgets('student dashboard blocks search without active subscription',
      (tester) async {
    final startPayloads = <Map<String, dynamic>>[];
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
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          startSearchRequest: (payload) async {
            startPayloads.add(Map<String, dynamic>.from(payload));
            return <String, dynamic>{'requestId': 'request-unexpected-start'};
          },
        ),
      ),
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
    expect(startPayloads, isEmpty);
    final blockedStartSearchButton =
        find.widgetWithText(StudentStartSearchButton, 'Начать поиск');
    expect(blockedStartSearchButton, findsOneWidget);
    expect(
      tester.widget<StudentStartSearchButton>(blockedStartSearchButton)
          .isActive,
      isFalse,
    );
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

  testWidgets('student dashboard renders start search CTA in idle state',
      (tester) async {
    setActiveStudent('student-start-search-idle-render-test');

    await tester.pumpWidget(
      _buildDashboardTestApp(const StudentsDashboardWidget()),
    );
    await tester.pump();

    final cta = find.widgetWithText(StudentStartSearchButton, 'Начать поиск');
    expect(cta, findsOneWidget);
    expect(tester.widget<StudentStartSearchButton>(cta).isActive, isFalse);
    expect(
      find
          .descendant(of: cta, matching: find.text('Начать поиск'))
          .hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('Соединяем'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

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
    final startPayloads = <Map<String, dynamic>>[];
    setActiveStudent('student-start-search-usage-limit-test');

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          usageLimitReachedChecker: (_) async => true,
          startSearchRequest: (payload) async {
            startPayloads.add(Map<String, dynamic>.from(payload));
            return <String, dynamic>{'requestId': 'request-unexpected-start'};
          },
        ),
      ),
    );
    await tester.pump();

    final startSearchButton =
        find.widgetWithText(StudentStartSearchButton, 'Начать поиск');
    await tester.tap(startSearchButton);
    await tester.pump();

    expect(find.text('Лимит звонков исчерпан'), findsOneWidget);
    expect(startPayloads, isEmpty);
    expect(startSearchButton, findsOneWidget);
    expect(
      tester.widget<StudentStartSearchButton>(startSearchButton).isActive,
      isFalse,
    );
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('Соединяем'), findsNothing);
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

  testWidgets('student dashboard switches CTA to stop after successful start',
      (tester) async {
    setActiveStudent('student-stop-search-test');
    final startPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          startSearchRequest: (payload) async {
            startPayloads.add(Map<String, dynamic>.from(payload));
            return <String, dynamic>{'requestId': 'request-stop-cta-test'};
          },
        ),
      ),
    );
    await tester.pump();

    final startSearchButton =
        find.widgetWithText(StudentStartSearchButton, 'Начать поиск');
    expect(startSearchButton, findsOneWidget);
    expect(
      tester.widget<StudentStartSearchButton>(startSearchButton).isActive,
      isFalse,
    );
    expect(find.text('Остановить поиск'), findsNothing);

    await tester.tap(startSearchButton);
    await tester.pump();

    expect(startPayloads, hasLength(1));
    expect(startPayloads.single['appState'], 'foreground');
    expect(startPayloads.single['language'], 'en');
    final stopSearchButton =
        find.widgetWithText(StudentStartSearchButton, 'Остановить поиск');
    expect(stopSearchButton, findsOneWidget);
    expect(
      tester.widget<StudentStartSearchButton>(stopSearchButton).isActive,
      isTrue,
    );
    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(find.text('Начать поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard renders searching state', (tester) async {
    setActiveStudent('student-searching-state-render-test');
    final startPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          initialSearchState: StudentDashboardSearchState.searching,
          startSearchRequest: (payload) async {
            startPayloads.add(Map<String, dynamic>.from(payload));
            return <String, dynamic>{'requestId': 'request-unexpected-start'};
          },
        ),
      ),
    );
    await tester.pump();

    expect(startPayloads, isEmpty);
    final stopSearchButton =
        find.widgetWithText(StudentStartSearchButton, 'Остановить поиск');
    expect(stopSearchButton, findsOneWidget);
    expect(stopSearchButton.hitTestable(), findsOneWidget);
    expect(
      tester.widget<StudentStartSearchButton>(stopSearchButton).isActive,
      isTrue,
    );
    final searchingStatusText = find.text('Ищем собеседника');
    expect(searchingStatusText, findsOneWidget);
    expect(searchingStatusText.hitTestable(), findsOneWidget);
    expect(find.text('Начать поиск'), findsNothing);
    expect(find.text('Соединяем'), findsNothing);
    expect(find.text('Пока никого не нашли'), findsNothing);
    expect(find.text('Не удалось начать поиск'), findsNothing);

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

  testWidgets('student dashboard restores active search after restart',
      (tester) async {
    const userId = 'student-recover-active-search-after-restart-test';
    const requestId = 'request-recovered-search-after-restart-test';
    setActiveStudent(userId);
    final startPayloads = <Map<String, dynamic>>[];
    final heartbeatPayloads = <Map<String, dynamic>>[];
    final stopPayloads = <Map<String, dynamic>>[];
    final stoppedSessionIds = <String?>[];
    StudentsDashboardWidget.debugStopSearchPayloadObserver = (payload) {
      stopPayloads.add(Map<String, dynamic>.from(payload));
    };

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (requestedUserId) async {
            expect(requestedUserId, userId);
            return activeSearchRecoveryState(
              userId: userId,
              requestId: requestId,
              expiresAt: DateTime.now().add(const Duration(minutes: 5)),
            );
          },
          startSearchRequest: (payload) async {
            startPayloads.add(Map<String, dynamic>.from(payload));
            return <String, dynamic>{
              'requestId': 'request-should-not-start-test',
            };
          },
          heartbeatSearchRequest: (payload) async {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
          },
          stopSearchRequest: (activeSessionId) async {
            stoppedSessionIds.add(activeSessionId);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();
    await tester.pump();

    expect(startPayloads, isEmpty);
    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Начать поиск'), findsNothing);
    expect(heartbeatPayloads, hasLength(1));
    expect(heartbeatPayloads.single, <String, dynamic>{
      'requestId': requestId,
      'appState': 'foreground',
    });

    await tester.pump(StudentsDashboardWidget.heartbeatSearchInterval);
    await tester.pump();

    expect(heartbeatPayloads, hasLength(2));
    expect(heartbeatPayloads.last, <String, dynamic>{
      'requestId': requestId,
      'appState': 'foreground',
    });

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(stoppedSessionIds, [null]);
    expect(stopPayloads, [
      <String, dynamic>{'requestId': requestId},
    ]);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('Остановить поиск'), findsNothing);

    await tester.pump(StudentsDashboardWidget.heartbeatSearchInterval);
    await tester.pump();

    expect(heartbeatPayloads, hasLength(2));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard handles recovered search request mismatch',
      (tester) async {
    const userId = 'student-recover-request-mismatch-test';
    const requestId = 'request-mismatch-recovery-test';
    setActiveStudent(userId);
    final heartbeatPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: requestId,
          ),
          heartbeatSearchRequest: (payload) async {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
            return <String, dynamic>{
              'status': 'noop',
              'errorCode': 'request_mismatch',
              'reason': 'request_mismatch',
            };
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(heartbeatPayloads, [
      <String, dynamic>{
        'requestId': requestId,
        'appState': 'foreground',
      },
    ]);
    expect(find.text('Пока никого не нашли'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Начать поиск'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard ignores expired search recovery',
      (tester) async {
    const userId = 'student-recover-expired-search-ui-test';
    setActiveStudent(userId);
    final heartbeatPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: 'request-expired-recovery-test',
            expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
            isExpired: true,
          ),
          heartbeatSearchRequest: (payload) async {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(heartbeatPayloads, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard ignores terminal call search recovery',
      (tester) async {
    const userId = 'student-recover-terminal-call-ui-test';
    setActiveStudent(userId);
    final heartbeatPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: 'request-terminal-call-recovery-test',
            status: 'stopped',
            extraData: const <String, dynamic>{
              'stopReason': 'session_ended',
            },
          ),
          heartbeatSearchRequest: (payload) async {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('Соединяем'), findsNothing);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(heartbeatPayloads, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard ignores live search with terminal stop reason',
      (tester) async {
    const userId = 'student-recover-live-terminal-reason-ui-test';
    setActiveStudent(userId);
    final heartbeatPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: 'request-live-terminal-reason-recovery-test',
            status: 'active',
            extraData: const <String, dynamic>{
              'stopReason': 'session_ended',
            },
          ),
          heartbeatSearchRequest: (payload) async {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('Соединяем'), findsNothing);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(heartbeatPayloads, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard retry restores active search recovery',
      (tester) async {
    const userId = 'student-recover-search-retry-test';
    const requestId = 'request-retry-recovery-test';
    setActiveStudent(userId);
    var recoveryReadCount = 0;
    final heartbeatPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async {
            recoveryReadCount += 1;
            if (recoveryReadCount == 1) {
              throw StateError('temporary recovery failure');
            }
            return activeSearchRecoveryState(
              userId: userId,
              requestId: requestId,
            );
          },
          heartbeatSearchRequest: (payload) async {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(recoveryReadCount, 1);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(heartbeatPayloads, isEmpty);

    await tester.pump(StudentsDashboardWidget.activeSearchRecoveryRetryDelay);
    await tester.pump();
    await tester.idle();
    await tester.pump();

    expect(recoveryReadCount, 2);
    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Начать поиск'), findsNothing);
    expect(heartbeatPayloads, [
      <String, dynamic>{
        'requestId': requestId,
        'appState': 'foreground',
      },
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard restores session-bound search as connecting',
      (tester) async {
    const userId = 'student-recover-session-bound-search-test';
    const sessionId = 'session-bound-recovery-test';
    setActiveStudent(userId);
    final heartbeatPayloads = <Map<String, dynamic>>[];
    final stoppedSessionIds = <String?>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: 'request-session-bound-recovery-test',
            status: 'matched',
            currentSessionId: sessionId,
          ),
          heartbeatSearchRequest: (payload) async {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
          },
          stopSearchRequest: (activeSessionId) async {
            stoppedSessionIds.add(activeSessionId);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Соединяем'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Начать поиск'), findsNothing);
    expect(heartbeatPayloads, isEmpty);

    await tester.tap(
      find.ancestor(
        of: find.text('Остановить поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();

    expect(stoppedSessionIds, [sessionId]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard restores matching session-bound search',
      (tester) async {
    const userId = 'student-recover-matching-session-bound-test';
    const sessionId = 'session-matching-bound-recovery-test';
    setActiveStudent(userId);
    final heartbeatPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: 'request-matching-session-bound-test',
            status: 'matching',
            currentSessionId: sessionId,
          ),
          heartbeatSearchRequest: (payload) async {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Соединяем'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(heartbeatPayloads, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard restores pending confirmation search',
      (tester) async {
    const userId = 'student-recover-pending-confirmation-search-test';
    const sessionId = 'session-pending-confirmation-search-test';
    setActiveStudent(userId);

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: 'request-pending-confirmation-search-test',
            status: 'pending_confirmation',
            currentSessionId: sessionId,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Соединяем'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard restores connecting search', (tester) async {
    const userId = 'student-recover-connecting-search-test';
    const sessionId = 'session-connecting-search-test';
    setActiveStudent(userId);

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: 'request-connecting-search-test',
            status: 'connecting',
            currentSessionId: sessionId,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Соединяем'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Начать поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard restores matched session id fallback',
      (tester) async {
    const userId = 'student-recover-matched-session-id-test';
    const sessionId = 'session-matched-id-recovery-test';
    setActiveStudent(userId);

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: 'request-matched-session-id-test',
            status: 'matched',
            matchedSessionId: sessionId,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Соединяем'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Начать поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard clears recovered connecting terminal session',
      (tester) async {
    const userId = 'student-recover-terminal-session-test';
    const sessionId = 'session-terminal-recovery-test';
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    setActiveStudent(userId);

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: 'request-terminal-session-test',
            status: 'matched',
            currentSessionId: sessionId,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Соединяем'), findsOneWidget);

    activeSessionController.add(sessionFixture(sessionId, 'ended'));
    await tester.pump();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Соединяем'), findsNothing);
    expect(find.text('Остановить поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard ignores terminal linked search recovery',
      (tester) async {
    const userId = 'student-recover-terminal-linked-session-test';
    const sessionId = 'session-terminal-linked-recovery-test';
    setActiveStudent(userId);
    StudentsDashboardWidget.debugActiveSessionReader = (sessionRef) async {
      expect(sessionRef.id, sessionId);
      return sessionFixture(sessionId, 'ended');
    };

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: 'request-terminal-linked-session-test',
            status: 'matched',
            currentSessionId: sessionId,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Соединяем'), findsNothing);
    expect(find.text('Остановить поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'student dashboard ignores recovered search on session read error',
      (tester) async {
    const userId = 'student-recover-session-read-error-test';
    const sessionId = 'session-read-error-recovery-test';
    setActiveStudent(userId);
    StudentsDashboardWidget.debugActiveSessionReader = (sessionRef) async {
      expect(sessionRef.id, sessionId);
      throw StateError('linked session read failed');
    };

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: 'request-session-read-error-test',
            status: 'matched',
            currentSessionId: sessionId,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Соединяем'), findsNothing);
    expect(find.text('Остановить поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard ignores foreign linked search recovery',
      (tester) async {
    const userId = 'student-recover-foreign-linked-session-test';
    const sessionId = 'session-foreign-linked-recovery-test';
    const foreignRequesterId = 'student-foreign-linked-requester-test';
    const foreignResponderId = 'student-foreign-linked-responder-test';
    setActiveStudent(userId);
    StudentsDashboardWidget.debugActiveSessionReader = (sessionRef) async {
      expect(sessionRef.id, sessionId);
      return sessionFixture(
        sessionId,
        'connecting',
        requesterId: foreignRequesterId,
        responderId: foreignResponderId,
        participantIds: [foreignRequesterId, foreignResponderId],
      );
    };

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: 'request-foreign-linked-session-test',
            status: 'matched',
            currentSessionId: sessionId,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Соединяем'), findsNothing);
    expect(find.text('Остановить поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard clears recovered connecting missing session',
      (tester) async {
    const userId = 'student-recover-missing-session-test';
    const sessionId = 'session-missing-recovery-test';
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    setActiveStudent(userId);

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: 'request-missing-session-test',
            status: 'matched',
            currentSessionId: sessionId,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Соединяем'), findsOneWidget);

    activeSessionController.add(null);
    await tester.pump();

    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Соединяем'), findsNothing);
    expect(find.text('Остановить поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard keeps recovered connecting on stream error',
      (tester) async {
    const userId = 'student-recover-connection-stream-error-test';
    const sessionId = 'session-connection-stream-error-test';
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    setActiveStudent(userId);

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSessionStream: activeSessionController.stream,
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: 'request-connection-stream-error-test',
            status: 'matched',
            currentSessionId: sessionId,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Соединяем'), findsOneWidget);

    activeSessionController.addError(
      StateError('recovered connection stream failed'),
    );
    await tester.pump();

    expect(find.text('Соединяем'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard restores active session-bound search',
      (tester) async {
    const userId = 'student-recover-active-session-status-test';
    setActiveStudent(userId);

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: 'request-active-session-status-test',
            status: 'active',
            currentSessionId: 'session-active-session-status-test',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Соединяем'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Начать поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student dashboard ignores unsupported session-bound statuses',
      (tester) async {
    const userId = 'student-recover-unsupported-session-status-test';

    Future<void> verifyStatus(String status) async {
      setActiveStudent(userId);
      await tester.pumpWidget(
        _buildDashboardTestApp(
          StudentsDashboardWidget(
            activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
              userId: userId,
              requestId: 'request-unsupported-$status-test',
              status: status,
              currentSessionId: 'session-unsupported-$status-test',
              isExpired: status == 'expired',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.idle();

      expect(find.text('Начать поиск'), findsOneWidget);
      expect(find.text('Соединяем'), findsNothing);
      expect(find.text('Остановить поиск'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    await verifyStatus('unknown');
    await verifyStatus('expired');
    await verifyStatus('failed');
    await verifyStatus('completed');
  });

  testWidgets('student dashboard times out recovered active search',
      (tester) async {
    const userId = 'student-recover-search-expiry-timeout-test';
    const requestId = 'request-recovered-expiry-timeout-test';
    setActiveStudent(userId);
    final heartbeatPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: requestId,
            expiresAt: DateTime.now().add(const Duration(seconds: 2)),
          ),
          heartbeatSearchRequest: (payload) async {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();

    expect(find.text('Ищем собеседника'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsOneWidget);
    expect(find.text('Начать поиск'), findsNothing);
    expect(heartbeatPayloads, [
      <String, dynamic>{
        'requestId': requestId,
        'appState': 'foreground',
      },
    ]);

    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump();

    expect(find.text('Пока никого не нашли'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Остановить поиск'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'student dashboard skips heartbeat when recovered search has expired',
      (tester) async {
    const userId = 'student-recover-search-zero-timeout-test';
    const requestId = 'request-recovered-zero-timeout-test';
    setActiveStudent(userId);
    final heartbeatPayloads = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildDashboardTestApp(
        StudentsDashboardWidget(
          activeSearchRecoveryReader: (_) async => activeSearchRecoveryState(
            userId: userId,
            requestId: requestId,
            expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
          ),
          heartbeatSearchRequest: (payload) async {
            heartbeatPayloads.add(Map<String, dynamic>.from(payload));
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();
    await tester.pump();

    expect(find.text('Пока никого не нашли'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('Остановить поиск'), findsNothing);
    expect(heartbeatPayloads, isEmpty);

    await tester.pump(StudentsDashboardWidget.heartbeatSearchInterval);
    await tester.pump();

    expect(heartbeatPayloads, isEmpty);

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

  testWidgets('student dashboard returns to idle on expired heartbeat',
      (tester) async {
    Future<void> verifyExpiredHeartbeat(String reason) async {
      setActiveStudent('student-heartbeat-$reason-idle-test');
      final heartbeatPayloads = <Map<String, dynamic>>[];

      await tester.pumpWidget(
        _buildDashboardTestApp(
          StudentsDashboardWidget(
            startSearchRequest: (_) async {
              return <String, dynamic>{
                'requestId': 'request-heartbeat-$reason-idle-test',
              };
            },
            heartbeatSearchRequest: (payload) async {
              heartbeatPayloads.add(Map<String, dynamic>.from(payload));
              return <String, dynamic>{
                'errorCode': reason,
                'reason': reason,
              };
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
      expect(find.text('Начать поиск'), findsOneWidget);
      expect(find.text('Пока никого не нашли'), findsNothing);
      expect(find.text('Ищем собеседника'), findsNothing);
      expect(find.text('Остановить поиск'), findsNothing);

      await tester.pump(StudentsDashboardWidget.heartbeatSearchInterval);
      await tester.pump();
      expect(heartbeatPayloads, hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    await verifyExpiredHeartbeat('expired');
    await verifyExpiredHeartbeat('stale');
    await verifyExpiredHeartbeat('background_expired');
  });

  testWidgets('student dashboard keeps no match for inactive heartbeat',
      (tester) async {
    Future<void> verifyInactiveHeartbeat(String reason) async {
      setActiveStudent('student-heartbeat-$reason-no-match-test');
      final heartbeatPayloads = <Map<String, dynamic>>[];

      await tester.pumpWidget(
        _buildDashboardTestApp(
          StudentsDashboardWidget(
            startSearchRequest: (_) async {
              return <String, dynamic>{
                'requestId': 'request-heartbeat-$reason-no-match-test',
              };
            },
            heartbeatSearchRequest: (payload) async {
              heartbeatPayloads.add(Map<String, dynamic>.from(payload));
              return <String, dynamic>{
                'errorCode': reason,
                'reason': reason,
              };
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
      expect(find.text('Пока никого не нашли'), findsOneWidget);
      expect(find.text('Начать поиск'), findsOneWidget);
      expect(find.text('Ищем собеседника'), findsNothing);
      expect(find.text('Остановить поиск'), findsNothing);

      await tester.pump(StudentsDashboardWidget.heartbeatSearchInterval);
      await tester.pump();
      expect(heartbeatPayloads, hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    await verifyInactiveHeartbeat('inactive');
    await verifyInactiveHeartbeat('not_found');
    await verifyInactiveHeartbeat('request_id_required');
    await verifyInactiveHeartbeat('request_mismatch');
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

  testWidgets('matched teacher search opens waiting page instead of video call',
      (tester) async {
    const sessionId = 'session-teacher-waiting-route-test';
    final waitingSessionController =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
    addTearDown(waitingSessionController.close);
    var createSessionCalls = 0;
    final listenedSessionIds = <String>[];
    WaitingForTeacherPageWidget.debugCreateVideoSessionRequest = (_) async {
      createSessionCalls += 1;
      return <String, dynamic>{};
    };
    WaitingForTeacherPageWidget.debugSessionSnapshots = (sessionId) {
      listenedSessionIds.add(sessionId);
      return waitingSessionController.stream;
    };
    setActiveStudent('student-teacher-waiting-route-test');
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => StudentsDashboardWidget(
            startSearchRequest: (_) async => <String, dynamic>{
              'requestId': 'request-teacher-waiting-route-test',
              'status': 'matched',
              'sessionId': sessionId,
              'scenario': 'student_teacher',
              'matchedRole': 'native_speaker',
            },
          ),
        ),
        GoRoute(
          name: WaitingForTeacherPageWidget.routeName,
          path: WaitingForTeacherPageWidget.routePath,
          builder: (context, state) => WaitingForTeacherPageWidget(
            key: const Key('teacher-waiting-route'),
            sessionId: state.uri.queryParameters['sessionId'],
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

    await tester.tap(
      find.ancestor(
        of: find.text('Начать поиск'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      router.getCurrentLocation(),
      startsWith(WaitingForTeacherPageWidget.routePath),
    );
    expect(router.getCurrentLocation(), contains('sessionId=$sessionId'));
    expect(createSessionCalls, 0);
    expect(listenedSessionIds, contains(sessionId));
    expect(find.byType(WaitingForTeacherPageWidget), findsOneWidget);
    expect(find.byKey(const Key('teacher-waiting-route')), findsOneWidget);
    expect(find.byKey(const Key('video-call-route')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pending teacher session restores waiting page after restart',
      (tester) async {
    StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation = false;
    const sessionId = 'session-teacher-waiting-restore-test';
    const requesterId = 'student-teacher-waiting-restore-test';
    const teacherId = 'teacher-teacher-waiting-restore-test';
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    final waitingSessionController =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
    addTearDown(activeSessionController.close);
    addTearDown(waitingSessionController.close);
    var createSessionCalls = 0;
    WaitingForTeacherPageWidget.debugCreateVideoSessionRequest = (_) async {
      createSessionCalls += 1;
      return <String, dynamic>{};
    };
    WaitingForTeacherPageWidget.debugSessionSnapshots =
        (_) => waitingSessionController.stream;
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
          name: WaitingForTeacherPageWidget.routeName,
          path: WaitingForTeacherPageWidget.routePath,
          builder: (context, state) => WaitingForTeacherPageWidget(
            sessionId: state.uri.queryParameters['sessionId'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    activeSessionController.add(
      sessionFixture(
        sessionId,
        'pending_confirmation',
        requesterId: requesterId,
        responderId: teacherId,
        scenario: 'student_teacher',
        responderRole: 'native_speaker',
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      router.getCurrentLocation(),
      startsWith(WaitingForTeacherPageWidget.routePath),
    );
    expect(router.getCurrentLocation(), contains('sessionId=$sessionId'));
    expect(createSessionCalls, 0);
    expect(find.byType(WaitingForTeacherPageWidget), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('queue waiting cancel returns to dashboard without back stack',
      (tester) async {
    const sessionId = 'session-teacher-waiting-cancel-test';
    final waitingSessionController =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
    addTearDown(waitingSessionController.close);
    final cancelledSessionIds = <String>[];
    WaitingForTeacherPageWidget.debugSessionSnapshots =
        (_) => waitingSessionController.stream;
    WaitingForTeacherPageWidget.debugCancelCallRequest = (sessionId) async {
      cancelledSessionIds.add(sessionId);
      return <String, dynamic>{
        'status': 'cancelled',
        'cancelledSessionId': sessionId,
      };
    };
    setActiveStudent('student-teacher-waiting-cancel-test');
    final router = GoRouter(
      initialLocation:
          '${WaitingForTeacherPageWidget.routePath}?sessionId=$sessionId',
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => const SizedBox(
            key: Key('student-dashboard-route'),
          ),
        ),
        GoRoute(
          name: WaitingForTeacherPageWidget.routeName,
          path: WaitingForTeacherPageWidget.routePath,
          builder: (context, state) => WaitingForTeacherPageWidget(
            sessionId: state.uri.queryParameters['sessionId'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    expect(find.byType(WaitingForTeacherPageWidget), findsOneWidget);
    await tester.tap(find.text('Отменить'));
    await tester.pump();
    await tester.pump();

    expect(cancelledSessionIds, [sessionId]);
    expect(router.getCurrentLocation(), StudentsDashboardWidget.routePath);
    expect(find.byKey(const Key('student-dashboard-route')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('direct waiting cancel pops back to previous page',
      (tester) async {
    const sessionId = 'session-direct-waiting-cancel-test';
    final waitingSessionController =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
    addTearDown(waitingSessionController.close);
    final cancelledSessionIds = <String>[];
    WaitingForTeacherPageWidget.debugCreateVideoSessionRequest = (_) async {
      return <String, dynamic>{
        'sessionId': sessionId,
      };
    };
    WaitingForTeacherPageWidget.debugSessionSnapshots =
        (_) => waitingSessionController.stream;
    WaitingForTeacherPageWidget.debugCancelCallRequest = (sessionId) async {
      cancelledSessionIds.add(sessionId);
      return <String, dynamic>{
        'status': 'cancelled',
        'cancelledSessionId': sessionId,
      };
    };
    setActiveStudent('student-direct-waiting-cancel-test');
    final router = GoRouter(
      initialLocation: '/native-speaker-test',
      routes: [
        GoRoute(
          path: '/native-speaker-test',
          builder: (context, state) => TextButton(
            key: const Key('open-direct-waiting'),
            onPressed: () {
              context.pushNamed(WaitingForTeacherPageWidget.routeName);
            },
            child: const Text('Open direct waiting'),
          ),
          routes: [
            GoRoute(
              name: WaitingForTeacherPageWidget.routeName,
              path: 'waiting',
              builder: (context, state) => const WaitingForTeacherPageWidget(
                targetTutorId: 'teacher-direct-waiting-cancel-test',
              ),
            ),
          ],
        ),
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => const SizedBox(
            key: Key('student-dashboard-route'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(find.byKey(const Key('open-direct-waiting')));
    await tester.pump();
    await tester.pump();

    expect(find.byType(WaitingForTeacherPageWidget), findsOneWidget);
    await tester.tap(find.text('Отменить'));
    await tester.pump();
    await tester.pump();

    expect(cancelledSessionIds, [sessionId]);
    expect(router.getCurrentLocation(), '/native-speaker-test');
    expect(find.byKey(const Key('student-dashboard-route')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('queue waiting opens video call after joinable snapshot',
      (tester) async {
    const sessionId = 'session-teacher-waiting-joinable-test';
    final waitingSessionController =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
    addTearDown(waitingSessionController.close);
    final tokenSessionIds = <String>[];
    WaitingForTeacherPageWidget.debugSessionSnapshots =
        (_) => waitingSessionController.stream;
    WaitingForTeacherPageWidget.debugGetSessionTokensRequest =
        (sessionId) async {
      tokenSessionIds.add(sessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    setActiveStudent('student-teacher-waiting-joinable-test');
    final router = GoRouter(
      initialLocation:
          '${WaitingForTeacherPageWidget.routePath}?sessionId=$sessionId',
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => const SizedBox(
            key: Key('student-dashboard-route'),
          ),
        ),
        GoRoute(
          name: WaitingForTeacherPageWidget.routeName,
          path: WaitingForTeacherPageWidget.routePath,
          builder: (context, state) => WaitingForTeacherPageWidget(
            sessionId: state.uri.queryParameters['sessionId'],
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

    waitingSessionController.add(
      _FakeSessionSnapshot(
        sessionId,
        <String, dynamic>{
          'status': 'connecting',
          'dailyRoomUrl': 'https://daily.test/$sessionId',
          'dailyRoomName': 'room-$sessionId',
        },
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
    expect(find.byKey(const Key('video-call-route')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('queue waiting retries token fetch after transient failure',
      (tester) async {
    const sessionId = 'session-teacher-waiting-token-retry-test';
    final waitingSessionController =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
    addTearDown(waitingSessionController.close);
    var tokenAttempts = 0;
    WaitingForTeacherPageWidget.debugSessionSnapshots =
        (_) => waitingSessionController.stream;
    WaitingForTeacherPageWidget.debugGetSessionTokensRequest =
        (sessionId) async {
      tokenAttempts += 1;
      if (tokenAttempts == 1) {
        throw StateError('temporary token failure');
      }
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    setActiveStudent('student-teacher-waiting-token-retry-test');
    final router = GoRouter(
      initialLocation:
          '${WaitingForTeacherPageWidget.routePath}?sessionId=$sessionId',
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => const SizedBox(
            key: Key('student-dashboard-route'),
          ),
        ),
        GoRoute(
          name: WaitingForTeacherPageWidget.routeName,
          path: WaitingForTeacherPageWidget.routePath,
          builder: (context, state) => WaitingForTeacherPageWidget(
            sessionId: state.uri.queryParameters['sessionId'],
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

    waitingSessionController.add(
      _FakeSessionSnapshot(
        sessionId,
        <String, dynamic>{
          'status': 'connecting',
          'dailyRoomUrl': 'https://daily.test/$sessionId',
          'dailyRoomName': 'room-$sessionId',
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(tokenAttempts, 2);
    expect(
      router.getCurrentLocation(),
      startsWith(VideoCallPageWidget.routePath),
    );
    expect(router.getCurrentLocation(), contains('meetingToken='));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('queue waiting terminal snapshot returns to dashboard',
      (tester) async {
    const sessionId = 'session-teacher-waiting-terminal-test';
    final waitingSessionController =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
    addTearDown(waitingSessionController.close);
    WaitingForTeacherPageWidget.debugSessionSnapshots =
        (_) => waitingSessionController.stream;
    setActiveStudent('student-teacher-waiting-terminal-test');
    final router = GoRouter(
      initialLocation:
          '${WaitingForTeacherPageWidget.routePath}?sessionId=$sessionId',
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => const SizedBox(
            key: Key('student-dashboard-route'),
          ),
        ),
        GoRoute(
          name: WaitingForTeacherPageWidget.routeName,
          path: WaitingForTeacherPageWidget.routePath,
          builder: (context, state) => WaitingForTeacherPageWidget(
            sessionId: state.uri.queryParameters['sessionId'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    waitingSessionController.add(
      _FakeSessionSnapshot(
        sessionId,
        const <String, dynamic>{
          'status': 'expired',
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(router.getCurrentLocation(), StudentsDashboardWidget.routePath);
    expect(find.byKey(const Key('student-dashboard-route')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('legacy student listener ignores flag before joinable status',
      (tester) async {
    const sessionId = 'session-legacy-flag-before-joinable-test';
    final sessionController =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
    addTearDown(sessionController.close);
    debugStudentSessionSnapshots = (_) => sessionController.stream;
    setActiveStudent('student-legacy-flag-before-joinable-test');
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('start-legacy-listener'),
            onPressed: () {
              unawaited(startStudentSessionListener(context, sessionId));
            },
            child: const Text('Start legacy listener'),
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

    await tester.tap(find.byKey(const Key('start-legacy-listener')));
    await tester.pump();
    await tester.pump();

    sessionController.add(
      _FakeSessionSnapshot(
        sessionId,
        <String, dynamic>{
          'status': 'pending_confirmation',
          'dailyRoomUrl': 'https://daily.test/$sessionId',
          'studentNavigationTriggered': true,
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(router.getCurrentLocation(), StudentsDashboardWidget.routePath);
    expect(find.byKey(const Key('video-call-route')), findsNothing);
    expect(studentNavigationHandled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('legacy student listener fetches token before video call',
      (tester) async {
    const sessionId = 'session-legacy-token-before-video-test';
    final sessionController =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
    addTearDown(sessionController.close);
    final tokenSessionIds = <String>[];
    final openedSessions = <Map<String, String?>>[];
    debugStudentSessionSnapshots = (_) => sessionController.stream;
    debugStudentSessionTokenRequest = (sessionId) async {
      tokenSessionIds.add(sessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugStudentSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add({
        'sessionId': videoDocRef.id,
        'roomUrl': roomUrl,
        'roomName': roomName,
        'meetingToken': meetingToken,
      });
    };
    setActiveStudent('student-legacy-token-before-video-test');
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('start-legacy-listener'),
            onPressed: () {
              unawaited(startStudentSessionListener(context, sessionId));
            },
            child: const Text('Start legacy listener'),
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

    await tester.tap(find.byKey(const Key('start-legacy-listener')));
    await tester.pump();

    sessionController.add(
      _FakeSessionSnapshot(
        sessionId,
        <String, dynamic>{
          'status': 'connecting',
          'dailyRoomUrl': 'https://stale-daily.test/$sessionId',
          'dailyRoomName': 'stale-room-$sessionId',
          'studentMeetingToken': 'stale-doc-token',
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.idle();
    await tester.pump();

    expect(tokenSessionIds, [sessionId]);
    expect(studentNavigationHandled, isTrue);
    expect(openedSessions, hasLength(1));
    expect(openedSessions.single['sessionId'], sessionId);
    expect(openedSessions.single['roomUrl'], 'https://daily.test/$sessionId');
    expect(openedSessions.single['roomName'], 'room-$sessionId');
    expect(openedSessions.single['meetingToken'], 'token-$sessionId');
    expect(openedSessions.single['meetingToken'], isNot('stale-doc-token'));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'legacy student listener ignores stale token callback after restart',
      (tester) async {
    const firstSessionId = 'session-legacy-stale-first-test';
    const secondSessionId = 'session-legacy-stale-second-test';
    final firstSessionController =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
    final secondSessionController =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
    addTearDown(firstSessionController.close);
    addTearDown(secondSessionController.close);
    final firstToken = Completer<Map<String, dynamic>>();
    final tokenSessionIds = <String>[];
    final openedSessions = <String>[];
    debugStudentSessionSnapshots = (sessionId) {
      if (sessionId == firstSessionId) {
        return firstSessionController.stream;
      }
      return secondSessionController.stream;
    };
    debugStudentSessionTokenRequest = (sessionId) async {
      tokenSessionIds.add(sessionId);
      if (sessionId == firstSessionId) {
        return firstToken.future;
      }
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugStudentSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add(videoDocRef.id);
    };
    setActiveStudent('student-legacy-stale-callback-test');
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => Column(
            children: [
              TextButton(
                key: const Key('start-first-legacy-listener'),
                onPressed: () {
                  unawaited(
                    startStudentSessionListener(context, firstSessionId),
                  );
                },
                child: const Text('Start first legacy listener'),
              ),
              TextButton(
                key: const Key('start-second-legacy-listener'),
                onPressed: () {
                  unawaited(
                    startStudentSessionListener(context, secondSessionId),
                  );
                },
                child: const Text('Start second legacy listener'),
              ),
            ],
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

    await tester.tap(find.byKey(const Key('start-first-legacy-listener')));
    await tester.pump();
    firstSessionController.add(
      _FakeSessionSnapshot(
        firstSessionId,
        <String, dynamic>{
          'status': 'connecting',
          'dailyRoomUrl': 'https://daily.test/$firstSessionId',
        },
      ),
    );
    await tester.pump();
    await tester.idle();

    expect(tokenSessionIds, [firstSessionId]);
    expect(studentSessionTokenFetchInProgress, isTrue);

    await tester.tap(find.byKey(const Key('start-second-legacy-listener')));
    await tester.pump();
    await tester.idle();
    firstToken.complete(<String, dynamic>{
      'roomUrl': 'https://daily.test/$firstSessionId',
      'roomName': 'room-$firstSessionId',
      'meetingToken': 'token-$firstSessionId',
    });
    await tester.pump();
    await tester.idle();

    expect(openedSessions, isEmpty);
    expect(studentNavigationHandled, isFalse);

    secondSessionController.add(
      _FakeSessionSnapshot(
        secondSessionId,
        <String, dynamic>{
          'status': 'connecting',
          'dailyRoomUrl': 'https://daily.test/$secondSessionId',
        },
      ),
    );
    await tester.pump();
    await tester.idle();
    await tester.pump();

    expect(tokenSessionIds, [firstSessionId, secondSessionId]);
    expect(openedSessions, [secondSessionId]);
    expect(studentNavigationHandled, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'legacy student listener ignores stale stream event after restart',
      (tester) async {
    const firstSessionId = 'session-legacy-stale-stream-first-test';
    const secondSessionId = 'session-legacy-stale-stream-second-test';
    final firstSessionController =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
    final secondSessionController =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
    addTearDown(firstSessionController.close);
    addTearDown(secondSessionController.close);
    final tokenSessionIds = <String>[];
    final openedSessions = <String>[];
    debugStudentSessionSnapshots = (sessionId) {
      if (sessionId == firstSessionId) {
        return firstSessionController.stream;
      }
      return secondSessionController.stream;
    };
    debugStudentSessionTokenRequest = (sessionId) async {
      tokenSessionIds.add(sessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugStudentSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add(videoDocRef.id);
    };
    setActiveStudent('student-legacy-stale-stream-test');
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => Column(
            children: [
              TextButton(
                key: const Key('start-first-legacy-listener'),
                onPressed: () {
                  unawaited(
                    startStudentSessionListener(context, firstSessionId),
                  );
                },
                child: const Text('Start first legacy listener'),
              ),
              TextButton(
                key: const Key('start-second-legacy-listener'),
                onPressed: () {
                  unawaited(
                    startStudentSessionListener(context, secondSessionId),
                  );
                },
                child: const Text('Start second legacy listener'),
              ),
            ],
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

    await tester.tap(find.byKey(const Key('start-first-legacy-listener')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('start-second-legacy-listener')));
    await tester.pump();

    firstSessionController.add(
      _FakeSessionSnapshot(
        firstSessionId,
        <String, dynamic>{
          'status': 'connecting',
          'dailyRoomUrl': 'https://daily.test/$firstSessionId',
        },
      ),
    );
    await tester.pump();
    await tester.idle();

    expect(tokenSessionIds, isEmpty);
    expect(openedSessions, isEmpty);
    expect(studentSessionTokenFetchInProgress, isFalse);

    secondSessionController.add(
      _FakeSessionSnapshot(
        secondSessionId,
        <String, dynamic>{
          'status': 'connecting',
          'dailyRoomUrl': 'https://daily.test/$secondSessionId',
        },
      ),
    );
    await tester.pump();
    await tester.idle();
    await tester.pump();

    expect(tokenSessionIds, [secondSessionId]);
    expect(openedSessions, [secondSessionId]);
    expect(studentNavigationHandled, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('accepted teacher session recovers from current session id',
      (tester) async {
    const userId = 'student-accepted-current-session-recovery-test';
    const sessionId = 'session-accepted-current-session-recovery-test';
    const teacherId = 'teacher-accepted-current-session-recovery-test';
    final tokenSessionIds = <String>[];
    final openedSessions = <Map<String, String?>>[];
    debugActiveSessionUserSnapshot = (requestedUserId) async {
      expect(requestedUserId, userId);
      return _FakeSessionSnapshot(
        userId,
        const <String, dynamic>{
          'currentSessionId': sessionId,
          'isInCall': true,
        },
        FirebaseFirestore.instance.collection('users').doc(userId),
      );
    };
    debugActiveNavigationSessionSnapshots = (_) async => [];
    debugActiveCurrentSessionSnapshot = (requestedSessionId) async {
      expect(requestedSessionId, sessionId);
      return _FakeSessionSnapshot(
        sessionId,
        <String, dynamic>{
          'status': 'connecting',
          'studentId': userId,
          'tutorId': teacherId,
          'dailyRoomUrl': 'https://stale-daily.test/$sessionId',
          'dailyRoomName': 'stale-room-$sessionId',
          'studentNavigationTriggered': false,
          'tutorNavigationTriggered': false,
        },
        FirebaseFirestore.instance.collection('videoSessions').doc(sessionId),
      );
    };
    debugActiveSessionTokenRequest = (requestedSessionId) async {
      tokenSessionIds.add(requestedSessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add({
        'sessionId': videoDocRef.id,
        'roomUrl': roomUrl,
        'roomName': roomName,
        'meetingToken': meetingToken,
      });
    };
    setActiveStudent(userId, currentSessionId: sessionId, isInCall: true);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-accepted-current-session'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover accepted session'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(find.byKey(const Key('recover-accepted-current-session')));
    await tester.pump();
    await tester.idle();
    await tester.pump();

    expect(recovered, isTrue);
    expect(tokenSessionIds, [sessionId]);
    expect(openedSessions, hasLength(1));
    expect(openedSessions.single['sessionId'], sessionId);
    expect(openedSessions.single['roomUrl'], 'https://daily.test/$sessionId');
    expect(openedSessions.single['roomName'], 'room-$sessionId');
    expect(openedSessions.single['meetingToken'], 'token-$sessionId');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup recovery restores active call after restart',
      (tester) async {
    const userId = 'student-active-call-restart-test';
    const peerId = 'student-active-call-peer-test';
    const sessionId = 'session-active-call-restart-test';
    final tokenSessionIds = <String>[];
    final openedSessions = <Map<String, String?>>[];
    var fallbackSessionsRead = false;
    debugActiveSessionUserSnapshot = (requestedUserId) async {
      expect(requestedUserId, userId);
      return _FakeSessionSnapshot(
        userId,
        const <String, dynamic>{
          'currentSessionId': sessionId,
          'isInCall': true,
        },
        FirebaseFirestore.instance.collection('users').doc(userId),
      );
    };
    debugActiveNavigationSessionSnapshots = (_) async {
      fallbackSessionsRead = true;
      return [];
    };
    debugActiveCurrentSessionSnapshot = (requestedSessionId) async {
      expect(requestedSessionId, sessionId);
      return _FakeSessionSnapshot(
        sessionId,
        <String, dynamic>{
          'status': 'active',
          'participantIds': [userId, peerId],
          'requesterId': userId,
          'responderId': peerId,
          'dailyRoomUrl': 'https://stale-daily.test/$sessionId',
          'dailyRoomName': 'stale-room-$sessionId',
        },
        FirebaseFirestore.instance.collection('videoSessions').doc(sessionId),
      );
    };
    debugActiveSessionTokenRequest = (requestedSessionId) async {
      tokenSessionIds.add(requestedSessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add({
        'sessionId': videoDocRef.id,
        'roomUrl': roomUrl,
        'roomName': roomName,
        'meetingToken': meetingToken,
      });
    };
    setActiveStudent(userId, currentSessionId: sessionId, isInCall: true);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-active-call-after-restart'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover active call after restart'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester
        .tap(find.byKey(const Key('recover-active-call-after-restart')));
    await tester.pump();
    await tester.idle();
    await tester.pump();

    expect(recovered, isTrue);
    expect(fallbackSessionsRead, isFalse);
    expect(tokenSessionIds, [sessionId]);
    expect(openedSessions, hasLength(1));
    expect(openedSessions.single['sessionId'], sessionId);
    expect(openedSessions.single['roomUrl'], 'https://daily.test/$sessionId');
    expect(openedSessions.single['roomName'], 'room-$sessionId');
    expect(openedSessions.single['meetingToken'], 'token-$sessionId');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('accepted recovery ignores current session when not in call',
      (tester) async {
    const userId = 'student-accepted-not-in-call-test';
    const sessionId = 'session-accepted-not-in-call-test';
    var currentSessionRead = false;
    var tokenRequested = false;
    final openedSessions = <String>[];
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'currentSessionId': sessionId,
            'isInCall': false,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveNavigationSessionSnapshots = (_) async {
      throw StateError('navigation fallback should not be read');
    };
    debugActiveCurrentSessionSnapshot = (_) async {
      currentSessionRead = true;
      return _FakeSessionSnapshot(
        sessionId,
        <String, dynamic>{
          'status': 'connecting',
          'studentId': userId,
          'tutorId': 'teacher-not-in-call-test',
        },
        FirebaseFirestore.instance.collection('videoSessions').doc(sessionId),
      );
    };
    debugActiveSessionTokenRequest = (_) async {
      tokenRequested = true;
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add(videoDocRef.id);
    };
    setActiveStudent(userId, currentSessionId: sessionId, isInCall: false);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-not-in-call-current-session'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover not in call current session'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('recover-not-in-call-current-session')),
    );
    await tester.pump();
    await tester.idle();

    expect(recovered, isFalse);
    expect(currentSessionRead, isFalse);
    expect(tokenRequested, isFalse);
    expect(openedSessions, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup recovery opens dashboard for active search request',
      (tester) async {
    const userId = 'student-startup-active-search-test';
    final searchRequestReads = <String>[];
    ActiveSearchRecoveryState? observedSearchState;
    var currentSessionRead = false;
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'isInCall': false,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveSearchRequestSnapshot = (requestedUserId) async {
      searchRequestReads.add(requestedUserId);
      return _FakeSessionSnapshot(
        requestedUserId,
        <String, dynamic>{
          'requestId': 'request-startup-active-search-test',
          'userId': userId,
          'status': 'active',
          'heartbeatAt': DateTime.now(),
          'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
        },
        FirebaseFirestore.instance
            .collection('searchRequests')
            .doc(requestedUserId),
      );
    };
    debugActiveSearchRecoveryObserver = (state) {
      observedSearchState = state;
    };
    debugActiveCurrentSessionSnapshot = (_) async {
      currentSessionRead = true;
      return null;
    };
    setActiveStudent(userId, isInCall: false);
    bool? recovered;
    final router = GoRouter(
      initialLocation: '/startup-active-search-test',
      routes: [
        GoRoute(
          name: 'StartupActiveSearchTest',
          path: '/startup-active-search-test',
          builder: (context, state) => TextButton(
            key: const Key('recover-active-search-request'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover active search request'),
          ),
        ),
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => const Text(
            'Recovered active search dashboard',
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(find.byKey(const Key('recover-active-search-request')));
    await tester.pump();
    await tester.idle();
    await tester.pump();

    expect(recovered, isTrue);
    expect(router.getCurrentLocation(), StudentsDashboardWidget.routePath);
    expect(find.text('Recovered active search dashboard'), findsOneWidget);
    expect(searchRequestReads, [userId]);
    expect(currentSessionRead, isFalse);
    expect(observedSearchState, isNotNull);
    expect(observedSearchState!.exists, isTrue);
    expect(observedSearchState!.belongsToUser, isTrue);
    expect(observedSearchState!.isLiveStatus, isTrue);
    expect(observedSearchState!.isExpired, isFalse);
    expect(observedSearchState!.hasActiveSearch, isTrue);
    expect(
      observedSearchState!.requestId,
      'request-startup-active-search-test',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup recovery ignores terminal cancelled search request',
      (tester) async {
    const userId = 'student-startup-cancelled-search-test';
    ActiveSearchRecoveryState? observedSearchState;
    var currentSessionRead = false;
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'isInCall': false,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveSearchRequestSnapshot = (requestedUserId) async {
      return _FakeSessionSnapshot(
        requestedUserId,
        <String, dynamic>{
          'requestId': 'request-startup-cancelled-search-test',
          'userId': userId,
          'status': 'cancelled',
          'heartbeatAt': DateTime.now(),
          'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
          'stopReason': 'call_cancelled',
        },
        FirebaseFirestore.instance
            .collection('searchRequests')
            .doc(requestedUserId),
      );
    };
    debugActiveSearchRecoveryObserver = (state) {
      observedSearchState = state;
    };
    debugActiveCurrentSessionSnapshot = (_) async {
      currentSessionRead = true;
      return null;
    };
    setActiveStudent(userId, isInCall: false);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-cancelled-search-request'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover cancelled search request'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(find.byKey(const Key('recover-cancelled-search-request')));
    await tester.pump();
    await tester.idle();

    expect(recovered, isFalse);
    expect(currentSessionRead, isFalse);
    expect(observedSearchState, isNotNull);
    expect(observedSearchState!.hasTerminalResult, isTrue);
    expect(observedSearchState!.hasActiveSearch, isFalse);
    expect(observedSearchState!.canResumeActiveSession, isFalse);
    expect(observedSearchState!.canResumeConnection, isFalse);
    expect(observedSearchState!.canResumeUnboundSearch, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup recovery ignores live search with terminal stop reason',
      (tester) async {
    const userId = 'student-startup-live-terminal-reason-test';
    var currentSessionRead = false;
    ActiveSearchRecoveryState? observedSearchState;
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'isInCall': false,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveSearchRequestSnapshot = (requestedUserId) async {
      return _FakeSessionSnapshot(
        requestedUserId,
        <String, dynamic>{
          'requestId': 'request-startup-live-terminal-reason-test',
          'userId': userId,
          'status': 'active',
          'heartbeatAt': DateTime.now(),
          'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
          'stopReason': 'session_ended',
        },
        FirebaseFirestore.instance
            .collection('searchRequests')
            .doc(requestedUserId),
      );
    };
    debugActiveSearchRecoveryObserver = (state) {
      observedSearchState = state;
    };
    debugActiveCurrentSessionSnapshot = (_) async {
      currentSessionRead = true;
      return null;
    };
    setActiveStudent(userId, isInCall: false);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-live-terminal-reason-search-request'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover live terminal reason search request'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('recover-live-terminal-reason-search-request')),
    );
    await tester.pump();
    await tester.idle();

    expect(recovered, isFalse);
    expect(currentSessionRead, isFalse);
    expect(observedSearchState, isNotNull);
    expect(observedSearchState!.isLiveStatus, isTrue);
    expect(observedSearchState!.hasTerminalResult, isTrue);
    expect(observedSearchState!.hasActiveSearch, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup recovery opens active session from search request',
      (tester) async {
    const userId = 'student-startup-active-session-search-test';
    const peerId = 'student-startup-active-session-peer-test';
    const sessionId = 'session-startup-active-session-search-test';
    final tokenSessionIds = <String>[];
    final openedSessions = <Map<String, String?>>[];
    ActiveSearchRecoveryState? observedSearchState;
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'isInCall': false,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveSearchRequestSnapshot = (requestedUserId) async {
      return _FakeSessionSnapshot(
        requestedUserId,
        <String, dynamic>{
          'requestId': 'request-startup-active-session-search-test',
          'userId': userId,
          'status': 'active',
          'heartbeatAt': DateTime.now(),
          'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
          'currentSessionId': sessionId,
        },
        FirebaseFirestore.instance
            .collection('searchRequests')
            .doc(requestedUserId),
      );
    };
    debugActiveSearchRecoveryObserver = (state) {
      observedSearchState = state;
    };
    debugActiveCurrentSessionSnapshot = (requestedSessionId) async {
      expect(requestedSessionId, sessionId);
      return _FakeSessionSnapshot(
        sessionId,
        <String, dynamic>{
          'status': 'active',
          'participantIds': [userId, peerId],
          'requesterId': userId,
          'responderId': peerId,
          'dailyRoomUrl': 'https://stale-daily.test/$sessionId',
          'dailyRoomName': 'stale-room-$sessionId',
        },
        FirebaseFirestore.instance.collection('videoSessions').doc(sessionId),
      );
    };
    debugActiveSessionTokenRequest = (requestedSessionId) async {
      tokenSessionIds.add(requestedSessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add({
        'sessionId': videoDocRef.id,
        'roomUrl': roomUrl,
        'roomName': roomName,
        'meetingToken': meetingToken,
      });
    };
    setActiveStudent(userId, isInCall: false);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-active-session-search-request'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover active session search request'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('recover-active-session-search-request')),
    );
    await tester.pump();
    await tester.idle();

    expect(recovered, isTrue);
    expect(observedSearchState, isNotNull);
    expect(observedSearchState!.canResumeActiveSession, isTrue);
    expect(observedSearchState!.canResumeConnection, isTrue);
    expect(tokenSessionIds, [sessionId]);
    expect(openedSessions, hasLength(1));
    expect(openedSessions.single['sessionId'], sessionId);
    expect(openedSessions.single['roomUrl'], 'https://daily.test/$sessionId');
    expect(openedSessions.single['roomName'], 'room-$sessionId');
    expect(openedSessions.single['meetingToken'], 'token-$sessionId');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup recovery does not open expired room join window',
      (tester) async {
    const userId = 'student-startup-expired-join-window-test';
    const peerId = 'student-startup-expired-join-window-peer-test';
    const sessionId = 'session-startup-expired-join-window-test';
    final now = DateTime(2026, 1, 1, 12);
    final tokenSessionIds = <String>[];
    final openedSessions = <String>[];
    debugActiveSearchRecoveryNow = () => now;
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'isInCall': false,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveSearchRequestSnapshot = (requestedUserId) async {
      return _FakeSessionSnapshot(
        requestedUserId,
        <String, dynamic>{
          'requestId': 'request-startup-expired-join-window-test',
          'userId': userId,
          'status': 'active',
          'heartbeatAt': now,
          'expiresAt': now.add(const Duration(minutes: 5)),
          'currentSessionId': sessionId,
        },
        FirebaseFirestore.instance
            .collection('searchRequests')
            .doc(requestedUserId),
      );
    };
    debugActiveCurrentSessionSnapshot = (requestedSessionId) async {
      expect(requestedSessionId, sessionId);
      return _FakeSessionSnapshot(
        sessionId,
        <String, dynamic>{
          'status': 'connecting',
          'participantIds': [userId, peerId],
          'requesterId': userId,
          'responderId': peerId,
          'joinDeadlineAt': now.subtract(const Duration(seconds: 1)),
          'dailyRoomUrl': 'https://daily.test/$sessionId',
        },
        FirebaseFirestore.instance.collection('videoSessions').doc(sessionId),
      );
    };
    debugActiveSessionTokenRequest = (requestedSessionId) async {
      tokenSessionIds.add(requestedSessionId);
      throw StateError('Session credential window has expired');
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add(videoDocRef.id);
    };
    setActiveStudent(userId, isInCall: false);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-expired-join-window'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover expired join window'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(find.byKey(const Key('recover-expired-join-window')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.idle();

    expect(recovered, isFalse);
    expect(tokenSessionIds, isEmpty);
    expect(openedSessions, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup recovery waits when active search session lacks token',
      (tester) async {
    const userId = 'student-startup-active-session-no-token-test';
    const peerId = 'student-startup-active-session-no-token-peer-test';
    const sessionId = 'session-startup-active-session-no-token-test';
    final tokenSessionIds = <String>[];
    final openedSessionIds = <String>[];
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'isInCall': false,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveSearchRequestSnapshot = (requestedUserId) async {
      return _FakeSessionSnapshot(
        requestedUserId,
        <String, dynamic>{
          'requestId': 'request-startup-active-session-no-token-test',
          'userId': userId,
          'status': 'active',
          'heartbeatAt': DateTime.now(),
          'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
          'currentSessionId': sessionId,
        },
        FirebaseFirestore.instance
            .collection('searchRequests')
            .doc(requestedUserId),
      );
    };
    debugActiveCurrentSessionSnapshot = (_) async => _FakeSessionSnapshot(
          sessionId,
          <String, dynamic>{
            'status': 'active',
            'participantIds': [userId, peerId],
            'requesterId': userId,
            'responderId': peerId,
            'dailyRoomUrl': 'https://daily.test/$sessionId',
          },
          FirebaseFirestore.instance.collection('videoSessions').doc(sessionId),
        );
    debugActiveSessionTokenRequest = (requestedSessionId) async {
      tokenSessionIds.add(requestedSessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
      };
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessionIds.add(videoDocRef.id);
    };
    setActiveStudent(userId, isInCall: false);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-active-session-no-token-search-request'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover active session without token'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('recover-active-session-no-token-search-request')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.idle();

    expect(recovered, isTrue);
    expect(tokenSessionIds, List.filled(5, sessionId));
    expect(openedSessionIds, isEmpty);
    expect(router.getCurrentLocation(), StudentsDashboardWidget.routePath);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup recovery opens linked connecting session',
      (tester) async {
    const userId = 'student-startup-connecting-session-search-test';
    const peerId = 'student-startup-connecting-session-peer-test';
    const sessionId = 'session-startup-connecting-session-search-test';
    final now = DateTime(2026, 1, 1, 12);
    final openedSessions = <String>[];
    debugActiveSearchRecoveryNow = () => now;
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'isInCall': false,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveSearchRequestSnapshot = (requestedUserId) async {
      return _FakeSessionSnapshot(
        requestedUserId,
        <String, dynamic>{
          'requestId': 'request-startup-connecting-session-search-test',
          'userId': userId,
          'status': 'active',
          'heartbeatAt': now,
          'expiresAt': now.add(const Duration(minutes: 5)),
          'currentSessionId': sessionId,
        },
        FirebaseFirestore.instance
            .collection('searchRequests')
            .doc(requestedUserId),
      );
    };
    debugActiveCurrentSessionSnapshot = (requestedSessionId) async {
      expect(requestedSessionId, sessionId);
      return _FakeSessionSnapshot(
        sessionId,
        <String, dynamic>{
          'status': 'connecting',
          'participantIds': [userId, peerId],
          'requesterId': userId,
          'responderId': peerId,
          'joinDeadlineAt': now.add(const Duration(seconds: 60)),
          'dailyRoomUrl': 'https://daily.test/$sessionId',
        },
        FirebaseFirestore.instance.collection('videoSessions').doc(sessionId),
      );
    };
    debugActiveSessionTokenRequest = (_) async => <String, dynamic>{
          'roomUrl': 'https://daily.test/$sessionId',
          'meetingToken': 'token-$sessionId',
        };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add(videoDocRef.id);
    };
    setActiveStudent(userId, isInCall: false);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-connecting-session-search-request'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover connecting session'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('recover-connecting-session-search-request')),
    );
    await tester.pump();
    await tester.idle();

    expect(recovered, isTrue);
    expect(openedSessions, [sessionId]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup recovery ignores terminal linked active session',
      (tester) async {
    const userId = 'student-startup-terminal-active-session-test';
    const peerId = 'student-startup-terminal-active-session-peer-test';
    const sessionId = 'session-startup-terminal-active-session-test';
    final tokenSessionIds = <String>[];
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'isInCall': false,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveSearchRequestSnapshot = (requestedUserId) async {
      return _FakeSessionSnapshot(
        requestedUserId,
        <String, dynamic>{
          'requestId': 'request-startup-terminal-active-session-test',
          'userId': userId,
          'status': 'active',
          'heartbeatAt': DateTime.now(),
          'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
          'currentSessionId': sessionId,
        },
        FirebaseFirestore.instance
            .collection('searchRequests')
            .doc(requestedUserId),
      );
    };
    debugActiveCurrentSessionSnapshot = (requestedSessionId) async {
      expect(requestedSessionId, sessionId);
      return _FakeSessionSnapshot(
        sessionId,
        <String, dynamic>{
          'status': 'ended',
          'participantIds': [userId, peerId],
          'requesterId': userId,
          'responderId': peerId,
        },
        FirebaseFirestore.instance.collection('videoSessions').doc(sessionId),
      );
    };
    debugActiveSessionTokenRequest = (requestedSessionId) async {
      tokenSessionIds.add(requestedSessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    setActiveStudent(userId, isInCall: false);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-terminal-active-session'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover terminal active session'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(find.byKey(const Key('recover-terminal-active-session')));
    await tester.pump();
    await tester.idle();

    expect(recovered, isFalse);
    expect(tokenSessionIds, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup recovery fails closed when linked session read fails',
      (tester) async {
    const userId = 'student-startup-session-read-error-test';
    const sessionId = 'session-startup-session-read-error-test';
    final tokenSessionIds = <String>[];
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'isInCall': false,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveSearchRequestSnapshot = (requestedUserId) async {
      return _FakeSessionSnapshot(
        requestedUserId,
        <String, dynamic>{
          'requestId': 'request-startup-session-read-error-test',
          'userId': userId,
          'status': 'active',
          'heartbeatAt': DateTime.now(),
          'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
          'currentSessionId': sessionId,
        },
        FirebaseFirestore.instance
            .collection('searchRequests')
            .doc(requestedUserId),
      );
    };
    debugActiveCurrentSessionSnapshot = (requestedSessionId) async {
      expect(requestedSessionId, sessionId);
      throw StateError('linked session unavailable');
    };
    debugActiveSessionTokenRequest = (requestedSessionId) async {
      tokenSessionIds.add(requestedSessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    setActiveStudent(userId, isInCall: false);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-session-read-error'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover session read error'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(find.byKey(const Key('recover-session-read-error')));
    await tester.pump();
    await tester.idle();

    expect(recovered, isFalse);
    expect(tokenSessionIds, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup recovery ignores foreign active search session',
      (tester) async {
    const userId = 'student-startup-active-session-foreign-test';
    const foreignRequesterId =
        'student-startup-active-session-foreign-requester-test';
    const foreignResponderId =
        'student-startup-active-session-foreign-responder-test';
    const sessionId = 'session-startup-active-session-foreign-test';
    final tokenSessionIds = <String>[];
    final openedSessionIds = <String>[];
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'isInCall': false,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveSearchRequestSnapshot = (requestedUserId) async {
      return _FakeSessionSnapshot(
        requestedUserId,
        <String, dynamic>{
          'requestId': 'request-startup-active-session-foreign-test',
          'userId': userId,
          'status': 'active',
          'heartbeatAt': DateTime.now(),
          'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
          'currentSessionId': sessionId,
        },
        FirebaseFirestore.instance
            .collection('searchRequests')
            .doc(requestedUserId),
      );
    };
    debugActiveCurrentSessionSnapshot = (_) async => _FakeSessionSnapshot(
          sessionId,
          <String, dynamic>{
            'status': 'active',
            'participantIds': [foreignRequesterId, foreignResponderId],
            'requesterId': foreignRequesterId,
            'responderId': foreignResponderId,
            'dailyRoomUrl': 'https://daily.test/$sessionId',
          },
          FirebaseFirestore.instance.collection('videoSessions').doc(sessionId),
        );
    debugActiveSessionTokenRequest = (requestedSessionId) async {
      tokenSessionIds.add(requestedSessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessionIds.add(videoDocRef.id);
    };
    setActiveStudent(userId, isInCall: false);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-active-session-foreign-search-request'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover foreign active session'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('recover-active-session-foreign-search-request')),
    );
    await tester.pump();
    await tester.idle();

    expect(recovered, isFalse);
    expect(tokenSessionIds, isEmpty);
    expect(openedSessionIds, isEmpty);
    expect(router.getCurrentLocation(), StudentsDashboardWidget.routePath);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup recovery ignores terminal session-bound search',
      (tester) async {
    const userId = 'student-startup-terminal-bound-search-test';
    const sessionId = 'session-startup-terminal-bound-search-test';
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'isInCall': false,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveSearchRequestSnapshot = (requestedUserId) async {
      return _FakeSessionSnapshot(
        requestedUserId,
        <String, dynamic>{
          'requestId': 'request-startup-terminal-bound-search-test',
          'userId': userId,
          'status': 'matching',
          'heartbeatAt': DateTime.now(),
          'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
          'currentSessionId': sessionId,
        },
        FirebaseFirestore.instance
            .collection('searchRequests')
            .doc(requestedUserId),
      );
    };
    debugActiveCurrentSessionSnapshot = (requestedSessionId) async {
      expect(requestedSessionId, sessionId);
      return _FakeSessionSnapshot(
        sessionId,
        const <String, dynamic>{
          'status': 'cancelled',
        },
        FirebaseFirestore.instance.collection('videoSessions').doc(sessionId),
      );
    };
    setActiveStudent(userId, isInCall: false);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-terminal-bound-search-request'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover terminal bound search request'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('recover-terminal-bound-search-request')),
    );
    await tester.pump();
    await tester.idle();

    expect(recovered, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup recovery completes session-bound active search',
      (tester) async {
    const userId = 'student-startup-session-bound-search-test';
    const sessionId = 'session-startup-session-bound-search-test';
    ActiveSearchRecoveryState? observedSearchState;
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'isInCall': false,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveSearchRequestSnapshot = (requestedUserId) async {
      return _FakeSessionSnapshot(
        requestedUserId,
        <String, dynamic>{
          'requestId': 'request-startup-session-bound-search-test',
          'userId': userId,
          'status': 'matching',
          'heartbeatAt': DateTime.now(),
          'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
          'currentSessionId': sessionId,
        },
        FirebaseFirestore.instance
            .collection('searchRequests')
            .doc(requestedUserId),
      );
    };
    debugActiveSearchRecoveryObserver = (state) {
      observedSearchState = state;
    };
    debugActiveCurrentSessionSnapshot = (requestedSessionId) async {
      expect(requestedSessionId, sessionId);
      return _FakeSessionSnapshot(
        sessionId,
        const <String, dynamic>{
          'status': 'pending_confirmation',
          'participantIds': [userId],
        },
        FirebaseFirestore.instance.collection('videoSessions').doc(sessionId),
      );
    };
    setActiveStudent(userId, isInCall: false);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-session-bound-search-request'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover session-bound search request'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('recover-session-bound-search-request')),
    );
    await tester.pump();
    await tester.idle();

    expect(recovered, isTrue);
    expect(observedSearchState, isNotNull);
    expect(observedSearchState!.canResumeSearch, isTrue);
    expect(observedSearchState!.canResumeConnection, isTrue);
    expect(observedSearchState!.canResumeUnboundSearch, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup recovery treats matching search as active',
      (tester) async {
    const userId = 'student-startup-matching-search-test';
    final observedSearchState = await runStartupSearchRecoveryTest(
      tester,
      userId: userId,
      searchData: <String, dynamic>{
        'requestId': 'request-startup-matching-search-test',
        'userId': userId,
        'status': 'matching',
        'heartbeatAt': DateTime.now(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
      },
    );

    expect(observedSearchState, isNotNull);
    expect(observedSearchState!.isLiveStatus, isTrue);
    expect(observedSearchState.isExpired, isFalse);
    expect(observedSearchState.hasActiveSearch, isTrue);
  });

  testWidgets('startup recovery does not treat matched search as active',
      (tester) async {
    const userId = 'student-startup-matched-search-test';
    final observedSearchState = await runStartupSearchRecoveryTest(
      tester,
      userId: userId,
      searchData: <String, dynamic>{
        'requestId': 'request-startup-matched-search-test',
        'userId': userId,
        'status': 'matched',
        'heartbeatAt': DateTime.now(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
        'currentSessionId': 'session-startup-matched-search-test',
      },
    );

    expect(observedSearchState, isNotNull);
    expect(observedSearchState!.isLiveStatus, isFalse);
    expect(observedSearchState.hasActiveSearch, isFalse);
  });

  testWidgets('startup recovery treats stale active search as expired',
      (tester) async {
    const userId = 'student-startup-stale-search-test';
    final observedSearchState = await runStartupSearchRecoveryTest(
      tester,
      userId: userId,
      searchData: <String, dynamic>{
        'requestId': 'request-startup-stale-search-test',
        'userId': userId,
        'status': 'active',
        'heartbeatAt': DateTime.now().subtract(const Duration(minutes: 2)),
        'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
      },
    );

    expect(observedSearchState, isNotNull);
    expect(observedSearchState!.exists, isTrue);
    expect(observedSearchState.belongsToUser, isTrue);
    expect(observedSearchState.isLiveStatus, isTrue);
    expect(observedSearchState.isExpired, isTrue);
    expect(observedSearchState.hasActiveSearch, isFalse);
  });

  testWidgets('startup recovery treats missing heartbeat as expired',
      (tester) async {
    const userId = 'student-startup-missing-heartbeat-search-test';
    final observedSearchState = await runStartupSearchRecoveryTest(
      tester,
      userId: userId,
      searchData: <String, dynamic>{
        'requestId': 'request-startup-missing-heartbeat-search-test',
        'userId': userId,
        'status': 'active',
        'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
      },
    );

    expect(observedSearchState, isNotNull);
    expect(observedSearchState!.isLiveStatus, isTrue);
    expect(observedSearchState.isExpired, isTrue);
    expect(observedSearchState.hasActiveSearch, isFalse);
  });

  testWidgets('startup recovery treats missing expiresAt as expired',
      (tester) async {
    const userId = 'student-startup-missing-expires-search-test';
    final observedSearchState = await runStartupSearchRecoveryTest(
      tester,
      userId: userId,
      searchData: <String, dynamic>{
        'requestId': 'request-startup-missing-expires-search-test',
        'userId': userId,
        'status': 'active',
        'heartbeatAt': DateTime.now(),
      },
    );

    expect(observedSearchState, isNotNull);
    expect(observedSearchState!.isLiveStatus, isTrue);
    expect(observedSearchState.isExpired, isTrue);
    expect(observedSearchState.hasActiveSearch, isFalse);
  });

  testWidgets('startup recovery keeps heartbeat at stale cutoff active',
      (tester) async {
    const userId = 'student-startup-cutoff-search-test';
    final now = DateTime(2026, 1, 1, 12);
    debugActiveSearchRecoveryNow = () => now;
    final observedSearchState = await runStartupSearchRecoveryTest(
      tester,
      userId: userId,
      searchData: <String, dynamic>{
        'requestId': 'request-startup-cutoff-search-test',
        'userId': userId,
        'status': 'active',
        'heartbeatAt': now.subtract(const Duration(seconds: 90)),
        'expiresAt': now.add(const Duration(minutes: 5)),
      },
    );

    expect(observedSearchState, isNotNull);
    expect(observedSearchState!.isLiveStatus, isTrue);
    expect(observedSearchState.isExpired, isFalse);
    expect(observedSearchState.hasActiveSearch, isTrue);
  });

  testWidgets('startup recovery keeps background search during grace window',
      (tester) async {
    const userId = 'student-startup-background-search-test';
    final now = DateTime(2026, 1, 1, 12);
    debugActiveSearchRecoveryNow = () => now;
    final observedSearchState = await runStartupSearchRecoveryTest(
      tester,
      userId: userId,
      searchData: <String, dynamic>{
        'requestId': 'request-startup-background-search-test',
        'userId': userId,
        'status': 'active',
        'appState': 'background',
        'heartbeatAt': now.subtract(const Duration(seconds: 30)),
        'backgroundExpiresAt': now.add(const Duration(minutes: 5)),
        'expiresAt': now.add(const Duration(minutes: 5)),
      },
    );

    expect(observedSearchState, isNotNull);
    expect(observedSearchState!.exists, isTrue);
    expect(observedSearchState.belongsToUser, isTrue);
    expect(observedSearchState.isLiveStatus, isTrue);
    expect(observedSearchState.isExpired, isFalse);
    expect(observedSearchState.hasActiveSearch, isTrue);
  });

  testWidgets('startup recovery rejects closed background stale heartbeat',
      (tester) async {
    const userId = 'student-startup-background-stale-search-test';
    final now = DateTime(2026, 1, 1, 12);
    debugActiveSearchRecoveryNow = () => now;
    final observedSearchState = await runStartupSearchRecoveryTest(
      tester,
      userId: userId,
      searchData: <String, dynamic>{
        'requestId': 'request-startup-background-stale-search-test',
        'userId': userId,
        'status': 'active',
        'appState': 'background',
        'heartbeatAt': now.subtract(const Duration(seconds: 91)),
        'backgroundExpiresAt': now.add(const Duration(minutes: 5)),
        'expiresAt': now.add(const Duration(minutes: 5)),
      },
    );

    expect(observedSearchState, isNotNull);
    expect(observedSearchState!.exists, isTrue);
    expect(observedSearchState.belongsToUser, isTrue);
    expect(observedSearchState.isLiveStatus, isTrue);
    expect(observedSearchState.isExpired, isTrue);
    expect(observedSearchState.hasActiveSearch, isFalse);
  });

  testWidgets('startup recovery rejects mismatched search owner',
      (tester) async {
    const userId = 'student-startup-owner-search-test';
    final observedSearchState = await runStartupSearchRecoveryTest(
      tester,
      userId: userId,
      searchData: <String, dynamic>{
        'requestId': 'request-startup-owner-search-test',
        'userId': 'other-student-startup-owner-search-test',
        'status': 'active',
        'heartbeatAt': DateTime.now(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
      },
    );

    expect(observedSearchState, isNotNull);
    expect(observedSearchState!.exists, isTrue);
    expect(observedSearchState.belongsToUser, isFalse);
    expect(observedSearchState.hasActiveSearch, isFalse);
  });

  testWidgets('accepted recovery uses token room url before session room write',
      (tester) async {
    const userId = 'student-accepted-token-room-url-test';
    const sessionId = 'session-accepted-token-room-url-test';
    final tokenSessionIds = <String>[];
    final openedSessions = <Map<String, String?>>[];
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'currentSessionId': sessionId,
            'isInCall': true,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveNavigationSessionSnapshots = (_) async => [];
    debugActiveCurrentSessionSnapshot = (_) async => _FakeSessionSnapshot(
          sessionId,
          <String, dynamic>{
            'status': 'connecting',
            'studentId': userId,
            'tutorId': 'teacher-token-room-url-test',
          },
          FirebaseFirestore.instance.collection('videoSessions').doc(sessionId),
        );
    debugActiveSessionTokenRequest = (requestedSessionId) async {
      tokenSessionIds.add(requestedSessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add({
        'sessionId': videoDocRef.id,
        'roomUrl': roomUrl,
        'roomName': roomName,
        'meetingToken': meetingToken,
      });
    };
    setActiveStudent(userId, currentSessionId: sessionId, isInCall: true);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-token-room-url-before-session-room'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover token room before session room'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(
        find.byKey(const Key('recover-token-room-url-before-session-room')));
    await tester.pump();
    await tester.idle();

    expect(recovered, isTrue);
    expect(tokenSessionIds, [sessionId]);
    expect(openedSessions.single['sessionId'], sessionId);
    expect(openedSessions.single['roomUrl'], 'https://daily.test/$sessionId');
    expect(openedSessions.single['meetingToken'], 'token-$sessionId');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('accepted recovery prefers current session over stale trigger',
      (tester) async {
    const userId = 'student-accepted-prefers-current-test';
    const currentSessionId = 'session-accepted-current-test';
    const staleSessionId = 'session-accepted-stale-trigger-test';
    final openedSessions = <String>[];
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'currentSessionId': currentSessionId,
            'isInCall': true,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveNavigationSessionSnapshots = (_) async => [
          _FakeSessionSnapshot(
            staleSessionId,
            <String, dynamic>{
              'status': 'connecting',
              'studentId': userId,
              'tutorId': 'teacher-stale-trigger-test',
              'dailyRoomUrl': 'https://daily.test/$staleSessionId',
            },
            FirebaseFirestore.instance
                .collection('videoSessions')
                .doc(staleSessionId),
          ),
        ];
    debugActiveCurrentSessionSnapshot = (_) async => _FakeSessionSnapshot(
          currentSessionId,
          <String, dynamic>{
            'status': 'connecting',
            'studentId': userId,
            'tutorId': 'teacher-current-trigger-test',
            'dailyRoomUrl': 'https://daily.test/$currentSessionId',
          },
          FirebaseFirestore.instance
              .collection('videoSessions')
              .doc(currentSessionId),
        );
    debugActiveSessionTokenRequest = (sessionId) async {
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add(videoDocRef.id);
    };
    setActiveStudent(userId,
        currentSessionId: currentSessionId, isInCall: true);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-current-before-stale-trigger'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover current before stale trigger'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester
        .tap(find.byKey(const Key('recover-current-before-stale-trigger')));
    await tester.pump();
    await tester.idle();

    expect(recovered, isTrue);
    expect(openedSessions, [currentSessionId]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('accepted recovery waits when current session lacks token',
      (tester) async {
    const userId = 'student-accepted-current-lacks-token-test';
    const currentSessionId = 'session-accepted-current-lacks-token-test';
    const triggerSessionId = 'session-accepted-trigger-has-token-test';
    final tokenSessionIds = <String>[];
    final openedSessions = <String>[];
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'currentSessionId': currentSessionId,
            'isInCall': true,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveCurrentSessionSnapshot = (_) async => _FakeSessionSnapshot(
          currentSessionId,
          <String, dynamic>{
            'status': 'connecting',
            'studentId': userId,
            'tutorId': 'teacher-current-lacks-token-test',
          },
          FirebaseFirestore.instance
              .collection('videoSessions')
              .doc(currentSessionId),
        );
    debugActiveNavigationSessionSnapshots = (_) async => [
          _FakeSessionSnapshot(
            triggerSessionId,
            <String, dynamic>{
              'status': 'connecting',
              'studentId': userId,
              'tutorId': 'teacher-trigger-has-token-test',
              'dailyRoomUrl': 'https://daily.test/$triggerSessionId',
            },
            FirebaseFirestore.instance
                .collection('videoSessions')
                .doc(triggerSessionId),
          ),
        ];
    debugActiveSessionTokenRequest = (sessionId) async {
      tokenSessionIds.add(sessionId);
      if (sessionId == currentSessionId) {
        return <String, dynamic>{};
      }
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add(videoDocRef.id);
    };
    setActiveStudent(userId,
        currentSessionId: currentSessionId, isInCall: true);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-wait-current-lacks-token'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover wait current lacks token'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(find.byKey(const Key('recover-wait-current-lacks-token')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.idle();

    expect(recovered, isFalse);
    expect(tokenSessionIds, List.filled(5, currentSessionId));
    expect(openedSessions, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('accepted recovery retries current session token before fallback',
      (tester) async {
    const userId = 'student-accepted-current-token-retry-test';
    const currentSessionId = 'session-accepted-current-token-retry-test';
    const triggerSessionId = 'session-accepted-stale-token-retry-test';
    final tokenSessionIds = <String>[];
    final openedSessions = <String>[];
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'currentSessionId': currentSessionId,
            'isInCall': true,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveCurrentSessionSnapshot = (_) async => _FakeSessionSnapshot(
          currentSessionId,
          <String, dynamic>{
            'status': 'connecting',
            'studentId': userId,
            'tutorId': 'teacher-current-token-retry-test',
          },
          FirebaseFirestore.instance
              .collection('videoSessions')
              .doc(currentSessionId),
        );
    debugActiveNavigationSessionSnapshots = (_) async => [
          _FakeSessionSnapshot(
            triggerSessionId,
            <String, dynamic>{
              'status': 'connecting',
              'studentId': userId,
              'studentNavigationTriggered': true,
              'dailyRoomUrl': 'https://daily.test/$triggerSessionId',
            },
            FirebaseFirestore.instance
                .collection('videoSessions')
                .doc(triggerSessionId),
          ),
        ];
    debugActiveSessionTokenRequest = (sessionId) async {
      tokenSessionIds.add(sessionId);
      if (sessionId == currentSessionId && tokenSessionIds.length < 3) {
        return <String, dynamic>{};
      }
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add(videoDocRef.id);
    };
    setActiveStudent(userId,
        currentSessionId: currentSessionId, isInCall: true);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-current-token-retry'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover current token retry'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(find.byKey(const Key('recover-current-token-retry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.idle();

    expect(recovered, isTrue);
    expect(tokenSessionIds, List.filled(3, currentSessionId));
    expect(openedSessions, [currentSessionId]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('accepted recovery sorts trigger fallback by newest navigation',
      (tester) async {
    const userId = 'student-accepted-sorted-trigger-test';
    const newerSessionId = 'session-accepted-newer-trigger-test';
    const legacySessionId = 'session-accepted-legacy-trigger-test';
    final tokenSessionIds = <String>[];
    final openedSessions = <String>[];
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'isInCall': true,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveCurrentSessionSnapshot = (_) async => null;
    debugActiveNavigationSessionSnapshots = (_) async => [
          for (var i = 0; i < 25; i++)
            _FakeSessionSnapshot(
              'session-accepted-older-trigger-$i-test',
              <String, dynamic>{
                'status': 'connecting',
                'studentId': userId,
                'tutorId': 'teacher-older-trigger-$i-test',
                'studentNavigationTriggered': true,
                'dailyRoomUrl':
                    'https://daily.test/session-accepted-older-trigger-$i-test',
                'navigationTimestamp': DateTime(2026, 1, 1, 10, i),
              },
              FirebaseFirestore.instance
                  .collection('videoSessions')
                  .doc('session-accepted-older-trigger-$i-test'),
            ),
          _FakeSessionSnapshot(
            legacySessionId,
            <String, dynamic>{
              'status': 'connecting',
              'studentId': userId,
              'tutorId': 'teacher-legacy-trigger-test',
              'studentNavigationTriggered': true,
              'dailyRoomUrl': 'https://daily.test/$legacySessionId',
              'acceptedAt': DateTime(2026, 1, 1, 12),
            },
            FirebaseFirestore.instance
                .collection('videoSessions')
                .doc(legacySessionId),
          ),
          _FakeSessionSnapshot(
            newerSessionId,
            <String, dynamic>{
              'status': 'connecting',
              'studentId': userId,
              'tutorId': 'teacher-newer-trigger-test',
              'studentNavigationTriggered': true,
              'dailyRoomUrl': 'https://daily.test/$newerSessionId',
              'navigationTimestamp': DateTime(2026, 1, 1, 11),
            },
            FirebaseFirestore.instance
                .collection('videoSessions')
                .doc(newerSessionId),
          ),
        ];
    debugActiveSessionTokenRequest = (sessionId) async {
      tokenSessionIds.add(sessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add(videoDocRef.id);
    };
    setActiveStudent(userId, isInCall: true);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-newest-trigger-first'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover newest trigger first'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(find.byKey(const Key('recover-newest-trigger-first')));
    await tester.pump();
    await tester.idle();

    expect(recovered, isTrue);
    expect(tokenSessionIds, [newerSessionId]);
    expect(openedSessions, [newerSessionId]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('accepted recovery waits when current session read fails',
      (tester) async {
    const userId = 'student-accepted-current-read-fails-test';
    const currentSessionId = 'session-accepted-current-read-fails-test';
    const triggerSessionId = 'session-accepted-trigger-fallback-test';
    final openedSessions = <String>[];
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'currentSessionId': currentSessionId,
            'isInCall': true,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveCurrentSessionSnapshot = (_) async {
      throw StateError('current session unavailable');
    };
    debugActiveNavigationSessionSnapshots = (_) async => [
          _FakeSessionSnapshot(
            triggerSessionId,
            <String, dynamic>{
              'status': 'connecting',
              'studentId': userId,
              'tutorId': 'teacher-trigger-fallback-test',
              'studentNavigationTriggered': true,
              'dailyRoomUrl': 'https://daily.test/$triggerSessionId',
            },
            FirebaseFirestore.instance
                .collection('videoSessions')
                .doc(triggerSessionId),
          ),
        ];
    debugActiveSessionTokenRequest = (sessionId) async {
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add(videoDocRef.id);
    };
    setActiveStudent(userId,
        currentSessionId: currentSessionId, isInCall: true);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-wait-after-current-read-fails'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover wait after current read fails'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester
        .tap(find.byKey(const Key('recover-wait-after-current-read-fails')));
    await tester.pump();
    await tester.idle();

    expect(recovered, isFalse);
    expect(openedSessions, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('accepted recovery skips trigger query when current is valid',
      (tester) async {
    const userId = 'student-accepted-trigger-query-fails-test';
    const currentSessionId = 'session-accepted-current-query-fails-test';
    final tokenSessionIds = <String>[];
    final openedSessions = <String>[];
    var triggerQueryCalled = false;
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'currentSessionId': currentSessionId,
            'isInCall': true,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveCurrentSessionSnapshot = (_) async => _FakeSessionSnapshot(
          currentSessionId,
          <String, dynamic>{
            'status': 'connecting',
            'studentId': userId,
            'tutorId': 'teacher-current-query-fails-test',
            'dailyRoomUrl': 'https://daily.test/$currentSessionId',
          },
          FirebaseFirestore.instance
              .collection('videoSessions')
              .doc(currentSessionId),
        );
    debugActiveNavigationSessionSnapshots = (_) async {
      triggerQueryCalled = true;
      throw StateError('trigger query unavailable');
    };
    debugActiveSessionTokenRequest = (sessionId) async {
      tokenSessionIds.add(sessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add(videoDocRef.id);
    };
    setActiveStudent(userId,
        currentSessionId: currentSessionId, isInCall: true);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-current-after-trigger-query-fails'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover current after trigger query fails'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(
        find.byKey(const Key('recover-current-after-trigger-query-fails')));
    await tester.pump();
    await tester.idle();

    expect(recovered, isTrue);
    expect(tokenSessionIds, [currentSessionId]);
    expect(openedSessions, [currentSessionId]);
    expect(triggerQueryCalled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('accepted recovery skips nonparticipant current session',
      (tester) async {
    const userId = 'student-accepted-skip-nonparticipant-test';
    const currentSessionId = 'session-accepted-nonparticipant-current-test';
    const triggerSessionId = 'session-accepted-participant-trigger-test';
    final tokenSessionIds = <String>[];
    final openedSessions = <String>[];
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'currentSessionId': currentSessionId,
            'isInCall': true,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveCurrentSessionSnapshot = (_) async => _FakeSessionSnapshot(
          currentSessionId,
          <String, dynamic>{
            'status': 'connecting',
            'studentId': 'other-student',
            'tutorId': 'other-teacher',
            'dailyRoomUrl': 'https://daily.test/$currentSessionId',
          },
          FirebaseFirestore.instance
              .collection('videoSessions')
              .doc(currentSessionId),
        );
    debugActiveNavigationSessionSnapshots = (_) async => [
          _FakeSessionSnapshot(
            triggerSessionId,
            <String, dynamic>{
              'status': 'connecting',
              'responderId': userId,
              'participantIds': [userId, 'teacher-participant-trigger-test'],
              'tutorNavigationTriggered': true,
              'dailyRoomUrl': 'https://daily.test/$triggerSessionId',
            },
            FirebaseFirestore.instance
                .collection('videoSessions')
                .doc(triggerSessionId),
          ),
        ];
    debugActiveSessionTokenRequest = (sessionId) async {
      tokenSessionIds.add(sessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add(videoDocRef.id);
    };
    setActiveStudent(userId,
        currentSessionId: currentSessionId, isInCall: true);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-skip-nonparticipant-current'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover skip nonparticipant current'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester
        .tap(find.byKey(const Key('recover-skip-nonparticipant-current')));
    await tester.pump();
    await tester.idle();

    expect(recovered, isTrue);
    expect(tokenSessionIds, [triggerSessionId]);
    expect(openedSessions, [triggerSessionId]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('accepted recovery uses neutral fallback without legacy flags',
      (tester) async {
    Future<void> verifyNeutralFallback({
      required String label,
      required String userId,
      required Map<String, dynamic> neutralFields,
      bool includeParticipantIds = true,
    }) async {
      final sessionId = 'session-neutral-fallback-$label-test';
      final tokenSessionIds = <String>[];
      final openedSessions = <String>[];
      debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
            userId,
            const <String, dynamic>{
              'isInCall': true,
            },
            FirebaseFirestore.instance.collection('users').doc(userId),
          );
      debugActiveCurrentSessionSnapshot = (_) async => null;
      debugActiveNavigationSessionSnapshots = (_) async => [
            _FakeSessionSnapshot(
              sessionId,
              <String, dynamic>{
                'status': 'connecting',
                if (includeParticipantIds)
                  'participantIds': [
                    userId,
                    'peer-neutral-fallback-$label-test',
                  ],
                'createdAt': DateTime(2026, 1, 1, 12),
                'dailyRoomUrl': 'https://daily.test/$sessionId',
                ...neutralFields,
              },
              FirebaseFirestore.instance
                  .collection('videoSessions')
                  .doc(sessionId),
            ),
          ];
      debugActiveSessionTokenRequest = (sessionId) async {
        tokenSessionIds.add(sessionId);
        return <String, dynamic>{
          'roomUrl': 'https://daily.test/$sessionId',
          'roomName': 'room-$sessionId',
          'meetingToken': 'token-$sessionId',
        };
      };
      debugActiveSessionNavigator = (
        videoDocRef, {
        roomUrl,
        roomName,
        meetingToken,
      }) {
        openedSessions.add(videoDocRef.id);
      };
      setActiveStudent(userId, isInCall: true);
      bool? recovered;
      final router = GoRouter(
        initialLocation: StudentsDashboardWidget.routePath,
        routes: [
          GoRoute(
            name: StudentsDashboardWidget.routeName,
            path: StudentsDashboardWidget.routePath,
            builder: (context, state) => TextButton(
              key: Key('recover-neutral-fallback-$label'),
              onPressed: () async {
                recovered = await checkActiveSessionAndNavigate(context);
              },
              child: Text('Recover neutral fallback $label'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(_buildDashboardRouterTestApp(router));
      await tester.pump();

      await tester.tap(find.byKey(Key('recover-neutral-fallback-$label')));
      await tester.pump();
      await tester.idle();

      expect(recovered, isTrue);
      expect(tokenSessionIds, [sessionId]);
      expect(openedSessions, [sessionId]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    await verifyNeutralFallback(
      label: 'requester',
      userId: 'student-neutral-requester-fallback-test',
      neutralFields: const <String, dynamic>{
        'requesterId': 'student-neutral-requester-fallback-test',
        'responderId': 'student-neutral-requester-peer-test',
      },
      includeParticipantIds: false,
    );
    await verifyNeutralFallback(
      label: 'current-responder',
      userId: 'student-neutral-current-responder-fallback-test',
      neutralFields: const <String, dynamic>{
        'requesterId': 'student-neutral-current-responder-peer-test',
        'currentResponderId': 'student-neutral-current-responder-fallback-test',
      },
      includeParticipantIds: false,
    );
    await verifyNeutralFallback(
      label: 'responder',
      userId: 'student-neutral-responder-fallback-test',
      neutralFields: const <String, dynamic>{
        'requesterId': 'student-neutral-responder-peer-test',
        'responderId': 'student-neutral-responder-fallback-test',
      },
      includeParticipantIds: false,
    );
    await verifyNeutralFallback(
      label: 'participant-only',
      userId: 'student-neutral-participant-fallback-test',
      neutralFields: const <String, dynamic>{},
    );
  });

  testWidgets('accepted recovery restores requester neutral trigger',
      (tester) async {
    const userId = 'student-accepted-requester-participant-trigger-test';
    const sessionId = 'session-accepted-requester-participant-trigger-test';
    const ambiguousSessionId =
        'session-accepted-ambiguous-participant-trigger-test';
    final tokenSessionIds = <String>[];
    final openedSessions = <String>[];
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'isInCall': true,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveCurrentSessionSnapshot = (_) async => null;
    debugActiveNavigationSessionSnapshots = (_) async => [
          _FakeSessionSnapshot(
            sessionId,
            <String, dynamic>{
              'status': 'connecting',
              'requesterId': userId,
              'responderId': 'teacher-requester-participant-trigger-test',
              'participantIds': [
                userId,
                'teacher-requester-participant-trigger-test',
              ],
              'tutorNavigationTriggered': true,
              'createdAt': DateTime(2026, 1, 1, 12),
              'dailyRoomUrl': 'https://daily.test/$sessionId',
            },
            FirebaseFirestore.instance
                .collection('videoSessions')
                .doc(sessionId),
          ),
          _FakeSessionSnapshot(
            ambiguousSessionId,
            <String, dynamic>{
              'status': 'connecting',
              'participantIds': [
                userId,
                'teacher-ambiguous-participant-trigger-test',
              ],
              'tutorNavigationTriggered': true,
              'createdAt': DateTime(2026, 1, 1, 11),
              'dailyRoomUrl': 'https://daily.test/$ambiguousSessionId',
            },
            FirebaseFirestore.instance
                .collection('videoSessions')
                .doc(ambiguousSessionId),
          ),
        ];
    debugActiveSessionTokenRequest = (sessionId) async {
      tokenSessionIds.add(sessionId);
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {
      openedSessions.add(videoDocRef.id);
    };
    setActiveStudent(userId, isInCall: true);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-requester-participant-tutor-trigger'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover requester participant tutor trigger'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('recover-requester-participant-tutor-trigger')),
    );
    await tester.pump();
    await tester.idle();

    expect(recovered, isTrue);
    expect(tokenSessionIds, [sessionId]);
    expect(openedSessions, [sessionId]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('accepted recovery leaves foreign navigation flag unchanged',
      (tester) async {
    const userId = 'student-accepted-foreign-triggered-flag-test';
    const sessionId = 'session-accepted-foreign-triggered-flag-test';
    final sessionRef = _CapturingDocumentReference(sessionId);
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'currentSessionId': sessionId,
            'isInCall': true,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveNavigationSessionSnapshots = (_) async => [];
    debugActiveCurrentSessionSnapshot = (_) async => _FakeSessionSnapshot(
          sessionId,
          <String, dynamic>{
            'status': 'connecting',
            'studentId': userId,
            'tutorId': 'teacher-foreign-triggered-flag-test',
            'tutorNavigationTriggered': true,
            'studentNavigationTriggered': false,
          },
          sessionRef,
        );
    debugActiveSessionTokenRequest = (sessionId) async => <String, dynamic>{
          'roomUrl': 'https://daily.test/$sessionId',
          'roomName': 'room-$sessionId',
          'meetingToken': 'token-$sessionId',
        };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {};
    setActiveStudent(userId, currentSessionId: sessionId, isInCall: true);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-foreign-triggered-flag'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover foreign triggered flag'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(find.byKey(const Key('recover-foreign-triggered-flag')));
    await tester.pump();
    await tester.idle();

    expect(recovered, isTrue);
    expect(sessionRef.updates, hasLength(1));
    expect(sessionRef.updates.single['studentNavigationTriggered'], isFalse);
    expect(
      sessionRef.updates.single.containsKey('tutorNavigationTriggered'),
      isFalse,
    );
    expect(sessionRef.updates.single['navigationCompletedAt'], isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('accepted recovery clears neutral responder navigation flag',
      (tester) async {
    const userId = 'teacher-accepted-clear-neutral-flag-test';
    const sessionId = 'session-accepted-clear-neutral-flag-test';
    final sessionRef = _CapturingDocumentReference(sessionId);
    debugActiveSessionUserSnapshot = (_) async => _FakeSessionSnapshot(
          userId,
          const <String, dynamic>{
            'currentSessionId': sessionId,
            'isInCall': true,
          },
          FirebaseFirestore.instance.collection('users').doc(userId),
        );
    debugActiveNavigationSessionSnapshots = (_) async => [];
    debugActiveCurrentSessionSnapshot = (_) async => _FakeSessionSnapshot(
          sessionId,
          <String, dynamic>{
            'status': 'connecting',
            'requesterId': 'student-neutral-flag-test',
            'responderId': userId,
            'participantIds': ['student-neutral-flag-test', userId],
            'tutorNavigationTriggered': false,
            'studentNavigationTriggered': false,
          },
          sessionRef,
        );
    debugActiveSessionTokenRequest = (sessionId) async => <String, dynamic>{
          'roomUrl': 'https://daily.test/$sessionId',
          'roomName': 'room-$sessionId',
          'meetingToken': 'token-$sessionId',
        };
    debugActiveSessionNavigator = (
      videoDocRef, {
      roomUrl,
      roomName,
      meetingToken,
    }) {};
    setActiveStudent(userId, currentSessionId: sessionId, isInCall: true);
    bool? recovered;
    final router = GoRouter(
      initialLocation: StudentsDashboardWidget.routePath,
      routes: [
        GoRoute(
          name: StudentsDashboardWidget.routeName,
          path: StudentsDashboardWidget.routePath,
          builder: (context, state) => TextButton(
            key: const Key('recover-clear-neutral-flag'),
            onPressed: () async {
              recovered = await checkActiveSessionAndNavigate(context);
            },
            child: const Text('Recover clear neutral flag'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildDashboardRouterTestApp(router));
    await tester.pump();

    await tester.tap(find.byKey(const Key('recover-clear-neutral-flag')));
    await tester.pump();
    await tester.idle();

    expect(recovered, isTrue);
    expect(sessionRef.updates, hasLength(1));
    expect(sessionRef.updates.single['tutorNavigationTriggered'], isFalse);
    expect(
      sessionRef.updates.single.containsKey('studentNavigationTriggered'),
      isFalse,
    );
    expect(sessionRef.updates.single['navigationCompletedAt'], isNotNull);

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
    final startSearchButton =
        find.widgetWithText(StudentStartSearchButton, 'Начать поиск');
    expect(startSearchButton, findsOneWidget);
    expect(startSearchButton.hitTestable(), findsOneWidget);
    expect(
      tester.widget<StudentStartSearchButton>(startSearchButton).isActive,
      isFalse,
    );
    expect(find.text('Остановить поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('Соединяем'), findsNothing);
    expect(find.text('Не удалось начать поиск'), findsNothing);

    await tester.tap(
      startSearchButton,
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
    final startPayloads = <Map<String, dynamic>>[];
    final stoppedSessions = <String?>[];
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
        StudentsDashboardWidget(
          initialSearchState: StudentDashboardSearchState.connecting,
          startSearchRequest: (payload) async {
            startPayloads.add(Map<String, dynamic>.from(payload));
            return <String, dynamic>{'requestId': 'request-unexpected-start'};
          },
          stopSearchRequest: (activeSessionId) async {
            stoppedSessions.add(activeSessionId);
          },
        ),
      ),
    );
    await tester.pump();

    expect(startPayloads, isEmpty);
    final stopSearchButton =
        find.widgetWithText(StudentStartSearchButton, 'Остановить поиск');
    expect(stopSearchButton, findsOneWidget);
    expect(stopSearchButton.hitTestable(), findsOneWidget);
    expect(
      tester.widget<StudentStartSearchButton>(stopSearchButton).isActive,
      isTrue,
    );
    final connectingStatusText = find.text('Соединяем');
    expect(connectingStatusText, findsOneWidget);
    expect(connectingStatusText.hitTestable(), findsOneWidget);
    expect(find.text('Начать поиск'), findsNothing);
    expect(find.text('Ищем собеседника'), findsNothing);
    expect(find.text('Пока никого не нашли'), findsNothing);
    expect(find.text('Не удалось начать поиск'), findsNothing);
    expect(find.text('считаем людей рядом'), findsNothing);
    expect(find.textContaining('рядом с вами'), findsNothing);

    await tester.tap(stopSearchButton);
    await tester.pump();

    expect(startPayloads, isEmpty);
    expect(stoppedSessions, <String?>[null]);
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

  testWidgets('student-student open apps flow connects foreground responder',
      (tester) async {
    StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation = false;
    final requesterSessionController = StreamController<VideoSessionsRecord?>();
    final responderSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(requesterSessionController.close);
    addTearDown(responderSessionController.close);
    const sessionId = 'session-student-student-open-apps-test';
    const requesterId = 'student-open-apps-requester-test';
    const responderId = 'student-open-apps-responder-test';
    final acceptedSessions = <Map<String, String>>[];
    final tokenRequests = <Map<String, String>>[];
    final openedSessions = <Map<String, String?>>[];
    StudentsDashboardWidget.debugAcceptCallRequest = (sessionId) async {
      acceptedSessions.add({
        'sessionId': sessionId,
        'userId': currentUserUid,
      });
      return <String, dynamic>{
        'status': 'connected',
        'sessionId': sessionId,
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'token-$sessionId',
      };
    };
    StudentsDashboardWidget.debugGetSessionTokensRequest = (sessionId) async {
      tokenRequests.add({
        'sessionId': sessionId,
        'userId': currentUserUid,
      });
      return <String, dynamic>{
        'roomUrl': 'https://daily.test/$sessionId',
        'roomName': 'room-$sessionId',
        'meetingToken': 'requester-token-$sessionId',
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
        'userId': currentUserUid,
        'roomUrl': roomUrl,
        'meetingToken': meetingToken,
        'roomName': roomName,
      });
    };

    setActiveStudent(requesterId, currentSessionId: sessionId);
    await tester.pumpWidget(
      _buildDashboardTestApp(
        Column(
          children: [
            Expanded(
              child: StudentsDashboardWidget(
                activeSessionStream: requesterSessionController.stream,
              ),
            ),
            Expanded(
              child: StudentsDashboardWidget(
                activeSessionStream: responderSessionController.stream,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    requesterSessionController.add(
      sessionFixture(
        sessionId,
        'pending_confirmation',
        requesterId: requesterId,
        responderId: responderId,
        participantIds: [requesterId, responderId],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Соединяем'), findsOneWidget);
    expect(acceptedSessions, isEmpty);
    expect(tokenRequests, isEmpty);
    expect(openedSessions, isEmpty);

    setActiveStudent(responderId, currentSessionId: sessionId);
    responderSessionController.add(
      sessionFixture(
        sessionId,
        'pending_confirmation',
        requesterId: requesterId,
        responderId: responderId,
        participantIds: [requesterId, responderId],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(acceptedSessions, [
      {'sessionId': sessionId, 'userId': responderId},
    ]);
    expect(tokenRequests, isEmpty);
    expect(openedSessions, hasLength(1));
    expect(openedSessions.first['sessionId'], sessionId);
    expect(openedSessions.first['userId'], responderId);
    expect(openedSessions.first['roomUrl'], 'https://daily.test/$sessionId');
    expect(openedSessions.first['meetingToken'], 'token-$sessionId');
    expect(openedSessions.first['roomName'], 'room-$sessionId');

    responderSessionController.add(
      sessionFixture(
        sessionId,
        'pending_confirmation',
        requesterId: requesterId,
        responderId: responderId,
        participantIds: [requesterId, responderId],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(acceptedSessions, [
      {'sessionId': sessionId, 'userId': responderId},
    ]);
    expect(openedSessions, hasLength(1));

    setActiveStudent(requesterId, currentSessionId: sessionId);
    requesterSessionController.add(
      sessionFixture(
        sessionId,
        'connected',
        requesterId: requesterId,
        responderId: responderId,
        participantIds: [requesterId, responderId],
        dailyRoomUrl: 'https://stale-daily.test/$sessionId',
        dailyRoomName: 'stale-room-$sessionId',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(acceptedSessions, [
      {'sessionId': sessionId, 'userId': responderId},
    ]);
    expect(tokenRequests, [
      {'sessionId': sessionId, 'userId': requesterId},
    ]);
    expect(openedSessions, hasLength(2));
    expect(openedSessions.last['sessionId'], sessionId);
    expect(openedSessions.last['userId'], requesterId);
    expect(
      openedSessions.last['roomUrl'],
      'https://daily.test/$sessionId',
    );
    expect(
      openedSessions.last['meetingToken'],
      'requester-token-$sessionId',
    );
    expect(openedSessions.last['roomName'], 'room-$sessionId');

    requesterSessionController.add(
      sessionFixture(
        sessionId,
        'connected',
        requesterId: requesterId,
        responderId: responderId,
        participantIds: [requesterId, responderId],
        dailyRoomUrl: 'https://stale-daily.test/$sessionId',
        dailyRoomName: 'stale-room-$sessionId',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tokenRequests, [
      {'sessionId': sessionId, 'userId': requesterId},
    ]);
    expect(openedSessions, hasLength(2));

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

  testWidgets('foreground connected session routes to video call',
      (tester) async {
    StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation = false;
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    const sessionId = 'session-foreground-connected-route-test';
    const requesterId = 'student-foreground-connected-requester-test';
    const responderId = 'student-foreground-connected-responder-test';
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
        'connected',
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

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('foreground active session routes to video call', (tester) async {
    StudentsDashboardWidget.debugDisableAutoOpenSessionNavigation = false;
    final activeSessionController = StreamController<VideoSessionsRecord?>();
    addTearDown(activeSessionController.close);
    const sessionId = 'session-foreground-active-route-test';
    const requesterId = 'student-foreground-active-requester-test';
    const responderId = 'student-foreground-active-responder-test';
    final openedSessions = <Map<String, String?>>[];
    StudentsDashboardWidget.debugGetSessionTokensRequest = (sessionId) async {
      return <String, dynamic>{
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
        'active',
        requesterId: requesterId,
        responderId: responderId,
        dailyRoomUrl: 'https://daily.test/$sessionId',
        dailyRoomName: 'room-$sessionId',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(openedSessions, hasLength(1));
    expect(openedSessions.single['sessionId'], sessionId);
    expect(openedSessions.single['roomUrl'], 'https://daily.test/$sessionId');
    expect(openedSessions.single['meetingToken'], 'token-$sessionId');
    expect(openedSessions.single['roomName'], 'room-$sessionId');

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

  for (final deniedPermissionScenario in <String, int>{
    'camera permission denied': Permission.camera.value,
    'microphone permission denied': Permission.microphone.value,
  }.entries) {
    testWidgets(
        'student dashboard does not start search when '
        '${deniedPermissionScenario.key}', (tester) async {
      final startPayloads = <Map<String, dynamic>>[];
      _permissionStatusByPermission[deniedPermissionScenario.value] =
          _permissionDenied;
      setActiveStudent(
        'student-${deniedPermissionScenario.value}-permission-denied-test',
      );

      await tester.pumpWidget(
        _buildDashboardTestApp(
          StudentsDashboardWidget(
            startSearchRequest: (payload) async {
              startPayloads.add(Map<String, dynamic>.from(payload));
              return <String, dynamic>{
                'requestId': 'request-unexpected-start',
              };
            },
          ),
        ),
      );
      await tester.pump();

      final startSearchButton =
          find.widgetWithText(StudentStartSearchButton, 'Начать поиск');
      expect(startSearchButton, findsOneWidget);

      await tester.tap(startSearchButton);
      await tester.pump();

      expect(find.text('Разрешите камеру и микрофон'), findsOneWidget);
      expect(startPayloads, isEmpty);
      expect(startSearchButton, findsOneWidget);
      expect(
        tester.widget<StudentStartSearchButton>(startSearchButton).isActive,
        isFalse,
      );
      expect(find.text('Остановить поиск'), findsNothing);
      expect(find.text('Ищем собеседника'), findsNothing);
      expect(find.text('Соединяем'), findsNothing);
      expect(_checkPermissionStatusCallCount, greaterThan(0));

      await tester.pump(const Duration(minutes: 10));
      await tester.pump();

      expect(find.text('Пока никого не нашли'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

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

// ignore: subtype_of_sealed_class
class _FakeSessionSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  const _FakeSessionSnapshot(this.id, this._data, [this._reference]);

  @override
  final String id;

  final Map<String, dynamic> _data;
  final DocumentReference<Map<String, dynamic>>? _reference;

  @override
  bool get exists => true;

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  DocumentReference<Map<String, dynamic>> get reference =>
      _reference ?? (throw UnimplementedError());

  @override
  Map<String, dynamic> data() => _data;

  @override
  Object? get(Object field) => field is String ? _data[field] : null;

  @override
  Object? operator [](Object field) => get(field);
}

// ignore: subtype_of_sealed_class
class _CapturingDocumentReference
    implements DocumentReference<Map<String, dynamic>> {
  _CapturingDocumentReference(this.id);

  @override
  final String id;

  final updates = <Map<Object, Object?>>[];

  @override
  String get path => 'videoSessions/$id';

  @override
  Future<void> update(Map<Object, Object?> data) async {
    updates.add(Map<Object, Object?>.from(data));
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      throw UnimplementedError();

  @override
  Future<void> delete() => throw UnimplementedError();

  @override
  FirebaseFirestore get firestore => throw UnimplementedError();

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      throw UnimplementedError();

  @override
  CollectionReference<Map<String, dynamic>> get parent =>
      throw UnimplementedError();

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) =>
      throw UnimplementedError();

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) =>
      throw UnimplementedError();

  @override
  DocumentReference<R> withConverter<R>({
    required FromFirestore<R> fromFirestore,
    required ToFirestore<R> toFirestore,
  }) =>
      throw UnimplementedError();
}
