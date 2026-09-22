import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/voip_navigation_coordinator.dart';

void main() {
  const requestA = VoipNavigationRequest(
    sessionId: 'session-a',
    isTutor: false,
    roomUrl: 'https://original.example/room',
    meetingToken: 'original-token',
    roomName: 'original-room',
  );
  const requestB = VoipNavigationRequest(
    sessionId: 'session-b',
    isTutor: false,
  );

  test('target omits blanks and prefers provided effective credentials', () {
    final target = VoipNavigationTarget.fromRequest(
      requestA,
      effectiveRoomUrl: 'https://effective.example/room',
      effectiveMeetingToken: 'effective-token',
      effectiveRoomName: 'effective-room',
    );
    final blankTarget = VoipNavigationTarget.fromRequest(
      const VoipNavigationRequest(
        sessionId: 'session-blank',
        isTutor: true,
        roomUrl: '  ',
        meetingToken: '',
        roomName: '\t',
      ),
    );

    expect(target.path, '/videoCallPage');
    expect(target.queryParameters, <String, String>{
      'videoDocRef': 'session-a',
      'roomUrl': 'https://effective.example/room',
      'meetingToken': 'effective-token',
      'roomName': 'effective-room',
    });
    expect(
      blankTarget.queryParameters,
      <String, String>{'videoDocRef': 'session-blank'},
    );
  });

  test('context unavailable retries the same pending request', () async {
    final attempted = <String>[];
    var contextReady = false;
    final coordinator = VoipNavigationCoordinator(
      attempt: (target) {
        attempted.add(target.sessionId);
        return contextReady;
      },
      delay: (_) async {
        contextReady = true;
      },
    );

    await coordinator.requestNavigation(requestA);

    expect(attempted, ['session-a', 'session-a']);
    expect(coordinator.hasPendingNavigation, isFalse);
    expect(coordinator.lastNavigatedSessionId, 'session-a');
  });

  test('defaults preserve the facade retry budget and interval', () {
    final coordinator = VoipNavigationCoordinator(attempt: (_) => true);

    expect(coordinator.maxAttempts, 600);
    expect(coordinator.retryDelay, const Duration(milliseconds: 100));
  });

  test('cleared A followed by queued B navigates only B', () async {
    final delay = Completer<void>();
    final attempted = <String>[];
    final coordinator = VoipNavigationCoordinator(
      attempt: (target) {
        attempted.add(target.sessionId);
        return target.sessionId == 'session-b';
      },
      delay: (_) => delay.future,
    );

    final first = coordinator.requestNavigation(requestA);
    expect(attempted, ['session-a']);
    coordinator.clearPending(sessionId: 'session-a');

    final replacement = coordinator.requestNavigation(requestB);
    expect(identical(first, replacement), isTrue);
    delay.complete();
    await first;

    expect(attempted, ['session-a', 'session-b']);
    expect(coordinator.lastNavigatedSessionId, 'session-b');
  });

  test('B replaces A while the A attempt is awaiting', () async {
    final aAttempt = Completer<bool>();
    final attempted = <String>[];
    final coordinator = VoipNavigationCoordinator(
      attempt: (target) {
        attempted.add(target.sessionId);
        if (target.sessionId == 'session-a') return aAttempt.future;
        return true;
      },
      delay: (_) async {},
    );

    final first = coordinator.requestNavigation(requestA);
    final replacement = coordinator.requestNavigation(requestB);
    expect(identical(first, replacement), isTrue);

    aAttempt.complete(true);
    await first;

    expect(attempted, ['session-a', 'session-b']);
    expect(coordinator.lastNavigatedSessionId, 'session-b');
  });

  test('duplicate same session and role is a no-op', () async {
    var attempts = 0;
    final coordinator = VoipNavigationCoordinator(
      attempt: (_) {
        attempts++;
        return true;
      },
    );

    await coordinator.requestNavigation(requestA);
    await coordinator.requestNavigation(requestA);

    expect(attempts, 1);
  });

  test('same session with a different role navigates again', () async {
    final roles = <bool>[];
    final coordinator = VoipNavigationCoordinator(
      attempt: (target) {
        roles.add(target.isTutor);
        return true;
      },
    );

    await coordinator.requestNavigation(requestA);
    await coordinator.requestNavigation(
      const VoipNavigationRequest(
        sessionId: 'session-a',
        isTutor: true,
      ),
    );

    expect(roles, [false, true]);
  });

  test('clearing the last navigation allows the same request again', () async {
    var attempts = 0;
    final coordinator = VoipNavigationCoordinator(
      attempt: (_) {
        attempts++;
        return true;
      },
    );

    await coordinator.requestNavigation(requestA);
    coordinator.clearLastNavigation();
    await coordinator.requestNavigation(requestA);

    expect(attempts, 2);
  });

  test('reset during an attempt invalidates its late completion', () async {
    final attempt = Completer<bool>();
    final coordinator = VoipNavigationCoordinator(
      attempt: (_) => attempt.future,
    );

    final navigation = coordinator.requestNavigation(requestA);
    coordinator.reset();
    attempt.complete(true);
    await navigation;

    expect(coordinator.hasPendingNavigation, isFalse);
    expect(coordinator.lastNavigatedSessionId, isNull);
    expect(coordinator.lastNavigatedIsTutor, isNull);
  });

  test('max attempts clears pending navigation', () async {
    var attempts = 0;
    var delays = 0;
    var exhausted = 0;
    final coordinator = VoipNavigationCoordinator(
      attempt: (_) {
        attempts++;
        return false;
      },
      delay: (_) async {
        delays++;
      },
      onRetryExhausted: () {
        exhausted++;
      },
      maxAttempts: 3,
    );

    await coordinator.requestNavigation(requestA);

    expect(attempts, 3);
    expect(delays, 3);
    expect(exhausted, 1);
    expect(coordinator.hasPendingNavigation, isFalse);
    expect(coordinator.lastNavigatedSessionId, isNull);
  });

  test('replacement keeps the active retry attempt budget', () async {
    final attempted = <String>[];
    late final VoipNavigationCoordinator coordinator;
    coordinator = VoipNavigationCoordinator(
      attempt: (target) {
        attempted.add(target.sessionId);
        return false;
      },
      delay: (_) async {
        if (attempted.length == 1) {
          unawaited(coordinator.requestNavigation(requestB));
        }
      },
      maxAttempts: 2,
    );

    await coordinator.requestNavigation(requestA);

    expect(attempted, ['session-a', 'session-b']);
    expect(coordinator.hasPendingNavigation, isFalse);
  });

  test('debug strings do not expose token or room URL', () {
    final target = VoipNavigationTarget.fromRequest(requestA);

    for (final debugValue in [requestA.toString(), target.toString()]) {
      expect(debugValue, isNot(contains('original-token')));
      expect(debugValue, isNot(contains('original.example')));
    }
  });
}
