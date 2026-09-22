import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/io.dart';

import 'deepgram_transport_controller.dart';

/// Production wiring kept separate so lifecycle tests need no platform channel.
DeepgramTransportController createDeepgramTransportController({
  required bool Function() shouldRun,
  required String? Function() sessionId,
  required String Function() language,
  required DeepgramCredentialResolver resolveCredential,
  required void Function(dynamic) onMessage,
  required DeepgramIssueCallback onIssue,
  required void Function() onCredentialUnavailable,
  required void Function(bool) onStreamingChanged,
  required void Function() onStarted,
  required Future<void> Function() finalizeCaptionAndFlush,
  required void Function() clearCaption,
  void Function(String code)? onDiagnostic,
}) {
  return DeepgramTransportController(
    shouldRun: shouldRun,
    sessionId: sessionId,
    language: language,
    resolveCredential: resolveCredential,
    requestMicrophonePermission: () async =>
        (await Permission.microphone.request()).isGranted,
    createRecorder: () => _FlutterSoundDeepgramRecorder(FlutterSoundRecorder()),
    connectSocket: (config) => _IODeepgramSocket(
      IOWebSocketChannel.connect(
        config.uri,
        protocols: config.protocols,
        headers: config.headers,
        connectTimeout: config.connectTimeout,
      ),
    ),
    onMessage: onMessage,
    onIssue: onIssue,
    onCredentialUnavailable: onCredentialUnavailable,
    onStreamingChanged: onStreamingChanged,
    onStarted: onStarted,
    finalizeCaptionAndFlush: finalizeCaptionAndFlush,
    clearCaption: clearCaption,
    onDiagnostic: onDiagnostic,
  );
}

class _FlutterSoundDeepgramRecorder implements DeepgramRecorder {
  _FlutterSoundDeepgramRecorder(this._recorder);

  final FlutterSoundRecorder _recorder;

  @override
  bool get isRecording => _recorder.isRecording;

  @override
  Future<void> open() async {
    await _recorder.openRecorder();
  }

  @override
  Future<void> setSubscriptionDuration(Duration duration) =>
      _recorder.setSubscriptionDuration(duration);

  @override
  Future<void> start(StreamSink<Uint8List> sink) => _recorder.startRecorder(
        toStream: sink,
        codec: Codec.pcm16,
        sampleRate: 16000,
        numChannels: 1,
      );

  @override
  Future<void> stop() async {
    await _recorder.stopRecorder();
  }

  @override
  Future<void> close() => _recorder.closeRecorder();
}

class _IODeepgramSocket implements DeepgramSocket {
  _IODeepgramSocket(this._channel) {
    // This SDK reports connection failure on both ready and stream. The stream
    // listener owns reporting/retry; consume ready's duplicate error as well.
    unawaited(_channel.ready.catchError((Object _) {}));
  }

  final IOWebSocketChannel _channel;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  void add(Object data) => _channel.sink.add(data);

  @override
  Future<void> close() async {
    await _channel.sink.close();
  }
}
