import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/voip_service.dart';

void main() {
  late VoIPService service;

  setUp(() {
    service = VoIPService();
    service.debugResetInMemoryStateForTesting();
  });

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
