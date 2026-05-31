import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/domain/messaging/message_entity.dart';
import 'package:memovault/domain/messaging/participant_entity.dart';
import 'package:memovault/features/hidden/controllers/hidden_chat_controller.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';
import 'package:memovault/features/messaging/services/signal_session_manager.dart';
import 'package:intl/intl.dart';

class HiddenChatScreen extends StatelessWidget {
  const HiddenChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String conversationId = Get.arguments as String;
    final theme = Theme.of(context);

    // Dynamic clean dependency injection per chat thread
    final controller = Get.put(
      HiddenChatController(
        Get.find<MessagingRepository>(),
        Get.find<HiddenSessionService>(),
        conversationId,
      ),
      tag: conversationId,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: controller.onUserInteraction,
      onPanDown: (_) => controller.onUserInteraction(),
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            // Clean up the unique dynamic controller instance when navigating back
            Get.delete<HiddenChatController>(tag: conversationId);
          }
        },
        child: AppScaffold(
          // title is null to suppress default AppBar rendering, allowing us to build a custom premium nav bar
          title: null,
          body: Column(
            children: [
              // Custom Premium secure App Bar
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                  child: Row(
                    children: [
                      AppIconButton.secondary(
                        icon: Icons.arrow_back_ios_new_rounded,
                        tooltip: 'Back',
                        onPressed: () {
                          Get.delete<HiddenChatController>(tag: conversationId);
                          Get.back();
                        },
                      ),
                      const AppGap.h8(),
                      Expanded(
                        child: Obx(() {
                          final other = controller.otherParticipant.value;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Text('🔒 ', style: TextStyle(fontSize: 14)),
                                  Expanded(
                                    child: Text(
                                      other?.username ?? 'Secure Chat',
                                      style: AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'End-to-End Encrypted',
                                style: AppTypography.bodySmall.copyWith(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 0.5),

              // Messages area
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(child: AppLoading.medium());
                  }

                  if (controller.messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.s16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_person_rounded,
                              size: 40,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const AppGap.v16(),
                          Text(
                            'No Messages Yet',
                            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const AppGap.v8(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
                            child: Text(
                              'Your messages are secured locally with physical database isolation and AES key enclaves.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium.copyWith(
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: controller.scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
                    itemCount: controller.messages.length,
                    itemBuilder: (context, index) {
                      final msg = controller.messages[index];
                      final isMe = msg.senderId == 'me';
                      return _buildMessageBubble(context, controller, msg, isMe);
                    },
                  );
                }),
              ),

              // Chat Input row / Safety Warning (Obx wrapped)
              Obx(() {
                final other = controller.otherParticipant.value;
                if (other != null && other.trustState == 'revoked') {
                  return _buildSafetyWarningCard(context, other);
                }

                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: theme.dividerColor.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                const AppGap.h16(),
                                Expanded(
                                  child: TextField(
                                    controller: controller.textController,
                                    onChanged: (_) => controller.onUserInteraction(),
                                    style: AppTypography.bodyMedium,
                                    decoration: const InputDecoration(
                                      hintText: 'Type secure message...',
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    maxLines: 4,
                                    minLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const AppGap.h8(),
                        GestureDetector(
                          onTap: controller.sendMessage,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyWarningCard(BuildContext context, ParticipantEntity other) {
    final theme = Theme.of(context);
    final controller = Get.find<HiddenChatController>(tag: Get.arguments as String);

    return Container(
      margin: const EdgeInsets.all(AppSpacing.s16),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.rLarge),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              const AppGap.h12(),
              Expanded(
                child: Text(
                  'Safety Number Changed',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const AppGap.v12(),
          Text(
            'The identity of ${other.username} has changed.\n\nThis may indicate:\n• New device\n• Reinstall\n• Security risk',
            style: AppTypography.bodyMedium,
          ),
          const AppGap.v12(),
          Text(
            'Verify the fingerprint before continuing.',
            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const AppGap.v8(),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.rMedium),
            ),
            child: SelectableText(
              other.identityFingerprint,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const AppGap.v16(),
          AppButton.primary(
            text: 'Verify & Re-approve',
            onPressed: () async {
              try {
                final sessionManager = Get.find<SignalSessionManager>();
                await sessionManager.reapproveParticipantIdentity(other.id);
                await controller.bootstrapChat();
                AppSnackBar.success(
                  title: 'Identity Verified',
                  message: 'New identity fingerprint approved successfully.',
                );
              } catch (e) {
                AppSnackBar.error(
                  title: 'Verification Failed',
                  message: 'Could not re-approve identity: $e',
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    HiddenChatController controller,
    MessageEntity msg,
    bool isMe,
  ) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('h:mm a').format(msg.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: () => _showBubbleMenu(context, controller, msg),
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe ? null : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  border: isMe
                      ? null
                      : Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.08),
                        ),
                ),
                child: Text(
                  msg.encryptedContent, // Display text
                  style: AppTypography.bodyMedium.copyWith(
                    color: isMe ? Colors.white : theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ),
            const AppGap.v4(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 9,
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                    ),
                  ),
                  if (isMe) ...[
                    const AppGap.h4(),
                    Icon(
                      Icons.done_all_rounded,
                      size: 11,
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBubbleMenu(BuildContext context, HiddenChatController controller, MessageEntity msg) {
    AppBottomSheet.show(
      context,
      title: 'Message Options',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
            borderColor: Colors.red.withValues(alpha: 0.3),
            backgroundColor: Colors.red.withValues(alpha: 0.05),
            onTap: () {
              Navigator.pop(context);
              controller.deleteMessage(msg.id);
            },
            child: Row(
              children: [
                const Icon(Icons.delete_forever_rounded, color: Colors.red),
                const AppGap.h16(),
                Expanded(
                  child: Text(
                    'Delete Message',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const AppGap.v16(),
        ],
      ),
    );
  }
}
