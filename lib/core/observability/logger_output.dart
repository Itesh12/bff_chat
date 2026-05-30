import 'package:memovault/core/observability/log_level.dart';

/// Represents a single recorded log event in the application.
class LogEvent {
  final LogLevel level;
  final String message;
  final Map<String, Object>? metadata;
  final Object? error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  LogEvent({
    required this.level,
    required this.message,
    this.metadata,
    this.error,
    this.stackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Abstract contract representing a logging destination/pipeline output.
///
/// Under ADR-013, different environments route log events to different outputs
/// (e.g. ConsoleOutput in development, CrashlyticsOutput in release).
abstract class LoggerOutput {
  /// Receives the redacted and validated log event.
  void output(LogEvent event);
}
