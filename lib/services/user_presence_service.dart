import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/schema/util/firestore_util.dart';

class UserPresenceService {
  UserPresenceService._();

  static final UserPresenceService instance = UserPresenceService._();

  static const Duration _heartbeatInterval = Duration(seconds: 60);
  static const Duration _minimumWriteInterval = Duration(seconds: 45);

  Timer? _heartbeatTimer;
  DateTime? _lastWriteStartedAt;

  void start() {
    _heartbeatTimer?.cancel();
    unawaited(markSeen(force: true));
    _heartbeatTimer = Timer.periodic(
      _heartbeatInterval,
      (_) => unawaited(markSeen()),
    );
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastWriteStartedAt = null;
  }

  Future<void> markSeen({bool force = false}) async {
    final userRef = currentUserReference;
    if (!loggedIn || userRef == null) {
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastWriteStartedAt != null &&
        now.difference(_lastWriteStartedAt!) < _minimumWriteInterval) {
      return;
    }

    _lastWriteStartedAt = now;
    try {
      await userRef.update(
        mapToFirestore(
          <String, dynamic>{
            'lastSeenAt': FieldValue.serverTimestamp(),
          },
        ),
      );
    } catch (error) {
      debugPrint('UserPresenceService: failed to update lastSeenAt: $error');
    }
  }
}
