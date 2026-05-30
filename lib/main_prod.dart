import 'package:flutter/material.dart';
import 'package:memovault/app.dart';
import 'package:memovault/core/config/env_config.dart';

/// Production flavor entry point.
/// Firebase initialization: configure memovault-prod credentials before enabling.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  EnvConfig.initialize(Environment.prod);
  // TODO(phase-1.1): Uncomment when google-services.json is configured
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptionsProd.currentPlatform,
  // );
  runApp(const App());
}
