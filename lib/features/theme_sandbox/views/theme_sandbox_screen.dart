import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/services/theme_service.dart';
import 'package:memovault/core/theme/app_color_scheme.dart';
import 'package:memovault/core/theme/app_radius.dart';
import 'package:memovault/core/theme/app_spacing.dart';
import 'package:memovault/core/theme/app_typography.dart';

class ThemeSandboxScreen extends StatelessWidget {
  const ThemeSandboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<ThemeService>();
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorScheme>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text('MemoVault Design System Sandbox', style: AppTypography.titleMedium.copyWith(color: theme.colorScheme.onSurface)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(height: 1.0, color: theme.dividerColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Mode Toggle
            Card(
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.large,
                side: BorderSide.none,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: AppRadius.large,
                  border: Border.all(color: theme.dividerColor, width: 0.75),
                  color: theme.cardColor,
                ),
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Theme Mode Control', style: AppTypography.titleLarge),
                    const SizedBox(height: AppSpacing.s12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => themeService.setThemeMode(ThemeMode.light),
                          child: const Text('Light'),
                        ),
                        ElevatedButton(
                          onPressed: () => themeService.setThemeMode(ThemeMode.dark),
                          child: const Text('Dark'),
                        ),
                        ElevatedButton(
                          onPressed: () => themeService.setThemeMode(ThemeMode.system),
                          child: const Text('System'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s24),

            // Typography Matrix
            const Text('Typography', style: AppTypography.titleLarge),
            const SizedBox(height: AppSpacing.s12),
            Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.large,
                border: Border.all(color: theme.dividerColor, width: 0.75),
                color: theme.cardColor,
              ),
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Display Large (Outfit 28)', style: AppTypography.displayLarge),
                  SizedBox(height: AppSpacing.s12),
                  Text('Title Large (Outfit 20)', style: AppTypography.titleLarge),
                  SizedBox(height: AppSpacing.s12),
                  Text('Title Medium (Outfit 16)', style: AppTypography.titleMedium),
                  SizedBox(height: AppSpacing.s12),
                  Text('Body Large (Inter 15)', style: AppTypography.bodyLarge),
                  SizedBox(height: AppSpacing.s12),
                  Text('Label Medium (Inter 12)', style: AppTypography.labelMedium),
                  SizedBox(height: AppSpacing.s12),
                  Text('BUTTON TEXT (Inter 14)', style: AppTypography.buttonText),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),

            // Colors Matrix
            const Text('Color Palette', style: AppTypography.titleLarge),
            const SizedBox(height: AppSpacing.s12),
            Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.large,
                border: Border.all(color: theme.dividerColor, width: 0.75),
                color: theme.cardColor,
              ),
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _colorBlock(theme, 'Primary Accent (Slate Blue)', theme.colorScheme.primary),
                  _colorBlock(theme, 'Secondary Accent (Muted Amber)', theme.colorScheme.secondary),
                  _colorBlock(theme, 'Vault Status Locked', customColors.vaultStatusLocked),
                  _colorBlock(theme, 'Vault Status Unlocked', customColors.vaultStatusUnlocked),
                  const Divider(height: AppSpacing.s24),
                  const Text('Semantic Colors', style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.s12),
                  _colorBlock(theme, 'Success', customColors.success),
                  _colorBlock(theme, 'Warning', customColors.warning),
                  _colorBlock(theme, 'Error', customColors.error),
                  _colorBlock(theme, 'Info', customColors.info),
                  _colorBlock(theme, 'Disabled', customColors.disabled),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),

            // Component Samples
            const Text('Components', style: AppTypography.titleLarge),
            const SizedBox(height: AppSpacing.s12),
            Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.large,
                border: Border.all(color: theme.dividerColor, width: 0.75),
                color: theme.cardColor,
              ),
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text input
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Vault Input Field',
                      border: OutlineInputBorder(borderRadius: AppRadius.medium),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // Chips
                  Row(
                    children: [
                      Chip(
                        label: const Text('Design System'),
                        backgroundColor: customColors.info.withValues(alpha: 0.1),
                        labelStyle: AppTypography.labelMedium.copyWith(color: customColors.info),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Chip(
                        label: const Text('MemoVault'),
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        labelStyle: AppTypography.labelMedium.copyWith(color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorBlock(ThemeData theme, String name, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadius.small,
              border: Border.all(color: theme.dividerColor),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Text(name, style: AppTypography.bodyLarge),
        ],
      ),
    );
  }
}
