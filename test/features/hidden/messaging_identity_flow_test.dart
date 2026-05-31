import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/features/hidden/domain/entities/messaging_setup_state.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/features/hidden/services/seed_recovery_service.dart';
import 'package:memovault/features/hidden/controllers/messaging_setup_controller.dart';
import 'package:memovault/features/hidden/controllers/hidden_activation_controller.dart';
import 'package:memovault/features/hidden/services/hidden_vault_service.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';

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
    late MessagingIdentityService identityService;
    late SeedRecoveryService seedRecoveryService;
    late MessagingSetupController controller;

    setUp(() {
      fakeStorage = _FakeSecureStorageService();
      identityService = MessagingIdentityServiceImpl(fakeStorage);
      seedRecoveryService = SeedRecoveryServiceImpl();
      controller = MessagingSetupController(identityService, seedRecoveryService);
      controller.onInit();
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

    test('Username rules filter reserved system handles, enforce length constraints, and normalize case', () async {
      // 1. Enforce alphanumeric character set regex
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
    });

    test('Onboarding State Machine quiz verification prompt and pre-registration confirmation gates', () async {
      expect(controller.setupState.value, MessagingSetupState.unconfigured);

      // 1. Set username
      await controller.checkUsernameUniqueness('shadow_fox');
      await controller.proceedFromUsernameSelection();
      expect(await identityService.getUsername(), '@shadow_fox');

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

    test('Panic PIN wipe triggers fully revoke and scrub secure messaging identity', () async {
      // 1. Setup active identity
      await identityService.saveUsername('@alice');
      await identityService.saveIdentityKeys(pubKey: 'pub', privKey: 'priv');
      await identityService.setSetupState(MessagingSetupState.ready);

      expect(await identityService.getUsername(), '@alice');
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
      expect(await identityService.getPublicKey(), isNull);
      expect(await identityService.getSetupState(), MessagingSetupState.unconfigured);
    });
  });
}
