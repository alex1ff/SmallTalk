Duration? resolveServerClockOffset({
  required Object? serverNowMillis,
  required DateTime requestStartedAt,
  required Duration roundTripDuration,
}) {
  final parsedServerNowMillis = _readPositiveInt(serverNowMillis, 0);
  if (parsedServerNowMillis == 0 || roundTripDuration.isNegative) {
    return null;
  }

  final requestMidpoint = requestStartedAt.add(
    Duration(microseconds: roundTripDuration.inMicroseconds ~/ 2),
  );
  final serverNow = DateTime.fromMillisecondsSinceEpoch(
    parsedServerNowMillis,
    isUtc: true,
  );
  return serverNow.difference(requestMidpoint);
}

DateTime resolveServerAlignedNow(
  Duration? serverClockOffset, {
  DateTime? deviceNow,
}) {
  return (deviceNow ?? DateTime.now()).add(
    serverClockOffset ?? Duration.zero,
  );
}

DateTime resolveSessionLimitNow({
  required String? sessionStatus,
  required Duration? serverClockOffset,
  required DateTime? expiresAt,
  required Map<String, dynamic>? sessionPolicy,
  required int elapsedSeconds,
  DateTime? deviceNow,
}) {
  final currentDeviceTime = deviceNow ?? DateTime.now();
  final normalizedStatus = (sessionStatus ?? '').trim().toLowerCase();
  if (normalizedStatus == 'active') {
    return resolveServerAlignedNow(
      serverClockOffset,
      deviceNow: currentDeviceTime,
    );
  }
  if (expiresAt == null) {
    return currentDeviceTime;
  }

  final effectiveLimitSeconds = resolveSessionPolicyEffectiveLimitSeconds(
    sessionPolicy,
  );
  final safeElapsedSeconds = elapsedSeconds < 0 ? 0 : elapsedSeconds;
  final remainingSeconds = effectiveLimitSeconds - safeElapsedSeconds;
  return expiresAt.subtract(
    Duration(seconds: remainingSeconds < 0 ? 0 : remainingSeconds),
  );
}

String formatCallTimerDuration(int totalSeconds) {
  final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
  final minutes = safeSeconds ~/ 60;
  final seconds = safeSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

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

int resolveSessionLimitDisplaySeconds({
  required DateTime? expiresAt,
  required Map<String, dynamic>? sessionPolicy,
  required int elapsedSeconds,
  required bool useProvisionalCountdown,
  DateTime? now,
}) {
  final effectiveLimitSeconds = resolveSessionPolicyEffectiveLimitSeconds(
    sessionPolicy,
  );
  final safeElapsedSeconds = elapsedSeconds < 0 ? 0 : elapsedSeconds;
  final elapsedRemainingSeconds = effectiveLimitSeconds - safeElapsedSeconds;
  final safeElapsedRemaining =
      elapsedRemainingSeconds < 0 ? 0 : elapsedRemainingSeconds;
  if (expiresAt == null) {
    return useProvisionalCountdown ? safeElapsedRemaining : 0;
  }

  final deadlineRemaining = resolveSessionLimitRemainingSeconds(
    expiresAt,
    now: now,
  );
  return deadlineRemaining < safeElapsedRemaining
      ? deadlineRemaining
      : safeElapsedRemaining;
}

bool shouldUseSessionLimitCountdown({
  required String? sessionStatus,
  required DateTime? expiresAt,
  required Map<String, dynamic>? sessionPolicy,
}) {
  final normalizedStatus = (sessionStatus ?? '').trim().toLowerCase();
  if (normalizedStatus != 'connecting' && normalizedStatus != 'active') {
    return false;
  }
  return expiresAt != null && sessionPolicy != null && sessionPolicy.isNotEmpty;
}

bool shouldUseProvisionalSessionLimitCountdown({
  required bool hasJoinCredentials,
  required bool hasAuthoritativeCountdown,
  required String? sessionStatus,
}) {
  if (!hasJoinCredentials || hasAuthoritativeCountdown) {
    return false;
  }
  final normalizedStatus = (sessionStatus ?? '').trim().toLowerCase();
  return normalizedStatus.isEmpty ||
      normalizedStatus == 'searching' ||
      normalizedStatus == 'pending_confirmation' ||
      normalizedStatus == 'connecting';
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

int resolveSessionPolicyEffectiveLimitSeconds(
  Map<String, dynamic>? sessionPolicy, {
  int fallback = 300,
}) {
  return _readPositiveInt(
    sessionPolicy?['effectiveLimitSeconds'],
    fallback,
  );
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
