import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'error_reporter.dart';

ErrorReportSink createPlatformErrorReportSink(AppEnvironment environment) {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return const NoopErrorReportSink();
  }
  return CrashlyticsErrorReportSink(
    crashlytics: FirebaseCrashlytics.instance,
    environment: environment,
  );
}

class CrashlyticsErrorReportSink implements ErrorReportSink {
  CrashlyticsErrorReportSink({
    required FirebaseCrashlytics crashlytics,
    required AppEnvironment environment,
  })  : _crashlytics = crashlytics,
        _environment = environment;

  final FirebaseCrashlytics _crashlytics;
  final AppEnvironment _environment;
  bool _environmentKeySet = false;

  @override
  Future<void> record(SafeErrorReport report) async {
    if (!_environmentKeySet) {
      await _crashlytics.setCustomKey('environment', _environment.value);
      _environmentKeySet = true;
    }
    await _crashlytics.recordError(
      report.safeException,
      report.stackTrace,
      reason: report.reason,
      information: report.information,
      printDetails: false,
      fatal: report.fatal,
    );
  }
}
