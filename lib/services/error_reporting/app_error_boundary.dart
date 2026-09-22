import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'error_reporter.dart';

class AppErrorBoundary {
  AppErrorBoundary._();

  static bool _installed = false;
  static FlutterExceptionHandler? _previousFlutterHandler;
  static ErrorCallback? _previousPlatformHandler;

  static void install(ErrorReporter reporter) {
    if (_installed) return;
    _installed = true;
    _previousFlutterHandler = FlutterError.onError;
    _previousPlatformHandler = PlatformDispatcher.instance.onError;

    FlutterError.onError = (details) {
      try {
        final previous = _previousFlutterHandler;
        if (previous != null) {
          previous(details);
        } else {
          FlutterError.presentError(details);
        }
      } catch (_) {
        // A prior handler must not prevent the reporting boundary from running.
      }
      try {
        reporter.captureFatal(
          feature: ErrorFeature.bootstrap,
          code: AppErrorCode.flutterFrameworkFatal,
          error: details.exception,
          stackTrace: details.stack ?? StackTrace.current,
        );
      } catch (_) {
        // Reporting must never turn a framework error into another failure.
      }
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      try {
        _previousPlatformHandler?.call(error, stackTrace);
      } catch (_) {
        // The reporter still owns the uncaught error if a prior handler fails.
      }
      try {
        reporter.captureFatal(
          feature: ErrorFeature.bootstrap,
          code: AppErrorCode.platformAsyncFatal,
          error: error,
          stackTrace: stackTrace,
        );
      } catch (_) {
        // Reporting must never escape the root async error boundary.
      }
      return true;
    };
  }

  @visibleForTesting
  static void restoreForTesting() {
    if (!_installed) return;
    FlutterError.onError = _previousFlutterHandler;
    PlatformDispatcher.instance.onError = _previousPlatformHandler;
    _previousFlutterHandler = null;
    _previousPlatformHandler = null;
    _installed = false;
  }
}
