import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:drift/native.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/core/services/database_service.dart';
import 'package:memovault/core/routes/app_pages.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/core/services/preferences_service.dart';
import 'package:memovault/core/services/network_service.dart';
import 'package:memovault/core/services/theme_service.dart';
import 'package:memovault/core/services/notes_preferences_service.dart';
import 'package:memovault/features/hidden/services/hidden_vault_service.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';
import 'package:memovault/features/hidden/services/activation_trigger_service.dart';
import 'package:memovault/features/hidden/services/pin_hashing_service.dart';
import 'package:memovault/domain/notes/notes_repository.dart';
import 'package:memovault/domain/notes/categories_repository.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/category_entity.dart';
import 'package:memovault/domain/notes/note_sort_mode.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';
import 'package:memovault/features/notes/controllers/notes_search_controller.dart';
import 'package:memovault/features/hidden/controllers/hidden_activation_controller.dart';
import 'package:memovault/features/hidden/controllers/hidden_home_controller.dart';
import 'package:memovault/features/hidden/domain/repositories/hidden_notes_repository.dart';
import 'package:memovault/features/hidden/domain/entities/hidden_note_entity.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';
import 'package:memovault/features/hidden/data/hidden_notes_dao.dart';
import 'package:memovault/core/design_system/design_system.dart';

// Fake implementations for notes dependencies
class FakeNotesRepository implements NotesRepository {
  @override
  Future<NoteEntity> createNote(
      {required String title, required String body, String? categoryId}) async {
    return NoteEntity(
      id: '1',
      title: title,
      body: body,
      categoryId: categoryId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      revision: 1,
      isArchived: false,
      isFavorite: false,
    );
  }

  @override
  Future<NoteEntity> updateNote(NoteEntity note) async => note;

  @override
  Stream<List<NoteEntity>> watchAllNotes(
          {NoteSortMode sort = NoteSortMode.updatedDesc}) =>
      Stream.value([]);

  @override
  Stream<List<NoteEntity>> watchFavoriteNotes(
          {NoteSortMode sort = NoteSortMode.updatedDesc}) =>
      Stream.value([]);

  @override
  Future<List<NoteEntity>> getArchivedNotes(
          {NoteSortMode sort = NoteSortMode.updatedDesc}) async =>
      [];

  @override
  Future<List<NoteEntity>> searchNotes(String query,
          {NoteSortMode sort = NoteSortMode.updatedDesc}) async =>
      [];

  @override
  Future<NoteEntity?> getNoteById(String id) async => null;

  @override
  Future<void> updateLastOpened(String id) async {}

  @override
  Future<void> toggleFavorite(String id) async {}

  @override
  Future<void> archiveNote(String id) async {}

  @override
  Future<void> restoreNote(String id) async {}

  @override
  Future<void> softDeleteNote(String id) async {}

  @override
  Future<void> permanentlyDeleteNote(String id) async {}

  @override
  Future<int> notesCount() async => 0;

  @override
  Future<int> favoritesCount() async => 0;

  @override
  Future<int> archivedCount() async => 0;
}

class FakeCategoriesRepository implements CategoriesRepository {
  @override
  Future<CategoryEntity> createCategory(
      {required String name, required String colorHex}) async {
    return CategoryEntity(
      id: 'c1',
      name: name,
      colorHex: colorHex,
      displayOrder: 0,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<CategoryEntity> updateCategory(CategoryEntity category) async =>
      category;

  @override
  Future<void> deleteCategory(String id) async {}

  @override
  Future<void> reorderCategories(List<String> orderedIds) async {}

  @override
  Future<List<CategoryEntity>> getAllCategories() async => [];
}

class FakeNotesPreferencesService extends NotesPreferencesService {
  FakeNotesPreferencesService() : super(FakePreferences());

  @override
  Future<NoteSortMode> getSortMode() async => NoteSortMode.updatedDesc;

  @override
  Future<void> setSortMode(NoteSortMode mode) async {}

  @override
  Future<NotesViewMode> getViewMode() async => NotesViewMode.grid;

  @override
  Future<void> setViewMode(NotesViewMode mode) async {}

  @override
  Future<String?> getLastSelectedCategory() async => null;

  @override
  Future<void> setLastSelectedCategory(String? categoryId) async {}
}

class FakeSecureStorage implements SecureStorageService {
  @override
  Future<String?> read(String key) async => 'fake_key';
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> clearAll() async {}
}

class FakePreferences implements PreferencesService {
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

class FakeNetwork extends NetworkService {
  @override
  Future<void> init() async {}
  @override
  bool get isConnected => true;
}

class FakeHiddenVaultService extends HiddenVaultService {
  FakeHiddenVaultService(super.secureStorage, super.pinHashing);

  bool isSetup = true;
  bool isUnlocked = false;

  @override
  HiddenVaultDatabase? get db => null;

  @override
  HiddenNotesDao? get notesDao => null;

  @override
  bool get isVaultInitialized => isUnlocked;

  @override
  Future<bool> isVaultSetup() async => isSetup;

  @override
  Future<void> setupVault(String pin) async {
    isSetup = true;
  }

  @override
  Future<bool> unlockVault(String pin) async {
    if (pin == '1234') {
      isUnlocked = true;
      return true;
    }
    return false;
  }

  @override
  Future<void> lockVault() async {
    isUnlocked = false;
  }

  @override
  Future<void> panicWipe() async {
    isSetup = false;
    isUnlocked = false;
  }
}

class FakeHiddenNotesRepository implements HiddenNotesRepository {
  @override
  Stream<List<HiddenNoteEntity>> watchAllNotes() => Stream.value([]);
  @override
  Future<HiddenNoteEntity?> getNoteById(String id) async => null;
  @override
  Future<HiddenNoteEntity> createNote(
      {required String title, required String body}) async {
    return HiddenNoteEntity(
      id: '1',
      title: title,
      body: body,
      revision: 1,
      isFavorite: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<HiddenNoteEntity> updateNote(HiddenNoteEntity note) async => note;
  @override
  Future<void> updateLastOpened(String id) async {}
  @override
  Future<void> toggleFavorite(String id) async {}
  @override
  Future<void> permanentlyDeleteNote(String id) async {}
  @override
  Future<int> notesCount() async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Navigation Stability & Phase 2.2 Audit Tests', () {
    late FakeHiddenVaultService fakeVaultService;
    late HiddenSessionService sessionService;
    late AppDatabase db;
    late DatabaseService dbService;

    setUp(() async {
      Get.reset();

      // Register infrastructure first
      Get.put<ThemeService>(ThemeService(), permanent: true);
      Get.put<SecureStorageService>(FakeSecureStorage(), permanent: true);
      Get.put<PreferencesService>(FakePreferences(), permanent: true);
      Get.put<NetworkService>(FakeNetwork(), permanent: true);

      // Register DatabaseService with in-memory SQLite
      db = AppDatabase(NativeDatabase.memory());
      dbService = DatabaseService(dbFactory: (_, __) => db);
      await dbService.init(dbName: 'test_navigation_stability.db');
      Get.put<DatabaseService>(dbService, permanent: true);

      // Register standard notes dependencies
      final fakeNotesRepo = FakeNotesRepository();
      Get.put<NotesRepository>(fakeNotesRepo, permanent: true);
      Get.put<CategoriesRepository>(FakeCategoriesRepository(),
          permanent: true);
      Get.put<NotesPreferencesService>(FakeNotesPreferencesService(),
          permanent: true);

      // Register hidden vault foundation
      Get.put<ActivationTriggerService>(ActivationTriggerService(),
          permanent: true);
      Get.put<PinHashingService>(PinHashingService(), permanent: true);

      fakeVaultService = FakeHiddenVaultService(
        Get.find<SecureStorageService>(),
        Get.find<PinHashingService>(),
      );
      Get.put<HiddenVaultService>(fakeVaultService, permanent: true);

      sessionService = HiddenSessionService(fakeVaultService);
      Get.put<HiddenSessionService>(sessionService, permanent: true);

      // Bind controllers
      Get.put<NotesController>(
          NotesController(
            Get.find<NotesRepository>(),
            Get.find<CategoriesRepository>(),
            Get.find<NotesPreferencesService>(),
          ),
          permanent: true);

      Get.put<NotesSearchController>(
          NotesSearchController(
            Get.find<NotesRepository>(),
          ),
          permanent: true);

      Get.put<HiddenNotesRepository>(FakeHiddenNotesRepository(),
          permanent: true);
    });

    tearDown(() async {
      await db.close();
      Get.reset();
    });

    testWidgets(
        'Complete Exit Vault navigation routes back to NotesDashboardScreen',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.notes,
          getPages: AppPages.pages,
          defaultTransition: Transition.noTransition,
          transitionDuration: Duration.zero,
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Initial route is notes
      expect(Get.currentRoute, AppRoutes.notes);

      // Go to search
      Get.toNamed(AppRoutes.notesSearch);
      await tester.pump(const Duration(milliseconds: 500));
      expect(Get.currentRoute, AppRoutes.notesSearch);

      // Submit activation key `.4837`
      final searchField = find.byType(TextField).last;
      await tester.enterText(searchField, '.4837');

      final appTextField =
          tester.widget<AppTextField>(find.byType(AppTextField).last);
      appTextField.onSubmitted?.call('.4837');
      await tester.pump(const Duration(milliseconds: 500));

      // Should redirect to Hidden PIN Screen
      expect(Get.currentRoute, AppRoutes.hiddenPin);

      // Input PIN "1234" to unlock
      final controller = Get.find<HiddenActivationController>();
      controller.appendDigit('1');
      controller.appendDigit('2');
      controller.appendDigit('3');
      controller.appendDigit('4');
      await controller.submit();
      await tester.pump(const Duration(milliseconds: 500));

      expect(Get.currentRoute, AppRoutes.hiddenHome);
      expect(sessionService.isActive, true);

      // Click manual logout (Lock Vault button)
      final logoutButton = find.byTooltip('Lock Vault');
      expect(logoutButton, findsOneWidget);
      await tester.tap(logoutButton);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verifications:
      // 1. Current route is Notes Dashboard
      expect(Get.currentRoute, AppRoutes.notes);

      // 2. Hidden Session is locked
      expect(sessionService.isActive, false);
      expect(sessionService.isLocked, true);

      // 3. Hidden controllers are disposed
      expect(Get.isRegistered<HiddenHomeController>(), false);
      expect(Get.isRegistered<HiddenActivationController>(), false);
    });

    testWidgets(
        'Session timeout/auto-lock auto-redirects from hidden routes back to notes',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.notes,
          getPages: AppPages.pages,
          defaultTransition: Transition.noTransition,
          transitionDuration: Duration.zero,
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Navigate straight to Hidden Home for test setup by activating the session
      sessionService.activateSession();
      Get.offAllNamed(AppRoutes.hiddenHome);
      await tester.pump(const Duration(milliseconds: 500));
      expect(Get.currentRoute, AppRoutes.hiddenHome);

      // Force session lock (timeout / background)
      sessionService.lockSession();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verifications:
      // 1. Redirection kicked us out to AppRoutes.notes
      expect(Get.currentRoute, AppRoutes.notes);

      // 2. Hidden controllers are disposed
      expect(Get.isRegistered<HiddenHomeController>(), false);
    });

    testWidgets(
        'Create vault -> Set PIN 1234 -> Restart (Simulated) -> Unlock with 1234 -> Verify Hidden Notes Screen opens',
        (tester) async {
      // 1. Initial State: Vault is NOT setup
      fakeVaultService.isSetup = false;
      fakeVaultService.isUnlocked = false;

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.notes,
          getPages: AppPages.pages,
          defaultTransition: Transition.noTransition,
          transitionDuration: Duration.zero,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Go to PIN Setup (starts since vault is not setup)
      Get.toNamed(AppRoutes.hiddenPin);
      await tester.pump(const Duration(milliseconds: 500));
      expect(Get.currentRoute, AppRoutes.hiddenPin);

      // Create PIN "1234"
      final controller = Get.find<HiddenActivationController>();
      controller.appendDigit('1');
      controller.appendDigit('2');
      controller.appendDigit('3');
      controller.appendDigit('4');
      await controller.submit(); // Enters confirming mode
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.isConfirmingMode.value, isTrue);

      // Confirm PIN "1234"
      controller.appendDigit('1');
      controller.appendDigit('2');
      controller.appendDigit('3');
      controller.appendDigit('4');
      await controller.submit(); // Vault is setup and unlocked
      await tester.pump(const Duration(milliseconds: 500));

      // Verification: Setup succeeds and routes to Hidden Home
      expect(fakeVaultService.isSetup, isTrue);
      expect(fakeVaultService.isVaultInitialized, isTrue);
      expect(Get.currentRoute, AppRoutes.hiddenHome);

      // 2. Restart App (Simulated: lock vault, reset controller states, re-register bindings)
      await fakeVaultService.lockVault();
      sessionService.lockSession();
      await tester.pump(const Duration(milliseconds: 500));

      // Disposed state check
      expect(Get.isRegistered<HiddenHomeController>(), false);
      expect(Get.currentRoute, AppRoutes.notes);

      // Go back to hidden pin (now vault is setup, should request PIN to unlock)
      Get.toNamed(AppRoutes.hiddenPin);
      await tester.pump(const Duration(milliseconds: 500));
      expect(Get.currentRoute, AppRoutes.hiddenPin);

      final lockController = Get.find<HiddenActivationController>();
      expect(lockController.isSetup.value, isTrue);

      // Unlock with correct PIN "1234"
      lockController.appendDigit('1');
      lockController.appendDigit('2');
      lockController.appendDigit('3');
      lockController.appendDigit('4');
      await lockController.submit();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify that hidden notes screen is now open
      expect(Get.currentRoute, AppRoutes.hiddenHome);
      expect(sessionService.isActive, true);

      // Clean up the inactivity timer to avoid leaking it in widget test
      sessionService.lockSession();
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
