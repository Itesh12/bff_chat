import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/features/hidden/services/activation_trigger_service.dart';

void main() {
  group('ActivationTriggerService Tests', () {
    late ActivationTriggerService service;

    setUp(() {
      service = ActivationTriggerService();
    });

    test('isActivationTrigger returns true for exact matches of .[0-9]{4,8}', () {
      expect(service.isActivationTrigger('.1234'), isTrue);
      expect(service.isActivationTrigger('.12345'), isTrue);
      expect(service.isActivationTrigger('.12345678'), isTrue);
    });

    test('isActivationTrigger returns false for invalid strings', () {
      // Too short
      expect(service.isActivationTrigger('.123'), isFalse);
      // Too long
      expect(service.isActivationTrigger('.123456789'), isFalse);
      // Leading/trailing spaces
      expect(service.isActivationTrigger(' .1234'), isFalse);
      expect(service.isActivationTrigger('.1234 '), isFalse);
      // Missing dot
      expect(service.isActivationTrigger('1234'), isFalse);
      // Non-digits
      expect(service.isActivationTrigger('.123a'), isFalse);
      expect(service.isActivationTrigger('.abcd'), isFalse);
    });

    test('extractPin extracts digits after leading dot when query is valid', () {
      expect(service.extractPin('.1234'), '1234');
      expect(service.extractPin('.12345678'), '12345678');
    });

    test('extractPin returns null when query is invalid', () {
      expect(service.extractPin('1234'), isNull);
      expect(service.extractPin('.123'), isNull);
      expect(service.extractPin('.1234 '), isNull);
    });
  });
}
