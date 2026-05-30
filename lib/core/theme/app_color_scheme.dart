import 'package:flutter/material.dart';

class AppColorScheme extends ThemeExtension<AppColorScheme> {
  final Color vaultStatusLocked;
  final Color vaultStatusUnlocked;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color disabled;

  const AppColorScheme({
    required this.vaultStatusLocked,
    required this.vaultStatusUnlocked,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.disabled,
  });

  @override
  AppColorScheme copyWith({
    Color? vaultStatusLocked,
    Color? vaultStatusUnlocked,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? disabled,
  }) {
    return AppColorScheme(
      vaultStatusLocked: vaultStatusLocked ?? this.vaultStatusLocked,
      vaultStatusUnlocked: vaultStatusUnlocked ?? this.vaultStatusUnlocked,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      disabled: disabled ?? this.disabled,
    );
  }

  @override
  AppColorScheme lerp(ThemeExtension<AppColorScheme>? other, double t) {
    if (other is! AppColorScheme) return this;
    return AppColorScheme(
      vaultStatusLocked: Color.lerp(vaultStatusLocked, other.vaultStatusLocked, t)!,
      vaultStatusUnlocked: Color.lerp(vaultStatusUnlocked, other.vaultStatusUnlocked, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
    );
  }
}
