import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal/libsignal.dart';
import 'package:drift/native.dart';
import 'package:memovault/core/config/env_config.dart';
import 'package:memovault/core/crypto/media_cryptor.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/core/services/database_service.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/features/hidden/services/hidden_vault_service.dart';
import 'package:memovault/features/hidden/services/pin_hashing_service.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/features/hidden/services/seed_recovery_service.dart';
import 'package:memovault/data/messaging/messaging_repository_impl.dart';
import 'package:memovault/features/messaging/services/signal_session_manager.dart';
import 'package:memovault/features/messaging/services/signal_sync_service.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';
import 'package:memovault/domain/messaging/message_entity.dart';
import 'package:memovault/data/messaging/services/media_transfer_service_impl.dart';
import 'package:memovault/data/messaging/services/r2_storage_service_impl.dart';
import 'package:flutter/services.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getLibraryPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }
}

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

class _FakeHiddenSessionService extends HiddenSessionService {
  _FakeHiddenSessionService() : super(_FakeHiddenVaultService());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Encrypted Media Transfer E2E Flow Tests', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      PathProviderPlatform.instance = MockPathProviderPlatform();
      EnvConfig.isTest = true;
      await LibSignal.init();
    });

    test('MediaCryptor Symmetric AES-256-GCM and X25519 ECIES escrow encrypt/decrypt loops', () async {
      final plaintext = Uint8List.fromList('Antigravity Secret Document Data'.codeUnits);
      final mediaKey = MediaCryptor.generateMediaKey();

      // 1. Symmetric File Encryption/Decryption
      final encryptedBytes = await MediaCryptor.encryptFileBytes(plaintext, mediaKey);
      expect(encryptedBytes.length, greaterThan(12 + 16));

      final decryptedBytes = await MediaCryptor.decryptFileBytes(encryptedBytes, mediaKey);
      expect(String.fromCharCodes(decryptedBytes), 'Antigravity Secret Document Data');

      // 2. Compliance Key Agreement & Decryption Loop
      // Generate compliance key pair (X25519 key pair)
      final aliceX25519 = X25519();
      final complianceKeyPair = await aliceX25519.newKeyPair();
      final compPubHex = _bytesToHex((await complianceKeyPair.extractPublicKey()).bytes);
      final compPrivHex = _bytesToHex((await complianceKeyPair.extractPrivateKeyBytes()));

      final escrowBlock = await MediaCryptor.encryptKeyForCompliance(mediaKey, compPubHex);
      expect(escrowBlock['ephemeralPublicKey'], isNotNull);
      expect(escrowBlock['ciphertext'], isNotNull);

      final decryptedMediaKey = await MediaCryptor.decryptKeyForCompliance(escrowBlock, compPrivHex);
      expect(decryptedMediaKey, mediaKey);
    });

    test('Alice uploads encrypted media, Bob handshakes, receives E2EE Media Key, and decrypts attachment E2E', () async {
      final seedRecoveryService = SeedRecoveryServiceImpl();

      // 1. Initialize Alice's dependencies
      final aliceStorage = _FakeSecureStorageService();
      final aliceIdentityService = MessagingIdentityServiceImpl(aliceStorage);
      final aliceDb = AppDatabase(NativeDatabase.memory());
      final aliceFakeVault = _FakeHiddenVaultService();
      aliceFakeVault.mockDb = HiddenVaultDatabase(NativeDatabase.memory());
      final aliceRepo = MessagingRepositoryImpl(
        _FakeDatabaseService(aliceDb),
        aliceFakeVault,
      );
      final aliceSessionManager = SignalSessionManager(
        aliceIdentityService,
        aliceRepo,
        aliceStorage,
      );

      final aliceMnemonic = 'abandon ability able about above absent absorb abstract act action actor actress';
      final alicePriv = seedRecoveryService.derivePrivateKey(aliceMnemonic);
      final alicePub = seedRecoveryService.derivePublicKey(alicePriv);
      await aliceIdentityService.saveIdentityKeys(pubKey: alicePub, privKey: alicePriv);

      // 2. Initialize Bob's dependencies
      final bobStorage = _FakeSecureStorageService();
      final bobIdentityService = MessagingIdentityServiceImpl(bobStorage);
      final bobDb = AppDatabase(NativeDatabase.memory());
      final bobFakeVault = _FakeHiddenVaultService();
      bobFakeVault.mockDb = HiddenVaultDatabase(NativeDatabase.memory());
      final bobRepo = MessagingRepositoryImpl(
        _FakeDatabaseService(bobDb),
        bobFakeVault,
      );
      final bobSessionManager = SignalSessionManager(
        bobIdentityService,
        bobRepo,
        bobStorage,
      );

      final bobMnemonic = 'amazing among amount amused analyst anchor ancient anger angle angry animal ankle';
      final bobPriv = seedRecoveryService.derivePrivateKey(bobMnemonic);
      final bobPub = seedRecoveryService.derivePublicKey(bobPriv);
      await bobIdentityService.saveIdentityKeys(pubKey: bobPub, privKey: bobPriv);

      // Setup Bob Signed Prekey & OTP
      final bobSignedPreKeyPair = PrivateKey.generate();
      final bobIdentityKey = PrivateKey.deserialize(bytes: _hexToBytes(bobPriv));
      final bobSignedPreKeySignature = bobIdentityKey.sign(message: bobSignedPreKeyPair.getPublicKey().serialize());
      final bobKyberKeyPair = KyberKeyPair.generate();
      final bobKyberSignature = bobIdentityKey.sign(message: bobKyberKeyPair.getPublicKey().serialize());
      final bobOtKeyPair = PrivateKey.generate();

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
      await bobRepo.storePreKey(1, Uint8List.fromList(bobOtRecord.serialize()), true);

      // Register directory fakes
      SignalSessionManager.mockPseudonyms = {
        'alice_username': {'uid': 'alice_uid', 'displayName': 'Alice', 'identityPublicKey': alicePub},
        'bob_username': {'uid': 'bob_uid', 'displayName': 'Bob', 'identityPublicKey': bobPub}
      };

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

      SignalSessionManager.mockSyncQueues = {};

      // ─── Setup Alice Handshake with Bob ───
      await aliceSessionManager.initiateSession(targetUsername: 'bob_username', isHidden: true);
      expect(SignalSessionManager.mockSyncQueues!['bob_uid']!.length, 1);

      // Bob sync processes handshake
      final bobSyncService = SignalSyncService(bobSessionManager, bobIdentityService, _FakeHiddenSessionService(), bobRepo);
      await bobSyncService.testProcessMockQueue('bob_uid');
      expect(SignalSessionManager.mockSyncQueues!['bob_uid']!.isEmpty, true);

      // ─── E2E Media Encryption & Upload ───
      // Alice creates a mock file to send
      final tempDir = Directory.systemTemp.path;
      final fileToSend = File('$tempDir/test_receipt.jpg');
      await fileToSend.writeAsBytes(Uint8List.fromList('Antigravity E2E Attachment Test Plaintext'.codeUnits));

      // Alice inserts the queued message locally
      final msgId = 'media_msg_123';
      final initialMsg = MessageEntity(
        id: msgId,
        conversationId: 'alice_uid_bob_uid',
        senderId: 'alice_uid',
        encryptedContent: '[Media Attachment]',
        nonce: 'nonce_val',
        state: 'queued',
        messageType: 'image',
        createdAt: DateTime.now().toUtc(),
      );
      await aliceRepo.insertMessage(initialMsg);

      final r2Storage = R2StorageServiceImpl();
      final aliceTransferService = MediaTransferServiceImpl(r2Storage, aliceRepo);

      // Upload and encrypt file
      final completedAttachment = await aliceTransferService.uploadEncryptedFile(
        messageId: msgId,
        file: fileToSend,
        fileType: 'image/jpeg',
      );

      expect(completedAttachment.status, 'completed');
      expect(completedAttachment.remotePath, startsWith('mock-r2://'));
      expect(completedAttachment.localPath, fileToSend.path);

      // Send the secure E2EE media message
      await aliceSessionManager.sendSecureMediaMessage(
        targetUid: 'bob_uid',
        attachment: completedAttachment,
      );

      // ─── Bob receives and decrypts E2E ───
      expect(SignalSessionManager.mockSyncQueues!['bob_uid']!.length, 1);
      final incomingMessageData = SignalSessionManager.mockSyncQueues!['bob_uid']!.first;
      expect(incomingMessageData['messageType'], 'image');
      expect(incomingMessageData['attachment'], isNotNull);

      // Bob processes the incoming media message
      await bobSyncService.testProcessMockQueue('bob_uid');

      // Verify Bob stores the E2EE message and attachment details locally
      final bobReceivedMsg = await bobRepo.getMessageById(msgId);
      expect(bobReceivedMsg, isNotNull);
      expect(bobReceivedMsg!.messageType, 'image');

      final bobReceivedAttachments = await bobRepo.getAttachmentsForMessage(msgId);
      expect(bobReceivedAttachments.length, 1);
      final bobAttachment = bobReceivedAttachments.first;
      expect(bobAttachment.status, 'queued');
      expect(bobAttachment.remotePath, completedAttachment.remotePath);
      expect(bobAttachment.keyPayload, completedAttachment.keyPayload); // Decrypted DR key is stored

      // Bob downloads and decrypts the file
      final bobTransferService = MediaTransferServiceImpl(r2Storage, bobRepo);
      final bobDecryptedFile = await bobTransferService.downloadAndDecryptFile(attachment: bobAttachment);

      expect(bobDecryptedFile.existsSync(), true);
      final bobDecryptedBytes = await bobDecryptedFile.readAsBytes();
      expect(String.fromCharCodes(bobDecryptedBytes), 'Antigravity E2E Attachment Test Plaintext');

      // Cleanup files
      if (fileToSend.existsSync()) fileToSend.deleteSync();
      if (bobDecryptedFile.existsSync()) bobDecryptedFile.deleteSync();

      await aliceDb.close();
      await bobDb.close();
      if (aliceFakeVault.mockDb != null) await aliceFakeVault.mockDb!.close();
      if (bobFakeVault.mockDb != null) await bobFakeVault.mockDb!.close();
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
