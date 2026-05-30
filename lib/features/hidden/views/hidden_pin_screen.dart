import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/features/hidden/controllers/hidden_activation_controller.dart';

class HiddenPinScreen extends GetView<HiddenActivationController> {
  const HiddenPinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const AppGap.v48(),
              Icon(
                Icons.lock_outline_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const AppGap.v24(),
              Obx(() {
                String title;
                String subtitle;
                if (!controller.isSetup.value) {
                  if (controller.isConfirmingMode.value) {
                    title = 'Confirm Vault PIN';
                    subtitle = 'Re-enter your 4-digit PIN to confirm';
                  } else {
                    title = 'Create Vault PIN';
                    subtitle = 'Choose a secure 4-digit PIN';
                  }
                } else {
                  title = 'Vault Locked';
                  subtitle = 'Enter PIN to unlock hidden notes';
                }

                return Column(
                  children: [
                    Text(
                      title,
                      style: AppTypography.displayLarge.copyWith(
                        color: theme.textTheme.displayLarge?.color,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const AppGap.v8(),
                    Text(
                      subtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              }),
              const AppGap.v32(),

              // PIN display indicators
              Center(
                child: Obx(() {
                  final text = controller.isConfirmingMode.value
                      ? controller.confirmInput.value
                      : controller.pinInput.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      4,
                      (index) {
                        final hasDigit = index < text.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasDigit
                                ? theme.colorScheme.primary
                                : (theme.brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[300]),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
              const AppGap.v16(),

              // Error Message
              Center(
                child: Obx(() {
                  final err = controller.errorMessage.value;
                  if (err.isEmpty) return const AppGap.v24();
                  return Text(
                    err,
                    style: AppTypography.bodyMedium.copyWith(
                      color: context.colors.error,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  );
                }),
              ),
              const AppGap.v24(),

              // Keypad
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int row = 0; row < 3; row++) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (int col = 1; col <= 3; col++)
                                _buildKeypadButton(context, '${row * 3 + col}'),
                            ],
                          ),
                          const AppGap.v12(),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Clear Button
                            _buildSpecialKeypadButton(
                              context,
                              icon: Icons.clear_all_rounded,
                              onPressed: controller.clear,
                            ),
                            _buildKeypadButton(context, '0'),
                            // Backspace Button
                            _buildSpecialKeypadButton(
                              context,
                              icon: Icons.backspace_outlined,
                              onPressed: controller.backspace,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const AppGap.v16(),

              // Submit and Wipe Buttons
              Obx(() {
                final hasInput = controller.isConfirmingMode.value
                    ? controller.confirmInput.value.length >= 4
                    : controller.pinInput.value.length >= 4;

                return AppButton.primary(
                  text: controller.isConfirmingMode.value ? 'Confirm PIN' : 'Submit PIN',
                  onPressed: hasInput ? controller.submit : null,
                );
              }),
              const AppGap.v12(),

              Obx(() {
                if (controller.isSetup.value) {
                  return AppButton.text(
                    text: 'Forgot PIN? Reset Vault',
                    onPressed: () => _showPanicWipeConfirmation(context),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              }),
              const AppGap.v16(),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildKeypadButton(BuildContext context, String digit) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.grey[900] : Colors.grey[100],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.max,
          onTap: () => controller.appendDigit(digit),
          child: Center(
            child: Text(
              digit,
              style: AppTypography.headlineMedium.copyWith(
                color: theme.textTheme.headlineMedium?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKeypadButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.grey[900] : Colors.grey[100],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.max,
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              color: theme.textTheme.titleMedium?.color,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  void _showPanicWipeConfirmation(BuildContext context) {
    AppDialog.delete(
      context,
      title: 'Reset Vault',
      message: 'This will permanently destroy all hidden notes and reset the vault. This action cannot be undone. Do you wish to continue?',
      deleteLabel: 'Wipe & Reset',
      cancelLabel: 'Cancel',
      onDelete: () async {
        await controller.triggerPanicWipe();
      },
    );
  }
}
