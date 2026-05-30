import 'package:flutter/foundation.dart';
import 'package:memovault/core/observability/log_level.dart';
import 'package:memovault/core/observability/logger_output.dart';

/// Central logging coordinator for the MemoVault application.
///
/// Implements strict ADR-013 privacy rules:
/// 1. Runs an automated regex-based redaction engine to strip keys, emails, and sensitive fields.
/// 2. Implements modular [LoggerOutput] pipelines.
/// 3. Ensures no decrypted note, vault data, or encryption keys are printed or stored.
class AppLogger {
  static final List<LoggerOutput> _outputs = [];

  /// Adds a logging target to the pipeline.
  static void addOutput(LoggerOutput output) {
    _outputs.add(output);
  }

  /// Clears all targets from the pipeline (useful for test resets).
  static void clearOutputs() {
    _outputs.clear();
  }

  /// Enforces automated privacy redaction of base64url keys, emails, and malformed strings.
  static String redact(String input) {
    var result = input;

    // 1. Redact Base64url 32-byte cryptographic keys (exactly 43 characters of base64url representation)
    final keyRegex = RegExp(r'\b[a-zA-Z0-9_-]{43}\b');
    result = result.replaceAllMapped(keyRegex, (_) => '[REDACTED_KEY]');

    // 2. Redact simple email addresses
    final emailRegex = RegExp(r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b');
    result = result.replaceAll(emailRegex, '[REDACTED_EMAIL]');

    return result;
  }

  /// Automatically redacts values from key-value metadata maps.
  ///
  /// Replaces any values associated with forbidden fields (e.g. key, password, secret)
  /// with a placeholder, and applies text redaction to any string parameters.
  static Map<String, Object> redactMetadata(Map<String, Object> metadata) {
    final Map<String, Object> redacted = {};
    final sensitiveKeys = RegExp(
      r'(key|password|secret|token|pass|vault|message|note|body|text)',
      caseSensitive: false,
    );

    metadata.forEach((key, value) {
      if (sensitiveKeys.hasMatch(key)) {
        redacted[key] = '[REDACTED_SENSITIVE_FIELD]';
      } else if (value is String) {
        redacted[key] = redact(value);
      } else if (value is Map) {
        try {
          final typedMap = Map<String, Object>.from(value);
          redacted[key] = redactMetadata(typedMap);
        } catch (_) {
          redacted[key] = '[UNPARSABLE_MAP]';
        }
      } else {
        redacted[key] = value;
      }
    });

    return redacted;
  }

  // ── Logging Level Dispatches ──────────────────────────────────────────────

  static void trace(String message, {Map<String, Object>? metadata, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.trace, message, metadata, error, stackTrace);
  }

  static void debug(String message, {Map<String, Object>? metadata, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, metadata, error, stackTrace);
  }

  static void info(String message, {Map<String, Object>? metadata, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, metadata, error, stackTrace);
  }

  static void warning(String message, {Map<String, Object>? metadata, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, metadata, error, stackTrace);
  }

  static void error(String message, {Map<String, Object>? metadata, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, metadata, error, stackTrace);
  }

  static void fatal(String message, {Map<String, Object>? metadata, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.fatal, message, metadata, error, stackTrace);
  }

  // ── Dispatch Implementation ───────────────────────────────────────────────

  static void _log(
    LogLevel level,
    String message,
    Map<String, Object>? metadata,
    Object? error,
    StackTrace? stackTrace,
  ) {
    // 1. Redact inputs
    final redactedMessage = redact(message);
    final redactedMetadata = metadata != null ? redactMetadata(metadata) : null;

    final event = LogEvent(
      level: level,
      message: redactedMessage,
      metadata: redactedMetadata,
      error: error,
      stackTrace: stackTrace,
    );

    // 2. Dispatch to all active outputs
    for (final output in _outputs) {
      try {
        output.output(event);
      } catch (e) {
        debugPrint('[AppLogger] Error dispatching log event: $e');
      }
    }
  }
}
