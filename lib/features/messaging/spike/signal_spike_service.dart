import 'dart:typed_data';
import 'package:libsignal/libsignal.dart';

class SignalSpikeTestResult {
  final String stepName;
  final bool isSuccess;
  final String detail;
  final String? error;

  SignalSpikeTestResult({
    required this.stepName,
    required this.isSuccess,
    required this.detail,
    this.error,
  });
}

class SignalSpikeService {
  final List<String> logs = [];
  final List<SignalSpikeTestResult> results = [];

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    logs.add('[$timestamp] $message');
    print('SignalSpikeService: $message');
  }

  Future<bool> runDiagnostics() async {
    logs.clear();
    results.clear();
    _log('Starting libsignal runtime cryptographic diagnostics...');

    // 1. Initialize native library
    try {
      _log('Executing: Init LibSignal library...');
      await LibSignal.init();
      final initialized = LibSignal.isInitialized;
      results.add(SignalSpikeTestResult(
        stepName: 'Library Initialization',
        isSuccess: initialized,
        detail: initialized ? 'Native FFI library loaded successfully' : 'Native FFI library returned uninitialized',
      ));
      if (!initialized) throw StateError('Library failed to initialize.');
    } catch (e) {
      _log('ERROR initializing library: $e');
      results.add(SignalSpikeTestResult(
        stepName: 'Library Initialization',
        isSuccess: false,
        detail: 'FFI link or symbol error during initialization',
        error: e.toString(),
      ));
      return false; // Cannot proceed if init fails
    }

    IdentityKeyPair? aliceIdentity;
    IdentityKeyPair? bobIdentity;
    PrivateKey? bobPrivateKey;

    // 2. Generate Identity Keys
    try {
      _log('Executing: Generate Identity Key Pair...');
      aliceIdentity = IdentityKeyPair.generate();
      bobIdentity = IdentityKeyPair.generate();
      final success = aliceIdentity.publicKey.isNotEmpty && bobIdentity.publicKey.isNotEmpty;
      results.add(SignalSpikeTestResult(
        stepName: 'Generate Identity Keys',
        isSuccess: success,
        detail: 'Generated keys: Alice public key length = ${aliceIdentity.publicKey.length} bytes, Bob public key length = ${bobIdentity.publicKey.length} bytes',
      ));
      bobPrivateKey = PrivateKey.deserialize(bytes: bobIdentity.privateKey);
    } catch (e) {
      _log('ERROR generating identity keys: $e');
      results.add(SignalSpikeTestResult(
        stepName: 'Generate Identity Keys',
        isSuccess: false,
        detail: 'Failed to generate Curve25519 identity keypairs',
        error: e.toString(),
      ));
    }

    PrivateKey? bobSignedPreKeyPair;
    PublicKey? bobSignedPreKeyPublicKey;
    Uint8List? bobSignedPreKeySignature;

    // 3. Generate Signed Prekey
    try {
      _log('Executing: Generate Signed Prekey...');
      if (bobPrivateKey == null) throw StateError('Identity key unavailable.');
      final bobSignedPreKeyId = 101;
      bobSignedPreKeyPair = PrivateKey.generate();
      bobSignedPreKeyPublicKey = bobSignedPreKeyPair.getPublicKey();
      bobSignedPreKeySignature = bobPrivateKey.sign(
        message: bobSignedPreKeyPublicKey.serialize(),
      );

      final bobSignedPreKeyRecord = SignedPreKeyRecord(
        id: bobSignedPreKeyId,
        timestamp: BigInt.from(DateTime.now().millisecondsSinceEpoch),
        publicKey: bobSignedPreKeyPublicKey,
        privateKey: bobSignedPreKeyPair,
        signature: bobSignedPreKeySignature,
      );

      results.add(SignalSpikeTestResult(
        stepName: 'Generate Signed Prekey',
        isSuccess: bobSignedPreKeyRecord.publicKey().isNotEmpty,
        detail: 'Generated ID: $bobSignedPreKeyId, Signature Size: ${bobSignedPreKeySignature.length} bytes',
      ));
    } catch (e) {
      _log('ERROR generating signed prekey: $e');
      results.add(SignalSpikeTestResult(
        stepName: 'Generate Signed Prekey',
        isSuccess: false,
        detail: 'Failed to generate or sign medium-term prekey',
        error: e.toString(),
      ));
    }

    PrivateKey? bobPreKeyPair;
    PublicKey? bobPreKeyPublicKey;
    PreKeyRecord? bobPreKeyRecord;

    // 4. Generate One-Time Prekey
    try {
      _log('Executing: Generate One-Time Prekey...');
      final bobPreKeyId = 201;
      bobPreKeyPair = PrivateKey.generate();
      bobPreKeyPublicKey = bobPreKeyPair.getPublicKey();
      bobPreKeyRecord = PreKeyRecord(
        id: bobPreKeyId,
        publicKey: bobPreKeyPublicKey,
        privateKey: bobPreKeyPair,
      );

      results.add(SignalSpikeTestResult(
        stepName: 'Generate One-Time Prekey',
        isSuccess: bobPreKeyRecord.publicKey().isNotEmpty,
        detail: 'Generated Prekey ID: $bobPreKeyId, Public Key Size: ${bobPreKeyRecord.publicKey().length} bytes',
      ));
    } catch (e) {
      _log('ERROR generating one-time prekey: $e');
      results.add(SignalSpikeTestResult(
        stepName: 'Generate One-Time Prekey',
        isSuccess: false,
        detail: 'Failed to generate ephemeral Curve25519 prekey',
        error: e.toString(),
      ));
    }

    KyberKeyPair? bobKyberKeyPair;
    Uint8List? bobKyberPreKeySignature;
    KyberPreKeyRecord? bobKyberPreKeyRecord;

    // 5. Generate Kyber PQ Prekey
    try {
      _log('Executing: Generate Kyber PQ Prekey...');
      if (bobPrivateKey == null) throw StateError('Identity key unavailable.');
      final bobKyberPreKeyId = 301;
      bobKyberKeyPair = KyberKeyPair.generate();
      bobKyberPreKeySignature = bobPrivateKey.sign(
        message: bobKyberKeyPair.getPublicKey().serialize(),
      );

      bobKyberPreKeyRecord = KyberPreKeyRecord.create(
        id: bobKyberPreKeyId,
        timestamp: BigInt.from(DateTime.now().millisecondsSinceEpoch),
        keyPair: bobKyberKeyPair,
        signature: bobKyberPreKeySignature,
      );

      results.add(SignalSpikeTestResult(
        stepName: 'Generate Kyber Prekey',
        isSuccess: bobKyberPreKeyRecord.signature().isNotEmpty,
        detail: 'Post-Quantum Kyber key generated. Public Key: ${bobKyberKeyPair.getPublicKey().serialize().length} bytes, Signature: ${bobKyberPreKeySignature.length} bytes',
      ));
    } catch (e) {
      _log('ERROR generating Kyber prekey: $e');
      results.add(SignalSpikeTestResult(
        stepName: 'Generate Kyber Prekey',
        isSuccess: false,
        detail: 'Failed to generate PQ-Kyber prekey or construct record',
        error: e.toString(),
      ));
    }

    // Alice Stores
    final aliceAddress = ProtocolAddress(name: 'alice-uuid', deviceId: 1);
    final bobAddress = ProtocolAddress(name: 'bob-uuid', deviceId: 1);
    final aliceSessionStore = InMemorySessionStore();
    InMemoryIdentityKeyStore? aliceIdentityStore;
    final alicePreKeyStore = InMemoryPreKeyStore();
    final aliceSignedPreKeyStore = InMemorySignedPreKeyStore();
    final aliceKyberPreKeyStore = InMemoryKyberPreKeyStore();

    // Bob Stores
    final bobSessionStore = InMemorySessionStore();
    InMemoryIdentityKeyStore? bobIdentityStore;
    final bobPreKeyStore = InMemoryPreKeyStore();
    final bobSignedPreKeyStore = InMemorySignedPreKeyStore();
    final bobKyberPreKeyStore = InMemoryKyberPreKeyStore();

    // Setup Stores
    if (aliceIdentity != null && bobIdentity != null) {
      aliceIdentityStore = InMemoryIdentityKeyStore(aliceIdentity, 12345);
      bobIdentityStore = InMemoryIdentityKeyStore(bobIdentity, 67890);
    }

    // Bob publishes to store
    if (bobPreKeyRecord != null) {
      await bobPreKeyStore.storePreKey(201, bobPreKeyRecord);
    }
    if (bobSignedPreKeyPublicKey != null && bobSignedPreKeyPair != null && bobSignedPreKeySignature != null) {
      final signedRecord = SignedPreKeyRecord(
        id: 101,
        timestamp: BigInt.from(DateTime.now().millisecondsSinceEpoch),
        publicKey: bobSignedPreKeyPublicKey,
        privateKey: bobSignedPreKeyPair,
        signature: bobSignedPreKeySignature,
      );
      await bobSignedPreKeyStore.storeSignedPreKey(101, signedRecord);
    }
    if (bobKyberPreKeyRecord != null) {
      await bobKyberPreKeyStore.storeKyberPreKey(301, bobKyberPreKeyRecord);
    }

    PreKeyBundle? bobBundle;

    // 6. X3DH Handshake Setup (Prekey bundle building)
    try {
      _log('Executing: Create Bob Prekey Bundle...');
      if (bobIdentity == null ||
          bobPreKeyPublicKey == null ||
          bobSignedPreKeyPublicKey == null ||
          bobSignedPreKeySignature == null ||
          bobKyberKeyPair == null ||
          bobKyberPreKeySignature == null) {
        throw StateError('Prekey bundle dependency elements are missing.');
      }

      bobBundle = PreKeyBundle(
        registrationId: 67890,
        deviceId: 1,
        preKeyId: 201,
        preKeyPublic: bobPreKeyPublicKey.serialize(),
        signedPreKeyId: 101,
        signedPreKeyPublic: bobSignedPreKeyPublicKey.serialize(),
        signedPreKeySignature: bobSignedPreKeySignature,
        identityKey: bobIdentity.publicKey,
        kyberPreKeyId: 301,
        kyberPreKeyPublic: bobKyberKeyPair.getPublicKey().serialize(),
        kyberPreKeySignature: bobKyberPreKeySignature,
      );

      results.add(SignalSpikeTestResult(
        stepName: 'Build Prekey Bundle',
        isSuccess: true,
        detail: 'PreKeyBundle successfully built with Curve25519 and PQ Kyber keys',
      ));
    } catch (e) {
      _log('ERROR building bundle: $e');
      results.add(SignalSpikeTestResult(
        stepName: 'Build Prekey Bundle',
        isSuccess: false,
        detail: 'Failed to pack key elements into PreKeyBundle',
        error: e.toString(),
      ));
    }

    // 7. Perform local X3DH Handshake
    bool handshakeSuccess = false;
    try {
      _log('Executing: Perform X3DH Handshake...');
      if (bobBundle == null || aliceIdentityStore == null) {
        throw StateError('Handshake dependencies are missing.');
      }

      final aliceSessionBuilder = SessionBuilder(
        localAddress: aliceAddress,
        sessionStore: aliceSessionStore,
        identityKeyStore: aliceIdentityStore,
      );

      await aliceSessionBuilder.processPreKeyBundle(bobAddress, bobBundle);
      handshakeSuccess = await aliceSessionStore.containsSession(bobAddress);

      results.add(SignalSpikeTestResult(
        stepName: 'X3DH Handshake',
        isSuccess: handshakeSuccess,
        detail: handshakeSuccess ? 'Alice successfully initialized Curve25519 & Kyber session with Bob' : 'Handshake returned false session existence',
      ));
    } catch (e) {
      _log('ERROR performing handshake: $e');
      results.add(SignalSpikeTestResult(
        stepName: 'X3DH Handshake',
        isSuccess: false,
        detail: 'Handshake execution aborted or failed to derive shared secret',
        error: e.toString(),
      ));
    }

    CiphertextMessage? ciphertextMessage;

    // 8. Encrypt Payload
    try {
      _log('Executing: Encrypt Payload (Alice -> Bob)...');
      if (!handshakeSuccess || aliceIdentityStore == null) {
        throw StateError('Established session is required for encryption.');
      }

      final aliceCipher = SessionCipher(
        localAddress: aliceAddress,
        sessionStore: aliceSessionStore,
        identityKeyStore: aliceIdentityStore,
        preKeyStore: alicePreKeyStore,
        signedPreKeyStore: aliceSignedPreKeyStore,
        kyberPreKeyStore: aliceKyberPreKeyStore,
      );

      final plaintext = Uint8List.fromList('Spike validation message.'.codeUnits);
      ciphertextMessage = await aliceCipher.encrypt(bobAddress, plaintext);

      results.add(SignalSpikeTestResult(
        stepName: 'Encrypt Payload',
        isSuccess: ciphertextMessage.ciphertext.isNotEmpty,
        detail: 'Encrypted message type: ${ciphertextMessage.type.name}, Ciphertext Size: ${ciphertextMessage.ciphertext.length} bytes',
      ));
    } catch (e) {
      _log('ERROR encrypting payload: $e');
      results.add(SignalSpikeTestResult(
        stepName: 'Encrypt Payload',
        isSuccess: false,
        detail: 'Failed to run Double Ratchet step or AES-GCM encryption',
        error: e.toString(),
      ));
    }

    // 9. Decrypt Payload
    try {
      _log('Executing: Decrypt Payload (Bob side)...');
      if (ciphertextMessage == null || bobIdentityStore == null) {
        throw StateError('Ciphertext message or Bob identity store missing.');
      }

      final bobCipher = SessionCipher(
        localAddress: bobAddress,
        sessionStore: bobSessionStore,
        identityKeyStore: bobIdentityStore,
        preKeyStore: bobPreKeyStore,
        signedPreKeyStore: bobSignedPreKeyStore,
        kyberPreKeyStore: bobKyberPreKeyStore,
      );

      final decryptedMessage = await bobCipher.decrypt(aliceAddress, ciphertextMessage);
      final decryptedString = String.fromCharCodes(decryptedMessage);
      final verified = decryptedString == 'Spike validation message.';

      results.add(SignalSpikeTestResult(
        stepName: 'Decrypt Payload',
        isSuccess: verified,
        detail: verified ? 'Decrypted and verified matches plaintext: "$decryptedString"' : 'Decrypted plaintext does not match original plaintext: "$decryptedString"',
      ));
    } catch (e) {
      _log('ERROR decrypting payload: $e');
      results.add(SignalSpikeTestResult(
        stepName: 'Decrypt Payload',
        isSuccess: false,
        detail: 'Failed to run decryption ratchet, signature verify, or MAC verify',
        error: e.toString(),
      ));
    }

    final overallSuccess = results.every((element) => element.isSuccess);
    _log('E2EE diagnostics execution finished. Overall Success: $overallSuccess');
    return overallSuccess;
  }
}
