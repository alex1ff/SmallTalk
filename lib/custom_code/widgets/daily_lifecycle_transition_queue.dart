/// Serializes one call widget's background/foreground transitions.
///
/// Tokens become stale synchronously when newer work is queued or [invalidate]
/// is called. Actions still run: the widget owns mounted/connection guards and
/// must recheck [isCurrent] after awaits before applying further side effects.
class DailyLifecycleTransitionQueue {
  DailyLifecycleTransitionQueue({void Function(Object error)? onError})
      : _onError = onError;

  /// Diagnostic observer only; it must not throw.
  final void Function(Object error)? _onError;
  Future<void> _chain = Future<void>.value();
  int _generation = 0;

  Future<void> enqueue(Future<void> Function(int transitionId) action) {
    final transitionId = ++_generation;
    final nextTransition =
        _chain.catchError((_) {}).then((_) => action(transitionId));
    // Recovery belongs to the internal chain, not the future returned to callers.
    _chain = nextTransition.catchError((Object error) {
      _onError?.call(error);
    });
    return nextTransition;
  }

  bool isCurrent(int transitionId) => transitionId == _generation;

  /// Invalidates tokens without aborting work or releasing the serialized chain.
  void invalidate() {
    _generation += 1;
  }
}
