import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal/libsignal.dart';
import 'package:drift/native.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/core/services/database_service.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/features/hidden/services/hidden_vault_service.dart';
import 'package:memovault/features/hidden/services/pin_hashing_service.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/features/hidden/services/seed_recovery_service.dart';
import 'package:memovault/data/messaging/messaging_repository_impl.dart';
import 'package:memovault/features/messaging/services/signal_session_manager.dart';
import 'package:memovault/features/messaging/services/signal_store_impl.dart';
import 'package:memovault/features/messaging/services/signal_sync_service.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';
import 'package:memovault/domain/messaging/message_entity.dart';
import 'package:get/get.dart';
import 'package:memovault/features/hidden/controllers/hidden_chat_controller.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';
import 'package:memovault/core/config/env_config.dart';

class _FakeSecureStorageService implements SecureStorageService {
  final Map<String, String> _data = {};

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    return _data[key];
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clearAll() async {
    _data.clear();
  }
}

class _FakeDatabaseService extends DatabaseService {
  final AppDatabase _dbInstance;
  _FakeDatabaseService(this._dbInstance);

  @override
  AppDatabase get db => _dbInstance;
}

class _FakeHiddenVaultService extends HiddenVaultService {
  _FakeHiddenVaultService() : super(_FakeSecureStorageService(), PinHashingService());

  HiddenVaultDatabase? mockDb;

  @override
  HiddenVaultDatabase? get db => mockDb;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Messaging Cryptographic Handshake & Session Integration Tests', () {
    setUpAll(() async {
      EnvConfig.isTest = true;
      await LibSignal.init();
    });

    late _FakeSecureStorageService aliceStorage;
    late MessagingIdentityService aliceIdentityService;
    late AppDatabase aliceDb;
    late MessagingRepositoryImpl aliceRepo;
    late SignalSessionManager aliceSessionManager;
    late _FakeHiddenVaultService aliceFakeVault;

    late _FakeSecureStorageService bobStorage;
    late MessagingIdentityService bobIdentityService;
    late AppDatabase bobDb;
    late MessagingRepositoryImpl bobRepo;
    late SignalSessionManager bobSessionManager;
    late _FakeHiddenVaultService bobFakeVault;

    final seedRecoveryService = SeedRecoveryServiceImpl();

    setUp(() async {
      // 1. Initialize Alice's dependencies
      aliceStorage = _FakeSecureStorageService();
      aliceIdentityService = MessagingIdentityServiceImpl(aliceStorage);
      aliceDb = AppDatabase(NativeDatabase.memory());
      aliceFakeVault = _FakeHiddenVaultService();
      aliceFakeVault.mockDb = HiddenVaultDatabase(NativeDatabase.memory());
      aliceRepo = MessagingRepositoryImpl(
        _FakeDatabaseService(aliceDb),
        aliceFakeVault,
      );
      aliceSessionManager = SignalSessionManager(
        aliceIdentityService,
        aliceRepo,
        aliceStorage,
      );

      // Register Alice's services globally in Get for the controllers under test
      Get.put<MessagingIdentityService>(aliceIdentityService);
      Get.put<SignalSessionManager>(aliceSessionManager);

      // 2. Initialize Bob's dependencies
      bobStorage = _FakeSecureStorageService();
      bobIdentityService = MessagingIdentityServiceImpl(bobStorage);
      bobDb = AppDatabase(NativeDatabase.memory());
      bobFakeVault = _FakeHiddenVaultService();
      bobFakeVault.mockDb = HiddenVaultDatabase(NativeDatabase.memory());
      bobRepo = MessagingRepositoryImpl(
        _FakeDatabaseService(bobDb),
        bobFakeVault,
      );
      bobSessionManager = SignalSessionManager(
        bobIdentityService,
        bobRepo,
        bobStorage,
      );

      // 3. Reset mock state for SignalSessionManager
      SignalSessionManager.mockPseudonyms = {};
      SignalSessionManager.mockPrekeyBundles = {};
      SignalSessionManager.mockSyncQueues = {};
    });

    tearDown(() async {
      await aliceDb.close();
      await bobDb.close();
      if (aliceFakeVault.mockDb != null) await aliceFakeVault.mockDb!.close();
      if (bobFakeVault.mockDb != null) await bobFakeVault.mockDb!.close();

      await Get.delete<MessagingIdentityService>();
      await Get.delete<SignalSessionManager>();
    });

    test('Alice & Bob onboard, execute secure X3DH/PQXDH handshake, and establish active Double Ratchet session', () async {
      const aliceMnemonic = 'abandon ability able about above absent absorb abstract act action actor actress';
      const bobMnemonic = 'amazing among amount amused analyst anchor ancient anger angle angry animal ankle';

      // ─── Step 1: Onboard Alice ───
      final alicePriv = seedRecoveryService.derivePrivateKey(aliceMnemonic);
      final alicePub = seedRecoveryService.derivePublicKey(alicePriv);
      await aliceIdentityService.saveIdentityKeys(pubKey: alicePub, privKey: alicePriv);

      // Generate Alice's prekey bundle locally
      const aliceSignedPreKeyId = 1;
      final aliceSignedPreKeyPair = PrivateKey.generate();
      final aliceSignedPreKeyPublic = aliceSignedPreKeyPair.getPublicKey();
      final aliceIdentityKey = PrivateKey.deserialize(bytes: _hexToBytes(alicePriv));
      final aliceSignedPreKeySignature = aliceIdentityKey.sign(
        message: aliceSignedPreKeyPublic.serialize(),
      );

      final aliceKyberKeyPair = KyberKeyPair.generate();
      final aliceKyberSignature = aliceIdentityKey.sign(
        message: aliceKyberKeyPair.getPublicKey().serialize(),
      );

      final aliceSignedPreKeyRecord = SignedPreKeyRecord(
        id: aliceSignedPreKeyId,
        timestamp: BigInt.from(DateTime.now().millisecondsSinceEpoch),
        publicKey: aliceSignedPreKeyPublic,
        privateKey: aliceSignedPreKeyPair,
        signature: aliceSignedPreKeySignature,
      );
      await aliceStorage.write('signed_prekey_record_$aliceSignedPreKeyId', _bytesToHex(aliceSignedPreKeyRecord.serialize()));

      final aliceKyberRecord = KyberPreKeyRecord.create(
        id: 1,
        timestamp: BigInt.from(DateTime.now().millisecondsSinceEpoch),
        keyPair: aliceKyberKeyPair,
        signature: aliceKyberSignature,
      );
      await aliceStorage.write('kyber_prekey_record_1', _bytesToHex(aliceKyberRecord.serialize()));

      // ─── Step 2: Onboard Bob ───
      final bobPriv = seedRecoveryService.derivePrivateKey(bobMnemonic);
      final bobPub = seedRecoveryService.derivePublicKey(bobPriv);
      await bobIdentityService.saveIdentityKeys(pubKey: bobPub, privKey: bobPriv);

      const bobSignedPreKeyId = 1;
      final bobSignedPreKeyPair = PrivateKey.generate();
      final bobSignedPreKeyPublic = bobSignedPreKeyPair.getPublicKey();
      final bobIdentityKey = PrivateKey.deserialize(bytes: _hexToBytes(bobPriv));
      final bobSignedPreKeySignature = bobIdentityKey.sign(
        message: bobSignedPreKeyPublic.serialize(),
      );

      final bobKyberKeyPair = KyberKeyPair.generate();
      final bobKyberSignature = bobIdentityKey.sign(
        message: bobKyberKeyPair.getPublicKey().serialize(),
      );

      final bobSignedPreKeyRecord = SignedPreKeyRecord(
        id: bobSignedPreKeyId,
        timestamp: BigInt.from(DateTime.now().millisecondsSinceEpoch),
        publicKey: bobSignedPreKeyPublic,
        privateKey: bobSignedPreKeyPair,
        signature: bobSignedPreKeySignature,
      );
      await bobStorage.write('signed_prekey_record_$bobSignedPreKeyId', _bytesToHex(bobSignedPreKeyRecord.serialize()));

      final bobKyberRecord = KyberPreKeyRecord.create(
        id: 1,
        timestamp: BigInt.from(DateTime.now().millisecondsSinceEpoch),
        keyPair: bobKyberKeyPair,
        signature: bobKyberSignature,
      );
      await bobStorage.write('kyber_prekey_record_1', _bytesToHex(bobKyberRecord.serialize()));

      // Store a one-time prekey for Bob
      final bobOtKeyPair = PrivateKey.generate();
      final bobOtRecord = PreKeyRecord(
        id: 1,
        publicKey: bobOtKeyPair.getPublicKey(),
        privateKey: bobOtKeyPair,
      );
      await bobStorage.write('ot_prekey_record_1', _bytesToHex(bobOtRecord.serialize()));

      // ─── Step 3: Populate Mock Pseudonym Directory ───
      SignalSessionManager.mockPseudonyms = {
        'alice_username': {
          'uid': 'alice_uid',
          'displayName': 'Alice',
          'identityPublicKey': alicePub,
        },
        'bob_username': {
          'uid': 'bob_uid',
          'displayName': 'Bob',
          'identityPublicKey': bobPub,
        }
      };

      SignalSessionManager.mockPrekeyBundles = {
        'bob_uid': {
          'identityPublicKey': bobPub,
          'signedPrekeyId': bobSignedPreKeyId,
          'signedPrekeyPublic': _bytesToHex(bobSignedPreKeyPublic.serialize()),
          'signedPrekeySignature': _bytesToHex(bobSignedPreKeySignature),
          'kyberPrekeyId': 1,
          'kyberPrekeyPublic': _bytesToHex(bobKyberKeyPair.getPublicKey().serialize()),
          'kyberPrekeySignature': _bytesToHex(bobKyberSignature),
          'oneTimePrekeys': [
            {
              'id': 1,
              'publicKey': _bytesToHex(bobOtKeyPair.getPublicKey().serialize()),
            }
          ]
        }
      };

      // ─── Step 4: Alice Initiates Handshake with Bob ───
      await aliceSessionManager.initiateSession(
        targetUsername: 'bob_username',
        isHidden: false,
      );

      // Verify Alice has Bob in her database now
      final aliceBobContact = await aliceRepo.getParticipantById('bob_uid');
      expect(aliceBobContact, isNotNull);
      expect(aliceBobContact!.username, 'bob_username');
      expect(aliceBobContact.identityKeyPub, bobPub);
      expect(aliceBobContact.trustState, 'accepted');

      final aliceBobConv = await aliceRepo.getConversationById('alice_uid_bob_uid');
      expect(aliceBobConv, isNotNull);
      expect(aliceBobConv!.participantId, 'bob_uid');

      // Verify initial handshake message is pushed to Bob's sync queue
      final bobQueue = SignalSessionManager.mockSyncQueues!['bob_uid'];
      expect(bobQueue, isNotNull);
      expect(bobQueue!.length, 1);
      final handshakeMsgData = bobQueue.first;
      expect(handshakeMsgData['senderUid'], 'alice_uid');

      // ─── Step 5: Bob Receives & Processes Handshake from Alice ───
      await bobSessionManager.receiveHandshake(
        senderUid: 'alice_uid',
        ciphertextHex: handshakeMsgData['ciphertext'] as String,
        messageType: handshakeMsgData['type'] as int,
        senderUsername: 'alice_username',
        senderIdentityKeyPubHex: alicePub,
        isHidden: false,
      );

      // Verify Bob has Alice in his database
      final bobAliceContact = await bobRepo.getParticipantById('alice_uid');
      expect(bobAliceContact, isNotNull);
      expect(bobAliceContact!.username, 'alice_username');
      expect(bobAliceContact.identityKeyPub, alicePub);
      expect(bobAliceContact.trustState, 'accepted');

      final bobAliceConv = await bobRepo.getConversationById('bob_uid_alice_uid');
      expect(bobAliceConv, isNotNull);

      // ─── Step 6: Verify Bidirectional Encryption works ───
      final aliceStore = SignalStoreImpl(aliceStorage, aliceIdentityService, aliceRepo);
      final bobStore = SignalStoreImpl(bobStorage, bobIdentityService, bobRepo);

      final aliceCipher = SessionCipher(
        localAddress: ProtocolAddress(name: 'alice_uid', deviceId: 1),
        sessionStore: aliceStore,
        identityKeyStore: aliceStore,
        preKeyStore: aliceStore,
        signedPreKeyStore: aliceStore,
        kyberPreKeyStore: aliceStore,
      );

      final bobCipher = SessionCipher(
        localAddress: ProtocolAddress(name: 'bob_uid', deviceId: 1),
        sessionStore: bobStore,
        identityKeyStore: bobStore,
        preKeyStore: bobStore,
        signedPreKeyStore: bobStore,
        kyberPreKeyStore: bobStore,
      );

      // Alice sends message to Bob
      final messageBytes = Uint8List.fromList('Hello Bob!'.codeUnits);
      final encryptedMsg = await aliceCipher.encrypt(
        ProtocolAddress(name: 'bob_uid', deviceId: 1),
        messageBytes,
      );

      // Bob decrypts it
      final decryptedBytes = await bobCipher.decrypt(
        ProtocolAddress(name: 'alice_uid', deviceId: 1),
        encryptedMsg,
      );
      expect(String.fromCharCodes(decryptedBytes), 'Hello Bob!');
    });

    test('Key Change safety warn: detects changed identityPublicKey, blocks messaging, and revokes trustState', () async {
      // Setup initial trusted contact for Bob inside Alice's repository
      final initialBob = await aliceRepo.createOrUpdateParticipant(
        id: 'bob_uid',
        username: 'bob_username',
        identityKeyPub: 'original_identity_key_pub_hex',
        trustState: 'accepted',
      );
      expect(initialBob.trustState, 'accepted');

      // Bob rotates key: directory now returns a different key!
      SignalSessionManager.mockPseudonyms = {
        'bob_username': {
          'uid': 'bob_uid',
          'displayName': 'Bob',
          'identityPublicKey': 'new_rotated_identity_key_pub_hex', // Changed key!
        }
      };

      // Alice tries to initiate a session with Bob
      await expectLater(
        aliceSessionManager.initiateSession(targetUsername: 'bob_username', isHidden: false),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'IDENTITY_KEY_CHANGED')),
      );

      // Verify Alice has set Bob's trust state to 'revoked'
      final updatedBob = await aliceRepo.getParticipantById('bob_uid');
      expect(updatedBob, isNotNull);
      expect(updatedBob!.identityKeyPub, 'original_identity_key_pub_hex'); // Retained original
      expect(updatedBob.trustState, 'revoked'); // Trust revoked!
    });

    test('Sprint 7: Bidirectional E2EE Messaging via Sync Queues & Store-Before-Delete', () async {
      // 1. Setup session between Alice and Bob
      final alicePriv = seedRecoveryService.derivePrivateKey('abandon ability able about above absent absorb abstract act action actor actress');
      final alicePub = seedRecoveryService.derivePublicKey(alicePriv);
      await aliceIdentityService.saveIdentityKeys(pubKey: alicePub, privKey: alicePriv);

      final bobPriv = seedRecoveryService.derivePrivateKey('amazing among amount amused analyst anchor ancient anger angle angry animal ankle');
      final bobPub = seedRecoveryService.derivePublicKey(bobPriv);
      await bobIdentityService.saveIdentityKeys(pubKey: bobPub, privKey: bobPriv);

      // Register pseudonyms
      SignalSessionManager.mockPseudonyms = {
        'alice_username': {'uid': 'alice_uid', 'displayName': 'Alice', 'identityPublicKey': alicePub},
        'bob_username': {'uid': 'bob_uid', 'displayName': 'Bob', 'identityPublicKey': bobPub}
      };

      // Generate Bob Signed Prekey & OTP
      final bobSignedPreKeyPair = PrivateKey.generate();
      final bobIdentityKey = PrivateKey.deserialize(bytes: _hexToBytes(bobPriv));
      final bobSignedPreKeySignature = bobIdentityKey.sign(message: bobSignedPreKeyPair.getPublicKey().serialize());
      final bobKyberKeyPair = KyberKeyPair.generate();
      final bobKyberSignature = bobIdentityKey.sign(message: bobKyberKeyPair.getPublicKey().serialize());
      final bobOtKeyPair = PrivateKey.generate();

      SignalSessionManager.mockPrekeyBundles = {
        'bob_uid': {
          'identityPublicKey': bobPub,
          'signedPrekeyId': 1,
          'signedPrekeyPublic': _bytesToHex(bobSignedPreKeyPair.getPublicKey().serialize()),
          'signedPrekeySignature': _bytesToHex(bobSignedPreKeySignature),
          'kyberPrekeyId': 1,
          'kyberPrekeyPublic': _bytesToHex(bobKyberKeyPair.getPublicKey().serialize()),
          'kyberPrekeySignature': _bytesToHex(bobKyberSignature),
          'oneTimePrekeys': [
            {'id': 1, 'publicKey': _bytesToHex(bobOtKeyPair.getPublicKey().serialize())}
          ]
        }
      };

      // Set Bob's storage with signed/OT keys
      final bobSignedPreKeyRecord = SignedPreKeyRecord(
        id: 1,
        timestamp: BigInt.from(123456),
        publicKey: bobSignedPreKeyPair.getPublicKey(),
        privateKey: bobSignedPreKeyPair,
        signature: bobSignedPreKeySignature,
      );
      await bobStorage.write('signed_prekey_record_1', _bytesToHex(bobSignedPreKeyRecord.serialize()));

      final bobKyberRecord = KyberPreKeyRecord.create(
        id: 1,
        timestamp: BigInt.from(123456),
        keyPair: bobKyberKeyPair,
        signature: bobKyberSignature,
      );
      await bobStorage.write('kyber_prekey_record_1', _bytesToHex(bobKyberRecord.serialize()));

      final bobOtRecord = PreKeyRecord(
        id: 1,
        publicKey: bobOtKeyPair.getPublicKey(),
        privateKey: bobOtKeyPair,
      );
      await bobStorage.write('ot_prekey_record_1', _bytesToHex(bobOtRecord.serialize()));

      // Run Alice initiate session
      await aliceSessionManager.initiateSession(targetUsername: 'bob_username', isHidden: true);

      // Bob's sync queue has the handshake message
      expect(SignalSessionManager.mockSyncQueues!['bob_uid']!.length, 1);

      // Create Bob's Sync Service
      final bobSessionService = _FakeHiddenSessionService();
      final bobSyncService = SignalSyncService(bobSessionManager, bobIdentityService, bobSessionService, bobRepo);

      // Bob processes his sync queue (Store-Before-Delete)
      await bobSyncService.testProcessMockQueue('bob_uid');

      // Sync queue has been consumed and is now empty
      expect(SignalSessionManager.mockSyncQueues!['bob_uid']!.isEmpty, true);

      // Bob has Alice in his participants list
      final bobAliceContact = await bobRepo.getParticipantById('alice_uid');
      expect(bobAliceContact, isNotNull);
      expect(bobAliceContact!.trustState, 'accepted');

      // Now send message Alice -> Bob
      await aliceSessionManager.sendSecureMessage(targetUid: 'bob_uid', plaintext: 'Hello Bob!');

      // Bob's sync queue has 1 message
      expect(SignalSessionManager.mockSyncQueues!['bob_uid']!.length, 1);
      final msgId = SignalSessionManager.mockSyncQueues!['bob_uid']!.first['id'];

      // Process it
      await bobSyncService.testProcessMockQueue('bob_uid');

      // Verify stored locally
      final storedMsg = await bobRepo.getMessageById(msgId);
      expect(storedMsg, isNotNull);
      expect(storedMsg!.encryptedContent, 'Hello Bob!');
      expect(storedMsg.senderId, 'alice_uid');
    });

    test('Sprint 7: Concurrency & Transactional OTP Reservation', () async {
      final alicePriv = seedRecoveryService.derivePrivateKey('abandon ability able about above absent absorb abstract act action actor actress');
      final alicePub = seedRecoveryService.derivePublicKey(alicePriv);
      await aliceIdentityService.saveIdentityKeys(pubKey: alicePub, privKey: alicePriv);

      final bobPriv = seedRecoveryService.derivePrivateKey('amazing among amount amused analyst anchor ancient anger angle angry animal ankle');
      final bobPub = seedRecoveryService.derivePublicKey(bobPriv);
      await bobIdentityService.saveIdentityKeys(pubKey: bobPub, privKey: bobPriv);

      SignalSessionManager.mockPseudonyms = {
        'bob_username': {'uid': 'bob_uid', 'displayName': 'Bob', 'identityPublicKey': bobPub}
      };

      // Bob has exactly 1 OTP
      final bobSignedPreKeyPair = PrivateKey.generate();
      final bobIdentityKey = PrivateKey.deserialize(bytes: _hexToBytes(bobPriv));
      final bobSignedPreKeySignature = bobIdentityKey.sign(message: bobSignedPreKeyPair.getPublicKey().serialize());
      final bobKyberKeyPair = KyberKeyPair.generate();
      final bobKyberSignature = bobIdentityKey.sign(message: bobKyberKeyPair.getPublicKey().serialize());
      final bobOtKeyPair = PrivateKey.generate();

      SignalSessionManager.mockPrekeyBundles = {
        'bob_uid': {
          'identityPublicKey': bobPub,
          'signedPrekeyId': 1,
          'signedPrekeyPublic': _bytesToHex(bobSignedPreKeyPair.getPublicKey().serialize()),
          'signedPrekeySignature': _bytesToHex(bobSignedPreKeySignature),
          'kyberPrekeyId': 1,
          'kyberPrekeyPublic': _bytesToHex(bobKyberKeyPair.getPublicKey().serialize()),
          'kyberPrekeySignature': _bytesToHex(bobKyberSignature),
          'oneTimePrekeys': [
            {'id': 42, 'publicKey': _bytesToHex(bobOtKeyPair.getPublicKey().serialize())}
          ]
        }
      };

      // Alice initiates -> consumes the OTP
      await aliceSessionManager.initiateSession(targetUsername: 'bob_username', isHidden: false);

      // Verify OTP 42 was popped and is no longer present in Bob's prekey bundle
      final oneTimePrekeys = SignalSessionManager.mockPrekeyBundles!['bob_uid']!['oneTimePrekeys'] as List;
      expect(oneTimePrekeys.isEmpty, true);
    });

    test('Sprint 7: OTP Depletion and Auto-Replenishment', () async {
      // Mock Bob's prekey bundle with 0 OTPs
      SignalSessionManager.mockPrekeyBundles = {
        'bob_uid': {
          'identityPublicKey': 'bob_pub',
          'oneTimePrekeys': []
        }
      };

      // Trigger replenishment check for Bob (threshold is < 20)
      await bobSessionManager.checkAndReplenishOneTimePrekeys();

      // Verify that Bob's mock prekey bundle is replenished with 80 new OTPs
      final oneTimePrekeys = List<Map<String, dynamic>>.from(
        SignalSessionManager.mockPrekeyBundles!['bob_uid']!['oneTimePrekeys'] as List,
      );
      expect(oneTimePrekeys.length, 80);
      expect(oneTimePrekeys.first['id'], isNotNull);
    });

    test('Sprint 7: Handshake TTL Cleanup Sweeps Handshake Messages', () async {
      // Create local handshake messages
      final now = DateTime.now().toUtc();
      final oldHandshake = MessageEntity(
        id: 'old_handshake_id',
        conversationId: 'alice_uid_bob_uid',
        senderId: 'bob_uid',
        encryptedContent: 'Handshake message',
        nonce: '',
        state: 'delivered',
        messageType: 'handshake',
        createdAt: now.subtract(const Duration(days: 8)), // Exceeded 7 days TTL
      );

      final newHandshake = MessageEntity(
        id: 'new_handshake_id',
        conversationId: 'alice_uid_bob_uid',
        senderId: 'bob_uid',
        encryptedContent: 'Handshake message',
        nonce: '',
        state: 'delivered',
        messageType: 'handshake',
        createdAt: now.subtract(const Duration(days: 3)), // Within 7 days
      );

      final normalMessage = MessageEntity(
        id: 'normal_msg_id',
        conversationId: 'alice_uid_bob_uid',
        senderId: 'bob_uid',
        encryptedContent: 'Normal text message',
        nonce: '',
        state: 'delivered',
        messageType: 'text',
        createdAt: now.subtract(const Duration(days: 10)), // Normal messages are NOT swept
      );

      // Create conversation
      await aliceRepo.createOrUpdateParticipant(id: 'bob_uid', username: 'bob', identityKeyPub: 'pub');
      await aliceRepo.createConversation(id: 'alice_uid_bob_uid', participantId: 'bob_uid', isHidden: false);

      await aliceRepo.insertMessage(oldHandshake);
      await aliceRepo.insertMessage(newHandshake);
      await aliceRepo.insertMessage(normalMessage);

      // Execute local expired handshake TTL cleanup sweep
      await aliceRepo.deleteExpiredHandshakes();

      // Old handshake swept
      expect(await aliceRepo.getMessageById('old_handshake_id'), isNull);
      // New handshake preserved
      expect(await aliceRepo.getMessageById('new_handshake_id'), isNotNull);
      // Normal message preserved
      expect(await aliceRepo.getMessageById('normal_msg_id'), isNotNull);
    });

    test('Sprint 7: Contact Blocking Gates Handshakes/Messages & Ignores Sync Payloads', () async {
      // Create conversation and set it to blocked
      await aliceRepo.createOrUpdateParticipant(id: 'bob_uid', username: 'bob_username', identityKeyPub: 'bob_pub');
      await aliceRepo.createConversation(id: 'alice_uid_bob_uid', participantId: 'bob_uid', isHidden: false);
      await aliceRepo.toggleBlockConversation('alice_uid_bob_uid');

      // Setup Bob pseudonym in mock directory so that pseudonym lookup succeeds before block check
      SignalSessionManager.mockPseudonyms = {
        'bob_username': {'uid': 'bob_uid', 'displayName': 'Bob', 'identityPublicKey': 'bob_pub'}
      };

      // Alice tries to send secure message to blocked Bob -> rejected
      await expectLater(
        aliceSessionManager.sendSecureMessage(targetUid: 'bob_uid', plaintext: 'Hello blocked Bob!'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'BLOCKED_CONTACT')),
      );

      // Alice tries to initiate session with blocked Bob -> rejected
      await expectLater(
        aliceSessionManager.initiateSession(targetUsername: 'bob_username', isHidden: false),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'BLOCKED_CONTACT')),
      );

      // Bob sync service ignores incoming message from blocked Alice
      SignalSessionManager.mockSyncQueues = {
        'bob_uid': [
          {
            'id': 'msg_block_id',
            'senderUid': 'alice_uid',
            'ciphertext': 'ciphertext',
            'type': 2,
          }
        ]
      };

      // Set Bob's local conversation with Alice to blocked
      await bobRepo.createOrUpdateParticipant(id: 'alice_uid', username: 'alice_username', identityKeyPub: 'alice_pub');
      await bobRepo.createConversation(id: 'bob_uid_alice_uid', participantId: 'alice_uid', isHidden: false);
      await bobRepo.toggleBlockConversation('bob_uid_alice_uid');

      final bobSessionService = _FakeHiddenSessionService();
      final bobSyncService = SignalSyncService(bobSessionManager, bobIdentityService, bobSessionService, bobRepo);

      // Bob processes sync queue
      await bobSyncService.testProcessMockQueue('bob_uid');

      // Sync queue entry deleted/consumed, but NOT written locally because it was ignored
      expect(SignalSessionManager.mockSyncQueues!['bob_uid']!.isEmpty, true);
      expect(await bobRepo.getMessageById('msg_block_id'), isNull);
    });

    test('Sprint 7: Identity Change Revokes trustState, blocks sendMessage, and Re-approves successfully', () async {
      final alicePriv = seedRecoveryService.derivePrivateKey('abandon ability able about above absent absorb abstract act action actor actress');
      final alicePub = seedRecoveryService.derivePublicKey(alicePriv);
      await aliceIdentityService.saveIdentityKeys(pubKey: alicePub, privKey: alicePriv);

      final originalKey = _bytesToHex(PrivateKey.generate().getPublicKey().serialize());
      final newBobIdentityKeyPair = PrivateKey.generate();
      final rotatedKey = _bytesToHex(newBobIdentityKeyPair.getPublicKey().serialize());

      // 1. Setup Alice's E2EE connection with Bob
      final initialBob = await aliceRepo.createOrUpdateParticipant(
        id: 'bob_uid',
        username: 'bob_username',
        identityKeyPub: originalKey,
        trustState: 'accepted',
      );
      expect(initialBob.trustState, 'accepted');

      // 2. Bob rotates his identity key
      SignalSessionManager.mockPseudonyms = {
        'bob_username': {
          'uid': 'bob_uid',
          'displayName': 'Bob',
          'identityPublicKey': rotatedKey,
        }
      };

      // 3. Alice tries to initiate a session, which detects the change, sets trustState to 'revoked', and throws StateError
      await expectLater(
        aliceSessionManager.initiateSession(targetUsername: 'bob_username', isHidden: false),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'IDENTITY_KEY_CHANGED')),
      );

      // Verify trust state is revoked locally
      final revokedBob = await aliceRepo.getParticipantById('bob_uid');
      expect(revokedBob!.trustState, 'revoked');

      // 4. HiddenChatController.sendMessage() should block sending if trustState == 'revoked'
      final chatController = HiddenChatController(aliceRepo, _FakeHiddenSessionService(), 'alice_uid_bob_uid');
      chatController.otherParticipant.value = revokedBob;
      chatController.textController.text = 'Trying to send message to revoked key';

      await chatController.sendMessage();
      // Message was blocked, so text field was NOT cleared and messages list remains empty
      expect(chatController.textController.text, 'Trying to send message to revoked key');
      expect(chatController.messages.isEmpty, true);

      // 5. Re-approve identity
      // Bob Signed Prekey & OTP mock setup
      final bobSignedPreKeyPair = PrivateKey.generate();
      final bobSignedPreKeySignature = newBobIdentityKeyPair.sign(message: bobSignedPreKeyPair.getPublicKey().serialize());
      final bobKyberKeyPair = KyberKeyPair.generate();
      final bobKyberSignature = newBobIdentityKeyPair.sign(message: bobKyberKeyPair.getPublicKey().serialize());

      SignalSessionManager.mockPrekeyBundles = {
        'bob_uid': {
          'identityPublicKey': rotatedKey,
          'signedPrekeyId': 1,
          'signedPrekeyPublic': _bytesToHex(bobSignedPreKeyPair.getPublicKey().serialize()),
          'signedPrekeySignature': _bytesToHex(bobSignedPreKeySignature),
          'kyberPrekeyId': 1,
          'kyberPrekeyPublic': _bytesToHex(bobKyberKeyPair.getPublicKey().serialize()),
          'kyberPrekeySignature': _bytesToHex(bobKyberSignature),
          'oneTimePrekeys': []
        }
      };

      await aliceSessionManager.reapproveParticipantIdentity('bob_uid');

      // Verify that re-approval updated the key, set trustState to accepted, and performed a new handshake
      final acceptedBob = await aliceRepo.getParticipantById('bob_uid');
      expect(acceptedBob!.identityKeyPub, rotatedKey);
      expect(acceptedBob.trustState, 'accepted');
    });
  });
}

class _FakeHiddenSessionService extends HiddenSessionService {
  _FakeHiddenSessionService() : super(_FakeHiddenVaultService());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uint8List _hexToBytes(String hex) {
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return bytes;
}

String _bytesToHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
