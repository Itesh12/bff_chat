import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/services/notes_preferences_service.dart';
import 'package:memovault/core/services/preferences_service.dart';
import 'package:memovault/domain/notes/note_sort_mode.dart';

class FakePreferencesService implements PreferencesService {
  final Map<String, dynamic> _storage = {};

  @override
  Future<String?> getString(String key) async => _storage[key] as String?;

  @override
  Future<void> setString(String key, String value) async => _storage[key] = value;

  @override
  Future<bool?> getBool(String key) async => _storage[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => _storage[key] = value;

  @override
  Future<void> remove(String key) async => _storage.remove(key);
}

void main() {
  group('NotesPreferencesService Tests', () {
    late FakePreferencesService fakePrefs;
    late NotesPreferencesService service;

    setUp(() {
      fakePrefs = FakePreferencesService();
      service = NotesPreferencesService(fakePrefs);
    });

    test('should return default view mode (grid) when none is saved', () async {
      final mode = await service.getViewMode();
      expect(mode, NotesViewMode.grid);
    });

    test('should persist and retrieve view mode list', () async {
      await service.setViewMode(NotesViewMode.list);
      final mode = await service.getViewMode();
      expect(mode, NotesViewMode.list);
    });

    test('should return default sort mode (updatedDesc) when none is saved', () async {
      final sort = await service.getSortMode();
      expect(sort, NoteSortMode.updatedDesc);
    });

    test('should persist and retrieve sort mode createdAsc', () async {
      await service.setSortMode(NoteSortMode.createdAsc);
      final sort = await service.getSortMode();
      expect(sort, NoteSortMode.createdAsc);
    });

    test('should persist and retrieve last category ID', () async {
      await service.setLastSelectedCategory('cat-123');
      final id = await service.getLastSelectedCategory();
      expect(id, 'cat-123');

      await service.setLastSelectedCategory(null);
      final idNull = await service.getLastSelectedCategory();
      expect(idNull, isNull);
    });
  });
}
