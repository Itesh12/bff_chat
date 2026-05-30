import 'package:flutter/material.dart';
import 'package:memovault/core/extensions/theme_extensions.dart';
import 'package:memovault/core/theme/app_spacing.dart';
import 'package:memovault/core/theme/app_radius.dart';
import 'package:memovault/core/theme/app_typography.dart';
import 'package:memovault/core/theme/app_durations.dart';

enum _AppButtonVariant { primary, secondary, text, danger }

/// A unified, highly-customizable button that conforms to the design system.
/// Handles standard, outline, and text button formats, async callback tracking, and loading spinners.
class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Future<void> Function()? onPressedAsync;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final _AppButtonVariant _variant;

  const AppButton.primary({
    super.key,
    required this.text,
    this.onPressed,
    this.onPressedAsync,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : _variant = _AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.onPressedAsync,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : _variant = _AppButtonVariant.secondary;

  const AppButton.text({
    super.key,
    required this.text,
    this.onPressed,
    this.onPressedAsync,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : _variant = _AppButtonVariant.text;

  const AppButton.danger({
    super.key,
    required this.text,
    this.onPressed,
    this.onPressedAsync,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : _variant = _AppButtonVariant.danger;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _localLoading = false;

  bool get _effectiveLoading => widget.isLoading || _localLoading;

  Future<void> _handlePressed() async {
    if (_effectiveLoading) return;

    if (widget.onPressedAsync != null) {
      setState(() => _localLoading = true);
      try {
        await widget.onPressedAsync!();
      } finally {
        if (mounted) {
          setState(() => _localLoading = false);
        }
      }
    } else {
      widget.onPressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = (widget.onPressed != null || widget.onPressedAsync != null) && !_effectiveLoading;

    // Resolve color styling tokens based on variant and dark/light modes
    Color bgColor;
    Color fgColor;
    Color? borderColor;

    switch (widget._variant) {
      case _AppButtonVariant.primary:
        bgColor = isEnabled
            ? theme.colorScheme.primary
            : (isDark ? Colors.grey[800]! : Colors.grey[300]!);
        fgColor = isEnabled
            ? (isDark ? Colors.black : Colors.white)
            : (isDark ? Colors.grey[600]! : Colors.grey[500]!);
        break;
      case _AppButtonVariant.secondary:
        bgColor = isEnabled
            ? (isDark ? Colors.grey[900]! : Colors.grey[100]!)
            : Colors.transparent;
        fgColor = isEnabled
            ? theme.colorScheme.primary
            : (isDark ? Colors.grey[750]! : Colors.grey[400]!);
        borderColor = isEnabled
            ? (isDark ? Colors.grey[800]! : Colors.grey[300]!)
            : (isDark ? Colors.grey[900]! : Colors.grey[200]!);
        break;
      case _AppButtonVariant.text:
        bgColor = Colors.transparent;
        fgColor = isEnabled
            ? theme.colorScheme.primary
            : (isDark ? Colors.grey[700]! : Colors.grey[450]!);
        break;
      case _AppButtonVariant.danger:
        bgColor = isEnabled
            ? colors.error
            : (isDark ? Colors.grey[850]! : Colors.grey[200]!);
        fgColor = isEnabled
            ? Colors.white
            : (isDark ? Colors.grey[600]! : Colors.grey[400]!);
        break;
    }

    final textStyle = AppTypography.buttonText.copyWith(color: fgColor);

    Widget content;
    if (_effectiveLoading) {
      content = SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(fgColor),
        ),
      );
    } else {
      final textWidget = Text(
        widget.text,
        style: textStyle,
        textAlign: TextAlign.center,
      );

      if (widget.icon != null) {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 18, color: fgColor),
            const SizedBox(width: AppSpacing.s8),
            textWidget,
          ],
        );
      } else {
        content = textWidget;
      }
    }

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
          onTap: isEnabled ? _handlePressed : null,
          borderRadius: AppRadius.medium,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.s12,
              horizontal: AppSpacing.s24,
            ),
            child: Center(
              widthFactor: widget.isFullWidth ? null : 1.0,
              heightFactor: 1.0,
              child: content,
            ),
          ),
        ),
      ),
    );

    if (widget.isFullWidth) {
      button = SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}
