import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/error_reporting/app_error_boundary.dart';
import 'package:small_talk/services/error_reporting/error_reporter.dart';

class _BoundarySink implements ErrorReportSink {
  final List<SafeErrorReport> reports = [];

  @override
  Future<void> record(SafeErrorReport report) async => reports.add(report);
}

class _ThrowingReporter implements ErrorReporter {
  @override
  void captureFatal({
    required ErrorFeature feature,
    required AppErrorCode code,
    required Object error,
    required StackTrace stackTrace,
    String? sessionId,
  }) {
    throw StateError('reporter failed');
  }

  @override
  void captureNonFatal({
    required ErrorFeature feature,
    required AppErrorCode code,
    required Object error,
    required StackTrace stackTrace,
    String? sessionId,
  }) {
    throw StateError('reporter failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterExceptionHandler? originalFlutterHandler;
  late ErrorCallback? originalPlatformHandler;

  setUp(() {
    originalFlutterHandler = FlutterError.onError;
    originalPlatformHandler = PlatformDispatcher.instance.onError;
    AppErrorBoundary.restoreForTesting();
  });

  tearDown(() {
    AppErrorBoundary.restoreForTesting();
    FlutterError.onError = originalFlutterHandler;
    PlatformDispatcher.instance.onError = originalPlatformHandler;
  });

  test('installer composes existing handlers and reports fatal errors',
      () async {
    var flutterFallbackCalls = 0;
    var platformFallbackCalls = 0;
    FlutterError.onError = (_) => flutterFallbackCalls += 1;
    PlatformDispatcher.instance.onError = (_, __) {
      platformFallbackCalls += 1;
      return false;
    };
    final sink = _BoundarySink();
    final reporter = AppErrorReporter(environment: AppEnvironment.test)
      ..attachSink(sink);

    AppErrorBoundary.install(reporter);
    FlutterError.onError!(FlutterErrorDetails(
      exception: StateError('framework secret'),
      stack: StackTrace.fromString('framework-stack'),
    ));
    final handled = PlatformDispatcher.instance.onError!(
      StateError('platform secret'),
      StackTrace.fromString('platform-stack'),
    );
    await reporter.drainForTesting();

    expect(flutterFallbackCalls, 1);
    expect(platformFallbackCalls, 1);
    expect(handled, true);
    expect(sink.reports.map((report) => report.code), <AppErrorCode>[
      AppErrorCode.flutterFrameworkFatal,
      AppErrorCode.platformAsyncFatal,
    ]);
    expect(sink.reports.every((report) => report.fatal), true);
    expect(sink.reports.join(' '), isNot(contains('secret')));
  });

  test('install is idempotent and restore reinstates original handlers', () {
    final fallback = FlutterError.onError;
    final platformFallback = PlatformDispatcher.instance.onError;
    final reporter = AppErrorReporter(environment: AppEnvironment.test);

    AppErrorBoundary.install(reporter);
    final installedFlutter = FlutterError.onError;
    final installedPlatform = PlatformDispatcher.instance.onError;
    AppErrorBoundary.install(reporter);

    expect(FlutterError.onError, same(installedFlutter));
    expect(PlatformDispatcher.instance.onError, same(installedPlatform));
    AppErrorBoundary.restoreForTesting();
    expect(FlutterError.onError, same(fallback));
    expect(PlatformDispatcher.instance.onError, same(platformFallback));
  });

  test('a throwing prior Flutter handler cannot block reporting', () async {
    FlutterError.onError = (_) => throw StateError('old handler failed');
    final sink = _BoundarySink();
    final reporter = AppErrorReporter(environment: AppEnvironment.test)
      ..attachSink(sink);

    AppErrorBoundary.install(reporter);
    FlutterError.onError!(FlutterErrorDetails(exception: StateError('boom')));
    await reporter.drainForTesting();

    expect(sink.reports.map((report) => report.code),
        contains(AppErrorCode.flutterFrameworkFatal));
  });

  test('a throwing reporter cannot escape either global handler', () {
    AppErrorBoundary.install(_ThrowingReporter());

    expect(
      () => FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('framework boom')),
      ),
      returnsNormally,
    );
    expect(
      () => PlatformDispatcher.instance.onError!(
        StateError('platform boom'),
        StackTrace.current,
      ),
      returnsNormally,
    );
  });
}
