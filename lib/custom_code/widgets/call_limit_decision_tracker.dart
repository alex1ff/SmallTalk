import 'session_limit_ui.dart' as session_limit_ui;

/// Tracks one-shot call checkpoints and session-limit decisions.
///
/// Time calculation stays in [session_limit_ui]. Timers, UI notifications and
/// backend effects remain owned by the call widget.
class CallLimitDecisionTracker {
  final Set<int> _shownCheckpointMinutes = <int>{};
  DateTime? _warningShownForExpiresAt;
  DateTime? _autoEndRequestedForExpiresAt;

  List<int> takeDueCheckpointMinutes({
    required int totalSeconds,
    required Iterable<int> checkpointMinutes,
  }) {
    final due = <int>[];
    for (final minutes in checkpointMinutes) {
      if (totalSeconds >= minutes * 60 &&
          _shownCheckpointMinutes.add(minutes)) {
        due.add(minutes);
      }
    }
    return List<int>.unmodifiable(due);
  }

  bool takeSessionLimitWarning({
    required DateTime? expiresAt,
    required DateTime now,
    required int warningLeadSeconds,
  }) {
    if (!session_limit_ui.shouldShowSessionLimitWarning(
      expiresAt: expiresAt,
      warnedForExpiresAt: _warningShownForExpiresAt,
      now: now,
      warningLeadSeconds: warningLeadSeconds,
    )) {
      return false;
    }
    _warningShownForExpiresAt = expiresAt;
    return true;
  }

  bool takeAutoEndRequest({
    required DateTime? expiresAt,
    required DateTime now,
    required int graceSeconds,
  }) {
    if (!session_limit_ui.shouldAutoEndSession(
      expiresAt: expiresAt,
      autoEndedForExpiresAt: _autoEndRequestedForExpiresAt,
      now: now,
      graceSeconds: graceSeconds,
    )) {
      return false;
    }
    _autoEndRequestedForExpiresAt = expiresAt;
    return true;
  }

  void clearAutoEndRequest(DateTime? expiresAt) {
    if (expiresAt == null) {
      _autoEndRequestedForExpiresAt = null;
      return;
    }
    if (_autoEndRequestedForExpiresAt?.isAtSameMomentAs(expiresAt) == true) {
      _autoEndRequestedForExpiresAt = null;
    }
  }

  void resetLimitMarkers() {
    _warningShownForExpiresAt = null;
    _autoEndRequestedForExpiresAt = null;
  }

  void clearCheckpointHistory() {
    _shownCheckpointMinutes.clear();
  }
}
