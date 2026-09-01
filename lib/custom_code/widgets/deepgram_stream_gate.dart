/// Owns the synchronous lifecycle state of one Deepgram stream.
///
/// Network, recorder and timer effects remain with the call widget. This gate
/// only invalidates stale callbacks and preserves the distinct start,
/// finalization and stop completion moments.
class DeepgramStreamGate {
  int _generation = 0;
  bool _stopRequested = false;
  bool _finalizing = false;
  bool _startInProgress = false;

  int get generation => _generation;
  bool get stopRequested => _stopRequested;
  bool get finalizing => _finalizing;
  bool get startInProgress => _startInProgress;

  int beginStart() {
    final generation = ++_generation;
    _startInProgress = true;
    _stopRequested = false;
    return generation;
  }

  void finishStart(int generation) {
    if (_generation == generation) {
      _startInProgress = false;
    }
  }

  void requestStop({required bool finalizing}) {
    _finalizing = finalizing;
    _generation++;
    _stopRequested = true;
  }

  bool requestSinkFailureStop() {
    if (_stopRequested) return false;
    _stopRequested = true;
    _generation++;
    return true;
  }

  void finishFinalization() {
    _finalizing = false;
  }

  void finishStop() {
    _startInProgress = false;
  }

  bool isCurrent(int generation) => _generation == generation;

  bool canHandleMessage({
    required int generation,
    required bool Function() shouldRun,
  }) {
    return (_finalizing && _stopRequested) ||
        (_generation == generation && !_stopRequested && shouldRun());
  }
}
