import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/domain/messaging/conversation_entity.dart';
import 'package:memovault/domain/messaging/participant_entity.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';
import 'package:memovault/features/hidden/controllers/hidden_messaging_controller.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/features/hidden/domain/entities/messaging_setup_state.dart';
import 'package:memovault/features/messaging/services/signal_session_manager.dart';

class _FakeMessagingRepository extends Fake implements MessagingRepository {
  final List<ParticipantEntity> participants = [];
  final List<ConversationEntity> conversations = [];

  @override
  Stream<List<ConversationEntity>> watchAllConversations({bool isHidden = false}) {
    return Stream.value(conversations);
  }

  @override
  Future<ParticipantEntity?> getParticipantByUsername(String username) async {
    return participants.firstWhereOrNull((p) => p.username == username);
  }

  @override
  Future<ConversationEntity?> getConversationById(String id) async {
    return conversations.firstWhereOrNull((c) => c.id == id);
  }

  @override
  Future<ParticipantEntity> createOrUpdateParticipant({
    required String id,
    required String username,
    required String identityKeyPub,
    String? trustState,
  }) async {
    final p = ParticipantEntity(
      id: id,
      username: username,
      identityKeyPub: identityKeyPub,
      trustState: trustState ?? 'accepted',
    );
    participants.add(p);
    return p;
  }

  @override
  Future<ConversationEntity> createConversation({
    required String id,
    required String participantId,
    required bool isHidden,
  }) async {
    final c = ConversationEntity(
      id: id,
      participantId: participantId,
      unreadCount: 0,
      isMuted: false,
      isBlocked: false,
      isPinned: false,
      isArchived: false,
      isHidden: isHidden,
      updatedAt: DateTime.now(),
    );
    conversations.add(c);
    return c;
  }
}

class _FakeHiddenSessionService extends Fake implements HiddenSessionService {
  int resetTimerCallCount = 0;

  @override
  void resetInactivityTimer() {
    resetTimerCallCount++;
  }
}

class _FakeMessagingIdentityService extends Fake implements MessagingIdentityService {
  MessagingSetupState setupState = MessagingSetupState.unconfigured;

  @override
  Future<MessagingSetupState> getSetupState() async => setupState;
}

void main() {
  group('HiddenMessagingController Navigation Tests', () {
    late _FakeMessagingRepository repository;
    late _FakeHiddenSessionService sessionService;
    late _FakeMessagingIdentityService identityService;
    late HiddenMessagingController controller;

    setUp(() {
      Get.reset();
      Get.testMode = true;

      repository = _FakeMessagingRepository();
      sessionService = _FakeHiddenSessionService();
      identityService = _FakeMessagingIdentityService();
      controller = HiddenMessagingController(repository, sessionService, identityService);

      Get.put<HiddenMessagingController>(controller);
    });

    tearDown(() {
      Get.reset();
    });

    testWidgets('createConversation navigates directly to chat screen for new offline fallback conversation', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/',
          getPages: [
            GetPage(name: '/', page: () => const SizedBox.shrink()),
            GetPage(name: AppRoutes.hiddenChat, page: () => const SizedBox.shrink()),
          ],
        ),
      );

      identityService.setupState = MessagingSetupState.unconfigured;

      expect(Get.currentRoute, '/');

      await controller.createConversation('@new_user');

      // Check participant and conversation created in repository
      expect(repository.participants.length, 1);
      expect(repository.conversations.length, 1);
      
      final createdConv = repository.conversations.first;
      expect(createdConv.isHidden, true);

      // Check it navigated to the chat screen with correct convId
      expect(Get.currentRoute, AppRoutes.hiddenChat);
      expect(Get.arguments, createdConv.id);
    });

    testWidgets('createConversation navigates directly to existing chat room if thread already exists', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/',
          getPages: [
            GetPage(name: '/', page: () => const SizedBox.shrink()),
            GetPage(name: AppRoutes.hiddenChat, page: () => const SizedBox.shrink()),
          ],
        ),
      );

      identityService.setupState = MessagingSetupState.ready;

      // Seed an existing participant and conversation in repository
      final p = await repository.createOrUpdateParticipant(
        id: 'p_123',
        username: '@bob_secure',
        identityKeyPub: 'pub_123',
      );
      final c = await repository.createConversation(
        id: 'me_p_123',
        participantId: p.id,
        isHidden: true,
      );

      // Add conversation to controller list to simulate active streams
      controller.conversations.add(c);

      expect(Get.currentRoute, '/');

      // Try creating conversation with existing username
      await controller.createConversation('@bob_secure');

      // No new participant or conversation should be created
      expect(repository.participants.length, 1);
      expect(repository.conversations.length, 1);

      // Check it navigated to the existing chat screen with correct convId
      expect(Get.currentRoute, AppRoutes.hiddenChat);
      expect(Get.arguments, 'me_p_123');
    });

    testWidgets('createConversation falls back to local-only offline mode when setupState is ready but Firebase is not initialized and mock bundles are absent', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/',
          getPages: [
            GetPage(name: '/', page: () => const SizedBox.shrink()),
            GetPage(name: AppRoutes.hiddenChat, page: () => const SizedBox.shrink()),
          ],
        ),
      );

      identityService.setupState = MessagingSetupState.ready;
      SignalSessionManager.mockPrekeyBundles = null;

      expect(Get.currentRoute, '/');

      await controller.createConversation('@dev_fallback_user');

      // Check participant and conversation created in repository (offline fallback behavior)
      expect(repository.participants.length, 1);
      expect(repository.conversations.length, 1);
      
      final createdConv = repository.conversations.first;
      expect(createdConv.isHidden, true);

      // Check it navigated to the chat screen with correct convId
      expect(Get.currentRoute, AppRoutes.hiddenChat);
      expect(Get.arguments, createdConv.id);
    });
  });
}
