import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/theme/app_color_scheme.dart';
import 'package:memovault/core/theme/app_spacing.dart';
import 'package:memovault/core/theme/app_radius.dart';
import 'package:memovault/core/theme/app_typography.dart';
import 'package:memovault/core/config/env_config.dart';

/// A static design system helper to trigger consistent, themed snackbars.
/// Avoids using [Get.snackbar] directly by structuring colors, margins, and icons internally.
abstract final class AppSnackBar {
  
  /// Displays a success notification.
  static void success({required String title, required String message}) {
    _show(
      title: title,
      message: message,
      getThemeColor: (colors) => colors.success,
      icon: Icons.check_circle_outline,
    );
  }

  /// Displays an error notification.
  static void error({required String title, required String message}) {
    _show(
      title: title,
      message: message,
      getThemeColor: (colors) => colors.error,
      icon: Icons.error_outline,
    );
  }

  /// Displays an information notification.
  static void info({required String title, required String message}) {
    _show(
      title: title,
      message: message,
      getThemeColor: (colors) => colors.info,
      icon: Icons.info_outline,
    );
  }

  static void _show({
    required String title,
    required String message,
    required Color Function(AppColorScheme) getThemeColor,
    required IconData icon,
  }) {
    // Fail-safe check for headless widget/integration test environments
    if (EnvConfig.isTest) {
      return;
    }

    final context = Get.context;
    if (context == null) return;

    final theme = Theme.of(context);
    final colors = theme.extension<AppColorScheme>();
    final baseColor = colors != null
        ? getThemeColor(colors)
        : (theme.brightness == Brightness.dark ? Colors.tealAccent : Colors.teal);

    Get.snackbar(
      title,
      message,
      titleText: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
      ),
      messageText: Text(
        message,
        style: AppTypography.bodySmall.copyWith(
          color: (theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87),
        ),
      ),
      icon: Icon(icon, color: baseColor, size: 22),
      backgroundColor: theme.brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
      borderColor: baseColor.withValues(alpha: 0.3),
      borderWidth: 1.0,
      borderRadius: AppRadius.rMedium,
      margin: const EdgeInsets.all(AppSpacing.s16),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      snackPosition: SnackPosition.BOTTOM,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.3 : 0.06),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
