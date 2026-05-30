import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/app.dart';
import 'package:memovault/core/config/env_config.dart';
import 'package:memovault/core/services/preferences_service.dart';
import 'package:memovault/core/services/preferences_service_impl.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/core/services/secure_storage_service_impl.dart';
import 'package:memovault/core/services/theme_service.dart';

/// Staging flavor entry point.
/// Firebase initialization: configure memovault-staging credentials before enabling.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  EnvConfig.initialize(Environment.staging);

  // Initialize storage services
  Get.put<SecureStorageService>(SecureStorageServiceImpl(), permanent: true);
  Get.put<PreferencesService>(PreferencesServiceImpl(), permanent: true);
  
  Get.put<ThemeService>(ThemeService(), permanent: true);

  // TODO(phase-1.1): Uncomment when google-services.json is configured
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptionsStaging.currentPlatform,
  // );
  runApp(const App());
}
