import 'package:flutter/material.dart';
import 'package:memovault/app.dart';

/// Development flavor entry point.
/// Firebase initialization: configure memovault-dev credentials before enabling.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO(phase-1.1): Uncomment when google-services.json is configured
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptionsDev.currentPlatform,
  // );
  runApp(const App());
}
