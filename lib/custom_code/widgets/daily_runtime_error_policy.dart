/// Safe classification for native Daily failures.
///
/// Raw native errors are used only for matching. They must never be returned,
/// logged, persisted, or shown because SDK failures can contain room tokens.
final class DailyRuntimeErrorDecision {
  const DailyRuntimeErrorDecision({
    required this.diagnosticCode,
    required this.userMessage,
    required this.userMessageEn,
    required this.isTokenError,
    required this.isTransientEvent,
  });

  final String diagnosticCode;
  final String userMessage;
  final String userMessageEn;
  final bool isTokenError;
  final bool isTransientEvent;
}

/// Keeps a typed caption credential failure from being replaced by fallback
/// text emitted after the resolver returns no credential.
bool shouldReportGenericCaptionCredentialIssue(String? currentIssueCode) =>
    currentIssueCode == null || currentIssueCode.trim().isEmpty;

String localizedCaptionRuntimeMessage({
  required bool useEnglish,
  required String code,
  required String fallback,
}) {
  if (!useEnglish) return fallback;
  return switch (code) {
    'microphone_permission_denied' =>
      'Captions are temporarily unavailable: microphone access is missing.',
    'deepgram_start_failed' =>
      'Captions are temporarily unavailable: speech recognition could not start.',
    'deepgram_websocket_error' =>
      'Captions are temporarily unavailable: the speech recognition connection was interrupted.',
    'audio_stream_error' =>
      'Captions are temporarily unavailable: audio could not be sent for recognition.',
    'deepgram_recorder_quarantined' =>
      'Captions are temporarily unavailable. Close and reopen the app.',
    'deepgram_token_grant_forbidden' =>
      'Captions are temporarily unavailable: speech recognition requires configuration.',
    'caption_token_unavailable' =>
      'Captions are temporarily unavailable: a recognition token could not be obtained.',
    _ => 'Captions are temporarily unavailable.',
  };
}

DailyRuntimeErrorDecision classifyDailyRuntimeError(
  Object error, {
  bool fromEventStream = false,
}) {
  final normalized = error.toString().toLowerCase();
  final isTokenError =
      normalized.contains('sigauthz') || normalized.contains('token');
  final isTransientEvent = fromEventStream &&
      (normalized.contains('subscription') ||
          normalized.contains('consumer') ||
          normalized.contains('track') ||
          normalized.contains('no longer exists') ||
          normalized.contains('meeting_event') ||
          normalized.contains('send_meeting_event'));

  if (isTransientEvent) {
    return const DailyRuntimeErrorDecision(
      diagnosticCode: 'daily_event_transient',
      userMessage: 'Не удалось обновить медиа звонка.',
      userMessageEn: 'Call media could not be updated.',
      isTokenError: false,
      isTransientEvent: true,
    );
  }
  if (isTokenError) {
    return const DailyRuntimeErrorDecision(
      diagnosticCode: 'daily_token_error',
      userMessage: 'Ошибка токена, перезапустите звонок',
      userMessageEn: 'The call token expired. Restart the call.',
      isTokenError: true,
      isTransientEvent: false,
    );
  }
  return const DailyRuntimeErrorDecision(
    diagnosticCode: 'daily_connection_error',
    userMessage: 'Не удалось подключиться к звонку. Повторите попытку.',
    userMessageEn: 'Could not connect to the call. Please try again.',
    isTokenError: false,
    isTransientEvent: false,
  );
}
