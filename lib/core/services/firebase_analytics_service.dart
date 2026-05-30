import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:memovault/core/services/analytics_service.dart';

/// Production [AnalyticsService] backed by Firebase Analytics.
///
/// Only instantiated when:
/// 1. Firebase has been initialized via `Firebase.initializeApp()`.
/// 2. The user has not opted out of telemetry (`isEnabled == true`).
///
/// ADR-013 rules enforced:
/// - Event names are asserted to be `snake_case` at debug time.
/// - Parameters must never contain sensitive user data.
class FirebaseAnalyticsService implements AnalyticsService {
  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  @override
  bool get isEnabled => true;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    assert(
      RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(name),
      'ADR-013: Analytics event name "$name" must be snake_case, start with a letter, '
      'and be ≤40 characters.',
    );
    await _analytics.logEvent(
      name: name,
      parameters: parameters?.map((k, v) => MapEntry(k, v)),
    );
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    await _analytics.setUserProperty(name: name, value: value);
  }
}
