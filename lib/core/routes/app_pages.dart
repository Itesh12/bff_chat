import 'package:get/get.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/features/home/views/home_screen.dart';
import 'package:memovault/features/theme_sandbox/views/theme_sandbox_screen.dart';

abstract final class AppPages {
  static final List<GetPage<dynamic>> pages = [
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
    ),
    GetPage(
      name: AppRoutes.themeSandbox,
      page: () => const ThemeSandboxScreen(),
    ),
  ];
}
