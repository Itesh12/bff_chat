import 'package:memovault/core/services/analytics_service.dart';

/// No-operation [AnalyticsService] implementation that silently discards all events.
///
/// Used in:
/// - All unit tests (prevents any real Firebase calls).
/// - Development flavor (telemetry disabled by default).
/// - When the user has opted out of telemetry in app preferences.
class NoOpAnalyticsService implements AnalyticsService {
  @override
  bool get isEnabled => false;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    // Intentionally empty — no telemetry dispatched.
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    // Intentionally empty.
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    // Intentionally empty.
  }
}
