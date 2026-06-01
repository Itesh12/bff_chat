import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Cryptographic utility class for local media encryption (AES-256-GCM)
/// and compliance escrow key envelope encryption (X25519 ECIES).
abstract final class MediaCryptor {
  static final _aesGcm = AesGcm.with256bits();
  static final _x25519 = X25519();
  static final _hkdf = Hkdf(
    hmac: Hmac(Sha256()),
    outputLength: 32,
  );

  /// Generates a cryptographically secure random 256-bit Media Key (32 bytes).
  static Uint8List generateMediaKey() {
    final rand = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rand.nextInt(256)));
  }

  /// Generates a cryptographically secure random 12-byte IV/Nonce.
  static Uint8List generateIv() {
    final rand = Random.secure();
    return Uint8List.fromList(List.generate(12, (_) => rand.nextInt(256)));
  }

  /// Encrypts local file bytes using AES-256-GCM with the provided [mediaKey].
  /// Returns a concatenated payload: IV (12 bytes) + Ciphertext + Auth Tag (16 bytes).
  static Future<Uint8List> encryptFileBytes(Uint8List plaintext, Uint8List mediaKey) async {
    final secretKey = SecretKey(mediaKey);
    final iv = generateIv();

    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: iv,
    );

    final macBytes = secretBox.mac.bytes;
    final builder = BytesBuilder();
    builder.add(iv);
    builder.add(secretBox.cipherText);
    builder.add(macBytes);
    return builder.takeBytes();
  }

  /// Decrypts a concatenated payload (IV + Ciphertext + Auth Tag) using AES-256-GCM with [mediaKey].
  static Future<Uint8List> decryptFileBytes(Uint8List payload, Uint8List mediaKey) async {
    if (payload.length < 12 + 16) {
      throw ArgumentError('Malformed encrypted payload. Payload length must be at least 28 bytes.');
    }

    final iv = payload.sublist(0, 12);
    final tag = payload.sublist(payload.length - 16);
    final ciphertext = payload.sublist(12, payload.length - 16);

    final secretKey = SecretKey(mediaKey);
    final secretBox = SecretBox(
      ciphertext,
      nonce: iv,
      mac: Mac(tag),
    );

    final decrypted = await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return Uint8List.fromList(decrypted);
  }

  /// Encrypts the [mediaKey] for the compliance officer using X25519 ECIES.
  /// Returns a compliance escrow block containing: ephemeralPublicKey, iv, ciphertext, and authTag.
  static Future<Map<String, String>> encryptKeyForCompliance(
    Uint8List mediaKey,
    String compliancePublicKeyHex,
  ) async {
    final compPubBytes = _hexToBytes(compliancePublicKeyHex);
    final compliancePublicKey = SimplePublicKey(compPubBytes, type: KeyPairType.x25519);

    // 1. Generate ephemeral keypair
    final ephemeralKeyPair = await _x25519.newKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();

    // 2. Compute shared secret
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: ephemeralKeyPair,
      remotePublicKey: compliancePublicKey,
    );

    // 3. Derive KEK via HKDF-SHA256
    final kek = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      info: Uint8List.fromList('MemoVault Compliance Envelope Key'.codeUnits),
    );

    // 4. Encrypt raw mediaKey with KEK via AES-256-GCM
    final iv = generateIv();
    final secretBox = await _aesGcm.encrypt(
      mediaKey,
      secretKey: kek,
      nonce: iv,
    );

    return {
      'ephemeralPublicKey': _bytesToHex(ephemeralPublicKey.bytes),
      'iv': _bytesToHex(iv),
      'ciphertext': _bytesToHex(secretBox.cipherText),
      'authTag': _bytesToHex(secretBox.mac.bytes),
    };
  }

  /// Decrypts a compliance escrow block to retrieve the original [mediaKey].
  /// Primarily used in tests and the admin platform.
  static Future<Uint8List> decryptKeyForCompliance(
    Map<String, String> escrowBlock,
    String compliancePrivateKeyHex,
  ) async {
    final ephemPubBytes = _hexToBytes(escrowBlock['ephemeralPublicKey']!);
    final iv = _hexToBytes(escrowBlock['iv']!);
    final ciphertext = _hexToBytes(escrowBlock['ciphertext']!);
    final authTag = _hexToBytes(escrowBlock['authTag']!);

    final ephemPubKey = SimplePublicKey(ephemPubBytes, type: KeyPairType.x25519);
    final compPrivBytes = _hexToBytes(compliancePrivateKeyHex);

    // Reconstruct compliance keypair from seed/private key
    final compKeyPair = await _x25519.newKeyPairFromSeed(compPrivBytes);

    // Compute shared secret
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: compKeyPair,
      remotePublicKey: ephemPubKey,
    );

    // Derive KEK via HKDF-SHA256
    final kek = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      info: Uint8List.fromList('MemoVault Compliance Envelope Key'.codeUnits),
    );

    // Decrypt media key using KEK
    final secretBox = SecretBox(
      ciphertext,
      nonce: iv,
      mac: Mac(authTag),
    );

    final decrypted = await _aesGcm.decrypt(
      secretBox,
      secretKey: kek,
    );
    return Uint8List.fromList(decrypted);
  }

  // ─── Hex Helpers ──────────────────────────────────────────────────────────

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _hexToBytes(String hex) {
    final length = hex.length;
    final bytes = Uint8List(length ~/ 2);
    for (var i = 0; i < length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }
}
