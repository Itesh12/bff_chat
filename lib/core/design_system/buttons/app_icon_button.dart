import 'package:flutter/material.dart';
import 'package:memovault/core/extensions/theme_extensions.dart';
import 'package:memovault/core/theme/app_spacing.dart';
import 'package:memovault/core/theme/app_radius.dart';
import 'package:memovault/core/theme/app_durations.dart';

enum _AppIconButtonVariant { primary, secondary, danger }

/// A custom Icon Button conforming strictly to the design system.
/// Avoids the raw [IconButton] widget and coordinates variant background circles and semantic colors.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double? size;
  final String? tooltip;
  final _AppIconButtonVariant _variant;

  const AppIconButton.primary({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size,
    this.tooltip,
  }) : _variant = _AppIconButtonVariant.primary;

  const AppIconButton.secondary({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size,
    this.tooltip,
  }) : _variant = _AppIconButtonVariant.secondary;

  const AppIconButton.danger({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size,
    this.tooltip,
  }) : _variant = _AppIconButtonVariant.danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = onPressed != null;

    Color color;
    Color? bgColor;
    Color? borderColor;

    switch (_variant) {
      case _AppIconButtonVariant.primary:
        color = isEnabled
            ? theme.colorScheme.primary
            : (isDark ? Colors.grey[750]! : Colors.grey[400]!);
        bgColor = Colors.transparent;
        break;
      case _AppIconButtonVariant.secondary:
        color = isEnabled
            ? theme.iconTheme.color?.withValues(alpha: 0.8) ?? (isDark ? Colors.white70 : Colors.black87)
            : (isDark ? Colors.grey[750]! : Colors.grey[400]!);
        bgColor = isEnabled
            ? (isDark ? Colors.grey[900]! : Colors.grey[100]!)
            : Colors.transparent;
        borderColor = isEnabled
            ? (isDark ? Colors.grey[850]! : Colors.grey[200]!)
            : Colors.transparent;
        break;
      case _AppIconButtonVariant.danger:
        color = isEnabled ? colors.error : (isDark ? Colors.grey[750]! : Colors.grey[400]!);
        bgColor = Colors.transparent;
        break;
    }

    final double effectiveSize = size ?? 20.0;

    Widget button = AnimatedContainer(
      duration: AppDurations.fast,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.medium,
        border: borderColor != null ? Border.all(color: borderColor, width: 1.0) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.medium,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s8),
            child: Icon(
              icon,
              size: effectiveSize,
              color: color,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
