import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/voip_pending_callkit_action_queue.dart';

void main() {
  const ttl = Duration(minutes: 2);
  final startedAt = DateTime.utc(2026, 8, 31, 12);

  VoipPendingCallKitAction action({
    required VoipPendingCallKitActionType type,
    required String sessionId,
    String? callKitId,
    String? targetUserId,
    String? queuedForUserId = 'user-a',
    DateTime? queuedAt,
    String marker = '',
  }) {
    return VoipPendingCallKitAction(
      type: type,
      data: <String, dynamic>{'marker': marker},
      sessionId: sessionId,
      callKitId: callKitId,
      targetUserId: targetUserId,
      queuedAt: queuedAt ?? startedAt,
      queuedForUserId: queuedForUserId,
    );
  }

  test('TTL keeps an action before the boundary and removes it at boundary',
      () {
    final queue = VoipPendingCallKitActionQueue(ttl: ttl, maxCount: 16)
      ..enqueue(action(
        type: VoipPendingCallKitActionType.decline,
        sessionId: 'session-a',
      ));

    queue.prune(
      now: startedAt.add(ttl).subtract(const Duration(microseconds: 1)),
      currentUserId: 'user-a',
      acceptPayloadHasExpired: (_, __) => false,
    );
    expect(queue.length, 1);

    queue.prune(
      now: startedAt.add(ttl),
      currentUserId: 'user-a',
      acceptPayloadHasExpired: (_, __) => false,
    );
    expect(queue, isEmpty);
  });

  test('higher and equal priority replace in the original queue position', () {
    final queue = VoipPendingCallKitActionQueue(ttl: ttl, maxCount: 16)
      ..enqueue(action(
        type: VoipPendingCallKitActionType.timeout,
        sessionId: 'session-a',
        callKitId: 'call-a',
        marker: 'timeout',
      ))
      ..enqueue(action(
        type: VoipPendingCallKitActionType.accept,
        sessionId: 'session-b',
        callKitId: 'call-b',
        marker: 'second',
      ))
      ..enqueue(action(
        type: VoipPendingCallKitActionType.accept,
        sessionId: 'session-a',
        callKitId: 'call-a',
        marker: 'accept',
      ))
      ..enqueue(action(
        type: VoipPendingCallKitActionType.accept,
        sessionId: 'session-a',
        callKitId: 'call-a',
        queuedAt: startedAt.add(const Duration(seconds: 1)),
        marker: 'accept-refreshed',
      ));

    expect(
        queue.items.map((item) => item.sessionId), ['session-a', 'session-b']);
    expect(queue.items.first.data['marker'], 'accept-refreshed');
    expect(
      queue.items.first.queuedAt,
      startedAt.add(const Duration(seconds: 1)),
    );
  });

  test('lower priority cannot replace and overflow evicts oldest identity', () {
    final queue = VoipPendingCallKitActionQueue(ttl: ttl, maxCount: 2)
      ..enqueue(action(
        type: VoipPendingCallKitActionType.decline,
        sessionId: 'session-a',
        marker: 'decline',
      ))
      ..enqueue(action(
        type: VoipPendingCallKitActionType.timeout,
        sessionId: 'session-a',
        marker: 'ignored-timeout',
      ))
      ..enqueue(action(
        type: VoipPendingCallKitActionType.accept,
        sessionId: 'session-b',
      ))
      ..enqueue(action(
        type: VoipPendingCallKitActionType.accept,
        sessionId: 'session-c',
      ));

    expect(
        queue.items.map((item) => item.sessionId), ['session-b', 'session-c']);
  });

  test('targeted and untargeted actions cannot cross authentication changes',
      () {
    final queue = VoipPendingCallKitActionQueue(ttl: ttl, maxCount: 16)
      ..enqueue(action(
        type: VoipPendingCallKitActionType.accept,
        sessionId: 'target-a',
        targetUserId: 'user-a',
      ))
      ..enqueue(action(
        type: VoipPendingCallKitActionType.accept,
        sessionId: 'target-b',
        targetUserId: 'user-b',
      ))
      ..enqueue(action(
        type: VoipPendingCallKitActionType.accept,
        sessionId: 'untargeted-a',
      ))
      ..enqueue(action(
        type: VoipPendingCallKitActionType.accept,
        sessionId: 'untargeted-no-auth',
        queuedForUserId: null,
      ));

    queue.prune(
      now: startedAt,
      currentUserId: 'user-a',
      acceptPayloadHasExpired: (_, __) => false,
    );
    expect(
      queue.items.map((item) => item.sessionId),
      ['target-a', 'untargeted-a'],
    );

    queue.prune(
      now: startedAt,
      currentUserId: 'user-b',
      acceptPayloadHasExpired: (_, __) => false,
    );
    expect(queue, isEmpty);
  });

  test('accept payload expiry is applied only to accept actions', () {
    final queue = VoipPendingCallKitActionQueue(ttl: ttl, maxCount: 16)
      ..enqueue(action(
        type: VoipPendingCallKitActionType.accept,
        sessionId: 'accept-a',
      ))
      ..enqueue(action(
        type: VoipPendingCallKitActionType.decline,
        sessionId: 'decline-a',
      ));

    queue.prune(
      now: startedAt,
      currentUserId: 'user-a',
      acceptPayloadHasExpired: (_, __) => true,
    );
    expect(queue.items.map((item) => item.sessionId), ['decline-a']);
  });
}
