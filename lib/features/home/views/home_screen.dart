import 'package:flutter/material.dart';

/// Placeholder home screen — Phase 1.1 bootstrap only.
/// All real UI is implemented in Phase 2+.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('MemoVault — Framework Checkpoint 1.1'),
      ),
    );
  }
}
