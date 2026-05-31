import 'dart:async';
import 'package:get/get.dart';
import 'package:memovault/core/design_system/feedback/app_snack_bar.dart';
import 'package:memovault/domain/messaging/conversation_entity.dart';
import 'package:memovault/domain/messaging/participant_entity.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/features/hidden/domain/entities/messaging_setup_state.dart';
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
      conversations.assignAll(data);
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

    final formattedUsername = cleanUsername.startsWith('@') ? cleanUsername : '@$cleanUsername';

    try {
      // 1. Check if participant exists or create a fake local one for connection exchange
      var participant = await _messagingRepository.getParticipantByUsername(formattedUsername);
      if (participant == null) {
        final pId = 'p_${_uuid.v4()}';
        participant = await _messagingRepository.createOrUpdateParticipant(
          id: pId,
          username: formattedUsername,
          identityKeyPub: 'pubkey_${_uuid.v4().substring(0, 8)}',
        );
      }

      // 2. Check if conversation already exists
      final existing = conversations.firstWhereOrNull((c) => c.participantId == participant!.id);
      if (existing != null) {
        AppSnackBar.info(
          title: 'Thread Exists',
          message: 'Opening existing conversation with $formattedUsername',
        );
        return;
      }

      // 3. Create private conversation
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
    } catch (e) {
      AppSnackBar.error(
        title: 'Error',
        message: 'Could not create conversation: $e',
      );
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
}
