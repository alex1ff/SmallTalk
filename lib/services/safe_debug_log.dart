import 'package:flutter/foundation.dart';

/// Keeps diagnostic details out of production logs.
void safeDebugLog(String? message, {int? wrapWidth}) {
  if (!kDebugMode) return;
  debugPrint(message, wrapWidth: wrapWidth);
}

void safeDebugStack({StackTrace? stackTrace}) {
  if (!kDebugMode) return;
  debugPrintStack(stackTrace: stackTrace);
}
