import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/deepgram_transport_controller.dart';

void main() {
  test('single start owns recorder, socket, audio and existing configuration',
      () {
    fakeAsync((async) {
      final h = _Harness();
      h.controller.start();
      h.controller.start();
      async.flushMicrotasks();

      expect(h.refreshes, [false]);
      expect(h.recorders, hasLength(1));
      expect(h.recorders.single.subscriptionDuration,
          const Duration(milliseconds: 100));
      expect(h.controller.isStreaming, isTrue);
      expect(h.streaming, [true]);
      expect(h.started, 1);
      final config = h.configurations.single;
      expect(config.uri.scheme, 'wss');
      expect(config.uri.host, 'api.deepgram.com');
      expect(config.uri.path, '/v1/listen');
      expect(config.uri.queryParameters, {
        'encoding': 'linear16',
        'sample_rate': '16000',
        'channels': '1',
        'model': 'nova-3',
        'language': 'ru',
        'smart_format': 'true',
        'punctuate': 'true',
        'utterances': 'true',
        'interim_results': 'true',
        'vad_events': 'true',
        'endpointing': '500',
        'utterance_end_ms': '1000',
      });
      expect(config.protocols, ['token', 'test-key']);
      expect(config.headers, {'Authorization': 'Token test-key'});
      expect(config.connectTimeout, const Duration(seconds: 10));
      h.recorders.single.audio!.add(Uint8List.fromList([1, 2]));
      h.sockets.single.messages.add('transcript');
      async.flushMicrotasks();
      expect(h.sockets.single.sent.single, [1, 2]);
      expect(h.messages, ['transcript']);
      h.controller.stop();
      _settleStop(async);
    });
  });

  test('temporary token retains Bearer header without subprotocol', () {
    fakeAsync((async) {
      final h = _Harness()..credential = ' first.second.third ';
      h.controller.start();
      async.flushMicrotasks();
      expect(h.configurations.single.protocols, isNull);
      expect(h.configurations.single.headers,
          {'Authorization': 'Bearer first.second.third'});
      h.controller.stop();
      _settleStop(async);
    });
  });

  test('stop is shared, blocks audio immediately and drains final frames', () {
    fakeAsync((async) {
      final h = _Harness();
      h.controller.start();
      async.flushMicrotasks();
      final recorder = h.recorders.single;
      final socket = h.sockets.single;
      h.shouldRun = false;
      var stopped = false;
      final first = h.controller.stop()..then((_) => stopped = true);
      expect(identical(first, h.controller.stop()), isTrue);
      expect(h.controller.finalizing, isTrue);
      recorder.audio!.add(Uint8List.fromList([8]));
      socket.messages.add('final-while-muted');
      async.flushMicrotasks();

      expect(socket.controls, ['Finalize']);
      expect(socket.sent.whereType<Uint8List>(), isEmpty);
      expect(h.messages, ['final-while-muted']);
      expect(socket.cancels, 0);
      expect(recorder.stops, 1);
      expect(recorder.closes, 1);
      async.elapse(const Duration(milliseconds: 249));
      async.flushMicrotasks();
      expect(socket.controls, ['Finalize']);
      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();
      expect(socket.controls, ['Finalize', 'CloseStream']);
      socket.messages.add('last-final');
      async.elapse(const Duration(milliseconds: 99));
      async.flushMicrotasks();
      expect(stopped, isFalse);
      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();

      expect(stopped, isTrue);
      expect(h.messages, ['final-while-muted', 'last-final']);
      expect(socket.closes, 1);
      expect(socket.cancels, 1);
      expect(h.finalizations, 1);
      expect(h.clears, 1);
      expect(h.streaming, [true, false]);
      expect(h.controller.hasResources, isFalse);
      expect(h.controller.finalizing, isFalse);
    });
  });

  test('empty transport stop still shares and awaits caption finalization', () {
    fakeAsync((async) {
      final h = _Harness();
      final flush = Completer<void>();
      h.flush = flush.future;
      var stopped = false;
      final first = h.controller.stop()..then((_) => stopped = true);
      expect(identical(first, h.controller.stop()), isTrue);
      async.flushMicrotasks();
      expect(h.finalizations, 1);
      expect(stopped, isFalse);
      flush.complete();
      async.flushMicrotasks();
      expect(stopped, isTrue);
      expect(h.recorders, isEmpty);
    });
  });

  test('stop invalidates pending credentials without blocking a newer start',
      () {
    fakeAsync((async) {
      final h = _Harness();
      final oldCredential = Completer<String?>();
      h.nextCredential = oldCredential.future;
      h.controller.start();
      h.controller.stop();
      async.flushMicrotasks();
      h.session = 'new-session';
      h.controller.start(forceRefresh: true);
      async.flushMicrotasks();
      oldCredential.complete('old-key');
      async.flushMicrotasks();
      expect(h.refreshes, [false, true]);
      expect(h.recorders, hasLength(1));
      expect(h.recorders.single.closes, 0);
      expect(
          h.configurations.single.headers, {'Authorization': 'Token test-key'});
      expect(h.controller.isStreaming, isTrue);
      h.controller.stop();
      _settleStop(async);
    });
  });

  test('session switch ignores pending credentials and native permission', () {
    fakeAsync((async) {
      final h = _Harness();
      final credential = Completer<String?>();
      h.nextCredential = credential.future;
      h.controller.start();
      h.session = 'second';
      credential.complete('first-key');
      async.flushMicrotasks();
      expect(h.permissions, 0);
      expect(h.controller.startInProgress, isFalse);

      final permission = Completer<bool>();
      h.nextPermission = permission.future;
      h.controller.start();
      async.flushMicrotasks();
      h.controller.stop();
      permission.complete(true);
      async.flushMicrotasks();
      expect(h.recorders, isEmpty);
    });
  });

  for (final pendingStep in ['open', 'start']) {
    test('stop waits pending recorder $pendingStep then closes it exactly once',
        () {
      fakeAsync((async) {
        final h = _Harness();
        final pending = Completer<void>();
        h.configureRecorder = (recorder) {
          if (pendingStep == 'open') {
            recorder.openPending = pending.future;
          } else {
            recorder.startPending = pending.future;
          }
        };
        h.controller.start();
        async.flushMicrotasks();
        final oldRecorder = h.recorders.single;
        var stopped = false;
        h.controller.stop().then((_) => stopped = true);
        async.flushMicrotasks();
        expect(oldRecorder.closes, 0);
        expect(stopped, isFalse);
        pending.complete();
        _settleStop(async);
        expect(stopped, isTrue);
        expect(oldRecorder.closes, 1);
        expect(oldRecorder.stops, pendingStep == 'start' ? 1 : 0);
        expect(h.streaming.where((value) => value), isEmpty);
        h.configureRecorder = null;
        h.controller.start();
        async.flushMicrotasks();
        expect(h.recorders, hasLength(2));
        expect(h.recorders.last.closes, 0);
        expect(h.controller.isStreaming, isTrue);
        h.controller.stop();
        _settleStop(async);
        expect(oldRecorder.closes, 1);
      });
    });
  }

  test('pending recorder failure during stop still closes later resources', () {
    fakeAsync((async) {
      final h = _Harness();
      final pending = Completer<void>();
      h.configureRecorder = (recorder) {
        recorder.startPending = pending.future;
        recorder.startError = StateError('private-start-error');
      };
      h.controller.start();
      async.flushMicrotasks();
      final recorder = h.recorders.single;
      final socket = h.sockets.single;
      h.controller.stop();
      pending.complete();
      async.elapse(const Duration(milliseconds: 350));
      expect(recorder.closes, 1);
      expect(socket.controls, ['Finalize', 'CloseStream']);
      expect(socket.closes, 1);
      expect(h.finalizations, 1);
      expect(
        h.diagnostics,
        contains('deepgram_start_failed'),
      );
      expect(h.diagnostics.toString(), isNot(contains('private')));
    });
  });

  test('permission rejection reports its specific code without allocating', () {
    fakeAsync((async) {
      final h = _Harness()..nextPermission = Future<bool>.value(false);
      h.controller.start();
      async.flushMicrotasks();
      expect(
          h.issues.map((issue) => issue.$1), ['microphone_permission_denied']);
      expect(h.recorders, isEmpty);
      expect(h.controller.startInProgress, isFalse);
    });
  });

  test('recorder start failure closes resources and keeps diagnostics safe',
      () {
    fakeAsync((async) {
      final h = _Harness();
      h.configureRecorder = (recorder) =>
          recorder.startError = StateError('sensitive-token-and-transcript');
      h.controller.start();
      _settleStop(async);
      expect(h.issues.map((issue) => issue.$1), ['deepgram_start_failed']);
      expect(h.issues.toString(), isNot(contains('sensitive')));
      expect(h.recorders.single.closes, 1);
      expect(h.sockets.single.closes, 1);
      expect(h.controller.isStreaming, isFalse);
      expect(h.controller.hasResources, isFalse);
    });
  });

  test('audio sink failure invalidates immediately and restarts once', () {
    fakeAsync((async) {
      final h = _Harness();
      h.controller.start();
      async.flushMicrotasks();
      final socket = h.sockets.single..failAudio = true;
      h.recorders.single.audio!
        ..add(Uint8List.fromList([1]))
        ..add(Uint8List.fromList([2]));
      async.flushMicrotasks();
      expect(socket.audioAttempts, 1);
      expect(h.issues.map((issue) => issue.$1), ['audio_stream_error']);
      _settleStop(async);
      expect(h.refreshes, [false, true]);
      expect(h.recorders, hasLength(2));
      expect(h.recorders.first.closes, 1);
      expect(h.controller.isStreaming, isTrue);
      h.controller.stop();
      _settleStop(async);
    });
  });

  test('socket failures share two-second restart timer and refresh credentials',
      () {
    fakeAsync((async) {
      final h = _Harness();
      h.controller.start();
      async.flushMicrotasks();
      h.sockets.single.messages
        ..addError(StateError('private-error'))
        ..addError(StateError('private-error'));
      expect(async.nonPeriodicTimerCount, 1);
      async.elapse(const Duration(milliseconds: 1999));
      expect(h.refreshes, [false]);
      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();
      _settleStop(async);
      expect(h.refreshes, [false, true]);
      expect(h.sockets, hasLength(2));
      expect(h.issues.toString(), isNot(contains('private')));
      h.controller.stop();
      _settleStop(async);
    });
  });

  test('session switch rejects stale messages and delayed restart', () {
    fakeAsync((async) {
      final h = _Harness();
      h.controller.start();
      async.flushMicrotasks();
      h.sockets.single.messages.addError(StateError('socket-error'));
      h.session = 'second';
      h.sockets.single.messages.add('old-session-transcript');
      async.elapse(const Duration(seconds: 3));
      expect(h.messages, isEmpty);
      expect(h.refreshes, [false]);
      h.controller.stop();
      h.sockets.single.messages.add('old-session-final');
      _settleStop(async);
      expect(h.messages, isEmpty);
    });
  });

  test('stop cancels delayed restart and a draining sink failure restart', () {
    fakeAsync((async) {
      final h = _Harness();
      h.controller.start();
      async.flushMicrotasks();
      h.sockets.single.messages.addError(StateError('socket-error'));
      h.controller.stop();
      _settleStop(async);
      async.elapse(const Duration(seconds: 3));
      expect(h.refreshes, [false]);

      h.controller.start();
      async.flushMicrotasks();
      h.sockets.last.failAudio = true;
      h.recorders.last.audio!.add(Uint8List.fromList([1]));
      async.flushMicrotasks();
      h.controller.stop();
      _settleStop(async);
      async.elapse(const Duration(seconds: 3));
      expect(h.refreshes, [false, false]);
    });
  });

  test('failed cleanup steps still close remaining resources and flush', () {
    fakeAsync((async) {
      final h = _Harness();
      h.controller.start();
      async.flushMicrotasks();
      h.recorders.single.stopError = StateError('private-stop-error');
      h.sockets.single.failControl = true;
      h.sockets.single.closeError = StateError('private-close-error');
      h.controller.stop();
      _settleStop(async);
      expect(h.recorders.single.stops, 1);
      expect(h.recorders.single.closes, 1);
      expect(h.sockets.single.closes, 1);
      expect(h.sockets.single.cancels, 1);
      expect(h.finalizations, 1);
      expect(h.clears, 1);
      expect(h.diagnostics, everyElement(isNot(contains('private'))));
    });
  });

  test('recorder close failure quarantines transport and blocks new starts',
      () {
    fakeAsync((async) {
      final h = _Harness();
      h.controller.start();
      async.flushMicrotasks();
      h.recorders.single.closeError = StateError('private-recorder-handle');

      h.controller.stop();
      _settleStop(async);

      expect(h.controller.isQuarantined, isTrue);
      expect(h.controller.hasResources, isTrue);
      expect(
        h.issues.map((issue) => issue.$1),
        contains('deepgram_recorder_quarantined'),
      );
      expect(h.diagnostics, contains('deepgram_recorder_close_failed'));
      expect(h.diagnostics, everyElement(isNot(contains('private'))));

      h.controller.start(forceRefresh: true);
      async.flushMicrotasks();
      expect(h.recorders, hasLength(1));
      expect(h.refreshes, [false]);
    });
  });

  test('dispose cancels restarts and permanently rejects new starts', () {
    fakeAsync((async) {
      final h = _Harness();
      h.controller.start();
      async.flushMicrotasks();
      h.sockets.single.messages.addError(StateError('socket-error'));
      h.controller.dispose();
      _settleStop(async);
      async.elapse(const Duration(seconds: 3));
      h.controller.start();
      async.flushMicrotasks();
      expect(h.refreshes, [false]);
      expect(h.recorders.single.closes, 1);
      expect(async.nonPeriodicTimerCount, 0);
    });
  });
}

void _settleStop(FakeAsync async) {
  async.flushMicrotasks();
  async.elapse(const Duration(milliseconds: 250));
  async.flushMicrotasks();
  async.elapse(const Duration(milliseconds: 100));
  async.flushMicrotasks();
}

class _Harness {
  _Harness() {
    controller = DeepgramTransportController(
      shouldRun: () => shouldRun,
      sessionId: () => session,
      language: () => 'ru',
      resolveCredential: ({bool forceRefresh = false}) async {
        refreshes.add(forceRefresh);
        final pending = nextCredential;
        nextCredential = null;
        return pending == null ? credential : await pending;
      },
      requestMicrophonePermission: () async {
        permissions++;
        return await (nextPermission ?? Future<bool>.value(true));
      },
      createRecorder: () {
        final recorder = _Recorder();
        configureRecorder?.call(recorder);
        recorders.add(recorder);
        return recorder;
      },
      connectSocket: (config) {
        configurations.add(config);
        final socket = _Socket();
        sockets.add(socket);
        return socket;
      },
      onMessage: messages.add,
      onIssue: ({required code, required message}) =>
          issues.add((code, message)),
      onCredentialUnavailable: () => unavailable++,
      onStreamingChanged: streaming.add,
      onStarted: () => started++,
      finalizeCaptionAndFlush: () async {
        finalizations++;
        await flush;
      },
      clearCaption: () => clears++,
      onDiagnostic: diagnostics.add,
    );
  }

  late final DeepgramTransportController controller;
  bool shouldRun = true;
  String session = 'session';
  String? credential = 'test-key';
  Future<String?>? nextCredential;
  Future<bool>? nextPermission;
  Future<void>? flush;
  void Function(_Recorder)? configureRecorder;
  int permissions = 0;
  int started = 0;
  int finalizations = 0;
  int clears = 0;
  int unavailable = 0;
  final refreshes = <bool>[];
  final recorders = <_Recorder>[];
  final sockets = <_Socket>[];
  final configurations = <DeepgramSocketConfiguration>[];
  final messages = <dynamic>[];
  final issues = <(String, String)>[];
  final diagnostics = <String>[];
  final streaming = <bool>[];
}

class _Recorder implements DeepgramRecorder {
  Future<void>? openPending;
  Future<void>? startPending;
  Object? startError;
  Object? stopError;
  Object? closeError;
  StreamSink<Uint8List>? audio;
  Duration? subscriptionDuration;
  int stops = 0;
  int closes = 0;
  @override
  bool isRecording = false;

  @override
  Future<void> open() async => await openPending;

  @override
  Future<void> setSubscriptionDuration(Duration duration) async {
    subscriptionDuration = duration;
  }

  @override
  Future<void> start(StreamSink<Uint8List> sink) async {
    audio = sink;
    await startPending;
    if (startError != null) throw startError!;
    isRecording = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (stopError != null) throw stopError!;
    isRecording = false;
  }

  @override
  Future<void> close() async {
    closes++;
    if (closeError != null) throw closeError!;
    isRecording = false;
  }
}

class _Socket implements DeepgramSocket {
  _Socket() {
    messages = StreamController<dynamic>(
      sync: true,
      onCancel: () => cancels++,
    );
  }

  late final StreamController<dynamic> messages;
  final sent = <Object>[];
  int closes = 0;
  int cancels = 0;
  int audioAttempts = 0;
  bool failAudio = false;
  bool failControl = false;
  Object? closeError;
  List<String> get controls => sent
      .whereType<String>()
      .map((message) => (jsonDecode(message) as Map)['type'] as String)
      .toList();

  @override
  Stream<dynamic> get stream => messages.stream;

  @override
  void add(Object data) {
    if (data is Uint8List) {
      audioAttempts++;
      if (failAudio) throw StateError('sensitive-audio-error');
    } else if (failControl) {
      throw StateError('sensitive-control-error');
    }
    sent.add(data);
  }

  @override
  Future<void> close() async {
    closes++;
    if (closeError != null) throw closeError!;
  }
}
