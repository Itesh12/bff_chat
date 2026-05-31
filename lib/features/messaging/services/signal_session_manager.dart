import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:libsignal/libsignal.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';
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

    // 2. Fetch Prekey Bundle
    final String identityKeyPubHex;
    final int signedPrekeyId;
    final String signedPrekeyPublicHex;
    final String signedPrekeySignatureHex;
    final int kyberPrekeyId;
    final String kyberPrekeyPublicHex;
    final String kyberPrekeySignatureHex;
    final List<dynamic> oneTimePrekeys;

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
      oneTimePrekeys = doc['oneTimePrekeys'] as List<dynamic>;
    } else {
      final firestore = FirebaseFirestore.instance;
      final bundleDoc = await firestore.collection('prekey_bundles').doc(bobUid).get();
      if (!bundleDoc.exists) {
        throw Exception('Prekey bundle not found for target user.');
      }
      identityKeyPubHex = bundleDoc.get('identityPublicKey') as String;
      signedPrekeyId = bundleDoc.get('signedPrekeyId') as int;
      signedPrekeyPublicHex = bundleDoc.get('signedPrekeyPublic') as String;
      signedPrekeySignatureHex = bundleDoc.get('signedPrekeySignature') as String;
      kyberPrekeyId = bundleDoc.get('kyberPrekeyId') as int;
      kyberPrekeyPublicHex = bundleDoc.get('kyberPrekeyPublic') as String;
      kyberPrekeySignatureHex = bundleDoc.get('kyberPrekeySignature') as String;
      oneTimePrekeys = bundleDoc.get('oneTimePrekeys') as List<dynamic>;
    }

    final identityKeyPubBytes = _hexToBytes(identityKeyPubHex);
    final signedPrekeyPublicBytes = _hexToBytes(signedPrekeyPublicHex);
    final signedPrekeySignatureBytes = _hexToBytes(signedPrekeySignatureHex);
    final kyberPrekeyPublicBytes = _hexToBytes(kyberPrekeyPublicHex);
    final kyberPrekeySignatureBytes = _hexToBytes(kyberPrekeySignatureHex);

    int? selectedPreKeyId;
    Uint8List? selectedPreKeyPublic;

    if (oneTimePrekeys.isNotEmpty) {
      final firstPrekey = oneTimePrekeys.first as Map<String, dynamic>;
      selectedPreKeyId = firstPrekey['id'] as int;
      selectedPreKeyPublic = _hexToBytes(firstPrekey['publicKey'] as String);
    }

    // 3. Construct PreKeyBundle for libsignal
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

    // 4. Initialize Local Signal Stores
    final signalStore = SignalStoreImpl(_secureStorage, _identityService, _messagingRepository);
    final localAddress = ProtocolAddress(name: currentUid, deviceId: 1);
    final bobAddress = ProtocolAddress(name: bobUid, deviceId: 1);

    final sessionBuilder = SessionBuilder(
      localAddress: localAddress,
      sessionStore: signalStore,
      identityKeyStore: signalStore,
    );

    // 5. Process Bundle to derive shared secret and initial session
    await sessionBuilder.processPreKeyBundle(bobAddress, bobBundle);

    // 6. Save Participant and Conversation Locally
    await _messagingRepository.createOrUpdateParticipant(
      id: bobUid,
      username: targetUsername,
      identityKeyPub: _bytesToHex(identityKeyPubBytes),
      trustState: 'accepted',
    );

    final conversationId = '${currentUid}_$bobUid';
    await _messagingRepository.createConversation(
      id: conversationId,
      participantId: bobUid,
      isHidden: isHidden,
    );

    // 7. Encrypt initial handshake message to initiate the handshake envelope
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

    // 8. Post to Bob's sync queue
    final messageId = DateTime.now().microsecondsSinceEpoch.toString();
    final messageData = {
      'id': messageId,
      'senderUid': currentUid,
      'ciphertext': _bytesToHex(ciphertextMessage.ciphertext),
      'type': ciphertextMessage.type.value, // preKey (type 3)
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
  }
}
