import 'dart:async';
import 'package:get/get.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/services/notes_preferences_service.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/category_entity.dart';
import 'package:memovault/domain/notes/note_sort_mode.dart';
import 'package:memovault/domain/notes/notes_repository.dart';
import 'package:memovault/domain/notes/categories_repository.dart';
import 'package:memovault/domain/notes/note_metrics.dart';

import 'package:memovault/core/observability/performance_tracker.dart';

class NotesController extends GetxController {
  final NotesRepository _notesRepository;
  final CategoriesRepository _categoriesRepository;
  final NotesPreferencesService _prefsService;

  NotesController(
    this._notesRepository,
    this._categoriesRepository,
    this._prefsService,
  );

  // Reactive UI State
  final RxList<NoteEntity> notes = <NoteEntity>[].obs;
  final RxList<CategoryEntity> categories = <CategoryEntity>[].obs;
  final RxBool isLoading = false.obs;
  final Rx<NoteSortMode> sortMode = NoteSortMode.updatedDesc.obs;
  final Rx<NotesViewMode> viewMode = NotesViewMode.grid.obs;
  final Rxn<String> selectedCategoryId = Rxn<String>();

  // Lazy-loaded Statistics for Dashboard Summary
  final RxInt totalNotes = 0.obs;
  final RxInt favoritesCount = 0.obs;
  final RxInt archivedCount = 0.obs;

  StreamSubscription<List<NoteEntity>>? _notesSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadPreferencesAndBootstrap();
  }

  @override
  void onClose() {
    _notesSubscription?.cancel();
    super.onClose();
  }

  Future<void> _loadPreferencesAndBootstrap() async {
    PerformanceTracker.start('notes_dashboard_open');
    isLoading.value = true;
    try {
      // 1. Read persistent preferences
      sortMode.value = await _prefsService.getSortMode();
      viewMode.value = await _prefsService.getViewMode();
      selectedCategoryId.value = await _prefsService.getLastSelectedCategory();

      // 2. Fetch all categories
      PerformanceTracker.start('category_load');
      await refreshCategories();
      PerformanceTracker.finish('category_load');

      // 3. Initiate Drift reactive DB streams
      _restartNotesSubscription();
      
      // 4. Calculate initial counts
      await refreshStats();
    } catch (e, stack) {
      AppLogger.error('Failed to bootstrap NotesController', error: e, stackTrace: stack);
    } finally {
      isLoading.value = false;
      PerformanceTracker.finish('notes_dashboard_open');
    }
  }

  void _restartNotesSubscription() {
    _notesSubscription?.cancel();
    _notesSubscription = _notesRepository.watchAllNotes(sort: sortMode.value).listen(
      (updatedNotes) {
        notes.assignAll(updatedNotes);
      },
      onError: (err) {
        AppLogger.error('Error in watchAllNotes stream', error: err);
      },
    );
  }

  // --- CRUD Category Actions ---
  Future<void> refreshCategories() async {
    try {
      final list = await _categoriesRepository.getAllCategories();
      categories.assignAll(list);
    } catch (e) {
      AppLogger.error('Failed to load categories', error: e);
    }
  }

  Future<CategoryEntity> createCategory({required String name, required String colorHex}) async {
    final cat = await _categoriesRepository.createCategory(name: name, colorHex: colorHex);
    await refreshCategories();
    AppLogger.info('category_created', metadata: {'category_id': cat.id});
    return cat;
  }

  Future<void> deleteCategory(String id) async {
    await _categoriesRepository.deleteCategory(id);
    if (selectedCategoryId.value == id) {
      await setSelectedCategory(null);
    }
    await refreshCategories();
    _restartNotesSubscription();
  }

  // --- Dashboard Filters & UI Preferences ---
  Future<void> setSelectedCategory(String? categoryId) async {
    selectedCategoryId.value = categoryId;
    await _prefsService.setLastSelectedCategory(categoryId);
  }

  Future<void> setSortMode(NoteSortMode mode) async {
    sortMode.value = mode;
    await _prefsService.setSortMode(mode);
    _restartNotesSubscription();
    AppLogger.info('notes_sort_changed', metadata: {'sort': mode.name});
  }

  Future<void> toggleViewMode() async {
    final newMode = viewMode.value == NotesViewMode.grid ? NotesViewMode.list : NotesViewMode.grid;
    viewMode.value = newMode;
    await _prefsService.setViewMode(newMode);
    AppLogger.info('notes_view_toggled', metadata: {'view': newMode.name});
  }

  // --- CRUD Note Mutations ---
  Future<NoteEntity> createNote({required String title, required String body, String? categoryId}) async {
    PerformanceTracker.start('create_note');
    final note = await _notesRepository.createNote(title: title, body: body, categoryId: categoryId);
    final hasCategory = categoryId != null;
    AppLogger.info('note_created', metadata: {'has_category': hasCategory});
    await refreshStats();
    PerformanceTracker.finish('create_note');
    return note;
  }

  Future<NoteEntity> updateNote(NoteEntity note) async {
    PerformanceTracker.start('edit_note');
    final updated = await _notesRepository.updateNote(note);
    final wordCount = NoteMetrics.calculateWordCount(note.body);
    
    // Bucket length for security-safe telemetry
    String charBucket = '0-100';
    if (note.body.length > 500) {
      charBucket = '500+';
    } else if (note.body.length > 100) {
      charBucket = '100-500';
    }
    
    AppLogger.info('note_updated', metadata: {
      'char_count_bucket': charBucket,
      'word_count': wordCount,
    });
    PerformanceTracker.finish('edit_note');
    return updated;
  }

  Future<void> viewNoteDetail(String noteId) async {
    await _notesRepository.updateLastOpened(noteId);
    AppLogger.info('note_opened', metadata: {'source': 'dashboard'});
  }

  Future<void> toggleFavorite(String id) async {
    await _notesRepository.toggleFavorite(id);
    AppLogger.info('note_favorited');
    await refreshStats();
  }

  Future<void> archiveNote(String id) async {
    await _notesRepository.archiveNote(id);
    AppLogger.info('note_archived');
    await refreshStats();
  }

  Future<void> restoreNote(String id) async {
    await _notesRepository.restoreNote(id);
    AppLogger.info('note_restored');
    await refreshStats();
  }

  Future<void> softDeleteNote(String id) async {
    await _notesRepository.softDeleteNote(id);
    AppLogger.info('note_deleted', metadata: {'soft': true});
    await refreshStats();
  }

  Future<void> permanentlyDeleteNote(String id) async {
    await _notesRepository.permanentlyDeleteNote(id);
    AppLogger.info('note_deleted', metadata: {'soft': false});
    await refreshStats();
  }

  Future<void> refreshStats() async {
    try {
      totalNotes.value = await _notesRepository.notesCount();
      favoritesCount.value = await _notesRepository.favoritesCount();
      archivedCount.value = await _notesRepository.archivedCount();
    } catch (e) {
      AppLogger.error('Failed to refresh stats', error: e);
    }
  }

  // Filtered helper matching dashboard filter selection
  List<NoteEntity> get filteredNotes {
    final catId = selectedCategoryId.value;
    if (catId == null) {
      return notes;
    }
    return notes.where((note) => note.categoryId == catId).toList();
  }
}
