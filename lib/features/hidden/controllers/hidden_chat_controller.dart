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
import 'package:memovault/features/messaging/services/typing_and_presence_service.dart';
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

  // Presence & Typing Status
  final RxBool isOtherOnline = false.obs;
  final RxBool isOtherTyping = false.obs;
  StreamSubscription? _presenceSubscription;
  StreamSubscription? _typingSubscription;

  Timer? _typingTimer;
  bool _isCurrentlyTyping = false;

  // Search Thread
  final RxBool isSearchActive = false.obs;
  final RxString searchQuery = ''.obs;
  final searchController = TextEditingController();
  final RxList<MessageEntity> searchResults = <MessageEntity>[].obs;
  final RxBool showJumpButton = false.obs;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(() {
      if (scrollController.hasClients) {
        final offset = scrollController.offset;
        final maxScroll = scrollController.position.maxScrollExtent;
        showJumpButton.value = (maxScroll - offset) > 300;
      }
    });
    bootstrapChat();
  }

  Future<void> bootstrapChat() async {
    try {
      // 1. Fetch conversation details to find participant
      final conv = await _messagingRepository.getConversationById(conversationId);
      if (conv != null) {
        final p = await _messagingRepository.getParticipantById(conv.participantId);
        otherParticipant.value = p;

        // Restore draft if any
        if (conv.draft != null && conv.draft!.isNotEmpty) {
          textController.text = conv.draft!;
        }

        // Listen to presence and typing if participant resolved
        if (p != null) {
          final presenceService = Get.find<TypingAndPresenceService>();
          _presenceSubscription?.cancel();
          _presenceSubscription = presenceService.watchUserPresence(p.id).listen((online) {
            isOtherOnline.value = online;
          });

          _typingSubscription?.cancel();
          _typingSubscription = presenceService.watchTypingUsers(conversationId).listen((typingUids) {
            isOtherTyping.value = typingUids.contains(p.id);
          });
        }

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
        _sendReadReceiptsForIncomingMessages(data);
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
    _presenceSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingTimer?.cancel();
    
    // Save draft text on exit
    final draftText = textController.text.trim();
    _messagingRepository.updateConversationDraft(conversationId, draftText.isEmpty ? null : draftText);

    if (_isCurrentlyTyping) {
      Get.find<TypingAndPresenceService>().setTypingState(conversationId, false);
    }

    textController.dispose();
    scrollController.dispose();
    searchController.dispose();
    super.onClose();
  }

  void onUserInteraction() {
    _sessionService.resetInactivityTimer();
  }

  void handleTextChanged(String val) {
    onUserInteraction();
    if (val.trim().isEmpty) {
      if (_isCurrentlyTyping) {
        _isCurrentlyTyping = false;
        Get.find<TypingAndPresenceService>().setTypingState(conversationId, false);
      }
      _typingTimer?.cancel();
      return;
    }

    if (!_isCurrentlyTyping) {
      _isCurrentlyTyping = true;
      Get.find<TypingAndPresenceService>().setTypingState(conversationId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), () {
      if (_isCurrentlyTyping) {
        _isCurrentlyTyping = false;
        Get.find<TypingAndPresenceService>().setTypingState(conversationId, false);
      }
    });
  }

  Future<void> runSearch(String query) async {
    searchQuery.value = query;
    if (query.trim().isEmpty) {
      searchResults.clear();
      return;
    }
    final results = await _messagingRepository.searchLocalMessages(query, isHidden: true);
    searchResults.assignAll(results.where((m) => m.conversationId == conversationId).toList());
  }

  Future<void> _sendReadReceiptsForIncomingMessages(List<MessageEntity> messageList) async {
    final other = otherParticipant.value;
    if (other == null) return;
    final presenceService = Get.find<TypingAndPresenceService>();
    for (final msg in messageList) {
      if (msg.senderId != 'me' && msg.state != 'read') {
        await presenceService.sendReadReceipt(msg.id, other.id);
      }
    }
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
    
    // Clear typing state immediately
    if (_isCurrentlyTyping) {
      _isCurrentlyTyping = false;
      Get.find<TypingAndPresenceService>().setTypingState(conversationId, false);
      _typingTimer?.cancel();
    }

    final msgId = 'm_${_uuid.v4()}';
    final now = DateTime.now().toUtc();

    final msg = MessageEntity(
      id: msgId,
      conversationId: conversationId,
      senderId: 'me', // Default ID for current local user in offline-first UI
      encryptedContent: text, // Plaintext stored in physical local DB for Phase 4.3 Offline
      nonce: 'nonce_${_uuid.v4().substring(0, 8)}',
      state: 'queued',
      createdAt: now,
    );

    try {
      await _messagingRepository.insertMessage(msg);
      await _messagingRepository.updateConversationLastMessage(conversationId, msgId);
      _scrollToBottom();

      // Clear draft in DB
      await _messagingRepository.updateConversationDraft(conversationId, null);

      // Move to sending
      await _messagingRepository.updateMessageState(msgId, 'sending');

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

  Future<void> clearHistory() async {
    onUserInteraction();
    try {
      await _messagingRepository.clearChatHistory(conversationId);
      AppSnackBar.success(
        title: 'Cleared',
        message: 'Chat history cleared.',
      );
    } catch (e) {
      AppSnackBar.error(
        title: 'Error',
        message: 'Could not clear history: $e',
      );
    }
  }
}
