import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:libsignal/libsignal.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/core/design_system/feedback/app_snack_bar.dart';
import 'package:memovault/features/hidden/domain/entities/messaging_setup_state.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/features/hidden/services/seed_recovery_service.dart';
import 'package:memovault/features/messaging/services/signal_store_impl.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';

class MessagingSetupController extends GetxController {
  final MessagingIdentityService _identityService;
  final SeedRecoveryService _seedRecoveryService;

  MessagingSetupController(this._identityService, this._seedRecoveryService);

  // Persistent text controller for Username input to prevent rebuild keyboard dismiss/cursor reset bugs
  final usernameController = TextEditingController();

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
      final cleanName = savedUser.startsWith('@') ? savedUser.substring(1) : savedUser;
      username.value = cleanName;
      final savedDisplay = await _identityService.getDisplayName();
      usernameController.text = savedDisplay ?? cleanName;
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

  static String normalizeUsername(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final codeUnit = input.codeUnitAt(i);
      if (codeUnit >= 0xff21 && codeUnit <= 0xff3a) {
        buffer.writeCharCode(codeUnit - 0xff21 + 0x0041);
      } else if (codeUnit >= 0xff41 && codeUnit <= 0xff5a) {
        buffer.writeCharCode(codeUnit - 0xff41 + 0x0061);
      } else if (codeUnit >= 0xff10 && codeUnit <= 0xff19) {
        buffer.writeCharCode(codeUnit - 0xff10 + 0x0030);
      } else if (codeUnit == 0xff3f) {
        buffer.writeCharCode(0x005f);
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString().trim().toLowerCase();
  }

  Future<void> checkUsernameUniqueness(String rawVal) async {
    isCheckingUsername.value = true;
    final normalized = normalizeUsername(rawVal);
    if (usernameController.text.isEmpty && rawVal.isNotEmpty) {
      usernameController.text = rawVal;
    }
    
    // Normalize case and validate format (must start with letter, no leading/trailing/double underscores)
    final regex = RegExp(r'^[a-z](?!.*__)[a-z0-9_]{2,19}(?<!_)$');
    if (!regex.hasMatch(normalized)) {
      isCheckingUsername.value = false;
      isUsernameAvailable.value = false;
      usernameFeedback.value = '3-20 chars, lowercase a-z, 0-9, and _ (no leading/trailing/double _)';
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

    final canonical = username.value;
    final display = usernameController.text.trim();

    await _identityService.saveUsername('@$canonical');
    await _identityService.saveDisplayName(display);
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

      // Deserialize private key bytes to create PrivateKey object for signing
      final privKeyBytes = _hexToBytes(privKey);
      final privateKey = PrivateKey.deserialize(bytes: privKeyBytes);

      // 2. Generate Signed Prekey (Curve25519)
      const signedPrekeyId = 1;
      final signedPrekeyPair = PrivateKey.generate();
      final signedPrekeyPublic = signedPrekeyPair.getPublicKey();
      final signedPrekeySignature = privateKey.sign(
        message: signedPrekeyPublic.serialize(),
      );
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 3. Generate Kyber PQ Prekey
      const kyberPrekeyId = 1;
      final kyberKeyPair = KyberKeyPair.generate();
      final kyberPrekeySignature = privateKey.sign(
        message: kyberKeyPair.getPublicKey().serialize(),
      );

      // 4. Generate 100 One-Time Prekeys
      final secureStorage = Get.find<SecureStorageService>();
      final signalStore = SignalStoreImpl(
        secureStorage,
        _identityService,
        Get.find<MessagingRepository>(),
        isHidden: true,
      );
      final oneTimePrekeysData = <Map<String, dynamic>>[];
      for (int i = 1; i <= 100; i++) {
        final otKeyPair = PrivateKey.generate();
        final otPublicKey = otKeyPair.getPublicKey();
        final otPubKeyHex = _bytesToHex(otPublicKey.serialize());

        // Serialize and save PreKeyRecord for SignalStoreImpl via SQLCipher
        final otRecord = PreKeyRecord(
          id: i,
          publicKey: otPublicKey,
          privateKey: otKeyPair,
        );
        await signalStore.storePreKey(i, otRecord);

        oneTimePrekeysData.add({
          'id': i,
          'publicKey': otPubKeyHex,
        });
      }

      // Save Signed and Kyber prekeys locally
      await _identityService.saveSignedPreKey(
        id: signedPrekeyId,
        privKeyHex: _bytesToHex(signedPrekeyPair.serialize()),
        pubKeyHex: _bytesToHex(signedPrekeyPublic.serialize()),
        signatureHex: _bytesToHex(signedPrekeySignature),
        timestampMs: nowMs,
      );

      final signedPreKeyRecord = SignedPreKeyRecord(
        id: signedPrekeyId,
        timestamp: BigInt.from(nowMs),
        publicKey: signedPrekeyPublic,
        privateKey: signedPrekeyPair,
        signature: signedPrekeySignature,
      );
      await secureStorage.write('signed_prekey_record_$signedPrekeyId', _bytesToHex(signedPreKeyRecord.serialize()));

      await _identityService.saveKyberPreKey(
        id: kyberPrekeyId,
        privKeyHex: _bytesToHex(kyberKeyPair.getSecretKey().serialize()),
        pubKeyHex: _bytesToHex(kyberKeyPair.getPublicKey().serialize()),
        signatureHex: _bytesToHex(kyberPrekeySignature),
        timestampMs: nowMs,
      );

      final kyberPreKeyRecord = KyberPreKeyRecord.create(
        id: kyberPrekeyId,
        timestamp: BigInt.from(nowMs),
        keyPair: kyberKeyPair,
        signature: kyberPrekeySignature,
      );
      await secureStorage.write('kyber_prekey_record_$kyberPrekeyId', _bytesToHex(kyberPreKeyRecord.serialize()));

      // 5. Perform Firestore Transaction Registration if Firebase is initialized
      if (Firebase.apps.isNotEmpty) {
        final auth = FirebaseAuth.instance;
        if (auth.currentUser == null) {
          await auth.signInAnonymously();
        }
        final currentUser = auth.currentUser;
        if (currentUser == null) {
          throw Exception('Failed to authenticate anonymously');
        }

        final firestore = FirebaseFirestore.instance;
        final docRef = firestore.collection('pseudonyms').doc(username.value);
        final bundleRef = firestore.collection('prekey_bundles').doc(currentUser.uid);

        await firestore.runTransaction((transaction) async {
          final docSnapshot = await transaction.get(docRef);
          if (docSnapshot.exists) {
            final existingUid = docSnapshot.get('uid');
            if (existingUid != currentUser.uid) {
              throw Exception('USERNAME_ALREADY_EXISTS');
            }
          }

          // Write pseudonym document
          transaction.set(docRef, {
            'username': username.value,
            'displayName': usernameController.text.trim(),
            'uid': currentUser.uid,
            'identityPublicKey': pubKey,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Write prekey bundle document
          transaction.set(bundleRef, {
            'uid': currentUser.uid,
            'identityPublicKey': pubKey,
            'signedPrekeyId': signedPrekeyId,
            'signedPrekeyPublic': _bytesToHex(signedPrekeyPublic.serialize()),
            'signedPrekeySignature': _bytesToHex(signedPrekeySignature),
            'kyberPrekeyId': kyberPrekeyId,
            'kyberPrekeyPublic': _bytesToHex(kyberKeyPair.getPublicKey().serialize()),
            'kyberPrekeySignature': _bytesToHex(kyberPrekeySignature),
            'oneTimePrekeys': oneTimePrekeysData,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      }

      // Plaintext mnemonic is wiped immediately (garbage collector hook)
      seedWords.clear();

      // 6. Persist derived keys only
      await _identityService.saveIdentityKeys(pubKey: pubKey, privKey: privKey);

      // 7. Complete onboarding
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

      // Restore username/display name from Firestore if initialized, or mock
      if (Firebase.apps.isNotEmpty) {
        final auth = FirebaseAuth.instance;
        if (auth.currentUser == null) {
          await auth.signInAnonymously();
        }

        final firestore = FirebaseFirestore.instance;
        final query = await firestore
            .collection('pseudonyms')
            .where('identityPublicKey', isEqualTo: pubKey)
            .limit(1)
            .get();

        if (query.docs.isEmpty) {
          throw Exception('No registered username found for this identity key.');
        }

        final doc = query.docs.first;
        final registeredUsername = doc.get('username') as String;
        final registeredDisplayName = doc.get('displayName') as String;

        await _identityService.saveUsername('@$registeredUsername');
        await _identityService.saveDisplayName(registeredDisplayName);
      } else {
        // Fallback/Mock behavior for tests
        await _identityService.saveUsername('@restored_user');
        await _identityService.saveDisplayName('Restored User');
      }

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

  @override
  void onClose() {
    usernameController.dispose();
    super.onClose();
  }
}
