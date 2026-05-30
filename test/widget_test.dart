import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:memovault/app.dart';
import 'package:memovault/core/services/theme_service.dart';
import 'package:memovault/core/services/preferences_service.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/core/services/database_service.dart';
import 'package:memovault/core/services/network_service.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:drift/native.dart';

class FakeSecureStorage extends GetxService implements SecureStorageService {
  final String _testKey = DatabaseService.generate256BitKey();

  @override
  Future<String?> read(String key) async => _testKey;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> clearAll() async {}
}

class FakePreferences extends GetxService implements PreferencesService {
  @override
  Future<String?> getString(String key) async => null;
  @override
  Future<void> setString(String key, String value) async {}
  @override
  Future<bool?> getBool(String key) async => null;
  @override
  Future<void> setBool(String key, bool value) async {}
  @override
  Future<void> remove(String key) async {}
}

class FakeNetwork extends GetxService implements NetworkService {
  @override
  Future<void> init() async {}

  @override
  bool get isConnected => true;
}

void main() {
  testWidgets('App renders without crashing', (tester) async {
    // Register all required infrastructure stubs
    Get.put<ThemeService>(ThemeService(), permanent: true);
    Get.put<SecureStorageService>(FakeSecureStorage(), permanent: true);
    Get.put<PreferencesService>(FakePreferences(), permanent: true);
    Get.put<NetworkService>(FakeNetwork(), permanent: true);

    // In-memory Drift database
    final db = AppDatabase(NativeDatabase.memory());
    final dbService = DatabaseService(dbFactory: (_, __) => db);
    await dbService.init(dbName: 'test_widget_app.db');
    Get.put<DatabaseService>(dbService, permanent: true);

    await tester.pumpWidget(const App());
    expect(find.byType(App), findsOneWidget);
    
    // Clean up
    await db.close();
    Get.reset();
  });
}
