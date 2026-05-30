import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:memovault/core/bindings/initial_binding.dart';
import 'package:memovault/core/routes/app_pages.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/core/services/theme_service.dart';
import 'package:memovault/core/theme/app_theme.dart';

import 'package:memovault/core/observability/app_logger.dart';

/// Root application widget.
///
/// Uses [GetMaterialApp] as the foundation for Phase 1 GetX integration.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeService themeService = Get.find<ThemeService>();

    return GetMaterialApp(
      title: 'MemoVault',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.notes,
      initialBinding: InitialBinding(),
      getPages: AppPages.pages,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeService.themeMode,
      routingCallback: (routing) {
        if (routing != null) {
          AppLogger.info('Route change', metadata: {'route': routing.current});
        }
      },
    );
  }
}
