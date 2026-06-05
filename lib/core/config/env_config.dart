import 'dart:io';
import 'package:flutter/widgets.dart';

enum Environment { dev, staging, prod }

abstract final class EnvConfig {
  static bool? _isTestOverride;
  static bool get isTest {
    if (_isTestOverride != null) return _isTestOverride!;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
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
  static late String r2WorkerBaseUrl;
  static late String r2CdnBaseUrl;

  static void initialize(Environment env) {
    environment = env;
    switch (env) {
      case Environment.dev:
        firebaseProjectId = 'memovault-dev';
        enableDetailedLogging = true;
        enableAnalytics = false;
        r2WorkerBaseUrl = 'http://localhost:8787';
        r2CdnBaseUrl = 'mock-r2://';
      case Environment.staging:
        firebaseProjectId = 'memovault-staging';
        enableDetailedLogging = true;
        enableAnalytics = true;
        r2WorkerBaseUrl = 'https://staging-media-api.memovault.com';
        r2CdnBaseUrl = 'https://staging-media.memovault.com';
      case Environment.prod:
        firebaseProjectId = 'memovault-prod';
        enableDetailedLogging = false;
        enableAnalytics = true;
        r2WorkerBaseUrl = 'https://media-api.memovault.com';
        r2CdnBaseUrl = 'https://media.memovault.com';
    }
  }

  static bool get isProduction => environment == Environment.prod;
  static bool get isDevelopment => environment == Environment.dev;
  static bool get isStaging => environment == Environment.staging;

  /// True only for the dev flavor. Used to conditionally skip Firebase
  /// initialization (eliminates DNS errors and startup network calls in dev).
  static bool get isDevFlavor => environment == Environment.dev;
}
