import 'package:flutter/material.dart';
import 'package:memovault/core/theme/app_spacing.dart';
import 'package:memovault/core/theme/app_gap.dart';
import 'package:memovault/core/theme/app_typography.dart';
import 'package:memovault/core/design_system/buttons/app_button.dart';

/// A reusable global visual empty state container.
/// Standardizes vacancies across lists and grids with icons, headlines, and slot configurations.
class AppEmptyState extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCtaTap;

  const AppEmptyState({
    super.key,
    this.icon,
    this.customIcon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onCtaTap,
  }) : assert(icon != null || customIcon != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Decorative background for the icon
                    Container(
                      height: 96,
                      width: 96,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : theme.primaryColor.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : theme.primaryColor.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: customIcon ?? Icon(
                          icon!,
                          size: 40,
                          color: theme.primaryColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const AppGap.v24(),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTypography.titleLarge.copyWith(
                        color: theme.textTheme.titleLarge?.color?.withValues(alpha: 0.85),
                      ),
                    ),
                    const AppGap.v12(),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    if (ctaLabel != null && onCtaTap != null) ...[
                      const AppGap.v32(),
                      AppButton.primary(
                        text: ctaLabel!,
                        icon: Icons.add,
                        onPressed: onCtaTap,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
