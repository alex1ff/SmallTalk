import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/deepgram_stop_single_flight.dart';

void main() {
  test('concurrent callers share one operation and identical future', () async {
    final coordinator = DeepgramStopSingleFlight();
    final operation = Completer<void>();
    var calls = 0;

    final first = coordinator.run(() {
      calls++;
      return operation.future;
    });
    final second = coordinator.run(() {
      calls++;
      return Future<void>.value();
    });

    expect(calls, 1);
    expect(identical(first, second), isTrue);
    operation.complete();
    await Future.wait<void>([first, second]);
  });

  test('operation enters synchronously after active future is installed',
      () async {
    final coordinator = DeepgramStopSingleFlight();
    final operation = Completer<void>();
    var entered = false;
    late Future<void> reentrant;

    final first = coordinator.run(() {
      entered = true;
      reentrant = coordinator.run(() {
        fail('reentrant call must not start a second operation');
      });
      return operation.future;
    });

    expect(entered, isTrue);
    expect(identical(first, reentrant), isTrue);
    operation.complete();
    await first;
  });

  test('completion listener can start a new operation', () async {
    final coordinator = DeepgramStopSingleFlight();
    final firstOperation = Completer<void>();
    final secondOperation = Completer<void>();
    var calls = 0;
    late Future<void> second;

    final first = coordinator.run(() {
      calls++;
      return firstOperation.future;
    });
    final listener = first.then<void>((_) {
      second = coordinator.run(() {
        calls++;
        return secondOperation.future;
      });
    });

    firstOperation.complete();
    await listener;
    expect(calls, 2);
    expect(identical(first, second), isFalse);
    secondOperation.complete();
    await second;
  });

  test('async error and original stack reach all waiters then allow retry',
      () async {
    final coordinator = DeepgramStopSingleFlight();
    final operation = Completer<void>();
    final error = StateError('stop failed');
    final stackTrace = StackTrace.current;
    final errors = <Object>[];
    final stackTraces = <StackTrace>[];
    var calls = 0;

    final first = coordinator.run(() {
      calls++;
      return operation.future;
    });
    final second = coordinator.run(() {
      calls++;
      return Future<void>.value();
    });
    Future<void> observe(Future<void> future) => future.then<void>(
          (_) => fail('operation must fail'),
          onError: (Object caught, StackTrace caughtStack) {
            errors.add(caught);
            stackTraces.add(caughtStack);
          },
        );
    final observations = [observe(first), observe(second)];

    operation.completeError(error, stackTrace);
    await Future.wait<void>(observations);
    expect(errors, everyElement(same(error)));
    expect(stackTraces, everyElement(same(stackTrace)));
    expect(calls, 1);

    await coordinator.run(() {
      calls++;
      return Future<void>.value();
    });
    expect(calls, 2);
  });

  test('error listener can start a new operation', () async {
    final coordinator = DeepgramStopSingleFlight();
    final firstOperation = Completer<void>();
    final secondOperation = Completer<void>();
    final error = StateError('stop failed');
    var calls = 0;
    late Future<void> second;

    final first = coordinator.run(() {
      calls++;
      return firstOperation.future;
    });
    final listener = first.then<void>(
      (_) => fail('operation must fail'),
      onError: (Object _, StackTrace __) {
        second = coordinator.run(() {
          calls++;
          return secondOperation.future;
        });
      },
    );

    firstOperation.completeError(error, StackTrace.current);
    await listener;
    expect(calls, 2);
    expect(identical(first, second), isFalse);
    secondOperation.complete();
    await second;
  });

  test('synchronous throw reaches caller and allows retry', () async {
    final coordinator = DeepgramStopSingleFlight();
    final error = StateError('synchronous stop failure');
    var calls = 0;

    final failed = coordinator.run(() {
      calls++;
      throw error;
    });
    await expectLater(failed, throwsA(same(error)));

    await coordinator.run(() {
      calls++;
      return Future<void>.value();
    });
    expect(calls, 2);
  });

  test('handled shared error does not emit a second runner error', () async {
    final coordinator = DeepgramStopSingleFlight();
    final error = StateError('observed stop failure');
    final uncaught = <Object>[];

    final zoned = runZonedGuarded<Future<void>>(
      () async {
        final shared = coordinator.run(() => Future<void>.error(error));
        await shared.then<void>(
          (_) => fail('operation must fail'),
          onError: (Object caught, StackTrace _) {
            expect(caught, same(error));
          },
        );
        await Future<void>.delayed(Duration.zero);
      },
      (caught, _) => uncaught.add(caught),
    );

    await zoned;
    await Future<void>.delayed(Duration.zero);
    expect(uncaught, isEmpty);
  });

  test('instances do not share active operations', () async {
    final first = DeepgramStopSingleFlight();
    final second = DeepgramStopSingleFlight();
    final firstOperation = Completer<void>();
    var calls = 0;

    final firstFuture = first.run(() {
      calls++;
      return firstOperation.future;
    });
    await second.run(() {
      calls++;
      return Future<void>.value();
    });

    expect(calls, 2);
    firstOperation.complete();
    await firstFuture;
  });
}
