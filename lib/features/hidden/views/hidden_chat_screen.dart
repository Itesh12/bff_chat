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

class ChatListItem {
  final String? dateHeader;
  final MessageEntity? message;
  final bool showAvatarAndMeta;
  final bool isConsecutive;

  ChatListItem({
    this.dateHeader,
    this.message,
    this.showAvatarAndMeta = true,
    this.isConsecutive = false,
  });
}

class HiddenChatScreen extends StatelessWidget {
  const HiddenChatScreen({super.key});

  List<ChatListItem> _buildChatListItems(List<MessageEntity> messages) {
    final list = <ChatListItem>[];
    if (messages.isEmpty) return list;

    DateTime? lastDate;
    MessageEntity? lastMsg;

    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final msgDate = msg.createdAt.toLocal();

      // 1. Date Separator Check
      if (lastDate == null ||
          msgDate.year != lastDate.year ||
          msgDate.month != lastDate.month ||
          msgDate.day != lastDate.day) {
        lastDate = msgDate;

        String dateStr = '';
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final checkDate = DateTime(msgDate.year, msgDate.month, msgDate.day);

        if (checkDate == today) {
          dateStr = 'Today';
        } else if (checkDate == yesterday) {
          dateStr = 'Yesterday';
        } else {
          dateStr = DateFormat('MMMM d, yyyy').format(msgDate);
        }

        list.add(ChatListItem(dateHeader: dateStr));
      }

      // 2. Message Grouping Check
      bool showAvatarAndMeta = true;
      bool isConsecutive = false;

      if (lastMsg != null && lastMsg.senderId == msg.senderId) {
        final diff = msg.createdAt.difference(lastMsg.createdAt).inMinutes;
        if (diff < 2) {
          showAvatarAndMeta = false;
          isConsecutive = true;
        }
      }

      list.add(ChatListItem(
        message: msg,
        showAvatarAndMeta: showAvatarAndMeta,
        isConsecutive: isConsecutive,
      ));

      lastMsg = msg;
    }

    return list;
  }

  void _showClearConfirmDialog(BuildContext context, HiddenChatController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History?'),
        content: const Text(
          'Are you sure you want to clear all messages in this conversation? Messages will be soft-deleted to preserve compliance audit trails.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.clearHistory();
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String conversationId = Get.arguments as String;
    final theme = Theme.of(context);

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
            Get.delete<HiddenChatController>(tag: conversationId);
          }
        },
        child: AppScaffold(
          title: null,
          body: Column(
            children: [
              // Custom Premium secure App Bar
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                  child: Obx(() {
                    final isSearching = controller.isSearchActive.value;
                    if (isSearching) {
                      return Row(
                        children: [
                          AppIconButton.secondary(
                            icon: Icons.close_rounded,
                            tooltip: 'Close Search',
                            onPressed: () {
                              controller.onUserInteraction();
                              controller.isSearchActive.value = false;
                              controller.searchQuery.value = '';
                              controller.searchController.clear();
                              controller.searchResults.clear();
                            },
                          ),
                          const AppGap.h8(),
                          Expanded(
                            child: AppTextField(
                              controller: controller.searchController,
                              hintText: 'Search in conversation...',
                              onChanged: controller.runSearch,
                              autofocus: true,
                            ),
                          ),
                        ],
                      );
                    }

                    final other = controller.otherParticipant.value;
                    final otherOnline = controller.isOtherOnline.value;
                    final otherTyping = controller.isOtherTyping.value;

                    String subtitle = 'Offline';
                    if (otherTyping) {
                      subtitle = 'typing...';
                    } else if (otherOnline) {
                      subtitle = 'Online';
                    } else {
                      subtitle = 'Secure Chat';
                    }

                    return Row(
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
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              other != null && other.displayName.isNotEmpty
                                  ? other.displayName.replaceAll('@', '').substring(0, 1).toUpperCase()
                                  : (other?.username != null && other!.username.isNotEmpty)
                                      ? other.username.replaceAll('@', '').substring(0, 1).toUpperCase()
                                      : 'C',
                              style: AppTypography.bodyLarge.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const AppGap.h12(),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (other != null && other.displayName.isNotEmpty)
                                    ? other.displayName
                                    : (other?.username ?? 'Secure Chat'),
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: AppTypography.bodySmall.copyWith(
                                  color: otherTyping
                                      ? Colors.green
                                      : otherOnline
                                          ? theme.colorScheme.primary
                                          : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppIconButton.secondary(
                          icon: Icons.search_rounded,
                          tooltip: 'Search Messages',
                          onPressed: () {
                            controller.onUserInteraction();
                            controller.isSearchActive.value = true;
                          },
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded, color: theme.iconTheme.color?.withValues(alpha: 0.8)),
                          onSelected: (val) {
                            if (val == 'clear') {
                              _showClearConfirmDialog(context, controller);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'clear',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 20),
                                  AppGap.h8(),
                                  Text('Clear Chat History', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ),
              ),
              const Divider(height: 1, thickness: 0.5),

              // Messages area
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(child: AppLoading.medium());
                  }

                  final displayMessages = controller.isSearchActive.value && controller.searchQuery.value.isNotEmpty
                      ? controller.searchResults
                      : controller.messages;

                  if (displayMessages.isEmpty) {
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
                            controller.isSearchActive.value ? 'No Matches Found' : 'No Messages Yet',
                            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const AppGap.v8(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
                            child: Text(
                              controller.isSearchActive.value
                                  ? 'Try adjusting your search query to find local messages.'
                                  : 'Your messages are secured locally with physical database isolation and AES key enclaves.',
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

                  final listItems = _buildChatListItems(displayMessages);

                  return Stack(
                    children: [
                      ListView.builder(
                        controller: controller.scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
                        itemCount: listItems.length,
                        itemBuilder: (context, index) {
                          final item = listItems[index];
                          if (item.dateHeader != null) {
                            return _buildDateSeparator(context, item.dateHeader!);
                          } else {
                            final msg = item.message!;
                            final isMe = msg.senderId == 'me';
                            return _buildMessageBubble(
                              context: context,
                              controller: controller,
                              msg: msg,
                              isMe: isMe,
                              showAvatarAndMeta: item.showAvatarAndMeta,
                              isConsecutive: item.isConsecutive,
                            );
                          }
                        },
                      ),
                      _buildJumpToLatestButton(context, controller),
                    ],
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
                                    onChanged: controller.handleTextChanged,
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

  Widget _buildDateSeparator(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.05),
            ),
          ),
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJumpToLatestButton(BuildContext context, HiddenChatController controller) {
    final theme = Theme.of(context);
    return Obx(() {
      if (!controller.showJumpButton.value) {
        return const SizedBox.shrink();
      }
      return Positioned(
        bottom: 16,
        right: 16,
        child: FloatingActionButton.small(
          onPressed: () {
            controller.onUserInteraction();
            controller.scrollController.animateTo(
              controller.scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          },
          backgroundColor: theme.colorScheme.primary,
          child: const Icon(Icons.arrow_downward_rounded, color: Colors.white),
        ),
      );
    });
  }

  Widget _buildMessageStatusIndicator(BuildContext context, String state) {
    final theme = Theme.of(context);
    switch (state) {
      case 'queued':
      case 'sending':
        return Icon(
          Icons.access_time_rounded,
          size: 11,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
        );
      case 'sent':
        return Icon(
          Icons.done_rounded,
          size: 12,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
        );
      case 'delivered':
        return Icon(
          Icons.done_all_rounded,
          size: 12,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
        );
      case 'read':
        return Icon(
          Icons.done_all_rounded,
          size: 12,
          color: theme.colorScheme.primary,
        );
      case 'failed':
        return const Icon(
          Icons.error_outline_rounded,
          size: 12,
          color: Colors.red,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMessageBubble({
    required BuildContext context,
    required HiddenChatController controller,
    required MessageEntity msg,
    required bool isMe,
    required bool showAvatarAndMeta,
    required bool isConsecutive,
  }) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('h:mm a').format(msg.createdAt.toLocal());

    return Padding(
      padding: EdgeInsets.only(
        top: isConsecutive ? 2.0 : 8.0,
        bottom: 2.0,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe && showAvatarAndMeta) ...[
                  Obx(() {
                    final other = controller.otherParticipant.value;
                    final initials = (other != null && other.displayName.isNotEmpty)
                        ? other.displayName.replaceAll('@', '').substring(0, 1).toUpperCase()
                        : (other?.username != null && other!.username.isNotEmpty)
                            ? other.username.replaceAll('@', '').substring(0, 1).toUpperCase()
                            : 'C';
                    return Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 8, bottom: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    );
                  }),
                ] else if (!isMe) ...[
                  const SizedBox(width: 32),
                ],
                GestureDetector(
                  onLongPress: () => _showBubbleMenu(context, controller, msg),
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 10.0),
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
                        bottomLeft: Radius.circular(isMe ? 16 : (showAvatarAndMeta ? 4 : 16)),
                        bottomRight: Radius.circular(isMe ? (showAvatarAndMeta ? 4 : 16) : 16),
                      ),
                      border: isMe
                          ? null
                          : Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.08),
                            ),
                    ),
                    child: Text(
                      msg.encryptedContent,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isMe ? Colors.white : theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (!isConsecutive) ...[
              const SizedBox(height: 2),
              Padding(
                padding: EdgeInsets.only(
                  left: isMe ? 4.0 : 36.0,
                  right: isMe ? 4.0 : 4.0,
                ),
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
                      _buildMessageStatusIndicator(context, msg.state),
                    ],
                  ],
                ),
              ),
            ],
          ],
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
