import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/app.dart';
import 'package:memovault/core/config/env_config.dart';
import 'package:memovault/core/services/database_service.dart';
import 'package:memovault/core/services/preferences_service.dart';
import 'package:memovault/core/services/preferences_service_impl.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/core/services/secure_storage_service_impl.dart';
import 'package:memovault/core/services/theme_service.dart';

/// Development flavor entry point.
/// Firebase initialization: configure memovault-dev credentials before enabling.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  EnvConfig.initialize(Environment.dev);

  // --- Bootstrap sequence (order is mandatory) ---
  // 1. Secure storage (provides encryption key to DatabaseService)
  Get.put<SecureStorageService>(SecureStorageServiceImpl(), permanent: true);
  // 2. Preferences (lightweight shared prefs, no encryption key dependency)
  Get.put<PreferencesService>(PreferencesServiceImpl(), permanent: true);
  // 3. Database (needs SecureStorageService; must complete before runApp)
  await Get.putAsync<DatabaseService>(
    () => DatabaseService().init(),
    permanent: true,
  );
  // 4. Theme (reads preferences, needs prefs ready)
  Get.put<ThemeService>(ThemeService(), permanent: true);

  // TODO(phase-1.1): Uncomment when google-services.json is configured
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptionsDev.currentPlatform,
  // );
  runApp(const App());
}

