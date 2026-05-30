/// Abstract contract for all analytics/telemetry implementations.
///
/// Consumers (controllers, repositories) must depend only on this interface,
/// never on `FirebaseAnalyticsService` directly.
///
/// ADR-013 rules that apply here:
/// - All event names MUST use snake_case (e.g. `note_created`, `vault_opened`).
/// - Parameters must never contain note content, message text, or encryption keys.
/// - Telemetry must be a no-op when [isEnabled] is false.
abstract class AnalyticsService {
  /// Returns true when telemetry is active and events should be dispatched.
  /// When false, all log/event calls should silently succeed without touching Firebase.
  bool get isEnabled;

  /// Logs a named application event with optional metadata parameters.
  ///
  /// [name] must be `snake_case`. Max 40 chars, no spaces.
  /// [parameters] must contain only non-sensitive metadata (IDs, enum values, counts).
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  });

  /// Logs a screen view transition for navigation analytics.
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  });

  /// Associates a non-identifying user property with the current session.
  Future<void> setUserProperty({
    required String name,
    required String value,
  });
}
