import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/services/theme_service.dart';

void main() {
  group('ThemeService Tests', () {
    late ThemeService themeService;

    setUp(() {
      themeService = ThemeService();
    });

    test('Initial theme mode is system', () async {
      await themeService.init();
      expect(themeService.themeMode, ThemeMode.system);
    });

    test('setThemeMode updates state successfully', () {
      themeService.setThemeMode(ThemeMode.dark);
      expect(themeService.themeMode, ThemeMode.dark);

      themeService.setThemeMode(ThemeMode.light);
      expect(themeService.themeMode, ThemeMode.light);
    });

    test('toggleTheme toggles correctly between light and dark modes', () {
      themeService.setThemeMode(ThemeMode.light);
      themeService.toggleTheme();
      expect(themeService.themeMode, ThemeMode.dark);

      themeService.toggleTheme();
      expect(themeService.themeMode, ThemeMode.light);
    });
  });
}
