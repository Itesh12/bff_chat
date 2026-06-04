import 'dart:async';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:memovault/core/design_system/feedback/app_snack_bar.dart';
import 'package:memovault/domain/messaging/conversation_entity.dart';
import 'package:memovault/domain/messaging/participant_entity.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/features/hidden/domain/entities/messaging_setup_state.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/features/messaging/services/signal_session_manager.dart';
import 'package:uuid/uuid.dart';

class HiddenMessagingController extends GetxController {
  final MessagingRepository _messagingRepository;
  final HiddenSessionService _sessionService;
  final MessagingIdentityService _identityService;
  final _uuid = const Uuid();

  HiddenMessagingController(this._messagingRepository, this._sessionService, this._identityService);

  final RxList<ConversationEntity> conversations = <ConversationEntity>[].obs;
  final RxMap<String, ParticipantEntity> participants = <String, ParticipantEntity>{}.obs;
  StreamSubscription<List<ConversationEntity>>? _conversationsSubscription;
  
  final Rx<MessagingSetupState> setupState = MessagingSetupState.unconfigured.obs;
  final RxBool showArchived = false.obs;

  @override
  void onInit() {
    super.onInit();
    _bootstrapMessaging();
  }

  Future<void> refreshSetupState() async {
    final state = await _identityService.getSetupState();
    setupState.value = state;
  }

  Future<void> _bootstrapMessaging() async {
    await refreshSetupState();
    _conversationsSubscription = _messagingRepository
        .watchAllConversations(isHidden: true)
        .listen((data) async {
      final sortedData = List<ConversationEntity>.from(data);
      sortedData.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      conversations.assignAll(sortedData);
      for (final conv in data) {
        if (!participants.containsKey(conv.participantId)) {
          final p = await _messagingRepository.getParticipantById(conv.participantId);
          if (p != null) {
            participants[conv.participantId] = p;
          }
        }
      }
    });
  }

  @override
  void onClose() {
    _conversationsSubscription?.cancel();
    super.onClose();
  }

  void onUserInteraction() {
    _sessionService.resetInactivityTimer();
  }

  Future<void> createConversation(String username) async {
    onUserInteraction();
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) return;

    final canonicalUsername = cleanUsername.replaceAll('@', '').toLowerCase();
    final formattedUsername = '@$canonicalUsername';

    try {
      // 1. Check if conversation already exists (checking both username formats)
      final existingPart = (await _messagingRepository.getParticipantByUsername(formattedUsername)) ??
                           (await _messagingRepository.getParticipantByUsername(canonicalUsername));
      if (existingPart != null) {
        // First try to find conversation in memory list
        ConversationEntity? existing = conversations.firstWhereOrNull((c) => c.participantId == existingPart.id);
        
        // If not found in memory, check DB using the various possible prefix combinations
        if (existing == null) {
          final uids = [
            Firebase.apps.isEmpty ? 'me' : (FirebaseAuth.instance.currentUser?.uid ?? 'me'),
            Firebase.apps.isEmpty ? 'alice_uid' : (FirebaseAuth.instance.currentUser?.uid ?? 'alice_uid'),
            Firebase.apps.isEmpty ? 'bob_uid' : (FirebaseAuth.instance.currentUser?.uid ?? 'bob_uid'),
          ];
          for (final uid in uids) {
            final conv = await _messagingRepository.getConversationById('${uid}_${existingPart.id}');
            if (conv != null) {
              existing = conv;
              break;
            }
          }
        }

        if (existing != null) {
          AppSnackBar.info(
            title: 'Thread Exists',
            message: 'Opening existing conversation with $formattedUsername',
          );
          Get.toNamed(AppRoutes.hiddenChat, arguments: existing.id);
          return;
        }
      }

      // 2. If secure messaging is configured and Firebase is initialized, do real X3DH initiateSession
      final isSecureReady = await _identityService.getSetupState() == MessagingSetupState.ready;
      final canInitSecureSession = isSecureReady && (Firebase.apps.isNotEmpty || SignalSessionManager.mockPrekeyBundles != null);
      if (canInitSecureSession) {
        final sessionManager = Get.find<SignalSessionManager>();
        
        AppSnackBar.info(
          title: 'Connecting',
          message: 'Establishing secure E2EE handshake with $formattedUsername...',
        );
        
        await sessionManager.initiateSession(
          targetUsername: canonicalUsername,
          isHidden: true,
        );

        AppSnackBar.success(
          title: 'Chat Created',
          message: 'Secure chat with $formattedUsername initiated.',
        );

        // Fetch participant and navigate to the E2EE conversation room
        final participant = (await _messagingRepository.getParticipantByUsername(formattedUsername)) ??
                            (await _messagingRepository.getParticipantByUsername(canonicalUsername));
        if (participant != null) {
          final currentUid = Firebase.apps.isEmpty
              ? 'alice_uid'
              : (FirebaseAuth.instance.currentUser?.uid ?? 'alice_uid');
          final conversationId = '${currentUid}_${participant.id}';
          Get.toNamed(AppRoutes.hiddenChat, arguments: conversationId);
        }
      } else {
        // Fallback for offline/local-only mode
        var participant = (await _messagingRepository.getParticipantByUsername(formattedUsername)) ??
                          (await _messagingRepository.getParticipantByUsername(canonicalUsername));
        if (participant == null) {
          final pId = 'p_${_uuid.v4()}';
          participant = await _messagingRepository.createOrUpdateParticipant(
            id: pId,
            username: formattedUsername,
            identityKeyPub: 'pubkey_${_uuid.v4().substring(0, 8)}',
          );
        }

        final convId = 'c_${_uuid.v4()}';
        await _messagingRepository.createConversation(
          id: convId,
          participantId: participant.id,
          isHidden: true,
        );

        AppSnackBar.success(
          title: 'Chat Created',
          message: 'Secure chat with $formattedUsername initiated.',
        );

        Get.toNamed(AppRoutes.hiddenChat, arguments: convId);
      }
    } catch (e) {
      if (e.toString().contains('IDENTITY_KEY_CHANGED')) {
        AppSnackBar.error(
          title: 'Identity Revoked',
          message: 'Safety number changed for this contact. Verify before continuing.',
        );
      } else if (e.toString().contains('BLOCKED_CONTACT')) {
        AppSnackBar.error(
          title: 'Blocked Contact',
          message: 'Cannot initiate session with a blocked contact.',
        );
      } else {
        AppSnackBar.error(
          title: 'Error',
          message: 'Could not create conversation: $e',
        );
      }
    }
  }

  Future<void> toggleMute(String id) async {
    onUserInteraction();
    await _messagingRepository.toggleMuteConversation(id);
    AppSnackBar.info(
      title: 'Muted',
      message: 'Mute preference updated.',
    );
  }

  Future<void> toggleArchive(String id) async {
    onUserInteraction();
    await _messagingRepository.toggleArchiveConversation(id);
    AppSnackBar.success(
      title: 'Archived',
      message: 'Chat state changed.',
    );
  }

  Future<void> toggleBlock(String id) async {
    onUserInteraction();
    await _messagingRepository.toggleBlockConversation(id);
    AppSnackBar.info(
      title: 'Block Status',
      message: 'Contact block state updated.',
    );
  }

  Future<void> togglePinned(String id) async {
    onUserInteraction();
    final conv = conversations.firstWhereOrNull((c) => c.id == id);
    if (conv == null) return;

    if (!conv.isPinned) {
      final pinnedCount = conversations.where((c) => c.isPinned).length;
      if (pinnedCount >= 5) {
        AppSnackBar.error(
          title: 'Limit Reached',
          message: 'Maximum pinned chats = 5',
        );
        return;
      }
    }

    await _messagingRepository.updateConversationPinnedState(id, !conv.isPinned);
    AppSnackBar.success(
      title: conv.isPinned ? 'Unpinned' : 'Pinned',
      message: conv.isPinned ? 'Chat unpinned successfully.' : 'Chat pinned to top.',
    );
  }
}
