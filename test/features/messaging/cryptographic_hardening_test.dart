import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal/libsignal.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull;
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
import 'package:memovault/features/messaging/services/prekey_rotation_service.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart' as private_db;
import 'package:memovault/core/config/env_config.dart';
import 'package:get/get.dart' hide Value;

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

  private_db.HiddenVaultDatabase? mockDb;

  @override
  private_db.HiddenVaultDatabase? get db => mockDb;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Phase 4.4 Cryptographic Hardening & Persistent Ratchets Integration Tests', () {
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
    late PrekeyRotationService bobRotationService;

    final seedRecoveryService = SeedRecoveryServiceImpl();

    setUp(() async {
      // 1. Initialize Alice's dependencies
      aliceStorage = _FakeSecureStorageService();
      aliceIdentityService = MessagingIdentityServiceImpl(aliceStorage);
      aliceDb = AppDatabase(NativeDatabase.memory());
      aliceFakeVault = _FakeHiddenVaultService();
      aliceFakeVault.mockDb = private_db.HiddenVaultDatabase(NativeDatabase.memory());
      aliceRepo = MessagingRepositoryImpl(
        _FakeDatabaseService(aliceDb),
        aliceFakeVault,
      );
      aliceSessionManager = SignalSessionManager(
        aliceIdentityService,
        aliceRepo,
        aliceStorage,
      );

      // Register Alice's services in Get
      Get.put<MessagingIdentityService>(aliceIdentityService);
      Get.put<SignalSessionManager>(aliceSessionManager);

      // 2. Initialize Bob's dependencies
      bobStorage = _FakeSecureStorageService();
      bobIdentityService = MessagingIdentityServiceImpl(bobStorage);
      bobDb = AppDatabase(NativeDatabase.memory());
      bobFakeVault = _FakeHiddenVaultService();
      bobFakeVault.mockDb = private_db.HiddenVaultDatabase(NativeDatabase.memory());
      bobRepo = MessagingRepositoryImpl(
        _FakeDatabaseService(bobDb),
        bobFakeVault,
      );
      bobSessionManager = SignalSessionManager(
        bobIdentityService,
        bobRepo,
        bobStorage,
      );
      bobRotationService = PrekeyRotationService(bobStorage, bobIdentityService);

      Get.put<PrekeyRotationService>(bobRotationService);

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
      await Get.delete<PrekeyRotationService>();
    });

    test('Out-of-Order Delivery (Skipped Keys), Replay Protection, and DoS Mitigation', () async {
      // ─── Setup Identities ───
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
      await bobRepo.storePreKey(
        1,
        Uint8List.fromList(bobOtRecord.serialize()),
        true,
      );

      // Run Alice initiate session
      await aliceSessionManager.initiateSession(targetUsername: 'bob_username', isHidden: true);

      // Bob processes the handshake message
      final bobQueue = SignalSessionManager.mockSyncQueues!['bob_uid']!;
      expect(bobQueue.length, 1);
      final handshakeMsg = bobQueue.first;
      await bobSessionManager.receiveHandshake(
        senderUid: 'alice_uid',
        ciphertextHex: handshakeMsg['ciphertext'] as String,
        messageType: handshakeMsg['type'] as int,
        senderUsername: 'alice_username',
        senderIdentityKeyPubHex: alicePub,
        isHidden: true,
      );

      // ─── Alice Encrypts 3 Messages ───
      final aliceStore = SignalStoreImpl(aliceStorage, aliceIdentityService, aliceRepo, isHidden: true);
      final aliceCipher = SessionCipher(
        localAddress: ProtocolAddress(name: 'alice_uid', deviceId: 1),
        sessionStore: aliceStore,
        identityKeyStore: aliceStore,
        preKeyStore: aliceStore,
        signedPreKeyStore: aliceStore,
        kyberPreKeyStore: aliceStore,
      );

      final bobAddress = ProtocolAddress(name: 'bob_uid', deviceId: 1);

      final cipherMsg0 = await aliceCipher.encrypt(bobAddress, Uint8List.fromList('Message 0'.codeUnits));
      final cipherMsg1 = await aliceCipher.encrypt(bobAddress, Uint8List.fromList('Message 1'.codeUnits));
      final cipherMsg2 = await aliceCipher.encrypt(bobAddress, Uint8List.fromList('Message 2'.codeUnits));

      // ─── Step 1: Bob processes Message 2 first (Out of Order) ───
      await bobSessionManager.decryptAndStoreMessage(
        senderUid: 'alice_uid',
        ciphertextHex: _bytesToHex(cipherMsg2.ciphertext),
        messageType: cipherMsg2.type.value,
        messageId: 'msg_2_id',
      );

      // Verify that skipped keys for 1 and 2 are saved in Bob's DB
      final skippedRows = await bobFakeVault.mockDb!.select(bobFakeVault.mockDb!.signalSkippedKeysTable).get();
      print('DEBUG: skippedRows = ${skippedRows.map((r) => r.sequenceNumber).toList()}');
      expect(skippedRows.length, 2);
      expect(skippedRows.any((r) => r.sequenceNumber == 1), isTrue);
      expect(skippedRows.any((r) => r.sequenceNumber == 2), isTrue);

      final msg2 = await bobRepo.getMessageById('msg_2_id');
      expect(msg2!.encryptedContent, 'Message 2');

      // ─── Step 2: Bob processes Message 0 next (Out of Order) ───
      await bobSessionManager.decryptAndStoreMessage(
        senderUid: 'alice_uid',
        ciphertextHex: _bytesToHex(cipherMsg0.ciphertext),
        messageType: cipherMsg0.type.value,
        messageId: 'msg_0_id',
      );

      // Verify that skipped key for 1 is consumed/cleared, and 2 remains
      final skippedRowsAfter0 = await bobFakeVault.mockDb!.select(bobFakeVault.mockDb!.signalSkippedKeysTable).get();
      expect(skippedRowsAfter0.length, 1);
      expect(skippedRowsAfter0.first.sequenceNumber, 2);

      final msg0 = await bobRepo.getMessageById('msg_0_id');
      expect(msg0!.encryptedContent, 'Message 0');

      // ─── Step 3: Bob processes Message 1 next ───
      await bobSessionManager.decryptAndStoreMessage(
        senderUid: 'alice_uid',
        ciphertextHex: _bytesToHex(cipherMsg1.ciphertext),
        messageType: cipherMsg1.type.value,
        messageId: 'msg_1_id',
      );

      // Verify all skipped keys are cleared
      final skippedRowsAfter1 = await bobFakeVault.mockDb!.select(bobFakeVault.mockDb!.signalSkippedKeysTable).get();
      expect(skippedRowsAfter1.isEmpty, isTrue);

      final msg1 = await bobRepo.getMessageById('msg_1_id');
      expect(msg1!.encryptedContent, 'Message 1');

      // ─── Step 4: Replay Protection ───
      // Try to decrypt Message 0 again -> should be blocked and throw StateError('REPLAYED_MESSAGE')
      await expectLater(
        bobSessionManager.decryptAndStoreMessage(
          senderUid: 'alice_uid',
          ciphertextHex: _bytesToHex(cipherMsg0.ciphertext),
          messageType: cipherMsg0.type.value,
          messageId: 'msg_0_replay_id',
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'REPLAYED_MESSAGE')),
      );

      // ─── Step 5: Skipped Keys DoS Protection (Limit 100) ───
      // Insert 100 skipped keys to simulate DoS threshold reached
      final now = DateTime.now().toUtc();
      for (int i = 0; i < 100; i++) {
        await bobFakeVault.mockDb!.into(bobFakeVault.mockDb!.signalSkippedKeysTable).insert(
          private_db.SignalSkippedKeysTableCompanion(
            senderId: const Value('alice_uid'),
            ratchetKey: const Value('some_ratchet_key'),
            sequenceNumber: Value(1000 + i),
            keyBytes: Value(Uint8List(32)),
            createdAt: Value(now),
          ),
        );
      }

      // Alice encrypts two more messages
      await aliceCipher.encrypt(bobAddress, Uint8List.fromList('Message 3'.codeUnits));
      final cipherMsg4 = await aliceCipher.encrypt(bobAddress, Uint8List.fromList('Message 4'.codeUnits));

      // Bob decrypts cipherMsg4 (skipping cipherMsg3, i.e., sequence 4 is skipped)
      // This should throw a StateError because Bob already has 100 skipped keys.
      await expectLater(
        bobSessionManager.decryptAndStoreMessage(
          senderUid: 'alice_uid',
          ciphertextHex: _bytesToHex(cipherMsg4.ciphertext),
          messageType: cipherMsg4.type.value,
          messageId: 'msg_4_id',
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'Skipped keys limit exceeded. Potential DoS.')),
      );
    });

    test('Skipped Key TTL Cleanup Sweeps keys older than 30 days', () async {
      final now = DateTime.now().toUtc();

      // Insert an expired skipped key
      final companionExpired = private_db.SignalSkippedKeysTableCompanion(
        senderId: const Value('alice_uid'),
        ratchetKey: const Value('ratchet_key_1'),
        sequenceNumber: const Value(5),
        keyBytes: Value(Uint8List(0)),
        createdAt: Value(now.subtract(const Duration(days: 31))), // Expired
      );
      await bobFakeVault.mockDb!.into(bobFakeVault.mockDb!.signalSkippedKeysTable).insert(companionExpired);

      // Insert a fresh skipped key
      final companionFresh = private_db.SignalSkippedKeysTableCompanion(
        senderId: const Value('alice_uid'),
        ratchetKey: const Value('ratchet_key_1'),
        sequenceNumber: const Value(6),
        keyBytes: Value(Uint8List(0)),
        createdAt: Value(now.subtract(const Duration(days: 15))), // Fresh
      );
      await bobFakeVault.mockDb!.into(bobFakeVault.mockDb!.signalSkippedKeysTable).insert(companionFresh);

      // Execute sweep
      await bobRepo.deleteExpiredSkippedKeys();

      // Expired is swept
      final rows = await bobFakeVault.mockDb!.select(bobFakeVault.mockDb!.signalSkippedKeysTable).get();
      expect(rows.length, 1);
      expect(rows.first.sequenceNumber, 6);
    });

    test('Prekey Rotation Service generates and stores new keys and updates Firestore bundle', () async {
      // Setup Bob identity
      final bobPriv = seedRecoveryService.derivePrivateKey('amazing among amount amused analyst anchor ancient anger angle angry animal ankle');
      final bobPub = seedRecoveryService.derivePublicKey(bobPriv);
      await bobIdentityService.saveIdentityKeys(pubKey: bobPub, privKey: bobPriv);

      await bobIdentityService.saveSignedPreKey(
        id: 1,
        privKeyHex: '00',
        pubKeyHex: '00',
        signatureHex: '00',
        timestampMs: 123456,
      );
      await bobIdentityService.saveKyberPreKey(
        id: 1,
        privKeyHex: '00',
        pubKeyHex: '00',
        signatureHex: '00',
        timestampMs: 123456,
      );

      // Setup initial bundle
      SignalSessionManager.mockPrekeyBundles = {
        'bob_uid': {
          'identityPublicKey': bobPub,
          'signedPrekeyId': 1,
          'signedPrekeyPublic': 'old_signed_pub',
          'signedPrekeySignature': 'old_signed_sig',
          'kyberPrekeyId': 1,
          'kyberPrekeyPublic': 'old_kyber_pub',
          'kyberPrekeySignature': 'old_kyber_sig',
          'oneTimePrekeys': []
        }
      };

      // Execute prekey rotation
      await bobRotationService.rotatePrekeys();

      // Verify new prekeys are registered in storage
      final storedSignedIds = await bobIdentityService.getSignedPreKeyIds();
      expect(storedSignedIds.contains(2), isTrue); // rotated to 2

      final storedKyberIds = await bobIdentityService.getKyberPreKeyIds();
      expect(storedKyberIds.contains(2), isTrue); // rotated to 2

      // Verify prekey bundle is updated
      final updatedBundle = SignalSessionManager.mockPrekeyBundles!['bob_uid']!;
      expect(updatedBundle['signedPrekeyId'], 2);
      expect(updatedBundle['kyberPrekeyId'], 2);
      expect(updatedBundle['signedPrekeyPublic'], isNot(equals('old_signed_pub')));
      expect(updatedBundle['kyberPrekeyPublic'], isNot(equals('old_kyber_pub')));
    });
  });
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
