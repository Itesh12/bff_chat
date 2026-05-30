import 'package:flutter/material.dart';
import 'package:memovault/app.dart';
import 'package:memovault/core/config/env_config.dart';

/// Development flavor entry point.
/// Firebase initialization: configure memovault-dev credentials before enabling.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  EnvConfig.initialize(Environment.dev);
  // TODO(phase-1.1): Uncomment when google-services.json is configured
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptionsDev.currentPlatform,
  // );
  runApp(const App());
}
