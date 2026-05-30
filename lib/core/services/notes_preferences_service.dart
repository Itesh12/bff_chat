import 'package:get/get.dart';
import 'package:memovault/core/services/preferences_service.dart';
import 'package:memovault/domain/notes/note_sort_mode.dart';

enum NotesViewMode { grid, list }

class NotesPreferencesService extends GetxService {
  final PreferencesService _prefs;

  NotesPreferencesService(this._prefs);

  static const _keyViewMode = 'notes_view_mode';
  static const _keySortMode = 'notes_sort_mode';
  static const _keyLastCategory = 'notes_last_category';

  Future<NotesViewMode> getViewMode() async {
    final value = await _prefs.getString(_keyViewMode);
    if (value == NotesViewMode.list.name) {
      return NotesViewMode.list;
    }
    return NotesViewMode.grid; // Default
  }

  Future<void> setViewMode(NotesViewMode mode) async {
    await _prefs.setString(_keyViewMode, mode.name);
  }

  Future<NoteSortMode> getSortMode() async {
    final value = await _prefs.getString(_keySortMode);
    if (value != null) {
      try {
        return NoteSortMode.values.byName(value);
      } catch (_) {
        // Fallback on parse failure
      }
    }
    return NoteSortMode.updatedDesc; // Default
  }

  Future<void> setSortMode(NoteSortMode mode) async {
    await _prefs.setString(_keySortMode, mode.name);
  }

  Future<String?> getLastSelectedCategory() async {
    return await _prefs.getString(_keyLastCategory);
  }

  Future<void> setLastSelectedCategory(String? id) async {
    if (id == null) {
      await _prefs.remove(_keyLastCategory);
    } else {
      await _prefs.setString(_keyLastCategory, id);
    }
  }
}
