import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/services/match_coordinator.dart';

Map<String, dynamic> v2Session({
  String status = 'pending_confirmation',
  String role = 'student',
  String surface = 'pending',
  String decision = 'pending',
  String delivery = 'not_required',
  String? deliveryFailureKind,
  String pairAttemptId = 'pair-a',
  String scenario = 'student_student',
  String matchStage = 'awaiting_initial_dispatch',
  String peerRole = 'student',
  String peerSurface = 'in_app',
  String peerDecision = 'accepted',
  String peerDelivery = 'not_required',
  String? roomUrl,
}) {
  return <String, dynamic>{
    'matchProtocolVersion': 2,
    'pairAttemptId': pairAttemptId,
    'status': status,
    'scenario': scenario,
    'matchStage': matchStage,
    'participantIds': const ['student-a', 'student-b'],
    'participantRoles': {
      'student-a': role,
      'student-b': peerRole,
    },
    'participantStates': {
      'student-a': {
        'role': role,
        'surface': surface,
        'decision': decision,
        'delivery': delivery,
        if (deliveryFailureKind != null)
          'deliveryFailureKind': deliveryFailureKind,
        'callKitId': '11111111-1111-4111-8111-111111111111',
      },
      'student-b': {
        'role': peerRole,
        'surface': peerSurface,
        'decision': peerDecision,
        'delivery': peerDelivery,
      },
    },
    if (roomUrl != null) 'dailyRoomUrl': roomUrl,
  };
}

Future<void> flushCoordinator() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  group('MatchCoordinator protocol v2', () {
    late StreamController<Map<String, dynamic>?> userController;
    late StreamController<Map<String, dynamic>?> searchController;
    late StreamController<Map<String, dynamic>?> sessionController;
    late List<Map<String, dynamic>> actions;
    late List<Map<String, dynamic>> endActions;
    late List<Map<String, String?>> navigations;
    late MatchCoordinator coordinator;

    setUp(() {
      userController = StreamController<Map<String, dynamic>?>.broadcast();
      searchController = StreamController<Map<String, dynamic>?>.broadcast();
      sessionController = StreamController<Map<String, dynamic>?>.broadcast();
      actions = <Map<String, dynamic>>[];
      endActions = <Map<String, dynamic>>[];
      navigations = <Map<String, String?>>[];
      coordinator = MatchCoordinator.forTesting(
        initialLifecycleState: AppLifecycleState.resumed,
        userStream: (_) => userController.stream,
        searchStream: (_) => searchController.stream,
        sessionStream: (_) => sessionController.stream,
        respondInvoker: (payload) async {
          actions.add(Map<String, dynamic>.from(payload));
          return <String, dynamic>{
            'ok': true,
            'status': 'pending_confirmation',
            'pairAttemptId': payload['pairAttemptId'],
          };
        },
        endInvoker: (payload) async {
          endActions.add(Map<String, dynamic>.from(payload));
          return const <String, dynamic>{
            'ok': true,
            'status': 'ended',
          };
        },
        tokenLoader: (_) async => const <String, dynamic>{
          'roomUrl': 'https://daily.test/room',
          'roomName': 'room',
          'meetingToken': 'token',
        },
        navigator: ({
          required sessionId,
          required roomUrl,
          required meetingToken,
          roomName,
        }) {
          navigations.add({
            'sessionId': sessionId,
            'roomUrl': roomUrl,
            'meetingToken': meetingToken,
            'roomName': roomName,
          });
        },
      );
    });

    tearDown(() async {
      await coordinator.stop();
      await userController.close();
      await searchController.close();
      await sessionController.close();
    });

    Future<void> start() async {
      await coordinator.startForUser('student-a');
      searchController.add(const {'matchedSessionId': 'session-a'});
      await flushCoordinator();
    }

    test('only resumed lifecycle claims the in-app surface', () async {
      await start();
      coordinator.debugSetLifecycleState(AppLifecycleState.detached);
      sessionController.add(v2Session());
      await flushCoordinator();
      expect(actions, isEmpty);

      coordinator.debugSetLifecycleState(AppLifecycleState.inactive);
      sessionController.add(v2Session());
      await flushCoordinator();
      expect(actions, isEmpty);

      coordinator.debugSetLifecycleState(AppLifecycleState.resumed);
      await flushCoordinator();
      expect(actions, hasLength(1));
      expect(actions.single['action'], 'claim_in_app');
      expect(actions.single['sessionId'], 'session-a');
      expect(actions.single['pairAttemptId'], 'pair-a');
      expect(actions.single['actionId'], isNotEmpty);
    });

    test('null lifecycle never claims or navigates', () {
      final pending = MatchSessionState.fromData(
        sessionId: 'session-null-lifecycle',
        userId: 'student-a',
        data: v2Session(),
      );
      final connecting = MatchSessionState.fromData(
        sessionId: 'session-null-lifecycle',
        userId: 'student-a',
        data: v2Session(
          status: 'connecting',
          surface: 'in_app',
          decision: 'accepted',
        ),
      );
      expect(
        matchShouldClaimInApp(
          session: pending,
          lifecycleState: null,
        ),
        isFalse,
      );
      expect(
        matchCanNavigate(
          session: connecting,
          lifecycleState: null,
        ),
        isFalse,
      );
    });

    test('teacher and locked CallKit surfaces never claim on resume', () async {
      await start();
      sessionController.add(v2Session(role: 'native_speaker'));
      await flushCoordinator();
      sessionController.add(v2Session(
        surface: 'callkit',
        delivery: 'sent',
      ));
      await flushCoordinator();
      expect(actions, isEmpty);
    });

    test('student waits for teacher accept before claiming in app', () async {
      await start();
      sessionController.add(v2Session(
        scenario: 'student_teacher',
        peerRole: 'native_speaker',
        peerSurface: 'callkit',
        peerDecision: 'pending',
        peerDelivery: 'sent',
        matchStage: 'awaiting_teacher_response',
      ));
      await flushCoordinator();
      expect(actions, isEmpty);

      sessionController.add(v2Session(
        scenario: 'student_teacher',
        peerRole: 'native_speaker',
        peerSurface: 'callkit',
        peerDelivery: 'sent',
        matchStage: 'awaiting_student_dispatch',
      ));
      await flushCoordinator();
      expect(actions.single['action'], 'claim_in_app');
    });

    test('retries a claim rejected before the server stage catches up',
        () async {
      await coordinator.stop();
      coordinator = MatchCoordinator.forTesting(
        initialLifecycleState: AppLifecycleState.resumed,
        userStream: (_) => userController.stream,
        searchStream: (_) => searchController.stream,
        sessionStream: (_) => sessionController.stream,
        respondInvoker: (payload) async {
          actions.add(Map<String, dynamic>.from(payload));
          if (actions.length == 1) {
            return const <String, dynamic>{
              'ok': false,
              'stale': false,
              'reason': 'student_stage_not_ready',
            };
          }
          return const <String, dynamic>{'ok': true};
        },
      );

      await coordinator.startForUser('student-a');
      searchController.add(const {'matchedSessionId': 'session-a'});
      await flushCoordinator();
      final session = v2Session(
        scenario: 'student_teacher',
        peerRole: 'native_speaker',
        peerSurface: 'callkit',
        peerDelivery: 'sent',
        matchStage: 'awaiting_student_dispatch',
      );
      sessionController.add(session);
      await flushCoordinator();
      sessionController.add(session);
      await flushCoordinator();

      expect(actions, hasLength(2));
      expect(actions.map((value) => value['action']).toSet(), {'claim_in_app'});
    });

    test('only definitive failed CallKit delivery may recover in app',
        () async {
      await start();
      sessionController.add(v2Session(
        surface: 'callkit',
        delivery: 'failed',
      ));
      await flushCoordinator();
      expect(actions, isEmpty);

      sessionController.add(v2Session(
        surface: 'callkit',
        delivery: 'failed',
        deliveryFailureKind: 'definitive',
        pairAttemptId: 'pair-definitive',
      ));
      await flushCoordinator();
      expect(actions.single['action'], 'claim_in_app');
    });

    test('CallKit accept responds but pending session does not navigate',
        () async {
      await start();
      sessionController.add(v2Session(
        surface: 'callkit',
        delivery: 'sent',
      ));
      await flushCoordinator();

      final handled = await coordinator.handleCallKitAccept({
        'id': '11111111-1111-4111-8111-111111111111',
        'extra': const {
          'matchProtocolVersion': '2',
          'sessionId': 'session-a',
          'pairAttemptId': 'pair-a',
          'surface': 'callkit',
          'acceptMode': 'respond_to_match',
          'recipientId': 'student-a',
          'callKitId': '11111111-1111-4111-8111-111111111111',
        },
      });
      await flushCoordinator();

      expect(handled, isTrue);
      expect(actions.single['action'], 'accept');
      expect(navigations, isEmpty);
    });

    test('unknown CallKit accept retries with the same action id', () async {
      final acceptAttempts = <Map<String, dynamic>>[];
      await coordinator.stop();
      coordinator = MatchCoordinator.forTesting(
        initialLifecycleState: AppLifecycleState.resumed,
        actionRetryInterval: const Duration(milliseconds: 1),
        userStream: (_) => userController.stream,
        searchStream: (_) => searchController.stream,
        sessionStream: (_) => sessionController.stream,
        respondInvoker: (payload) async {
          acceptAttempts.add(Map<String, dynamic>.from(payload));
          if (acceptAttempts.length == 1) {
            throw TimeoutException('response lost');
          }
          return const <String, dynamic>{
            'ok': true,
            'status': 'pending_confirmation',
          };
        },
      );
      await coordinator.startForUser('student-a');

      final handled = await coordinator.handleCallKitAccept({
        'extra': const {
          'matchProtocolVersion': '2',
          'sessionId': 'session-retry-accept',
          'pairAttemptId': 'pair-retry-accept',
          'acceptMode': 'respond_to_match',
          'recipientId': 'student-a',
        },
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(handled, isTrue);
      expect(acceptAttempts, hasLength(2));
      expect(
          acceptAttempts.map((value) => value['action']).toSet(), {'accept'});
      expect(acceptAttempts.map((value) => value['actionId']).toSet(),
          hasLength(1));
    });

    test('persisted unknown Accept resumes after coordinator restart',
        () async {
      final acceptAttempts = <Map<String, dynamic>>[];
      await coordinator.stop();
      coordinator = MatchCoordinator.forTesting(
        initialLifecycleState: AppLifecycleState.resumed,
        actionRetryInterval: const Duration(milliseconds: 20),
        userStream: (_) => userController.stream,
        searchStream: (_) => searchController.stream,
        sessionStream: (_) => sessionController.stream,
        respondInvoker: (payload) async {
          acceptAttempts.add(Map<String, dynamic>.from(payload));
          throw TimeoutException('response lost');
        },
      );
      await coordinator.startForUser('student-a');
      expect(
        await coordinator.handleCallKitAccept({
          'extra': const {
            'matchProtocolVersion': '2',
            'sessionId': 'session-persisted-accept',
            'pairAttemptId': 'pair-persisted-accept',
            'acceptMode': 'respond_to_match',
            'recipientId': 'student-a',
          },
        }),
        isTrue,
      );
      final originalActionId = acceptAttempts.single['actionId'];
      await coordinator.stop();

      coordinator = MatchCoordinator.forTesting(
        initialLifecycleState: AppLifecycleState.resumed,
        actionRetryInterval: const Duration(milliseconds: 1),
        userStream: (_) => userController.stream,
        searchStream: (_) => searchController.stream,
        sessionStream: (_) => sessionController.stream,
        respondInvoker: (payload) async {
          acceptAttempts.add(Map<String, dynamic>.from(payload));
          return const <String, dynamic>{
            'ok': true,
            'status': 'pending_confirmation',
          };
        },
      );
      await coordinator.startForUser('student-a');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(acceptAttempts, hasLength(2));
      expect(acceptAttempts.last['actionId'], originalActionId);
    });

    test('Decline supersedes an Accept whose outcome is unknown', () async {
      final attemptedActions = <Map<String, dynamic>>[];
      await coordinator.stop();
      coordinator = MatchCoordinator.forTesting(
        initialLifecycleState: AppLifecycleState.resumed,
        actionRetryInterval: const Duration(milliseconds: 5),
        userStream: (_) => userController.stream,
        searchStream: (_) => searchController.stream,
        sessionStream: (_) => sessionController.stream,
        respondInvoker: (payload) async {
          attemptedActions.add(Map<String, dynamic>.from(payload));
          if (payload['action'] == 'accept') {
            throw TimeoutException('response lost');
          }
          return const <String, dynamic>{
            'ok': true,
            'status': 'cancelled',
          };
        },
        tokenLoader: (_) async => const <String, dynamic>{
          'roomUrl': 'https://daily.test/terminal-wins',
          'meetingToken': 'terminal-token',
        },
        navigator: ({
          required sessionId,
          required roomUrl,
          required meetingToken,
          roomName,
        }) {
          navigations.add({'sessionId': sessionId});
        },
      );
      await coordinator.startForUser('student-a');
      const payload = <String, dynamic>{
        'extra': <String, dynamic>{
          'matchProtocolVersion': '2',
          'sessionId': 'session-terminal-wins',
          'pairAttemptId': 'pair-terminal-wins',
          'acceptMode': 'respond_to_match',
          'recipientId': 'student-a',
        },
      };

      expect(await coordinator.handleCallKitAccept(payload), isTrue);
      expect(await coordinator.handleCallKitDecline(payload), isTrue);
      sessionController.add(v2Session(
        status: 'connecting',
        surface: 'callkit',
        decision: 'accepted',
        pairAttemptId: 'pair-terminal-wins',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(
        attemptedActions.map((value) => value['action']).toList(),
        ['accept', 'decline'],
      );
      expect(navigations, isEmpty);
    });

    test(
        'CallKit timeout blocks late connecting and retries the same action id',
        () async {
      final timeoutAttempts = <Map<String, dynamic>>[];
      final firstResponse = Completer<Map<String, dynamic>>();
      await coordinator.stop();
      coordinator = MatchCoordinator.forTesting(
        initialLifecycleState: AppLifecycleState.resumed,
        actionRetryInterval: const Duration(milliseconds: 1),
        userStream: (_) => userController.stream,
        searchStream: (_) => searchController.stream,
        sessionStream: (_) => sessionController.stream,
        respondInvoker: (payload) {
          timeoutAttempts.add(Map<String, dynamic>.from(payload));
          if (timeoutAttempts.length == 1) return firstResponse.future;
          return Future<Map<String, dynamic>>.value(const {
            'ok': true,
            'status': 'cancelled',
          });
        },
        tokenLoader: (_) async => const <String, dynamic>{
          'roomUrl': 'https://daily.test/timeout-race',
          'meetingToken': 'timeout-token',
        },
        navigator: ({
          required sessionId,
          required roomUrl,
          required meetingToken,
          roomName,
        }) {
          navigations.add({'sessionId': sessionId});
        },
      );
      await coordinator.startForUser('student-a');
      const payload = <String, dynamic>{
        'sessionId': 'session-timeout-race',
        'recipientId': 'student-a',
        'matchProtocolVersion': '2',
        'pairAttemptId': 'pair-timeout-race',
        'callKitId': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'acceptMode': 'respond_to_match',
      };

      final timeoutResult = coordinator.handleCallKitTimeout(payload);
      await flushCoordinator();
      sessionController.add(v2Session(
        status: 'connecting',
        surface: 'callkit',
        decision: 'accepted',
        pairAttemptId: 'pair-timeout-race',
      ));
      await flushCoordinator();

      expect(timeoutAttempts, hasLength(1));
      expect(navigations, isEmpty);

      firstResponse.completeError(TimeoutException('response lost'));
      expect(await timeoutResult, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(timeoutAttempts, hasLength(2));
      expect(
        timeoutAttempts.map((value) => value['action']).toSet(),
        {'timeout'},
      );
      expect(
        timeoutAttempts.map((value) => value['actionId']).toSet(),
        hasLength(1),
      );
      expect(navigations, isEmpty);
    });

    test('persisted timeout retries after restart before cached navigation',
        () async {
      final timeoutAttempts = <Map<String, dynamic>>[];
      await coordinator.stop();
      coordinator = MatchCoordinator.forTesting(
        initialLifecycleState: AppLifecycleState.resumed,
        actionRetryInterval: const Duration(seconds: 1),
        userStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
        searchStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
        sessionStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
        respondInvoker: (payload) async {
          timeoutAttempts.add(Map<String, dynamic>.from(payload));
          throw TimeoutException('timeout response lost');
        },
      );
      await coordinator.startForUser('student-a');
      expect(
        await coordinator.handleCallKitTimeout(const {
          'sessionId': 'session-persisted-timeout',
          'recipientId': 'student-a',
          'matchProtocolVersion': '2',
          'pairAttemptId': 'pair-persisted-timeout',
          'callKitId': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          'acceptMode': 'respond_to_match',
        }),
        isTrue,
      );
      final originalActionId = timeoutAttempts.single['actionId'];
      await coordinator.stop();

      final cachedNavigations = <String>[];
      coordinator = MatchCoordinator.forTesting(
        initialLifecycleState: AppLifecycleState.resumed,
        actionRetryInterval: const Duration(milliseconds: 1),
        userStream: (_) => Stream<Map<String, dynamic>?>.value(
          const {'currentSessionId': 'session-persisted-timeout'},
        ),
        searchStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
        sessionStream: (_) => Stream<Map<String, dynamic>?>.value(
          v2Session(
            status: 'connecting',
            surface: 'callkit',
            decision: 'accepted',
            pairAttemptId: 'pair-persisted-timeout',
          ),
        ),
        respondInvoker: (payload) async {
          timeoutAttempts.add(Map<String, dynamic>.from(payload));
          return const <String, dynamic>{
            'ok': true,
            'status': 'cancelled',
          };
        },
        tokenLoader: (_) async => const <String, dynamic>{
          'roomUrl': 'https://daily.test/persisted-timeout',
          'meetingToken': 'persisted-timeout-token',
        },
        navigator: ({
          required sessionId,
          required roomUrl,
          required meetingToken,
          roomName,
        }) {
          cachedNavigations.add(sessionId);
        },
      );
      await coordinator.startForUser('student-a');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(timeoutAttempts, hasLength(2));
      expect(timeoutAttempts.last['action'], 'timeout');
      expect(timeoutAttempts.last['actionId'], originalActionId);
      expect(cachedNavigations, isEmpty);
    });

    test('CallKit timeout preserves higher-priority saved intents', () async {
      final attemptedActions = <Map<String, dynamic>>[];
      await coordinator.stop();
      coordinator = MatchCoordinator.forTesting(
        initialLifecycleState: AppLifecycleState.resumed,
        actionRetryInterval: const Duration(hours: 1),
        userStream: (_) => userController.stream,
        searchStream: (_) => searchController.stream,
        sessionStream: (_) => sessionController.stream,
        respondInvoker: (payload) async {
          attemptedActions.add(Map<String, dynamic>.from(payload));
          throw TimeoutException('${payload['action']} response lost');
        },
        tokenLoader: (_) async => const <String, dynamic>{
          'roomUrl': 'https://daily.test/priority',
          'meetingToken': 'priority-token',
        },
        navigator: ({
          required sessionId,
          required roomUrl,
          required meetingToken,
          roomName,
        }) {
          navigations.add({'sessionId': sessionId});
        },
      );
      await coordinator.startForUser('student-a');
      const acceptedPayload = <String, dynamic>{
        'sessionId': 'session-timeout-after-accept',
        'recipientId': 'student-a',
        'matchProtocolVersion': '2',
        'pairAttemptId': 'pair-timeout-after-accept',
        'callKitId': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        'acceptMode': 'respond_to_match',
      };

      expect(await coordinator.handleCallKitAccept(acceptedPayload), isTrue);
      expect(await coordinator.handleCallKitTimeout(acceptedPayload), isTrue);
      expect(
        attemptedActions.map((value) => value['action']).toList(),
        ['accept'],
      );

      sessionController.add(v2Session(
        status: 'connecting',
        surface: 'callkit',
        decision: 'accepted',
        pairAttemptId: 'pair-timeout-after-accept',
      ));
      await flushCoordinator();
      expect(navigations, hasLength(1));
      expect(await coordinator.handleCallKitTimeout(acceptedPayload), isTrue);
      expect(
        attemptedActions.map((value) => value['action']).toList(),
        ['accept'],
      );

      const declinedPayload = <String, dynamic>{
        'sessionId': 'session-timeout-after-decline',
        'recipientId': 'student-a',
        'matchProtocolVersion': '2',
        'pairAttemptId': 'pair-timeout-after-decline',
        'callKitId': 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
        'acceptMode': 'respond_to_match',
      };
      expect(await coordinator.handleCallKitDecline(declinedPayload), isTrue);
      expect(await coordinator.handleCallKitTimeout(declinedPayload), isTrue);
      expect(
        attemptedActions.map((value) => value['action']).toList(),
        ['accept', 'decline'],
      );

      sessionController.add(v2Session(
        status: 'connecting',
        surface: 'callkit',
        decision: 'accepted',
        pairAttemptId: 'pair-timeout-after-decline',
      ));
      await flushCoordinator();
      expect(navigations, hasLength(1));
    });

    test('connecting session navigates only with resolved credentials',
        () async {
      await start();
      sessionController.add(v2Session(
        status: 'connecting',
        surface: 'in_app',
        decision: 'accepted',
        roomUrl: 'https://daily.test/session-room',
      ));
      await flushCoordinator();

      expect(navigations, hasLength(1));
      expect(navigations.single['sessionId'], 'session-a');
      expect(navigations.single['meetingToken'], 'token');
    });

    test('dashboard cancel uses exact current v2 attempt', () async {
      await start();
      sessionController.add(v2Session(
        surface: 'in_app',
        decision: 'accepted',
      ));
      await flushCoordinator();
      actions.clear();

      expect(await coordinator.cancelCurrentMatch(), isTrue);
      expect(actions.single['action'], 'cancel');
      expect(actions.single['pairAttemptId'], 'pair-a');
    });

    test('connecting cancel ends the session and suppresses navigation',
        () async {
      final tokenCompleter = Completer<Map<String, dynamic>>();
      await coordinator.stop();
      coordinator = MatchCoordinator.forTesting(
        initialLifecycleState: AppLifecycleState.resumed,
        userStream: (_) => userController.stream,
        searchStream: (_) => searchController.stream,
        sessionStream: (_) => sessionController.stream,
        respondInvoker: (payload) async {
          actions.add(Map<String, dynamic>.from(payload));
          return const <String, dynamic>{'ok': true};
        },
        endInvoker: (payload) async {
          endActions.add(Map<String, dynamic>.from(payload));
          return const <String, dynamic>{
            'ok': true,
            'status': 'ended',
          };
        },
        tokenLoader: (_) => tokenCompleter.future,
        navigator: ({
          required sessionId,
          required roomUrl,
          required meetingToken,
          roomName,
        }) {
          navigations.add({
            'sessionId': sessionId,
            'roomUrl': roomUrl,
            'meetingToken': meetingToken,
            'roomName': roomName,
          });
        },
      );
      await start();
      sessionController.add(v2Session(
        status: 'connecting',
        surface: 'in_app',
        decision: 'accepted',
      ));
      await flushCoordinator();

      expect(coordinator.hasCancellableV2Match, isTrue);
      expect(await coordinator.cancelCurrentMatch(), isTrue);
      tokenCompleter.complete(const <String, dynamic>{
        'roomUrl': 'https://daily.test/room',
        'meetingToken': 'token',
      });
      await flushCoordinator();

      expect(endActions, hasLength(1));
      expect(endActions.single['sessionId'], 'session-a');
      expect(
        endActions.single['endReason'],
        'user_cancelled_connecting',
      );
      expect(endActions.single['actionId'], isNotEmpty);
      expect(actions, isEmpty);
      expect(navigations, isEmpty);
    });

    test('connecting cancellation retries the same durable end after restart',
        () async {
      final endAttempts = <Map<String, dynamic>>[];
      await coordinator.stop();
      coordinator = MatchCoordinator.forTesting(
        initialLifecycleState: AppLifecycleState.resumed,
        actionRetryInterval: const Duration(milliseconds: 20),
        userStream: (_) => userController.stream,
        searchStream: (_) => searchController.stream,
        sessionStream: (_) => sessionController.stream,
        endInvoker: (payload) async {
          endAttempts.add(Map<String, dynamic>.from(payload));
          throw TimeoutException('end response lost');
        },
      );
      await start();
      sessionController.add(v2Session(
        status: 'connecting',
        surface: 'in_app',
        decision: 'accepted',
      ));
      await flushCoordinator();

      expect(await coordinator.cancelCurrentMatch(), isTrue);
      final actionId = endAttempts.single['actionId'];
      await coordinator.stop();

      coordinator = MatchCoordinator.forTesting(
        initialLifecycleState: AppLifecycleState.resumed,
        actionRetryInterval: const Duration(milliseconds: 1),
        userStream: (_) => userController.stream,
        searchStream: (_) => searchController.stream,
        sessionStream: (_) => sessionController.stream,
        endInvoker: (payload) async {
          endAttempts.add(Map<String, dynamic>.from(payload));
          return const <String, dynamic>{
            'ok': true,
            'status': 'ended',
          };
        },
      );
      await coordinator.startForUser('student-a');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(endAttempts, hasLength(2));
      expect(endAttempts.last['actionId'], actionId);
    });

    test('persisted terminal intent blocks synchronous cached navigation',
        () async {
      await coordinator.stop();
      coordinator = MatchCoordinator.forTesting(
        initialLifecycleState: AppLifecycleState.resumed,
        actionRetryInterval: const Duration(seconds: 1),
        userStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
        searchStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
        sessionStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
        respondInvoker: (_) async => throw TimeoutException('cancel pending'),
      );
      await coordinator.startForUser('student-a');
      expect(
        await coordinator.handleCallKitEnd(const {
          'sessionId': 'session-cached-cancel',
          'recipientId': 'student-a',
          'matchProtocolVersion': '2',
          'pairAttemptId': 'pair-cached-cancel',
          'callKitId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          'acceptMode': 'respond_to_match',
        }),
        MatchCallKitEndDisposition.handledPending,
      );
      await coordinator.stop();

      final cachedNavigations = <String>[];
      coordinator = MatchCoordinator.forTesting(
        initialLifecycleState: AppLifecycleState.resumed,
        actionRetryInterval: const Duration(seconds: 1),
        userStream: (_) => Stream<Map<String, dynamic>?>.value(
          const {'currentSessionId': 'session-cached-cancel'},
        ),
        searchStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
        sessionStream: (_) => Stream<Map<String, dynamic>?>.value(
          v2Session(
            status: 'connecting',
            surface: 'callkit',
            decision: 'accepted',
            pairAttemptId: 'pair-cached-cancel',
          ),
        ),
        respondInvoker: (_) async => const <String, dynamic>{
          'ok': true,
          'status': 'connecting',
        },
        tokenLoader: (_) async => const <String, dynamic>{
          'roomUrl': 'https://daily.test/cached',
          'meetingToken': 'cached-token',
        },
        navigator: ({
          required sessionId,
          required roomUrl,
          required meetingToken,
          roomName,
        }) {
          cachedNavigations.add(sessionId);
        },
      );
      await coordinator.startForUser('student-a');
      await flushCoordinator();

      expect(cachedNavigations, isEmpty);
    });

    test('local exact cancellation suppresses a later connecting snapshot',
        () async {
      await start();
      coordinator.noteLocalCancellation('session-a');
      sessionController.add(v2Session(
        status: 'connecting',
        surface: 'in_app',
        decision: 'accepted',
      ));
      await flushCoordinator();

      expect(navigations, isEmpty);
    });

    test('user link has priority and null snapshots unlink stale session',
        () async {
      await coordinator.startForUser('student-a');
      searchController.add(const {'matchedSessionId': 'session-search'});
      await flushCoordinator();
      sessionController.add(const {
        'status': 'searching',
        'participantIds': ['student-a', 'student-b'],
      });
      await flushCoordinator();
      expect(coordinator.currentSession?.sessionId, 'session-search');

      userController.add(const {'currentSessionId': 'session-user'});
      await flushCoordinator();
      sessionController.add(const {
        'status': 'searching',
        'participantIds': ['student-a', 'student-b'],
      });
      await flushCoordinator();
      expect(coordinator.currentSession?.sessionId, 'session-user');

      searchController.add(const <String, dynamic>{});
      await flushCoordinator();
      expect(coordinator.currentSession?.sessionId, 'session-user');

      userController.add(null);
      await flushCoordinator();
      expect(coordinator.currentSession, isNull);
    });
  });

  test('legacy connecting session stays with legacy navigation owners', () {
    final session = MatchSessionState.fromData(
      sessionId: 'legacy-session',
      userId: 'student-a',
      data: const {
        'status': 'connecting',
        'participantIds': ['student-a', 'student-b'],
      },
    );
    expect(
      matchCanNavigate(
        session: session,
        lifecycleState: AppLifecycleState.resumed,
      ),
      isFalse,
    );
  });

  test('concurrent startForUser keeps only the latest user listeners',
      () async {
    final startedUsers = <String>[];
    final coordinator = MatchCoordinator.forTesting(
      userStream: (userId) {
        startedUsers.add('user:$userId');
        return const Stream<Map<String, dynamic>?>.empty();
      },
      searchStream: (userId) {
        startedUsers.add('search:$userId');
        return const Stream<Map<String, dynamic>?>.empty();
      },
      sessionStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
    );

    await Future.wait([
      coordinator.startForUser('student-old'),
      coordinator.startForUser('student-current'),
    ]);

    expect(startedUsers, ['user:student-current', 'search:student-current']);
    await coordinator.stop();
  });

  test('restart refreshes lifecycle instead of keeping stale paused state',
      () async {
    var lifecycle = AppLifecycleState.paused;
    final userController = StreamController<Map<String, dynamic>?>.broadcast();
    final searchController =
        StreamController<Map<String, dynamic>?>.broadcast();
    final sessionController =
        StreamController<Map<String, dynamic>?>.broadcast();
    final actions = <Map<String, dynamic>>[];
    final coordinator = MatchCoordinator.forTesting(
      lifecycleStateReader: () => lifecycle,
      userStream: (_) => userController.stream,
      searchStream: (_) => searchController.stream,
      sessionStream: (_) => sessionController.stream,
      respondInvoker: (payload) async {
        actions.add(Map<String, dynamic>.from(payload));
        return const <String, dynamic>{'ok': true};
      },
    );

    await coordinator.startForUser('student-a');
    expect(coordinator.lifecycleState, AppLifecycleState.paused);
    await coordinator.stop();
    expect(coordinator.lifecycleState, isNull);

    lifecycle = AppLifecycleState.resumed;
    await coordinator.startForUser('student-a');
    searchController.add(const {'matchedSessionId': 'session-a'});
    await flushCoordinator();
    sessionController.add(v2Session());
    await flushCoordinator();

    expect(coordinator.lifecycleState, AppLifecycleState.resumed);
    expect(actions.single['action'], 'claim_in_app');

    await coordinator.stop();
    await userController.close();
    await searchController.close();
    await sessionController.close();
  });

  test('global v2 search heartbeat follows lifecycle without a dashboard',
      () async {
    final userController = StreamController<Map<String, dynamic>?>.broadcast();
    final searchController =
        StreamController<Map<String, dynamic>?>.broadcast();
    final heartbeats = <Map<String, dynamic>>[];
    final coordinator = MatchCoordinator.forTesting(
      initialLifecycleState: AppLifecycleState.resumed,
      heartbeatInterval: const Duration(milliseconds: 10),
      userStream: (_) => userController.stream,
      searchStream: (_) => searchController.stream,
      sessionStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
      heartbeatInvoker: (payload) async {
        heartbeats.add(Map<String, dynamic>.from(payload));
        return const <String, dynamic>{'ok': true};
      },
    );

    await coordinator.startForUser('student-a');
    searchController.add(const {
      'userId': 'student-a',
      'requestId': 'request-a',
      'status': 'active',
      'matchProtocolVersion': 2,
    });
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(heartbeats, [
      <String, dynamic>{
        'requestId': 'request-a',
        'appState': 'foreground',
        'matchProtocolVersion': 2,
      },
    ]);

    await Future<void>.delayed(const Duration(milliseconds: 12));
    expect(heartbeats.length, greaterThanOrEqualTo(2));

    coordinator.debugSetLifecycleState(AppLifecycleState.inactive);
    await Future<void>.delayed(Duration.zero);
    expect(heartbeats.last['appState'], 'inactive');
    final inactiveHeartbeatCount = heartbeats.length;

    coordinator.debugSetLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(heartbeats, hasLength(inactiveHeartbeatCount + 1));
    expect(heartbeats.last['appState'], 'background');

    coordinator.debugSetLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(heartbeats.last['appState'], 'foreground');

    searchController.add(const {
      'userId': 'student-a',
      'requestId': 'request-b',
      'status': 'active',
      'matchProtocolVersion': 2,
    });
    await Future<void>.delayed(Duration.zero);
    expect(heartbeats.last['requestId'], 'request-b');

    await coordinator.stop();
    await userController.close();
    await searchController.close();
  });

  test('global coordinator does not own legacy search heartbeat', () async {
    final searchController =
        StreamController<Map<String, dynamic>?>.broadcast();
    final heartbeats = <Map<String, dynamic>>[];
    final coordinator = MatchCoordinator.forTesting(
      initialLifecycleState: AppLifecycleState.resumed,
      heartbeatInterval: const Duration(milliseconds: 1),
      userStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
      searchStream: (_) => searchController.stream,
      sessionStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
      heartbeatInvoker: (payload) async {
        heartbeats.add(Map<String, dynamic>.from(payload));
        return const <String, dynamic>{'ok': true};
      },
    );

    await coordinator.startForUser('student-a');
    searchController.add(const {
      'userId': 'student-a',
      'requestId': 'legacy-request',
      'status': 'matched',
      'matchProtocolVersion': 1,
      'currentSessionId': 'legacy-session',
      'pairAttemptId': 'legacy-pair',
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(heartbeats, isEmpty);

    await coordinator.stop();
    await searchController.close();
  });

  test('matched v2 search keeps exact lifecycle heartbeat until it unbinds',
      () async {
    final searchController =
        StreamController<Map<String, dynamic>?>.broadcast();
    final heartbeats = <Map<String, dynamic>>[];
    final coordinator = MatchCoordinator.forTesting(
      initialLifecycleState: AppLifecycleState.resumed,
      heartbeatInterval: const Duration(hours: 1),
      userStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
      searchStream: (_) => searchController.stream,
      sessionStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
      heartbeatInvoker: (payload) async {
        heartbeats.add(Map<String, dynamic>.from(payload));
        return const <String, dynamic>{'ok': true};
      },
    );

    await coordinator.startForUser('student-a');
    searchController.add(const {
      'userId': 'student-a',
      'requestId': 'matched-request',
      'status': 'matched',
      'matchProtocolVersion': 2,
      'currentSessionId': 'matched-session',
      'pairAttemptId': 'matched-pair',
    });
    await Future<void>.delayed(Duration.zero);

    expect(heartbeats, [
      <String, dynamic>{
        'requestId': 'matched-request',
        'appState': 'foreground',
        'matchProtocolVersion': 2,
      },
    ]);

    coordinator.debugSetLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(heartbeats, hasLength(2));
    expect(heartbeats.last['appState'], 'background');

    coordinator.debugSetLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(heartbeats, hasLength(3));
    expect(heartbeats.last['appState'], 'foreground');

    searchController.add(const {
      'userId': 'student-a',
      'requestId': 'matched-request',
      'status': 'matched',
      'matchProtocolVersion': 2,
    });
    await Future<void>.delayed(Duration.zero);
    coordinator.debugSetLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(heartbeats, hasLength(3));

    await coordinator.stop();
    await searchController.close();
  });

  test('foreground claim waits for matched-search heartbeat', () async {
    final searchController =
        StreamController<Map<String, dynamic>?>.broadcast();
    final sessionController =
        StreamController<Map<String, dynamic>?>.broadcast();
    final heartbeatGate = Completer<void>();
    final heartbeats = <Map<String, dynamic>>[];
    final actions = <Map<String, dynamic>>[];
    var foregroundHeartbeatStored = false;
    final coordinator = MatchCoordinator.forTesting(
      initialLifecycleState: AppLifecycleState.resumed,
      heartbeatInterval: const Duration(hours: 1),
      userStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
      searchStream: (_) => searchController.stream,
      sessionStream: (_) => sessionController.stream,
      heartbeatInvoker: (payload) async {
        heartbeats.add(Map<String, dynamic>.from(payload));
        await heartbeatGate.future;
        foregroundHeartbeatStored = true;
        return const <String, dynamic>{'heartbeat': true};
      },
      respondInvoker: (payload) async {
        actions.add(Map<String, dynamic>.from(payload));
        if (!foregroundHeartbeatStored) {
          return const <String, dynamic>{
            'ok': false,
            'stale': true,
            'reason': 'claim_requires_fresh_foreground',
          };
        }
        return const <String, dynamic>{'ok': true};
      },
    );
    addTearDown(() async {
      if (!heartbeatGate.isCompleted) heartbeatGate.complete();
      await coordinator.stop();
      await searchController.close();
      await sessionController.close();
    });

    await coordinator.startForUser('student-a');
    searchController.add(const {
      'userId': 'student-a',
      'requestId': 'matched-request',
      'status': 'matched',
      'matchProtocolVersion': 2,
      'currentSessionId': 'session-a',
      'pairAttemptId': 'pair-a',
    });
    await flushCoordinator();
    expect(heartbeats, hasLength(1));

    sessionController.add(v2Session());
    await flushCoordinator();

    expect(actions, isEmpty);

    heartbeatGate.complete();
    await flushCoordinator();

    expect(actions, hasLength(1));
    expect(actions.single['action'], 'claim_in_app');
  });

  test('navigation retries transient token failures for the exact v2 pair',
      () async {
    final searchController =
        StreamController<Map<String, dynamic>?>.broadcast();
    final sessionController =
        StreamController<Map<String, dynamic>?>.broadcast();
    final navigations = <String>[];
    var tokenLoadAttempts = 0;
    final coordinator = MatchCoordinator.forTesting(
      initialLifecycleState: AppLifecycleState.resumed,
      tokenRetryDelays: const [Duration.zero, Duration.zero, Duration.zero],
      userStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
      searchStream: (_) => searchController.stream,
      sessionStream: (_) => sessionController.stream,
      tokenLoader: (_) async {
        tokenLoadAttempts += 1;
        if (tokenLoadAttempts < 3) {
          throw StateError('temporary token failure');
        }
        return const <String, dynamic>{
          'roomUrl': 'https://daily.test/retry-room',
          'meetingToken': 'retry-token',
        };
      },
      navigator: ({
        required sessionId,
        required roomUrl,
        required meetingToken,
        roomName,
      }) {
        navigations.add(sessionId);
      },
    );

    await coordinator.startForUser('student-a');
    searchController.add(const {'matchedSessionId': 'session-retry'});
    await flushCoordinator();
    sessionController.add(v2Session(
      status: 'connecting',
      surface: 'in_app',
      decision: 'accepted',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(tokenLoadAttempts, 3);
    expect(navigations, ['session-retry']);

    await coordinator.stop();
    await searchController.close();
    await sessionController.close();
  });

  test('navigation retry stops when the exact v2 pair is no longer joinable',
      () async {
    final searchController =
        StreamController<Map<String, dynamic>?>.broadcast();
    final sessionController =
        StreamController<Map<String, dynamic>?>.broadcast();
    var tokenLoadAttempts = 0;
    final navigations = <String>[];
    final coordinator = MatchCoordinator.forTesting(
      initialLifecycleState: AppLifecycleState.resumed,
      tokenRetryDelays: const [
        Duration.zero,
        Duration(milliseconds: 5),
      ],
      userStream: (_) => const Stream<Map<String, dynamic>?>.empty(),
      searchStream: (_) => searchController.stream,
      sessionStream: (_) => sessionController.stream,
      tokenLoader: (_) async {
        tokenLoadAttempts += 1;
        sessionController.add(v2Session(
          status: 'cancelled',
          surface: 'in_app',
          decision: 'accepted',
        ));
        throw StateError('temporary token failure');
      },
      navigator: ({
        required sessionId,
        required roomUrl,
        required meetingToken,
        roomName,
      }) {
        navigations.add(sessionId);
      },
    );

    await coordinator.startForUser('student-a');
    searchController.add(const {'matchedSessionId': 'session-cancelled'});
    await flushCoordinator();
    sessionController.add(v2Session(
      status: 'connecting',
      surface: 'in_app',
      decision: 'accepted',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(tokenLoadAttempts, 1);
    expect(navigations, isEmpty);

    await coordinator.stop();
    await searchController.close();
    await sessionController.close();
  });
}
