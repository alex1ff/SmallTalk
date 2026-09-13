import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/call_chat_controller.dart';

void main() {
  test('incoming messages are trimmed, bounded and unread only while closed',
      () {
    final h = _Harness();
    h.controller.receive('  ', senderId: 'peer', senderName: 'Peer');
    expect(h.controller.messages, isEmpty);
    for (var index = 0; index < 201; index++) {
      h.controller.receive(' $index ', senderId: 'peer', senderName: 'Peer');
    }
    expect(h.controller.messages.length, 200);
    expect(h.controller.messages.first.text, '1');
    expect(h.controller.unreadCount, 201);
    h.controller.setOpen(true);
    h.controller.receive('hello', senderId: 'peer', senderName: 'Peer');
    expect(h.controller.unreadCount, 0);
    expect(h.controller.messages.last.isLocal, isFalse);
    expect(() => h.controller.messages.clear(), throwsUnsupportedError);
  });

  test('persist waits successful pending send and records the real message',
      () async {
    final h = _Harness();
    final pending = Completer<bool>();
    h.send = (_) => pending.future;
    final sent = h.controller.send(' hello ');
    expect(h.controller.messages.single.text, 'hello');
    expect(h.controller.isSending, isTrue);
    expect(h.acceptedDrafts, 1);
    final persist = h.controller.persist();
    await Future<void>.value();
    expect(h.batches, isEmpty);
    pending.complete(true);
    await sent;
    await persist;
    expect(h.batches.single.single.text, 'hello');
    expect(h.batches.single.single.isLocal, isTrue);
    expect(h.controller.isSending, isFalse);
  });

  test('late send from old session cannot clear sending or persist new state',
      () async {
    final h = _Harness();
    final oldSend = Completer<bool>();
    final newSend = Completer<bool>();
    h.send = (_) => oldSend.future;
    final old = h.controller.send('old');
    h.session = 'next';
    h.controller.resetSession();
    h.send = (_) => newSend.future;
    final current = h.controller.send('new');
    oldSend.complete(true);
    await old;
    expect(h.controller.isSending, isTrue);
    newSend.complete(true);
    await current;
    await h.controller.persist();
    expect(h.batches.single.map((message) => message.text), ['new']);
    expect(h.persistedSessions, ['next']);
  });

  test('failed and rejected sends remain optimistic but are not persisted',
      () async {
    final h = _Harness();
    h.send = (_) async => throw StateError('secret');
    await h.controller.send('failed');
    h.send = (_) async => false;
    await h.controller.send('not delivered');
    await h.controller.persist();
    expect(h.controller.messages.length, 2);
    expect(h.batches.single, isEmpty);
    expect(h.errors, ['send']);
    expect(h.controller.isSending, isFalse);
  });

  test(
      'end failure still persists; session replacement never persists into another',
      () async {
    final h = _Harness();
    await h.controller.send('hello');
    h.end = (_, __) async => throw StateError('private payload');
    await h.controller.endSessionAndPersist('user_ended');
    expect(h.batches.single.single.text, 'hello');
    expect(h.errors, ['end_session']);

    final pendingEnd = Completer<void>();
    h.end = (_, __) => pendingEnd.future;
    final end = h.controller.endSessionAndPersist('peer_left');
    h.session = 'next';
    h.controller.resetSession();
    pendingEnd.complete();
    await end;
    expect(h.persistedSessions, ['session']);
  });

  test('invalid session skips requests and eligibility suppresses send',
      () async {
    final h = _Harness();
    h.canSend = false;
    await h.controller.send('hello');
    expect(h.controller.messages, isEmpty);
    expect(h.acceptedDrafts, 0);
    h.session = ' ';
    await h.controller.endSessionAndPersist(null);
    expect(h.persistedSessions, isEmpty);
  });

  test('message delivered during persistence triggers a dirty tail', () async {
    final h = _Harness();
    await h.controller.send('first');
    final firstBatch = Completer<void>();
    h.persistAction = (batchNumber) =>
        batchNumber == 1 ? firstBatch.future : Future<void>.value();
    final persistence = h.controller.persist();
    await Future<void>.value();
    expect(h.batches.map((batch) => batch.length), [1]);
    await h.controller.send('second');
    firstBatch.complete();
    await persistence;
    expect(h.batches.map((batch) => batch.length), [1, 2]);
  });
}

class _Harness {
  _Harness() {
    controller = CallChatController(
      sessionId: () => session,
      canSend: () => canSend,
      localIdentity: () => (id: 'me', name: 'Me'),
      sendText: (text) => send(text),
      persistBatch: (sessionId, messages) async {
        persistedSessions.add(sessionId);
        batches.add(messages);
        await persistAction(batches.length);
      },
      endSession: (sessionId, reason) => end(sessionId, reason),
      onChanged: () {},
      onDraftAccepted: () => acceptedDrafts++,
      onMessageAppended: (_) {},
      onError: errors.add,
      now: () => DateTime.utc(2026, 9, 1),
    );
  }

  String? session = 'session';
  bool canSend = true;
  int acceptedDrafts = 0;
  Future<bool> Function(String) send = (_) async => true;
  Future<void> Function(String, String?) end = (_, __) async {};
  final batches = <List<CallChatMessage>>[];
  final persistedSessions = <String>[];
  final errors = <String>[];
  Future<void> Function(int batchNumber) persistAction =
      (_) => Future<void>.value();
  late final CallChatController controller;
}
