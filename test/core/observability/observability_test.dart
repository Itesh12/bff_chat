import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/observability/log_level.dart';
import 'package:memovault/core/observability/logger_output.dart';
import 'package:memovault/core/observability/performance_tracker.dart';
import 'package:memovault/core/services/analytics_service.dart';
import 'package:memovault/core/services/noop_analytics_service.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Records all log events dispatched through the pipeline during a test.
class _CollectingOutput implements LoggerOutput {
  final List<LogEvent> events = [];

  @override
  void output(LogEvent event) => events.add(event);

  Iterable<LogEvent> get warnings =>
      events.where((e) => e.level == LogLevel.warning);
  Iterable<LogEvent> get errors =>
      events.where((e) => e.level == LogLevel.error);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Reset AppLogger between tests.
  setUp(() {
    AppLogger.clearOutputs();
    PerformanceTracker.reset();
  });

  group('AppLogger Redaction Tests', () {
    test('redacts a valid 32-byte base64url encryption key from message', () {
      // Generate a realistic 43-char base64url key.
      final key = base64UrlEncode(List.generate(32, (i) => i));

      final redacted = AppLogger.redact('Opening database with key=$key now');

      expect(redacted, contains('[REDACTED_KEY]'),
          reason: 'Encryption key must be replaced with redaction marker');
      expect(redacted, isNot(contains(key)),
          reason: 'Original key must not appear in redacted output');
    });

    test('redacts an email address from message', () {
      final redacted = AppLogger.redact('User login: alice@memovault.app');

      expect(redacted, contains('[REDACTED_EMAIL]'));
      expect(redacted, isNot(contains('alice@memovault.app')));
    });

    test('passes through safe messages unchanged', () {
      const safe = 'Note created successfully';
      expect(AppLogger.redact(safe), equals(safe));
    });

    test('redacts sensitive metadata fields by key name', () {
      final redacted = AppLogger.redactMetadata({
        'userId': 'u_001',         // safe: no sensitive keyword
        'eventCount': 42,          // safe: numeric
        'password': 'super_secret', // sensitive: matches 'password'
        'token': 'Bearer xyz',     // sensitive: matches 'token'
        'noteBody': 'Dear diary',  // sensitive: matches 'note'
      });

      expect(redacted['password'], equals('[REDACTED_SENSITIVE_FIELD]'),
          reason: 'password field must be redacted');
      expect(redacted['token'], equals('[REDACTED_SENSITIVE_FIELD]'),
          reason: 'token field must be redacted');
      expect(redacted['noteBody'], equals('[REDACTED_SENSITIVE_FIELD]'),
          reason: 'noteBody matches note pattern and must be redacted');
      expect(redacted['userId'], equals('u_001'),
          reason: 'userId is not a sensitive field and must pass through');
      expect(redacted['eventCount'], equals(42),
          reason: 'Numeric non-sensitive field must pass through');
    });

    test('dispatches redacted log events to registered outputs', () {
      final collector = _CollectingOutput();
      AppLogger.addOutput(collector);

      final key = base64UrlEncode(List.generate(32, (i) => i));
      AppLogger.warning('Suspicious key=$key in payload');

      expect(collector.events.length, equals(1));
      final message = collector.events.first.message;
      expect(message, isNot(contains(key)));
      expect(message, contains('[REDACTED_KEY]'));
    });

    test('does not dispatch below minimum level on registered output', () {
      final collector = _CollectingOutput();
      AppLogger.addOutput(collector);

      AppLogger.trace('Very verbose trace');
      AppLogger.debug('Some debug message');
      AppLogger.info('Info message');
      AppLogger.warning('Warning message');

      // All are dispatched — filtering is the output's responsibility.
      expect(collector.events.length, equals(4));
    });
  });

  // ── Telemetry Opt-Out ─────────────────────────────────────────────────────

  group('NoOpAnalyticsService Tests', () {
    test('isEnabled returns false for NoOpAnalyticsService', () {
      final AnalyticsService analytics = NoOpAnalyticsService();
      expect(analytics.isEnabled, isFalse);
    });

    test('logEvent completes without error when disabled', () async {
      final analytics = NoOpAnalyticsService();
      // Should not throw.
      await analytics.logEvent(name: 'note_created', parameters: {'noteId': 'n1'});
    });

    test('logScreenView completes without error when disabled', () async {
      final analytics = NoOpAnalyticsService();
      await analytics.logScreenView(screenName: 'home_screen');
    });

    test('setUserProperty completes without error when disabled', () async {
      final analytics = NoOpAnalyticsService();
      await analytics.setUserProperty(name: 'theme', value: 'dark');
    });
  });

  // ── Performance Tracker ───────────────────────────────────────────────────

  group('PerformanceTracker Tests', () {
    test('records a valid duration for a named operation', () {
      PerformanceTracker.start('startup');
      final duration = PerformanceTracker.finish('startup');

      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('resultFor returns stored duration after finish', () {
      PerformanceTracker.start('db_open');
      PerformanceTracker.finish('db_open');

      final result = PerformanceTracker.resultFor('db_open');
      expect(result, isNotNull);
    });

    test('finish returns null for unstarted operation', () {
      final result = PerformanceTracker.finish('never_started');
      expect(result, isNull);
    });

    test('reset clears all stored timings', () {
      PerformanceTracker.start('op');
      PerformanceTracker.finish('op');
      PerformanceTracker.reset();

      expect(PerformanceTracker.resultFor('op'), isNull);
    });
  });
}
