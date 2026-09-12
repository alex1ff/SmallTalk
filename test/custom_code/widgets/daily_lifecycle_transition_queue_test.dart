import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/daily_lifecycle_transition_queue.dart';

void main() {
  test('callbacks are deferred and execute FIFO without overlap', () async {
    final queue = DailyLifecycleTransitionQueue();
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final secondStarted = Completer<void>();
    final releaseSecond = Completer<void>();
    final trace = <String>[];
    var firstFinished = false;

    final first = queue.enqueue((id) async {
      trace.add('first:start');
      firstStarted.complete();
      await releaseFirst.future;
      trace.add('first:end');
    });
    final observedFirst = first.then((_) => firstFinished = true);
    expect(trace, isEmpty);
    await firstStarted.future;
    final second = queue.enqueue((id) async {
      trace.add('second:start');
      secondStarted.complete();
      await releaseSecond.future;
      trace.add('second:end');
    });
    final third = queue.enqueue((id) async => trace.add('third'));
    await Future<void>.value();
    expect(trace, ['first:start']);
    expect(firstFinished, isFalse);

    releaseFirst.complete();
    await observedFirst;
    await secondStarted.future;
    expect(firstFinished, isTrue);
    expect(trace, ['first:start', 'first:end', 'second:start']);
    releaseSecond.complete();
    await Future.wait([second, third]);
    expect(trace,
        ['first:start', 'first:end', 'second:start', 'second:end', 'third']);
  });

  test('enqueue immediately supersedes the active token before next start',
      () async {
    final queue = DailyLifecycleTransitionQueue();
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    late int activeId;
    bool? currentAfterAwait;
    int? nextId;

    final first = queue.enqueue((id) async {
      activeId = id;
      firstStarted.complete();
      await releaseFirst.future;
      currentAfterAwait = queue.isCurrent(id);
    });
    await firstStarted.future;
    expect(queue.isCurrent(activeId), isTrue);
    final second = queue.enqueue((id) async => nextId = id);
    expect(queue.isCurrent(activeId), isFalse);
    expect(nextId, isNull);

    releaseFirst.complete();
    await Future.wait([first, second]);
    expect(currentAfterAwait, isFalse);
    expect(nextId, activeId + 1);
    expect(queue.isCurrent(nextId!), isTrue);
  });

  test('superseded queued callbacks still run; guard owns skipping effects',
      () async {
    final queue = DailyLifecycleTransitionQueue();
    final tokens = <int>[];
    final current = <bool>[];
    final effects = <int>[];
    Future<void> action(int id) async {
      tokens.add(id);
      current.add(queue.isCurrent(id));
      if (!queue.isCurrent(id)) return;
      effects.add(id);
    }

    final first = queue.enqueue(action);
    final second = queue.enqueue(action);
    final third = queue.enqueue(action);
    await Future.wait([first, second, third]);
    expect(tokens, [1, 2, 3]);
    expect(current, [false, false, true]);
    expect(effects, [3]);
  });

  test('invalidate before execution keeps callback but makes its token stale',
      () async {
    final queue = DailyLifecycleTransitionQueue();
    var invoked = false;
    var effectRan = false;
    final pending = queue.enqueue((id) async {
      invoked = true;
      if (!queue.isCurrent(id)) return;
      effectRan = true;
    });
    queue.invalidate();
    await pending;
    expect(invoked, isTrue);
    expect(effectRan, isFalse);

    await queue.enqueue((id) async {
      expect(id, 3);
      expect(queue.isCurrent(id), isTrue);
    });
  });

  test('invalidation does not release a blocked action or reset the chain',
      () async {
    final queue = DailyLifecycleTransitionQueue();
    final started = Completer<void>();
    final release = Completer<void>();
    final trace = <String>[];
    late int activeId;
    final old = queue.enqueue((id) async {
      activeId = id;
      trace.add('old:start');
      started.complete();
      await release.future;
      trace.add('old:complete');
      if (!queue.isCurrent(id)) return;
      trace.add('old:promotion');
    });
    await started.future;
    queue.invalidate();
    expect(queue.isCurrent(activeId), isFalse);
    final fresh = queue.enqueue((id) async {
      expect(queue.isCurrent(id), isTrue);
      trace.add('fresh');
    });
    await Future<void>.value();
    expect(trace, ['old:start']);

    release.complete();
    await Future.wait([old, fresh]);
    expect(trace, ['old:start', 'old:complete', 'fresh']);
  });

  test('guard after await blocks promotion when a newer transition is queued',
      () async {
    final queue = DailyLifecycleTransitionQueue();
    final inputsStarted = Completer<void>();
    final inputsCompleted = Completer<void>();
    final effects = <String>[];
    final foreground = queue.enqueue((id) async {
      if (!queue.isCurrent(id)) return;
      effects.add('inputs');
      inputsStarted.complete();
      await inputsCompleted.future;
      if (!queue.isCurrent(id)) return;
      effects.add('promote');
    });
    await inputsStarted.future;
    final background = queue.enqueue((id) async {
      if (!queue.isCurrent(id)) return;
      effects.add('background');
    });
    inputsCompleted.complete();
    await Future.wait([foreground, background]);
    expect(effects, ['inputs', 'background']);
  });

  test('async failure reaches caller unchanged and next action still runs',
      () async {
    final queue = DailyLifecycleTransitionQueue();
    final started = Completer<void>();
    final release = Completer<void>();
    final error = StateError('async lifecycle failure');
    var nextRan = false;
    final failed = queue.enqueue((id) async {
      started.complete();
      await release.future;
    });
    final failureAssertion = expectLater(failed, throwsA(same(error)));
    await started.future;
    final next = queue.enqueue((id) async => nextRan = true);
    expect(nextRan, isFalse);
    release.completeError(error);
    await failureAssertion;
    await next;
    expect(nextRan, isTrue);
  });

  test('synchronous throw reaches caller unchanged without poisoning queue',
      () async {
    final queue = DailyLifecycleTransitionQueue();
    final error = StateError('sync lifecycle failure');
    final failed = queue.enqueue((id) => throw error);
    final failureAssertion = expectLater(failed, throwsA(same(error)));
    var nextRan = false;
    final next = queue.enqueue((id) async => nextRan = true);
    await failureAssertion;
    await next;
    expect(nextRan, isTrue);
  });

  test('separate widget queues do not share execution or invalidation',
      () async {
    final firstQueue = DailyLifecycleTransitionQueue();
    final secondQueue = DailyLifecycleTransitionQueue();
    final started = Completer<void>();
    final release = Completer<void>();
    late int firstId;
    final first = firstQueue.enqueue((id) async {
      firstId = id;
      started.complete();
      await release.future;
    });
    await started.future;
    await secondQueue.enqueue((id) async {
      secondQueue.invalidate();
      expect(secondQueue.isCurrent(id), isFalse);
      expect(firstQueue.isCurrent(firstId), isTrue);
    });
    release.complete();
    await first;
  });

  for (final throwsSynchronously in [true, false]) {
    test('error observer runs once; synchronous throw: $throwsSynchronously',
        () async {
      final reported = <Object>[];
      final queue = DailyLifecycleTransitionQueue(onError: reported.add);
      final error = StateError('reported lifecycle failure');
      final failure = queue.enqueue((id) {
        if (throwsSynchronously) throw error;
        return Future<void>.error(error);
      });
      await expectLater(failure, throwsA(same(error)));
      await queue.enqueue((id) async {});
      queue.invalidate();
      await queue.enqueue((id) async {});
      expect(reported, [same(error)]);
    });
  }
}
