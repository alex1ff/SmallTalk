import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/base_auth_user_provider.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/components/call_history_card.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/call_details/call_details_widget.dart';
import 'package:small_talk/shared_pages/call_history/call_participant_display_utils.dart';

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

VideoSessionsRecord _session(
  String id,
  Map<String, dynamic> data,
) {
  return VideoSessionsRecord.getDocumentFromData(
    data,
    VideoSessionsRecord.collection.doc(id),
  );
}

Widget _buildRouterApp(
  VideoSessionsRecord session, {
  bool Function()? canOpen,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: CallHistoryCard(
            session: session,
            isTeacher: false,
            canOpen: canOpen,
          ),
        ),
      ),
      GoRoute(
        name: CallDetailsWidget.routeName,
        path: CallDetailsWidget.routePath,
        builder: (context, state) => const Scaffold(
          body: Text('details-opened'),
        ),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    locale: const Locale('en'),
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
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    setupFirebaseCoreMocks();
    await FFLocalizations.initialize();
    await Firebase.initializeApp();
  });

  tearDown(() {
    currentUser = null;
  });

  group('call participant display utils', () {
    test(
        'resolves actual counterpart from participantInfos before stale legacy',
        () {
      final session = _session(
        'participant-info-session',
        {
          'status': 'ended',
          'studentId': 'stale-student',
          'tutorId': 'stale-tutor',
          'requesterId': 'actual-requester',
          'responderId': 'actual-responder',
          'participantInfos': {
            'actual-requester': {
              'displayName': 'Actual requester',
              'photoUrl': 'requester-photo',
            },
            'actual-responder': {
              'displayName': 'Actual responder',
              'photoUrl': 'responder-photo',
            },
          },
          'studentInfo': {'name': 'Stale student', 'photo': 'stale-student'},
          'tutorInfo': {'name': 'Stale tutor', 'photo': 'stale-tutor'},
        },
      );

      final requesterInfo = resolveSessionParticipantDisplayInfo(
        session: session,
        userId: 'actual-requester',
      );
      final responderInfo = resolveSessionParticipantDisplayInfo(
        session: session,
        userId: 'actual-responder',
      );

      expect(requesterInfo.name, 'Actual requester');
      expect(requesterInfo.photoUrl, 'requester-photo');
      expect(responderInfo.name, 'Actual responder');
      expect(responderInfo.photoUrl, 'responder-photo');
    });

    test('falls back through requesterInfo and accepted responder info', () {
      final session = _session(
        'metadata-info-session',
        {
          'status': 'ended',
          'requesterId': 'actual-requester',
          'responderId': 'actual-responder',
          'requesterInfo': {
            'displayName': 'Requester info',
            'photoUrl': 'requester-info-photo',
          },
          'matchContext': {
            'acceptedResponderInfo': {
              'name': 'Accepted responder',
              'photo': 'accepted-responder-photo',
            },
          },
        },
      );

      expect(
        resolveSessionParticipantDisplayInfo(
          session: session,
          userId: 'actual-requester',
        ).name,
        'Requester info',
      );
      expect(
        resolveSessionParticipantDisplayInfo(
          session: session,
          userId: 'actual-responder',
        ).photoUrl,
        'accepted-responder-photo',
      );
    });

    test('ignores stale accepted responder info when responder id differs', () {
      final session = _session(
        'stale-accepted-responder-session',
        {
          'status': 'ended',
          'requesterId': 'actual-requester',
          'responderId': 'actual-responder',
          'matchContext': {
            'acceptedResponderId': 'stale-responder',
            'acceptedResponderInfo': {
              'name': 'Stale responder',
              'photo': 'stale-photo',
            },
          },
        },
      );

      final info = resolveSessionParticipantDisplayInfo(
        session: session,
        userId: 'actual-responder',
      );

      expect(info.name, isEmpty);
      expect(info.photoUrl, isEmpty);
    });

    test('supports legacy-only student and tutor info', () {
      final session = _session(
        'legacy-only-session',
        {
          'status': 'ended',
          'studentId': 'legacy-student',
          'tutorId': 'legacy-tutor',
          'studentInfo': {'name': 'Legacy student', 'photo': 'student-photo'},
          'tutorInfo': {'name': 'Legacy tutor', 'photo': 'tutor-photo'},
        },
      );

      expect(
        resolveSessionParticipantDisplayInfo(
          session: session,
          userId: 'legacy-student',
        ).name,
        'Legacy student',
      );
      expect(
        resolveSessionParticipantDisplayInfo(
          session: session,
          userId: 'legacy-tutor',
        ).photoUrl,
        'tutor-photo',
      );
    });
  });

  testWidgets('call history card opens details for legacy-only session',
      (tester) async {
    currentUser = _TestAuthUser('legacy-student');
    final session = _session(
      'legacy-card-session',
      {
        'status': 'ended',
        'studentId': 'legacy-student',
        'tutorId': 'legacy-tutor',
        'participantIds': ['legacy-student', 'legacy-tutor'],
        'studentInfo': {'name': 'Legacy student', 'photo': ''},
        'tutorInfo': {'name': 'Legacy tutor', 'photo': ''},
        'startedAt': DateTime(2026, 5, 12, 10),
        'endedAt': DateTime(2026, 5, 12, 10, 5),
      },
    );

    await tester.pumpWidget(_buildRouterApp(session));
    await tester.pumpAndSettle();

    expect(find.text('Legacy tutor'), findsOneWidget);

    await tester.tap(find.byType(CallHistoryCard));
    await tester.pumpAndSettle();

    expect(find.text('details-opened'), findsOneWidget);
  });

  testWidgets('call history card honors an owner-boundary navigation guard',
      (tester) async {
    currentUser = _TestAuthUser('user-b');
    final session = _session(
      'stale-owner-card',
      {
        'status': 'ended',
        'studentId': 'user-a',
        'tutorId': 'tutor-a',
        'participantIds': ['user-a', 'tutor-a'],
        'studentInfo': {'name': 'User A', 'photo': ''},
        'tutorInfo': {'name': 'Tutor A', 'photo': ''},
        'startedAt': DateTime(2026, 5, 12, 10),
        'endedAt': DateTime(2026, 5, 12, 10, 5),
      },
    );

    await tester.pumpWidget(
      _buildRouterApp(session, canOpen: () => false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CallHistoryCard));
    await tester.pumpAndSettle();

    expect(find.text('details-opened'), findsNothing);
  });
}
