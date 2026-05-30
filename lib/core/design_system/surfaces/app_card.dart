import 'package:flutter/material.dart';
import 'package:memovault/core/theme/app_spacing.dart';
import 'package:memovault/core/theme/app_radius.dart';

/// A reusable global card surface container.
/// Coordinates card background colors, borders, and shadows dynamically across light/dark themes.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBg = theme.cardColor;
    final defaultBorder = theme.dividerColor;

    Widget cardContent = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.s16),
      child: child,
    );

    if (onTap != null) {
      cardContent = InkWell(
        onTap: onTap,
        borderRadius: AppRadius.large,
        child: cardContent,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBg,
        borderRadius: AppRadius.large,
        border: Border.all(
          color: borderColor ?? defaultBorder,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.large,
        child: Material(
          color: Colors.transparent,
          child: cardContent,
        ),
      ),
    );
  }
}
