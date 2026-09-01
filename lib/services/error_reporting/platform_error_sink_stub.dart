import 'error_reporter.dart';

ErrorReportSink createPlatformErrorReportSink(AppEnvironment environment) =>
    const NoopErrorReportSink();
