import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal/libsignal.dart';

Uint8List? extractWhisperMessageFromPreKeyMessage(Uint8List preKeyBytes) {
  print('DEBUG: PreKey message bytes = $preKeyBytes');
  if (preKeyBytes.isEmpty) return null;
  int index = 1; // skip version/type byte
  while (index < preKeyBytes.length) {
    // Read key varint
    int key = 0;
    int shift = 0;
    while (index < preKeyBytes.length) {
      int b = preKeyBytes[index++];
      key |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) break;
      shift += 7;
    }
    int tag = key >> 3;
    int wireType = key & 0x7;
    print('DEBUG: tag = $tag, wireType = $wireType, index = $index');

    if (tag == 4 && wireType == 2) {
      // Read length varint
      int length = 0;
      int lShift = 0;
      while (index < preKeyBytes.length) {
        int b = preKeyBytes[index++];
        length |= (b & 0x7F) << lShift;
        if ((b & 0x80) == 0) break;
        lShift += 7;
      }
      print('DEBUG: Found tag 4 length = $length');
      if (index + length <= preKeyBytes.length) {
        return Uint8List.sublistView(preKeyBytes, index, index + length);
      }
      return null;
    } else {
      // Skip field
      if (wireType == 0) { // Varint
        int startVal = index;
        while (index < preKeyBytes.length) {
          int b = preKeyBytes[index++];
          if ((b & 0x80) == 0) break;
        }
        print('DEBUG: Skipped varint from $startVal to $index');
      } else if (wireType == 1) { // 64-bit
        index += 8;
        print('DEBUG: Skipped 64-bit to $index');
      } else if (wireType == 2) { // Length-delimited
        int length = 0;
        int lShift = 0;
        while (index < preKeyBytes.length) {
          int b = preKeyBytes[index++];
          length |= (b & 0x7F) << lShift;
          if ((b & 0x80) == 0) break;
          lShift += 7;
        }
        index += length;
        print('DEBUG: Skipped length-delimited length = $length to $index');
      } else if (wireType == 5) { // 32-bit
        index += 4;
        print('DEBUG: Skipped 32-bit to $index');
      } else {
        print('DEBUG: Unknown wireType $wireType at index $index');
        break;
      }
    }
  }
  return null;
}

void main() {
  setUpAll(() async {
    await LibSignal.init();
  });

  test('Check PreKeySignalMessage parsing', () async {
    // Generate identity keys
    final aliceIdentity = IdentityKeyPair.generate();
    final bobIdentity = IdentityKeyPair.generate();

    final bobSignedPreKeyPair = PrivateKey.generate();
    final bobPrivateKey = PrivateKey.deserialize(bytes: bobIdentity.privateKey);
    final bobSignedPreKeySignature = bobPrivateKey.sign(
      message: bobSignedPreKeyPair.getPublicKey().serialize(),
    );
    final bobSignedPreKeyRecord = SignedPreKeyRecord(
      id: 101,
      timestamp: BigInt.from(123456),
      publicKey: bobSignedPreKeyPair.getPublicKey(),
      privateKey: bobSignedPreKeyPair,
      signature: bobSignedPreKeySignature,
    );

    final bobPreKeyPair = PrivateKey.generate();
    final bobPreKeyRecord = PreKeyRecord(
      id: 201,
      publicKey: bobPreKeyPair.getPublicKey(),
      privateKey: bobPreKeyPair,
    );

    final bobKyberKeyPair = KyberKeyPair.generate();
    final bobKyberPreKeySignature = bobPrivateKey.sign(
      message: bobKyberKeyPair.getPublicKey().serialize(),
    );
    final bobKyberPreKeyRecord = KyberPreKeyRecord.create(
      id: 301,
      timestamp: BigInt.from(123456),
      keyPair: bobKyberKeyPair,
      signature: bobKyberPreKeySignature,
    );

    final bobBundle = PreKeyBundle(
      registrationId: 67890,
      deviceId: 1,
      preKeyId: 201,
      preKeyPublic: bobPreKeyPair.getPublicKey().serialize(),
      signedPreKeyId: 101,
      signedPreKeyPublic: bobSignedPreKeyPair.getPublicKey().serialize(),
      signedPreKeySignature: bobSignedPreKeySignature,
      identityKey: bobIdentity.publicKey,
      kyberPreKeyId: 301,
      kyberPreKeyPublic: bobKyberKeyPair.getPublicKey().serialize(),
      kyberPreKeySignature: bobKyberPreKeySignature,
    );

    final aliceAddress = ProtocolAddress(name: 'alice', deviceId: 1);
    final bobAddress = ProtocolAddress(name: 'bob', deviceId: 1);

    final aliceSessionStore = InMemorySessionStore();
    final aliceIdentityStore = InMemoryIdentityKeyStore(aliceIdentity, 12345);
    final alicePreKeyStore = InMemoryPreKeyStore();
    final aliceSignedPreKeyStore = InMemorySignedPreKeyStore();
    final aliceKyberPreKeyStore = InMemoryKyberPreKeyStore();

    final aliceSessionBuilder = SessionBuilder(
      localAddress: aliceAddress,
      sessionStore: aliceSessionStore,
      identityKeyStore: aliceIdentityStore,
    );

    await aliceSessionBuilder.processPreKeyBundle(bobAddress, bobBundle);

    final aliceCipher = SessionCipher(
      localAddress: aliceAddress,
      sessionStore: aliceSessionStore,
      identityKeyStore: aliceIdentityStore,
      preKeyStore: alicePreKeyStore,
      signedPreKeyStore: aliceSignedPreKeyStore,
      kyberPreKeyStore: aliceKyberPreKeyStore,
    );

    final plaintext = Uint8List.fromList('Hello World'.codeUnits);
    final cipherMsg = await aliceCipher.encrypt(bobAddress, plaintext);

    expect(cipherMsg.type.value, 3); // PreKey message

    // Create bob's cipher to decrypt it
    final bobSessionStore = InMemorySessionStore();
    final bobIdentityStore = InMemoryIdentityKeyStore(bobIdentity, 67890);
    final bobPreKeyStore = InMemoryPreKeyStore();
    final bobSignedPreKeyStore = InMemorySignedPreKeyStore();
    final bobKyberPreKeyStore = InMemoryKyberPreKeyStore();

    await bobPreKeyStore.storePreKey(201, bobPreKeyRecord);
    await bobSignedPreKeyStore.storeSignedPreKey(101, bobSignedPreKeyRecord);
    await bobKyberPreKeyStore.storeKyberPreKey(301, bobKyberPreKeyRecord);

    final bobCipher = SessionCipher(
      localAddress: bobAddress,
      sessionStore: bobSessionStore,
      identityKeyStore: bobIdentityStore,
      preKeyStore: bobPreKeyStore,
      signedPreKeyStore: bobSignedPreKeyStore,
      kyberPreKeyStore: bobKyberPreKeyStore,
    );

    // Decrypting prekey message establishes session on Bob's side
    await bobCipher.decrypt(aliceAddress, cipherMsg);

    // Bob replies to Alice
    final bobReply = await bobCipher.encrypt(aliceAddress, Uint8List.fromList('Reply from Bob'.codeUnits));
    print('DEBUG: Bob reply type = ${bobReply.type.value}');

    // Alice decrypts Bob's reply
    await aliceCipher.decrypt(bobAddress, bobReply);

    // Now Alice encrypts a third message -> this will be a type 2 (SignalMessage)!
    final cipherMsg3 = await aliceCipher.encrypt(bobAddress, Uint8List.fromList('Message 3'.codeUnits));
    expect(cipherMsg3.type.value, 2);

    print('DEBUG: Type 2 SignalMessage serialized bytes = ${cipherMsg3.ciphertext}');
    final signalMsgObj = SignalMessage.deserialize(data: cipherMsg3.ciphertext);
    print('SUCCESS: Deserialized Type 2 SignalMessage, counter = ${signalMsgObj.counter()}');

    final whisperBytes = extractWhisperMessageFromPreKeyMessage(cipherMsg.ciphertext);
    expect(whisperBytes, isNotNull);
    print('DEBUG: whisperBytes first 10 = ${whisperBytes!.take(10).toList()}');

    final extractedSignalMsgObj = SignalMessage.deserialize(data: whisperBytes);
    print('SUCCESS: extracted SignalMessage counter = ${extractedSignalMsgObj.counter()}');
    expect(extractedSignalMsgObj.counter(), 0);
  });
}
