import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/features/hidden/domain/entities/messaging_setup_state.dart';
import 'package:memovault/features/hidden/controllers/messaging_setup_controller.dart';

class MessagingSetupFlowView extends GetView<MessagingSetupController> {
  const MessagingSetupFlowView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup E2E Identity'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: AppIconButton.secondary(
          icon: Icons.arrow_back_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
          child: Obx(() {
            final state = controller.setupState.value;
            switch (state) {
              case MessagingSetupState.unconfigured:
                return _buildIntroScreen(context, theme);
              case MessagingSetupState.usernameSelected:
                return _buildUsernameScreen(context, theme);
              case MessagingSetupState.seedGenerated:
                return _buildSeedDisplayScreen(context, theme);
              case MessagingSetupState.seedVerified:
                return _buildSeedQuizScreen(context, theme);
              case MessagingSetupState.identityPublished:
                return _buildConfirmationScreen(context, theme);
              case MessagingSetupState.ready:
                return _buildReadyScreen(context, theme);
            }
          }),
        ),
      ),
    );
  }

  // ─── 1. Welcome Intro Screen ──────────────────────────────────────────────
  Widget _buildIntroScreen(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  blurRadius: 32,
                  spreadRadius: 8,
                )
              ],
            ),
            child: Icon(
              Icons.vpn_key_rounded,
              color: theme.colorScheme.primary,
              size: 56,
            ),
          ),
        ),
        const AppGap.v32(),
        Text(
          'Secure messaging not configured',
          textAlign: TextAlign.center,
          style: AppTypography.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const AppGap.v12(),
        Text(
          'Create a zero-knowledge E2EE cryptographic identity. Establish private pseudonym channels completely isolated from your public profile.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65),
            height: 1.5,
          ),
        ),
        const AppGap.v48(),
        AppButton.primary(
          text: 'Setup Messaging',
          icon: Icons.navigate_next_rounded,
          onPressed: () {
            controller.onUserInteraction();
            controller.setupState.value = MessagingSetupState.usernameSelected;
          },
        ),
        const AppGap.v16(),
        AppButton.secondary(
          text: 'Restore Identity From Seed',
          icon: Icons.restore_rounded,
          onPressed: () => _showRestoreBottomSheet(context),
        ),
      ],
    );
  }

  // ─── 2. Username Selection Screen ─────────────────────────────────────────
  Widget _buildUsernameScreen(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose Secure Username',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        const AppGap.v8(),
        Text(
          'Select a unique lowercase pseudonym. This handle is visible on the secure directory. Do not use your real name.',
          style: AppTypography.bodyMedium.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          ),
        ),
        const AppGap.v24(),
        AppTextField(
          controller: controller.usernameController,
          labelText: 'Choose Username',
          hintText: 'e.g. shadow_fox',
          prefix: const Icon(Icons.alternate_email_rounded, size: 20),
          onChanged: controller.onUsernameChanged,
        ),
        const AppGap.v12(),
        Obx(() {
          final feedback = controller.usernameFeedback.value;
          final available = controller.isUsernameAvailable.value;
          final checking = controller.isCheckingUsername.value;

          if (checking) {
            return Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const AppGap.h8(),
                Text(
                  'Checking availability on directory...',
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            );
          }

          if (feedback.isNotEmpty) {
            return Text(
              feedback,
              style: AppTypography.bodySmall.copyWith(
                color: available ? theme.colorScheme.primary : theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            );
          }

          return const SizedBox.shrink();
        }),
        const AppGap.v48(),
        Obx(() {
          final valid = controller.isUsernameAvailable.value;
          return AppButton.primary(
            text: 'Generate Recovery Seed',
            icon: Icons.security_rounded,
            onPressed: valid ? controller.proceedFromUsernameSelection : null,
          );
        }),
      ],
    );
  }

  // ─── 3. Seed Display Screen ───────────────────────────────────────────────
  Widget _buildSeedDisplayScreen(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.primary, size: 24),
            const AppGap.h8(),
            Text(
              'Your Recovery Seed Phrase',
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const AppGap.v8(),
        Text(
          'Write down these 12 words in order and store them offline. Anyone with this phrase can hijack your identity. Plaintext mnemonic is NEVER saved to disk.',
          style: AppTypography.bodyMedium.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          ),
        ),
        const AppGap.v24(),
        Obx(() {
          final revealed = controller.isSeedRevealed.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // 12-Word Grid
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: controller.seedWords.length,
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Center(
                        child: Text(
                          '${index + 1}. ${controller.seedWords[index]}',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (!revealed)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: AppButton.secondary(
                        text: 'Reveal Seed Phrase',
                        icon: Icons.visibility_rounded,
                        onPressed: () {
                          controller.onUserInteraction();
                          controller.isSeedRevealed.value = true;
                        },
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
        const AppGap.v48(),
        Obx(() {
          final revealed = controller.isSeedRevealed.value;
          return AppButton.primary(
            text: 'I Have Copied It Offline',
            icon: Icons.check_circle_outline_rounded,
            onPressed: revealed ? controller.proceedToQuiz : null,
          );
        }),
      ],
    );
  }

  // ─── 4. Seed Positioning Quiz Screen ──────────────────────────────────────
  Widget _buildSeedQuizScreen(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Confirm Recovery Phrase',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        const AppGap.v8(),
        Obx(() {
          final targetIndex = controller.quizPositions[controller.quizIndex.value];
          return Text(
            'To verify you wrote down the seed, please select word #${targetIndex + 1} from your list of recovery options below.',
            style: AppTypography.bodyMedium.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
          );
        }),
        const AppGap.v32(),
        Obx(() {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: controller.quizOptions.length,
            itemBuilder: (context, index) {
              final option = controller.quizOptions[index];
              return AppCard(
                borderColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                onTap: () => controller.selectQuizOption(option),
                child: Center(
                  child: Text(
                    option,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        }),
        const AppGap.v32(),
        Obx(() {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final completed = controller.quizAnswersSelected.contains(index);
              final active = controller.quizIndex.value == index;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completed
                      ? theme.colorScheme.primary
                      : active
                          ? theme.colorScheme.primary.withValues(alpha: 0.3)
                          : theme.dividerColor.withValues(alpha: 0.1),
                ),
              );
            }),
          );
        }),
      ],
    );
  }

  // ─── 5. Pre-Registration Confirmation Card Screen ─────────────────────────
  Widget _buildConfirmationScreen(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s24),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber,
              size: 48,
            ),
          ),
        ),
        const AppGap.v24(),
        Text(
          'Confirm Pseudonym Registration',
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        const AppGap.v12(),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            children: [
              Text(
                'YOUR SECURE PSEUDONYM',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                ),
              ),
              const AppGap.v8(),
              Text(
                '@${controller.username.value}',
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const AppGap.v16(),
        Text(
          'Your BIP-39 recovery seed is successfully verified! Tapping continue will sign your public E2EE key bundle and publish your secure profile to the Firestore directory. Mnemonic phrase will be purged from volatile memory.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65),
            height: 1.45,
          ),
        ),
        const AppGap.v48(),
        AppButton.primary(
          text: 'Register & Activate Identity',
          icon: Icons.verified_user_rounded,
          onPressed: controller.registerAndPublishIdentity,
        ),
      ],
    );
  }

  // ─── 6. Ready Screen ──────────────────────────────────────────────────────
  Widget _buildReadyScreen(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_rounded,
              color: theme.colorScheme.primary,
              size: 56,
            ),
          ),
        ),
        const AppGap.v24(),
        Text(
          'Identity Successfully Created!',
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        const AppGap.v8(),
        Text(
          'Your zero-knowledge secure E2EE profile is active and discoverable at:',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          ),
        ),
        const AppGap.v16(),
        Text(
          '@${controller.username.value}',
          textAlign: TextAlign.center,
          style: AppTypography.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const AppGap.v48(),
        AppButton.primary(
          text: 'Enter Secure Chats',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: () {
            controller.onUserInteraction();
            Navigator.of(context).pop(); // Pops setup flow
          },
        ),
      ],
    );
  }

  // ─── Restore Seed Bottom Sheet ────────────────────────────────────────────
  void _showRestoreBottomSheet(BuildContext context) {
    final textController = TextEditingController();
    AppBottomSheet.show(
      context,
      title: 'Restore Secure Identity',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter your 12-word BIP-39 mnemonic seed phrase in order, separated by a single space.',
            style: AppTypography.bodyMedium,
          ),
          const AppGap.v16(),
          AppTextField(
            controller: textController,
            labelText: 'Mnemonic Seed Phrase',
            hintText: 'e.g. apple river table...',
            prefix: const Icon(Icons.history_rounded, size: 20),
          ),
          const AppGap.v24(),
          AppButton.primary(
            text: 'Verify & Restore',
            icon: Icons.restore_rounded,
            onPressed: () {
              final words = textController.text.trim();
              if (words.isNotEmpty) {
                Navigator.of(context).pop();
                controller.restoreIdentityFromMnemonic(words);
              }
            },
          ),
          const AppGap.v16(),
        ],
      ),
    );
  }
}
