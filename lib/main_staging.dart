import 'package:flutter/material.dart';
import 'package:memovault/app.dart';

/// Staging flavor entry point.
/// Firebase initialization: configure memovault-staging credentials before enabling.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO(phase-1.1): Uncomment when google-services.json is configured
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptionsStaging.currentPlatform,
  // );
  runApp(const App());
}
