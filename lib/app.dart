import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/features/home/views/home_screen.dart';

/// Root application widget.
///
/// Uses [GetMaterialApp] as the foundation for Phase 1 GetX integration.
/// Route pages and bindings are wired in Phase 1.2.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'MemoVault',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.home,
      getPages: [
        GetPage(
          name: AppRoutes.home,
          page: () => const HomeScreen(),
        ),
      ],
    );
  }
}
