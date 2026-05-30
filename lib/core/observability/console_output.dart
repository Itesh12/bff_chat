import 'package:flutter/foundation.dart';
import 'package:memovault/core/observability/log_level.dart';
import 'package:memovault/core/observability/logger_output.dart';

/// Concrete [LoggerOutput] that pretty-prints structured logs to the developer console.
///
/// Employs ANSI colorized flags to distinguish levels and formatting structures.
class ConsoleOutput implements LoggerOutput {
  @override
  void output(LogEvent event) {
    final timeStr = event.timestamp.toIso8601String().substring(11, 23);
    final color = _colorForLevel(event.level);
    const reset = '\x1B[0m';

    var line = '$color[${event.level.emoji} ${event.level.label}] [$timeStr] ${event.message}$reset';

    if (event.metadata != null && event.metadata!.isNotEmpty) {
      line += '\n$color  Metadata: ${event.metadata}$reset';
    }

    if (event.error != null) {
      line += '\n$color  Error: ${event.error}$reset';
    }

    if (event.stackTrace != null) {
      line += '\n$color  StackTrace:\n${event.stackTrace}$reset';
    }

    debugPrint(line);
  }

  String _colorForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.trace:
        return '\x1B[36m'; // Cyan
      case LogLevel.debug:
        return '\x1B[90m'; // Grey
      case LogLevel.info:
        return '\x1B[32m'; // Green
      case LogLevel.warning:
        return '\x1B[33m'; // Yellow
      case LogLevel.error:
        return '\x1B[31m'; // Red
      case LogLevel.fatal:
        return '\x1B[35;1m'; // Magenta / Bold
    }
  }
}
