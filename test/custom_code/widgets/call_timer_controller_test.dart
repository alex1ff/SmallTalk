import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/call_timer_controller.dart';

void main() {
  final epoch = DateTime.utc(2026, 9, 1, 12);

  test('starts immediately, owns one timer, and derives time from server', () {
    fakeAsync((async) {
      final updates = <CallTimerUpdate>[];
      final controller = CallTimerController(
        readSession: () => CallTimerSession(connectedAt: epoch),
        now: () => epoch.add(async.elapsed),
        onUpdate: updates.add,
      );
      controller.start();
      controller.start();
      expect(updates.map((update) => update.elapsedSeconds), [0]);
      expect(async.periodicTimerCount, 1);
      async.elapse(const Duration(seconds: 2));
      expect(updates.last.elapsedSeconds, 2);
      controller.serverClockOffset = const Duration(seconds: 10);
      async.elapse(const Duration(seconds: 1));
      expect(updates.last.elapsedSeconds, 13);
      controller.dispose();
      expect(async.periodicTimerCount, 0);
    });
  });

  test('stop refreshes once, restart catches up, reset reports zero', () {
    fakeAsync((async) {
      final updates = <CallTimerUpdate>[];
      final controller = CallTimerController(
        readSession: () => CallTimerSession(connectedAt: epoch),
        now: () => epoch.add(async.elapsed),
        onUpdate: updates.add,
      );
      controller.start();
      async.elapse(const Duration(seconds: 2));
      controller.stop();
      final count = updates.length;
      async.elapse(const Duration(seconds: 10));
      expect(updates.length, count);
      controller.start();
      expect(updates.last.elapsedSeconds, 12);
      controller.stop(reset: true);
      expect(updates.last.elapsedSeconds, 0);
      controller.dispose();
    });
  });

  test('checkpoint jump preserves order and history across timer stops', () {
    final updates = <CallTimerUpdate>[];
    final controller = CallTimerController(
      readSession: () => const CallTimerSession(isStudent: true),
      onUpdate: updates.add,
    );
    controller.setElapsedSeconds(600);
    expect(updates.last.checkpointMinutes, [5, 10]);
    controller.stop(reset: true);
    controller.setElapsedSeconds(600);
    expect(updates.last.checkpointMinutes, isEmpty);
    controller.clearCheckpointHistory();
    controller.setElapsedSeconds(600);
    expect(updates.last.checkpointMinutes, [5, 10]);
    controller.dispose();
  });

  test('countdown uses live session expiry and exact-expiry retry markers', () {
    var session = CallTimerSession(
      status: 'active',
      expiresAt: epoch,
      policy: const {'effectiveLimitSeconds': 300},
    );
    final updates = <CallTimerUpdate>[];
    final controller = CallTimerController(
      readSession: () => session,
      now: () => epoch.add(const Duration(seconds: 2)),
      onUpdate: updates.add,
    );
    controller.refresh();
    expect(updates.last.shouldAutoEnd, isTrue);
    controller.refresh();
    expect(updates.last.shouldAutoEnd, isFalse);
    controller.clearAutoEndRequest(epoch.subtract(const Duration(seconds: 1)));
    controller.refresh();
    expect(updates.last.shouldAutoEnd, isFalse);
    controller.clearAutoEndRequest(epoch);
    controller.refresh();
    expect(updates.last.shouldAutoEnd, isTrue);
    session = CallTimerSession(
      status: 'ended',
      expiresAt: epoch,
      policy: const {'effectiveLimitSeconds': 300},
    );
    controller.resetLimitMarkers();
    controller.refresh();
    expect(updates.last.shouldAutoEnd, isFalse);
    controller.dispose();
  });

  test('provisional countdown, null timestamp, and student gating stay intact',
      () {
    var session = const CallTimerSession(provisionalCountdown: true);
    final updates = <CallTimerUpdate>[];
    final controller = CallTimerController(
      readSession: () => session,
      now: () => epoch,
      onUpdate: updates.add,
    );
    expect(controller.authoritativeSeconds(), 0);
    expect(controller.remainingSeconds(), 300);
    controller.setElapsedSeconds(30);
    expect(controller.remainingSeconds(), 270);
    session = const CallTimerSession();
    controller.setElapsedSeconds(600);
    expect(updates.last.checkpointMinutes, isEmpty);
    session = const CallTimerSession(isStudent: true);
    controller.setElapsedSeconds(600);
    expect(updates.last.checkpointMinutes, [5, 10]);
    controller.dispose();
  });

  test('dispose from initial update cannot resurrect periodic work', () {
    fakeAsync((async) {
      var count = 0;
      late CallTimerController controller;
      controller = CallTimerController(
        readSession: () => const CallTimerSession(),
        onUpdate: (_) {
          count++;
          controller.dispose();
        },
      );
      controller.start();
      controller.start();
      controller.refresh();
      controller.stop();
      async.elapse(const Duration(minutes: 1));
      expect(count, 1);
      expect(async.periodicTimerCount, 0);
    });
  });

  test('cleanup blocks a late promotion until the next call lifetime', () {
    fakeAsync((async) {
      final updates = <CallTimerUpdate>[];
      final controller = CallTimerController(
        readSession: () => CallTimerSession(connectedAt: epoch),
        now: () => epoch.add(async.elapsed),
        onUpdate: updates.add,
      );
      controller.start();
      controller.suspend();
      final count = updates.length;
      // A markRoomJoined/markSystemCallConnected future resolves during drain.
      controller.start();
      async.elapse(const Duration(seconds: 5));
      expect(updates.length, count);
      expect(async.periodicTimerCount, 0);
      controller.stop(reset: true);
      controller.start();
      expect(async.periodicTimerCount, 0);
      controller.resume();
      controller.start();
      expect(async.periodicTimerCount, 1);
      expect(updates.last.elapsedSeconds, 5);
      controller.dispose();
    });
  });
}
