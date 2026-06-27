import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/flutter_flow/nav/nav.dart';
import 'package:small_talk/services/voip_service.dart';

import 'voip_test_helpers.dart';

void main() {
  late VoIPService service;

  setUp(() {
    appNavigatorKey = GlobalKey<NavigatorState>();
    service = VoIPService();
    service.debugResetInMemoryStateForTesting();
    service.debugCurrentUserIdOverride = 'current-user';
  });

  Future<void> markCallActionsReady() async {
    service.debugSetInitializedForTesting(true);
    await service.debugSetCallActionHandlingReadyForTesting(true);
  }

  group('VoIP accept helpers', () {
    test('assigned responder prefers currentResponderId with legacy fallback',
        () {
      expect(
        voipAssignedResponderIdForSession({
          'currentResponderId': ' student-b ',
          'currentTutorId': 'teacher-a',
        }),
        'student-b',
      );
      expect(
        voipAssignedResponderIdForSession({
          'currentResponderId': ' ',
          'currentTutorId': ' teacher-a ',
        }),
        'teacher-a',
      );
      expect(
        voipAssignedResponderIdForSession({'tutorId': 'teacher-b'}),
        isNull,
      );
    });

    test('incoming session matches only pending assigned responders', () {
      expect(
        voipIncomingSessionMatchesResponder(
          sessionData: {
            'status': 'pending_confirmation',
            'currentResponderId': 'student-b',
          },
          userId: 'student-b',
        ),
        isTrue,
      );
      expect(
        voipIncomingSessionMatchesResponder(
          sessionData: {
            'status': 'searching',
            'currentTutorId': 'teacher-a',
          },
          userId: 'teacher-a',
        ),
        isTrue,
      );
      expect(
        voipIncomingSessionMatchesResponder(
          sessionData: {
            'status': 'connecting',
            'currentResponderId': 'student-b',
          },
          userId: 'student-b',
        ),
        isFalse,
      );
      expect(
        voipIncomingSessionMatchesResponder(
          sessionData: {
            'status': 'pending_confirmation',
            'currentResponderId': 'student-b',
          },
          userId: 'student-c',
        ),
        isFalse,
      );
    });

    test('incoming call extra data preserves backend payload metadata', () {
      final extra = voipIncomingCallExtraDataFromPayload({
        'type': 'incoming_call',
        'sessionId': 'session-a',
        'callerName': 'Ana',
        'callerId': 'student-a',
        'callerPhoto': 'photo',
        'studentName': 'Ana',
        'studentId': 'student-a',
        'studentPhoto': 'student-photo',
        'language': 'en',
        'scenario': 'student_teacher',
        'requesterId': 'student-a',
        'responderId': 'teacher-a',
        'requesterRole': 'student',
        'responderRole': 'native_speaker',
        'navRole': 'tutor',
        'acceptMode': 'responder_accepts',
        'callKitId': 'callkit-a',
        'notificationId': 'notification-a',
        'searchRequestId': 'search-a',
        'expiresAt': '2026-06-21T10:00:45.000Z',
        'roomUrl': '',
        'meetingToken': null,
        'roomName': 'room-a',
        'tokenStrategy': 'accept_call',
        'ignored': 'value',
      });

      expect(extra, {
        'type': 'incoming_call',
        'sessionId': 'session-a',
        'callerName': 'Ana',
        'callerId': 'student-a',
        'callerPhoto': 'photo',
        'studentName': 'Ana',
        'studentId': 'student-a',
        'studentPhoto': 'student-photo',
        'language': 'en',
        'scenario': 'student_teacher',
        'requesterId': 'student-a',
        'responderId': 'teacher-a',
        'requesterRole': 'student',
        'responderRole': 'native_speaker',
        'navRole': 'tutor',
        'acceptMode': 'responder_accepts',
        'callKitId': 'callkit-a',
        'notificationId': 'notification-a',
        'searchRequestId': 'search-a',
        'expiresAt': '2026-06-21T10:00:45.000Z',
        'roomUrl': '',
        'roomName': 'room-a',
        'tokenStrategy': 'accept_call',
      });
      expect(extra.containsKey('meetingToken'), isFalse);
      expect(extra.containsKey('ignored'), isFalse);
    });

    test('callkit extra keeps effective identity over payload identity', () {
      final extra = voipBuildCallKitExtraData(
        sessionId: 'session-effective',
        callerId: 'caller-effective',
        callKitId: 'callkit-effective',
        extraData: {
          'sessionId': 'session-stale',
          'callerId': 'caller-stale',
          'callKitId': 'callkit-stale',
          'roomName': 'room-a',
          'scenario': 'student_teacher',
        },
      );

      expect(extra['sessionId'], 'session-effective');
      expect(extra['callerId'], 'caller-effective');
      expect(extra['callKitId'], 'callkit-effective');
      expect(extra['roomName'], 'room-a');
      expect(extra['scenario'], 'student_teacher');
    });

    test('accept action treats open_session metadata as already accepted', () {
      expect(
        voipAcceptActionFromPayload({
          'acceptMode': 'OPEN_SESSION',
          'tokenStrategy': 'GET_SESSION_TOKENS',
        }),
        VoipAcceptPayloadAction.openSession,
      );
      expect(
        voipAcceptActionFromPayload({
          'tokenStrategy': 'PAYLOAD_ROOM',
        }),
        VoipAcceptPayloadAction.openSession,
      );
      expect(
        voipAcceptActionFromPayload({
          'extra': {
            'roomUrl': 'https://daily.test/room-a',
            'acceptMode': 'responder_accepts',
          },
        }),
        VoipAcceptPayloadAction.openSession,
      );
      expect(
        voipAcceptActionFromPayload({
          'acceptMode': 'responder_accepts',
          'tokenStrategy': 'accept_call',
        }),
        VoipAcceptPayloadAction.acceptCall,
      );
    });

    test('incoming call payload expiry is evaluated from foreground metadata',
        () {
      final now = DateTime.utc(2026, 6, 21, 10, 1);

      expect(
        voipIncomingCallPayloadHasExpired(
          {'expiresAt': '2026-06-21T10:00:45.000Z'},
          now: now,
        ),
        isTrue,
      );
      expect(
        voipIncomingCallPayloadHasExpired(
          {
            'extra': {'expiresAt': '2026-06-21T10:01:45.000Z'},
          },
          now: now,
        ),
        isFalse,
      );
      expect(
        voipIncomingCallPayloadHasExpired({'expiresAt': ''}, now: now),
        isFalse,
      );
      expect(
        voipIncomingCallPayloadHasExpired(
          {'expiresAt': DateTime.utc(2026, 6, 21, 10, 0, 45)},
          now: now,
        ),
        isTrue,
      );
      expect(
        voipIncomingCallPayloadHasExpired(
          {'expiresAt': DateTime.utc(2026, 6, 21, 10, 1, 45)},
          now: now,
        ),
        isFalse,
      );
      expect(
        voipIncomingCallPayloadHasExpired(
          {
            'expiresAt':
                DateTime.utc(2026, 6, 21, 10, 0, 45).millisecondsSinceEpoch
          },
          now: now,
        ),
        isTrue,
      );
      expect(
        voipIncomingCallPayloadHasExpired(
          {
            'expiresAt': DateTime.utc(2026, 6, 21, 10, 0, 45)
                .millisecondsSinceEpoch
                .toString(),
          },
          now: now,
        ),
        isTrue,
      );
      expect(
        voipIncomingCallPayloadHasExpired(
          {'expiresAt': _TimestampLike(DateTime.utc(2026, 6, 21, 10, 0, 45))},
          now: now,
        ),
        isTrue,
      );
    });

    test('active call replay data keeps accepted call metadata', () {
      final acceptedCalls = voipAcceptDataFromActiveCalls([
        {
          'id': '99999999-9999-9999-9999-999999999999',
          'isAccepted': true,
          'extra': {
            'sessionId': 'session-bg',
            'roomName': 'bg-room',
            'tokenStrategy': 'get_session_tokens',
          },
        },
        {
          'id': 'ignored-call',
          'isAccepted': false,
          'extra': {'sessionId': 'session-ignored'},
        },
      ]);

      expect(acceptedCalls, hasLength(1));
      expect(
          acceptedCalls.single['id'], '99999999-9999-9999-9999-999999999999');
      expect(acceptedCalls.single['sessionId'], 'session-bg');
      expect(acceptedCalls.single['extra'], {
        'sessionId': 'session-bg',
        'roomName': 'bg-room',
        'tokenStrategy': 'get_session_tokens',
        'callKitId': '99999999-9999-9999-9999-999999999999',
      });

      final singleMapAcceptedCall = voipAcceptDataFromActiveCalls({
        'id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'isAccepted': true,
        'extra': {'sessionId': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'},
      }).single;
      expect(singleMapAcceptedCall['sessionId'],
          'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

      expect(
        voipAcceptDataFromActiveCalls(
          '[{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","isAccepted":"true","extra":{"sessionId":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}}]',
        ).single['id'],
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      );

      final serializedAcceptedCall = voipAcceptDataFromActiveCalls(
        '[{"id":"cccccccc-cccc-cccc-cccc-cccccccccccc","accepted":1,"extra":"{\\"sessionId\\":\\"cccccccc-cccc-cccc-cccc-cccccccccccc\\",\\"roomName\\":\\"closed-room\\",\\"tokenStrategy\\":\\"get_session_tokens\\"}"}]',
      ).single;
      expect(serializedAcceptedCall['sessionId'],
          'cccccccc-cccc-cccc-cccc-cccccccccccc');
      expect(serializedAcceptedCall['extra'], {
        'sessionId': 'cccccccc-cccc-cccc-cccc-cccccccccccc',
        'roomName': 'closed-room',
        'tokenStrategy': 'get_session_tokens',
        'callKitId': 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      });

      final conflictingAcceptedCall = voipAcceptDataFromActiveCalls([
        {
          'id': 'dddddddd-dddd-dddd-dddd-dddddddddddd',
          'isAccepted': false,
          'accepted': 1,
          'extra': {'sessionId': 'dddddddd-dddd-dddd-dddd-dddddddddddd'},
        },
      ]).single;
      expect(conflictingAcceptedCall['sessionId'],
          'dddddddd-dddd-dddd-dddd-dddddddddddd');

      final stringAcceptedCalls = voipAcceptDataFromActiveCalls([
        {
          'id': 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
          'accepted': '1',
          'extra': {'sessionId': 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'},
        },
        {
          'id': 'ffffffff-ffff-ffff-ffff-ffffffffffff',
          'accepted': 'yes',
          'extra': {'sessionId': 'ffffffff-ffff-ffff-ffff-ffffffffffff'},
        },
      ]);
      expect(
        stringAcceptedCalls.map((call) => call['sessionId']),
        containsAll([
          'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
          'ffffffff-ffff-ffff-ffff-ffffffffffff',
        ]),
      );
      expect(voipAcceptDataFromActiveCalls('not-json'), isEmpty);
      expect(
        voipAcceptDataFromActiveCalls([
          {
            'id': '11111111-1111-1111-1111-111111111111',
            'isAccepted': true,
            'extra': '{not-json',
          },
        ]),
        isEmpty,
      );
    });

    test('closed app navigation retry window covers cold startup', () {
      final retryWindow = Duration(
        milliseconds:
            service.debugPendingNavigationRetryDelayForTesting.inMilliseconds *
                service.debugPendingNavigationMaxAttemptsForTesting,
      );

      expect(service.debugPendingNavigationRetryDelayForTesting,
          const Duration(milliseconds: 100));
      expect(retryWindow, greaterThanOrEqualTo(const Duration(minutes: 1)));
    });

    testWidgets('closed app accept navigates when navigator appears later',
        (tester) async {
      const sessionId = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
      var acceptCallInvoked = false;

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugPrefetchSessionTokensOverride = (_) async {};
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await service.debugHandleCallAcceptForTesting({
        'sessionId': sessionId,
        'extra':
            '{"acceptMode":"open_session","tokenStrategy":"get_session_tokens","roomName":"closed-room"}',
      });

      expect(acceptCallInvoked, isFalse);
      expect(service.hasPendingNavigation(), isTrue);

      final router = GoRouter(
        navigatorKey: appNavigatorKey,
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SizedBox(key: Key('home-route')),
          ),
          GoRoute(
            path: '/videoCallPage',
            builder: (context, state) =>
                const SizedBox(key: Key('video-call-route')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(service.debugPendingNavigationRetryDelayForTesting);
      await tester.pumpAndSettle();

      expect(router.getCurrentLocation(), startsWith('/videoCallPage'));
      expect(router.getCurrentLocation(), contains('videoDocRef=$sessionId'));
      expect(router.getCurrentLocation(), contains('roomName=closed-room'));
      expect(find.byKey(const Key('video-call-route')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'targeted CallKit accept waits for auth and later navigator recovery',
        (tester) async {
      const sessionId = 'auth-late-accept-session';
      var acceptCallInvoked = false;
      final prefetched = Completer<String>();

      service.debugCurrentUserIdOverride = null;
      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugPrefetchSessionTokensOverride = (sessionId) async {
        if (!prefetched.isCompleted) {
          prefetched.complete(sessionId);
        }
      };
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await service.debugHandleCallKitAcceptEventForTesting({
        'sessionId': sessionId,
        'recipientId': 'current-user',
        'extra': {
          'acceptMode': 'open_session',
          'tokenStrategy': 'get_session_tokens',
          'roomName': 'auth-late-room',
        },
      });

      expect(service.debugPendingCallKitActionCountForTesting, 1);
      expect(acceptCallInvoked, isFalse);
      expect(service.hasPendingNavigation(), isFalse);

      service.debugCurrentUserIdOverride = 'current-user';
      service.debugSetInitializedForTesting(true);
      await service.debugSetCallActionHandlingReadyForTesting(true);

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(
        await prefetched.future.timeout(const Duration(seconds: 1)),
        sessionId,
      );
      expect(acceptCallInvoked, isFalse);
      expect(service.hasPendingNavigation(), isTrue);

      final router = GoRouter(
        navigatorKey: appNavigatorKey,
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SizedBox(key: Key('home-route')),
          ),
          GoRoute(
            path: '/videoCallPage',
            builder: (context, state) =>
                const SizedBox(key: Key('video-call-route')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(service.debugPendingNavigationRetryDelayForTesting);
      await tester.pumpAndSettle();

      final targetUri = Uri.parse(router.getCurrentLocation());
      expect(targetUri.path, '/videoCallPage');
      expect(targetUri.queryParameters['videoDocRef'], sessionId);
      expect(targetUri.queryParameters['roomName'], 'auth-late-room');
      expect(find.byKey(const Key('video-call-route')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'closed app accepted replay waits for auth and later navigator recovery',
        (tester) async {
      const sessionId = 'closed-auth-late-accept-session';
      var acceptCallInvoked = false;
      final prefetched = Completer<String>();

      service.debugCurrentUserIdOverride = null;
      service.debugActiveCallsOverride = () async => jsonEncode([
            {
              'id': deterministicCallKitIdForTest(sessionId),
              'accepted': 1,
              'extra': jsonEncode({
                'sessionId': sessionId,
                'recipientId': 'current-user',
                'tokenStrategy': 'get_session_tokens',
                'roomName': 'closed-auth-room',
              }),
            },
          ]);
      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugPrefetchSessionTokensOverride = (sessionId) async {
        if (!prefetched.isCompleted) {
          prefetched.complete(sessionId);
        }
      };
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await service.recoverBackgroundAcceptedCalls();

      expect(service.debugPendingCallKitActionCountForTesting, 1);
      expect(acceptCallInvoked, isFalse);
      expect(service.hasPendingNavigation(), isFalse);

      service.debugCurrentUserIdOverride = 'current-user';
      service.debugSetInitializedForTesting(true);
      await service.debugSetCallActionHandlingReadyForTesting(true);

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(
        await prefetched.future.timeout(const Duration(seconds: 1)),
        sessionId,
      );
      expect(acceptCallInvoked, isFalse);
      expect(service.hasPendingNavigation(), isTrue);

      final router = GoRouter(
        navigatorKey: appNavigatorKey,
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SizedBox(key: Key('home-route')),
          ),
          GoRoute(
            path: '/videoCallPage',
            builder: (context, state) =>
                const SizedBox(key: Key('video-call-route')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(service.debugPendingNavigationRetryDelayForTesting);
      await tester.pumpAndSettle();

      final targetUri = Uri.parse(router.getCurrentLocation());
      expect(targetUri.path, '/videoCallPage');
      expect(targetUri.queryParameters['videoDocRef'], sessionId);
      expect(targetUri.queryParameters['roomName'], 'closed-auth-room');
      expect(find.byKey(const Key('video-call-route')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('accept replaces stale video call route with accepted session',
        (tester) async {
      const staleSessionId = 'stale-video-session';
      const acceptedSessionId = 'accepted-video-session';
      var acceptCallInvoked = false;

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugPrefetchSessionTokensOverride = (_) async {};
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      final router = GoRouter(
        navigatorKey: appNavigatorKey,
        initialLocation: '/videoCallPage?videoDocRef=$staleSessionId',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SizedBox(key: Key('home-route')),
          ),
          GoRoute(
            path: '/videoCallPage',
            builder: (context, state) =>
                const SizedBox(key: Key('video-call-route')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(
        Uri.parse(router.getCurrentLocation()).queryParameters['videoDocRef'],
        staleSessionId,
      );

      await service.debugHandleCallAcceptForTesting({
        'sessionId': acceptedSessionId,
        'extra': {
          'acceptMode': 'open_session',
          'tokenStrategy': 'get_session_tokens',
          'roomUrl': 'https://daily.test/accepted room?token=1&mode=call',
          'roomName': 'accepted-room',
        },
      });
      await tester.pumpAndSettle();

      final targetUri = Uri.parse(router.getCurrentLocation());
      expect(targetUri.path, '/videoCallPage');
      expect(targetUri.queryParameters['videoDocRef'], acceptedSessionId);
      expect(
        targetUri.queryParameters['roomUrl'],
        'https://daily.test/accepted room?token=1&mode=call',
      );
      expect(targetUri.queryParameters['roomName'], 'accepted-room');
      expect(acceptCallInvoked, isFalse);
      expect(find.byKey(const Key('video-call-route')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('early accept event waits for auth and service initialization',
        () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final prefetched = Completer<String>();
      var acceptCallInvoked = false;
      const sessionId = 'early-accept-session';

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (sessionId) async {
        if (!prefetched.isCompleted) {
          prefetched.complete(sessionId);
        }
      };
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await service.debugHandleCallKitAcceptEventForTesting({
        'sessionId': sessionId,
        'extra': {
          'tokenStrategy': 'get_session_tokens',
          'roomName': 'early-room',
        },
      });
      await service.debugHandleCallKitAcceptEventForTesting({
        'sessionId': sessionId,
        'extra': {
          'tokenStrategy': 'get_session_tokens',
          'roomName': 'early-room',
        },
      });

      expect(service.debugPendingCallKitActionCountForTesting, 1);
      expect(navigationCalls, isEmpty);
      expect(acceptCallInvoked, isFalse);

      await service.debugSetCallActionHandlingReadyForTesting(true);

      expect(service.debugPendingCallKitActionCountForTesting, 1);
      expect(navigationCalls, isEmpty);
      expect(acceptCallInvoked, isFalse);

      service.debugSetInitializedForTesting(true);
      await service.debugDrainPendingCallKitActionsForTesting();

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(await prefetched.future.timeout(const Duration(seconds: 1)),
          sessionId);
      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': sessionId,
        'isTutor': false,
        'roomUrl': null,
        'meetingToken': null,
        'roomName': 'early-room',
      });
    });

    test('background accepted replay waits for call actions ready', () async {
      final navigationCalls = <Map<String, dynamic>>[];
      const sessionId = 'early-background-replay-session';

      service.debugActiveCallsOverride = () async => [
            {
              'id': deterministicCallKitIdForTest(sessionId),
              'accepted': true,
              'extra': {
                'sessionId': sessionId,
                'tokenStrategy': 'get_session_tokens',
                'roomName': 'background-early-room',
              },
            },
          ];
      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (_) async {};
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await service.recoverBackgroundAcceptedCalls();

      expect(service.debugPendingCallKitActionCountForTesting, 1);
      expect(navigationCalls, isEmpty);

      await service.debugSetCallActionHandlingReadyForTesting(true);

      expect(service.debugPendingCallKitActionCountForTesting, 1);
      expect(navigationCalls, isEmpty);

      service.debugSetInitializedForTesting(true);
      await service.debugDrainPendingCallKitActionsForTesting();

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': sessionId,
        'isTutor': false,
        'roomName': 'background-early-room',
      });
    });

    test('background accepted replay is dropped for a different user',
        () async {
      final navigationCalls = <String>[];
      var acceptCallInvoked = false;
      const sessionId = 'background-wrong-user-session';

      service.debugActiveCallsOverride = () async => [
            {
              'id': deterministicCallKitIdForTest(sessionId),
              'accepted': true,
              'extra': {
                'sessionId': sessionId,
                'recipientId': 'other-user',
                'tokenStrategy': 'get_session_tokens',
                'roomName': 'background-wrong-user-room',
              },
            },
          ];
      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add(sessionId);
      };

      await markCallActionsReady();
      await service.recoverBackgroundAcceptedCalls();

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, isEmpty);
    });

    test('early decline event queues serialized extra until ready', () async {
      final declined = Completer<String>();
      const sessionId = 'early-decline-session';

      service.debugDeclineCallOverride = (declinedSessionId) async {
        if (!declined.isCompleted) {
          declined.complete(declinedSessionId);
        }
      };

      await service.debugHandleCallKitDeclineEventForTesting({
        'id': deterministicCallKitIdForTest(sessionId),
        'extra': '{"sessionId":"$sessionId"}',
      });

      expect(service.debugPendingCallKitActionCountForTesting, 1);
      expect(declined.isCompleted, isFalse);

      service.debugSetInitializedForTesting(true);
      await service.debugSetCallActionHandlingReadyForTesting(true);

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(
          await declined.future.timeout(const Duration(seconds: 1)), sessionId);
    });

    test('expired early accept is dropped when actions become ready', () async {
      var permissionsChecked = false;
      var acceptCallInvoked = false;

      service.debugEnsureMediaPermissionsOverride = () async {
        permissionsChecked = true;
        return true;
      };
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };

      await service.debugHandleCallKitAcceptEventForTesting({
        'sessionId': 'early-expired-session',
        'expiresAt': '2000-01-01T00:00:00.000Z',
      });

      expect(service.debugPendingCallKitActionCountForTesting, 1);

      service.debugSetInitializedForTesting(true);
      await service.debugSetCallActionHandlingReadyForTesting(true);

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(permissionsChecked, isFalse);
      expect(acceptCallInvoked, isFalse);
    });

    test('early accept queued past ttl is dropped before processing', () async {
      var permissionsChecked = false;
      var acceptCallInvoked = false;

      service.debugEnsureMediaPermissionsOverride = () async {
        permissionsChecked = true;
        return true;
      };
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };

      await service.debugHandleCallKitAcceptEventForTesting({
        'sessionId': 'early-ttl-session',
      });

      expect(service.debugPendingCallKitActionCountForTesting, 1);

      service.debugSetInitializedForTesting(true);
      await service.debugSetCallActionHandlingReadyForTesting(
        true,
        now: DateTime.now().add(const Duration(minutes: 3)),
      );

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(permissionsChecked, isFalse);
      expect(acceptCallInvoked, isFalse);
    });

    test('early action queue is bounded', () async {
      final maxCount = service.debugPendingCallKitActionMaxCountForTesting;

      for (var index = 0; index < maxCount + 3; index++) {
        await service.debugHandleCallKitAcceptEventForTesting({
          'sessionId': 'early-bounded-session-$index',
        });
      }

      expect(service.debugPendingCallKitActionCountForTesting, maxCount);
    });

    test('latest early action wins for the same CallKit session', () async {
      final declined = Completer<String>();
      var acceptCallInvoked = false;
      const sessionId = 'early-latest-action-session';

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugDeclineCallOverride = (declinedSessionId) async {
        if (!declined.isCompleted) {
          declined.complete(declinedSessionId);
        }
      };

      await service.debugHandleCallKitAcceptEventForTesting({
        'id': deterministicCallKitIdForTest(sessionId),
        'sessionId': sessionId,
      });
      await service.debugHandleCallKitDeclineEventForTesting({
        'id': deterministicCallKitIdForTest(sessionId),
        'sessionId': sessionId,
      });

      expect(service.debugPendingCallKitActionCountForTesting, 1);

      service.debugSetInitializedForTesting(true);
      await service.debugSetCallActionHandlingReadyForTesting(true);

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(acceptCallInvoked, isFalse);
      expect(
          await declined.future.timeout(const Duration(seconds: 1)), sessionId);
    });

    test('targeted early action is dropped for a different user', () async {
      var acceptCallInvoked = false;

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };

      await service.debugHandleCallKitAcceptEventForTesting({
        'sessionId': 'early-targeted-session',
        'recipientId': 'other-user',
      });

      expect(service.debugPendingCallKitActionCountForTesting, 1);

      service.debugSetInitializedForTesting(true);
      await service.debugSetCallActionHandlingReadyForTesting(true);

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(acceptCallInvoked, isFalse);
    });

    test('ready accept event is dropped for a different user', () async {
      final navigationCalls = <String>[];
      var permissionsChecked = false;
      var acceptCallInvoked = false;

      service.debugEnsureMediaPermissionsOverride = () async {
        permissionsChecked = true;
        return true;
      };
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add(sessionId);
      };

      await markCallActionsReady();
      await service.debugHandleCallKitAcceptEventForTesting({
        'sessionId': 'ready-wrong-user-accept',
        'recipientId': 'other-user',
        'extra': {
          'acceptMode': 'open_session',
          'tokenStrategy': 'get_session_tokens',
          'roomName': 'wrong-user-room',
        },
      });

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(permissionsChecked, isFalse);
      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, isEmpty);
    });

    test('ready decline event is dropped for a different user', () async {
      var declineCallInvoked = false;

      service.debugDeclineCallOverride = (_) async {
        declineCallInvoked = true;
      };

      await markCallActionsReady();
      await service.debugHandleCallKitDeclineEventForTesting({
        'sessionId': 'ready-wrong-user-decline',
        'recipientId': 'other-user',
      });

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(declineCallInvoked, isFalse);
    });

    test('untargeted early action is dropped without known user', () async {
      var acceptCallInvoked = false;

      service.debugCurrentUserIdOverride = null;
      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };

      await service.debugHandleCallKitAcceptEventForTesting({
        'sessionId': 'early-unknown-user-session',
      });

      expect(service.debugPendingCallKitActionCountForTesting, 1);

      service.debugSetInitializedForTesting(true);
      await service.debugSetCallActionHandlingReadyForTesting(true);

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(acceptCallInvoked, isFalse);
    });

    test('targeted early action runs for current user', () async {
      final navigationCalls = <Map<String, dynamic>>[];
      const sessionId = 'early-current-user-session';

      service.debugCurrentUserIdOverride = 'current-user';
      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (_) async {};
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await service.debugHandleCallKitAcceptEventForTesting({
        'sessionId': sessionId,
        'recipientId': 'current-user',
        'extra': {
          'tokenStrategy': 'get_session_tokens',
          'roomName': 'current-user-room',
        },
      });

      service.debugSetInitializedForTesting(true);
      await service.debugSetCallActionHandlingReadyForTesting(true);

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': sessionId,
        'isTutor': false,
        'roomName': 'current-user-room',
      });
    });

    test('student open-session action is not targeted by responderId',
        () async {
      final navigationCalls = <Map<String, dynamic>>[];
      const sessionId = 'early-student-open-session';

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (_) async {};
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await service.debugHandleCallKitAcceptEventForTesting({
        'sessionId': sessionId,
        'requesterId': 'student-user',
        'responderId': 'teacher-user',
        'navRole': 'student',
        'extra': {
          'acceptMode': 'open_session',
          'tokenStrategy': 'get_session_tokens',
          'roomName': 'student-open-room',
        },
      });

      service.debugSetInitializedForTesting(true);
      await service.debugSetCallActionHandlingReadyForTesting(true);

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': sessionId,
        'isTutor': false,
        'roomName': 'student-open-room',
      });
    });

    test('pending early events are cleared when actions become not ready',
        () async {
      await service.debugHandleCallKitAcceptEventForTesting({
        'sessionId': 'early-cleared-session',
        'extra': {'tokenStrategy': 'get_session_tokens'},
      });

      expect(service.debugPendingCallKitActionCountForTesting, 1);

      await service.debugSetCallActionHandlingReadyForTesting(false);

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(service.debugCallActionHandlingReadyForTesting, isFalse);
    });

    test('logout clear drops queued accept and decline actions', () async {
      final navigationCalls = <String>[];
      final declinedSessions = <String>[];

      service.debugCurrentUserIdOverride = 'current-user';
      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add(sessionId);
      };
      service.debugDeclineCallOverride = (sessionId) async {
        declinedSessions.add(sessionId);
      };

      await service.debugHandleCallKitAcceptEventForTesting({
        'sessionId': 'logout-queued-accept',
        'recipientId': 'current-user',
        'extra': {'tokenStrategy': 'get_session_tokens'},
      });
      await service.debugHandleCallKitDeclineEventForTesting({
        'sessionId': 'logout-queued-decline',
        'recipientId': 'current-user',
      });

      expect(service.debugPendingCallKitActionCountForTesting, 2);

      await service.debugSetCallActionHandlingReadyForTesting(false);
      service.debugSetInitializedForTesting(true);
      await service.debugSetCallActionHandlingReadyForTesting(true);

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(navigationCalls, isEmpty);
      expect(declinedSessions, isEmpty);
    });

    test('accept payload requires roomUrl for already accepted room branch',
        () {
      final credentials = voipRoomCredentialsFromAcceptedPayload({
        'roomUrl': ' https://daily.test/room-a ',
        'meetingToken': ' token-a ',
        'roomName': ' room-a ',
      });

      expect(credentials, isNotNull);
      expect(credentials!.roomUrl, 'https://daily.test/room-a');
      expect(credentials.meetingToken, 'token-a');
      expect(credentials.roomName, 'room-a');
      expect(
        voipRoomUrlFromAcceptPayload({
          'roomUrl': ' https://daily.test/room-a ',
          'meetingToken': 'token-a',
        }),
        'https://daily.test/room-a',
      );
      expect(
        voipMeetingTokenFromAcceptPayload({
          'roomUrl': 'https://daily.test/room-a',
          'meetingToken': ' token-a ',
        }),
        'token-a',
      );
      expect(
        voipRoomUrlFromAcceptPayload({
          'meetingToken': 'token-without-room',
        }),
        isNull,
      );
      expect(
        voipMeetingTokenFromAcceptPayload({
          'meetingToken': 'token-without-room',
        }),
        'token-without-room',
      );
      expect(
        voipRoomCredentialsFromAcceptedPayload({
          'meetingToken': 'token-without-room',
        }),
        isNull,
      );
    });

    test('accept payload reads CallKit extra before root fields', () {
      final payload = {
        'roomUrl': 'https://daily.test/root-room',
        'roomName': 'root-room',
        'extra': {
          'roomUrl': 'https://daily.test/extra-room',
          'roomName': 'extra-room',
        },
      };

      expect(
        voipRoomUrlFromAcceptPayload(payload),
        'https://daily.test/extra-room',
      );
      expect(voipRoomNameFromAcceptPayload(payload), 'extra-room');
    });

    test('accept payload falls back when CallKit extra fields are blank', () {
      final payload = {
        'roomUrl': 'https://daily.test/root-room',
        'meetingToken': 'root-token',
        'roomName': 'root-room',
        'extra': {
          'roomUrl': '   ',
          'meetingToken': '',
          'roomName': ' ',
        },
      };

      expect(
        voipRoomUrlFromAcceptPayload(payload),
        'https://daily.test/root-room',
      );
      expect(voipMeetingTokenFromAcceptPayload(payload), 'root-token');
      expect(voipRoomNameFromAcceptPayload(payload), 'root-room');
    });

    test('acceptCall response resolves only connected sessions with roomUrl',
        () {
      final credentials = voipRoomCredentialsFromAcceptCallResponse({
        'status': ' connected ',
        'roomUrl': ' https://daily.test/room-a ',
        'meetingToken': ' token-a ',
        'roomName': ' room-a ',
      });

      expect(credentials, isNotNull);
      expect(credentials!.roomUrl, 'https://daily.test/room-a');
      expect(credentials.meetingToken, 'token-a');
      expect(credentials.roomName, 'room-a');
      expect(
        voipRoomCredentialsFromAcceptCallResponse({
          'status': 'connected',
          'meetingToken': 'token-without-room',
        }),
        isNull,
      );
      expect(
        voipRoomCredentialsFromAcceptCallResponse({
          'status': 'failed-precondition',
          'roomUrl': 'https://daily.test/room-a',
        }),
        isNull,
      );
    });

    test('accept gate classifies early exits after process claim', () {
      final now = DateTime.utc(2026, 6, 25, 10);

      expect(
        voipEvaluateAcceptGate(
          now: now,
          lastAcceptAt: now.subtract(const Duration(seconds: 5)),
          handledCallKitAcceptId: false,
          acceptedSession: false,
          acceptInProgress: false,
        ),
        VoipAcceptGateDecision.duplicateTimeWindow,
      );
      expect(
        voipEvaluateAcceptGate(
          now: now,
          lastAcceptAt: null,
          handledCallKitAcceptId: true,
          acceptedSession: false,
          acceptInProgress: false,
        ),
        VoipAcceptGateDecision.duplicateCallKitId,
      );
      expect(
        voipEvaluateAcceptGate(
          now: now,
          lastAcceptAt: null,
          handledCallKitAcceptId: false,
          acceptedSession: true,
          acceptInProgress: false,
        ),
        VoipAcceptGateDecision.alreadyAccepted,
      );
      expect(
        voipEvaluateAcceptGate(
          now: now,
          lastAcceptAt: null,
          handledCallKitAcceptId: false,
          acceptedSession: false,
          acceptInProgress: true,
        ),
        VoipAcceptGateDecision.acceptInProgress,
      );
      expect(
        voipEvaluateAcceptGate(
          now: now,
          lastAcceptAt: now.subtract(const Duration(seconds: 31)),
          handledCallKitAcceptId: false,
          acceptedSession: false,
          acceptInProgress: false,
        ),
        VoipAcceptGateDecision.proceed,
      );
    });

    test('accept gate releases process claim for every early exit', () {
      for (final decision in VoipAcceptGateDecision.values) {
        expect(
          voipAcceptGateRequiresProcessClaimRelease(decision),
          decision != VoipAcceptGateDecision.proceed,
        );
      }
    });

    test('process accept claim can be released for retryable early exits', () {
      expect(service.debugTryClaimProcessAcceptForTesting('session-a'), isTrue);
      expect(service.debugHasProcessAcceptClaimForTesting('session-a'), isTrue);

      service.debugReleaseProcessAcceptClaimForTesting('session-a');

      expect(
          service.debugHasProcessAcceptClaimForTesting('session-a'), isFalse);
      expect(service.debugTryClaimProcessAcceptForTesting('session-a'), isTrue);
    });

    test('clear session state removes accept claim and local accept flags', () {
      expect(service.debugTryClaimProcessAcceptForTesting('session-a'), isTrue);
      service.debugMarkAcceptInProgressForTesting('session-a');
      service.debugMarkAcceptedSessionForTesting('session-a');
      service.debugTrackHandledCallKitAcceptForTesting(
        sessionId: 'session-a',
        callKitId: '12345678-1234-1234-1234-123456789abc',
      );

      expect(service.debugHasProcessAcceptClaimForTesting('session-a'), isTrue);
      expect(service.debugAcceptInProgressForTesting('session-a'), isTrue);
      expect(service.debugAcceptedSessionForTesting('session-a'), isTrue);
      expect(
        service.debugHandledCallKitAcceptForTesting(
          '12345678-1234-1234-1234-123456789abc',
        ),
        isTrue,
      );

      service.debugClearSessionStateForTesting('session-a');

      expect(
          service.debugHasProcessAcceptClaimForTesting('session-a'), isFalse);
      expect(service.debugAcceptInProgressForTesting('session-a'), isFalse);
      expect(service.debugAcceptedSessionForTesting('session-a'), isFalse);
      expect(
        service.debugHandledCallKitAcceptForTesting(
          '12345678-1234-1234-1234-123456789abc',
        ),
        isFalse,
      );
      expect(service.debugTryClaimProcessAcceptForTesting('session-a'), isTrue);
    });

    test('runtime acceptCall path navigates after backend credentials',
        () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final acceptStarted = Completer<void>();
      final acceptResponse = Completer<Map<String, dynamic>>();
      final navigationMarked = Completer<bool>();
      final prefetched = Completer<String>();

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (sessionId) {
        expect(sessionId, 'session-a');
        if (!acceptStarted.isCompleted) {
          acceptStarted.complete();
        }
        return acceptResponse.future;
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (sessionId) async {
        if (!prefetched.isCompleted) {
          prefetched.complete(sessionId);
        }
      };
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {
        expect(sessionId, 'session-a');
        if (!navigationMarked.isCompleted) {
          navigationMarked.complete(isTutor);
        }
      };

      await service.debugHandleCallAcceptForTesting({'sessionId': 'session-a'});

      await acceptStarted.future.timeout(const Duration(seconds: 1));
      expect(navigationCalls, isEmpty);

      acceptResponse.complete({
        'status': 'connected',
        'roomUrl': 'https://daily.test/room-a',
        'meetingToken': 'token-a',
        'roomName': 'room-a',
      });

      expect(
        await navigationMarked.future.timeout(const Duration(seconds: 1)),
        isTrue,
      );
      expect(
        await prefetched.future.timeout(const Duration(seconds: 1)),
        'session-a',
      );
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': 'session-a',
        'isTutor': true,
        'roomUrl': 'https://daily.test/room-a',
        'meetingToken': 'token-a',
        'roomName': 'room-a',
      });
      expect(service.debugAcceptedSessionForTesting('session-a'), isTrue);
      expect(service.debugAcceptInProgressForTesting('session-a'), isFalse);
    });

    test('runtime live accept reads sessionId from serialized CallKit extra',
        () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final prefetched = Completer<String>();
      var acceptCallInvoked = false;
      const sessionId = 'ffffffff-ffff-ffff-ffff-ffffffffffff';

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (sessionId) async {
        if (!prefetched.isCompleted) {
          prefetched.complete(sessionId);
        }
      };
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await service.debugHandleCallAcceptForTesting({
        'id': sessionId,
        'extra':
            '{"sessionId":"$sessionId","acceptMode":"open_session","tokenStrategy":"get_session_tokens","roomName":"live-extra-room"}',
      });

      expect(await prefetched.future.timeout(const Duration(seconds: 1)),
          sessionId);
      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': sessionId,
        'isTutor': false,
        'roomUrl': null,
        'meetingToken': null,
        'roomName': 'live-extra-room',
      });
    });

    test('runtime live accept handles non uuid serialized CallKit extra',
        () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final prefetched = Completer<String>();
      var acceptCallInvoked = false;
      const sessionId = 'live-session-non-uuid';
      final callKitId = deterministicCallKitIdForTest(sessionId);

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (sessionId) async {
        if (!prefetched.isCompleted) {
          prefetched.complete(sessionId);
        }
      };
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await service.debugHandleCallAcceptForTesting({
        'id': callKitId,
        'extra':
            '{"sessionId":"$sessionId","acceptMode":"open_session","tokenStrategy":"get_session_tokens","roomName":"live-non-uuid-room"}',
      });

      expect(await prefetched.future.timeout(const Duration(seconds: 1)),
          sessionId);
      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': sessionId,
        'isTutor': false,
        'roomUrl': null,
        'meetingToken': null,
        'roomName': 'live-non-uuid-room',
      });
    });

    test('runtime accepted student payload opens video and fetches fresh token',
        () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final prefetched = Completer<String>();
      final navigationMarked = Completer<bool>();
      var acceptCallInvoked = false;

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (sessionId) async {
        if (!prefetched.isCompleted) {
          prefetched.complete(sessionId);
        }
      };
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {
        expect(sessionId, 'session-student-accepted');
        if (!navigationMarked.isCompleted) {
          navigationMarked.complete(isTutor);
        }
      };

      await service.debugHandleCallAcceptForTesting({
        'sessionId': 'session-student-accepted',
        'extra': {
          'roomUrl': 'https://daily.test/student-room',
          'meetingToken': 'stale-payload-token',
          'roomName': 'student-room',
        },
      });

      expect(
        await prefetched.future.timeout(const Duration(seconds: 1)),
        'session-student-accepted',
      );
      expect(
        await navigationMarked.future.timeout(const Duration(seconds: 1)),
        isFalse,
      );
      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': 'session-student-accepted',
        'isTutor': false,
        'roomUrl': 'https://daily.test/student-room',
        'meetingToken': null,
        'roomName': 'student-room',
      });
      expect(
        service.debugAcceptedSessionForTesting('session-student-accepted'),
        isTrue,
      );
      expect(
        service.debugAcceptInProgressForTesting('session-student-accepted'),
        isFalse,
      );
    });

    test(
        'runtime open_session foreground payload skips acceptCall without room',
        () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final prefetched = Completer<String>();
      final navigationMarked = Completer<bool>();
      var acceptCallInvoked = false;

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (sessionId) async {
        if (!prefetched.isCompleted) {
          prefetched.complete(sessionId);
        }
      };
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {
        expect(sessionId, 'session-open-foreground');
        if (!navigationMarked.isCompleted) {
          navigationMarked.complete(isTutor);
        }
      };

      await service.debugHandleCallAcceptForTesting({
        'sessionId': 'session-open-foreground',
        'extra': {
          'acceptMode': 'open_session',
          'tokenStrategy': 'get_session_tokens',
          'roomName': 'room-open',
        },
      });

      expect(
        await prefetched.future.timeout(const Duration(seconds: 1)),
        'session-open-foreground',
      );
      expect(
        await navigationMarked.future.timeout(const Duration(seconds: 1)),
        isFalse,
      );
      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': 'session-open-foreground',
        'isTutor': false,
        'roomUrl': null,
        'meetingToken': null,
        'roomName': 'room-open',
      });
      expect(
        service.debugAcceptedSessionForTesting('session-open-foreground'),
        isTrue,
      );
      expect(
        service.debugAcceptInProgressForTesting('session-open-foreground'),
        isFalse,
      );
    });

    test('runtime root open_session payload skips acceptCall without room',
        () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final prefetched = Completer<String>();
      var acceptCallInvoked = false;

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (sessionId) async {
        if (!prefetched.isCompleted) {
          prefetched.complete(sessionId);
        }
      };
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await service.debugHandleCallAcceptForTesting({
        'sessionId': 'session-open-root',
        'acceptMode': 'open_session',
        'tokenStrategy': 'get_session_tokens',
        'roomName': 'root-room',
      });

      expect(
        await prefetched.future.timeout(const Duration(seconds: 1)),
        'session-open-root',
      );
      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': 'session-open-root',
        'isTutor': false,
        'roomUrl': null,
        'meetingToken': null,
        'roomName': 'root-room',
      });
      expect(
        service.debugAcceptedSessionForTesting('session-open-root'),
        isTrue,
      );
      expect(
        service.debugAcceptInProgressForTesting('session-open-root'),
        isFalse,
      );
    });

    test('runtime payload_room accept skips acceptCall without room', () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final prefetched = Completer<String>();
      var acceptCallInvoked = false;

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (sessionId) async {
        if (!prefetched.isCompleted) {
          prefetched.complete(sessionId);
        }
      };
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await service.debugHandleCallAcceptForTesting({
        'sessionId': 'session-payload-room',
        'extra': {
          'tokenStrategy': 'payload_room',
        },
      });

      expect(
        await prefetched.future.timeout(const Duration(seconds: 1)),
        'session-payload-room',
      );
      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': 'session-payload-room',
        'isTutor': false,
        'roomUrl': null,
        'meetingToken': null,
        'roomName': null,
      });
      expect(
        service.debugAcceptedSessionForTesting('session-payload-room'),
        isTrue,
      );
    });

    test(
        'runtime get_session_tokens accept skips acceptCall without acceptMode',
        () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final prefetched = Completer<String>();
      var acceptCallInvoked = false;

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (sessionId) async {
        if (!prefetched.isCompleted) {
          prefetched.complete(sessionId);
        }
      };
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await service.debugHandleCallAcceptForTesting({
        'sessionId': 'session-get-session-tokens',
        'extra': {
          'tokenStrategy': 'get_session_tokens',
        },
      });

      expect(
        await prefetched.future.timeout(const Duration(seconds: 1)),
        'session-get-session-tokens',
      );
      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': 'session-get-session-tokens',
        'isTutor': false,
        'roomUrl': null,
        'meetingToken': null,
        'roomName': null,
      });
      expect(
        service.debugAcceptedSessionForTesting('session-get-session-tokens'),
        isTrue,
      );
    });

    test('runtime expired accept payload is ignored before acceptCall',
        () async {
      final navigationCalls = <Map<String, dynamic>>[];
      var acceptCallInvoked = false;
      var permissionsChecked = false;
      var systemCallEnded = false;

      service.debugEnsureMediaPermissionsOverride = () async {
        permissionsChecked = true;
        return true;
      };
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugEndCallKitCallOverride = ({
        required sessionId,
        required callKitId,
      }) async {
        expect(sessionId, 'session-expired');
        expect(callKitId, '11111111-1111-1111-1111-111111111111');
        systemCallEnded = true;
      };
      service.debugTrackCallKitSessionForTesting(
        sessionId: 'session-expired',
        callKitId: '11111111-1111-1111-1111-111111111111',
      );

      await service.debugHandleCallAcceptForTesting({
        'id': '11111111-1111-1111-1111-111111111111',
        'sessionId': 'session-expired',
        'expiresAt': '2026-06-21T10:00:45.000Z',
      }, now: DateTime.utc(2026, 6, 21, 10, 1));

      expect(systemCallEnded, isTrue);
      expect(permissionsChecked, isFalse);
      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, isEmpty);
      expect(
          service.debugAcceptedSessionForTesting('session-expired'), isFalse);
      expect(
        service.debugAcceptInProgressForTesting('session-expired'),
        isFalse,
      );
    });

    test('runtime expired accept extra is ignored before acceptCall', () async {
      var acceptCallInvoked = false;
      var systemCallEnded = false;

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugEndCallKitCallOverride = ({
        required sessionId,
        required callKitId,
      }) async {
        expect(sessionId, 'session-expired-extra');
        expect(callKitId, '22222222-2222-2222-2222-222222222222');
        systemCallEnded = true;
      };
      service.debugTrackCallKitSessionForTesting(
        sessionId: 'session-expired-extra',
        callKitId: '22222222-2222-2222-2222-222222222222',
      );

      await service.debugHandleCallAcceptForTesting({
        'id': '22222222-2222-2222-2222-222222222222',
        'sessionId': 'session-expired-extra',
        'extra': {
          'expiresAt': '2026-06-21T10:00:45.000Z',
          'acceptMode': 'open_session',
        },
      }, now: DateTime.utc(2026, 6, 21, 10, 1));

      expect(systemCallEnded, isTrue);
      expect(acceptCallInvoked, isFalse);
      expect(
        service.debugAcceptedSessionForTesting('session-expired-extra'),
        isFalse,
      );
      expect(
        service.debugAcceptInProgressForTesting('session-expired-extra'),
        isFalse,
      );
    });

    test('runtime expired accept reads root callKitId', () async {
      var acceptCallInvoked = false;
      var systemCallEnded = false;

      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugEndCallKitCallOverride = ({
        required sessionId,
        required callKitId,
      }) async {
        expect(sessionId, 'session-expired-root-callkit');
        expect(callKitId, '77777777-7777-7777-7777-777777777777');
        systemCallEnded = true;
      };
      service.debugTrackCallKitSessionForTesting(
        sessionId: 'session-expired-root-callkit',
        callKitId: '77777777-7777-7777-7777-777777777777',
      );

      await service.debugHandleCallAcceptForTesting({
        'callKitId': '77777777-7777-7777-7777-777777777777',
        'sessionId': 'session-expired-root-callkit',
        'expiresAt': DateTime.utc(2026, 6, 21, 10, 0, 45),
      }, now: DateTime.utc(2026, 6, 21, 10, 1));

      expect(systemCallEnded, isTrue);
      expect(acceptCallInvoked, isFalse);
      expect(
        service.debugAcceptedSessionForTesting('session-expired-root-callkit'),
        isFalse,
      );
    });

    test('runtime expired accept reads untracked root callKitId', () async {
      var acceptCallInvoked = false;
      var systemCallEnded = false;
      const sessionId = 'session-expired-untracked-root-callkit';
      const callKitId = 'f9927535-9ed6-39ab-b197-b107131c5e9a';

      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugEndCallKitCallOverride = ({
        required sessionId,
        required callKitId,
      }) async {
        expect(sessionId, 'session-expired-untracked-root-callkit');
        expect(callKitId, 'f9927535-9ed6-39ab-b197-b107131c5e9a');
        systemCallEnded = true;
      };

      await service.debugHandleCallAcceptForTesting({
        'callKitId': callKitId,
        'sessionId': sessionId,
        'expiresAt': DateTime.utc(2026, 6, 21, 10, 0, 45),
      }, now: DateTime.utc(2026, 6, 21, 10, 1));

      expect(systemCallEnded, isTrue);
      expect(acceptCallInvoked, isFalse);
      expect(service.debugCallKitIdForSessionForTesting(sessionId), isNull);
    });

    test('runtime duplicate expired accept leaves accepted session alive',
        () async {
      var acceptCallInvoked = false;
      var systemCallEnded = false;

      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugEndCallKitCallOverride = ({
        required sessionId,
        required callKitId,
      }) async {
        systemCallEnded = true;
      };
      service.debugMarkAcceptedSessionForTesting('session-accepted-expired');
      service.debugTrackHandledCallKitAcceptForTesting(
        sessionId: 'session-accepted-expired',
        callKitId: '33333333-3333-3333-3333-333333333333',
      );

      await service.debugHandleCallAcceptForTesting({
        'id': '33333333-3333-3333-3333-333333333333',
        'sessionId': 'session-accepted-expired',
        'expiresAt': '2026-06-21T10:00:45.000Z',
      }, now: DateTime.utc(2026, 6, 21, 10, 1));

      expect(systemCallEnded, isFalse);
      expect(acceptCallInvoked, isFalse);
      expect(
        service.debugAcceptedSessionForTesting('session-accepted-expired'),
        isTrue,
      );
      expect(
        service.debugHandledCallKitAcceptForTesting(
          '33333333-3333-3333-3333-333333333333',
        ),
        isTrue,
      );
    });

    test('runtime in-progress expired accept leaves active flow alive',
        () async {
      var acceptCallInvoked = false;
      var systemCallEnded = false;

      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugEndCallKitCallOverride = ({
        required sessionId,
        required callKitId,
      }) async {
        systemCallEnded = true;
      };
      service.debugMarkAcceptInProgressForTesting('session-progress-expired');
      service.debugTrackCallKitSessionForTesting(
        sessionId: 'session-progress-expired',
        callKitId: '44444444-4444-4444-4444-444444444444',
      );

      await service.debugHandleCallAcceptForTesting({
        'id': '44444444-4444-4444-4444-444444444444',
        'sessionId': 'session-progress-expired',
        'expiresAt': '2026-06-21T10:00:45.000Z',
      }, now: DateTime.utc(2026, 6, 21, 10, 1));

      expect(systemCallEnded, isFalse);
      expect(acceptCallInvoked, isFalse);
      expect(
        service.debugAcceptInProgressForTesting('session-progress-expired'),
        isTrue,
      );
    });

    test('runtime protected-only expired accept leaves live state intact',
        () async {
      var acceptCallInvoked = false;
      var systemCallEnded = false;

      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugEndCallKitCallOverride = ({
        required sessionId,
        required callKitId,
      }) async {
        systemCallEnded = true;
      };
      service.debugMarkLastAcceptedSessionForTesting('session-protected-only');
      service.debugTrackCallKitSessionForTesting(
        sessionId: 'session-protected-only',
        callKitId: '66666666-6666-6666-6666-666666666666',
      );

      await service.debugHandleCallAcceptForTesting({
        'id': '66666666-6666-6666-6666-666666666666',
        'sessionId': 'session-protected-only',
        'expiresAt': '2026-06-21T10:00:45.000Z',
      }, now: DateTime.utc(2026, 6, 21, 10, 1));

      expect(systemCallEnded, isFalse);
      expect(acceptCallInvoked, isFalse);
      expect(
        service.debugAcceptedSessionForTesting('session-protected-only'),
        isFalse,
      );
      expect(
        service.debugCallKitIdForSessionForTesting('session-protected-only'),
        '66666666-6666-6666-6666-666666666666',
      );
    });

    test(
        'runtime expired accept with stale callkit id does not end other calls',
        () async {
      var acceptCallInvoked = false;
      var systemCallEnded = false;

      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugEndCallKitCallOverride = ({
        required sessionId,
        required callKitId,
      }) async {
        systemCallEnded = true;
      };

      await service.debugHandleCallAcceptForTesting({
        'id': '00000000-0000-0000-0000-000000000000',
        'sessionId': 'session-expired-stale',
        'expiresAt': '2026-06-21T10:00:45.000Z',
      }, now: DateTime.utc(2026, 6, 21, 10, 1));

      expect(systemCallEnded, isFalse);
      expect(acceptCallInvoked, isFalse);
      expect(
        service.debugAcceptedSessionForTesting('session-expired-stale'),
        isFalse,
      );
      expect(
        service.debugAcceptInProgressForTesting('session-expired-stale'),
        isFalse,
      );
    });

    test('runtime expired accept without callkit id does not end other calls',
        () async {
      var acceptCallInvoked = false;
      var systemCallEnded = false;

      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugEndCallKitCallOverride = ({
        required sessionId,
        required callKitId,
      }) async {
        systemCallEnded = true;
      };
      service.debugTrackCallKitSessionForTesting(
        sessionId: 'session-expired-unknown',
        callKitId: '55555555-5555-5555-5555-555555555555',
      );

      await service.debugHandleCallAcceptForTesting({
        'sessionId': 'session-expired-unknown',
        'expiresAt': '2026-06-21T10:00:45.000Z',
      }, now: DateTime.utc(2026, 6, 21, 10, 1));

      expect(systemCallEnded, isFalse);
      expect(acceptCallInvoked, isFalse);
      expect(
        service.debugAcceptedSessionForTesting('session-expired-unknown'),
        isFalse,
      );
      expect(
        service.debugAcceptInProgressForTesting('session-expired-unknown'),
        isFalse,
      );
      expect(
        service.debugCallKitIdForSessionForTesting('session-expired-unknown'),
        '55555555-5555-5555-5555-555555555555',
      );
    });

    test('runtime expired foreground incoming payload does not track CallKit',
        () async {
      await service.showIncomingCall(
        sessionId: 'session-expired-show',
        callerName: 'Caller',
        callerId: 'caller-a',
        extraData: {
          'expiresAt': '2026-06-21T10:00:45.000Z',
        },
      );

      expect(
        service.debugCallKitIdForSessionForTesting('session-expired-show'),
        isNull,
      );
    });

    test('runtime closed app incoming payload before 90 seconds tracks CallKit',
        () async {
      const sessionId = 'session-closed-before-stale';
      final expiresAt =
          DateTime.now().toUtc().add(const Duration(seconds: 89));

      expect(
        voipIncomingCallPayloadHasExpired({
          'expiresAt': expiresAt.toIso8601String(),
        }),
        isFalse,
      );

      await service.showIncomingCall(
        sessionId: sessionId,
        callerName: 'Caller',
        callerId: 'caller-a',
        extraData: {
          'type': 'incoming_call',
          'sessionId': sessionId,
          'recipientId': 'current-user',
          'acceptMode': 'responder_accepts',
          'tokenStrategy': 'accept_call',
          'expiresAt': expiresAt.toIso8601String(),
        },
      );

      expect(
        service.debugCallKitIdForSessionForTesting(sessionId),
        deterministicCallKitIdForTest(sessionId),
      );
    });

    test('runtime background replay opens accepted open_session call',
        () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final prefetched = Completer<String>();
      var acceptCallInvoked = false;
      const sessionId = '99999999-9999-9999-9999-999999999999';

      service.debugActiveCallsOverride = () async => [
            {
              'id': sessionId,
              'isAccepted': true,
              'extra': {
                'sessionId': sessionId,
                'tokenStrategy': 'get_session_tokens',
                'roomName': 'background-room',
              },
            },
          ];
      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (sessionId) async {
        if (!prefetched.isCompleted) {
          prefetched.complete(sessionId);
        }
      };
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await markCallActionsReady();
      await service.recoverBackgroundAcceptedCalls();

      expect(await prefetched.future.timeout(const Duration(seconds: 1)),
          sessionId);
      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': sessionId,
        'isTutor': false,
        'roomUrl': null,
        'meetingToken': null,
        'roomName': 'background-room',
      });
    });

    test('runtime closed app replay opens serialized accepted active call',
        () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final prefetched = Completer<String>();
      var acceptCallInvoked = false;
      const sessionId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

      service.debugActiveCallsOverride = () async =>
          '[{"id":"$sessionId","accepted":1,"extra":"{\\"sessionId\\":\\"$sessionId\\",\\"tokenStrategy\\":\\"get_session_tokens\\",\\"roomName\\":\\"closed-room\\"}"}]';
      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (sessionId) async {
        if (!prefetched.isCompleted) {
          prefetched.complete(sessionId);
        }
      };
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await markCallActionsReady();
      await service.recoverBackgroundAcceptedCalls();

      expect(await prefetched.future.timeout(const Duration(seconds: 1)),
          sessionId);
      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': sessionId,
        'isTutor': false,
        'roomUrl': null,
        'meetingToken': null,
        'roomName': 'closed-room',
      });
    });

    test('runtime closed app replay calls acceptCall for serialized responder',
        () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final navigationMarked = Completer<bool>();
      const sessionId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

      service.debugActiveCallsOverride = () async =>
          '[{"id":"$sessionId","isAccepted":false,"accepted":1,"extra":"{\\"sessionId\\":\\"$sessionId\\"}"}]';
      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (acceptedSessionId) async {
        expect(acceptedSessionId, sessionId);
        return {
          'status': 'connected',
          'roomUrl': 'https://daily.test/closed-responder',
          'meetingToken': 'closed-token',
          'roomName': 'closed-responder',
        };
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (_) async {};
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {
        if (!navigationMarked.isCompleted) {
          navigationMarked.complete(isTutor);
        }
      };

      await markCallActionsReady();
      await service.recoverBackgroundAcceptedCalls();

      expect(
        await navigationMarked.future.timeout(const Duration(seconds: 1)),
        isTrue,
      );
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': sessionId,
        'isTutor': true,
        'roomUrl': 'https://daily.test/closed-responder',
        'meetingToken': 'closed-token',
        'roomName': 'closed-responder',
      });
    });

    test('runtime closed app replay accepts serialized non uuid call',
        () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final prefetched = Completer<String>();
      var acceptCallInvoked = false;
      const sessionId = 'video-session-non-uuid';
      final callKitId = deterministicCallKitIdForTest(sessionId);

      service.debugActiveCallsOverride = () async =>
          '[{"id":"$callKitId","accepted":1,"extra":"{\\"sessionId\\":\\"$sessionId\\",\\"tokenStrategy\\":\\"get_session_tokens\\",\\"roomName\\":\\"non-uuid-room\\"}"}]';
      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (sessionId) async {
        if (!prefetched.isCompleted) {
          prefetched.complete(sessionId);
        }
      };
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await markCallActionsReady();
      await service.recoverBackgroundAcceptedCalls();

      expect(await prefetched.future.timeout(const Duration(seconds: 1)),
          sessionId);
      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': sessionId,
        'isTutor': false,
        'roomUrl': null,
        'meetingToken': null,
        'roomName': 'non-uuid-room',
      });
    });

    test('runtime background replay calls acceptCall for responder', () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final navigationMarked = Completer<bool>();
      const sessionId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

      service.debugActiveCallsOverride = () async => [
            {
              'id': sessionId,
              'isAccepted': true,
              'extra': {'sessionId': sessionId},
            },
          ];
      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (acceptedSessionId) async {
        expect(acceptedSessionId, sessionId);
        return {
          'status': 'connected',
          'roomUrl': 'https://daily.test/background-responder',
          'meetingToken': 'background-token',
          'roomName': 'background-responder',
        };
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (_) async {};
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {
        if (!navigationMarked.isCompleted) {
          navigationMarked.complete(isTutor);
        }
      };

      await markCallActionsReady();
      await service.recoverBackgroundAcceptedCalls();

      expect(
        await navigationMarked.future.timeout(const Duration(seconds: 1)),
        isTrue,
      );
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': sessionId,
        'isTutor': true,
        'roomUrl': 'https://daily.test/background-responder',
        'meetingToken': 'background-token',
        'roomName': 'background-responder',
      });
    });

    test('runtime background replay ignores duplicate live accept', () async {
      final navigationCalls = <Map<String, dynamic>>[];
      var acceptCallInvoked = false;
      const sessionId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (_) async {};
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {};

      await service.debugHandleCallAcceptForTesting({
        'id': sessionId,
        'sessionId': sessionId,
        'extra': {
          'tokenStrategy': 'get_session_tokens',
        },
      });

      service.debugActiveCallsOverride = () async => [
            {
              'id': sessionId,
              'isAccepted': true,
              'extra': {
                'sessionId': sessionId,
                'tokenStrategy': 'get_session_tokens',
              },
            },
          ];

      await markCallActionsReady();
      await service.recoverBackgroundAcceptedCalls();

      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, hasLength(1));
    });

    test('runtime background replay ignores stale active call id', () async {
      final navigationCalls = <Map<String, dynamic>>[];
      var acceptCallInvoked = false;

      service.debugActiveCallsOverride = () async => [
            {
              'id': '00000000-0000-0000-0000-000000000000',
              'isAccepted': true,
              'extra': {
                'sessionId': 'session-background-stale',
                'tokenStrategy': 'get_session_tokens',
              },
            },
          ];
      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        acceptCallInvoked = true;
        return <String, dynamic>{};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };

      await markCallActionsReady();
      await service.recoverBackgroundAcceptedCalls();

      expect(acceptCallInvoked, isFalse);
      expect(navigationCalls, isEmpty);
    });

    test('token prefetch ignores stale result after session swap', () async {
      final firstResponse = Completer<Map<String, dynamic>>();
      final secondResponse = Completer<Map<String, dynamic>>();

      service.debugGetSessionTokensOverride = (sessionId) {
        if (sessionId == 'session-a') {
          return firstResponse.future;
        }
        if (sessionId == 'session-b') {
          return secondResponse.future;
        }
        throw StateError('unexpected session: $sessionId');
      };

      final firstPrefetch =
          service.debugPrefetchSessionTokensForTesting('session-a');
      final secondPrefetch =
          service.debugPrefetchSessionTokensForTesting('session-b');

      secondResponse.complete({
        'meetingToken': 'token-b',
        'roomUrl': 'https://daily.test/room-b',
        'roomName': 'room-b',
      });
      await secondPrefetch;

      expect(
        service.debugFreshPrefetchedTokenForTesting('session-b'),
        'token-b',
      );
      expect(
        service.debugPrefetchedRoomUrlForTesting('session-b'),
        'https://daily.test/room-b',
      );
      expect(service.debugPrefetchedRoomNameForTesting('session-b'), 'room-b');

      firstResponse.complete({
        'meetingToken': 'token-a',
        'roomUrl': 'https://daily.test/room-a',
        'roomName': 'room-a',
      });
      await firstPrefetch;

      expect(service.debugFreshPrefetchedTokenForTesting('session-a'), isNull);
      expect(service.debugPrefetchedRoomUrlForTesting('session-a'), isNull);
      expect(
        service.debugFreshPrefetchedTokenForTesting('session-b'),
        'token-b',
      );
      expect(
        service.debugPrefetchedRoomUrlForTesting('session-b'),
        'https://daily.test/room-b',
      );
      expect(service.debugPrefetchedRoomNameForTesting('session-b'), 'room-b');
    });

    test('runtime acceptCall success without room credentials clears state',
        () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final acceptStarted = Completer<void>();
      var prefetched = false;
      var navigationMarked = false;

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (sessionId) async {
        expect(sessionId, 'session-a');
        if (!acceptStarted.isCompleted) {
          acceptStarted.complete();
        }
        return {'status': 'connected'};
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (_) async {
        prefetched = true;
      };
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {
        navigationMarked = true;
      };

      await service.debugHandleCallAcceptForTesting({'sessionId': 'session-a'});
      await acceptStarted.future.timeout(const Duration(seconds: 1));

      final deadline = DateTime.now().add(const Duration(seconds: 1));
      while (DateTime.now().isBefore(deadline) &&
          (service.debugAcceptedSessionForTesting('session-a') ||
              service.debugHasProcessAcceptClaimForTesting('session-a'))) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(navigationCalls, isEmpty);
      expect(prefetched, isFalse);
      expect(navigationMarked, isFalse);
      expect(service.debugAcceptedSessionForTesting('session-a'), isFalse);
      expect(
          service.debugHasProcessAcceptClaimForTesting('session-a'), isFalse);
      expect(service.debugAcceptInProgressForTesting('session-a'), isFalse);
      expect(service.debugTryClaimProcessAcceptForTesting('session-a'), isTrue);
    });

    test('runtime acceptCall error recovers and navigates', () async {
      final navigationCalls = <Map<String, dynamic>>[];
      final navigationMarked = Completer<bool>();

      service.debugEnsureMediaPermissionsOverride = () async => true;
      service.debugAcceptCallOverride = (_) async {
        throw StateError('callable timeout');
      };
      service.debugRecoverActiveSessionOverride = (sessionId) async {
        expect(sessionId, 'session-a');
        service.debugSetLastRoomCredentialsForTesting(
          roomUrl: 'https://daily.test/recovered-room',
          roomName: 'recovered-room',
        );
        return true;
      };
      service.debugNavigateToVideoCallOverride = ({
        required sessionId,
        required isTutor,
        roomUrl,
        meetingToken,
        roomName,
      }) {
        navigationCalls.add({
          'sessionId': sessionId,
          'isTutor': isTutor,
          'roomUrl': roomUrl,
          'meetingToken': meetingToken,
          'roomName': roomName,
        });
      };
      service.debugPrefetchSessionTokensOverride = (_) async {};
      service.debugMarkNavigationTriggeredOverride = ({
        required sessionId,
        required isTutor,
      }) async {
        expect(sessionId, 'session-a');
        if (!navigationMarked.isCompleted) {
          navigationMarked.complete(isTutor);
        }
      };

      await service.debugHandleCallAcceptForTesting({'sessionId': 'session-a'});

      expect(
        await navigationMarked.future.timeout(const Duration(seconds: 1)),
        isTrue,
      );
      expect(navigationCalls, hasLength(1));
      expect(navigationCalls.single, {
        'sessionId': 'session-a',
        'isTutor': true,
        'roomUrl': 'https://daily.test/recovered-room',
        'meetingToken': null,
        'roomName': 'recovered-room',
      });
      expect(service.debugAcceptedSessionForTesting('session-a'), isTrue);
      expect(service.debugAcceptInProgressForTesting('session-a'), isFalse);
    });
  });
}

class _TimestampLike {
  const _TimestampLike(this.value);

  final DateTime value;

  DateTime toDate() => value;
}
