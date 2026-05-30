import 'package:flutter/material.dart';
import 'package:memovault/core/theme/app_spacing.dart';
import 'package:memovault/core/theme/app_radius.dart';
import 'package:memovault/core/theme/app_gap.dart';
import 'package:memovault/core/theme/app_typography.dart';

/// A static design system helper to trigger consistent custom bottom sheets.
/// Standardizes upper corner radiuses, drag indicators, padding buffers, and dark mode colors.
abstract final class AppBottomSheet {

  /// Displays a highly polished, responsive bottom sheet modal.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    List<Widget>? actions,
    bool isScrollControlled = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.rLarge)),
      ),
      backgroundColor: theme.cardColor,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.s12,
                horizontal: AppSpacing.s16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Sleek Centered Drag Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        borderRadius: AppRadius.max,
                      ),
                    ),
                  ),
                  const AppGap.v16(),

                  // 2. Custom Sheet Header Title
                  if (title != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.titleMedium?.color,
                            ),
                          ),
                        ),
                        if (actions != null) ...actions,
                      ],
                    ),
                    const AppGap.v16(),
                  ],

                  // 3. Child Container content
                  isScrollControlled ? Expanded(child: child) : child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
