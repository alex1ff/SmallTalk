import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/error_reporting/error_reporter.dart';

class _RecordingSink implements ErrorReportSink {
  final List<SafeErrorReport> reports = [];
  int active = 0;
  int maxActive = 0;
  bool failNext = false;

  @override
  Future<void> record(SafeErrorReport report) async {
    active += 1;
    maxActive = maxActive < active ? active : maxActive;
    try {
      await Future<void>.delayed(Duration.zero);
      if (failNext) {
        failNext = false;
        throw StateError('sink secret failure');
      }
      reports.add(report);
    } finally {
      active -= 1;
    }
  }
}

class _BlockingSink implements ErrorReportSink {
  final started = Completer<void>();
  final release = Completer<void>();
  final reports = <SafeErrorReport>[];
  var calls = 0;

  @override
  Future<void> record(SafeErrorReport report) async {
    calls += 1;
    if (calls == 1) started.complete();
    if (calls == 1) await release.future;
    reports.add(report);
  }
}

void main() {
  test('report payload is typed, stable and excludes original error text', () {
    final report = SafeErrorReport.build(
      environment: AppEnvironment.production,
      feature: ErrorFeature.translation,
      code: AppErrorCode.translationUnexpected,
      error: StateError('token=secret caption=user words'),
      stackTrace: StackTrace.fromString('trusted-vm-stack'),
      sessionId: '  session-1  ',
      fatal: false,
    );

    expect(report.issueTitle,
        'AppReport[translation/translation_unexpected/unexpected]');
    expect(report.reason, report.issueTitle);
    expect(report.sessionHash,
        '84097828fc31a8c8d29210df48901a85de7fd013f686b17be77d1be29cb7a98b');
    expect(report.information, <String>[
      'environment=production',
      'feature=translation',
      'error_code=translation_unexpected',
      'error_type=unexpected',
      'session_hash=84097828fc31a8c8d29210df48901a85de7fd013f686b17be77d1be29cb7a98b',
    ]);
    expect(report.safeException.toString(), report.issueTitle);
    expect(report.safeException.toString(), isNot(contains('secret')));
    expect(report.information.join(' '), isNot(contains('session-1')));
    expect(report.stackTrace.toString(), 'trusted-vm-stack');
  });

  test('error-code mapping overrides a mismatched caller feature safely', () {
    final report = SafeErrorReport.build(
      environment: AppEnvironment.test,
      feature: ErrorFeature.purchase,
      code: AppErrorCode.authRefreshFailed,
      error: Exception('raw email=user@example.com'),
      stackTrace: StackTrace.empty,
      fatal: false,
    );

    expect(report.feature, ErrorFeature.auth);
    expect(report.errorType, ErrorType.infrastructure);
    expect(report.issueTitle,
        'AppReport[auth/auth_refresh_failed/infrastructure]');
    expect(report.information.join(' '), isNot(contains('example.com')));
  });

  test('bootstrap queue is bounded and flushes in original order', () async {
    final reporter = AppErrorReporter(
      environment: AppEnvironment.test,
      maxPendingReports: 3,
    );
    for (var index = 0; index < 5; index += 1) {
      reporter.captureNonFatal(
        feature: ErrorFeature.translation,
        code: index.isEven
            ? AppErrorCode.translationUnexpected
            : AppErrorCode.translationInvalidResponse,
        error: Exception('secret-$index'),
        stackTrace: StackTrace.fromString('stack-$index'),
      );
    }
    final sink = _RecordingSink();

    reporter.attachSink(sink);
    await reporter.drainForTesting();

    expect(sink.reports.map((report) => report.stackTrace.toString()),
        <String>['stack-2', 'stack-3', 'stack-4']);
    expect(sink.maxActive, 1);
  });

  test('post-attach queue stays bounded while sink is stalled', () async {
    final sink = _BlockingSink();
    final reporter = AppErrorReporter(
      environment: AppEnvironment.test,
      maxPendingReports: 3,
      reportTimeout: const Duration(seconds: 1),
    )..attachSink(sink);

    for (var index = 0; index < 5; index += 1) {
      reporter.captureNonFatal(
        feature: ErrorFeature.translation,
        code: AppErrorCode.translationUnexpected,
        error: Exception('secret-$index'),
        stackTrace: StackTrace.fromString('stack-$index'),
      );
    }
    await sink.started.future;
    sink.release.complete();
    await reporter.drainForTesting();

    expect(sink.reports.map((report) => report.stackTrace.toString()),
        <String>['stack-0', 'stack-2', 'stack-3', 'stack-4']);
  });

  test('sink failure is isolated and later reports still flush', () async {
    final sink = _RecordingSink()..failNext = true;
    final reporter = AppErrorReporter(
      environment: AppEnvironment.test,
      reportTimeout: const Duration(milliseconds: 100),
    )..attachSink(sink);

    reporter.captureNonFatal(
      feature: ErrorFeature.purchase,
      code: AppErrorCode.purchaseFailed,
      error: Exception('first secret'),
      stackTrace: StackTrace.fromString('first'),
    );
    reporter.captureFatal(
      feature: ErrorFeature.bootstrap,
      code: AppErrorCode.platformAsyncFatal,
      error: Exception('second secret'),
      stackTrace: StackTrace.fromString('second'),
    );

    await expectLater(reporter.drainForTesting(), completes);
    expect(sink.reports, hasLength(1));
    expect(sink.reports.single.fatal, true);
    expect(sink.reports.single.stackTrace.toString(), 'second');
  });

  test('noop sink completes without retaining reports', () async {
    const sink = NoopErrorReportSink();
    final report = SafeErrorReport.build(
      environment: AppEnvironment.test,
      feature: ErrorFeature.bootstrap,
      code: AppErrorCode.flutterFrameworkFatal,
      error: Exception('secret'),
      stackTrace: StackTrace.empty,
      fatal: true,
    );

    await expectLater(sink.record(report), completes);
  });
}
