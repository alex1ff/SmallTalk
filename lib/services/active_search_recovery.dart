import 'package:cloud_firestore/cloud_firestore.dart';

const Duration activeSearchHeartbeatStaleAfter = Duration(seconds: 90);

typedef ActiveSearchSnapshotReader
    = Future<DocumentSnapshot<Map<String, dynamic>>?> Function(String userId);

class ActiveSearchRecoveryState {
  const ActiveSearchRecoveryState({
    required this.userId,
    required this.requestId,
    required this.data,
    required this.exists,
    required this.belongsToUser,
    required this.isLiveStatus,
    required this.isExpired,
  });

  final String userId;
  final String? requestId;
  final Map<String, dynamic> data;
  final bool exists;
  final bool belongsToUser;
  final bool isLiveStatus;
  final bool isExpired;

  bool get hasActiveSearch =>
      exists && belongsToUser && isLiveStatus && !isExpired;

  bool get canResumeSearch => hasActiveSearch && requestId != null;

  bool get isTerminalStatus {
    final normalizedStatus = status;
    return normalizedStatus == 'stopped' ||
        normalizedStatus == 'expired' ||
        normalizedStatus == 'cancelled' ||
        normalizedStatus == 'error' ||
        normalizedStatus == 'failed' ||
        normalizedStatus == 'completed';
  }

  String? get status => activeSearchNonEmpty(data['status']);

  String? get sessionId =>
      activeSearchNonEmpty(data['currentSessionId']) ??
      activeSearchNonEmpty(data['matchedSessionId']) ??
      activeSearchNonEmpty(data['activeSessionId']);

  bool get canResumeUnboundSearch => canResumeSearch && sessionId == null;

  bool get canResumeConnection {
    if (!exists || !belongsToUser || sessionId == null || isExpired) {
      return false;
    }

    switch (status) {
      case 'matched':
      case 'matching':
      case 'pending_confirmation':
      case 'connecting':
        return true;
      default:
        return false;
    }
  }

  DateTime? get expiresAt => activeSearchDateTime(data['expiresAt']);

  Duration remainingSearchDuration({DateTime? now}) {
    final expiresAtValue = expiresAt;
    if (expiresAtValue == null) {
      return Duration.zero;
    }

    final remaining = expiresAtValue.difference(now ?? DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

String? activeSearchNonEmpty(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

DateTime? activeSearchDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return null;
}

Future<DocumentSnapshot<Map<String, dynamic>>?> readActiveSearchRequestSnapshot(
    String userId) {
  return FirebaseFirestore.instance
      .collection('searchRequests')
      .doc(userId)
      .get();
}

bool activeSearchRequestBelongsToUser({
  required DocumentSnapshot<Map<String, dynamic>> doc,
  required Map<String, dynamic> data,
  required String userId,
}) {
  if (doc.id != userId) {
    return false;
  }

  String? referenceId(dynamic value) {
    if (value is DocumentReference) {
      return activeSearchNonEmpty(value.id);
    }
    return null;
  }

  final ownerIds = <String?>[
    activeSearchNonEmpty(data['userId']),
    activeSearchNonEmpty(data['studentId']),
    activeSearchNonEmpty(data['requesterId']),
    referenceId(data['userRef']),
    referenceId(data['studentRef']),
    referenceId(data['requesterRef']),
  ].whereType<String>().toList();

  return ownerIds.isEmpty || ownerIds.every((ownerId) => ownerId == userId);
}

bool activeSearchRequestHasLiveStatus(Map<String, dynamic> data) {
  switch (activeSearchNonEmpty(data['status'])) {
    case 'active':
    case 'matching':
      return true;
    default:
      return false;
  }
}

bool activeSearchRequestIsExpired(
  Map<String, dynamic> data, {
  DateTime? now,
}) {
  final status = activeSearchNonEmpty(data['status']);
  if (status == 'stopped' ||
      status == 'expired' ||
      status == 'cancelled' ||
      status == 'error') {
    return true;
  }

  final effectiveNow = now ?? DateTime.now();
  final expiresAt = activeSearchDateTime(data['expiresAt']);
  if (expiresAt == null || !expiresAt.isAfter(effectiveNow)) {
    return true;
  }

  if (activeSearchNonEmpty(data['appState']) == 'background') {
    final backgroundExpiresAt =
        activeSearchDateTime(data['backgroundExpiresAt']);
    if (backgroundExpiresAt != null &&
        !backgroundExpiresAt.isAfter(effectiveNow)) {
      return true;
    }
    if (backgroundExpiresAt != null &&
        backgroundExpiresAt.isAfter(effectiveNow)) {
      return false;
    }
  }

  final heartbeatAt = activeSearchDateTime(data['heartbeatAt']);
  if (heartbeatAt == null) {
    return true;
  }
  if (effectiveNow.difference(heartbeatAt) > activeSearchHeartbeatStaleAfter) {
    return true;
  }

  return false;
}

Future<ActiveSearchRecoveryState> readActiveSearchRecoveryState(
  String userId, {
  ActiveSearchSnapshotReader? snapshotReader,
  void Function(ActiveSearchRecoveryState state)? observer,
  DateTime Function()? now,
}) async {
  final snapshot = await (snapshotReader ?? readActiveSearchRequestSnapshot)(
    userId,
  );
  if (snapshot == null || !snapshot.exists) {
    final state = ActiveSearchRecoveryState(
      userId: userId,
      requestId: null,
      data: const <String, dynamic>{},
      exists: false,
      belongsToUser: false,
      isLiveStatus: false,
      isExpired: false,
    );
    observer?.call(state);
    return state;
  }

  final data = snapshot.data() ?? const <String, dynamic>{};
  final belongsToUser = activeSearchRequestBelongsToUser(
    doc: snapshot,
    data: data,
    userId: userId,
  );
  final state = ActiveSearchRecoveryState(
    userId: userId,
    requestId: activeSearchNonEmpty(data['requestId']),
    data: data,
    exists: true,
    belongsToUser: belongsToUser,
    isLiveStatus: activeSearchRequestHasLiveStatus(data),
    isExpired: activeSearchRequestIsExpired(
      data,
      now: now?.call(),
    ),
  );
  observer?.call(state);
  return state;
}
