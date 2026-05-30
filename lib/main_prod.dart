import 'package:flutter/material.dart';
import 'package:memovault/app.dart';

/// Production flavor entry point.
/// Firebase initialization: configure memovault-prod credentials before enabling.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO(phase-1.1): Uncomment when google-services.json is configured
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptionsProd.currentPlatform,
  // );
  runApp(const App());
}
