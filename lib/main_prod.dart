import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:libsignal/libsignal.dart';
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
import 'package:memovault/firebase_options_prod.dart';

/// Production flavor entry point.
/// Firebase project: flutterpay-83bad  |  App: com.memovault
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LibSignal.init();
  EnvConfig.initialize(Environment.prod);

  // --- Firebase initialization (must come before observability outputs for Crashlytics) ---
  PerformanceTracker.start('startup_firebase');
  bool firebaseReady = false;
  bool crashlyticsReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (e, st) {
    // Firebase.initializeApp can throw if a registered plugin (e.g. Crashlytics)
    // is not enabled in the Firebase Console. Fall back to console logging.
    debugPrint('[MemoVault] Firebase.initializeApp failed: $e\n$st');
  }
  final firebaseMs = PerformanceTracker.finish('startup_firebase')?.inMilliseconds ?? 0;

  // --- Observability bootstrap ---
  if (firebaseReady) {
    try {
      // Production: Crashlytics only — no console output (ADR-013 retention policy:
      // no local persistent logs, metadata-bound error reporting only).
      AppLogger.addOutput(CrashlyticsOutput());
      crashlyticsReady = true;
    } catch (e) {
      // Crashlytics component not present (not enabled in Firebase Console).
      // Fall back to console output so errors are still visible via adb logcat.
      debugPrint('[MemoVault] Crashlytics unavailable, falling back to console: $e');
      AppLogger.addOutput(ConsoleOutput());
    }
  } else {
    // Firebase failed entirely — use console output as safety net.
    AppLogger.addOutput(ConsoleOutput());
  }

  // Production: analytics enabled via Firebase (only if Firebase init succeeded).
  if (firebaseReady) {
    Get.put<AnalyticsService>(FirebaseAnalyticsService(), permanent: true);
  }

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

  // ── Bootstrap sequence with per-phase timing ───────────────────────────────
  PerformanceTracker.start('startup_total');

  AppLogger.info('startup_firebase_ms', metadata: {
    'ms': firebaseMs,
    'firebase_ready': firebaseReady,
    'crashlytics_ready': crashlyticsReady,
  });

  // 1. Secure storage (provides encryption key to DatabaseService)
  PerformanceTracker.start('startup_secure_storage');
  Get.put<SecureStorageService>(SecureStorageServiceImpl(), permanent: true);
  AppLogger.info('startup_secure_storage_ms', metadata: {
    'ms': PerformanceTracker.finish('startup_secure_storage')?.inMilliseconds ?? 0,
  });

  // 2. Preferences
  PerformanceTracker.start('startup_preferences');
  Get.put<PreferencesService>(PreferencesServiceImpl(), permanent: true);
  AppLogger.info('startup_preferences_ms', metadata: {
    'ms': PerformanceTracker.finish('startup_preferences')?.inMilliseconds ?? 0,
  });

  // 3. Database (needs SecureStorageService; must complete before runApp)
  PerformanceTracker.start('startup_database');
  await Get.putAsync<DatabaseService>(
    () => DatabaseService().init(),
    permanent: true,
  );
  AppLogger.info('startup_database_ms', metadata: {
    'ms': PerformanceTracker.finish('startup_database')?.inMilliseconds ?? 0,
  });

  // 4. Theme
  Get.put<ThemeService>(ThemeService(), permanent: true);

  final totalMs = PerformanceTracker.finish('startup_total')?.inMilliseconds ?? 0;
  AppLogger.info('App bootstrap complete', metadata: {
    'startup_total_ms': totalMs,
  });

  runApp(const App());
}
