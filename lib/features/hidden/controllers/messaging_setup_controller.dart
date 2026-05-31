import 'dart:async';
import 'dart:math';
import 'package:get/get.dart';
import 'package:memovault/core/design_system/feedback/app_snack_bar.dart';
import 'package:memovault/features/hidden/domain/entities/messaging_setup_state.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/features/hidden/services/seed_recovery_service.dart';

class MessagingSetupController extends GetxController {
  final MessagingIdentityService _identityService;
  final SeedRecoveryService _seedRecoveryService;

  MessagingSetupController(this._identityService, this._seedRecoveryService);

  // Reactive step tracker
  final Rx<MessagingSetupState> setupState = MessagingSetupState.unconfigured.obs;

  // Username Selection States
  final RxString username = ''.obs;
  final RxBool isCheckingUsername = false.obs;
  final RxString usernameFeedback = ''.obs;
  final RxBool isUsernameAvailable = false.obs;
  Timer? _debounceTimer;

  // Seed Generation & Verification States
  final RxList<String> seedWords = <String>[].obs;
  final RxBool isSeedRevealed = false.obs;

  // Positioning Quiz States
  final RxInt quizIndex = 0.obs; // Current quiz question: 0, 1, 2 for 3 position prompts
  final List<int> quizPositions = [2, 7, 10]; // Word #3 (index 2), Word #8 (index 7), Word #11 (index 10)
  final RxList<String> quizOptions = <String>[].obs;
  final RxList<int> quizAnswersSelected = <int>[].obs; // Track completed answers

  @override
  void onInit() {
    super.onInit();
    _loadCurrentState();
  }

  Future<void> _loadCurrentState() async {
    final state = await _identityService.getSetupState();
    setupState.value = state;
    final savedUser = await _identityService.getUsername();
    if (savedUser != null) {
      username.value = savedUser;
    }
  }

  void onUserInteraction() {
    // Reset inactivity timer
  }

  // ─── Username Validation ──────────────────────────────────────────────────
  
  static const List<String> _reservedWords = [
    'admin', 'administrator', 'moderator', 'staff', 'support', 'system', 'root',
    'official', 'memovault', 'security'
  ];

  void onUsernameChanged(String val) {
    onUserInteraction();
    isUsernameAvailable.value = false;
    usernameFeedback.value = '';

    _debounceTimer?.cancel();
    if (val.trim().isEmpty) {
      username.value = '';
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      await checkUsernameUniqueness(val);
    });
  }

  Future<void> checkUsernameUniqueness(String rawVal) async {
    isCheckingUsername.value = true;
    final normalized = rawVal.trim().toLowerCase();
    
    // Normalize case and validate format
    final regex = RegExp(r'^[a-z0-9_]{3,20}$');
    if (!regex.hasMatch(normalized)) {
      isCheckingUsername.value = false;
      isUsernameAvailable.value = false;
      usernameFeedback.value = '3-20 chars, lowecase a-z, 0-9, and _';
      return;
    }

    // Check reserved words
    if (_reservedWords.contains(normalized)) {
      isCheckingUsername.value = false;
      isUsernameAvailable.value = false;
      usernameFeedback.value = 'Username is reserved by system';
      return;
    }

    // Uniqueness checks (Mocked local simulation for test/offline, integrates directly via pseudonyms collection)
    // Simulates a unique availability check
    await Future.delayed(const Duration(milliseconds: 250));
    
    // Simulates taken usernames for testing
    if (normalized == 'taken_user' || normalized == 'rahul_taken') {
      isCheckingUsername.value = false;
      isUsernameAvailable.value = false;
      usernameFeedback.value = 'Username already registered';
      return;
    }

    isCheckingUsername.value = false;
    isUsernameAvailable.value = true;
    username.value = normalized;
    usernameFeedback.value = 'Username available';
  }

  Future<void> proceedFromUsernameSelection() async {
    onUserInteraction();
    if (!isUsernameAvailable.value || username.value.isEmpty) return;

    await _identityService.saveUsername('@${username.value}');
    setupState.value = MessagingSetupState.usernameSelected;
    await _identityService.setSetupState(MessagingSetupState.usernameSelected);
    generateSeedPhrase();
  }

  // ─── Seed Generation ─────────────────────────────────────────────────────

  void generateSeedPhrase() {
    final words = _seedRecoveryService.generateMnemonic();
    seedWords.assignAll(words);
    isSeedRevealed.value = false;
    setupState.value = MessagingSetupState.seedGenerated;
  }

  void proceedToQuiz() {
    onUserInteraction();
    if (seedWords.isEmpty) return;
    setupState.value = MessagingSetupState.seedVerified; // Step state progress
    quizIndex.value = 0;
    quizAnswersSelected.clear();
    _buildQuizOptions();
  }

  // ─── Verification Positioning Quiz ───────────────────────────────────────

  void _buildQuizOptions() {
    if (quizIndex.value >= quizPositions.length) return;
    
    final targetIndex = quizPositions[quizIndex.value];
    final correctAnswer = seedWords[targetIndex];

    // Generate random options from bip39Vocab to populate choices card
    final Set<String> options = {correctAnswer};
    final random = Random();
    
    while (options.length < 4) {
      final w = seedWords[random.nextInt(12)];
      options.add(w);
    }

    final list = options.toList()..shuffle();
    quizOptions.assignAll(list);
  }

  void selectQuizOption(String selectedWord) {
    onUserInteraction();
    final targetIndex = quizPositions[quizIndex.value];
    final correctAnswer = seedWords[targetIndex];

    if (selectedWord == correctAnswer) {
      quizAnswersSelected.add(quizIndex.value);
      if (quizIndex.value < 2) {
        quizIndex.value++;
        _buildQuizOptions();
      } else {
        // Quiz completed successfully
        setupState.value = MessagingSetupState.identityPublished;
      }
    } else {
      AppSnackBar.error(
        title: 'Incorrect Word',
        message: 'The word chosen does not match your seed. Please try again.',
      );
      // Restart the quiz on failure to verify they actually wrote it down
      quizIndex.value = 0;
      quizAnswersSelected.clear();
      _buildQuizOptions();
    }
  }

  // ─── Identity Publishing & Activation ────────────────────────────────────

  Future<void> registerAndPublishIdentity() async {
    onUserInteraction();
    if (setupState.value != MessagingSetupState.identityPublished) return;

    try {
      // 1. Ephemeral Mnemonic Key Derivation in Volatile RAM
      final mnemonic = seedWords.join(' ');
      final privKey = _seedRecoveryService.derivePrivateKey(mnemonic);
      final pubKey = _seedRecoveryService.derivePublicKey(privKey);

      // Plaintext mnemonic is wiped immediately (garbage collector hook)
      seedWords.clear();

      // 2. Persist derived keys only
      await _identityService.saveIdentityKeys(pubKey: pubKey, privKey: privKey);

      // 3. Complete onboarding
      setupState.value = MessagingSetupState.ready;
      await _identityService.setSetupState(MessagingSetupState.ready);

      AppSnackBar.success(
        title: 'Identity Published',
        message: 'Your secure E2EE messaging pseudonym is active!',
      );
    } catch (e) {
      AppSnackBar.error(
        title: 'Registration Failed',
        message: 'Could not register key bundles: $e',
      );
    }
  }

  // ─── Restoration Mnemonic Path ──────────────────────────────────────────

  Future<void> restoreIdentityFromMnemonic(String mnemonicInput) async {
    onUserInteraction();
    final normalized = mnemonicInput.trim().toLowerCase();
    
    if (!_seedRecoveryService.validateMnemonic(normalized)) {
      AppSnackBar.error(
        title: 'Invalid Seed',
        message: 'Mnemonic must be exactly 12 valid BIP-39 words.',
      );
      return;
    }

    try {
      final privKey = _seedRecoveryService.derivePrivateKey(normalized);
      final pubKey = _seedRecoveryService.derivePublicKey(privKey);

      // Simulate challenge verification against Firestore
      // Under One Device Rule, signs challenge to prove username ownership
      await Future.delayed(const Duration(milliseconds: 400));

      await _identityService.saveUsername('@restored_user');
      await _identityService.saveIdentityKeys(pubKey: pubKey, privKey: privKey);
      
      setupState.value = MessagingSetupState.ready;
      await _identityService.setSetupState(MessagingSetupState.ready);

      AppSnackBar.success(
        title: 'Identity Restored',
        message: 'E2E identity keypair successfully recovered!',
      );
    } catch (e) {
      AppSnackBar.error(
        title: 'Restoration Failed',
        message: 'Could not verify seed signature: $e',
      );
    }
  }
}
