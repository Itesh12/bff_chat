import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:memovault/core/observability/log_level.dart';
import 'package:memovault/core/observability/logger_output.dart';

/// Concrete [LoggerOutput] that forwards warnings, errors, and fatal events to
/// Firebase Crashlytics for staging and production diagnostics.
///
/// Only forwards [LogLevel.warning] and above — trace, debug, and info stay
/// local (console only), in line with ADR-013 retention policy.
class CrashlyticsOutput implements LoggerOutput {
  final FirebaseCrashlytics _crashlytics;

  CrashlyticsOutput({FirebaseCrashlytics? crashlytics})
      : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  @override
  void output(LogEvent event) {
    // Only forward warning and above per ADR-013 retention policy.
    if (event.level.index < LogLevel.warning.index) return;

    final message = '[${event.level.label}] ${event.message}';

    if (event.level == LogLevel.fatal && event.error != null) {
      // Fatal: record as a proper Crashlytics crash.
      _crashlytics.recordError(
        event.error,
        event.stackTrace,
        reason: message,
        fatal: true,
      );
    } else if (event.error != null) {
      // Error: record as a non-fatal Crashlytics event.
      _crashlytics.recordError(
        event.error,
        event.stackTrace,
        reason: message,
        fatal: false,
      );
    } else {
      // Warning / Error with no exception: record as a log breadcrumb only.
      _crashlytics.log(message);
    }
  }
}
