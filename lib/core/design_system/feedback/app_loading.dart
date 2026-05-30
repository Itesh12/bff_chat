import 'package:flutter/material.dart';
import 'package:memovault/core/theme/app_spacing.dart';

enum _AppLoadingVariant { small, medium, fullScreen }

/// A unified loader conforming strictly to the design system.
/// Avoids raw circular indicators and creates standard container shapes and dark translucent overlays.
class AppLoading extends StatelessWidget {
  final _AppLoadingVariant _variant;

  const AppLoading.small({super.key}) : _variant = _AppLoadingVariant.small;
  const AppLoading.medium({super.key}) : _variant = _AppLoadingVariant.medium;
  const AppLoading.fullScreen({super.key}) : _variant = _AppLoadingVariant.fullScreen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (_variant) {
      case _AppLoadingVariant.small:
        return SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        );
      case _AppLoadingVariant.medium:
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: SizedBox(
            height: 36,
            width: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
        );
      case _AppLoadingVariant.fullScreen:
        return Stack(
          children: [
            // Darkened modal barrier to prevent double interaction
            const Opacity(
              opacity: 0.4,
              child: ModalBarrier(dismissible: false, color: Colors.black),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s24),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: const AppLoading.medium(),
              ),
            ),
          ],
        );
    }
  }
}
