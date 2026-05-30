import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/services/theme_service.dart';
import 'package:memovault/core/design_system/design_system.dart';

/// Live Catalog Showcase screen for MemoVault's Modular Design System.
/// Presents every layout, surface, feedback, and action primitive in all dark/light variants.
class DesignSystemSandboxScreen extends StatefulWidget {
  const DesignSystemSandboxScreen({super.key});

  @override
  State<DesignSystemSandboxScreen> createState() => _DesignSystemSandboxScreenState();
}

class _DesignSystemSandboxScreenState extends State<DesignSystemSandboxScreen> {
  final _searchController = TextEditingController();
  final _textController = TextEditingController();
  bool _isLoadingFullScreen = false;

  @override
  void dispose() {
    _searchController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<ThemeService>();
    final theme = Theme.of(context);

    return AppScaffold(
      isLoading: _isLoadingFullScreen,
      title: 'Design System Showcase',
      actions: [
        AppIconButton.secondary(
          icon: theme.brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode,
          tooltip: 'Toggle Theme',
          onPressed: () => themeService.toggleTheme(),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(
              title: 'Primitives Showcase',
              subtitle: 'Living catalog of MemoVault core elements',
            ),
            const AppGap.v24(),

            // ── Buttons Section ──────────────────────────────────────────────────
            const AppSectionHeader(title: 'Buttons & Action Primitives'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.primary(
                          text: 'Primary Action',
                          icon: Icons.check,
                          onPressed: () {},
                        ),
                      ),
                      const AppGap.h12(),
                      Expanded(
                        child: AppButton.secondary(
                          text: 'Secondary Action',
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const AppGap.v12(),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.danger(
                          text: 'Destructive Action',
                          icon: Icons.delete_outline,
                          onPressed: () {},
                        ),
                      ),
                      const AppGap.h12(),
                      Expanded(
                        child: AppButton.text(
                          text: 'Text Button Link',
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const AppGap.v16(),
                  const Text('Asynchronous Action Button (Autoplaying Spinner):', style: AppTypography.labelMedium),
                  const AppGap.v8(),
                  AppButton.primary(
                    text: 'Save Asynchronously (1.5s delay)',
                    isFullWidth: true,
                    onPressedAsync: () async {
                      await Future.delayed(const Duration(milliseconds: 1500));
                      if (context.mounted) {
                        AppSnackBar.success(title: 'Saved', message: 'The async execution finished perfectly!');
                      }
                    },
                  ),
                  const AppGap.v16(),
                  const Text('Icon Button Primitives:', style: AppTypography.labelMedium),
                  const AppGap.v8(),
                  Row(
                    children: [
                      AppIconButton.primary(
                        icon: Icons.star,
                        onPressed: () {},
                      ),
                      const AppGap.h12(),
                      AppIconButton.secondary(
                        icon: Icons.favorite,
                        onPressed: () {},
                      ),
                      const AppGap.h12(),
                      AppIconButton.danger(
                        icon: Icons.delete,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const AppGap.v24(),

            // ── Inputs Section ───────────────────────────────────────────────────
            const AppSectionHeader(title: 'Input Primitives'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Search Input (Pill Rounded, Built-in Debounce):', style: AppTypography.labelMedium),
                  const AppGap.v8(),
                  AppSearchBar(
                    controller: _searchController,
                    onChanged: (val) {
                      AppSnackBar.info(title: 'Search Query Debounced', message: 'Parsed query: "$val"');
                    },
                  ),
                  const AppGap.v16(),
                  const Text('Password Input (Obscure Toggle Suffix):', style: AppTypography.labelMedium),
                  const AppGap.v8(),
                  const AppTextField.password(),
                  const AppGap.v16(),
                  const Text('Multiline Form TextField:', style: AppTypography.labelMedium),
                  const AppGap.v8(),
                  AppTextField.multiline(
                    controller: _textController,
                    hintText: 'Type your secure thoughts...',
                    labelText: 'Secure Vault Details',
                  ),
                ],
              ),
            ),
            const AppGap.v24(),

            // ── Surfaces, Dialogs & Sheets ────────────────────────────────────────
            const AppSectionHeader(title: 'Surfaces, Modals & Dialogs'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton.secondary(
                    text: 'Show AppBottomSheet',
                    onPressed: () {
                      AppBottomSheet.show(
                        context,
                        title: 'Assign Category Modal',
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Bottom sheet modal conforms strictly to spacing and radiuses.'),
                            const AppGap.v16(),
                            AppButton.primary(
                              text: 'Dismiss Sheet',
                              isFullWidth: true,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const AppGap.v12(),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.secondary(
                          text: 'Dialog: Confirm',
                          onPressed: () {
                            AppDialog.confirm(
                              context,
                              title: 'Create Category?',
                              message: 'Are you sure you want to add this folder display swatch?',
                              onConfirm: () => AppSnackBar.success(title: 'Action Complete', message: 'Category was created.'),
                            );
                          },
                        ),
                      ),
                      const AppGap.h12(),
                      Expanded(
                        child: AppButton.danger(
                          text: 'Dialog: Delete',
                          onPressed: () {
                            AppDialog.delete(
                              context,
                              title: 'Delete Secure Note?',
                              message: 'Are you absolutely sure? This will soft-delete your secure entry.',
                              onDelete: () => AppSnackBar.error(title: 'Purged', message: 'Note was moved to trash.'),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const AppGap.v24(),

            // ── Feedback & Chips ─────────────────────────────────────────────────
            const AppSectionHeader(title: 'Feedback, Status & Chips'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Semantic Status Chips (AppChip):', style: AppTypography.labelMedium),
                  const AppGap.v8(),
                  const Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: [
                      AppChip(label: 'Work', color: Colors.blue),
                      AppChip(label: 'Finance', color: Colors.green),
                      AppChip(label: 'Encrypted', color: Colors.amber),
                      AppChip(label: 'Trash', color: Colors.red),
                    ],
                  ),
                  const AppGap.v16(),
                  const Text('AppLoading Primitive Variants:', style: AppTypography.labelMedium),
                  const AppGap.v8(),
                  const Row(
                    children: [
                      AppLoading.small(),
                      AppGap.h24(),
                      AppLoading.medium(),
                    ],
                  ),
                  const AppGap.v12(),
                  AppButton.secondary(
                    text: 'Trigger FullScreen Loader overlay (2s)',
                    onPressed: () async {
                      setState(() => _isLoadingFullScreen = true);
                      await Future.delayed(const Duration(milliseconds: 2000));
                      if (mounted) {
                        setState(() => _isLoadingFullScreen = false);
                      }
                    },
                  ),
                ],
              ),
            ),
            const AppGap.v24(),

            // ── Spacing Tokens Showcase ──────────────────────────────────────────
            const AppSectionHeader(title: 'Structured Gap Showcase (AppGap)'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Showing gap increments (v4, v8, v12, v16):', style: AppTypography.labelMedium),
                  const AppGap.v8(),
                  Container(height: 12, color: Colors.blue.withValues(alpha: 0.2)),
                  const AppGap.v4(),
                  Container(height: 12, color: Colors.blue.withValues(alpha: 0.3)),
                  const AppGap.v8(),
                  Container(height: 12, color: Colors.blue.withValues(alpha: 0.4)),
                  const AppGap.v12(),
                  Container(height: 12, color: Colors.blue.withValues(alpha: 0.5)),
                  const AppGap.v16(),
                  Container(height: 12, color: Colors.blue.withValues(alpha: 0.6)),
                ],
              ),
            ),
            const AppGap.v24(),
          ],
        ),
      ),
    );
  }
}
