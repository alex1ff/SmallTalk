import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/daily_call_error_policy.dart';

void main() {
  test('terminal error takes precedence over an invalid room URL', () {
    expect(
      shouldRenderDailyTerminalError(hasTerminalError: true),
      isTrue,
    );
    expect(
      shouldRenderDailyConnectingScreen(
        roomUrlValid: false,
        hasTerminalError: true,
      ),
      isFalse,
    );
  });

  test('invalid room without terminal failure keeps connecting UI', () {
    expect(
      shouldRenderDailyConnectingScreen(
        roomUrlValid: false,
        hasTerminalError: false,
      ),
      isTrue,
    );
  });

  test('terminal error blocks automatic session initialization', () {
    expect(
      shouldAttemptDailySessionInitialization(hasTerminalError: true),
      isFalse,
    );
    expect(
      shouldAttemptDailySessionInitialization(hasTerminalError: false),
      isTrue,
    );
  });

  test('late cleanup preserves terminal failure published while waiting', () {
    const message = 'Закройте и снова откройте приложение.';
    final result = terminalErrorAfterDailyCleanup(
      hasTerminalError: true,
      error: message,
    );

    expect(result.hasTerminalError, isTrue);
    expect(result.error, message);
  });

  test('ordinary cleanup does not create a terminal error', () {
    final result = terminalErrorAfterDailyCleanup(
      hasTerminalError: false,
      error: 'transient error',
    );

    expect(result.hasTerminalError, isFalse);
    expect(result.error, isNull);
  });
}
