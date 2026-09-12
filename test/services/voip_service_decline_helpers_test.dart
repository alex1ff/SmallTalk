import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/voip_service.dart';

import 'voip_test_helpers.dart';

void main() {
  late VoIPService service;

  setUp(() {
    service = VoIPService();
    service.debugResetInMemoryStateForTesting();
  });

  Future<void> markCallActionsReady({DateTime? now}) async {
    service.debugSetInitializedForTesting(true);
    await service.debugSetCallActionHandlingReadyForTesting(true, now: now);
  }

  group('VoIP decline helpers', () {
    test('targeted CallKit decline waits for auth and service readiness',
        () async {
      final declinedSessions = <String>[];
      const sessionId = 'auth-late-decline-session';

      service.debugCurrentUserIdOverride = null;
      service.debugDeclineCallOverride = (sessionId) async {
        declinedSessions.add(sessionId);
      };

      await service.debugHandleCallKitDeclineEventForTesting({
        'sessionId': sessionId,
        'recipientId': 'current-user',
      });

      expect(service.debugPendingCallKitActionCountForTesting, 1);
      expect(declinedSessions, isEmpty);

      service.debugCurrentUserIdOverride = 'current-user';
      await markCallActionsReady();

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(declinedSessions, [sessionId]);
      expect(service.debugRecentlyDeclinedSessionForTesting(sessionId), isTrue);
    });

    test('serialized CallKit decline waits for auth and service readiness',
        () async {
      final declinedSessions = <String>[];
      const sessionId = 'serialized-auth-late-decline-session';

      service.debugCurrentUserIdOverride = null;
      service.debugDeclineCallOverride = (sessionId) async {
        declinedSessions.add(sessionId);
      };

      await service.debugHandleCallKitDeclineEventForTesting({
        'id': deterministicCallKitIdForTest(sessionId),
        'extra': jsonEncode({
          'sessionId': sessionId,
          'recipientId': 'current-user',
          'notificationId': 'serialized-decline-notification',
        }),
      });

      expect(service.debugPendingCallKitActionCountForTesting, 1);
      expect(declinedSessions, isEmpty);

      service.debugCurrentUserIdOverride = 'current-user';
      await markCallActionsReady();

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(declinedSessions, [sessionId]);
      expect(service.debugRecentlyDeclinedSessionForTesting(sessionId), isTrue);
    });

    test(
        'queued CallKit decline is dropped after auth resolves to another user',
        () async {
      final declinedSessions = <String>[];

      service.debugCurrentUserIdOverride = null;
      service.debugDeclineCallOverride = (sessionId) async {
        declinedSessions.add(sessionId);
      };

      await service.debugHandleCallKitDeclineEventForTesting({
        'sessionId': 'wrong-user-decline-session',
        'recipientId': 'other-user',
      });

      expect(service.debugPendingCallKitActionCountForTesting, 1);

      service.debugCurrentUserIdOverride = 'current-user';
      await markCallActionsReady();

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(declinedSessions, isEmpty);
    });

    test('queued CallKit decline past ttl is dropped before backend call',
        () async {
      final declinedSessions = <String>[];

      service.debugCurrentUserIdOverride = 'current-user';
      service.debugDeclineCallOverride = (sessionId) async {
        declinedSessions.add(sessionId);
      };

      await service.debugHandleCallKitDeclineEventForTesting({
        'sessionId': 'ttl-decline-session',
        'recipientId': 'current-user',
      });

      expect(service.debugPendingCallKitActionCountForTesting, 1);

      await markCallActionsReady(
        now: DateTime.now().add(const Duration(minutes: 3)),
      );

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(declinedSessions, isEmpty);
    });

    test('duplicate queued CallKit decline calls backend once', () async {
      final declinedSessions = <String>[];
      const sessionId = 'duplicate-queued-decline-session';

      service.debugCurrentUserIdOverride = 'current-user';
      service.debugDeclineCallOverride = (sessionId) async {
        declinedSessions.add(sessionId);
      };

      await service.debugHandleCallKitDeclineEventForTesting({
        'sessionId': sessionId,
        'recipientId': 'current-user',
      });
      await service.debugHandleCallKitDeclineEventForTesting({
        'sessionId': sessionId,
        'recipientId': 'current-user',
      });

      expect(service.debugPendingCallKitActionCountForTesting, 1);

      await markCallActionsReady();

      expect(service.debugPendingCallKitActionCountForTesting, 0);
      expect(declinedSessions, [sessionId]);
    });

    test('runtime decline calls backend for cold-start session events',
        () async {
      final declinedSessions = <String>[];
      service.debugDeclineCallOverride = (sessionId) async {
        declinedSessions.add(sessionId);
      };

      await service.debugHandleCallDeclineForTesting({
        'sessionId': ' session-a ',
      });

      expect(declinedSessions, ['session-a']);
    });

    test('runtime decline ignores stale CallKit ids', () async {
      final declinedSessions = <String>[];
      service.debugTrackHandledCallKitAcceptForTesting(
        sessionId: 'session-a',
        callKitId: 'expected-callkit-id',
      );
      service.debugDeclineCallOverride = (sessionId) async {
        declinedSessions.add(sessionId);
      };

      await service.debugHandleCallDeclineForTesting({
        'sessionId': 'session-a',
        'id': 'stale-callkit-id',
      });

      expect(declinedSessions, isEmpty);
      expect(
        service.debugHandledCallKitAcceptForTesting('expected-callkit-id'),
        isTrue,
      );
    });

    test('runtime decline ignores already accepted sessions', () async {
      final declinedSessions = <String>[];
      service.debugMarkAcceptedSessionForTesting('session-a');
      service.debugDeclineCallOverride = (sessionId) async {
        declinedSessions.add(sessionId);
      };

      await service.debugHandleCallDeclineForTesting({
        'sessionId': 'session-a',
      });

      expect(declinedSessions, isEmpty);
      expect(service.debugAcceptedSessionForTesting('session-a'), isTrue);
    });

    test('runtime decline ignores accept-in-progress sessions', () async {
      final declinedSessions = <String>[];
      service.debugMarkAcceptInProgressForTesting('session-a');
      service.debugDeclineCallOverride = (sessionId) async {
        declinedSessions.add(sessionId);
      };

      await service.debugHandleCallDeclineForTesting({
        'sessionId': 'session-a',
      });

      expect(declinedSessions, isEmpty);
      expect(service.debugAcceptInProgressForTesting('session-a'), isTrue);
    });

    test('runtime decline ignores duplicates while backend call is in progress',
        () async {
      final declinedSessions = <String>[];
      final backendStarted = Completer<void>();
      final releaseBackend = Completer<void>();
      service.debugDeclineCallOverride = (sessionId) async {
        declinedSessions.add(sessionId);
        if (!backendStarted.isCompleted) {
          backendStarted.complete();
        }
        await releaseBackend.future;
      };

      final firstDecline = service.debugHandleCallDeclineForTesting({
        'sessionId': 'session-a',
      });
      await backendStarted.future.timeout(const Duration(seconds: 1));

      expect(service.debugDeclineInProgressForTesting('session-a'), isTrue);

      await service.debugHandleCallDeclineForTesting({
        'sessionId': 'session-a',
      });

      expect(declinedSessions, ['session-a']);

      releaseBackend.complete();
      await firstDecline;

      expect(service.debugDeclineInProgressForTesting('session-a'), isFalse);
      expect(
          service.debugRecentlyDeclinedSessionForTesting('session-a'), isTrue);
    });

    test('runtime decline ignores duplicate events after success', () async {
      final declinedSessions = <String>[];
      service.debugDeclineCallOverride = (sessionId) async {
        declinedSessions.add(sessionId);
      };

      await service.debugHandleCallDeclineForTesting({
        'sessionId': 'session-a',
      });
      await service.debugHandleCallDeclineForTesting({
        'sessionId': 'session-a',
      });

      expect(declinedSessions, ['session-a']);
      expect(
          service.debugRecentlyDeclinedSessionForTesting('session-a'), isTrue);
    });

    test('runtime decline keeps local state when backend call fails', () async {
      service.debugTrackHandledCallKitAcceptForTesting(
        sessionId: 'session-a',
        callKitId: 'expected-callkit-id',
      );
      service.debugDeclineCallOverride = (_) async {
        throw StateError('network unavailable');
      };

      await service.debugHandleCallDeclineForTesting({
        'sessionId': 'session-a',
        'id': 'expected-callkit-id',
      });

      expect(
        service.debugHandledCallKitAcceptForTesting('expected-callkit-id'),
        isTrue,
      );
      expect(
          service.debugRecentlyDeclinedSessionForTesting('session-a'), isFalse);
      expect(service.debugDeclineInProgressForTesting('session-a'), isFalse);
    });

    test('runtime decline clears local call state after backend call',
        () async {
      final declinedSessions = <String>[];
      service.debugTrackHandledCallKitAcceptForTesting(
        sessionId: 'session-a',
        callKitId: 'expected-callkit-id',
      );
      service.debugDeclineCallOverride = (sessionId) async {
        declinedSessions.add(sessionId);
      };

      await service.debugHandleCallDeclineForTesting({
        'sessionId': 'session-a',
        'id': 'expected-callkit-id',
      });

      expect(declinedSessions, ['session-a']);
      expect(
        service.debugHandledCallKitAcceptForTesting('expected-callkit-id'),
        isFalse,
      );
    });
  });
}
