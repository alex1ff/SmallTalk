import 'dart:async';

/// Shares one Deepgram stop operation between all concurrent callers.
///
/// The active future is installed before [operation] is invoked, so a
/// synchronous reentrant call joins the same operation. The coordinator owns
/// no recorder, WebSocket or widget state.
class DeepgramStopSingleFlight {
  Future<void>? _active;

  Future<void> run(Future<void> Function() operation) {
    final active = _active;
    if (active != null) return active;

    final completer = Completer<void>();
    final shared = completer.future;
    _active = shared;

    Future<void> operationFuture;
    try {
      operationFuture = operation();
    } catch (error, stackTrace) {
      _completeError(shared, completer, error, stackTrace);
      return shared;
    }

    unawaited(
      operationFuture.then<void>(
        (_) => _completeSuccess(shared, completer),
        onError: (Object error, StackTrace stackTrace) {
          _completeError(shared, completer, error, stackTrace);
        },
      ),
    );
    return shared;
  }

  void _completeSuccess(Future<void> shared, Completer<void> completer) {
    _clearIfCurrent(shared);
    completer.complete();
  }

  void _completeError(
    Future<void> shared,
    Completer<void> completer,
    Object error,
    StackTrace stackTrace,
  ) {
    _clearIfCurrent(shared);
    completer.completeError(error, stackTrace);
  }

  void _clearIfCurrent(Future<void> shared) {
    if (identical(_active, shared)) {
      _active = null;
    }
  }
}
