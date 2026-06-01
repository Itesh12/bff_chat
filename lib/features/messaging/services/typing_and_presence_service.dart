import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';
import 'package:memovault/domain/messaging/message_receipt_entity.dart';
import 'package:uuid/uuid.dart';

class TypingAndPresenceService extends GetxService {
  final MessagingRepository _messagingRepository;
  
  Timer? _presenceTimer;
  StreamSubscription? _receiptSubscription;
  final _uuid = const Uuid();

  // Mock store
  static final mockPresence = <String, Map<String, dynamic>>{}.obs;
  static final mockTyping = <String, Map<String, Map<String, dynamic>>>{}.obs; // conversationId -> userId -> {isTyping, updatedAt}
  static final mockReceipts = <String, Map<String, dynamic>>{}.obs; // receiptId -> receiptData

  TypingAndPresenceService(this._messagingRepository);

  @override
  void onInit() {
    super.onInit();
    // Start presence heartbeat
    _publishPresence();
    _presenceTimer = Timer.periodic(const Duration(seconds: 60), (_) => _publishPresence());
    
    // Start listening for read receipts
    _listenForReadReceipts();
  }

  @override
  void onClose() {
    _presenceTimer?.cancel();
    _receiptSubscription?.cancel();
    super.onClose();
  }

  String? _getMyUid() {
    if (Firebase.apps.isEmpty) {
      return 'bob_uid';
    }
    return FirebaseAuth.instance.currentUser?.uid;
  }

  // ─── Presence ─────────────────────────────────────────────────────────────

  Future<void> _publishPresence() async {
    final myUid = _getMyUid();
    if (myUid == null) return;

    final expiresAt = DateTime.now().toUtc().add(const Duration(seconds: 120));

    if (Firebase.apps.isEmpty) {
      mockPresence[myUid] = {
        'uid': myUid,
        'expiresAt': expiresAt,
        'updatedAt': DateTime.now().toUtc(),
      };
    } else {
      try {
        await FirebaseFirestore.instance.collection('presence').doc(myUid).set({
          'expiresAt': Timestamp.fromDate(expiresAt),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        AppLogger.error('[TypingAndPresenceService] Error publishing presence: $e');
      }
    }
  }

  Stream<bool> watchUserPresence(String userId) {
    if (Firebase.apps.isEmpty) {
      final controller = StreamController<bool>();
      
      void check() {
        if (controller.isClosed) return;
        final data = mockPresence[userId];
        if (data != null) {
          final expiresAt = data['expiresAt'] as DateTime;
          controller.add(expiresAt.isAfter(DateTime.now().toUtc()));
        } else {
          controller.add(false);
        }
      }

      check();
      final timer = Timer.periodic(const Duration(seconds: 5), (_) => check());
      final subscription = mockPresence.listen((_) => check());

      controller.onCancel = () {
        timer.cancel();
        subscription.cancel();
        controller.close();
      };
      return controller.stream.distinct();
    } else {
      return FirebaseFirestore.instance
          .collection('presence')
          .doc(userId)
          .snapshots()
          .map((snapshot) {
            if (!snapshot.exists) return false;
            final data = snapshot.data();
            if (data == null) return false;
            final expiresAtField = data['expiresAt'];
            if (expiresAtField == null) return false;
            final DateTime expiresAt = (expiresAtField as Timestamp).toDate();
            return expiresAt.isAfter(DateTime.now().toUtc());
          })
          .distinct();
    }
  }

  // ─── Typing Indicators ───────────────────────────────────────────────────

  Future<void> setTypingState(String conversationId, bool isTyping) async {
    final myUid = _getMyUid();
    if (myUid == null) return;

    if (Firebase.apps.isEmpty) {
      final convMap = mockTyping[conversationId] ?? <String, Map<String, dynamic>>{};
      convMap[myUid] = {
        'isTyping': isTyping,
        'updatedAt': DateTime.now().toUtc(),
      };
      mockTyping[conversationId] = Map<String, Map<String, dynamic>>.from(convMap);
    } else {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('typing')
            .doc(conversationId)
            .collection('users')
            .doc(myUid);
        if (isTyping) {
          await docRef.set({
            'isTyping': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await docRef.delete();
        }
      } catch (e) {
        AppLogger.error('[TypingAndPresenceService] Error updating typing state: $e');
      }
    }
  }

  Stream<List<String>> watchTypingUsers(String conversationId) {
    final myUid = _getMyUid();
    if (Firebase.apps.isEmpty) {
      final controller = StreamController<List<String>>();
      
      void check() {
        if (controller.isClosed) return;
        final convMap = mockTyping[conversationId];
        if (convMap == null) {
          controller.add([]);
          return;
        }
        final now = DateTime.now().toUtc();
        final activeTyping = <String>[];
        convMap.forEach((uid, data) {
          if (uid == myUid) return; // Exclude self
          final isTyping = data['isTyping'] as bool;
          final updatedAt = data['updatedAt'] as DateTime;
          // Typing state expires after 5s
          if (isTyping && now.difference(updatedAt).inSeconds < 5) {
            activeTyping.add(uid);
          }
        });
        controller.add(activeTyping);
      }

      check();
      final timer = Timer.periodic(const Duration(seconds: 2), (_) => check());
      final subscription = mockTyping.listen((_) => check());

      controller.onCancel = () {
        timer.cancel();
        subscription.cancel();
        controller.close();
      };
      return controller.stream.distinct((a, b) => a.length == b.length && a.every(b.contains));
    } else {
      return FirebaseFirestore.instance
          .collection('typing')
          .doc(conversationId)
          .collection('users')
          .snapshots()
          .map((snapshot) {
            final now = DateTime.now().toUtc();
            final activeTyping = <String>[];
            for (final doc in snapshot.docs) {
              if (doc.id == myUid) continue;
              final data = doc.data();
              final isTyping = data['isTyping'] as bool? ?? false;
              final updatedAtField = data['updatedAt'];
              if (isTyping && updatedAtField != null) {
                final DateTime updatedAt = (updatedAtField as Timestamp).toDate();
                if (now.difference(updatedAt).inSeconds < 5) {
                  activeTyping.add(doc.id);
                }
              }
            }
            return activeTyping;
          })
          .distinct((a, b) => a.length == b.length && a.every(b.contains));
    }
  }

  // ─── Read Receipts ────────────────────────────────────────────────────────

  Future<void> sendReadReceipt(String messageId, String recipientId) async {
    final myUid = _getMyUid();
    if (myUid == null) return;

    final receiptId = _uuid.v4();
    final timestamp = DateTime.now().toUtc();

    // Insert locally
    final localReceipt = MessageReceiptEntity(
      id: receiptId,
      messageId: messageId,
      participantId: myUid,
      status: 'read',
      timestamp: timestamp,
    );
    await _messagingRepository.insertReceipt(localReceipt);

    if (Firebase.apps.isEmpty) {
      mockReceipts[receiptId] = {
        'id': receiptId,
        'messageId': messageId,
        'senderId': myUid,
        'recipientId': recipientId,
        'status': 'read',
        'timestamp': timestamp,
      };
    } else {
      try {
        await FirebaseFirestore.instance.collection('receipts').doc(receiptId).set({
          'messageId': messageId,
          'senderId': myUid,
          'recipientId': recipientId,
          'status': 'read',
          'timestamp': Timestamp.fromDate(timestamp),
        });
      } catch (e) {
        AppLogger.error('[TypingAndPresenceService] Error sending read receipt: $e');
      }
    }
  }

  void _listenForReadReceipts() {
    final myUid = _getMyUid();
    if (myUid == null) return;

    if (Firebase.apps.isEmpty) {
      _receiptSubscription = mockReceipts.listen((map) async {
        final list = Map<String, dynamic>.from(map);
        for (final entry in list.entries) {
          final data = entry.value as Map<String, dynamic>;
          if (data['recipientId'] == myUid && data['status'] == 'read') {
            final messageId = data['messageId'] as String;
            // Update message status locally to read
            await _messagingRepository.updateMessageState(messageId, 'read');
            // Remove from mockReceipts (transient behavior)
            mockReceipts.remove(entry.key);
          }
        }
      });
    } else {
      _receiptSubscription = FirebaseFirestore.instance
          .collection('receipts')
          .where('recipientId', isEqualTo: myUid)
          .snapshots()
          .listen((snapshot) async {
            for (final doc in snapshot.docs) {
              if (!doc.exists) continue;
              final data = doc.data();
              final messageId = data['messageId'] as String;
              final senderId = data['senderId'] as String;
              final timestamp = (data['timestamp'] as Timestamp).toDate();

              // Update locally
              await _messagingRepository.updateMessageState(messageId, 'read');
              
              // Also store in our local receipts table for completeness
              final localReceipt = MessageReceiptEntity(
                id: doc.id,
                messageId: messageId,
                participantId: senderId,
                status: 'read',
                timestamp: timestamp,
              );
              await _messagingRepository.insertReceipt(localReceipt);

              // Delete transient receipt from Firestore
              try {
                await doc.reference.delete();
              } catch (e) {
                // Ignore transient delete errors
              }
            }
          });
    }
  }
}
