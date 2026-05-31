import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/design_system/feedback/app_snack_bar.dart';
import 'package:memovault/domain/messaging/message_entity.dart';
import 'package:memovault/domain/messaging/participant_entity.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/features/hidden/domain/entities/messaging_setup_state.dart';
import 'package:memovault/features/messaging/services/signal_session_manager.dart';
import 'package:uuid/uuid.dart';

class HiddenChatController extends GetxController {
  final MessagingRepository _messagingRepository;
  final HiddenSessionService _sessionService;
  final String conversationId;
  final _uuid = const Uuid();

  HiddenChatController(this._messagingRepository, this._sessionService, this.conversationId);

  final RxList<MessageEntity> messages = <MessageEntity>[].obs;
  final Rxn<ParticipantEntity> otherParticipant = Rxn<ParticipantEntity>();
  final RxBool isLoading = true.obs;

  StreamSubscription<List<MessageEntity>>? _messagesSubscription;
  final textController = TextEditingController();
  final scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    bootstrapChat();
  }

  Future<void> bootstrapChat() async {
    try {
      // 1. Fetch conversation details to find participant
      final conv = await _messagingRepository.getConversationById(conversationId);
      if (conv != null) {
        final p = await _messagingRepository.getParticipantById(conv.participantId);
        otherParticipant.value = p;

        // Reset unread count since we are opening the thread
        await _messagingRepository.updateConversationUnreadCount(conversationId, 0);
      }

      // 2. Watch messages
      _messagesSubscription?.cancel();
      _messagesSubscription = _messagingRepository
          .watchMessagesForConversation(conversationId)
          .listen((data) {
        messages.assignAll(data);
        isLoading.value = false;
        _scrollToBottom();
      });
    } catch (e) {
      isLoading.value = false;
      AppSnackBar.error(
        title: 'Error',
        message: 'Could not load secure chat: $e',
      );
    }
  }

  @override
  void onClose() {
    _messagesSubscription?.cancel();
    textController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  void onUserInteraction() {
    _sessionService.resetInactivityTimer();
  }

  void _scrollToBottom() {
    if (scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> sendMessage() async {
    onUserInteraction();
    final text = textController.text.trim();
    if (text.isEmpty) return;

    // Contact Blocking Gate (Point 5)
    final conv = await _messagingRepository.getConversationById(conversationId);
    if (conv != null && conv.isBlocked) {
      AppSnackBar.error(
        title: 'Blocked Contact',
        message: 'Cannot send messages to a blocked contact.',
      );
      return;
    }

    // Safety Warning / Trust Revoked Gate (Point 2)
    final p = otherParticipant.value;
    if (p != null && p.trustState == 'revoked') {
      AppSnackBar.error(
        title: 'Security Warning',
        message: 'Cannot send messages while the identity trust state is revoked.',
      );
      return;
    }

    textController.clear();

    final msgId = 'm_${_uuid.v4()}';
    final now = DateTime.now().toUtc();

    final msg = MessageEntity(
      id: msgId,
      conversationId: conversationId,
      senderId: 'me', // Default ID for current local user in offline-first UI
      encryptedContent: text, // Plaintext stored in physical local DB for Phase 4.3 Offline
      nonce: 'nonce_${_uuid.v4().substring(0, 8)}',
      state: 'pending',
      createdAt: now,
    );

    try {
      await _messagingRepository.insertMessage(msg);
      await _messagingRepository.updateConversationLastMessage(conversationId, msgId);
      _scrollToBottom();

      final identityService = Get.find<MessagingIdentityService>();
      final isSecureReady = await identityService.getSetupState() == MessagingSetupState.ready;

      if (isSecureReady && p != null) {
        final sessionManager = Get.find<SignalSessionManager>();
        await sessionManager.sendSecureMessage(
          targetUid: p.id,
          plaintext: text,
        );
        await _messagingRepository.updateMessageState(msgId, 'sent');
      } else {
        // Fallback for local-only mock mode
        await _messagingRepository.updateMessageState(msgId, 'sent');
      }
    } catch (e) {
      await _messagingRepository.updateMessageState(msgId, 'failed');
      AppSnackBar.error(
        title: 'Error Sending',
        message: 'Failed to send E2E message: $e',
      );
    }
  }

  Future<void> deleteMessage(String id) async {
    onUserInteraction();
    try {
      await _messagingRepository.deleteMessage(id);
      AppSnackBar.success(
        title: 'Deleted',
        message: 'Message permanently removed from vault.',
      );
    } catch (e) {
      AppSnackBar.error(
        title: 'Error',
        message: 'Could not delete message: $e',
      );
    }
  }
}
