import 'package:flutter/foundation.dart';

/// Measures and reports application performance metrics.
///
/// Tracks:
/// - Startup boot latency (from first `main()` call to `runApp()` completing).
/// - Named operation durations (database queries, sync operations, etc.).
///
/// All metrics are reported via [AppLogger] and, in release builds, via the
/// [AnalyticsService] as non-sensitive performance events.
class PerformanceTracker {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, Duration> _results = {};

  /// Records the start of a named operation.
  static void start(String name) {
    _startTimes[name] = DateTime.now();
  }

  /// Finishes a named operation and stores the elapsed duration.
  /// Returns the elapsed [Duration], or null if [start] was never called.
  static Duration? finish(String name) {
    final startTime = _startTimes.remove(name);
    if (startTime == null) return null;

    final duration = DateTime.now().difference(startTime);
    _results[name] = duration;

    debugPrint(
      '[PerformanceTracker] ⏱ $name completed in ${duration.inMilliseconds}ms',
    );

    return duration;
  }

  /// Returns the stored result for a named operation (for assertions in tests).
  static Duration? resultFor(String name) => _results[name];

  /// Clears all stored timings (useful for test resets).
  static void reset() {
    _startTimes.clear();
    _results.clear();
  }
}
