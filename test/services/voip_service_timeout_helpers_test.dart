import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/voip_service.dart';

void main() {
  late VoIPService service;

  setUp(() {
    service = VoIPService();
    service.debugResetInMemoryStateForTesting();
  });

  group('VoIP timeout helpers', () {
    test('runtime timeout clears tracked state from serialized extra',
        () async {
      service.debugTrackCallKitSessionForTesting(
        sessionId: 'session-a',
        callKitId: 'expected-callkit-id',
      );

      await service.debugHandleCallTimeoutForTesting({
        'id': 'expected-callkit-id',
        'extra': jsonEncode({
          'sessionId': 'session-a',
          'callKitId': 'expected-callkit-id',
        }),
      });

      expect(service.debugCallKitIdForSessionForTesting('session-a'), isNull);
    });

    test('runtime timeout ignores stale CallKit ids', () async {
      service.debugTrackCallKitSessionForTesting(
        sessionId: 'session-a',
        callKitId: 'expected-callkit-id',
      );

      await service.debugHandleCallTimeoutForTesting({
        'sessionId': 'session-a',
        'id': 'stale-callkit-id',
      });

      expect(
        service.debugCallKitIdForSessionForTesting('session-a'),
        'expected-callkit-id',
      );
    });

    test('runtime timeout ignores accepted sessions', () async {
      service.debugTrackCallKitSessionForTesting(
        sessionId: 'session-a',
        callKitId: 'expected-callkit-id',
      );
      service.debugMarkAcceptedSessionForTesting('session-a');

      await service.debugHandleCallTimeoutForTesting({
        'sessionId': 'session-a',
        'id': 'expected-callkit-id',
      });

      expect(service.debugAcceptedSessionForTesting('session-a'), isTrue);
      expect(
        service.debugCallKitIdForSessionForTesting('session-a'),
        'expected-callkit-id',
      );
    });

    test('CallKit timeout event ignores another known recipient', () async {
      service.debugCurrentUserIdOverride = 'current-user';
      service.debugTrackCallKitSessionForTesting(
        sessionId: 'session-a',
        callKitId: 'expected-callkit-id',
      );

      await service.debugHandleCallKitTimeoutEventForTesting({
        'sessionId': 'session-a',
        'recipientId': 'other-user',
        'id': 'expected-callkit-id',
      });

      expect(
        service.debugCallKitIdForSessionForTesting('session-a'),
        'expected-callkit-id',
      );
    });
  });
}
