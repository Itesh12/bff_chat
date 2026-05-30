import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:get/get.dart';

class PinHashingService extends GetxService {
  /// Hashes a PIN using SHA-256 with a salt and key stretching (10,000 iterations).
  String hashPin(String pin, String salt) {
    List<int> bytes = utf8.encode(pin + salt);
    // Key stretching: 10,000 rounds of SHA-256
    for (int i = 0; i < 10000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Url.encode(bytes);
  }

  /// Verifies a PIN against a stored hash and salt.
  bool verifyPin(String pin, String storedHash, String salt) {
    final computedHash = hashPin(pin, salt);
    return computedHash == storedHash;
  }
}
