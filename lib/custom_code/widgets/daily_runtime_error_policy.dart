/// Safe classification for native Daily failures.
///
/// Raw native errors are used only for matching. They must never be returned,
/// logged, persisted, or shown because SDK failures can contain room tokens.
final class DailyRuntimeErrorDecision {
  const DailyRuntimeErrorDecision({
    required this.diagnosticCode,
    required this.userMessage,
    required this.isTokenError,
    required this.isTransientEvent,
  });

  final String diagnosticCode;
  final String userMessage;
  final bool isTokenError;
  final bool isTransientEvent;
}

/// Keeps a typed caption credential failure from being replaced by fallback
/// text emitted after the resolver returns no credential.
bool shouldReportGenericCaptionCredentialIssue(String? currentIssueCode) =>
    currentIssueCode == null || currentIssueCode.trim().isEmpty;

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
      isTokenError: false,
      isTransientEvent: true,
    );
  }
  if (isTokenError) {
    return const DailyRuntimeErrorDecision(
      diagnosticCode: 'daily_token_error',
      userMessage: 'Ошибка токена, перезапустите звонок',
      isTokenError: true,
      isTransientEvent: false,
    );
  }
  return const DailyRuntimeErrorDecision(
    diagnosticCode: 'daily_connection_error',
    userMessage: 'Не удалось подключиться к звонку. Повторите попытку.',
    isTokenError: false,
    isTransientEvent: false,
  );
}
