import 'package:flutter/material.dart';
import 'package:memovault/core/theme/app_color_scheme.dart';
import 'package:memovault/core/theme/app_typography.dart';

abstract final class AppTheme {
  // Light Theme Colors
  static const Color _lightBg = Color(0xFFFAFAFA);
  static const Color _lightCardBg = Color(0xFFFFFFFF);
  static const Color _lightPrimaryAccent = Color(0xFF4F6BED);
  static const Color _lightSecondaryAccent = Color(0xFFD97706);
  static const Color _lightDivider = Color(0xFFE5E7EB);

  // Dark Theme Colors
  static const Color _darkBg = Color(0xFF111318);
  static const Color _darkCardBg = Color(0xFF22262F);
  static const Color _darkPrimaryAccent = Color(0xFF6E8CFF);
  static const Color _darkSecondaryAccent = Color(0xFFF59E0B);
  static const Color _darkDivider = Color(0xFF2E333F);

  static ThemeData get light {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightBg,
      cardColor: _lightCardBg,
      dividerColor: _lightDivider,
      colorScheme: const ColorScheme.light(
        primary: _lightPrimaryAccent,
        secondary: _lightSecondaryAccent,
        surface: _lightCardBg,
        error: Color(0xFFDC2626),
      ),
      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLarge,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        bodyLarge: AppTypography.bodyLarge,
        labelMedium: AppTypography.labelMedium,
      ),
      extensions: const [
        AppColorScheme(
          vaultStatusLocked: _lightSecondaryAccent,
          vaultStatusUnlocked: Color(0xFF10B981),
          success: Color(0xFF10B981),
          warning: Color(0xFFF59E0B),
          error: Color(0xFFDC2626),
          info: Color(0xFF0EA5E9),
          disabled: Color(0xFFD1D5DB),
        ),
      ],
    );
  }

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBg,
      cardColor: _darkCardBg,
      dividerColor: _darkDivider,
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimaryAccent,
        secondary: _darkSecondaryAccent,
        surface: _darkCardBg,
        error: Color(0xFFF87171),
      ),
      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLarge,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        bodyLarge: AppTypography.bodyLarge,
        labelMedium: AppTypography.labelMedium,
      ),
      extensions: const [
        AppColorScheme(
          vaultStatusLocked: _darkSecondaryAccent,
          vaultStatusUnlocked: Color(0xFF34D399),
          success: Color(0xFF34D399),
          warning: Color(0xFFFBBF24),
          error: Color(0xFFF87171),
          info: Color(0xFF38BDF8),
          disabled: Color(0xFF4B5563),
        ),
      ],
    );
  }
}
