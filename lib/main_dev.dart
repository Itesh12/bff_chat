import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:libsignal/libsignal.dart';
import 'package:memovault/app.dart';
import 'package:memovault/core/config/env_config.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/observability/console_output.dart';
import 'package:memovault/core/observability/performance_tracker.dart';
import 'package:memovault/core/services/analytics_service.dart';
import 'package:memovault/core/services/database_service.dart';
import 'package:memovault/core/services/noop_analytics_service.dart';
import 'package:memovault/core/services/preferences_service.dart';
import 'package:memovault/core/services/preferences_service_impl.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/core/services/secure_storage_service_impl.dart';
import 'package:memovault/core/services/theme_service.dart';

/// Development flavor entry point.
///
/// Key differences from staging/prod:
///   - Firebase initialization is SKIPPED entirely (ADR-013: dev flavor
///     uses NoOp analytics; eliminates DNS errors and startup network calls).
///   - Console-only logging — no Crashlytics.
///   - Per-phase startup timing logged to console for performance analysis.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LibSignal.init();
  EnvConfig.initialize(Environment.dev);

  // Dev: console-only observability — no network telemetry (ADR-013).
  AppLogger.addOutput(ConsoleOutput());

  // Dev: NoOp analytics — no Firebase events dispatched.
  Get.put<AnalyticsService>(NoOpAnalyticsService(), permanent: true);

  // Intercept Flutter framework errors (synchronous widget/layout errors).
  FlutterError.onError = (details) {
    AppLogger.fatal(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // Intercept asynchronous Dart isolate errors (e.g. unawaited Future crashes).
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.fatal('Unhandled async error', error: error, stackTrace: stack);
    return true; // mark handled
  };

  // ── Bootstrap sequence with per-phase timing ───────────────────────────────

  PerformanceTracker.start('startup_total');

  // 1. Secure storage — provides encryption key to DatabaseService.
  PerformanceTracker.start('startup_secure_storage');
  Get.put<SecureStorageService>(SecureStorageServiceImpl(), permanent: true);
  AppLogger.info('startup_secure_storage_ms', metadata: {
    'ms': PerformanceTracker.finish('startup_secure_storage')?.inMilliseconds ??
        0,
  });

  // 2. Preferences — lightweight shared prefs, no encryption key dependency.
  PerformanceTracker.start('startup_preferences');
  Get.put<PreferencesService>(PreferencesServiceImpl(), permanent: true);
  AppLogger.info('startup_preferences_ms', metadata: {
    'ms': PerformanceTracker.finish('startup_preferences')?.inMilliseconds ?? 0,
  });

  // 3. Database — must complete before runApp (notes load on first frame).
  PerformanceTracker.start('startup_database');
  await Get.putAsync<DatabaseService>(
    () => DatabaseService().init(),
    permanent: true,
  );
  AppLogger.info('startup_database_ms', metadata: {
    'ms': PerformanceTracker.finish('startup_database')?.inMilliseconds ?? 0,
  });

  // 4. Theme — reads preferences, needs prefs ready.
  Get.put<ThemeService>(ThemeService(), permanent: true);

  AppLogger.info('startup_total_ms', metadata: {
    'ms': PerformanceTracker.finish('startup_total')?.inMilliseconds ?? 0,
  });

  // NOTE: Firebase.initializeApp() is intentionally omitted in dev flavor.
  // Use staging flavor to test Firebase-dependent features.

  runApp(const App());
}
