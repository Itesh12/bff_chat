import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/app.dart';
import 'package:memovault/core/config/env_config.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/observability/console_output.dart';
import 'package:memovault/core/observability/crashlytics_output.dart';
import 'package:memovault/core/observability/performance_tracker.dart';
import 'package:memovault/core/services/analytics_service.dart';
import 'package:memovault/core/services/database_service.dart';
import 'package:memovault/core/services/firebase_analytics_service.dart';
import 'package:memovault/core/services/preferences_service.dart';
import 'package:memovault/core/services/preferences_service_impl.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/core/services/secure_storage_service_impl.dart';
import 'package:memovault/core/services/theme_service.dart';
import 'package:memovault/firebase_options_staging.dart';

/// Staging flavor entry point.
/// Firebase project: flutterpay-83bad  |  App: com.memovault.staging
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  EnvConfig.initialize(Environment.staging);

  // --- Firebase initialization (must come before observability outputs) ---
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- Observability bootstrap ---
  // Staging: console + Crashlytics (warning+, ≤30 days, per ADR-013).
  AppLogger.addOutput(ConsoleOutput());
  AppLogger.addOutput(CrashlyticsOutput());
  // Staging: analytics enabled via Firebase.
  Get.put<AnalyticsService>(FirebaseAnalyticsService(), permanent: true);

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
    return true;
  };

  PerformanceTracker.start('startup');

  // --- Bootstrap sequence (order is mandatory) ---
  // 1. Secure storage (provides encryption key to DatabaseService)
  Get.put<SecureStorageService>(SecureStorageServiceImpl(), permanent: true);
  // 2. Preferences
  Get.put<PreferencesService>(PreferencesServiceImpl(), permanent: true);
  // 3. Database (needs SecureStorageService; must complete before runApp)
  await Get.putAsync<DatabaseService>(
    () => DatabaseService().init(),
    permanent: true,
  );
  // 4. Theme
  Get.put<ThemeService>(ThemeService(), permanent: true);

  final startupMs = PerformanceTracker.finish('startup')?.inMilliseconds;
  AppLogger.info('App bootstrap complete', metadata: {'startup_ms': startupMs ?? 0});

  runApp(const App());
}
