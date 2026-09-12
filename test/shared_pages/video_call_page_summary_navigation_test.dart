import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';
import 'package:small_talk/shared_pages/call_summary/call_summary_widget.dart';
import 'package:small_talk/shared_pages/video_call_page/video_call_page_widget.dart';

Widget _buildRouterTestApp(GoRouter router) {
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
    required this.userId,
  });

  final bool isLoggedIn;
  final String userId;

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
    currentUser = _TestAuthUser(
      isLoggedIn: true,
      userId: 'student-summary-nav-test',
    );
    currentUserDocument = UsersRecord.getDocumentFromData(
      {
        'role': 'student',
        'display_name': 'Student',
      },
      UsersRecord.collection.doc('student-summary-nav-test'),
    );
    VideoCallPageWidget.debugEnsureMediaPermissions = () async => true;
    VideoCallPageWidget.debugEndCurrentCall = (_) async {};
    VideoCallPageModel.debugSessionStream = null;
  });

  tearDown(() {
    currentUser = null;
    currentUserDocument = null;
    VideoCallPageWidget.debugEnsureMediaPermissions = null;
    VideoCallPageWidget.debugEndCurrentCall = null;
    VideoCallPageModel.debugSessionStream = null;
  });

  Future<
      ({
        GoRouter router,
        StreamController<VideoSessionsRecord> sessionController,
        List<String> endedCallCleanupSessionIds,
      })> pumpVideoCallRoute(WidgetTester tester, String sessionId) async {
    final sessionRef = VideoSessionsRecord.collection.doc(sessionId);
    final sessionController = StreamController<VideoSessionsRecord>.broadcast();
    final endedCallCleanupSessionIds = <String>[];
    addTearDown(sessionController.close);

    VideoCallPageWidget.debugEndCurrentCall = (sessionId) async {
      endedCallCleanupSessionIds.add(sessionId);
    };
    VideoCallPageModel.debugSessionStream = (ref) {
      expect(ref.path, sessionRef.path);
      return sessionController.stream;
    };

    final router = GoRouter(
      initialLocation: VideoCallPageWidget.routePath,
      routes: [
        GoRoute(
          name: VideoCallPageWidget.routeName,
          path: VideoCallPageWidget.routePath,
          builder: (context, state) => VideoCallPageWidget(
            videoDocRef: sessionRef,
          ),
        ),
        GoRoute(
          name: CallSummaryWidget.routeName,
          path: CallSummaryWidget.routePath,
          builder: (context, state) => const SizedBox(
            key: Key('call-summary-route'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_buildRouterTestApp(router));
    await tester.pump();

    return (
      router: router,
      sessionController: sessionController,
      endedCallCleanupSessionIds: endedCallCleanupSessionIds,
    );
  }

  testWidgets('navigates to call summary when backend marks call ended',
      (tester) async {
    const sessionId = 'session-summary-nav-test';
    const peerId = 'peer-summary-nav-test';
    final harness = await pumpVideoCallRoute(tester, sessionId);
    final sessionRef = VideoSessionsRecord.collection.doc(sessionId);

    harness.sessionController.add(
      VideoSessionsRecord.getDocumentFromData(
        {
          'status': 'ended',
          'studentId': currentUserUid,
          'tutorId': peerId,
          'participantIds': [currentUserUid, peerId],
          'language': 'en',
          'duration': 42,
        },
        sessionRef,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('call-summary-route')), findsOneWidget);
    expect(harness.router.getCurrentLocation(),
        startsWith(CallSummaryWidget.routePath));
    expect(harness.router.getCurrentLocation(), contains('userRef=$peerId'));
    expect(
        harness.router.getCurrentLocation(), contains('sessionID=$sessionId'));
    expect(harness.router.getCurrentLocation(), contains('lang=en'));
    expect(harness.router.getCurrentLocation(), contains('dur=42'));
    expect(harness.endedCallCleanupSessionIds, [sessionId]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('does not open call summary for pre-active cancelled sessions',
      (tester) async {
    const sessionId = 'session-cancelled-no-summary-test';
    const peerId = 'peer-cancelled-no-summary-test';
    final harness = await pumpVideoCallRoute(tester, sessionId);
    final sessionRef = VideoSessionsRecord.collection.doc(sessionId);

    harness.sessionController.add(
      VideoSessionsRecord.getDocumentFromData(
        {
          'status': 'cancelled',
          'studentId': currentUserUid,
          'currentResponderId': peerId,
          'participantIds': [currentUserUid, peerId],
          'language': 'en',
          'duration': 0,
        },
        sessionRef,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('call-summary-route')), findsNothing);
    expect(harness.router.getCurrentLocation(), VideoCallPageWidget.routePath);
    expect(harness.endedCallCleanupSessionIds, [sessionId]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'opens call summary for connected expired sessions with neutral fields',
      (tester) async {
    const sessionId = 'session-expired-neutral-summary-test';
    const peerId = 'peer-expired-neutral-summary-test';
    final harness = await pumpVideoCallRoute(tester, sessionId);
    final sessionRef = VideoSessionsRecord.collection.doc(sessionId);

    harness.sessionController.add(
      VideoSessionsRecord.getDocumentFromData(
        {
          'status': 'expired',
          'requesterId': currentUserUid,
          'currentResponderId': peerId,
          'language': 'en',
          'duration': 0,
          'sessionMetadata': {
            'callConnectedAt':
                DateTime.now().subtract(const Duration(seconds: 12)),
          },
        },
        sessionRef,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('call-summary-route')), findsOneWidget);
    expect(
      harness.router.getCurrentLocation(),
      startsWith(CallSummaryWidget.routePath),
    );
    expect(harness.router.getCurrentLocation(), contains('userRef=$peerId'));
    expect(
        harness.router.getCurrentLocation(), contains('sessionID=$sessionId'));
    expect(harness.endedCallCleanupSessionIds, [sessionId]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('does not open summary for unverified expired call evidence',
      (tester) async {
    final cases = <({String name, Map<String, dynamic> data})>[
      (
        name: 'duration-only',
        data: {'duration': 12},
      ),
      (
        name: 'startedAt-only',
        data: {
          'startedAt': DateTime.now().subtract(const Duration(seconds: 12)),
        },
      ),
      (
        name: 'client-signal-only',
        data: {
          'sessionMetadata': {
            'connectedParticipantSignalsComplete': true,
          },
        },
      ),
    ];

    for (final testCase in cases) {
      final sessionId = 'session-expired-${testCase.name}-test';
      final peerId = 'peer-expired-${testCase.name}-test';
      final harness = await pumpVideoCallRoute(tester, sessionId);
      final sessionRef = VideoSessionsRecord.collection.doc(sessionId);

      harness.sessionController.add(
        VideoSessionsRecord.getDocumentFromData(
          {
            'status': 'expired',
            'requesterId': currentUserUid,
            'currentResponderId': peerId,
            'language': 'en',
            ...testCase.data,
          },
          sessionRef,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('call-summary-route')), findsNothing);
      expect(
          harness.router.getCurrentLocation(), VideoCallPageWidget.routePath);
      expect(harness.endedCallCleanupSessionIds, [sessionId]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('opens summary when connected metadata arrives after terminal',
      (tester) async {
    const sessionId = 'session-late-connected-metadata-test';
    const peerId = 'peer-late-connected-metadata-test';
    final harness = await pumpVideoCallRoute(tester, sessionId);
    final sessionRef = VideoSessionsRecord.collection.doc(sessionId);

    harness.sessionController.add(
      VideoSessionsRecord.getDocumentFromData(
        {
          'status': 'expired',
          'requesterId': currentUserUid,
          'currentResponderId': peerId,
          'language': 'en',
        },
        sessionRef,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('call-summary-route')), findsNothing);
    expect(harness.endedCallCleanupSessionIds, [sessionId]);

    harness.sessionController.add(
      VideoSessionsRecord.getDocumentFromData(
        {
          'status': 'expired',
          'requesterId': currentUserUid,
          'currentResponderId': peerId,
          'language': 'en',
          'sessionMetadata': {
            'callConnectedAt':
                DateTime.now().subtract(const Duration(seconds: 8)),
          },
        },
        sessionRef,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('call-summary-route')), findsOneWidget);
    expect(harness.router.getCurrentLocation(), contains('userRef=$peerId'));
    expect(harness.endedCallCleanupSessionIds, [sessionId]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('skips empty connected metadata before valid connected metadata',
      (tester) async {
    const sessionId = 'session-connected-metadata-fallback-test';
    const peerId = 'peer-connected-metadata-fallback-test';
    final harness = await pumpVideoCallRoute(tester, sessionId);
    final sessionRef = VideoSessionsRecord.collection.doc(sessionId);
    final connectedAt = DateTime.now().subtract(const Duration(seconds: 10));

    harness.sessionController.add(
      VideoSessionsRecord.getDocumentFromData(
        {
          'status': 'expired',
          'requesterId': currentUserUid,
          'currentResponderId': peerId,
          'language': 'en',
          'sessionMetadata': {
            'callConnectedAt': '',
            'callConnectedAtTimestamp': connectedAt,
          },
        },
        sessionRef,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('call-summary-route')), findsOneWidget);
    expect(harness.router.getCurrentLocation(), contains('userRef=$peerId'));
    final duration = int.parse(
      Uri.parse(harness.router.getCurrentLocation()).queryParameters['dur']!,
    );
    expect(duration, greaterThanOrEqualTo(10));
    expect(harness.endedCallCleanupSessionIds, [sessionId]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('opens summary for numeric connected timestamp millis',
      (tester) async {
    const sessionId = 'session-connected-millis-test';
    const peerId = 'peer-connected-millis-test';
    final harness = await pumpVideoCallRoute(tester, sessionId);
    final sessionRef = VideoSessionsRecord.collection.doc(sessionId);
    final connectedAtMillis = DateTime.now()
        .subtract(const Duration(seconds: 14))
        .millisecondsSinceEpoch;

    harness.sessionController.add(
      VideoSessionsRecord.getDocumentFromData(
        {
          'status': 'cancelled',
          'requesterId': currentUserUid,
          'responderId': peerId,
          'language': 'en',
          'sessionMetadata': {
            'callConnectedAtTimestamp': connectedAtMillis,
          },
        },
        sessionRef,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('call-summary-route')), findsOneWidget);
    expect(harness.router.getCurrentLocation(), contains('userRef=$peerId'));
    final duration = int.parse(
      Uri.parse(harness.router.getCurrentLocation()).queryParameters['dur']!,
    );
    expect(duration, greaterThanOrEqualTo(14));
    expect(harness.endedCallCleanupSessionIds, [sessionId]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'does not open summary for unparseable connected timestamp string',
      (tester) async {
    const sessionId = 'session-invalid-connected-timestamp-test';
    const peerId = 'peer-invalid-connected-timestamp-test';
    final harness = await pumpVideoCallRoute(tester, sessionId);
    final sessionRef = VideoSessionsRecord.collection.doc(sessionId);

    harness.sessionController.add(
      VideoSessionsRecord.getDocumentFromData(
        {
          'status': 'expired',
          'requesterId': currentUserUid,
          'responderId': peerId,
          'language': 'en',
          'sessionMetadata': {
            'callConnectedAtTimestamp': 'connected',
          },
        },
        sessionRef,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('call-summary-route')), findsNothing);
    expect(harness.router.getCurrentLocation(), VideoCallPageWidget.routePath);
    expect(harness.endedCallCleanupSessionIds, [sessionId]);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
