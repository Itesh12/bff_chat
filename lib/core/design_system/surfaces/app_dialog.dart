import 'package:flutter/material.dart';
import 'package:memovault/core/theme/app_spacing.dart';
import 'package:memovault/core/theme/app_radius.dart';
import 'package:memovault/core/theme/app_gap.dart';
import 'package:memovault/core/theme/app_typography.dart';
import 'package:memovault/core/design_system/buttons/app_button.dart';

/// A static design system helper to trigger consistent custom dialog actions.
/// Standardizes layouts, spacing, header fonts, and uses [AppButton] variant API.
abstract final class AppDialog {

  /// Shows an informational modal dialog.
  static void info(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'Dismiss',
    VoidCallback? onPressed,
  }) {
    _show(
      context,
      title: title,
      message: message,
      actions: (theme) => [
        AppButton.primary(
          text: buttonText,
          onPressed: () {
            Navigator.pop(context);
            onPressed?.call();
          },
        ),
      ],
    );
  }

  /// Shows a confirmation dialog with dynamic actions.
  static void confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    _show(
      context,
      title: title,
      message: message,
      actions: (theme) => [
        AppButton.text(
          text: cancelLabel,
          onPressed: () {
            Navigator.pop(context);
            onCancel?.call();
          },
        ),
        const AppGap.h8(),
        AppButton.primary(
          text: confirmLabel,
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
        ),
      ],
    );
  }

  /// Shows a warning/destructive deletion dialog.
  static void delete(
    BuildContext context, {
    required String title,
    required String message,
    String deleteLabel = 'Delete',
    String cancelLabel = 'Cancel',
    required VoidCallback onDelete,
    VoidCallback? onCancel,
  }) {
    _show(
      context,
      title: title,
      message: message,
      actions: (theme) => [
        AppButton.text(
          text: cancelLabel,
          onPressed: () {
            Navigator.pop(context);
            onCancel?.call();
          },
        ),
        const AppGap.h8(),
        AppButton.danger(
          text: deleteLabel,
          onPressed: () {
            Navigator.pop(context);
            onDelete();
          },
        ),
      ],
    );
  }

  static void _show(
    BuildContext context, {
    required String title,
    required String message,
    required List<Widget> Function(ThemeData) actions,
  }) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.large),
          backgroundColor: theme.cardColor,
          titlePadding: const EdgeInsets.fromLTRB(AppSpacing.s24, AppSpacing.s24, AppSpacing.s24, 0),
          contentPadding: const EdgeInsets.fromLTRB(AppSpacing.s24, AppSpacing.s16, AppSpacing.s24, AppSpacing.s24),
          actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, AppSpacing.s16),
          title: Text(
            title,
            style: AppTypography.titleLarge.copyWith(
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          content: Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions(theme),
            ),
          ],
        );
      },
    );
  }
}
