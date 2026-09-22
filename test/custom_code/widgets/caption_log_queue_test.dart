import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/caption_log_queue.dart';

void main() {
  test('empty flush does not invoke persistence', () async {
    final queue = CaptionLogQueue<String>();
    var calls = 0;
    final result = await queue.flush((entries) async {
      calls++;
      return true;
    });
    expect(result, CaptionLogFlushOutcome.empty);
    expect(calls, 0);
  });

  test('success acknowledges snapshot and suppresses persisted duplicate',
      () async {
    final queue = CaptionLogQueue<String>();
    expect(queue.enqueue('a', 'first'), isTrue);
    expect(queue.enqueue('b', 'second'), isTrue);
    expect(queue.pendingCount, 2);

    List<CaptionLogQueueEntry<String>>? written;
    expect(
        await queue.flush((entries) async {
          written = entries;
          return true;
        }),
        CaptionLogFlushOutcome.persisted);
    expect(written, [(id: 'a', value: 'first'), (id: 'b', value: 'second')]);
    expect(queue.isEmpty, isTrue);
    expect(queue.enqueue('a', 'duplicate'), isFalse);

    queue.reset();
    expect(queue.enqueue('a', 'new session'), isTrue);
  });

  test('unavailable persistence retains pending and is not empty success',
      () async {
    final queue = CaptionLogQueue<String>()..enqueue('a', 'value');
    expect(await queue.flush((entries) async => false),
        CaptionLogFlushOutcome.unavailable);
    expect(queue.pendingCount, 1);
    expect(await queue.flush((entries) async => true),
        CaptionLogFlushOutcome.persisted);
    expect(queue.isEmpty, isTrue);
  });

  test('same-id replacement during commit survives old acknowledgement',
      () async {
    final queue = CaptionLogQueue<String>()..enqueue('same', 'old');
    final started = Completer<List<CaptionLogQueueEntry<String>>>();
    final release = Completer<bool>();
    final first = queue.flush((entries) {
      started.complete(entries);
      return release.future;
    });
    expect(await started.future, [(id: 'same', value: 'old')]);

    expect(queue.enqueue('same', 'replacement'), isTrue);
    release.complete(true);
    expect(await first, CaptionLogFlushOutcome.persisted);
    expect(queue.pendingCount, 1);
    // Old acknowledgement must not mark the ID persisted.
    expect(queue.enqueue('same', 'latest'), isTrue);

    List<CaptionLogQueueEntry<String>>? secondSnapshot;
    expect(
        await queue.flush((entries) async {
          secondSnapshot = entries;
          return true;
        }),
        CaptionLogFlushOutcome.persisted);
    expect(secondSnapshot, [(id: 'same', value: 'latest')]);
    expect(queue.isEmpty, isTrue);
    expect(queue.enqueue('same', 'after persist'), isFalse);
  });

  test('reset during successful commit isolates new same-id entry', () async {
    final queue = CaptionLogQueue<String>()..enqueue('same', 'session A');
    final started = Completer<void>();
    final release = Completer<bool>();
    final oldFlush = queue.flush((entries) {
      started.complete();
      return release.future;
    });
    await started.future;

    queue.reset();
    expect(queue.enqueue('same', 'session B'), isTrue);
    release.complete(true);
    expect(await oldFlush, CaptionLogFlushOutcome.stale);
    expect(queue.pendingCount, 1);
    expect(queue.enqueue('same', 'session B latest'), isTrue);

    List<CaptionLogQueueEntry<String>>? written;
    await queue.flush((entries) async {
      written = entries;
      return true;
    });
    expect(written, [(id: 'same', value: 'session B latest')]);
  });

  test('queued old-generation flush never reads new-generation entries',
      () async {
    final queue = CaptionLogQueue<String>()..enqueue('old', 'session A');
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<bool>();
    var secondPersistCalls = 0;
    final first = queue.flush((entries) {
      firstStarted.complete();
      return releaseFirst.future;
    });
    await firstStarted.future;
    final second = queue.flush((entries) async {
      secondPersistCalls++;
      return true;
    });

    queue.reset();
    queue.enqueue('new', 'session B');
    releaseFirst.complete(true);
    expect(await first, CaptionLogFlushOutcome.stale);
    expect(await second, CaptionLogFlushOutcome.stale);
    expect(secondPersistCalls, 0);
    expect(queue.pendingCount, 1);

    List<CaptionLogQueueEntry<String>>? written;
    await queue.flush((entries) async {
      written = entries;
      return true;
    });
    expect(written, [(id: 'new', value: 'session B')]);
  });

  test('flush callbacks execute strictly serially', () async {
    final queue = CaptionLogQueue<String>()..enqueue('a', 'one');
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<bool>();
    var active = 0;
    var maxActive = 0;
    final trace = <String>[];

    final first = queue.flush((entries) async {
      active++;
      if (active > maxActive) maxActive = active;
      trace.add('first:start');
      firstStarted.complete();
      final committed = await releaseFirst.future;
      trace.add('first:end');
      active--;
      return committed;
    });
    await firstStarted.future;
    queue.enqueue('b', 'two');
    final second = queue.flush((entries) async {
      active++;
      if (active > maxActive) maxActive = active;
      trace.add('second');
      active--;
      return true;
    });
    await Future<void>.value();
    expect(trace, ['first:start']);

    releaseFirst.complete(true);
    expect(await first, CaptionLogFlushOutcome.persisted);
    expect(await second, CaptionLogFlushOutcome.persisted);
    expect(maxActive, 1);
    expect(trace, ['first:start', 'first:end', 'second']);
    expect(queue.isEmpty, isTrue);
  });

  for (final synchronous in [true, false]) {
    test(
        'current error reaches caller and serial chain recovers (sync $synchronous)',
        () async {
      final queue = CaptionLogQueue<String>()..enqueue('a', 'value');
      final error = StateError('write failed');
      final failed = queue.flush((entries) {
        if (synchronous) throw error;
        return Future<bool>.error(error);
      });
      await expectLater(failed, throwsA(same(error)));
      expect(queue.pendingCount, 1);

      expect(await queue.flush((entries) async => true),
          CaptionLogFlushOutcome.persisted);
      expect(queue.isEmpty, isTrue);
    });
  }

  test('stale error cannot enter retry path of new generation', () async {
    final queue = CaptionLogQueue<String>()..enqueue('a', 'session A');
    final started = Completer<void>();
    final release = Completer<void>();
    final error = StateError('old failure');
    final failed = queue.flush((entries) async {
      started.complete();
      await release.future;
      throw error;
    });
    await started.future;
    queue.reset();
    queue.enqueue('a', 'session B');
    release.complete();

    expect(await failed, CaptionLogFlushOutcome.stale);
    expect(queue.pendingCount, 1);
    expect(await queue.flush((entries) async => true),
        CaptionLogFlushOutcome.persisted);
  });

  test('persist callback receives an immutable snapshot', () async {
    final queue = CaptionLogQueue<String>()..enqueue('a', 'value');
    await queue.flush((entries) async {
      expect(
          () => entries.add((id: 'b', value: 'other')), throwsUnsupportedError);
      return true;
    });
  });
}
