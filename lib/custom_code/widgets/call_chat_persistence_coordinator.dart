import 'dart:async';

/// Coordinates idempotent call-chat persistence for one session generation.
///
/// The coordinator deliberately knows nothing about Flutter, Firebase, or the
/// shape of a chat message. The caller provides an immutable snapshot callback
/// and a persistence callback for each batch.
class CallChatPersistenceCoordinator<T> {
  CallChatPersistenceCoordinator({this.maxAttempts = 3}) {
    if (maxAttempts <= 0) {
      throw ArgumentError.value(
          maxAttempts, 'maxAttempts', 'Must be positive.');
    }
  }

  final int maxAttempts;

  int _generation = 0;
  int _messageRevision = 0;
  int _acknowledgedRevision = 0;
  int _attemptCount = 0;
  bool _completed = false;
  _PersistenceRoot<T>? _activeRoot;

  int get generation => _generation;

  bool isCurrentGeneration(int expectedGeneration) =>
      expectedGeneration == _generation;

  /// Marks the current local message set dirty.
  void recordMessage() {
    _messageRevision += 1;
    _completed = false;
  }

  /// Starts a new session generation and detaches any old root future.
  ///
  /// A backend request already in progress cannot be cancelled. Its
  /// completion is identity-checked and therefore cannot mutate this new
  /// generation.
  void reset() {
    _generation += 1;
    _messageRevision = 0;
    _acknowledgedRevision = 0;
    _attemptCount = 0;
    _completed = false;
    _activeRoot = null;
  }

  /// Completes the current generation without doing I/O, unless a root chain
  /// is already active, in which case it joins that chain.
  Future<void> completeWithoutRequest({required int expectedGeneration}) {
    if (!isCurrentGeneration(expectedGeneration)) {
      return Future<void>.value();
    }

    final activeRoot = _activeRoot;
    if (activeRoot != null) {
      return activeRoot.future;
    }

    _acknowledgedRevision = _messageRevision;
    _completed = true;
    return Future<void>.value();
  }

  /// Persists the current snapshot and any dirty tail using one root Future.
  ///
  /// `snapshot` is evaluated once per batch. The supplied list to
  /// `persistBatch` is an immutable copy, while each `T` remains caller-owned
  /// and must itself be immutable/value-like.
  Future<void> persist({
    int? expectedGeneration,
    required Iterable<T> Function() snapshot,
    required FutureOr<void> Function(List<T> immutableEntries) persistBatch,
  }) {
    if (expectedGeneration != null &&
        !isCurrentGeneration(expectedGeneration)) {
      return Future<void>.value();
    }

    if (_completed && _messageRevision == _acknowledgedRevision) {
      return Future<void>.value();
    }

    final activeRoot = _activeRoot;
    if (activeRoot != null) {
      return activeRoot.future;
    }

    if (_attemptCount >= maxAttempts) {
      return Future<void>.value();
    }

    final root = _PersistenceRoot<T>(
      generation: _generation,
      snapshot: snapshot,
      persistBatch: persistBatch,
    );
    _activeRoot = root;
    _startBatch(root);
    return root.future;
  }

  void _startBatch(_PersistenceRoot<T> root) {
    if (!identical(_activeRoot, root) || root.generation != _generation) {
      _completeRootSuccessfully(root);
      return;
    }

    root.batchRunning = true;
    _attemptCount += 1;
    final batchRevision = _messageRevision;

    late final List<T> entries;
    try {
      entries = List<T>.unmodifiable(root.snapshot());
    } catch (error, stackTrace) {
      root.batchRunning = false;
      _completeRootWithError(root, error, stackTrace);
      return;
    }

    final operation = Future<void>.sync(() => root.persistBatch(entries));
    unawaited(
      operation.then<void>(
        (_) => _handleBatchSuccess(root, batchRevision),
        onError: (Object error, StackTrace stackTrace) {
          _completeRootWithError(root, error, stackTrace);
        },
      ),
    );
  }

  void _handleBatchSuccess(_PersistenceRoot<T> root, int batchRevision) {
    if (!root.batchRunning || root.completed) return;
    root.batchRunning = false;

    if (!identical(_activeRoot, root) || root.generation != _generation) {
      _completeRootSuccessfully(root);
      return;
    }

    if (_messageRevision == batchRevision) {
      _acknowledgedRevision = batchRevision;
      _completed = true;
      _completeRootSuccessfully(root);
      return;
    }

    _completed = false;
    if (_attemptCount >= maxAttempts) {
      _completeRootSuccessfully(root);
      return;
    }

    // Keep the root active, but clear batchRunning before starting the tail.
    // Calling _startBatch directly avoids joining the root to itself.
    _startBatch(root);
  }

  void _completeRootSuccessfully(_PersistenceRoot<T> root) {
    if (root.completed) return;
    root.completed = true;
    root.batchRunning = false;
    if (identical(_activeRoot, root)) {
      _activeRoot = null;
    }
    root.completer.complete();
  }

  void _completeRootWithError(
    _PersistenceRoot<T> root,
    Object error,
    StackTrace stackTrace,
  ) {
    if (root.completed) return;
    root.completed = true;
    root.batchRunning = false;
    if (identical(_activeRoot, root)) {
      _activeRoot = null;
    }
    root.completer.completeError(error, stackTrace);
  }
}

class _PersistenceRoot<T> {
  _PersistenceRoot({
    required this.generation,
    required this.snapshot,
    required this.persistBatch,
  });

  final int generation;
  final Iterable<T> Function() snapshot;
  final FutureOr<void> Function(List<T> immutableEntries) persistBatch;
  final Completer<void> completer = Completer<void>();
  bool batchRunning = false;
  bool completed = false;

  Future<void> get future => completer.future;
}
