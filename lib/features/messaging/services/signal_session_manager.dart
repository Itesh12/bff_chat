import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:libsignal/libsignal.dart';
import 'package:get/get.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';
import 'package:memovault/domain/messaging/message_entity.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/features/messaging/services/signal_store_impl.dart';

class SignalSessionManager {
  final MessagingIdentityService _identityService;
  final MessagingRepository _messagingRepository;
  final SecureStorageService _secureStorage;

  SignalSessionManager(
    this._identityService,
    this._messagingRepository,
    this._secureStorage,
  );

  // Fallbacks for testing environments when Firebase is not initialized
  static Map<String, Map<String, dynamic>>? mockPseudonyms;
  static Map<String, Map<String, dynamic>>? mockPrekeyBundles;
  static Map<String, List<Map<String, dynamic>>>? mockSyncQueues;

  static Uint8List _hexToBytes(String hex) {
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Initiates a session with a target user (Alice initiating with Bob)
  Future<void> initiateSession({
    required String targetUsername,
    required bool isHidden,
  }) async {
    final currentUid = Firebase.apps.isEmpty
        ? 'alice_uid'
        : FirebaseAuth.instance.currentUser!.uid;

    // 1. Resolve Target Pseudonym
    final String bobUid;
    final String bobIdentityKeyPub;

    if (Firebase.apps.isEmpty && mockPseudonyms != null) {
      final doc = mockPseudonyms![targetUsername];
      if (doc == null) throw Exception('Target username not found in directory.');
      bobUid = doc['uid'] as String;
      bobIdentityKeyPub = doc['identityPublicKey'] as String;
    } else {
      final firestore = FirebaseFirestore.instance;
      final pseudonymDoc = await firestore.collection('pseudonyms').doc(targetUsername).get();
      if (!pseudonymDoc.exists) {
        throw Exception('Target username not found in directory.');
      }
      bobUid = pseudonymDoc.get('uid') as String;
      bobIdentityKeyPub = pseudonymDoc.get('identityPublicKey') as String;
    }

    // 2. Check for contact blocking gate (Point 5)
    final conversationId = '${currentUid}_$bobUid';
    final existingConv = await _messagingRepository.getConversationById(conversationId);
    if (existingConv != null && existingConv.isBlocked) {
      throw StateError('BLOCKED_CONTACT');
    }

    // Detect identity key change under ADR-022:
    final existingContact = await _messagingRepository.getParticipantById(bobUid);
    if (existingContact != null && existingContact.identityKeyPub != bobIdentityKeyPub) {
      // Identity key changed! Set trustState to 'revoked' to trigger safety warning
      await _messagingRepository.createOrUpdateParticipant(
        id: bobUid,
        username: targetUsername,
        identityKeyPub: existingContact.identityKeyPub, // Keep original key for warnings
        trustState: 'revoked',
      );
      throw StateError('IDENTITY_KEY_CHANGED');
    }

    // 3. Fetch and Reserve OTP Atomically using Transaction (Concurrency Protection)
    final String identityKeyPubHex;
    final int signedPrekeyId;
    final String signedPrekeyPublicHex;
    final String signedPrekeySignatureHex;
    final int kyberPrekeyId;
    final String kyberPrekeyPublicHex;
    final String kyberPrekeySignatureHex;
    int? selectedPreKeyId;
    Uint8List? selectedPreKeyPublic;

    if (Firebase.apps.isEmpty && mockPrekeyBundles != null) {
      final doc = mockPrekeyBundles![bobUid];
      if (doc == null) throw Exception('Prekey bundle not found for target user.');
      identityKeyPubHex = doc['identityPublicKey'] as String;
      signedPrekeyId = doc['signedPrekeyId'] as int;
      signedPrekeyPublicHex = doc['signedPrekeyPublic'] as String;
      signedPrekeySignatureHex = doc['signedPrekeySignature'] as String;
      kyberPrekeyId = doc['kyberPrekeyId'] as int;
      kyberPrekeyPublicHex = doc['kyberPrekeyPublic'] as String;
      kyberPrekeySignatureHex = doc['kyberPrekeySignature'] as String;

      final otps = doc['oneTimePrekeys'] as List<dynamic>;
      if (otps.isNotEmpty) {
        final first = otps.removeAt(0) as Map<String, dynamic>;
        selectedPreKeyId = first['id'] as int;
        selectedPreKeyPublic = _hexToBytes(first['publicKey'] as String);
      }
    } else {
      final firestore = FirebaseFirestore.instance;
      final bundleRef = firestore.collection('prekey_bundles').doc(bobUid);

      final transactionResult = await firestore.runTransaction((transaction) async {
        final bundleDoc = await transaction.get(bundleRef);
        if (!bundleDoc.exists) {
          throw Exception('Prekey bundle not found for target user.');
        }

        final idPubKeyHex = bundleDoc.get('identityPublicKey') as String;
        final spKeyId = bundleDoc.get('signedPrekeyId') as int;
        final spKeyPubHex = bundleDoc.get('signedPrekeyPublic') as String;
        final spKeySigHex = bundleDoc.get('signedPrekeySignature') as String;
        final kpKeyId = bundleDoc.get('kyberPrekeyId') as int;
        final kpKeyPubHex = bundleDoc.get('kyberPrekeyPublic') as String;
        final kpKeySigHex = bundleDoc.get('kyberPrekeySignature') as String;
        final oneTimePrekeys = bundleDoc.get('oneTimePrekeys') as List<dynamic>? ?? [];

        Map<String, dynamic>? chosenOtp;
        if (oneTimePrekeys.isNotEmpty) {
          chosenOtp = Map<String, dynamic>.from(oneTimePrekeys.first as Map);
          // Atomically remove the chosen OTP from Firestore
          transaction.update(bundleRef, {
            'oneTimePrekeys': FieldValue.arrayRemove([chosenOtp]),
          });
        }

        return {
          'identityKeyPubHex': idPubKeyHex,
          'signedPrekeyId': spKeyId,
          'signedPrekeyPublicHex': spKeyPubHex,
          'signedPrekeySignatureHex': spKeySigHex,
          'kyberPrekeyId': kpKeyId,
          'kyberPrekeyPublicHex': kpKeyPubHex,
          'kyberPrekeySignatureHex': kpKeySigHex,
          'chosenOtp': chosenOtp,
        };
      });

      identityKeyPubHex = transactionResult['identityKeyPubHex']! as String;
      signedPrekeyId = transactionResult['signedPrekeyId']! as int;
      signedPrekeyPublicHex = transactionResult['signedPrekeyPublicHex']! as String;
      signedPrekeySignatureHex = transactionResult['signedPrekeySignatureHex']! as String;
      kyberPrekeyId = transactionResult['kyberPrekeyId']! as int;
      kyberPrekeyPublicHex = transactionResult['kyberPrekeyPublicHex']! as String;
      kyberPrekeySignatureHex = transactionResult['kyberPrekeySignatureHex']! as String;

      final chosenOtp = transactionResult['chosenOtp'] as Map<String, dynamic>?;
      if (chosenOtp != null) {
        selectedPreKeyId = chosenOtp['id'] as int;
        selectedPreKeyPublic = _hexToBytes(chosenOtp['publicKey'] as String);
      }
    }

    final identityKeyPubBytes = _hexToBytes(identityKeyPubHex);
    final signedPrekeyPublicBytes = _hexToBytes(signedPrekeyPublicHex);
    final signedPrekeySignatureBytes = _hexToBytes(signedPrekeySignatureHex);
    final kyberPrekeyPublicBytes = _hexToBytes(kyberPrekeyPublicHex);
    final kyberPrekeySignatureBytes = _hexToBytes(kyberPrekeySignatureHex);

    // 4. Construct PreKeyBundle for libsignal
    final bobBundle = PreKeyBundle(
      registrationId: 67890,
      deviceId: 1,
      preKeyId: selectedPreKeyId,
      preKeyPublic: selectedPreKeyPublic,
      signedPreKeyId: signedPrekeyId,
      signedPreKeyPublic: signedPrekeyPublicBytes,
      signedPreKeySignature: signedPrekeySignatureBytes,
      identityKey: identityKeyPubBytes,
      kyberPreKeyId: kyberPrekeyId,
      kyberPreKeyPublic: kyberPrekeyPublicBytes,
      kyberPreKeySignature: kyberPrekeySignatureBytes,
    );

    // 5. Initialize Local Signal Stores
    final signalStore = SignalStoreImpl(_secureStorage, _identityService, _messagingRepository);
    final localAddress = ProtocolAddress(name: currentUid, deviceId: 1);
    final bobAddress = ProtocolAddress(name: bobUid, deviceId: 1);

    final sessionBuilder = SessionBuilder(
      localAddress: localAddress,
      sessionStore: signalStore,
      identityKeyStore: signalStore,
    );

    // 6. Process Bundle to derive shared secret and initial session
    await sessionBuilder.processPreKeyBundle(bobAddress, bobBundle);

    // 7. Save Participant and Conversation Locally
    await _messagingRepository.createOrUpdateParticipant(
      id: bobUid,
      username: targetUsername,
      identityKeyPub: _bytesToHex(identityKeyPubBytes),
      trustState: 'accepted',
    );

    await _messagingRepository.createConversation(
      id: conversationId,
      participantId: bobUid,
      isHidden: isHidden,
    );

    // 8. Encrypt initial handshake message to initiate the handshake envelope
    final sessionCipher = SessionCipher(
      localAddress: localAddress,
      sessionStore: signalStore,
      identityKeyStore: signalStore,
      preKeyStore: signalStore,
      signedPreKeyStore: signalStore,
      kyberPreKeyStore: signalStore,
    );

    final handshakePayload = Uint8List.fromList('handshake_init'.codeUnits);
    final ciphertextMessage = await sessionCipher.encrypt(bobAddress, handshakePayload);

    // Write a local handshake message history row
    final localMessageId = 'h_${DateTime.now().microsecondsSinceEpoch}';
    final localHandshakeMsg = MessageEntity(
      id: localMessageId,
      conversationId: conversationId,
      senderId: 'me',
      encryptedContent: 'Handshake initiated',
      nonce: '',
      state: 'sent',
      messageType: 'handshake',
      createdAt: DateTime.now().toUtc(),
    );
    await _messagingRepository.insertMessage(localHandshakeMsg);
    await _messagingRepository.updateConversationLastMessage(conversationId, localMessageId);

    // 9. Post to Bob's sync queue
    final messageId = DateTime.now().microsecondsSinceEpoch.toString();
    final myUsername = await _identityService.getUsername() ?? 'unknown';
    final myPubKey = await _identityService.getPublicKey() ?? '';

    final messageData = {
      'id': messageId,
      'senderUid': currentUid,
      'ciphertext': _bytesToHex(ciphertextMessage.ciphertext),
      'type': ciphertextMessage.type.value, // preKey (type 3)
      'senderUsername': myUsername,
      'senderIdentityKeyPubHex': myPubKey,
    };

    if (Firebase.apps.isEmpty && mockSyncQueues != null) {
      mockSyncQueues!.putIfAbsent(bobUid, () => []).add(messageData);
    } else {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('sync_queues')
          .doc(bobUid)
          .collection('messages')
          .doc(messageId)
          .set({
        ...messageData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Processes an incoming handshake message (Bob receiving from Alice)
  Future<void> receiveHandshake({
    required String senderUid,
    required String ciphertextHex,
    required int messageType,
    required String senderUsername,
    required String senderIdentityKeyPubHex,
    required bool isHidden,
  }) async {
    final currentUid = Firebase.apps.isEmpty
        ? 'bob_uid'
        : FirebaseAuth.instance.currentUser!.uid;

    final signalStore = SignalStoreImpl(_secureStorage, _identityService, _messagingRepository);
    final localAddress = ProtocolAddress(name: currentUid, deviceId: 1);
    final senderAddress = ProtocolAddress(name: senderUid, deviceId: 1);

    final sessionCipher = SessionCipher(
      localAddress: localAddress,
      sessionStore: signalStore,
      identityKeyStore: signalStore,
      preKeyStore: signalStore,
      signedPreKeyStore: signalStore,
      kyberPreKeyStore: signalStore,
    );

    // Create participant and conversation locally if they do not exist
    await _messagingRepository.createOrUpdateParticipant(
      id: senderUid,
      username: senderUsername,
      identityKeyPub: senderIdentityKeyPubHex,
      trustState: 'accepted',
    );

    final conversationId = '${currentUid}_$senderUid';
    final existingConv = await _messagingRepository.getConversationById(conversationId);
    if (existingConv == null) {
      await _messagingRepository.createConversation(
        id: conversationId,
        participantId: senderUid,
        isHidden: isHidden,
      );
    }

    final ciphertextBytes = _hexToBytes(ciphertextHex);

    // Reconstruct CiphertextMessage
    final signalMsg = CiphertextMessage.fromRaw(
      messageType: messageType,
      ciphertext: ciphertextBytes,
    );

    // Decrypting the message automatically executes SessionBuilder processing on Bob's side
    await sessionCipher.decrypt(senderAddress, signalMsg);

    // Write local handshake received system message row (TTL cleanup sweeps this after 7 days)
    final localMessageId = 'h_${DateTime.now().microsecondsSinceEpoch}';
    final localHandshakeMsg = MessageEntity(
      id: localMessageId,
      conversationId: conversationId,
      senderId: senderUid,
      encryptedContent: 'Handshake received',
      nonce: '',
      state: 'delivered',
      messageType: 'handshake',
      createdAt: DateTime.now().toUtc(),
    );
    await _messagingRepository.insertMessage(localHandshakeMsg);
    await _messagingRepository.updateConversationLastMessage(conversationId, localMessageId);
  }

  /// Sends a secure E2EE message over the sync queues
  Future<void> sendSecureMessage({
    required String targetUid,
    required String plaintext,
  }) async {
    final currentUid = Firebase.apps.isEmpty
        ? 'alice_uid'
        : FirebaseAuth.instance.currentUser!.uid;

    final conversationId = '${currentUid}_$targetUid';
    final existingConv = await _messagingRepository.getConversationById(conversationId);
    if (existingConv != null && existingConv.isBlocked) {
      throw StateError('BLOCKED_CONTACT');
    }

    final signalStore = SignalStoreImpl(_secureStorage, _identityService, _messagingRepository);
    final bobAddress = ProtocolAddress(name: targetUid, deviceId: 1);
    final localAddress = ProtocolAddress(name: currentUid, deviceId: 1);

    if (!await signalStore.containsSession(bobAddress)) {
      final participant = await _messagingRepository.getParticipantById(targetUid);
      if (participant == null) throw Exception('Participant not found locally.');
      final cleanUsername = participant.username.replaceAll('@', '');
      await initiateSession(targetUsername: cleanUsername, isHidden: true);
    }

    final sessionCipher = SessionCipher(
      localAddress: localAddress,
      sessionStore: signalStore,
      identityKeyStore: signalStore,
      preKeyStore: signalStore,
      signedPreKeyStore: signalStore,
      kyberPreKeyStore: signalStore,
    );

    final messageBytes = Uint8List.fromList(plaintext.codeUnits);
    final ciphertextMessage = await sessionCipher.encrypt(bobAddress, messageBytes);

    final messageId = DateTime.now().microsecondsSinceEpoch.toString();
    final messageData = {
      'id': messageId,
      'senderUid': currentUid,
      'ciphertext': _bytesToHex(ciphertextMessage.ciphertext),
      'type': ciphertextMessage.type.value, // whisper (type 2)
    };

    if (Firebase.apps.isEmpty && mockSyncQueues != null) {
      mockSyncQueues!.putIfAbsent(targetUid, () => []).add(messageData);
    } else {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('sync_queues')
          .doc(targetUid)
          .collection('messages')
          .doc(messageId)
          .set({
        ...messageData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Decrypts an incoming message and stores it locally inside SQLCipher
  Future<void> decryptAndStoreMessage({
    required String senderUid,
    required String ciphertextHex,
    required int messageType,
    required String messageId,
  }) async {
    final currentUid = Firebase.apps.isEmpty
        ? 'bob_uid'
        : FirebaseAuth.instance.currentUser!.uid;

    final signalStore = SignalStoreImpl(_secureStorage, _identityService, _messagingRepository);
    final localAddress = ProtocolAddress(name: currentUid, deviceId: 1);
    final senderAddress = ProtocolAddress(name: senderUid, deviceId: 1);

    final sessionCipher = SessionCipher(
      localAddress: localAddress,
      sessionStore: signalStore,
      identityKeyStore: signalStore,
      preKeyStore: signalStore,
      signedPreKeyStore: signalStore,
      kyberPreKeyStore: signalStore,
    );

    final ciphertextBytes = _hexToBytes(ciphertextHex);
    final signalMsg = CiphertextMessage.fromRaw(
      messageType: messageType,
      ciphertext: ciphertextBytes,
    );

    final decryptedBytes = await sessionCipher.decrypt(senderAddress, signalMsg);
    final decryptedText = String.fromCharCodes(decryptedBytes);

    // Save message locally (Store-Before-Delete timing)
    final conversationId = '${currentUid}_$senderUid';
    final msg = MessageEntity(
      id: messageId,
      conversationId: conversationId,
      senderId: senderUid,
      encryptedContent: decryptedText,
      nonce: '',
      state: 'delivered',
      createdAt: DateTime.now().toUtc(),
    );

    await _messagingRepository.insertMessage(msg);
    await _messagingRepository.updateConversationLastMessage(conversationId, messageId);

    // Increment unread count if the chat is not currently open
    final currentRoute = Get.currentRoute;
    final isChatOpen = currentRoute.startsWith('/hidden/chat') && Get.arguments == conversationId;
    if (!isChatOpen) {
      final conv = await _messagingRepository.getConversationById(conversationId);
      if (conv != null) {
        await _messagingRepository.updateConversationUnreadCount(conversationId, conv.unreadCount + 1);
      }
    }
  }

  /// Re-approves a participant identity after key changes and establishes a new session
  Future<void> reapproveParticipantIdentity(String participantId) async {
    final participant = await _messagingRepository.getParticipantById(participantId);
    if (participant == null) throw Exception('Participant not found.');

    final String cleanUsername = participant.username.replaceAll('@', '');
    final String bobUid;
    final String bobIdentityKeyPub;

    if (Firebase.apps.isEmpty && mockPseudonyms != null) {
      final doc = mockPseudonyms![cleanUsername];
      if (doc == null) throw Exception('Target username not found in directory.');
      bobUid = doc['uid'] as String;
      bobIdentityKeyPub = doc['identityPublicKey'] as String;
    } else {
      final firestore = FirebaseFirestore.instance;
      final pseudonymDoc = await firestore.collection('pseudonyms').doc(cleanUsername).get();
      if (!pseudonymDoc.exists) {
        throw Exception('Target username not found in directory.');
      }
      bobUid = pseudonymDoc.get('uid') as String;
      bobIdentityKeyPub = pseudonymDoc.get('identityPublicKey') as String;
    }

    // 1. Update participant to the new key and set trustState = 'accepted'
    await _messagingRepository.createOrUpdateParticipant(
      id: bobUid,
      username: participant.username,
      identityKeyPub: bobIdentityKeyPub,
      trustState: 'accepted',
    );

    // 2. Clear old session in store to force a clean re-handshake
    final signalStore = SignalStoreImpl(_secureStorage, _identityService, _messagingRepository);
    final bobAddress = ProtocolAddress(name: bobUid, deviceId: 1);
    await signalStore.deleteSession(bobAddress);

    // 3. Force a new session handshake to establish keys with the new identity
    await initiateSession(targetUsername: cleanUsername, isHidden: true);
  }

  /// Checks own Firestore prekey bundle and auto-replenishes OTPs if batch < 20
  Future<void> checkAndReplenishOneTimePrekeys() async {
    final currentUid = Firebase.apps.isEmpty
        ? 'bob_uid'
        : (FirebaseAuth.instance.currentUser?.uid ?? 'bob_uid');

    if (Firebase.apps.isEmpty && mockPrekeyBundles != null) {
      final doc = mockPrekeyBundles![currentUid];
      if (doc == null) return;
      final List<dynamic> oneTimePrekeys = doc['oneTimePrekeys'] as List<dynamic>? ?? [];
      if (oneTimePrekeys.length < 20) {
        AppLogger.info('[SignalSessionManager] [Mock] OTP count is ${oneTimePrekeys.length} (< 20). Replenishing...');
        final newOtpData = <Map<String, dynamic>>[];
        final existingIds = await _identityService.getOneTimePreKeyIds();
        final int startId = existingIds.isEmpty ? 1 : (existingIds.reduce((a, b) => a > b ? a : b) + 1);

        for (int i = 0; i < 80; i++) {
          final id = startId + i;
          final keyPair = PrivateKey.generate();
          await _identityService.saveOneTimePreKey(
            id: id,
            privKeyHex: _bytesToHex(keyPair.serialize()),
            pubKeyHex: _bytesToHex(keyPair.getPublicKey().serialize()),
          );
          newOtpData.add({
            'id': id,
            'publicKey': _bytesToHex(keyPair.getPublicKey().serialize()),
          });
        }
        doc['oneTimePrekeys'] = [...oneTimePrekeys, ...newOtpData];
        AppLogger.info('[SignalSessionManager] [Mock] Successfully replenished 80 OTPs.');
      }
      return;
    }

    if (Firebase.apps.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final bundleRef = firestore.collection('prekey_bundles').doc(currentUid);

    try {
      final doc = await bundleRef.get();
      if (!doc.exists) return;

      final List<dynamic> oneTimePrekeys = doc.get('oneTimePrekeys') as List<dynamic>? ?? [];

      if (oneTimePrekeys.length < 20) {
        AppLogger.info('[SignalSessionManager] OTP count is ${oneTimePrekeys.length} (< 20). Replenishing...');

        final newOtpData = <Map<String, dynamic>>[];
        final existingIds = await _identityService.getOneTimePreKeyIds();
        final int startId = existingIds.isEmpty ? 1 : (existingIds.reduce((a, b) => a > b ? a : b) + 1);

        for (int i = 0; i < 80; i++) {
          final id = startId + i;
          final keyPair = PrivateKey.generate();

          // Save locally
          await _identityService.saveOneTimePreKey(
            id: id,
            privKeyHex: _bytesToHex(keyPair.serialize()),
            pubKeyHex: _bytesToHex(keyPair.getPublicKey().serialize()),
          );

          newOtpData.add({
            'id': id,
            'publicKey': _bytesToHex(keyPair.getPublicKey().serialize()),
          });
        }

        // Upload new batch to Firestore
        await bundleRef.update({
          'oneTimePrekeys': FieldValue.arrayUnion(newOtpData),
        });
        AppLogger.info('[SignalSessionManager] Successfully replenished 80 OTPs.');
      }
    } catch (e) {
      AppLogger.error('[SignalSessionManager] OTP replenishment failed: $e');
    }
  }
}
