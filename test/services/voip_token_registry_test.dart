import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/voip_token_registry.dart';

void main() {
  late List<Map<String, dynamic>> calls;
  late List<String> logs;
  String? currentUserId;
  var platform = 'ios';
  dynamic pushKitToken;

  VoipTokenRegistry registry({
    Future<void> Function(Map<String, dynamic>)? invoke,
    Future<dynamic> Function()? readPushKitToken,
  }) {
    return VoipTokenRegistry(
      currentUserId: () => currentUserId,
      invokeRegistration: invoke ??
          (payload) async {
            calls.add(Map<String, dynamic>.from(payload));
          },
      readPushKitToken: readPushKitToken ?? () async => pushKitToken,
      clientPlatform: () => platform,
      matchProtocolVersion: () => 2,
      log: logs.add,
    );
  }

  setUp(() {
    calls = <Map<String, dynamic>>[];
    logs = <String>[];
    currentUserId = 'user-a';
    platform = 'ios';
    pushKitToken = null;
  });

  test('FCM save trims token and sends the exact callable payload', () async {
    await registry().saveFcmToken('  private-fcm-token  ');

    expect(calls, [
      {
        'tokenType': 'fcm',
        'token': 'private-fcm-token',
        'platform': 'ios',
        'matchProtocolVersion': 2,
      },
    ]);
    expect(
        logs.any((message) => message.contains('private-fcm-token')), isFalse);
  });

  test('empty or unauthenticated token saves are no-ops', () async {
    final tokenRegistry = registry();

    await tokenRegistry.saveFcmToken('   ');
    currentUserId = null;
    await tokenRegistry.saveFcmToken('private-fcm-token');
    await tokenRegistry.savePushKitToken('private-push-token');

    expect(calls, isEmpty);
  });

  test('PushKit sync saves a non-empty token and removes an empty token',
      () async {
    final tokenRegistry = registry();
    pushKitToken = '  private-push-token  ';

    await tokenRegistry.syncPushKitToken();
    pushKitToken = '   ';
    await tokenRegistry.syncPushKitToken();

    expect(calls, [
      {
        'tokenType': 'pushkit',
        'token': 'private-push-token',
        'platform': 'ios',
        'matchProtocolVersion': 2,
      },
      {
        'removeTokenType': 'pushkit',
        'platform': 'ios',
        'matchProtocolVersion': 2,
      },
    ]);
  });

  test('PushKit sync ignores non-iOS platforms and non-string results',
      () async {
    var reads = 0;
    final tokenRegistry = registry(
      readPushKitToken: () async {
        reads += 1;
        return pushKitToken;
      },
    );
    platform = 'android';
    pushKitToken = 'private-push-token';

    await tokenRegistry.syncPushKitToken();
    platform = 'ios';
    pushKitToken = 42;
    await tokenRegistry.syncPushKitToken();

    expect(reads, 1);
    expect(calls, isEmpty);
  });

  test('PushKit sync ignores a null token on iOS', () async {
    var reads = 0;
    final tokenRegistry = registry(
      readPushKitToken: () async {
        reads += 1;
        return null;
      },
    );

    await tokenRegistry.syncPushKitToken();

    expect(reads, 1);
    expect(calls, isEmpty);
  });

  test('clear sends only clearAll and protocol version', () async {
    await registry().clearRegisteredTokens();

    expect(calls, [
      {
        'clearAll': true,
        'matchProtocolVersion': 2,
      },
    ]);
  });

  test('remove and clear are no-ops after logout', () async {
    currentUserId = null;
    final tokenRegistry = registry();

    await tokenRegistry.removeRegisteredToken('pushkit');
    await tokenRegistry.clearRegisteredTokens();

    expect(calls, isEmpty);
  });

  test('callable and PushKit read failures are contained without secrets',
      () async {
    final tokenRegistry = registry(
      invoke: (_) async => throw StateError('callable unavailable'),
      readPushKitToken: () async => throw StateError('pushkit unavailable'),
    );

    await tokenRegistry.saveFcmToken('private-fcm-token');
    await tokenRegistry.savePushKitToken('private-push-token');
    await tokenRegistry.removeRegisteredToken('pushkit');
    await tokenRegistry.clearRegisteredTokens();
    await tokenRegistry.syncPushKitToken();

    expect(logs, hasLength(5));
    expect(
        logs.any((message) => message.contains('private-fcm-token')), isFalse);
    expect(
        logs.any((message) => message.contains('private-push-token')), isFalse);
  });
}
