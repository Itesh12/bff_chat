import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/features/hidden/services/pin_hashing_service.dart';

void main() {
  group('PinHashingService Tests', () {
    late PinHashingService service;

    setUp(() {
      service = PinHashingService();
    });

    test('hashPin returns a non-empty base64url encoded hash', () {
      final hash = service.hashPin('1234', 'somesalt');
      expect(hash, isNotEmpty);
      expect(hash, isNot('1234'));
    });

    test('hashPin produces identical output for same pin and salt', () {
      final hash1 = service.hashPin('1234', 'salt1');
      final hash2 = service.hashPin('1234', 'salt1');
      expect(hash1, hash2);
    });

    test('hashPin produces different output for different salt or pin', () {
      final hash1 = service.hashPin('1234', 'salt1');
      final hash2 = service.hashPin('1234', 'salt2');
      final hash3 = service.hashPin('5678', 'salt1');

      expect(hash1, isNot(hash2));
      expect(hash1, isNot(hash3));
    });

    test('verifyPin returns true for correct credentials and false otherwise', () {
      const pin = '123456';
      const salt = 'random_salt_123';
      final storedHash = service.hashPin(pin, salt);

      expect(service.verifyPin(pin, storedHash, salt), isTrue);
      expect(service.verifyPin('123457', storedHash, salt), isFalse);
      expect(service.verifyPin(pin, storedHash, 'different_salt'), isFalse);
    });
  });
}
