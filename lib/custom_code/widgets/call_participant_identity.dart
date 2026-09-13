/// Display fallback policy for the remote participant, not an auth identity.
String resolveRemoteParticipantName({
  String? username,
  required String fallback,
}) {
  final trimmedUsername = username?.trim();
  if (trimmedUsername?.isNotEmpty == true) {
    return trimmedUsername!;
  }
  return fallback;
}

/// Speaker key for legacy peer caption logs only.
///
/// Active captions and chat keep their raw Daily participant ID. Do not use
/// this fallback chain as an authenticated writer ID.
String resolveRemoteCaptionLogSpeakerId({
  String? userId,
  required String participantSessionId,
  required int utteranceId,
}) {
  final trimmedUserId = userId?.trim();
  if (trimmedUserId?.isNotEmpty == true) {
    return trimmedUserId!;
  }

  final trimmedSessionId = participantSessionId.trim();
  if (trimmedSessionId.isNotEmpty) {
    return trimmedSessionId;
  }
  return 'remote_$utteranceId';
}

String resolveLocalParticipantName({
  String? dailyUsername,
  String? configuredUsername,
  bool? isStudent,
}) {
  final trimmedDailyUsername = dailyUsername?.trim();
  if (trimmedDailyUsername?.isNotEmpty == true) {
    return trimmedDailyUsername!;
  }

  final trimmedConfiguredUsername = configuredUsername?.trim();
  if (trimmedConfiguredUsername?.isNotEmpty == true) {
    return trimmedConfiguredUsername!;
  }
  return isStudent == true ? 'Студент' : 'Преподаватель';
}

/// Preserve the raw Daily ID, including whitespace, for chat and live captions.
/// Only null/empty values use the local fallback; caption-log writer UID is
/// resolved separately by the widget.
String resolveLocalParticipantId(String? participantId) {
  if (participantId?.isNotEmpty == true) {
    return participantId!;
  }
  return 'local';
}
