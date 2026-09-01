import 'dart:collection';

enum VoipPendingCallKitActionType {
  accept,
  decline,
  timeout,
  ended,
}

class VoipPendingCallKitAction {
  const VoipPendingCallKitAction({
    required this.type,
    required this.data,
    required this.sessionId,
    required this.callKitId,
    required this.targetUserId,
    required this.queuedAt,
    required this.queuedForUserId,
  });

  final VoipPendingCallKitActionType type;
  final Map<String, dynamic> data;
  final String sessionId;
  final String? callKitId;
  final String? targetUserId;
  final DateTime queuedAt;
  final String? queuedForUserId;

  String get identityKey => '$sessionId:${callKitId ?? ''}';
}

typedef VoipAcceptPayloadExpiry = bool Function(
  Map<String, dynamic> data,
  DateTime now,
);

/// Owns only early CallKit action ordering and eligibility policy.
///
/// Native event subscription and asynchronous action dispatch remain in
/// `VoIPService`, which removes one eligible action at a time.
class VoipPendingCallKitActionQueue
    extends IterableBase<VoipPendingCallKitAction> {
  VoipPendingCallKitActionQueue({
    required this.ttl,
    required this.maxCount,
  })  : assert(!ttl.isNegative),
        assert(maxCount > 0);

  final Duration ttl;
  final int maxCount;
  final List<VoipPendingCallKitAction> _items = <VoipPendingCallKitAction>[];

  @override
  Iterator<VoipPendingCallKitAction> get iterator => _items.iterator;

  List<VoipPendingCallKitAction> get items =>
      List<VoipPendingCallKitAction>.unmodifiable(_items);

  void enqueue(VoipPendingCallKitAction action) {
    final existingIndex = _items.indexWhere(
      (item) => item.identityKey == action.identityKey,
    );
    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      if (_priority(action.type) >= _priority(existing.type)) {
        _items[existingIndex] = action;
      }
      return;
    }

    _items.add(action);
    if (_items.length > maxCount) {
      _items.removeAt(0);
    }
  }

  VoipPendingCallKitAction removeFirst() => _items.removeAt(0);

  void clear() => _items.clear();

  void prune({
    required DateTime now,
    required String? currentUserId,
    required VoipAcceptPayloadExpiry acceptPayloadHasExpired,
  }) {
    _items.removeWhere((action) {
      return !isEligible(
        action,
        now: now,
        currentUserId: currentUserId,
        acceptPayloadHasExpired: acceptPayloadHasExpired,
      );
    });
  }

  bool isEligible(
    VoipPendingCallKitAction action, {
    required DateTime now,
    required String? currentUserId,
    required VoipAcceptPayloadExpiry acceptPayloadHasExpired,
  }) {
    return !_hasExpired(
          action,
          now: now,
          acceptPayloadHasExpired: acceptPayloadHasExpired,
        ) &&
        _targetsCurrentUser(action, currentUserId);
  }

  bool _hasExpired(
    VoipPendingCallKitAction action, {
    required DateTime now,
    required VoipAcceptPayloadExpiry acceptPayloadHasExpired,
  }) {
    if (now.difference(action.queuedAt) >= ttl) {
      return true;
    }
    return action.type == VoipPendingCallKitActionType.accept &&
        acceptPayloadHasExpired(action.data, now);
  }

  bool _targetsCurrentUser(
    VoipPendingCallKitAction action,
    String? currentUserId,
  ) {
    final targetUserId = action.targetUserId;
    if (targetUserId != null) {
      return currentUserId != null && targetUserId == currentUserId;
    }
    final queuedForUserId = action.queuedForUserId;
    return queuedForUserId != null &&
        currentUserId != null &&
        queuedForUserId == currentUserId;
  }

  int _priority(VoipPendingCallKitActionType type) {
    switch (type) {
      case VoipPendingCallKitActionType.timeout:
        return 0;
      case VoipPendingCallKitActionType.accept:
        return 1;
      case VoipPendingCallKitActionType.decline:
      case VoipPendingCallKitActionType.ended:
        return 2;
    }
  }
}
