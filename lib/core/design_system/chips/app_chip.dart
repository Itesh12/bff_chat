import 'package:flutter/material.dart';
import 'package:memovault/core/theme/app_spacing.dart';
import 'package:memovault/core/theme/app_radius.dart';
import 'package:memovault/core/theme/app_typography.dart';

/// A unified tag chip conforming strictly to design tokens.
/// Standardizes category swatches, message types, and metadata labels.
class AppChip extends StatelessWidget {
  final String label;
  final Color? color;

  const AppChip({
    super.key,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Fallback default style colors
    final baseColor = color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.15),
        borderRadius: AppRadius.max,
        border: Border.all(
          color: baseColor.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelLarge.copyWith(
          color: baseColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
