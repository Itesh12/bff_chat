import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:memovault/core/bindings/initial_binding.dart';
import 'package:memovault/core/routes/app_pages.dart';
import 'package:memovault/core/routes/app_routes.dart';

/// Root application widget.
///
/// Uses [GetMaterialApp] as the foundation for Phase 1 GetX integration.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'MemoVault',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.home,
      initialBinding: InitialBinding(),
      getPages: AppPages.pages,
    );
  }
}
