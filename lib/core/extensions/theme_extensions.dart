import 'package:flutter/material.dart';
import 'package:memovault/core/theme/app_color_scheme.dart';

/// Context theme lookups helper extension.
/// Ensures standard clean references: `context.theme` and `context.colors`
/// instead of repetitive direct ThemeData lookup boilerplate.
extension ThemeContextX on BuildContext {
  /// Resolves the custom [AppColorScheme] extension from the active theme.
  /// Returns a robust fallback if the extension is not defined (e.g. inside a test context).
  AppColorScheme get colors => Theme.of(this).extension<AppColorScheme>() ?? const AppColorScheme(
        vaultStatusLocked: Color(0xFFD97706),
        vaultStatusUnlocked: Color(0xFF10B981),
        success: Color(0xFF10B981),
        warning: Color(0xFFF59E0B),
        error: Color(0xFFDC2626),
        info: Color(0xFF0EA5E9),
        disabled: Color(0xFFD1D5DB),
      );
}
