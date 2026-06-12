import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/features/hidden/domain/entities/messaging_setup_state.dart';
import 'package:memovault/features/messaging/services/signal_session_manager.dart';
import 'package:memovault/features/messaging/services/prekey_rotation_service.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';

class SignalSyncService extends GetxService {
  final SignalSessionManager _sessionManager;
  final MessagingIdentityService _identityService;
  final HiddenSessionService _sessionService;
  final MessagingRepository _messagingRepository;

  StreamSubscription<QuerySnapshot>? _syncSubscription;
  StreamSubscription<HiddenSessionState>? _sessionSubscription;

  SignalSyncService(
    this._sessionManager,
    this._identityService,
    this._sessionService,
    this._messagingRepository,
  );

  @override
  void onInit() {
    super.onInit();
    // Watch hidden session state to start/stop sync listener dynamically
    _sessionSubscription = _sessionService.state.listen((state) {
      if (state == HiddenSessionState.active) {
        startSyncListener();
        _sessionManager.checkAndReplenishOneTimePrekeys();
        Get.find<PrekeyRotationService>().checkAndRotatePrekeys();
      } else {
        stopSyncListener();
      }
    });
  }

  @override
  void onClose() {
    _sessionSubscription?.cancel();
    stopSyncListener();
    super.onClose();
  }

  void startSyncListener() async {
    if (Firebase.apps.isEmpty) return;

    final isSetup = await _identityService.getSetupState();
    if (isSetup != MessagingSetupState.ready) return;

    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        AppLogger.error('[SignalSyncService] Failed to sign in anonymously: $e');
        return;
      }
    }

    final currentUid = auth.currentUser?.uid;
    if (currentUid == null) return;

    stopSyncListener();

    AppLogger.info('[SignalSyncService] Starting Firestore sync listener for $currentUid');

    final firestore = FirebaseFirestore.instance;
    _syncSubscription = firestore
        .collection('sync_queues')
        .doc(currentUid)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((snapshot) async {
      final sortedDocs = [...snapshot.docs]..sort((a, b) {
        final aData = a.data() as Map<String, dynamic>? ?? {};
        final bData = b.data() as Map<String, dynamic>? ?? {};
        final aIsHandshake = (aData['type'] as int?) == 3 && aData['senderUsername'] != null;
        final bIsHandshake = (bData['type'] as int?) == 3 && bData['senderUsername'] != null;
        if (aIsHandshake && !bIsHandshake) return -1;
        if (!aIsHandshake && bIsHandshake) return 1;
        return 0;
      });
      for (final doc in sortedDocs) {
        if (!doc.exists) continue;
        try {
          await _processSyncMessage(doc, currentUid);
        } catch (e) {
          AppLogger.error('[SignalSyncService] Failed to process message ${doc.id}: $e');
        }
      }
    }, onError: (error) async {
      final isPermissionDenied = error is FirebaseException && error.code == 'permission-denied' ||
          error.toString().contains('permission-denied') ||
          error.toString().contains('PERMISSION_DENIED');
      if (isPermissionDenied) {
        AppLogger.warning('[SignalSyncService] Sync listener permission denied. Retrying with fresh anonymous session.');
        try {
          await auth.signOut();
          await auth.signInAnonymously();
          startSyncListener();
        } catch (e) {
          AppLogger.error('[SignalSyncService] Failed to heal anonymous session: $e');
        }
      } else {
        AppLogger.error('[SignalSyncService] Sync listener error: $error');
      }
    });
  }

  void stopSyncListener() {
    _syncSubscription?.cancel();
    _syncSubscription = null;
    AppLogger.info('[SignalSyncService] Stopped Firestore sync listener.');
  }

  Future<void> _processSyncMessage(DocumentSnapshot doc, String currentUid) async {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final messageId = doc.id;
    final senderUid = data['senderUid'] as String;
    final ciphertextHex = data['ciphertext'] as String;
    final type = data['type'] as int;

    // Contact Blocking Gate (Point 5): Discard and delete immediately if blocked
    final conversationId = '${currentUid}_$senderUid';
    final existingConv = await _messagingRepository.getConversationById(conversationId);
    if (existingConv != null && existingConv.isBlocked) {
      AppLogger.info('[SignalSyncService] Blocked sender $senderUid. Deleting message from queue.');
      await doc.reference.delete();
      return;
    }

    // Check duplicate/already processed message
    final existingMsg = await _messagingRepository.getMessageById(messageId);
    if (existingMsg != null) {
      AppLogger.info('[SignalSyncService] Duplicate message $messageId already processed. Deleting from queue.');
      await doc.reference.delete();
      return;
    }

    try {
      if (type == 3 && data['senderUsername'] != null) {
        // Handshake / PreKeySignalMessage
        final senderUsername = data['senderUsername'] as String;
        final senderIdentityKeyPubHex = data['senderIdentityKeyPubHex'] as String;

        await _sessionManager.receiveHandshake(
          senderUid: senderUid,
          ciphertextHex: ciphertextHex,
          messageType: type,
          senderUsername: senderUsername,
          senderIdentityKeyPubHex: senderIdentityKeyPubHex,
          isHidden: true,
        );
      } else {
        // Normal E2EE whisper message (type 2 or type 3 first message after handshake)
        final attachmentData = data['attachment'] as Map<String, dynamic>?;
        final messageType = data['messageType'] as String? ?? 'text';
        await _sessionManager.decryptAndStoreMessage(
          senderUid: senderUid,
          ciphertextHex: ciphertextHex,
          messageType: type,
          messageId: messageId,
          attachmentData: attachmentData,
          incomingMessageType: messageType,
        );
      }
    } on StateError catch (e) {
      if (e.message == 'REPLAYED_MESSAGE' || e.message == 'DUPLICATE_MESSAGE') {
        AppLogger.warning('[SignalSyncService] Replayed or duplicate message detected. Deleting from queue: ${e.message}');
        await doc.reference.delete();
        return;
      }
      rethrow;
    }

    // Store-Before-Delete: Delete from Firestore ONLY after successful local processing
    await doc.reference.delete();
  }

  /// Public test helper to process current mock sync queue for testing (when Firebase is empty)
  Future<void> testProcessMockQueue(String currentUid) async {
    if (SignalSessionManager.mockSyncQueues != null) {
      final queue = SignalSessionManager.mockSyncQueues![currentUid];
      if (queue != null) {
        // Process a copy to prevent concurrent modification
        final copy = List<Map<String, dynamic>>.from(queue)..sort((a, b) {
          final aIsHandshake = (a['type'] as int?) == 3 && a['senderUsername'] != null;
          final bIsHandshake = (b['type'] as int?) == 3 && b['senderUsername'] != null;
          if (aIsHandshake && !bIsHandshake) return -1;
          if (!aIsHandshake && bIsHandshake) return 1;
          return 0;
        });
        for (final item in copy) {
          final doc = _FakeDocumentSnapshot(
            docId: item['id'] as String,
            data: item,
            currentUid: currentUid,
          );
          await _processSyncMessage(doc, currentUid);
        }
      }
    }
  }
}

// ignore: subtype_of_sealed_class
class _FakeDocumentSnapshot implements DocumentSnapshot {
  final String docId;
  final Map<String, dynamic> _data;
  final String currentUid;

  _FakeDocumentSnapshot({
    required this.docId,
    required Map<String, dynamic> data,
    required this.currentUid,
  }) : _data = data;

  @override
  String get id => docId;

  @override
  bool get exists => true;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  DocumentReference get reference => _FakeDocumentReference(docId, currentUid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeDocumentReference implements DocumentReference {
  final String docId;
  final String currentUid;

  _FakeDocumentReference(this.docId, this.currentUid);

  @override
  Future<void> delete() async {
    if (SignalSessionManager.mockSyncQueues != null) {
      final queue = SignalSessionManager.mockSyncQueues![currentUid];
      if (queue != null) {
        queue.removeWhere((item) => item['id'] == docId);
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
