int resolveSessionLimitRemainingSeconds(
  DateTime? expiresAt, {
  DateTime? now,
}) {
  if (expiresAt == null) {
    return 0;
  }

  final remaining = expiresAt.difference(now ?? DateTime.now()).inSeconds;
  return remaining < 0 ? 0 : remaining;
}

bool shouldUseSessionLimitCountdown({
  required String? sessionStatus,
  required DateTime? expiresAt,
  required Map<String, dynamic>? sessionPolicy,
}) {
  final normalizedStatus = (sessionStatus ?? '').trim().toLowerCase();
  if (normalizedStatus != 'active' && normalizedStatus != 'connecting') {
    return false;
  }
  return expiresAt != null && sessionPolicy != null && sessionPolicy.isNotEmpty;
}

int _readPositiveInt(
  dynamic value,
  int fallback,
) {
  final number = value is num ? value.toInt() : int.tryParse('$value');
  if (number == null || number <= 0) {
    return fallback;
  }
  return number;
}

Map<String, bool> readSessionExtensionRequests(
  Map<String, dynamic>? sessionPolicy,
) {
  final rawRequests = sessionPolicy?['extensionRequests'];
  if (rawRequests is! Map) {
    return const <String, bool>{};
  }

  final requests = <String, bool>{};
  for (final entry in rawRequests.entries) {
    final key = entry.key?.toString().trim() ?? '';
    if (key.isEmpty || entry.value != true) {
      continue;
    }
    requests[key] = true;
  }
  return requests;
}

bool isSessionExtensionApproved(
  Map<String, dynamic>? sessionPolicy,
) {
  return sessionPolicy?['extensionApproved'] == true;
}

int resolveSessionExtensionSeconds(
  Map<String, dynamic>? sessionPolicy, {
  int fallback = 300,
}) {
  return _readPositiveInt(sessionPolicy?['extensionSeconds'], fallback);
}

bool hasUserRequestedSessionExtension(
  Map<String, dynamic>? sessionPolicy,
  String? userId,
) {
  final normalizedUserId = (userId ?? '').trim();
  if (normalizedUserId.isEmpty) {
    return false;
  }

  return readSessionExtensionRequests(sessionPolicy)[normalizedUserId] == true;
}

bool hasOtherParticipantRequestedSessionExtension(
  Map<String, dynamic>? sessionPolicy,
  String? userId,
) {
  final normalizedUserId = (userId ?? '').trim();
  return readSessionExtensionRequests(sessionPolicy).entries.any(
        (entry) => entry.key != normalizedUserId && entry.value,
      );
}

bool shouldShowSessionExtensionSurface({
  required Map<String, dynamic>? sessionPolicy,
  required DateTime? expiresAt,
  required String? currentUserId,
  DateTime? now,
}) {
  final normalizedUserId = (currentUserId ?? '').trim();
  if (normalizedUserId.isEmpty ||
      expiresAt == null ||
      sessionPolicy == null ||
      sessionPolicy.isEmpty) {
    return false;
  }
  if (isSessionExtensionApproved(sessionPolicy)) {
    return false;
  }

  final remainingSeconds = resolveSessionLimitRemainingSeconds(
    expiresAt,
    now: now,
  );
  if (remainingSeconds <= 0) {
    return false;
  }

  final warningLeadSeconds = _readPositiveInt(
    sessionPolicy['warningLeadSeconds'],
    60,
  );
  return remainingSeconds <= warningLeadSeconds;
}

bool canCurrentUserRequestSessionExtension({
  required Map<String, dynamic>? sessionPolicy,
  required DateTime? expiresAt,
  required String? currentUserId,
  DateTime? now,
}) {
  return shouldShowSessionExtensionSurface(
        sessionPolicy: sessionPolicy,
        expiresAt: expiresAt,
        currentUserId: currentUserId,
        now: now,
      ) &&
      !hasUserRequestedSessionExtension(sessionPolicy, currentUserId);
}

bool shouldAutoEndSession({
  required DateTime? expiresAt,
  required DateTime? autoEndedForExpiresAt,
  DateTime? now,
  int graceSeconds = 0,
}) {
  if (expiresAt == null) {
    return false;
  }
  if (autoEndedForExpiresAt?.isAtSameMomentAs(expiresAt) == true) {
    return false;
  }

  final currentTime = now ?? DateTime.now();
  final effectiveExpiry = graceSeconds > 0
      ? expiresAt.add(Duration(seconds: graceSeconds))
      : expiresAt;
  return !currentTime.isBefore(effectiveExpiry);
}

bool shouldRetainAutoEndMarkerForResponseStatus(String? status) {
  final normalizedStatus = (status ?? '').trim().toLowerCase();
  return normalizedStatus == 'ignored_expired_end';
}

bool shouldShowSessionLimitWarning({
  required DateTime? expiresAt,
  required DateTime? warnedForExpiresAt,
  DateTime? now,
  int warningLeadSeconds = 60,
}) {
  if (expiresAt == null) {
    return false;
  }
  if (warningLeadSeconds <= 0) {
    return false;
  }
  if (warnedForExpiresAt?.isAtSameMomentAs(expiresAt) == true) {
    return false;
  }

  final remainingSeconds = resolveSessionLimitRemainingSeconds(
    expiresAt,
    now: now,
  );
  return remainingSeconds > 0 && remainingSeconds <= warningLeadSeconds;
}
