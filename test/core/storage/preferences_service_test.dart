import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:memovault/core/services/preferences_service_impl.dart';

void main() {
  late PreferencesServiceImpl preferencesService;

  setUp(() {
    // Set the platform implementation to the in-memory tester implementation
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData({});
    preferencesService = PreferencesServiceImpl();
  });

  group('PreferencesServiceImpl Tests', () {
    test('setString and getString write and retrieve value', () async {
      await preferencesService.setString('test_key', 'test_value');
      final value = await preferencesService.getString('test_key');
      expect(value, 'test_value');
    });

    test('getString returns null for non-existent key', () async {
      final value = await preferencesService.getString('non_existent');
      expect(value, isNull);
    });

    test('setBool and getBool write and retrieve value', () async {
      await preferencesService.setBool('bool_key', true);
      final value = await preferencesService.getBool('bool_key');
      expect(value, isTrue);
    });

    test('remove deletes entry from storage', () async {
      await preferencesService.setString('key_to_delete', 'value');
      await preferencesService.remove('key_to_delete');
      final value = await preferencesService.getString('key_to_delete');
      expect(value, isNull);
    });
  });
}
