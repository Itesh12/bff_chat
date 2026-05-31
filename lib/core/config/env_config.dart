import 'package:flutter/widgets.dart';

enum Environment { dev, staging, prod }

abstract final class EnvConfig {
  static bool? _isTestOverride;
  static bool get isTest {
    if (_isTestOverride != null) return _isTestOverride!;
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('TestWidgets');
    } catch (_) {
      return false;
    }
  }
  static set isTest(bool value) => _isTestOverride = value;
  static late Environment environment;
  static late String firebaseProjectId;
  static late bool enableDetailedLogging;
  static late bool enableAnalytics;

  static void initialize(Environment env) {
    environment = env;
    switch (env) {
      case Environment.dev:
        firebaseProjectId = 'memovault-dev';
        enableDetailedLogging = true;
        enableAnalytics = false;
      case Environment.staging:
        firebaseProjectId = 'memovault-staging';
        enableDetailedLogging = true;
        enableAnalytics = true;
      case Environment.prod:
        firebaseProjectId = 'memovault-prod';
        enableDetailedLogging = false;
        enableAnalytics = true;
    }
  }

  static bool get isProduction => environment == Environment.prod;
  static bool get isDevelopment => environment == Environment.dev;
  static bool get isStaging => environment == Environment.staging;

  /// True only for the dev flavor. Used to conditionally skip Firebase
  /// initialization (eliminates DNS errors and startup network calls in dev).
  static bool get isDevFlavor => environment == Environment.dev;
}
