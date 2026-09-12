import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/call_chat_persistence_coordinator.dart';

void main() {
  group('CallChatPersistenceCoordinator', () {
    test('concurrent callers share one root future and one batch', () async {
      final gate = Completer<void>();
      var calls = 0;
      final coordinator = CallChatPersistenceCoordinator<String>();

      final first = coordinator.persist(
        snapshot: () => const <String>['hello'],
        persistBatch: (_) {
          calls += 1;
          return gate.future;
        },
      );
      final second = coordinator.persist(
        snapshot: () => throw StateError('second snapshot must not run'),
        persistBatch: (_) => throw StateError('second batch must not run'),
      );

      expect(identical(first, second), isTrue);
      expect(calls, 1);
      gate.complete();
      await first;
    });

    test('installs root before entering the synchronous operation', () async {
      late Future<void> reentrant;
      final coordinator = CallChatPersistenceCoordinator<String>();

      final root = coordinator.persist(
        snapshot: () => const <String>['hello'],
        persistBatch: (_) {
          reentrant = coordinator.persist(
            snapshot: () => throw StateError('reentrant snapshot must not run'),
            persistBatch: (_) =>
                throw StateError('reentrant batch must not run'),
          );
        },
      );

      expect(identical(root, reentrant), isTrue);
      await root;
    });

    test('message during first batch creates a dirty tail snapshot', () async {
      final gate = Completer<void>();
      final messages = <String>['first'];
      final batches = <List<String>>[];
      final coordinator = CallChatPersistenceCoordinator<String>();

      final root = coordinator.persist(
        snapshot: () => messages,
        persistBatch: (entries) {
          batches.add(entries);
          expect(() => entries.add('mutation'), throwsUnsupportedError);
          if (batches.length == 1) {
            messages.add('during');
            coordinator.recordMessage();
            return gate.future;
          }
        },
      );

      expect(batches, const <List<String>>[
        <String>['first'],
      ]);
      gate.complete();
      await root;
      expect(batches, const <List<String>>[
        <String>['first'],
        <String>['first', 'during'],
      ]);
    });

    test('root future waits for the complete tail chain', () async {
      final firstGate = Completer<void>();
      final tailGate = Completer<void>();
      final messages = <String>['first'];
      var calls = 0;
      var completed = false;
      final coordinator = CallChatPersistenceCoordinator<String>();

      final root = coordinator.persist(
        snapshot: () => messages,
        persistBatch: (_) {
          calls += 1;
          if (calls == 1) return firstGate.future;
          return tailGate.future;
        },
      );
      root.then<void>((_) => completed = true);

      messages.add('during');
      coordinator.recordMessage();
      firstGate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      expect(completed, isFalse);

      tailGate.complete();
      await root;
      expect(completed, isTrue);
    });

    test('caller during tail receives the same root identity', () async {
      final firstGate = Completer<void>();
      final tailGate = Completer<void>();
      final messages = <String>['first'];
      var calls = 0;
      final coordinator = CallChatPersistenceCoordinator<String>();

      final root = coordinator.persist(
        snapshot: () => messages,
        persistBatch: (_) {
          calls += 1;
          if (calls == 1) return firstGate.future;
          return tailGate.future;
        },
      );
      messages.add('during');
      coordinator.recordMessage();
      firstGate.complete();
      await Future<void>.delayed(Duration.zero);

      final duringTail = coordinator.persist(
        snapshot: () => throw StateError('tail snapshot must already exist'),
        persistBatch: (_) => throw StateError('tail batch must already exist'),
      );
      expect(identical(root, duringTail), isTrue);

      tailGate.complete();
      await root;
    });

    test('message after clean success starts a new root', () async {
      final messages = <String>['first'];
      var calls = 0;
      final coordinator = CallChatPersistenceCoordinator<String>();

      final first = coordinator.persist(
        snapshot: () => messages,
        persistBatch: (_) => calls += 1,
      );
      await first;

      messages.add('after');
      coordinator.recordMessage();
      final second = coordinator.persist(
        snapshot: () => messages,
        persistBatch: (_) => calls += 1,
      );

      expect(identical(first, second), isFalse);
      await second;
      expect(calls, 2);
    });

    test('reset during batch isolates late completion and allows new root',
        () async {
      final oldGate = Completer<void>();
      final newGate = Completer<void>();
      final oldMessages = <String>['old'];
      final newMessages = <String>['new'];
      final batches = <List<String>>[];
      final coordinator = CallChatPersistenceCoordinator<String>();

      final oldRoot = coordinator.persist(
        snapshot: () => oldMessages,
        persistBatch: (entries) {
          batches.add(entries);
          return oldGate.future;
        },
      );
      coordinator.reset();

      final newRoot = coordinator.persist(
        snapshot: () => newMessages,
        persistBatch: (entries) {
          batches.add(entries);
          return newGate.future;
        },
      );
      oldGate.complete();
      await oldRoot;

      final joinedNewRoot = coordinator.persist(
        snapshot: () => throw StateError('new root must remain active'),
        persistBatch: (_) => throw StateError('new batch must remain active'),
      );
      expect(identical(newRoot, joinedNewRoot), isTrue);
      newGate.complete();
      await newRoot;

      expect(batches, const <List<String>>[
        <String>['old'],
        <String>['new'],
      ]);
    });

    test('reset isolates a late old error from an active new root', () async {
      final oldGate = Completer<void>();
      final newGate = Completer<void>();
      final coordinator = CallChatPersistenceCoordinator<String>();

      final oldRoot = coordinator.persist(
        snapshot: () => const <String>['old'],
        persistBatch: (_) => oldGate.future,
      );
      final oldFailure = expectLater(oldRoot, throwsA(isA<StateError>()));
      coordinator.reset();

      final newRoot = coordinator.persist(
        snapshot: () => const <String>['new'],
        persistBatch: (_) => newGate.future,
      );
      oldGate.completeError(StateError('old failure'), StackTrace.current);
      await oldFailure;

      final joinedNewRoot = coordinator.persist(
        snapshot: () => throw StateError('new root must remain active'),
        persistBatch: (_) => throw StateError('new batch must remain active'),
      );
      expect(identical(newRoot, joinedNewRoot), isTrue);
      newGate.complete();
      await newRoot;
    });

    test('reset during tail prevents the old chain from reading new state',
        () async {
      final firstGate = Completer<void>();
      final tailGate = Completer<void>();
      final oldMessages = <String>['old'];
      final batches = <List<String>>[];
      final coordinator = CallChatPersistenceCoordinator<String>();

      final oldRoot = coordinator.persist(
        snapshot: () => oldMessages,
        persistBatch: (entries) {
          batches.add(entries);
          if (batches.length == 1) return firstGate.future;
          return tailGate.future;
        },
      );
      oldMessages.add('old-tail');
      coordinator.recordMessage();
      firstGate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(batches.length, 2);

      coordinator.reset();
      final newRoot = coordinator.persist(
        snapshot: () => const <String>['new'],
        persistBatch: (entries) => batches.add(entries),
      );
      await newRoot;
      tailGate.complete();
      await oldRoot;

      expect(batches, const <List<String>>[
        <String>['old'],
        <String>['old', 'old-tail'],
        <String>['new'],
      ]);
    });

    test('sync and async failures preserve error stack without automatic retry',
        () async {
      final syncCoordinator = CallChatPersistenceCoordinator<String>();
      var syncCalls = 0;
      final syncFuture = syncCoordinator.persist(
        snapshot: () => const <String>['sync'],
        persistBatch: (_) {
          syncCalls += 1;
          throw StateError('sync failure');
        },
      );
      Object? observedSyncError;
      StackTrace? observedSyncStack;
      try {
        await syncFuture;
      } catch (error, stackTrace) {
        observedSyncError = error;
        observedSyncStack = stackTrace;
      }
      expect(observedSyncError, isA<StateError>());
      expect(
        observedSyncStack.toString(),
        contains('call_chat_persistence_coordinator.dart'),
      );
      expect(syncCalls, 1);

      final asyncCoordinator = CallChatPersistenceCoordinator<String>();
      var asyncCalls = 0;
      final asyncError = StateError('async failure');
      final asyncFuture = asyncCoordinator.persist(
        snapshot: () => const <String>['async'],
        persistBatch: (_) {
          asyncCalls += 1;
          return Future<void>.error(asyncError, StackTrace.current);
        },
      );
      await expectLater(asyncFuture, throwsA(same(asyncError)));
      expect(asyncCalls, 1);
    });

    test('tail failure is observable through root without a second request',
        () async {
      final firstGate = Completer<void>();
      final messages = <String>['first'];
      var calls = 0;
      final coordinator = CallChatPersistenceCoordinator<String>();

      final root = coordinator.persist(
        snapshot: () => messages,
        persistBatch: (_) {
          calls += 1;
          if (calls == 1) return firstGate.future;
          return Future<void>.error(StateError('tail failure'));
        },
      );
      messages.add('during');
      coordinator.recordMessage();
      firstGate.complete();

      await expectLater(root, throwsA(isA<StateError>()));
      expect(calls, 2);
    });

    test('custom maxAttempts bounds dirty tails and default is three',
        () async {
      expect(
        CallChatPersistenceCoordinator<String>().maxAttempts,
        3,
      );
      expect(
        () => CallChatPersistenceCoordinator<String>(maxAttempts: 0),
        throwsArgumentError,
      );
      final messages = <String>['first'];
      var calls = 0;
      final coordinator =
          CallChatPersistenceCoordinator<String>(maxAttempts: 2);

      final root = coordinator.persist(
        snapshot: () => messages,
        persistBatch: (_) {
          calls += 1;
          messages.add('dirty-$calls');
          coordinator.recordMessage();
        },
      );

      await root;
      expect(calls, 2);
    });

    test('completeWithoutRequest joins active root and respects generation',
        () async {
      final gate = Completer<void>();
      final coordinator = CallChatPersistenceCoordinator<String>();
      final initialGeneration = coordinator.generation;
      final root = coordinator.persist(
        snapshot: () => const <String>['active'],
        persistBatch: (_) => gate.future,
      );
      final joined = coordinator.completeWithoutRequest(
        expectedGeneration: initialGeneration,
      );

      expect(identical(root, joined), isTrue);
      coordinator.reset();
      final stale = coordinator.completeWithoutRequest(
        expectedGeneration: initialGeneration,
      );
      await stale;
      final stalePersist = coordinator.persist(
        expectedGeneration: initialGeneration,
        snapshot: () => throw StateError('stale snapshot must not run'),
        persistBatch: (_) => throw StateError('stale batch must not run'),
      );
      await stalePersist;

      var calls = 0;
      final current = coordinator.completeWithoutRequest(
        expectedGeneration: coordinator.generation,
      );
      await current;
      await coordinator.persist(
        snapshot: () => throw StateError('completed state must be a no-op'),
        persistBatch: (_) => calls += 1,
      );
      expect(calls, 0);

      gate.complete();
      await root;
    });

    test('coordinator instances keep independent state', () async {
      final gate = Completer<void>();
      var firstCalls = 0;
      var secondCalls = 0;
      final firstCoordinator = CallChatPersistenceCoordinator<String>();
      final secondCoordinator = CallChatPersistenceCoordinator<String>();

      final first = firstCoordinator.persist(
        snapshot: () => const <String>['first'],
        persistBatch: (_) {
          firstCalls += 1;
          return gate.future;
        },
      );
      final second = secondCoordinator.persist(
        snapshot: () => const <String>['second'],
        persistBatch: (_) => secondCalls += 1,
      );

      await second;
      expect(identical(first, second), isFalse);
      expect(firstCalls, 1);
      expect(secondCalls, 1);
      gate.complete();
      await first;
    });
  });
}
