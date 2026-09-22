import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'daily_join_credentials.dart' as credentials;
import 'deepgram_stop_single_flight.dart';
import 'deepgram_stream_gate.dart';

typedef DeepgramCredentialResolver = Future<String?> Function({
  bool forceRefresh,
});
typedef DeepgramIssueCallback = void Function({
  required String code,
  required String message,
});

/// Only the native recorder operations used by this transport.
abstract interface class DeepgramRecorder {
  bool get isRecording;
  Future<void> open();
  Future<void> setSubscriptionDuration(Duration duration);
  Future<void> start(StreamSink<Uint8List> sink);
  Future<void> stop();
  Future<void> close();
}

abstract interface class DeepgramSocket {
  Stream<dynamic> get stream;
  void add(Object data);
  Future<void> close();
}

class DeepgramSocketConfiguration {
  const DeepgramSocketConfiguration({
    required this.uri,
    required this.protocols,
    required this.headers,
    required this.connectTimeout,
  });

  final Uri uri;
  final List<String>? protocols;
  final Map<String, String> headers;
  final Duration connectTimeout;
}

/// Owns one call's recorder, socket, subscriptions, generations and retries.
/// Caption assembly, credential policy and widget state remain with the caller.
class DeepgramTransportController {
  DeepgramTransportController({
    required bool Function() shouldRun,
    required String? Function() sessionId,
    required String Function() language,
    required DeepgramCredentialResolver resolveCredential,
    required Future<bool> Function() requestMicrophonePermission,
    required DeepgramRecorder Function() createRecorder,
    required DeepgramSocket Function(DeepgramSocketConfiguration) connectSocket,
    required void Function(dynamic) onMessage,
    required DeepgramIssueCallback onIssue,
    required void Function() onCredentialUnavailable,
    required void Function(bool) onStreamingChanged,
    required void Function() onStarted,
    required Future<void> Function() finalizeCaptionAndFlush,
    required void Function() clearCaption,
    void Function(String code)? onDiagnostic,
  })  : _shouldRun = shouldRun,
        _sessionId = sessionId,
        _language = language,
        _resolveCredential = resolveCredential,
        _requestMicrophonePermission = requestMicrophonePermission,
        _createRecorder = createRecorder,
        _connectSocket = connectSocket,
        _onMessage = onMessage,
        _onIssue = onIssue,
        _onCredentialUnavailable = onCredentialUnavailable,
        _onStreamingChanged = onStreamingChanged,
        _onStarted = onStarted,
        _finalizeCaptionAndFlush = finalizeCaptionAndFlush,
        _clearCaption = clearCaption,
        _onDiagnostic = onDiagnostic;

  final bool Function() _shouldRun;
  final String? Function() _sessionId;
  final String Function() _language;
  final DeepgramCredentialResolver _resolveCredential;
  final Future<bool> Function() _requestMicrophonePermission;
  final DeepgramRecorder Function() _createRecorder;
  final DeepgramSocket Function(DeepgramSocketConfiguration) _connectSocket;
  final void Function(dynamic) _onMessage;
  final DeepgramIssueCallback _onIssue;
  final void Function() _onCredentialUnavailable;
  final void Function(bool) _onStreamingChanged;
  final void Function() _onStarted;
  final Future<void> Function() _finalizeCaptionAndFlush;
  final void Function() _clearCaption;
  final void Function(String code)? _onDiagnostic;
  final _gate = DeepgramStreamGate();
  final _stopSingleFlight = DeepgramStopSingleFlight();

  _DeepgramResources? _active;
  Timer? _restartTimer;
  int _restartRevision = 0;
  bool _isStreaming = false;
  bool _stopping = false;
  bool _disposed = false;
  bool _quarantined = false;

  bool get isStreaming => _isStreaming;
  bool get startInProgress => _gate.startInProgress;
  bool get finalizing => _gate.finalizing;
  bool get hasResources => _active?.hasResources ?? false;
  bool get isQuarantined => _quarantined;

  Future<void> sync({bool forceRefresh = false}) async {
    if (_disposed) return;
    if (_shouldRun()) {
      await start(forceRefresh: forceRefresh);
    } else {
      await stop();
      _clearCaption();
    }
  }

  Future<void> start({bool forceRefresh = false}) async {
    if (_disposed ||
        _quarantined ||
        _stopping ||
        _isStreaming ||
        _gate.startInProgress ||
        !_shouldRun()) {
      return;
    }

    final resources = _DeepgramResources(
      generation: _gate.beginStart(),
      sessionId: _sessionId()?.trim(),
    );
    _active = resources;
    var started = false;
    try {
      final credential = await _resolveCredential(forceRefresh: forceRefresh);
      if (!_isCurrent(resources)) return;
      final sanitized = credentials.sanitizeDeepgramCredential(credential);
      if (sanitized == null) {
        _onCredentialUnavailable();
        return;
      }

      final granted = await _requestMicrophonePermission();
      if (!_isCurrent(resources)) return;
      if (!granted) {
        _onIssue(
          code: 'microphone_permission_denied',
          message: 'Субтитры временно недоступны: нет доступа к микрофону.',
        );
        return;
      }

      final recorder = _createRecorder();
      resources.recorder = recorder;
      await _recorderOperation(resources, recorder.open);
      if (!_isCurrent(resources)) return;
      await _recorderOperation(
        resources,
        () => recorder.setSubscriptionDuration(
          const Duration(milliseconds: 100),
        ),
      );
      if (!_isCurrent(resources)) return;

      final socket = _connectSocket(_socketConfiguration(sanitized));
      resources.socket = socket;
      resources.messages = socket.stream.listen(
        (dynamic message) {
          if (!_canHandleMessage(resources)) return;
          _onMessage(message);
        },
        onError: (Object _) => _handleSocketFailure(resources),
        onDone: () => _handleSocketFailure(resources),
      );
      if (!_isCurrent(resources)) return;

      final audio = StreamController<Uint8List>();
      resources.audio = audio;
      resources.audioSubscription = audio.stream.listen(
        (data) {
          if (!_isCurrent(resources)) return;
          try {
            socket.add(data);
          } catch (_) {
            _handleAudioSinkFailure(resources);
          }
        },
        onError: (Object _) {
          if (_isCurrent(resources)) _reportAudioIssue();
        },
      );
      await _recorderOperation(resources, () => recorder.start(audio.sink));
      if (!_isCurrent(resources)) return;

      started = true;
      _isStreaming = true;
      _onStreamingChanged(true);
      if (_isCurrent(resources)) _onStarted();
    } catch (_) {
      if (_isCurrent(resources)) {
        _onIssue(
          code: 'deepgram_start_failed',
          message:
              'Субтитры временно недоступны: не удалось запустить распознавание речи.',
        );
      }
      _onDiagnostic?.call('deepgram_start_failed');
    } finally {
      _gate.finishStart(resources.generation);
      // A stale continuation can only join cleanup of its own lease. In
      // particular it must never stop a newer recorder after credential await.
      if (!started && identical(_active, resources)) {
        await _stopTransport();
      }
    }
  }

  bool _isCurrent(_DeepgramResources resources) {
    return !_disposed &&
        identical(_active, resources) &&
        !_gate.stopRequested &&
        _gate.isCurrent(resources.generation) &&
        _sessionId()?.trim() == resources.sessionId &&
        _shouldRun();
  }

  bool _canHandleMessage(_DeepgramResources resources) {
    return !_disposed &&
        identical(_active, resources) &&
        _sessionId()?.trim() == resources.sessionId &&
        _gate.canHandleMessage(
          generation: resources.generation,
          shouldRun: _shouldRun,
        );
  }

  Future<void> _recorderOperation(
    _DeepgramResources resources,
    Future<void> Function() operation,
  ) async {
    // Install the barrier before invoking native code. Closing before a pending
    // open/start settles can otherwise resurrect an already-released recorder.
    final settled = Completer<void>();
    resources.recorderOperation = settled.future;
    try {
      await operation();
    } finally {
      settled.complete();
      if (identical(resources.recorderOperation, settled.future)) {
        resources.recorderOperation = null;
      }
    }
  }

  DeepgramSocketConfiguration _socketConfiguration(String credential) {
    return DeepgramSocketConfiguration(
      uri: Uri(
        scheme: 'wss',
        host: 'api.deepgram.com',
        path: '/v1/listen',
        queryParameters: {
          'encoding': 'linear16',
          'sample_rate': '16000',
          'channels': '1',
          'model': 'nova-3',
          'language': _language(),
          'smart_format': 'true',
          'punctuate': 'true',
          'utterances': 'true',
          'interim_results': 'true',
          'vad_events': 'true',
          'endpointing': '500',
          'utterance_end_ms': '1000',
        },
      ),
      protocols:
          credentials.looksLikeJwt(credential) ? null : ['token', credential],
      headers: {
        'Authorization': credentials.buildDeepgramAuthHeader(credential),
      },
      connectTimeout: const Duration(seconds: 10),
    );
  }

  void _handleSocketFailure(_DeepgramResources resources) {
    if (!_isCurrent(resources)) return;
    _onIssue(
      code: 'deepgram_websocket_error',
      message:
          'Субтитры временно недоступны: соединение с распознаванием речи прервано.',
    );
    if (_restartTimer != null) return;
    _restartTimer = Timer(const Duration(seconds: 2), () {
      _restartTimer = null;
      if (_isCurrent(resources)) {
        _runBackground(_restartAfterStop(resources));
      }
    });
  }

  void _handleAudioSinkFailure(_DeepgramResources resources) {
    if (!_isCurrent(resources)) return;
    _reportAudioIssue();
    if (!_gate.requestSinkFailureStop()) return;
    _runBackground(_restartAfterStop(resources));
  }

  void _reportAudioIssue() {
    _onIssue(
      code: 'audio_stream_error',
      message:
          'Субтитры временно недоступны: не удалось передать звук на распознавание.',
    );
  }

  Future<void> _restartAfterStop(_DeepgramResources resources) async {
    final revision = _restartRevision;
    await _stopTransport();
    if (!_disposed &&
        !_quarantined &&
        revision == _restartRevision &&
        _sessionId()?.trim() == resources.sessionId &&
        _shouldRun()) {
      await start(forceRefresh: true);
    }
  }

  void _runBackground(Future<void> operation) {
    unawaited(operation.catchError((Object _, StackTrace __) {
      _onDiagnostic?.call('deepgram_background_operation_failed');
    }));
  }

  /// Invalidates starts/retries before returning the shared cleanup future.
  Future<void> stop() {
    _restartRevision++;
    _restartTimer?.cancel();
    _restartTimer = null;
    return _stopTransport();
  }

  Future<void> dispose() {
    _disposed = true;
    return stop();
  }

  Future<void> _stopTransport() => _stopSingleFlight.run(_performStop);

  Future<void> _performStop() async {
    _stopping = true;
    _restartTimer?.cancel();
    _restartTimer = null;
    final resources = _active;
    final hadTransport = resources?.hasResources ?? false;
    _gate.requestStop(finalizing: resources?.socket != null);
    try {
      final safeToRelease =
          resources == null || await _closeResources(resources);
      if (safeToRelease && identical(_active, resources)) _active = null;
      _gate.finishStop();
      if (_isStreaming || hadTransport) {
        _isStreaming = false;
        _onStreamingChanged(false);
      }
      // Interim captions can outlive a failed/absent transport; always flush.
      await _finalizeCaptionAndFlush();
      if (hadTransport) _clearCaption();
    } finally {
      _gate.finishFinalization();
      _gate.finishStop();
      _stopping = false;
    }
  }

  Future<bool> _closeResources(_DeepgramResources resources) async {
    var recorderClosed = true;
    // Cancel subscriptions before native teardown. Some platform streams can
    // defer completion until their source closes, so do not deadlock cleanup
    // on cancellation; generation invalidation already blocks callbacks.
    _cancelWithoutBlocking(
      resources.audioSubscription,
      'deepgram_audio_subscription_cancel_failed',
    );
    await _cleanup(
      'deepgram_recorder_operation_failed',
      () async {
        final operation = resources.recorderOperation;
        if (operation != null) await operation;
      },
    );
    final recorder = resources.recorder;
    if (recorder != null) {
      await _cleanup('deepgram_recorder_stop_failed', () async {
        if (recorder.isRecording) await recorder.stop();
      });
      recorderClosed =
          await _cleanup('deepgram_recorder_close_failed', recorder.close);
      if (!recorderClosed) {
        _quarantined = true;
        _onIssue(
          code: 'deepgram_recorder_quarantined',
          message:
              'Субтитры отключены: перезапустите звонок, чтобы снова включить микрофон.',
        );
      }
    }
    final socket = resources.socket;
    if (socket != null) {
      _sendControl(socket, 'Finalize');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _sendControl(socket, 'CloseStream');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await _cleanup('deepgram_socket_close_failed', socket.close);
      // ignore: avoid_print
    }
    _gate.finishFinalization();
    _cancelWithoutBlocking(
      resources.messages,
      'deepgram_message_subscription_cancel_failed',
    );
    // Closing a controller can await a platform subscription cancellation.
    // The cancellation was initiated above; start close without making the
    // native cleanup root wait on a potentially cyclic stream future.
    final audio = resources.audio;
    if (audio != null && !audio.isClosed) {
      unawaited(
          _cleanup('deepgram_audio_controller_close_failed', audio.close));
    }
    // ignore: avoid_print
    return recorderClosed;
  }

  void _sendControl(DeepgramSocket socket, String type) {
    try {
      socket.add(jsonEncode({'type': type}));
    } catch (_) {
      _onDiagnostic?.call('deepgram_control_send_failed');
    }
  }

  Future<bool> _cleanup(String code, Future<void> Function() operation) async {
    try {
      await operation();
      return true;
    } catch (_) {
      _onDiagnostic?.call(code);
      return false;
    }
  }

  void _cancelWithoutBlocking(
    StreamSubscription<dynamic>? subscription,
    String code,
  ) {
    if (subscription == null) return;
    unawaited(_cleanup(code, subscription.cancel));
  }
}

class _DeepgramResources {
  _DeepgramResources({required this.generation, required this.sessionId});

  final int generation;
  final String? sessionId;
  DeepgramRecorder? recorder;
  DeepgramSocket? socket;
  StreamController<Uint8List>? audio;
  StreamSubscription<Uint8List>? audioSubscription;
  StreamSubscription<dynamic>? messages;
  Future<void>? recorderOperation;

  bool get hasResources => recorder != null || socket != null || audio != null;
}
