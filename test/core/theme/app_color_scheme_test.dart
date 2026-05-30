import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/theme/app_color_scheme.dart';

void main() {
  group('AppColorScheme ThemeExtension Tests', () {
    const scheme1 = AppColorScheme(
      vaultStatusLocked: Color(0xFF111111),
      vaultStatusUnlocked: Color(0xFF222222),
      success: Color(0xFF333333),
      warning: Color(0xFF444444),
      error: Color(0xFF555555),
      info: Color(0xFF666666),
      disabled: Color(0xFF777777),
    );

    const scheme2 = AppColorScheme(
      vaultStatusLocked: Color(0xFF888888),
      vaultStatusUnlocked: Color(0xFF999999),
      success: Color(0xFFAAAAAA),
      warning: Color(0xFFBBBBBB),
      error: Color(0xFFCCCCCC),
      info: Color(0xFFDDDDDD),
      disabled: Color(0xFFEEEEEE),
    );

    test('copyWith works correctly', () {
      final copied = scheme1.copyWith(success: const Color(0xFF999999));

      expect(copied.vaultStatusLocked, scheme1.vaultStatusLocked);
      expect(copied.success, const Color(0xFF999999));
    });

    test('lerp works correctly between schemes', () {
      final lerped = scheme1.lerp(scheme2, 0.5);

      expect(
        lerped.vaultStatusLocked,
        Color.lerp(scheme1.vaultStatusLocked, scheme2.vaultStatusLocked, 0.5),
      );
      expect(
        lerped.success,
        Color.lerp(scheme1.success, scheme2.success, 0.5),
      );
    });
  });
}
