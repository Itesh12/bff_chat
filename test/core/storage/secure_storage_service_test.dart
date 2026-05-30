import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/services/secure_storage_service_impl.dart';

class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.clear();
  }
}

void main() {
  late FakeFlutterSecureStorage fakeStorage;
  late SecureStorageServiceImpl secureStorageService;

  setUp(() {
    fakeStorage = FakeFlutterSecureStorage();
    secureStorageService = SecureStorageServiceImpl(storage: fakeStorage);
  });

  group('SecureStorageServiceImpl Tests', () {
    test('write and read successfully store sensitive data', () async {
      await secureStorageService.write('secret_key', 'my_secret_value');
      final value = await secureStorageService.read('secret_key');
      expect(value, 'my_secret_value');
    });

    test('read returns null if key does not exist', () async {
      final value = await secureStorageService.read('non_existent_secret');
      expect(value, isNull);
    });

    test('delete successfully removes single key', () async {
      await secureStorageService.write('key_to_delete', 'val');
      await secureStorageService.delete('key_to_delete');
      final value = await secureStorageService.read('key_to_delete');
      expect(value, isNull);
    });

    test('clearAll wipes entire secure storage', () async {
      await secureStorageService.write('k1', 'v1');
      await secureStorageService.write('k2', 'v2');
      await secureStorageService.clearAll();
      expect(await secureStorageService.read('k1'), isNull);
      expect(await secureStorageService.read('k2'), isNull);
    });
  });
}
