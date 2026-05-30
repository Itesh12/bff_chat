import 'package:flutter/material.dart';
import 'package:memovault/core/theme/app_spacing.dart';
import 'package:memovault/core/theme/app_gap.dart';
import 'package:memovault/core/theme/app_typography.dart';

/// A reusable global page title header component.
/// Standardizes major title screens with large headings and dynamic item/meta counters.
class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTypography.displayLarge.copyWith(
              color: theme.textTheme.displayLarge?.color,
            ),
          ),
          if (subtitle != null) ...[
            const AppGap.v4(),
            Text(
              subtitle!,
              style: AppTypography.bodyMedium.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
