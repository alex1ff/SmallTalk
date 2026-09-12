typedef CaptionLogQueueEntry<T> = ({String id, T value});

enum CaptionLogFlushOutcome {
  empty,
  persisted,
  unavailable,
  stale,
}

class CaptionLogQueue<T> {
  final Map<String, _CaptionLogQueueItem<T>> _pending = {};
  final Set<String> _persistedIds = {};
  Future<void> _flushChain = Future<void>.value();
  int _generation = 0;
  int _nextVersion = 0;

  int get pendingCount => _pending.length;
  bool get isEmpty => _pending.isEmpty;

  bool enqueue(String id, T value) {
    if (_persistedIds.contains(id)) return false;
    _pending[id] = _CaptionLogQueueItem<T>(
      id: id,
      value: value,
      version: ++_nextVersion,
    );
    return true;
  }

  Future<CaptionLogFlushOutcome> flush(
    Future<bool> Function(List<CaptionLogQueueEntry<T>> entries) persist,
  ) {
    final requestGeneration = _generation;
    final operation = _flushChain.catchError((_) {}).then((_) async {
      if (requestGeneration != _generation) {
        return CaptionLogFlushOutcome.stale;
      }
      if (_pending.isEmpty) {
        return CaptionLogFlushOutcome.empty;
      }

      final snapshot =
          List<_CaptionLogQueueItem<T>>.unmodifiable(_pending.values);
      final publicSnapshot = List<CaptionLogQueueEntry<T>>.unmodifiable(
        snapshot.map((item) => (id: item.id, value: item.value)),
      );

      bool committed;
      try {
        committed = await persist(publicSnapshot);
      } catch (error, stackTrace) {
        if (requestGeneration != _generation) {
          return CaptionLogFlushOutcome.stale;
        }
        Error.throwWithStackTrace(error, stackTrace);
      }

      if (requestGeneration != _generation) {
        return CaptionLogFlushOutcome.stale;
      }
      if (!committed) {
        return CaptionLogFlushOutcome.unavailable;
      }

      for (final item in snapshot) {
        final current = _pending[item.id];
        if (!identical(current, item) || current?.version != item.version) {
          continue;
        }
        _pending.remove(item.id);
        _persistedIds.add(item.id);
      }
      return CaptionLogFlushOutcome.persisted;
    });

    _flushChain = operation.then<void>(
      (_) {},
      onError: (_, __) {},
    );
    return operation;
  }

  void reset() {
    _generation += 1;
    _pending.clear();
    _persistedIds.clear();
  }
}

class _CaptionLogQueueItem<T> {
  const _CaptionLogQueueItem({
    required this.id,
    required this.value,
    required this.version,
  });

  final String id;
  final T value;
  final int version;
}
