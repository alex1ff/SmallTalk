import 'dart:async';

import 'call_limit_decision_tracker.dart';
import 'session_limit_ui.dart' as limits;

/// Immutable input snapshot. The caller supplies current server-owned session
/// data on each tick, so extensions and clock corrections need no timer restart.
class CallTimerSession {
  const CallTimerSession({
    this.connectedAt,
    this.expiresAt,
    this.policy,
    this.status,
    this.provisionalCountdown = false,
    this.isStudent = false,
    this.userRequestedEnd = false,
  });

  final DateTime? connectedAt;
  final DateTime? expiresAt;
  final Map<String, dynamic>? policy;
  final String? status;
  final bool provisionalCountdown;
  final bool isStudent;
  final bool userRequestedEnd;

  bool get hasCountdown =>
      provisionalCountdown ||
      (expiresAt != null && policy != null && policy!.isNotEmpty);
}

class CallTimerUpdate {
  const CallTimerUpdate({
    required this.elapsedSeconds,
    required this.checkpointMinutes,
    required this.shouldAutoEnd,
  });

  final int elapsedSeconds;
  final List<int> checkpointMinutes;
  final bool shouldAutoEnd;
}

/// Owns the periodic clock and one-shot limit decisions, not widgets or network
/// calls. Elapsed time is always recalculated from the server timestamp; ticks
/// are never accumulated (backgrounding must not cause timer drift).
class CallTimerController {
  CallTimerController({
    required CallTimerSession Function() readSession,
    required void Function(CallTimerUpdate) onUpdate,
    DateTime Function()? now,
    Timer Function(Duration, void Function(Timer))? schedulePeriodic,
  })  : _readSession = readSession,
        _onUpdate = onUpdate,
        _now = now ?? DateTime.now,
        _schedulePeriodic = schedulePeriodic ?? Timer.periodic;

  final CallTimerSession Function() _readSession;
  final void Function(CallTimerUpdate) _onUpdate;
  final DateTime Function() _now;
  final Timer Function(Duration, void Function(Timer)) _schedulePeriodic;
  final _decisions = CallLimitDecisionTracker();
  Timer? _timer;
  bool _disposed = false;
  bool _suspended = false;
  int _timerGeneration = 0;
  int _elapsedSeconds = 0;
  Duration? serverClockOffset;

  int get elapsedSeconds => _elapsedSeconds;
  bool get isRunning => _timer != null;
  bool get hasCountdown => _readSession().hasCountdown;

  void start() {
    if (_disposed || _suspended || _timer != null) return;
    final generation = ++_timerGeneration;
    refresh();
    if (_disposed || generation != _timerGeneration) return;
    _timer = _schedulePeriodic(const Duration(seconds: 1), (_) {
      if (!_disposed && generation == _timerGeneration) refresh();
    });
  }

  void stop({bool reset = false}) {
    cancelTicker();
    if (_disposed) return;
    setElapsedSeconds(reset ? 0 : authoritativeSeconds());
  }

  /// Stops scheduling immediately without publishing a new limit decision.
  /// Teardown uses this before draining media, then resets the display last.
  void cancelTicker() {
    _timerGeneration++;
    _timer?.cancel();
    _timer = null;
  }

  /// Cleanup may await native work while an older promotion callback resumes.
  /// Keep starts blocked until the next call lifetime explicitly resumes us.
  void suspend() {
    _suspended = true;
    cancelTicker();
  }

  void resume() {
    if (!_disposed) _suspended = false;
  }

  int authoritativeSeconds([DateTime? now]) =>
      limits.resolveAuthoritativeCallDurationSeconds(
        serverConnectedAt: _readSession().connectedAt,
        serverAlignedNow: now ??
            limits.resolveServerAlignedNow(serverClockOffset,
                deviceNow: _now()),
      );

  DateTime sessionLimitNow() => _sessionLimitNow(_readSession());

  DateTime _sessionLimitNow(CallTimerSession session) =>
      limits.resolveSessionLimitNow(
        sessionStatus: session.status,
        serverClockOffset: serverClockOffset,
        expiresAt: session.expiresAt,
        sessionPolicy: session.policy,
        elapsedSeconds: _elapsedSeconds,
        deviceNow: _now(),
      );

  int remainingSeconds([DateTime? now]) {
    final session = _readSession();
    return limits.resolveSessionLimitDisplaySeconds(
      expiresAt: session.expiresAt,
      sessionPolicy: session.policy,
      elapsedSeconds: _elapsedSeconds,
      useProvisionalCountdown: session.provisionalCountdown,
      now: now ?? _sessionLimitNow(session),
    );
  }

  void refresh() {
    if (!_disposed) setElapsedSeconds(authoritativeSeconds());
  }

  void setElapsedSeconds(int seconds) {
    if (_disposed) return;
    _elapsedSeconds = seconds;
    final session = _readSession();
    var shouldAutoEnd = false;
    var checkpoints = const <int>[];
    if (session.hasCountdown) {
      final status = session.status?.trim().toLowerCase();
      final now = _sessionLimitNow(session);
      if (!session.userRequestedEnd &&
          status != 'ended' &&
          status != 'cancelled' &&
          status != 'expired') {
        shouldAutoEnd = _decisions.takeAutoEndRequest(
          expiresAt: session.expiresAt,
          now: now,
          graceSeconds: 2,
        );
      }
      _decisions.takeSessionLimitWarning(
        expiresAt: session.expiresAt,
        now: now,
        warningLeadSeconds: 60,
      );
    } else if (session.isStudent) {
      checkpoints = _decisions.takeDueCheckpointMinutes(
        totalSeconds: seconds,
        checkpointMinutes: const [5, 10],
      );
    }
    _onUpdate(CallTimerUpdate(
      elapsedSeconds: seconds,
      checkpointMinutes: checkpoints,
      shouldAutoEnd: shouldAutoEnd,
    ));
  }

  void resetLimitMarkers() => _decisions.resetLimitMarkers();
  void clearCheckpointHistory() => _decisions.clearCheckpointHistory();
  void clearAutoEndRequest(DateTime? expiry) =>
      _decisions.clearAutoEndRequest(expiry);

  void dispose() {
    _disposed = true;
    cancelTicker();
  }
}
