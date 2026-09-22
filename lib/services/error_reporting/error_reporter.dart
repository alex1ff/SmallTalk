import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

enum AppEnvironment {
  development('development'),
  test('test'),
  production('production');

  const AppEnvironment(this.value);
  final String value;

  static AppEnvironment get current =>
      kReleaseMode ? AppEnvironment.production : AppEnvironment.development;
}

enum ErrorFeature {
  bootstrap('bootstrap'),
  voip('voip'),
  auth('auth'),
  purchase('purchase'),
  translation('translation'),
  aiFeedback('ai_feedback');

  const ErrorFeature(this.value);
  final String value;
}

enum ErrorType {
  fatal('fatal'),
  infrastructure('infrastructure'),
  invalidResponse('invalid_response'),
  unexpected('unexpected');

  const ErrorType(this.value);
  final String value;
}

enum AppErrorCode {
  flutterFrameworkFatal(
    'flutter_framework_fatal',
    ErrorFeature.bootstrap,
    ErrorType.fatal,
  ),
  platformAsyncFatal(
    'platform_async_fatal',
    ErrorFeature.bootstrap,
    ErrorType.fatal,
  ),
  firebaseInitializeFailed(
    'firebase_initialize_failed',
    ErrorFeature.bootstrap,
    ErrorType.infrastructure,
  ),
  voipInitializeFailed(
    'voip_initialize_failed',
    ErrorFeature.voip,
    ErrorType.infrastructure,
  ),
  authRefreshFailed(
    'auth_refresh_failed',
    ErrorFeature.auth,
    ErrorType.infrastructure,
  ),
  purchaseFailed(
    'purchase_failed',
    ErrorFeature.purchase,
    ErrorType.infrastructure,
  ),
  translationInvalidResponse(
    'translation_invalid_response',
    ErrorFeature.translation,
    ErrorType.invalidResponse,
  ),
  translationUnexpected(
    'translation_unexpected',
    ErrorFeature.translation,
    ErrorType.unexpected,
  ),
  aiFeedbackInvalidResponse(
    'ai_feedback_invalid_response',
    ErrorFeature.aiFeedback,
    ErrorType.invalidResponse,
  ),
  aiFeedbackUnexpected(
    'ai_feedback_unexpected',
    ErrorFeature.aiFeedback,
    ErrorType.unexpected,
  );

  const AppErrorCode(this.value, this.feature, this.errorType);
  final String value;
  final ErrorFeature feature;
  final ErrorType errorType;
}

class SafeReportedException implements Exception {
  const SafeReportedException(this.issueTitle);
  final String issueTitle;

  @override
  String toString() => issueTitle;
}

@immutable
class SafeErrorReport {
  const SafeErrorReport._({
    required this.environment,
    required this.feature,
    required this.code,
    required this.errorType,
    required this.issueTitle,
    required this.reason,
    required this.information,
    required this.sessionHash,
    required this.safeException,
    required this.stackTrace,
    required this.fatal,
  });

  factory SafeErrorReport.build({
    required AppEnvironment environment,
    required ErrorFeature feature,
    required AppErrorCode code,
    required Object error,
    required StackTrace stackTrace,
    required bool fatal,
    String? sessionId,
  }) {
    // The code owns feature/type. Never derive metadata or text from [error].
    final safeFeature = code.feature;
    final errorType = code.errorType;
    final issueTitle =
        'AppReport[${safeFeature.value}/${code.value}/${errorType.value}]';
    final trimmedSessionId = sessionId?.trim() ?? '';
    final sessionHash = trimmedSessionId.isEmpty
        ? ''
        : sha256.convert(utf8.encode(trimmedSessionId)).toString();
    final information = <String>[
      'environment=${environment.value}',
      'feature=${safeFeature.value}',
      'error_code=${code.value}',
      'error_type=${errorType.value}',
      if (sessionHash.isNotEmpty) 'session_hash=$sessionHash',
    ];

    return SafeErrorReport._(
      environment: environment,
      feature: safeFeature,
      code: code,
      errorType: errorType,
      issueTitle: issueTitle,
      reason: issueTitle,
      information: List<String>.unmodifiable(information),
      sessionHash: sessionHash,
      safeException: SafeReportedException(issueTitle),
      stackTrace: stackTrace,
      fatal: fatal,
    );
  }

  final AppEnvironment environment;
  final ErrorFeature feature;
  final AppErrorCode code;
  final ErrorType errorType;
  final String issueTitle;
  final String reason;
  final List<String> information;
  final String sessionHash;
  final SafeReportedException safeException;
  final StackTrace stackTrace;
  final bool fatal;
}

abstract interface class ErrorReportSink {
  Future<void> record(SafeErrorReport report);
}

class NoopErrorReportSink implements ErrorReportSink {
  const NoopErrorReportSink();

  @override
  Future<void> record(SafeErrorReport report) async {}
}

abstract interface class ErrorReporter {
  void captureFatal({
    required ErrorFeature feature,
    required AppErrorCode code,
    required Object error,
    required StackTrace stackTrace,
    String? sessionId,
  });

  void captureNonFatal({
    required ErrorFeature feature,
    required AppErrorCode code,
    required Object error,
    required StackTrace stackTrace,
    String? sessionId,
  });
}

class AppErrorReporter implements ErrorReporter {
  AppErrorReporter({
    required this.environment,
    this.maxPendingReports = 20,
    this.reportTimeout = const Duration(seconds: 2),
  }) : assert(maxPendingReports > 0);

  final AppEnvironment environment;
  final int maxPendingReports;
  final Duration reportTimeout;
  final ListQueue<SafeErrorReport> _pending = ListQueue<SafeErrorReport>();
  ErrorReportSink? _sink;
  Future<void>? _drainFuture;

  @override
  void captureFatal({
    required ErrorFeature feature,
    required AppErrorCode code,
    required Object error,
    required StackTrace stackTrace,
    String? sessionId,
  }) {
    _capture(
      feature: feature,
      code: code,
      error: error,
      stackTrace: stackTrace,
      sessionId: sessionId,
      fatal: true,
    );
  }

  @override
  void captureNonFatal({
    required ErrorFeature feature,
    required AppErrorCode code,
    required Object error,
    required StackTrace stackTrace,
    String? sessionId,
  }) {
    _capture(
      feature: feature,
      code: code,
      error: error,
      stackTrace: stackTrace,
      sessionId: sessionId,
      fatal: false,
    );
  }

  void _capture({
    required ErrorFeature feature,
    required AppErrorCode code,
    required Object error,
    required StackTrace stackTrace,
    required bool fatal,
    String? sessionId,
  }) {
    final report = SafeErrorReport.build(
      environment: environment,
      feature: feature,
      code: code,
      error: error,
      stackTrace: stackTrace,
      sessionId: sessionId,
      fatal: fatal,
    );
    if (_pending.length == maxPendingReports) _pending.removeFirst();
    _pending.addLast(report);
    _drain();
  }

  void attachSink(ErrorReportSink sink) {
    _sink = sink;
    _drain();
  }

  void _drain() {
    if (_sink == null || _pending.isEmpty || _drainFuture != null) return;
    final sink = _sink!;
    final future = _flush(sink);
    _drainFuture = future;
    future.whenComplete(() {
      if (!identical(_drainFuture, future)) return;
      _drainFuture = null;
      _drain();
    });
  }

  Future<void> _flush(ErrorReportSink sink) async {
    while (_pending.isNotEmpty && identical(_sink, sink)) {
      final report = _pending.removeFirst();
      try {
        await sink.record(report).timeout(reportTimeout);
      } catch (_) {
        // Reporting must never become an app failure or block the next report.
      }
    }
  }

  @visibleForTesting
  Future<void> drainForTesting() => _drainFuture ?? Future<void>.value();
}

class ErrorReporting {
  ErrorReporting._();

  static AppErrorReporter _reporter = AppErrorReporter(
    environment: AppEnvironment.current,
  );

  static ErrorReporter get reporter => _reporter;

  static void attachSink(ErrorReportSink sink) => _reporter.attachSink(sink);

  @visibleForTesting
  static void replaceReporterForTesting(AppErrorReporter reporter) {
    _reporter = reporter;
  }
}
