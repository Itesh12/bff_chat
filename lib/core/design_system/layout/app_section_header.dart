import 'package:flutter/material.dart';
import 'package:memovault/core/theme/app_spacing.dart';
import 'package:memovault/core/theme/app_typography.dart';

/// A reusable global section subtitle/action header component.
/// Coordinates clean separations in listings (e.g. lists, grids, dividers) using spacing tokens.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleMedium?.color?.withValues(alpha: 0.8),
              ),
            ),
          ),
          if (action != null)
            action!,
        ],
      ),
    );
  }
}
