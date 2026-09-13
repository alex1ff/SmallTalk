import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/daily_session_controller.dart';

void main() {
  test('opens in order and closes one captured client in cleanup order',
      () async {
    final harness = _Harness();
    expect(await harness.owner.open(), DailySessionOpenResult.opened);
    expect(harness.trace,
        ['create', 'prepare', 'events', 'join', 'publishing', 'inputs']);
    expect(harness.owner.client, same(harness.client));
    expect(harness.owner.isCurrent(harness.client), isTrue);

    final closed = harness.owner.close();
    expect(harness.owner.isClosing, isTrue);
    expect(harness.owner.isCurrent(harness.client), isFalse);
    expect(harness.owner.client, same(harness.client));
    await closed;
    expect(harness.trace, [
      'create',
      'prepare',
      'events',
      'join',
      'publishing',
      'inputs',
      'cancel-events',
      'disable',
      'captions',
      'leave',
      'detach',
      'dispose',
    ]);
    expect(harness.owner.client, isNull);
    expect(harness.owner.isClosing, isFalse);
    expect(harness.errors, isEmpty);
  });

  test('concurrent starts return the same future and create only once',
      () async {
    final create = Completer<_Client>();
    final harness = _Harness(create: () => create.future);
    final first = harness.owner.open();
    final second = harness.owner.open();
    expect(second, same(first));
    expect(harness.trace, ['create']);
    create.complete(harness.client);
    expect(await first, DailySessionOpenResult.opened);
    expect(await harness.owner.open(), DailySessionOpenResult.opened);
    expect(harness.trace.where((step) => step == 'create'), hasLength(1));
    await harness.owner.close();
  });

  test('duplicate starts waiting on another lease still create only once',
      () async {
    final lease = DailySessionLease();
    final first = _Harness(lease: lease);
    final second = _Harness(lease: lease);
    await first.owner.open();
    final waiting = second.owner.open();
    expect(second.owner.open(), same(waiting));
    expect(second.trace, isEmpty);
    await first.owner.close();
    expect(await waiting, DailySessionOpenResult.opened);
    expect(second.trace.where((step) => step == 'create'), hasLength(1));
    await second.owner.close();
  });

  test('lease wait returns busy after two seconds and can be retried', () {
    fakeAsync((clock) {
      final lease = DailySessionLease();
      final first = _Harness(lease: lease);
      final second = _Harness(lease: lease);
      first.owner.open();
      clock.flushMicrotasks();
      DailySessionOpenResult? result;
      second.owner.open().then((value) => result = value);
      clock.elapse(const Duration(milliseconds: 1999));
      expect(result, isNull);
      clock.elapse(const Duration(milliseconds: 1));
      expect(result, DailySessionOpenResult.busy);
      expect(second.trace, isEmpty);
      first.owner.close();
      clock.flushMicrotasks();
      second.owner.open().then((value) => result = value);
      clock.flushMicrotasks();
      expect(result, DailySessionOpenResult.opened);
      second.owner.close();
      clock.flushMicrotasks();
    });
  });

  test('competing waiters cannot both acquire a newly released lease', () {
    fakeAsync((clock) {
      final lease = DailySessionLease();
      final first = _Harness(lease: lease);
      final second = _Harness(lease: lease);
      final third = _Harness(lease: lease);
      first.owner.open();
      clock.flushMicrotasks();
      final results = <DailySessionOpenResult>[];
      second.owner.open().then(results.add);
      third.owner.open().then(results.add);
      first.owner.close();
      clock.flushMicrotasks();
      expect(
          results,
          unorderedEquals([
            DailySessionOpenResult.opened,
            DailySessionOpenResult.busy,
          ]));
      expect([...second.trace, ...third.trace].where((s) => s == 'create'),
          hasLength(1));
      second.owner.close();
      third.owner.close();
      clock.flushMicrotasks();
    });
  });

  test('creation timeout retains lease until late resource disposal completes',
      () {
    fakeAsync((clock) {
      final lease = DailySessionLease();
      final create = Completer<_Client>();
      final dispose = Completer<void>();
      final first = _Harness(
          lease: lease,
          create: () => create.future,
          dispose: (_) => dispose.future);
      final second = _Harness(lease: lease);
      Object? failure;
      first.owner.open().catchError((Object error) {
        failure = error;
        return DailySessionOpenResult.cancelled;
      });
      clock.elapse(const Duration(milliseconds: 9999));
      expect(failure, isNull);
      clock.elapse(const Duration(milliseconds: 1));
      expect(failure, isA<TimeoutException>());
      expect(first.errors, ['create_timeout']);
      expect(first.owner.isClosing, isTrue);
      bool closed = false;
      first.owner.close(leaveCall: false).then((_) => closed = true);
      DailySessionOpenResult? waiting;
      second.owner.open().then((value) => waiting = value);
      clock.flushMicrotasks();
      expect(waiting, DailySessionOpenResult.quarantined);
      create.complete(first.client);
      clock.flushMicrotasks();
      expect(
          first.trace, ['create', 'disable', 'captions', 'detach', 'dispose']);
      expect(closed, isFalse);
      second.owner.open().then((value) => waiting = value);
      clock.flushMicrotasks();
      expect(waiting, DailySessionOpenResult.quarantined);
      dispose.complete();
      clock.flushMicrotasks();
      expect(closed, isTrue);
      second.owner.open().then((value) => waiting = value);
      clock.flushMicrotasks();
      expect(waiting, DailySessionOpenResult.opened);
      second.owner.close();
      clock.flushMicrotasks();
    });
  });

  test('late creation error after timeout is observed and releases lease', () {
    fakeAsync((clock) {
      final lease = DailySessionLease();
      final create = Completer<_Client>();
      final first = _Harness(lease: lease, create: () => create.future);
      final second = _Harness(lease: lease);
      first.owner
          .open()
          .catchError((Object _) => DailySessionOpenResult.cancelled);
      clock.elapse(const Duration(seconds: 10));
      create.completeError(StateError('secret meeting token'));
      clock.flushMicrotasks();
      expect(first.errors, ['create_timeout', 'create_after_close']);
      expect(first.trace, ['create', 'captions', 'detach']);
      DailySessionOpenResult? result;
      second.owner.open().then((value) => result = value);
      clock.flushMicrotasks();
      expect(result, DailySessionOpenResult.opened);
      second.owner.close();
      clock.flushMicrotasks();
    });
  });

  test('stop before creation returns cancelled and disposes late client once',
      () async {
    final create = Completer<_Client>();
    final harness = _Harness(create: () => create.future);
    final opened = harness.owner.open();
    final closed = harness.owner.close();
    expect(await opened, DailySessionOpenResult.cancelled);
    expect(harness.owner.close(), same(closed));
    expect(harness.owner.isClosing, isTrue);
    create.complete(harness.client);
    await closed;
    expect(harness.trace,
        ['create', 'disable', 'captions', 'leave', 'detach', 'dispose']);
  });

  test('stop during join blocks configuration and waits before disposing',
      () async {
    final join = Completer<void>();
    final joined = Completer<void>();
    final harness = _Harness(join: (_) {
      joined.complete();
      return join.future;
    });
    final opened = harness.owner.open();
    await joined.future;
    final closed = harness.owner.close();
    expect(await opened, DailySessionOpenResult.cancelled);
    expect(harness.trace,
        ['create', 'prepare', 'events', 'join', 'cancel-events']);
    join.complete();
    await closed;
    expect(harness.trace, [
      'create',
      'prepare',
      'events',
      'join',
      'cancel-events',
      'disable',
      'captions',
      'leave',
      'detach',
      'dispose',
    ]);
  });

  test('stop during configuration prevents following configuration effects',
      () async {
    final configure = Completer<void>();
    final started = Completer<void>();
    final harness = _Harness(publishing: (_) {
      started.complete();
      return configure.future;
    });
    final opened = harness.owner.open();
    await started.future;
    final closed = harness.owner.close();
    expect(await opened, DailySessionOpenResult.cancelled);
    configure.complete();
    await closed;
    expect(harness.trace, isNot(contains('inputs')));
  });

  test('events and stream errors are synchronously guarded on close', () async {
    final harness = _Harness();
    await harness.owner.open();
    harness.client.events.add('active');
    harness.client.events.addError(StateError('active'));
    expect(harness.received, ['active', 'event-error']);
    final closed = harness.owner.close();
    harness.client.events.add('stale');
    harness.client.events.addError(StateError('stale'));
    await closed;
    expect(harness.received, ['active', 'event-error']);
    expect(harness.errors, ['event_stream']);
  });

  test('old event callbacks stay invalid after a new lifetime is opened',
      () async {
    final harness = _Harness();
    await harness.owner.open();
    final oldEvent = harness.client.events._onData!;
    final oldError = harness.client.events._onError!;
    await harness.owner.close();
    await harness.owner.open();
    oldEvent('stale generation');
    Function.apply(oldError, [StateError('secret old token')]);
    harness.client.events.add('new generation');
    expect(harness.received, ['new generation']);
    expect(harness.errors, isEmpty);
    await harness.owner.close();
  });

  test('join error after stopping is observed without stale failure effects',
      () async {
    final join = Completer<void>();
    final started = Completer<void>();
    final harness = _Harness(join: (_) {
      started.complete();
      return join.future;
    });
    final opened = harness.owner.open();
    await started.future;
    final closed = harness.owner.close();
    expect(await opened, DailySessionOpenResult.cancelled);
    join.completeError(StateError('secret token'));
    await closed;
    expect(harness.errors, ['join_after_close']);
    expect(harness.trace.last, 'dispose');
    expect(harness.trace, isNot(contains('publishing')));
  });

  for (final synchronous in [true, false]) {
    test('creation error propagates and releases lease (sync: $synchronous)',
        () async {
      final lease = DailySessionLease();
      final failure = StateError('secret token');
      final first = _Harness(
          lease: lease,
          create: () {
            if (synchronous) throw failure;
            return Future.error(failure);
          });
      final second = _Harness(lease: lease);
      await expectLater(first.owner.open(), throwsA(same(failure)));
      await first.owner.close();
      expect(first.errors, ['create']);
      expect(first.trace, ['create', 'captions', 'detach']);
      expect(await second.owner.open(), DailySessionOpenResult.opened);
      await second.owner.close();
    });
  }

  for (final failedPhase in [
    'cancel-events',
    'disable',
    'captions',
    'leave',
    'detach',
  ]) {
    test('cleanup continues after $failedPhase failure and releases lease',
        () async {
      final lease = DailySessionLease();
      final first = _Harness(lease: lease, failedPhase: failedPhase);
      final second = _Harness(lease: lease);
      await first.owner.open();
      await first.owner.close();
      expect(first.trace.sublist(6), [
        'cancel-events',
        'disable',
        'captions',
        'leave',
        'detach',
        'dispose'
      ]);
      expect(first.errors, [failedPhase.replaceAll('-', '_')]);
      expect(await second.owner.open(), DailySessionOpenResult.opened);
      await second.owner.close();
    });
  }

  test('a throwing diagnostic observer cannot abort cleanup', () async {
    final harness = _Harness(
        failedPhase: 'captions',
        diagnostic: (_) => throw StateError('observer'));
    await harness.owner.open();
    await harness.owner.close();
    expect(harness.trace.last, 'dispose');
  });

  test(
      'failed disposal reports failure and does not hand off an unknown client',
      () {
    fakeAsync((clock) {
      final lease = DailySessionLease();
      final first = _Harness(lease: lease, failedPhase: 'dispose');
      final second = _Harness(lease: lease);
      first.owner.open();
      clock.flushMicrotasks();
      var closed = false;
      first.owner.close().then((_) => closed = true);
      clock.flushMicrotasks();
      expect(closed, isTrue);
      expect(first.errors, ['dispose']);
      DailySessionOpenResult? secondResult;
      DailySessionOpenResult? firstResult;
      second.owner.open().then((value) => secondResult = value);
      first.owner.open().then((value) => firstResult = value);
      clock.flushMicrotasks();
      expect(secondResult, DailySessionOpenResult.quarantined);
      expect(firstResult, DailySessionOpenResult.quarantined);
      expect(second.trace, isEmpty);
      expect(first.trace.where((step) => step == 'create'), hasLength(1));
    });
  });

  test('close without an open still clears nullable widget resources once',
      () async {
    final snapshots = <_Client?>[];
    var closingCount = 0;
    final harness = _Harness(
      onClosing: () => closingCount += 1,
      captions: (client) async => snapshots.add(client),
      detach: (client) async => snapshots.add(client),
    );
    final closed = harness.owner.close();
    expect(closingCount, 1);
    expect(harness.owner.close(), same(closed));
    await closed;
    expect(harness.owner.close(), same(closed));
    expect(harness.trace, ['captions', 'detach']);
    expect(snapshots, [null, null]);
  });

  test('onClosing invalidates once before cleanup and is safe when it throws',
      () async {
    var closingCount = 0;
    late _Harness harness;
    harness = _Harness(onClosing: () {
      closingCount += 1;
      expect(harness.owner.isClosing, isTrue);
      expect(harness.owner.isCurrent(harness.client), isFalse);
      expect(harness.trace.last, 'inputs');
      throw StateError('observer');
    });
    await harness.owner.open();
    final closed = harness.owner.close();
    expect(closingCount, 1);
    expect(harness.owner.close(), same(closed));
    await closed;
    expect(harness.trace.last, 'dispose');
    expect(harness.errors, ['on_closing']);
  });

  test('close is single-flight and later true upgrades an earlier false',
      () async {
    final captions = Completer<void>();
    final started = Completer<void>();
    final harness = _Harness(captions: (_) {
      started.complete();
      return captions.future;
    });
    await harness.owner.open();
    final first = harness.owner.close(leaveCall: false);
    await started.future;
    expect(harness.owner.close(leaveCall: true), same(first));
    captions.complete();
    await first;
    expect(harness.trace.where((step) => step == 'leave'), hasLength(1));
    expect(harness.trace.where((step) => step == 'dispose'), hasLength(1));
  });

  test('leave escalation while detaching still runs before dispose', () async {
    final detach = Completer<void>();
    final started = Completer<void>();
    final harness = _Harness(detach: (_) {
      started.complete();
      return detach.future;
    });
    await harness.owner.open();
    final first = harness.owner.close(leaveCall: false);
    await started.future;
    expect(harness.owner.close(), same(first));
    detach.complete();
    await first;
    expect(harness.trace.sublist(6),
        ['cancel-events', 'disable', 'captions', 'detach', 'leave', 'dispose']);
  });

  test('leave requested after disposal starts is reported without unsafe leave',
      () async {
    final dispose = Completer<void>();
    final started = Completer<void>();
    final harness = _Harness(dispose: (_) {
      started.complete();
      return dispose.future;
    });
    await harness.owner.open();
    final first = harness.owner.close(leaveCall: false);
    await started.future;
    expect(harness.owner.close(), same(first));
    dispose.complete();
    await first;
    expect(harness.errors, ['leave_requested_after_dispose']);
    expect(harness.trace, isNot(contains('leave')));
  });

  test('open error propagates without waiting on cleanup or retry handler',
      () async {
    final dispose = Completer<void>();
    final failure =
        StateError('token classification still available to caller');
    final harness = _Harness(
        join: (_) => Future.error(failure), dispose: (_) => dispose.future);
    await expectLater(harness.owner.open(), throwsA(same(failure)));
    expect(harness.owner.isClosing, isTrue);
    final cleanup = harness.owner.close();
    expect(await harness.owner.open(), DailySessionOpenResult.busy);
    dispose.complete();
    await cleanup;
    expect(harness.errors, ['join']);
  });

  test('closing an owner waiting for lease does not release another owner',
      () async {
    final lease = DailySessionLease();
    final first = _Harness(lease: lease);
    final second = _Harness(lease: lease);
    await first.owner.open();
    final waiting = second.owner.open();
    await second.owner.close();
    expect(await waiting, DailySessionOpenResult.cancelled);
    expect(second.trace, ['captions', 'detach']);
    expect(first.owner.isCurrent(first.client), isTrue);
    await first.owner.close();
    expect(await second.owner.open(), DailySessionOpenResult.opened);
    await second.owner.close();
  });

  test('independent leases do not serialize unrelated owners', () async {
    final first = _Harness();
    final second = _Harness();
    expect(await first.owner.open(), DailySessionOpenResult.opened);
    expect(await second.owner.open(), DailySessionOpenResult.opened);
    await first.owner.close();
    expect(second.owner.isCurrent(second.client), isTrue);
    await second.owner.close();
  });

  test('runWithClient rejects work without a created active client', () async {
    final create = Completer<_Client>();
    final harness = _Harness(create: () => create.future);
    var calls = 0;
    Future<void> action(_Client client) async => calls += 1;
    expect(await harness.owner.runWithClient(action), isFalse);
    final opened = harness.owner.open();
    expect(await harness.owner.runWithClient(action), isFalse);
    final closed = harness.owner.close();
    expect(await harness.owner.runWithClient(action), isFalse);
    create.complete(harness.client);
    await opened;
    await closed;
    expect(await harness.owner.runWithClient(action), isFalse);
    expect(calls, 0);
  });

  test('runWithClient captures the client and reports current completion',
      () async {
    final harness = _Harness();
    await harness.owner.open();
    final applied = await harness.owner.runWithClient((client) async {
      expect(client, same(harness.client));
      harness.trace.add('update');
    });
    expect(applied, isTrue);
    await harness.owner.close();
    expect(harness.trace.indexOf('update'),
        lessThan(harness.trace.indexOf('disable')));
  });

  test('close drains active native work and rejects new operations immediately',
      () async {
    final update = Completer<void>();
    final harness = _Harness();
    await harness.owner.open();
    final running = harness.owner.runWithClient((client) {
      expect(client, same(harness.client));
      harness.trace.add('update-start');
      return update.future;
    });
    final closed = harness.owner.close();
    var newWorkRan = false;
    expect(await harness.owner.runWithClient((_) async => newWorkRan = true),
        isFalse);
    expect(newWorkRan, isFalse);
    expect(harness.trace, isNot(contains('disable')));
    expect(harness.trace, isNot(contains('dispose')));
    update.complete();
    expect(await running, isFalse);
    await closed;
    expect(harness.trace.last, 'dispose');
  });

  test('concurrent native operations run immediately and all drain on close',
      () async {
    final first = Completer<void>();
    final second = Completer<void>();
    final starts = <int>[];
    final harness = _Harness();
    await harness.owner.open();
    final firstRun = harness.owner.runWithClient((_) {
      starts.add(1);
      return first.future;
    });
    final secondRun = harness.owner.runWithClient((_) {
      starts.add(2);
      return second.future;
    });
    expect(starts, [1, 2]);
    var closed = false;
    final closing = harness.owner.close().then((_) => closed = true);
    first.complete();
    expect(await firstRun, isFalse);
    expect(closed, isFalse);
    expect(harness.trace, isNot(contains('disable')));
    second.complete();
    expect(await secondRun, isFalse);
    await closing;
    expect(closed, isTrue);
    expect(harness.trace.last, 'dispose');
  });

  for (final synchronous in [true, false]) {
    test(
        'native error retains its stack and drains registration (sync: $synchronous)',
        () async {
      final harness = _Harness();
      final failure = StateError('secret native token');
      final stack = StackTrace.fromString('native operation original stack');
      await harness.owner.open();
      final operation = harness.owner.runWithClient((_) {
        if (synchronous) Error.throwWithStackTrace(failure, stack);
        return Future<void>.error(failure, stack);
      });
      Object? reportedError;
      StackTrace? reportedStack;
      final observed = operation.then<void>((_) => fail('Expected error'),
          onError: (Object error, StackTrace trace) {
        reportedError = error;
        reportedStack = trace;
      });
      await harness.owner.close();
      await observed;
      expect(reportedError, same(failure));
      expect(reportedStack.toString(), stack.toString());
      expect(harness.trace.last, 'dispose');
      expect(harness.errors, isEmpty);
    });
  }

  test('native operation registers before a synchronously reentrant close',
      () async {
    final update = Completer<void>();
    final harness = _Harness();
    await harness.owner.open();
    late Future<void> closed;
    final running = harness.owner.runWithClient((_) {
      closed = harness.owner.close();
      return update.future;
    });
    expect(harness.owner.isClosing, isTrue);
    await Future<void>.value();
    expect(harness.trace, isNot(contains('dispose')));
    update.complete();
    expect(await running, isFalse);
    await closed;
    expect(harness.trace.last, 'dispose');
  });

  test('old operation completion cannot apply effects to the next lifetime',
      () async {
    final update = Completer<void>();
    final harness = _Harness();
    await harness.owner.open();
    final effects = <String>[];
    final running =
        harness.owner.runWithClient((_) => update.future).then((current) {
      if (current) effects.add('old-effect');
    });
    final reopened = harness.owner.close().then((_) => harness.owner.open());
    update.complete();
    await running;
    expect(await reopened, DailySessionOpenResult.opened);
    expect(effects, isEmpty);
    expect(
        await harness.owner
            .runWithClient((_) async => effects.add('new-effect')),
        isTrue);
    expect(effects, ['new-effect']);
    await harness.owner.close();
  });
}

class _Client {
  final events = _Events();
}

// Model stream cancellation explicitly: broadcast onCancel is a void observer,
// so throwing there is a zone error, not a failed subscription.cancel future.
class _Events extends Fake implements Stream<Object> {
  void Function()? onCancel;
  void Function(Object)? _onData;
  Function? _onError;

  Stream<Object> get stream => this;

  void add(Object value) => _onData?.call(value);
  void addError(Object error) {
    final onError = _onError;
    if (onError != null) Function.apply(onError, [error]);
  }

  @override
  StreamSubscription<Object> listen(void Function(Object)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    _onData = onData;
    _onError = onError;
    return _Subscription(() {
      _onData = null;
      _onError = null;
      onCancel?.call();
    });
  }
}

class _Subscription extends Fake implements StreamSubscription<Object> {
  _Subscription(this._cancel);
  final void Function() _cancel;

  @override
  Future<void> cancel() => Future<void>.sync(_cancel);
}

class _Harness {
  _Harness({
    DailySessionLease? lease,
    Future<_Client> Function()? create,
    Future<void> Function(_Client)? join,
    Future<void> Function(_Client)? publishing,
    Future<void> Function(_Client?)? captions,
    Future<void> Function(_Client?)? detach,
    Future<void> Function(_Client)? dispose,
    String? failedPhase,
    void Function()? onClosing,
    void Function(String)? diagnostic,
  }) {
    Future<void> run(String phase, Future<void> Function()? action) async {
      trace.add(phase);
      if (failedPhase == phase) throw StateError('secret token in $phase');
      await action?.call();
    }

    client.events.onCancel = () {
      trace.add('cancel-events');
      if (failedPhase == 'cancel-events') throw StateError('secret token');
    };
    owner = DailySessionController<_Client>(
      lease: lease ?? DailySessionLease(),
      create: () {
        trace.add('create');
        return create?.call() ?? Future.value(client);
      },
      prepare: (value) => run('prepare', null),
      events: (value) {
        trace.add('events');
        return value.events.stream;
      },
      onEvent: received.add,
      onEventError: (_) => received.add('event-error'),
      join: (value) => run('join', () async => await join?.call(value)),
      configure: [
        (value) => run('publishing', () async => await publishing?.call(value)),
        (value) => run('inputs', null),
      ],
      disableInputs: (value) => run('disable', null),
      stopCaptions: (value) =>
          run('captions', () async => await captions?.call(value)),
      leave: (value) => run('leave', null),
      detachVideo: (value) =>
          run('detach', () async => await detach?.call(value)),
      dispose: (value) =>
          run('dispose', () async => await dispose?.call(value)),
      onClosing: onClosing,
      onError: (code) {
        errors.add(code);
        diagnostic?.call(code);
      },
    );
  }

  final client = _Client();
  final trace = <String>[];
  final received = <dynamic>[];
  final errors = <String>[];
  late final DailySessionController<_Client> owner;
}
