import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/daily_runtime_error_policy.dart';

void main() {
  test('token classification returns only fixed redacted output', () {
    const secret = 'room-token=secret-value https://private.example/room';

    final decision = classifyDailyRuntimeError(StateError(secret));

    expect(decision.isTokenError, isTrue);
    expect(decision.diagnosticCode, 'daily_token_error');
    expect(decision.userMessage, isNot(contains('secret-value')));
    expect(decision.userMessage, isNot(contains('private.example')));
    expect(decision.diagnosticCode, isNot(contains('secret-value')));
  });

  test('known event stream noise is transient and redacted', () {
    final decision = classifyDailyRuntimeError(
      StateError('track no longer exists for user-secret'),
      fromEventStream: true,
    );

    expect(decision.isTransientEvent, isTrue);
    expect(decision.isTokenError, isFalse);
    expect(decision.diagnosticCode, 'daily_event_transient');
    expect(decision.userMessage, isNot(contains('user-secret')));
  });

  test('unknown native failure has a fixed reconnect-safe message', () {
    final decision = classifyDailyRuntimeError(
      StateError('caption text and session/private-session'),
      fromEventStream: true,
    );

    expect(decision.isTransientEvent, isFalse);
    expect(decision.isTokenError, isFalse);
    expect(decision.diagnosticCode, 'daily_connection_error');
    expect(decision.userMessage, isNot(contains('caption text')));
    expect(decision.userMessage, isNot(contains('private-session')));
  });

  test('specific caption credential issue wins over generic fallback', () {
    expect(shouldReportGenericCaptionCredentialIssue(null), isTrue);
    expect(shouldReportGenericCaptionCredentialIssue('  '), isTrue);
    expect(
      shouldReportGenericCaptionCredentialIssue('caption_backend_denied'),
      isFalse,
    );
  });
}
