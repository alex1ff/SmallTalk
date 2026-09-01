import 'dart:async';

enum DailySessionOpenResult { opened, busy, cancelled, quarantined }

/// Share one instance between widgets that use the process-wide Daily SDK.
/// The lease covers creation and disposal, not just an already-created client.
class DailySessionLease {
  Object? _owner;
  Completer<void>? _released;
  bool _quarantined = false;

  bool _claim(Object owner) {
    if (_owner != null) return identical(_owner, owner);
    _owner = owner;
    _released = Completer<void>();
    return true;
  }

  void _quarantine(Object owner) {
    if (identical(_owner, owner)) _quarantined = true;
  }

  void _release(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _quarantined = false;
    final released = _released;
    _released = null;
    released?.complete();
  }
}

/// Owns one Daily client lifetime at a time; UI, credentials and retry policy
/// stay in the widget. All client callbacks receive the captured client, never
/// a mutable widget field. Each configuration callback is one guarded step.
class DailySessionController<T extends Object> {
  DailySessionController({
    required DailySessionLease lease,
    required Future<T> Function() create,
    required Stream<dynamic> Function(T client) events,
    required void Function(dynamic event) onEvent,
    void Function(Object error)? onEventError,
    FutureOr<void> Function(T client)? prepare,
    required Future<void> Function(T client) join,
    List<Future<void> Function(T client)> configure = const [],
    required Future<void> Function(T client) disableInputs,
    required Future<void> Function(T? client) stopCaptions,
    required Future<void> Function(T client) leave,
    required Future<void> Function(T? client) detachVideo,
    required Future<void> Function(T client) dispose,
    void Function()? onClosing,
    void Function(String operationCode)? onError,
    Duration createTimeout = const Duration(seconds: 10),
    Duration leaseWaitTimeout = const Duration(seconds: 2),
  })  : _lease = lease,
        _create = create,
        _events = events,
        _onEvent = onEvent,
        _onEventError = onEventError,
        _prepare = prepare,
        _join = join,
        _configure = List.unmodifiable(configure),
        _disableInputs = disableInputs,
        _stopCaptions = stopCaptions,
        _leave = leave,
        _detachVideo = detachVideo,
        _dispose = dispose,
        _onClosing = onClosing,
        _onError = onError,
        _createTimeout = createTimeout,
        _leaseWaitTimeout = leaseWaitTimeout;

  final DailySessionLease _lease;
  final Future<T> Function() _create;
  final Stream<dynamic> Function(T) _events;
  final void Function(dynamic) _onEvent;
  final void Function(Object)? _onEventError;
  final FutureOr<void> Function(T)? _prepare;
  final Future<void> Function(T) _join;
  final List<Future<void> Function(T)> _configure;
  final Future<void> Function(T) _disableInputs;
  final Future<void> Function(T?) _stopCaptions;
  final Future<void> Function(T) _leave;
  final Future<void> Function(T?) _detachVideo;
  final Future<void> Function(T) _dispose;
  final void Function()? _onClosing;
  final void Function(String)? _onError;
  final Duration _createTimeout;
  final Duration _leaseWaitTimeout;

  _DailySession<T>? _session;
  Future<void>? _lastClose;

  /// Retained while closing for final caption flushes. Other widget operations
  /// must use [isCurrent] before and after awaits before applying further work.
  T? get client => _session?.client;
  bool get isClosing => _session?.closeFuture != null;
  bool get isQuarantined =>
      _session?.quarantined == true || _lease._quarantined;

  bool isCurrent(T client) {
    final session = _session;
    return session != null &&
        _isCurrent(session) &&
        identical(session.client, client);
  }

  bool _isCurrent(_DailySession<T> session) =>
      identical(_session, session) && !session.stopped.isCompleted;

  /// Runs native work on a captured client without changing operation order.
  /// Close rejects new work immediately and waits for all accepted operations.
  /// Returns false if there is no active client or completion is now stale;
  /// failures still reach the caller with their original stack.
  ///
  /// Keep this callback to native work only. Do not await [close] from inside
  /// it or include Firebase/UI-policy waits, since close must drain this work.
  Future<bool> runWithClient(Future<void> Function(T client) action) async {
    final session = _session;
    final client = session?.client;
    if (session == null || client == null || !_isCurrent(session)) return false;
    final settled = Completer<void>();
    // Register before action: it may synchronously trigger close itself.
    session.nativeOperations.add(settled.future);
    try {
      await action(client);
      return _isCurrent(session);
    } finally {
      session.nativeOperations.remove(settled.future);
      // Cleanup waits for settlement, not the caller-facing error future.
      settled.complete();
    }
  }

  /// Concurrent starts join the same future. Busy callers may retry later;
  /// waiting on a lease does not reserve it or permit a second create.
  ///
  /// Failures reach the caller unchanged for existing connection/token policy.
  /// Cleanup starts independently: never await a UI error handler here, since
  /// that handler may itself await [close] and then retry [open].
  Future<DailySessionOpenResult> open() {
    final current = _session;
    if (current != null) {
      if (current.closeFuture != null) {
        return Future.value(current.quarantined || _lease._quarantined
            ? DailySessionOpenResult.quarantined
            : DailySessionOpenResult.busy);
      }
      return current.openFuture!;
    }
    if (_lease._quarantined) {
      return Future.value(DailySessionOpenResult.quarantined);
    }
    final session = _DailySession<T>();
    final completer = Completer<DailySessionOpenResult>();
    session.openFuture = completer.future;
    _session = session;
    _lastClose = null;
    unawaited(_completeOpen(session, completer));
    return completer.future;
  }

  Future<void> _completeOpen(_DailySession<T> session,
      Completer<DailySessionOpenResult> completer) async {
    try {
      final result = await _open(session);
      if (result == DailySessionOpenResult.busy && _isCurrent(session)) {
        _session = null;
      }
      completer.complete(result);
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
  }

  Future<DailySessionOpenResult> _open(_DailySession<T> session) async {
    if (!_lease._claim(session)) {
      if (_lease._quarantined) {
        return DailySessionOpenResult.quarantined;
      }
      final released = _lease._released!.future;
      try {
        await Future.any([
          released.timeout(_leaseWaitTimeout),
          session.stopped.future,
        ]);
      } on TimeoutException {
        // The widget retains its existing delayed retry policy.
      }
      if (!_isCurrent(session)) return DailySessionOpenResult.cancelled;
      if (_lease._quarantined) {
        return DailySessionOpenResult.quarantined;
      }
      if (!_lease._claim(session)) return DailySessionOpenResult.busy;
    }

    try {
      session.operation = 'create';
      // Keep the original future. timeout() only stops waiting; it does not
      // cancel native allocation. Close waits for and disposes any late result.
      session.pending = Future<T>.sync(_create).then((value) {
        session.client = value;
      });
      await Future.any([
        session.pending!.timeout(_createTimeout),
        session.stopped.future,
      ]);
      if (!_isCurrent(session)) return DailySessionOpenResult.cancelled;
      final client = session.client!;
      final prepare = _prepare;
      if (prepare != null) {
        await _stage(session, 'prepare', () => prepare(client));
        if (!_isCurrent(session)) return DailySessionOpenResult.cancelled;
      }

      session.operation = 'events';
      session.subscription = _events(client).listen(
        (event) {
          if (!_isCurrent(session)) return;
          try {
            _onEvent(event);
          } catch (_) {
            _report('event_callback');
          }
        },
        onError: (Object error) {
          if (!_isCurrent(session)) return;
          _report('event_stream');
          try {
            _onEventError?.call(error);
          } catch (_) {
            _report('event_error_callback');
          }
        },
        cancelOnError: false,
      );
      if (!_isCurrent(session)) return DailySessionOpenResult.cancelled;
      await _stage(session, 'join', () => _join(client));
      if (!_isCurrent(session)) return DailySessionOpenResult.cancelled;
      for (final configure in _configure) {
        await _stage(session, 'configure', () => configure(client));
        if (!_isCurrent(session)) return DailySessionOpenResult.cancelled;
      }
      return DailySessionOpenResult.opened;
    } catch (error, stackTrace) {
      if (!_isCurrent(session)) return DailySessionOpenResult.cancelled;
      final timedOut =
          session.operation == 'create' && error is TimeoutException;
      if (timedOut) {
        session.quarantined = true;
        _lease._quarantine(session);
      }
      session.pendingFailureReported = !timedOut;
      _report(timedOut ? 'create_timeout' : session.operation);
      unawaited(close(leaveCall: false));
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _stage(_DailySession<T> session, String operation,
      FutureOr<void> Function() action) async {
    session.operation = operation;
    session.pendingFailureReported = false;
    session.pending = Future<void>.sync(action);
    await Future.any([session.pending!, session.stopped.future]);
  }

  /// Invalidates events/stages synchronously and returns the one root cleanup
  /// future. A later leave=true request upgrades an in-flight leave=false close.
  /// Once disposal has started, a late leave request is reported instead of
  /// issuing an unsafe native call concurrently with disposal.
  Future<void> close({bool leaveCall = true}) {
    var session = _session;
    if (session == null) {
      final previous = _lastClose;
      if (previous != null) return previous;
      // A widget can own caption/video state even before its first create.
      session = _DailySession<T>();
      _session = session;
    }
    if (leaveCall && !session.leaveRequested) {
      session.leaveRequested = true;
      if (session.disposalStarted && !session.leaveAttempted) {
        _report('leave_requested_after_dispose');
      }
    }
    final current = session.closeFuture;
    if (current != null) return current;
    session.stopped.complete();
    final completer = Completer<void>();
    session.closeFuture = completer.future;
    _lastClose = completer.future;
    try {
      _onClosing?.call();
    } catch (_) {
      _report('on_closing');
    }
    unawaited(_completeClose(session, completer));
    return completer.future;
  }

  Future<void> _completeClose(
      _DailySession<T> session, Completer<void> completer) async {
    // Publish the root future before invoking hooks. This also lets a
    // synchronously reentrant open hook finish assigning its pending resource.
    await Future<void>.value();
    var releaseLease = true;
    try {
      final subscription = session.subscription;
      session.subscription = null;
      if (subscription != null) {
        await _cleanupStep('cancel_events', subscription.cancel);
      }
      try {
        await session.pending;
      } catch (_) {
        if (!session.pendingFailureReported) {
          _report('${session.operation}_after_close');
        }
      }
      // Invalidation prevents any new registrations. Already-running native
      // updates must settle before disabling capture or destroying the client.
      await Future.wait(session.nativeOperations.toList());
      // Snapshot only after pending creation settles. No later generation may
      // start until disposal has completed and this exact lease is released.
      final client = session.client;
      if (client != null) {
        await _cleanupStep('disable', () => _disableInputs(client));
      }
      await _cleanupStep('captions', () => _stopCaptions(client));
      await _leaveIfRequested(session, client);
      await _cleanupStep('detach', () => _detachVideo(client));
      // An explicit end can arrive while video detachment is awaiting native
      // work, after the initial leave=false decision.
      if (session.leaveRequested && !session.leaveAttempted) {
        await _leaveIfRequested(session, client);
      }
      if (client != null) {
        session.disposalStarted = true;
        releaseLease = false;
        await _cleanupStep('dispose', () async {
          await _dispose(client);
          releaseLease = true;
        });
        if (!releaseLease) {
          session.quarantined = true;
          _lease._quarantine(session);
        }
      }
    } finally {
      if (releaseLease) {
        session.client = null;
        _lease._release(session);
      }
      // Failed native disposal leaves resource state unknown. Keep the lease
      // (and its captured client) quarantined instead of risking two clients.
      if (identical(_session, session)) _session = null;
      completer.complete();
    }
  }

  Future<void> _leaveIfRequested(_DailySession<T> session, T? client) async {
    if (client == null || !session.leaveRequested || session.leaveAttempted) {
      return;
    }
    session.leaveAttempted = true;
    await _cleanupStep('leave', () => _leave(client));
  }

  Future<void> _cleanupStep(
      String operation, Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      _report(operation);
    }
  }

  void _report(String operation) {
    // Diagnostics deliberately carry only a fixed operation code: native
    // errors can include meeting tokens. A faulty observer cannot stop cleanup.
    try {
      _onError?.call(operation);
    } catch (_) {}
  }
}

class _DailySession<T> {
  final stopped = Completer<void>();
  final nativeOperations = <Future<void>>{};
  T? client;
  Future<DailySessionOpenResult>? openFuture;
  Future<void>? closeFuture;
  Future<void>? pending;
  StreamSubscription<dynamic>? subscription;
  String operation = 'create';
  bool pendingFailureReported = false;
  bool leaveRequested = false;
  bool leaveAttempted = false;
  bool disposalStarted = false;
  bool quarantined = false;
}
