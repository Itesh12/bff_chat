import 'package:flutter/material.dart';
import 'package:memovault/core/extensions/theme_extensions.dart';
import 'package:memovault/core/theme/app_spacing.dart';
import 'package:memovault/core/theme/app_gap.dart';
import 'package:memovault/core/theme/app_typography.dart';
import 'package:memovault/core/design_system/feedback/app_loading.dart';
import 'package:memovault/core/design_system/buttons/app_button.dart';

/// A global, design-system compliant Page scaffold.
/// Coordinates global page structures, AppBar layouts, loading screens, and custom error/retry displays.
class AppScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.leading,
    this.actions,
    this.floatingActionButton,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Resolve visual layout stack
    Widget? appBarWidget;
    if (title != null) {
      appBarWidget = AppBar(
        leading: leading,
        title: Text(
          title!,
          style: AppTypography.titleLarge.copyWith(
            color: theme.textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: actions,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      );
    }

    Widget contentWidget;
    if (errorMessage != null) {
      contentWidget = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_outlined,
                size: 64,
                color: context.colors.error,
              ),
              const AppGap.v16(),
              Text(
                'Something went wrong',
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              const AppGap.v8(),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                ),
              ),
              if (onRetry != null) ...[
                const AppGap.v24(),
                AppButton.primary(
                  text: 'Try Again',
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      contentWidget = body;
    }

    return GestureDetector(
      // Global click-outside keyboard dismissal helper
      onTap: () {
        final currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: appBarWidget as PreferredSizeWidget?,
            body: contentWidget,
            floatingActionButton: floatingActionButton,
          ),
          if (isLoading)
            const AppLoading.fullScreen(),
        ],
      ),
    );
  }
}
