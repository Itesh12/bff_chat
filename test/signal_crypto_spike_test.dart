// ignore_for_file: avoid_print, prefer_const_declarations
import 'dart:typed_data';
import 'package:libsignal/libsignal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    // Initialize native FFI library
    print('Initializing LibSignal...');
    await LibSignal.init();
    print('LibSignal Initialized.');
  });

  test('Perform full cryptographic flow: Identity, Prekeys, X3DH, Encrypt, Decrypt', () async {
    expect(LibSignal.isInitialized, isTrue);

    // 1. Generate Alice and Bob identities
    print('Step 1: Generating identities...');
    final aliceIdentity = IdentityKeyPair.generate();
    final bobIdentity = IdentityKeyPair.generate();

    print('Alice Identity Public Key Size: ${aliceIdentity.publicKey.length}');
    print('Bob Identity Public Key Size: ${bobIdentity.publicKey.length}');

    final bobPrivateKey = PrivateKey.deserialize(bytes: bobIdentity.privateKey);

    // 2. Generate Bob's Signed Prekey
    print('Step 2: Generating Bob Signed Prekey...');
    final bobSignedPreKeyId = 101;
    final bobSignedPreKeyPair = PrivateKey.generate();
    final bobSignedPreKeyPublicKey = bobSignedPreKeyPair.getPublicKey();
    final bobSignedPreKeySignature = bobPrivateKey.sign(
      message: bobSignedPreKeyPublicKey.serialize(),
    );

    final bobSignedPreKeyRecord = SignedPreKeyRecord(
      id: bobSignedPreKeyId,
      timestamp: BigInt.from(DateTime.now().millisecondsSinceEpoch),
      publicKey: bobSignedPreKeyPublicKey,
      privateKey: bobSignedPreKeyPair,
      signature: bobSignedPreKeySignature,
    );

    // 3. Generate Bob's One-Time Prekey
    print('Step 3: Generating Bob One-Time Prekey...');
    final bobPreKeyId = 201;
    final bobPreKeyPair = PrivateKey.generate();
    final bobPreKeyPublicKey = bobPreKeyPair.getPublicKey();
    final bobPreKeyRecord = PreKeyRecord(
      id: bobPreKeyId,
      publicKey: bobPreKeyPublicKey,
      privateKey: bobPreKeyPair,
    );

    // 4. Generate Bob's Kyber Prekey (required by libsignal-rust FFI)
    print('Step 4: Generating Bob Kyber Prekey...');
    final bobKyberPreKeyId = 301;
    final bobKyberKeyPair = KyberKeyPair.generate();
    final bobKyberPreKeySignature = bobPrivateKey.sign(
      message: bobKyberKeyPair.getPublicKey().serialize(),
    );

    final bobKyberPreKeyRecord = KyberPreKeyRecord.create(
      id: bobKyberPreKeyId,
      timestamp: BigInt.from(DateTime.now().millisecondsSinceEpoch),
      keyPair: bobKyberKeyPair,
      signature: bobKyberPreKeySignature,
    );

    // 5. Establish In-Memory Stores
    print('Step 5: Setting up in-memory stores...');
    final aliceAddress = ProtocolAddress(name: 'alice-uuid', deviceId: 1);
    final bobAddress = ProtocolAddress(name: 'bob-uuid', deviceId: 1);

    // Alice Stores
    final aliceSessionStore = InMemorySessionStore();
    final aliceIdentityStore = InMemoryIdentityKeyStore(
      aliceIdentity,
      12345, // Registration ID
    );
    final alicePreKeyStore = InMemoryPreKeyStore();
    final aliceSignedPreKeyStore = InMemorySignedPreKeyStore();
    final aliceKyberPreKeyStore = InMemoryKyberPreKeyStore();

    // Bob Stores
    final bobSessionStore = InMemorySessionStore();
    final bobIdentityStore = InMemoryIdentityKeyStore(
      bobIdentity,
      67890, // Registration ID
    );
    final bobPreKeyStore = InMemoryPreKeyStore();
    final bobSignedPreKeyStore = InMemorySignedPreKeyStore();
    final bobKyberPreKeyStore = InMemoryKyberPreKeyStore();

    // Bob publishes his prekeys to his store
    await bobPreKeyStore.storePreKey(bobPreKeyId, bobPreKeyRecord);
    await bobSignedPreKeyStore.storeSignedPreKey(bobSignedPreKeyId, bobSignedPreKeyRecord);
    await bobKyberPreKeyStore.storeKyberPreKey(bobKyberPreKeyId, bobKyberPreKeyRecord);

    // 6. Build bob bundle for X3DH Handshake
    print('Step 6: Creating Prekey Bundle...');
    final bobBundle = PreKeyBundle(
      registrationId: 67890,
      deviceId: 1,
      preKeyId: bobPreKeyId,
      preKeyPublic: bobPreKeyPublicKey.serialize(),
      signedPreKeyId: bobSignedPreKeyId,
      signedPreKeyPublic: bobSignedPreKeyPublicKey.serialize(),
      signedPreKeySignature: bobSignedPreKeySignature,
      identityKey: bobIdentity.publicKey,
      kyberPreKeyId: bobKyberPreKeyId,
      kyberPreKeyPublic: bobKyberKeyPair.getPublicKey().serialize(),
      kyberPreKeySignature: bobKyberPreKeySignature,
    );

    // 7. Perform Handshake: Alice processes Bob's prekey bundle
    print('Step 7: Executing X3DH handshake (Alice processes Bob bundle)...');
    final aliceSessionBuilder = SessionBuilder(
      localAddress: aliceAddress,
      sessionStore: aliceSessionStore,
      identityKeyStore: aliceIdentityStore,
    );

    await aliceSessionBuilder.processPreKeyBundle(bobAddress, bobBundle);
    expect(await aliceSessionStore.containsSession(bobAddress), isTrue);
    print('Alice successfully established session with Bob.');

    // 8. Alice Encrypts Payload
    print('Step 8: Encrypting payload Alice -> Bob...');
    final aliceCipher = SessionCipher(
      localAddress: aliceAddress,
      sessionStore: aliceSessionStore,
      identityKeyStore: aliceIdentityStore,
      preKeyStore: alicePreKeyStore,
      signedPreKeyStore: aliceSignedPreKeyStore,
      kyberPreKeyStore: aliceKyberPreKeyStore,
    );

    final rawMessage = Uint8List.fromList('Antigravity Secure E2EE Payload!'.codeUnits);
    final ciphertextMessage = await aliceCipher.encrypt(bobAddress, rawMessage);
    print('Ciphertext type: ${ciphertextMessage.type}');
    print('Ciphertext length: ${ciphertextMessage.ciphertext.length}');

    // 9. Bob Decrypts Payload
    print('Step 9: Decrypting payload on Bob side...');
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
    print('Decrypted message: "$decryptedString"');

    expect(decryptedString, equals('Antigravity Secure E2EE Payload!'));
    print('SUCCESS: E2EE crypto operations executed flawlessly without data loss!');
  });

  test('Check KyberKeyPair properties', () {
    final kp = KyberKeyPair.generate();
    try {
      print('KyberKeyPair properties:');
      print('Public key: ${kp.getPublicKey()}');
      // Let's check kp.privateKey, kp.private, kp.getPrivateKey() etc.
      // We can use reflection or try-catch block for compile checks.
    } catch (e) {
      print('Error checking KyberKeyPair: $e');
    }
  });
}
