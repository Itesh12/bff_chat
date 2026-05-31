import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/features/hidden/controllers/hidden_messaging_controller.dart';
import 'package:intl/intl.dart';

class HiddenChatsView extends StatelessWidget {
  const HiddenChatsView({super.key});

  void showAddChatBottomSheet(BuildContext context, HiddenMessagingController controller) {
    final theme = Theme.of(context);
    final textEditingController = TextEditingController();

    AppBottomSheet.show(
      context,
      title: 'Start Secure Chat',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter the exact pseudonym/username of the contact you want to establish an E2E pairing handshake with.',
            style: AppTypography.bodyMedium.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          const AppGap.v16(),
          AppTextField(
            controller: textEditingController,
            labelText: 'Pseudonym Username',
            hintText: 'e.g. @alice_secure',
            prefix: const Icon(Icons.alternate_email_rounded, size: 20),
          ),
          const AppGap.v24(),
          AppButton.primary(
            text: 'Initialize Handshake',
            icon: Icons.vpn_key_rounded,
            onPressed: () {
              final username = textEditingController.text.trim();
              if (username.isNotEmpty) {
                Navigator.pop(context);
                controller.createConversation(username);
              }
            },
          ),
          const AppGap.v16(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HiddenMessagingController>();
    final theme = Theme.of(context);

    return Obx(() {
      if (controller.conversations.isEmpty) {
        return AppEmptyState(
          customIcon: const Text(
            '💬',
            style: TextStyle(fontSize: 40),
          ),
          title: 'No Secure Chats',
          message: 'Start an end-to-end encrypted conversation with a private pseudonym.',
          ctaLabel: 'Start Chat',
          onCtaTap: () => showAddChatBottomSheet(context, controller),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
        itemCount: controller.conversations.length,
        itemBuilder: (context, index) {
          final conv = controller.conversations[index];
          final participant = controller.participants[conv.participantId];

          final String title = participant?.username ?? 'Connecting...';
          final String subtitle = conv.lastMessageId != null
              ? 'Secure message'
              : 'End-to-End Session Active';

          final timeStr = DateFormat('jm').format(conv.updatedAt.toLocal());

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 14.0),
              onTap: () {
                controller.onUserInteraction();
                Get.toNamed(AppRoutes.hiddenChat, arguments: conv.id);
              },
              child: Row(
                children: [
                  // Glassmorphic secure avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        title.isNotEmpty ? title.replaceAll('@', '').substring(0, 1).toUpperCase() : 'C',
                        style: AppTypography.titleMedium.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const AppGap.h16(),

                  // Text details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              title,
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              timeStr,
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const AppGap.v4(),
                        Row(
                          children: [
                            if (conv.isMuted) ...[
                              Icon(Icons.volume_off_rounded, size: 13, color: theme.iconTheme.color?.withValues(alpha: 0.4)),
                              const AppGap.h4(),
                            ],
                            if (conv.isBlocked) ...[
                              Icon(Icons.block_flipped, size: 12, color: Colors.red.withValues(alpha: 0.6)),
                              const AppGap.h4(),
                            ],
                            Expanded(
                              child: Text(
                                subtitle,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const AppGap.h8(),

                  // Actions menu button
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: theme.iconTheme.color?.withValues(alpha: 0.5)),
                    onSelected: (val) {
                      if (val == 'mute') {
                        controller.toggleMute(conv.id);
                      } else if (val == 'archive') {
                        controller.toggleArchive(conv.id);
                      } else if (val == 'block') {
                        controller.toggleBlock(conv.id);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'mute',
                        child: Row(
                          children: [
                            Icon(conv.isMuted ? Icons.volume_up_rounded : Icons.volume_off_rounded, size: 18),
                            const AppGap.h8(),
                            Text(conv.isMuted ? 'Unmute' : 'Mute'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(conv.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 18),
                            const AppGap.h8(),
                            Text(conv.isArchived ? 'Unarchive' : 'Archive'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(conv.isBlocked ? Icons.check_circle_outline : Icons.block_flipped, size: 18, color: Colors.red),
                            const AppGap.h8(),
                            Text(conv.isBlocked ? 'Unblock' : 'Block Contact', style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}
