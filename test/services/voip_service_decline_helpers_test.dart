import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/voip_service.dart';

void main() {
  late VoIPService service;

  setUp(() {
    service = VoIPService();
    service.debugResetInMemoryStateForTesting();
  });

  group('VoIP decline helpers', () {
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
