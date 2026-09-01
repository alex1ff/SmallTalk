import 'dart:async';

import 'call_chat_persistence_coordinator.dart';

class CallChatMessage {
  const CallChatMessage({
    required this.id,
    required this.text,
    required this.senderName,
    required this.senderId,
    required this.sentAt,
    required this.isLocal,
  });

  final String id;
  final String text;
  final String senderName;
  final String senderId;
  final DateTime sentAt;
  final bool isLocal;
}

typedef CallChatIdentity = ({String id, String name});

/// Owns chat messages and send/persist ordering for one call generation.
/// Transport and UI remain injected effects, so the state transitions can be
/// tested without Daily, Firebase or Flutter widgets.
class CallChatController {
  CallChatController({
    required String? Function() sessionId,
    required bool Function() canSend,
    required CallChatIdentity Function() localIdentity,
    required Future<bool> Function(String text) sendText,
    required Future<void> Function(String sessionId, List<CallChatMessage>)
        persistBatch,
    required Future<void> Function(String sessionId, String? reason) endSession,
    required void Function() onChanged,
    required void Function() onDraftAccepted,
    required void Function(CallChatMessage message) onMessageAppended,
    required void Function(String code) onError,
    DateTime Function()? now,
    int maxMessages = 200,
  })  : _sessionId = sessionId,
        _canSend = canSend,
        _localIdentity = localIdentity,
        _sendText = sendText,
        _persistBatch = persistBatch,
        _endSession = endSession,
        _onChanged = onChanged,
        _onDraftAccepted = onDraftAccepted,
        _onMessageAppended = onMessageAppended,
        _onError = onError,
        _now = now ?? DateTime.now,
        _maxMessages = maxMessages;

  final String? Function() _sessionId;
  final bool Function() _canSend;
  final CallChatIdentity Function() _localIdentity;
  final Future<bool> Function(String) _sendText;
  final Future<void> Function(String, List<CallChatMessage>) _persistBatch;
  final Future<void> Function(String, String?) _endSession;
  final void Function() _onChanged;
  final void Function() _onDraftAccepted;
  final void Function(CallChatMessage) _onMessageAppended;
  final void Function(String) _onError;
  final DateTime Function() _now;
  final int _maxMessages;

  final List<CallChatMessage> _messages = <CallChatMessage>[];
  final List<CallChatMessage> _ownSent = <CallChatMessage>[];
  final CallChatPersistenceCoordinator<CallChatMessage> _persistence =
      CallChatPersistenceCoordinator<CallChatMessage>();
  final Map<int, Set<Future<void>>> _pendingSends = <int, Set<Future<void>>>{};
  final Map<int, int> _sendingCounts = <int, int>{};
  int _messageSequence = 0;
  bool _open = false;
  int _unread = 0;

  List<CallChatMessage> get messages =>
      List<CallChatMessage>.unmodifiable(_messages);
  int get unreadCount => _unread;
  bool get isSending => (_sendingCounts[_persistence.generation] ?? 0) > 0;
  int get generation => _persistence.generation;

  void receive(
    String text, {
    required String senderId,
    required String senderName,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final message = CallChatMessage(
      id: _nextId(senderId, trimmed),
      text: trimmed,
      senderName: senderName,
      senderId: senderId,
      sentAt: _now(),
      isLocal: false,
    );
    _append(message, incrementUnread: !_open);
  }

  void setOpen(bool value) {
    _open = value;
    if (value) _unread = 0;
    _onChanged();
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !_canSend()) return;
    final session = _sessionId()?.trim();
    if (session == null || session.isEmpty) return;
    final generation = _persistence.generation;
    final identity = _localIdentity();
    final message = CallChatMessage(
      id: _nextId(identity.id, trimmed),
      text: trimmed,
      senderName: identity.name,
      senderId: identity.id,
      sentAt: _now(),
      isLocal: true,
    );
    _append(message);
    _onDraftAccepted();
    _sendingCounts[generation] = (_sendingCounts[generation] ?? 0) + 1;
    final settled = Completer<void>();
    (_pendingSends[generation] ??= <Future<void>>{}).add(settled.future);
    var delivered = false;
    try {
      delivered = await _sendText(trimmed);
      if (delivered && _isCurrent(generation, session)) {
        _ownSent.add(message);
        _persistence.recordMessage();
      }
    } catch (_) {
      _onError('send');
    } finally {
      final count = (_sendingCounts[generation] ?? 1) - 1;
      if (count == 0) {
        _sendingCounts.remove(generation);
      } else {
        _sendingCounts[generation] = count;
      }
      _pendingSends[generation]?.remove(settled.future);
      if (_pendingSends[generation]?.isEmpty == true) {
        _pendingSends.remove(generation);
      }
      settled.complete();
      _onChanged();
    }
  }

  Future<void> persist() async {
    final generation = _persistence.generation;
    final session = _sessionId()?.trim();
    if (session == null || session.isEmpty) return;
    final waits = List<Future<void>>.of(_pendingSends[generation] ?? const []);
    if (waits.isNotEmpty) await Future.wait(waits);
    if (!_isCurrent(generation, session)) return;
    try {
      await _persistence.persist(
        expectedGeneration: generation,
        snapshot: () => _ownSent,
        persistBatch: (messages) => _persistBatch(session, messages),
      );
    } catch (_) {
      _onError('persist');
    }
  }

  Future<void> endSessionAndPersist(String? reason) async {
    final generation = _persistence.generation;
    final session = _sessionId()?.trim();
    if (session == null || session.isEmpty) return;
    try {
      await _endSession(session, reason);
    } catch (_) {
      _onError('end_session');
    }
    if (_isCurrent(generation, session)) await persist();
  }

  void resetSession() {
    _persistence.reset();
    _messages.clear();
    _ownSent.clear();
    _unread = 0;
    _open = false;
    _onChanged();
  }

  bool _isCurrent(int generation, String session) =>
      _persistence.isCurrentGeneration(generation) &&
      _sessionId()?.trim() == session;

  String _nextId(String sender, String text) =>
      '${_now().microsecondsSinceEpoch}_${_messageSequence++}_${sender}_${text.hashCode}';

  void _append(CallChatMessage message, {bool incrementUnread = false}) {
    _messages.add(message);
    if (_messages.length > _maxMessages) {
      _messages.removeRange(0, _messages.length - _maxMessages);
    }
    if (incrementUnread) _unread++;
    _onMessageAppended(message);
    _onChanged();
  }
}
