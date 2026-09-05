import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/active_search_recovery.dart';
import 'package:small_talk/services/passive_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 9, 5, 12);

  test('waiting expires at its server instant without heartbeat', () {
    final state = PassiveSearchState.fromData({
      'status': 'waiting',
      'requestId': 'consent',
      'expiresAt': Timestamp.fromDate(now.add(const Duration(minutes: 30))),
    });
    expect(state.isWaiting(now.add(const Duration(minutes: 29))), isTrue);
    expect(state.isWaiting(now.add(const Duration(minutes: 30))), isFalse);
    expect(
        PassiveSearchState.fromData({
          'status': 'stopped',
          'requestId': 'consent',
          'expiresAt': now.add(const Duration(hours: 1)),
        }).isWaiting(now),
        isFalse);
    expect(
        PassiveSearchState.fromData({
          'status': 'waiting',
          'requestId': 'consent',
        }).isWaiting(now),
        isFalse);
  });

  for (final duration in PassiveSearchDuration.values) {
    test(
        'join ${duration.value} keeps exact consent identity and server expiry',
        () async {
      final payloads = <Map<String, dynamic>>[];
      var timezoneReads = 0;
      final service = PassiveSearchService(
        readTimeZone: () async {
          timezoneReads++;
          return 'America/New_York';
        },
        invoke: (name, data) async {
          expect(name, 'joinPassiveSearch');
          payloads.add(data);
          return {
            'status': 'waiting',
            'requestId': data['requestId'],
            'expiresAt': '2026-09-06T04:00:00.000Z'
          };
        },
      );
      final result = await service.join(
          searchRequestId: 'source',
          requestId: 'consent',
          duration: duration,
          locale: 'ru');
      expect(result.sourceSearchRequestId, 'source');
      expect(result.expiresAt, DateTime.utc(2026, 9, 6, 4));
      expect(payloads.single, {
        'searchRequestId': 'source',
        'requestId': 'consent',
        'duration': duration.value,
        'locale': 'ru',
        if (duration == PassiveSearchDuration.endOfDay)
          'timeZone': 'America/New_York',
      });
      expect(timezoneReads, duration == PassiveSearchDuration.endOfDay ? 1 : 0);
    });
  }

  test('day choice reads IANA zone through the native channel', () async {
    const channel = MethodChannel('smalltalk/timezone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getTimeZone');
      return 'America/New_York';
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final service = PassiveSearchService(invoke: (_, data) async {
      expect(data['timeZone'], 'America/New_York');
      return {
        'status': 'waiting',
        'requestId': 'consent',
        'expiresAt': '2026-11-02T05:00:00Z'
      };
    });
    await service.join(
        searchRequestId: 'source',
        requestId: 'consent',
        duration: PassiveSearchDuration.endOfDay,
        locale: 'en');
  });

  test('failed stop is propagated and retry uses the same consent', () async {
    var attempts = 0;
    final service = PassiveSearchService(invoke: (name, data) async {
      expect(name, 'leavePassiveSearch');
      expect(data, {'requestId': 'consent'});
      if (++attempts == 1) throw StateError('offline');
      return {'status': 'stopped'};
    });
    await expectLater(service.leave('consent'), throwsStateError);
    expect(await service.leave('consent'), {'status': 'stopped'});
  });

  test('old ten minute attempt is capped without resetting on recovery', () {
    final data = {
      'createdAt': now,
      'expiresAt': now.add(const Duration(minutes: 10))
    };
    expect(activeSearchDeadline(data), now.add(const Duration(minutes: 2)));
    final state = ActiveSearchRecoveryState(
        userId: 'u',
        requestId: 'r',
        data: {...data, 'status': 'expired', 'stopReason': 'search_timeout'},
        exists: true,
        belongsToUser: true,
        isLiveStatus: false,
        isExpired: true);
    expect(state.canOfferPassiveQueue(now: now.add(const Duration(minutes: 1))),
        isFalse);
    expect(state.canOfferPassiveQueue(now: now.add(const Duration(minutes: 2))),
        isTrue);
    expect(
        state.remainingSearchDuration(
            now: now.add(const Duration(seconds: 100))),
        const Duration(seconds: 20));
  });

  test('manual stop and session binding cannot restore a queue offer', () {
    for (final extra in [
      {'status': 'stopped'},
      {'status': 'expired', 'stopReason': 'user_stopped'},
      {'status': 'expired', 'currentSessionId': 'session'},
    ]) {
      final state = ActiveSearchRecoveryState(
          userId: 'u',
          requestId: 'r',
          data: {'expiresAt': now, ...extra},
          exists: true,
          belongsToUser: true,
          isLiveStatus: false,
          isExpired: true);
      expect(state.canOfferPassiveQueue(now: now), isFalse);
    }
  });
}
