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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Messaging Cryptographic Handshake & Session Integration Tests', () {
    setUpAll(() async {
      await LibSignal.init();
    });

    late _FakeSecureStorageService aliceStorage;
    late MessagingIdentityService aliceIdentityService;
    late AppDatabase aliceDb;
    late MessagingRepositoryImpl aliceRepo;
    late SignalSessionManager aliceSessionManager;

    late _FakeSecureStorageService bobStorage;
    late MessagingIdentityService bobIdentityService;
    late AppDatabase bobDb;
    late MessagingRepositoryImpl bobRepo;
    late SignalSessionManager bobSessionManager;

    final seedRecoveryService = SeedRecoveryServiceImpl();

    setUp(() async {
      // 1. Initialize Alice's dependencies
      aliceStorage = _FakeSecureStorageService();
      aliceIdentityService = MessagingIdentityServiceImpl(aliceStorage);
      aliceDb = AppDatabase(NativeDatabase.memory());
      aliceRepo = MessagingRepositoryImpl(
        _FakeDatabaseService(aliceDb),
        _FakeHiddenVaultService(),
      );
      aliceSessionManager = SignalSessionManager(
        aliceIdentityService,
        aliceRepo,
        aliceStorage,
      );

      // 2. Initialize Bob's dependencies
      bobStorage = _FakeSecureStorageService();
      bobIdentityService = MessagingIdentityServiceImpl(bobStorage);
      bobDb = AppDatabase(NativeDatabase.memory());
      bobRepo = MessagingRepositoryImpl(
        _FakeDatabaseService(bobDb),
        _FakeHiddenVaultService(),
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
