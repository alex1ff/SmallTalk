typedef DailyTerminalErrorSnapshot = ({
  bool hasTerminalError,
  String? error,
});

bool shouldRenderDailyTerminalError({
  required bool hasTerminalError,
}) =>
    hasTerminalError;

bool shouldRenderDailyConnectingScreen({
  required bool roomUrlValid,
  required bool hasTerminalError,
}) =>
    !roomUrlValid && !hasTerminalError;

bool shouldAttemptDailySessionInitialization({
  required bool hasTerminalError,
}) =>
    !hasTerminalError;

/// Cleanup can finish after a terminal native-resource failure is published.
/// Preserve that current terminal state instead of restoring a connecting UI.
DailyTerminalErrorSnapshot terminalErrorAfterDailyCleanup({
  required bool hasTerminalError,
  required String? error,
}) {
  if (!hasTerminalError) {
    return (hasTerminalError: false, error: null);
  }
  return (hasTerminalError: true, error: error);
}
