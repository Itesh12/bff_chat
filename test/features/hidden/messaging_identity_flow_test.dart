import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:libsignal/libsignal.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/features/hidden/domain/entities/messaging_setup_state.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/features/hidden/services/seed_recovery_service.dart';
import 'package:memovault/features/hidden/controllers/messaging_setup_controller.dart';
import 'package:memovault/features/hidden/controllers/hidden_activation_controller.dart';
import 'package:memovault/features/hidden/services/hidden_vault_service.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';

import 'package:memovault/domain/messaging/messaging_repository.dart';

// Fake secure storage implementation
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

class _FakeMessagingRepository implements MessagingRepository {
  final Map<int, Uint8List> _preKeys = {};

  @override
  Future<void> storePreKey(int preKeyId, Uint8List recordBytes, bool isHidden) async {
    _preKeys[preKeyId] = recordBytes;
  }

  @override
  Future<Uint8List?> loadPreKey(int preKeyId, bool isHidden) async {
    return _preKeys[preKeyId];
  }

  @override
  Future<bool> containsPreKey(int preKeyId, bool isHidden) async {
    return _preKeys.containsKey(preKeyId);
  }

  @override
  Future<void> removePreKey(int preKeyId, bool isHidden) async {
    _preKeys.remove(preKeyId);
  }

  @override
  Future<List<int>> getAllPreKeyIds(bool isHidden) async {
    return _preKeys.keys.toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVaultService implements HiddenVaultService {
  bool isWiped = false;

  @override
  Future<void> panicWipe() async {
    isWiped = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionService implements HiddenSessionService {
  @override
  bool isLocked = false;

  @override
  void lockSession() {
    isLocked = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Messaging Identity Onboarding Flow Integration Tests', () {
    late _FakeSecureStorageService fakeStorage;
    late _FakeMessagingRepository fakeRepo;
    late MessagingIdentityService identityService;
    late SeedRecoveryService seedRecoveryService;
    late MessagingSetupController controller;

    setUpAll(() async {
      await LibSignal.init();
    });

    setUp(() {
      fakeStorage = _FakeSecureStorageService();
      Get.put<SecureStorageService>(fakeStorage);
      fakeRepo = _FakeMessagingRepository();
      Get.put<MessagingRepository>(fakeRepo);
      identityService = MessagingIdentityServiceImpl(fakeStorage);
      seedRecoveryService = SeedRecoveryServiceImpl();
      controller = MessagingSetupController(identityService, seedRecoveryService);
      controller.onInit();
    });

    tearDown(() {
      Get.delete<SecureStorageService>();
      Get.delete<MessagingRepository>();
    });

    test('BIP-39 Mnemonic Seed generation derives exactly 12 valid words', () {
      final mnemonicList = seedRecoveryService.generateMnemonic();
      expect(mnemonicList.length, 12);

      final mnemonicStr = mnemonicList.join(' ');
      expect(seedRecoveryService.validateMnemonic(mnemonicStr), true);
      expect(seedRecoveryService.validateMnemonic('invalid word list phrase'), false);
    });

    test('Identity Keypair derivation remains deterministic and one-way', () {
      const mnemonic = 'abandon ability able about above absent absorb abstract act action actor actress';
      
      final privKey1 = seedRecoveryService.derivePrivateKey(mnemonic);
      final privKey2 = seedRecoveryService.derivePrivateKey(mnemonic);
      expect(privKey1, privKey2); // Deterministic

      final pubKey1 = seedRecoveryService.derivePublicKey(privKey1);
      final pubKey2 = seedRecoveryService.derivePublicKey(privKey1);
      expect(pubKey1, pubKey2); // Deterministic
      expect(pubKey1 != privKey1, true); // One-way
    });

    test('Username rules filter reserved system handles, enforce length constraints, normalize case and Unicode, and protect against homograph attacks', () async {
      // 1. Enforce alphanumeric character set regex & length
      await controller.checkUsernameUniqueness('sh'); // Too short
      expect(controller.isUsernameAvailable.value, false);
      expect(controller.usernameFeedback.value.contains('3-20 chars'), true);

      await controller.checkUsernameUniqueness('user@name!'); // Malformed chars
      expect(controller.isUsernameAvailable.value, false);

      // 2. Reject reserved words client-side
      await controller.checkUsernameUniqueness('admin');
      expect(controller.isUsernameAvailable.value, false);
      expect(controller.usernameFeedback.value.contains('reserved'), true);

      await controller.checkUsernameUniqueness('memovault');
      expect(controller.isUsernameAvailable.value, false);

      // 3. Normalize case to lowercase and remove spaces
      await controller.checkUsernameUniqueness('  Shadow_Fox  ');
      expect(controller.isUsernameAvailable.value, true);
      expect(controller.username.value, 'shadow_fox'); // Normalized

      // 4. Unicode Compatibility (NFKC-like mapping) for fullwidth Latin & numbers
      // Full-width 'ｊｏｈｎ' -> 'john'
      await controller.checkUsernameUniqueness('ｊｏｈｎ');
      expect(controller.isUsernameAvailable.value, true);
      expect(controller.username.value, 'john');

      // 5. Rejection of leading, trailing, and double underscores, and starting with a digit
      await controller.checkUsernameUniqueness('1john');
      expect(controller.isUsernameAvailable.value, false);
      await controller.checkUsernameUniqueness('123abc');
      expect(controller.isUsernameAvailable.value, false);
      await controller.checkUsernameUniqueness('a_');
      expect(controller.isUsernameAvailable.value, false);
      await controller.checkUsernameUniqueness('ab_');
      expect(controller.isUsernameAvailable.value, false);
      await controller.checkUsernameUniqueness('john_');
      expect(controller.isUsernameAvailable.value, false);
      await controller.checkUsernameUniqueness('__john');
      expect(controller.isUsernameAvailable.value, false);
      await controller.checkUsernameUniqueness('john__');
      expect(controller.isUsernameAvailable.value, false);
      await controller.checkUsernameUniqueness('___');
      expect(controller.isUsernameAvailable.value, false);
      await controller.checkUsernameUniqueness('john__doe');
      expect(controller.isUsernameAvailable.value, false);

      // 6. Homograph attack prevention (Greek/Cyrillic lookalikes)
      // Greek Alpha: 'Αlice' (starts with \u0391) -> lowercases to 'αlice' (starts with \u03b1)
      await controller.checkUsernameUniqueness('\u0391lice');
      expect(controller.isUsernameAvailable.value, false);

      // Cyrillic A: 'Аlice' (starts with \u0410) -> lowercases to 'аlice' (starts with \u0430)
      await controller.checkUsernameUniqueness('\u0410lice');
      expect(controller.isUsernameAvailable.value, false);
    });

    test('Onboarding State Machine quiz verification prompt and pre-registration confirmation gates', () async {
      expect(controller.setupState.value, MessagingSetupState.unconfigured);

      // 1. Set username (maintain capitalization for display name)
      await controller.checkUsernameUniqueness('Shadow_Fox');
      await controller.proceedFromUsernameSelection();
      expect(await identityService.getUsername(), '@shadow_fox');
      expect(await identityService.getDisplayName(), 'Shadow_Fox');

      // 2. Generate recovery seed
      expect(controller.setupState.value, MessagingSetupState.seedGenerated);
      expect(controller.seedWords.length, 12);
      
      // Save local reference of generated seed words for quiz verification
      final List<String> originalSeed = List.from(controller.seedWords);

      // 3. Position prompt quiz checks
      controller.proceedToQuiz();
      expect(controller.setupState.value, MessagingSetupState.seedVerified);
      expect(controller.quizIndex.value, 0);

      // Word #3 is index 2, Word #8 is index 7, Word #11 is index 10
      final w3 = originalSeed[2];
      final w8 = originalSeed[7];
      final w11 = originalSeed[10];

      // Simulate entering wrong word
      controller.selectQuizOption('wrong_word_choice');
      expect(controller.quizIndex.value, 0); // Reset to 0

      // Enter correct options for quiz progression
      controller.selectQuizOption(w3);
      expect(controller.quizIndex.value, 1);

      controller.selectQuizOption(w8);
      expect(controller.quizIndex.value, 2);

      controller.selectQuizOption(w11);
      
      // 4. Transitions to Pre-Registration Confirmation state
      expect(controller.setupState.value, MessagingSetupState.identityPublished);

      // 5. Register and activate identity publishes keys and purges plaintext seed from memory
      await controller.registerAndPublishIdentity();
      expect(controller.setupState.value, MessagingSetupState.ready);
      expect(controller.seedWords.isEmpty, true); // Ephemeral mnemonic purged!

      // Derived keys persisted securely
      expect(await identityService.getPublicKey(), isNotNull);
      expect(await identityService.getPrivateKey(), isNotNull);
    });

    test('Local prekey storage persists signed, Kyber, and one-time prekeys correctly and is purged on reset', () async {
      // Test Signed Prekeys
      await identityService.saveSignedPreKey(
        id: 101,
        privKeyHex: 'priv_sp_101',
        pubKeyHex: 'pub_sp_101',
        signatureHex: 'sig_sp_101',
        timestampMs: 123456789,
      );
      final sp = await identityService.loadSignedPreKey(101);
      expect(sp, isNotNull);
      expect(sp!['privKeyHex'], 'priv_sp_101');
      expect(sp['timestampMs'], 123456789);
      expect(await identityService.getSignedPreKeyIds(), [101]);

      // Test Kyber Prekeys
      await identityService.saveKyberPreKey(
        id: 301,
        privKeyHex: 'priv_kp_301',
        pubKeyHex: 'pub_kp_301',
        signatureHex: 'sig_kp_301',
        timestampMs: 987654321,
      );
      final kp = await identityService.loadKyberPreKey(301);
      expect(kp, isNotNull);
      expect(kp!['pubKeyHex'], 'pub_kp_301');
      expect(await identityService.getKyberPreKeyIds(), [301]);

      // Test One-Time Prekeys
      await identityService.saveOneTimePreKey(id: 1, privKeyHex: 'priv_ot_1', pubKeyHex: 'pub_ot_1');
      await identityService.saveOneTimePreKey(id: 2, privKeyHex: 'priv_ot_2', pubKeyHex: 'pub_ot_2');
      expect(await identityService.containsOneTimePreKey(1), true);
      expect(await identityService.containsOneTimePreKey(3), false);
      expect(await identityService.getOneTimePreKeyIds(), [1, 2]);

      final ot1 = await identityService.loadOneTimePreKey(1);
      expect(ot1!['privKeyHex'], 'priv_ot_1');

      await identityService.removeOneTimePreKey(1);
      expect(await identityService.containsOneTimePreKey(1), false);
      expect(await identityService.getOneTimePreKeyIds(), [2]);

      // Reset Identity cleans all prekeys
      await identityService.resetIdentity();
      expect(await identityService.getSignedPreKeyIds(), isEmpty);
      expect(await identityService.getKyberPreKeyIds(), isEmpty);
      expect(await identityService.getOneTimePreKeyIds(), isEmpty);
      expect(await identityService.loadSignedPreKey(101), isNull);
    });

    test('Panic PIN wipe triggers fully revoke and scrub secure messaging identity', () async {
      // 1. Setup active identity
      await identityService.saveUsername('@alice');
      await identityService.saveDisplayName('Alice');
      await identityService.saveIdentityKeys(pubKey: 'pub', privKey: 'priv');
      await identityService.setSetupState(MessagingSetupState.ready);

      expect(await identityService.getUsername(), '@alice');
      expect(await identityService.getDisplayName(), 'Alice');
      expect(await identityService.getPublicKey(), 'pub');

      // 2. Simulate Panic Trigger Wipes
      final fakeVault = _FakeVaultService();
      final fakeSession = _FakeSessionService();
      
      Get.put<MessagingIdentityService>(identityService);
      final activationController = HiddenActivationController(fakeVault, fakeSession);

      await activationController.triggerPanicWipe();

      expect(fakeVault.isWiped, true);
      expect(fakeSession.isLocked, true);

      // Secure messaging credentials fully scrubbed from storage
      expect(await identityService.getUsername(), isNull);
      expect(await identityService.getDisplayName(), isNull);
      expect(await identityService.getPublicKey(), isNull);
      expect(await identityService.getSetupState(), MessagingSetupState.unconfigured);
    });
  });
}
