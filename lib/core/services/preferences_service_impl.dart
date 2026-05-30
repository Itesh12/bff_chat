import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memovault/core/services/preferences_service.dart';

class PreferencesServiceImpl extends GetxService implements PreferencesService {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<String?> getString(String key) async {
    return await _prefs.getString(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  @override
  Future<bool?> getBool(String key) async {
    return await _prefs.getBool(key);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}
