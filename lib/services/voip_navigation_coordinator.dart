import 'dart:async';

typedef VoipNavigationAttempt = FutureOr<bool> Function(
  VoipNavigationTarget target,
);
typedef VoipNavigationDelay = Future<void> Function(Duration duration);
typedef VoipNavigationRetryExhausted = void Function();

/// Immutable input for one video-call navigation request.
class VoipNavigationRequest {
  const VoipNavigationRequest({
    required this.sessionId,
    required this.isTutor,
    this.roomUrl,
    this.meetingToken,
    this.roomName,
  });

  final String sessionId;
  final bool isTutor;
  final String? roomUrl;
  final String? meetingToken;
  final String? roomName;
}

/// Framework-independent route target passed to the navigation adapter.
class VoipNavigationTarget {
  VoipNavigationTarget._({
    required this.request,
    required this.uri,
  });

  factory VoipNavigationTarget.fromRequest(
    VoipNavigationRequest request, {
    String path = videoCallPath,
    String? effectiveRoomUrl,
    String? effectiveMeetingToken,
    String? effectiveRoomName,
  }) {
    final roomUrl = _effectiveValue(
      effectiveRoomUrl,
      request.roomUrl,
    );
    final meetingToken = _effectiveValue(
      effectiveMeetingToken,
      request.meetingToken,
    );
    final roomName = _effectiveValue(
      effectiveRoomName,
      request.roomName,
    );
    final queryParameters = <String, String>{
      'videoDocRef': request.sessionId,
      if (roomUrl != null) 'roomUrl': roomUrl,
      if (meetingToken != null) 'meetingToken': meetingToken,
      if (roomName != null) 'roomName': roomName,
    };

    return VoipNavigationTarget._(
      request: request,
      uri: Uri(path: path, queryParameters: queryParameters),
    );
  }

  static const String videoCallPath = '/videoCallPage';

  final VoipNavigationRequest request;
  final Uri uri;

  String get sessionId => request.sessionId;
  bool get isTutor => request.isTutor;
  String get path => uri.path;
  String get location => uri.toString();
  Map<String, String> get queryParameters =>
      Map<String, String>.unmodifiable(uri.queryParameters);

  static String? _effectiveValue(String? effective, String? fallback) {
    return _nonBlank(effective ?? fallback);
  }

  static String? _nonBlank(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }
}

class _PendingNavigation {
  const _PendingNavigation({
    required this.request,
    required this.target,
  });

  final VoipNavigationRequest request;
  final VoipNavigationTarget target;
}

/// Owns pending video-call navigation retry, replacement and deduplication.
///
/// [attempt] returns `true` when the target was handled. Returning `false`
/// means that navigation context is not ready yet and schedules another try.
class VoipNavigationCoordinator {
  VoipNavigationCoordinator({
    required VoipNavigationAttempt attempt,
    VoipNavigationDelay? delay,
    VoipNavigationRetryExhausted? onRetryExhausted,
    this.retryDelay = defaultRetryDelay,
    this.maxAttempts = defaultMaxAttempts,
    this.routePath = VoipNavigationTarget.videoCallPath,
  })  : assert(!retryDelay.isNegative),
        assert(maxAttempts > 0),
        _attempt = attempt,
        _delay = delay ?? Future<void>.delayed,
        _onRetryExhausted = onRetryExhausted;

  static const Duration defaultRetryDelay = Duration(milliseconds: 100);
  static const int defaultMaxAttempts = 600;

  final VoipNavigationAttempt _attempt;
  final VoipNavigationDelay _delay;
  final VoipNavigationRetryExhausted? _onRetryExhausted;
  final Duration retryDelay;
  final int maxAttempts;
  final String routePath;

  _PendingNavigation? _pending;
  Future<void>? _activeRetry;
  int _generation = 0;
  String? _lastNavigatedSessionId;
  bool? _lastNavigatedIsTutor;

  bool get hasPendingNavigation => _pending != null;
  String? get pendingSessionId => _pending?.request.sessionId;
  bool get retryInProgress => _activeRetry != null;
  String? get lastNavigatedSessionId => _lastNavigatedSessionId;
  bool? get lastNavigatedIsTutor => _lastNavigatedIsTutor;

  Future<void> requestNavigation(
    VoipNavigationRequest request, {
    String? effectiveRoomUrl,
    String? effectiveMeetingToken,
    String? effectiveRoomName,
  }) {
    if (_wasLastNavigated(request)) {
      return Future<void>.value();
    }

    _pending = _PendingNavigation(
      request: request,
      target: VoipNavigationTarget.fromRequest(
        request,
        path: routePath,
        effectiveRoomUrl: effectiveRoomUrl,
        effectiveMeetingToken: effectiveMeetingToken,
        effectiveRoomName: effectiveRoomName,
      ),
    );
    _generation++;

    final active = _activeRetry;
    if (active != null) return active;
    return _startRetry();
  }

  void clearPending({required String sessionId}) {
    if (_pending?.request.sessionId != sessionId) return;
    _pending = null;
    _generation++;
  }

  void clearLastNavigation() {
    _lastNavigatedSessionId = null;
    _lastNavigatedIsTutor = null;
  }

  void reset() {
    _pending = null;
    _lastNavigatedSessionId = null;
    _lastNavigatedIsTutor = null;
    _generation++;
  }

  Future<void> _startRetry() {
    final completer = Completer<void>();
    final shared = completer.future;
    _activeRetry = shared;
    unawaited(_runRetry(shared, completer));
    return shared;
  }

  Future<void> _runRetry(
    Future<void> shared,
    Completer<void> completer,
  ) async {
    var attempts = 0;

    try {
      while (true) {
        final pending = _pending;
        if (pending == null) break;
        if (attempts >= maxAttempts) {
          _pending = null;
          _generation++;
          _onRetryExhausted?.call();
          break;
        }

        final generation = _generation;
        final handled = await _attempt(pending.target);
        if (!_isCurrent(pending, generation)) continue;

        if (handled) {
          _lastNavigatedSessionId = pending.request.sessionId;
          _lastNavigatedIsTutor = pending.request.isTutor;
          _pending = null;
          _generation++;
          break;
        }

        attempts++;
        await _delay(retryDelay);
        if (!_isCurrent(pending, generation)) continue;
      }
    } catch (error, stackTrace) {
      _clearActiveIfCurrent(shared);
      completer.completeError(error, stackTrace);
      return;
    }

    _clearActiveIfCurrent(shared);
    completer.complete();
  }

  bool _isCurrent(_PendingNavigation pending, int generation) {
    return identical(_pending, pending) && _generation == generation;
  }

  bool _wasLastNavigated(VoipNavigationRequest request) {
    return _lastNavigatedSessionId == request.sessionId &&
        _lastNavigatedIsTutor == request.isTutor;
  }

  void _clearActiveIfCurrent(Future<void> shared) {
    if (identical(_activeRetry, shared)) {
      _activeRetry = null;
    }
  }
}
