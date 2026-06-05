import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:libsignal/libsignal.dart';
import 'package:get/get.dart' hide Value;
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';
import 'package:memovault/domain/messaging/message_entity.dart';
import 'package:memovault/domain/messaging/attachment_entity.dart';
import 'package:memovault/domain/messaging/attachment_type.dart';
import 'package:memovault/core/crypto/media_cryptor.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/features/messaging/services/signal_store_impl.dart';
import 'package:drift/drift.dart' hide isNull;

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
    } else if (Firebase.apps.isNotEmpty) {
      final firestore = FirebaseFirestore.instance;
      final pseudonymDoc = await firestore.collection('pseudonyms').doc(targetUsername).get();
      if (!pseudonymDoc.exists) {
        throw Exception('Target username not found in directory.');
      }
      bobUid = pseudonymDoc.get('uid') as String;
      bobIdentityKeyPub = pseudonymDoc.get('identityPublicKey') as String;
    } else {
      throw Exception('[SignalSessionManager] Firebase not available and no mock data. Cannot resolve pseudonym for $targetUsername.');
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
    } else if (Firebase.apps.isNotEmpty) {
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
    } else {
      throw Exception('[SignalSessionManager] Firebase not available and no mock data. Cannot fetch prekey bundle for $bobUid.');
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
    final signalStore = SignalStoreImpl(_secureStorage, _identityService, _messagingRepository, isHidden: isHidden);
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
    } else if (Firebase.apps.isNotEmpty) {
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
    } else {
      AppLogger.warning('[SignalSessionManager] Dev mode: skipping Firestore handshake sync queue push (no Firebase, no mock).');
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

    final signalStore = SignalStoreImpl(_secureStorage, _identityService, _messagingRepository, isHidden: isHidden);
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

    // Register initial sequence number for replay protection
    try {
      final signalMsgBytes = _extractWhisperMessageFromPreKeyMessage(ciphertextBytes);
      if (signalMsgBytes != null) {
        final signalMsgObj = SignalMessage.deserialize(data: signalMsgBytes);
        final counter = signalMsgObj.counter();
        final ratchetKey = _bytesToHex(signalMsgObj.senderRatchetKey());
        await _messagingRepository.setSyncMetadata('max_seq:${senderUid}:${ratchetKey}', counter.toString());
      }
    } catch (e) {
      AppLogger.error('[SignalSessionManager] Failed to extract handshake sequence number: $e');
    }

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

    final isHidden = existingConv?.isHidden ?? true;
    final signalStore = SignalStoreImpl(_secureStorage, _identityService, _messagingRepository, isHidden: isHidden);
    final bobAddress = ProtocolAddress(name: targetUid, deviceId: 1);
    final localAddress = ProtocolAddress(name: currentUid, deviceId: 1);

    if (existingConv != null) {
      final lastActive = existingConv.updatedAt;
      final daysInactive = DateTime.now().toUtc().difference(lastActive).inDays;
      if (daysInactive > 30) {
        AppLogger.info('[SignalSessionManager] Session inactive for $daysInactive days (> 30 days). Rotating session.');
        await signalStore.deleteSession(bobAddress);
      }
    }

    if (!await signalStore.containsSession(bobAddress)) {
      final participant = await _messagingRepository.getParticipantById(targetUid);
      if (participant == null) throw Exception('Participant not found locally.');
      final cleanUsername = participant.username.replaceAll('@', '');
      await initiateSession(targetUsername: cleanUsername, isHidden: isHidden);
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
    } else if (Firebase.apps.isNotEmpty) {
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
    } else {
      AppLogger.warning('[SignalSessionManager] Dev mode: skipping Firestore secure message sync queue push (no Firebase, no mock).');
    }
  }

  /// Decrypts an incoming message and stores it locally inside SQLCipher
  Future<void> decryptAndStoreMessage({
    required String senderUid,
    required String ciphertextHex,
    required int messageType,
    required String messageId,
    Map<String, dynamic>? attachmentData,
    String? incomingMessageType,
  }) async {
    final currentUid = Firebase.apps.isEmpty
        ? 'bob_uid'
        : FirebaseAuth.instance.currentUser!.uid;

    final conversationId = '${currentUid}_$senderUid';
    final existingConv = await _messagingRepository.getConversationById(conversationId);
    final isHidden = existingConv?.isHidden ?? true;
    final signalStore = SignalStoreImpl(_secureStorage, _identityService, _messagingRepository, isHidden: isHidden);
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

    // Sequence index / Replay protection validation (Point 3 & 4)
    final hexToDecrypt = attachmentData != null 
        ? attachmentData['keyRecipient'] as String 
        : ciphertextHex;

    final ciphertextBytes = _hexToBytes(hexToDecrypt);

    if (messageType == 2 || messageType == 3) {
      final Uint8List signalMsgBytes;
      if (messageType == 3) {
        final extracted = _extractWhisperMessageFromPreKeyMessage(ciphertextBytes);
        if (extracted == null) {
          throw StateError('Invalid PreKeySignalMessage format.');
        }
        signalMsgBytes = extracted;
      } else {
        signalMsgBytes = ciphertextBytes;
      }

      final signalMsg = SignalMessage.deserialize(data: signalMsgBytes);
      final counter = signalMsg.counter();
      final ratchetKey = _bytesToHex(signalMsg.senderRatchetKey());
      await _enforceDoubleRatchetHardening(
        senderId: senderUid,
        ratchetKey: ratchetKey,
        counter: counter,
        isHidden: isHidden,
      );
    }

    final signalMsg = CiphertextMessage.fromRaw(
      messageType: messageType,
      ciphertext: ciphertextBytes,
    );

    final decryptedBytes = await sessionCipher.decrypt(senderAddress, signalMsg);
    
    final String decryptedText;
    AttachmentEntity? localAttachment;

    if (attachmentData != null) {
      final hexMediaKey = _bytesToHex(decryptedBytes);
      final attachmentId = attachmentData['id'] as String;
      final fileName = attachmentData['fileName'] as String;
      final mimeType = attachmentData['mimeType'] as String;
      final size = attachmentData['size'] as int;
      final remotePath = attachmentData['remotePath'] as String;
      final thumbnailPath = attachmentData['thumbnailPath'] as String?;
      final checksumSha256 = attachmentData['checksumSha256'] as String?;
      final encryptionVersion = attachmentData['encryptionVersion'] as int? ?? 1;
      final duration = attachmentData['duration'] as int?;
      final waveform = attachmentData['waveform'] as String?;

      localAttachment = AttachmentEntity(
        id: attachmentId,
        messageId: messageId,
        type: AttachmentType.fromJson(incomingMessageType ?? 'file'),
        fileName: fileName,
        mimeType: mimeType,
        size: size,
        status: 'queued',
        remotePath: remotePath,
        thumbnailPath: thumbnailPath,
        keyPayload: hexMediaKey,
        checksumSha256: checksumSha256,
        encryptionVersion: encryptionVersion,
        duration: duration,
        waveform: waveform,
        createdAt: DateTime.now().toUtc(),
      );
      decryptedText = '[Media Attachment]';
    } else {
      decryptedText = String.fromCharCodes(decryptedBytes);
    }

    // If we decrypted using a skipped key, delete it from the DB!
    if (messageType == 2 || messageType == 3) {
      final Uint8List signalMsgBytes;
      if (messageType == 3) {
        final extracted = _extractWhisperMessageFromPreKeyMessage(ciphertextBytes);
        if (extracted != null) {
          signalMsgBytes = extracted;
          final signalMsgObj = SignalMessage.deserialize(data: signalMsgBytes);
          final counter = signalMsgObj.counter();
          final ratchetKey = _bytesToHex(signalMsgObj.senderRatchetKey());
          await _messagingRepository.deleteSkippedKey(
            senderUid,
            ratchetKey,
            counter,
            isHidden,
          );
        }
      } else {
        signalMsgBytes = ciphertextBytes;
        final signalMsgObj = SignalMessage.deserialize(data: signalMsgBytes);
        final counter = signalMsgObj.counter();
        final ratchetKey = _bytesToHex(signalMsgObj.senderRatchetKey());
        await _messagingRepository.deleteSkippedKey(
          senderUid,
          ratchetKey,
          counter,
          isHidden,
        );
      }
    }

    // Save message locally (Store-Before-Delete timing)
    final msg = MessageEntity(
      id: messageId,
      conversationId: conversationId,
      senderId: senderUid,
      encryptedContent: decryptedText,
      nonce: '',
      state: 'delivered',
      messageType: incomingMessageType ?? 'text',
      createdAt: DateTime.now().toUtc(),
    );

    await _messagingRepository.insertMessage(msg);
    if (localAttachment != null) {
      await _messagingRepository.insertAttachment(localAttachment);
    }
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

  /// Encrypts and sends a secure E2EE media attachment message
  Future<void> sendSecureMediaMessage({
    required String targetUid,
    required AttachmentEntity attachment,
  }) async {
    final currentUid = Firebase.apps.isEmpty
        ? 'alice_uid'
        : FirebaseAuth.instance.currentUser!.uid;

    final conversationId = '${currentUid}_$targetUid';
    final existingConv = await _messagingRepository.getConversationById(conversationId);
    if (existingConv != null && existingConv.isBlocked) {
      throw StateError('BLOCKED_CONTACT');
    }

    final isHidden = existingConv?.isHidden ?? true;
    final signalStore = SignalStoreImpl(_secureStorage, _identityService, _messagingRepository, isHidden: isHidden);
    final bobAddress = ProtocolAddress(name: targetUid, deviceId: 1);
    final localAddress = ProtocolAddress(name: currentUid, deviceId: 1);

    if (!await signalStore.containsSession(bobAddress)) {
      final participant = await _messagingRepository.getParticipantById(targetUid);
      if (participant == null) throw Exception('Participant not found locally.');
      final cleanUsername = participant.username.replaceAll('@', '');
      await initiateSession(targetUsername: cleanUsername, isHidden: isHidden);
    }

    final sessionCipher = SessionCipher(
      localAddress: localAddress,
      sessionStore: signalStore,
      identityKeyStore: signalStore,
      preKeyStore: signalStore,
      signedPreKeyStore: signalStore,
      kyberPreKeyStore: signalStore,
    );

    // 1. Get raw Media Key
    final hexMediaKey = attachment.keyPayload;
    if (hexMediaKey == null || hexMediaKey.isEmpty) {
      throw StateError('Attachment has no encryption key payload');
    }
    final rawMediaKey = _hexToBytes(hexMediaKey);

    // 2. Encrypt Media Key for recipient via Double Ratchet session cipher
    final ciphertextMessage = await sessionCipher.encrypt(bobAddress, rawMediaKey);
    final keyRecipientHex = _bytesToHex(ciphertextMessage.ciphertext);
    final recipientType = ciphertextMessage.type.value;

    // 3. Encrypt Media Key for Compliance Escrow via X25519 ECIES
    var compKeyHex = '03c3a9d7211bf5a3cfb403487053e1a6c0b9e830e0176cd1f1e847c2130dfa2e'; // default test key
    var compKeyVersion = 1;

    if (Firebase.apps.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('compliance').doc('config').get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data['current'] != null) {
            final currentData = data['current'] as Map<String, dynamic>;
            compKeyHex = currentData['publicKey'] as String;
            compKeyVersion = currentData['keyVersion'] as int;
          }
        }
      } catch (e) {
        AppLogger.warning('[SignalSessionManager] Failed to fetch current compliance key from Firestore: $e');
      }
    }

    final escrowBlock = await MediaCryptor.encryptKeyForCompliance(rawMediaKey, compKeyHex);

    // 4. Build message payload for Firestore
    final messageId = attachment.messageId;
    final messageData = {
      'id': messageId,
      'senderUid': currentUid,
      'ciphertext': '', // empty for media type, payload in attachment
      'type': recipientType,
      'messageType': attachment.type.name,
      'attachment': {
        'id': attachment.id,
        'fileName': attachment.fileName,
        'mimeType': attachment.mimeType,
        'size': attachment.size,
        'remotePath': attachment.remotePath,
        'thumbnailPath': attachment.thumbnailPath,
        'checksumSha256': attachment.checksumSha256,
        'encryptionVersion': attachment.encryptionVersion,
        'keyRecipient': keyRecipientHex,
        'duration': attachment.duration,
        'waveform': attachment.waveform,
        'keyEscrow': {
          ...escrowBlock,
          'keyVersion': compKeyVersion,
        },
      }
    };

    if (Firebase.apps.isEmpty && mockSyncQueues != null) {
      mockSyncQueues!.putIfAbsent(targetUid, () => []).add(messageData);
    } else if (Firebase.apps.isNotEmpty) {
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
    } else {
      AppLogger.warning('[SignalSessionManager] Dev mode: skipping Firestore media message sync queue push (no Firebase, no mock).');
    }

    // 5. Insert or update E2EE message locally
    final localMsg = MessageEntity(
      id: messageId,
      conversationId: conversationId,
      senderId: currentUid,
      encryptedContent: '[Media Attachment]',
      nonce: '',
      state: 'sent',
      messageType: attachment.type.name,
      createdAt: DateTime.now().toUtc(),
    );
    
    final existingMsg = await _messagingRepository.getMessageById(messageId);
    if (existingMsg == null) {
      await _messagingRepository.insertMessage(localMsg);
    } else {
      await _messagingRepository.updateMessageState(messageId, 'sent');
    }
    await _messagingRepository.updateConversationLastMessage(conversationId, messageId);

    // Link or update the attachment locally
    final finalAttachment = attachment.copyWith(messageId: messageId);
    final existingAttachment = await _messagingRepository.getAttachmentById(finalAttachment.id);
    if (existingAttachment == null) {
      await _messagingRepository.insertAttachment(finalAttachment);
    } else {
      await _messagingRepository.updateAttachmentRemotePaths(
        finalAttachment.id,
        finalAttachment.remotePath,
        finalAttachment.thumbnailPath,
      );
      await _messagingRepository.updateAttachmentState(
        finalAttachment.id,
        'completed',
      );
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
    } else if (Firebase.apps.isNotEmpty) {
      final firestore = FirebaseFirestore.instance;
      final pseudonymDoc = await firestore.collection('pseudonyms').doc(cleanUsername).get();
      if (!pseudonymDoc.exists) {
        throw Exception('Target username not found in directory.');
      }
      bobUid = pseudonymDoc.get('uid') as String;
      bobIdentityKeyPub = pseudonymDoc.get('identityPublicKey') as String;
    } else {
      throw Exception('[SignalSessionManager] Firebase not available and no mock data. Cannot re-approve identity for $cleanUsername.');
    }

    // 1. Update participant to the new key and set trustState = 'accepted'
    await _messagingRepository.createOrUpdateParticipant(
      id: bobUid,
      username: participant.username,
      identityKeyPub: bobIdentityKeyPub,
      trustState: 'accepted',
    );

    // 2. Clear old session in store to force a clean re-handshake
    final signalStore = SignalStoreImpl(_secureStorage, _identityService, _messagingRepository, isHidden: true);
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
        final signalStore = SignalStoreImpl(_secureStorage, _identityService, _messagingRepository, isHidden: true);
        final existingIds = await signalStore.getAllPreKeyIds();
        final int startId = existingIds.isEmpty ? 1 : (existingIds.reduce((a, b) => a > b ? a : b) + 1);

        for (int i = 0; i < 80; i++) {
          final id = startId + i;
          final keyPair = PrivateKey.generate();
          final otRecord = PreKeyRecord(
            id: id,
            publicKey: keyPair.getPublicKey(),
            privateKey: keyPair,
          );
          await signalStore.storePreKey(id, otRecord);
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
        final signalStore = SignalStoreImpl(_secureStorage, _identityService, _messagingRepository, isHidden: true);
        final existingIds = await signalStore.getAllPreKeyIds();
        final int startId = existingIds.isEmpty ? 1 : (existingIds.reduce((a, b) => a > b ? a : b) + 1);

        for (int i = 0; i < 80; i++) {
          final id = startId + i;
          final keyPair = PrivateKey.generate();
          final otRecord = PreKeyRecord(
            id: id,
            publicKey: keyPair.getPublicKey(),
            privateKey: keyPair,
          );

          // Save locally in SQLCipher
          await signalStore.storePreKey(id, otRecord);

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

  static Uint8List? _extractWhisperMessageFromPreKeyMessage(Uint8List preKeyBytes) {
    if (preKeyBytes.isEmpty) return null;
    int index = 1; // skip version/type byte
    while (index < preKeyBytes.length) {
      // Read key varint
      int key = 0;
      int shift = 0;
      while (index < preKeyBytes.length) {
        int b = preKeyBytes[index++];
        key |= (b & 0x7F) << shift;
        if ((b & 0x80) == 0) break;
        shift += 7;
      }
      int tag = key >> 3;
      int wireType = key & 0x7;

      if (tag == 4 && wireType == 2) {
        // Read length varint
        int length = 0;
        int lShift = 0;
        while (index < preKeyBytes.length) {
          int b = preKeyBytes[index++];
          length |= (b & 0x7F) << lShift;
          if ((b & 0x80) == 0) break;
          lShift += 7;
        }
        if (index + length <= preKeyBytes.length) {
          return Uint8List.sublistView(preKeyBytes, index, index + length);
        }
        return null;
      } else {
        // Skip field
        if (wireType == 0) { // Varint
          while (index < preKeyBytes.length) {
            int b = preKeyBytes[index++];
            if ((b & 0x80) == 0) break;
          }
        } else if (wireType == 1) { // 64-bit
          index += 8;
        } else if (wireType == 2) { // Length-delimited
          int length = 0;
          int lShift = 0;
          while (index < preKeyBytes.length) {
            int b = preKeyBytes[index++];
            length |= (b & 0x7F) << lShift;
            if ((b & 0x80) == 0) break;
            lShift += 7;
          }
          index += length;
        } else if (wireType == 5) { // 32-bit
          index += 4;
        } else {
          // Unknown or group start/end, let's stop
          break;
        }
      }
    }
    return null;
  }

  /// Validates sequence numbers, stores skipped keys, limits them to 100, and prevents replay attacks.
  Future<void> _enforceDoubleRatchetHardening({
    required String senderId,
    required String ratchetKey,
    required int counter,
    required bool isHidden,
  }) async {
    final maxSeqStr = await _messagingRepository.getSyncMetadata('max_seq:${senderId}:${ratchetKey}');
    final maxSeq = maxSeqStr != null ? int.parse(maxSeqStr) : -1;

    if (counter <= maxSeq) {
      // Check if skipped key exists
      final exists = await _messagingRepository.checkSkippedKeyExists(
        senderId,
        ratchetKey,
        counter,
        isHidden,
      );
      if (!exists) {
        throw StateError('REPLAYED_MESSAGE');
      }
    } else {
      // Check if we skipped any sequence numbers
      final skippedCount = counter - (maxSeq + 1);
      if (skippedCount > 0) {
        // Enforce the 100 skipped keys limit
        final currentSkippedCount = await _messagingRepository.getSkippedKeysCount(senderId, isHidden);
        if (currentSkippedCount + skippedCount > 100) {
          throw StateError('Skipped keys limit exceeded. Potential DoS.');
        }

        // Insert skipped keys
        for (int i = maxSeq + 1; i < counter; i++) {
          await _messagingRepository.insertSkippedKey(
            senderId,
            ratchetKey,
            i,
            isHidden,
          );
        }
      }

      // Update max_seq
      await _messagingRepository.setSyncMetadata('max_seq:${senderId}:${ratchetKey}', counter.toString());
    }
  }
}
