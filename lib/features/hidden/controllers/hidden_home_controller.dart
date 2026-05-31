import 'dart:async';
import 'package:get/get.dart';
import 'package:memovault/core/design_system/feedback/app_snack_bar.dart';
import 'package:memovault/domain/notes/category_entity.dart';
import 'package:memovault/features/hidden/domain/entities/hidden_note_entity.dart';
import 'package:memovault/features/hidden/domain/repositories/hidden_notes_repository.dart';
import 'package:memovault/features/hidden/domain/repositories/hidden_categories_repository.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';

class HiddenHomeController extends GetxController {
  final HiddenNotesRepository _notesRepository;
  final HiddenCategoriesRepository _categoriesRepository;
  final HiddenSessionService _sessionService;

  HiddenHomeController(this._notesRepository, this._categoriesRepository, this._sessionService);

  final RxList<HiddenNoteEntity> notes = <HiddenNoteEntity>[].obs;
  final RxList<CategoryEntity> categories = <CategoryEntity>[].obs;
  StreamSubscription<List<HiddenNoteEntity>>? _notesSubscription;
  final Rxn<String> selectedCategoryId = Rxn<String>();
  final RxInt selectedSegmentIndex = 0.obs; // 0 = Notes, 1 = Chats

  // Reactive Stats
  final RxInt notesCount = 0.obs;
  final RxInt favoritesCount = 0.obs;
  final RxInt archivedCount = 0.obs;
  final RxInt trashedCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _bootstrapHiddenHomeController();
  }

  Future<void> _bootstrapHiddenHomeController() async {
    await refreshCategories();
    _notesSubscription = _notesRepository.watchAllNotes().listen((data) {
      notes.assignAll(data);
      refreshStats();
    });
    await refreshStats();
  }

  @override
  void onClose() {
    _notesSubscription?.cancel();
    super.onClose();
  }

  /// Resets the inactivity timer on any user interaction in the hidden vault.
  void onUserInteraction() {
    _sessionService.resetInactivityTimer();
  }

  Future<void> refreshStats() async {
    notesCount.value = await _notesRepository.notesCount();
    favoritesCount.value = await _notesRepository.favoritesCount();
    archivedCount.value = await _notesRepository.archivedCount();
    trashedCount.value = await _notesRepository.trashedCount();
  }

  Future<void> refreshCategories() async {
    try {
      final list = await _categoriesRepository.getAllCategories();
      categories.assignAll(list);
    } catch (_) {}
  }

  Future<CategoryEntity> createCategory({required String name, required String colorHex}) async {
    onUserInteraction();
    final cat = await _categoriesRepository.createCategory(name: name, colorHex: colorHex);
    await refreshCategories();
    return cat;
  }

  Future<void> deleteCategory(String id) async {
    onUserInteraction();
    await _categoriesRepository.deleteCategory(id);
    if (selectedCategoryId.value == id) {
      await setSelectedCategory(null);
    }
    await refreshCategories();
  }

  Future<void> setSelectedCategory(String? categoryId) async {
    selectedCategoryId.value = categoryId;
  }

  Future<void> createNote(String title, String body, {String? categoryId}) async {
    onUserInteraction();
    await _notesRepository.createNote(title: title, body: body, categoryId: categoryId);
    await refreshStats();
    AppSnackBar.success(
      title: 'Saved',
      message: 'Secret note saved.',
    );
  }

  Future<void> updateNote(HiddenNoteEntity note) async {
    onUserInteraction();
    await _notesRepository.updateNote(note);
    await refreshStats();
    AppSnackBar.success(
      title: 'Updated',
      message: 'Secret note updated.',
    );
  }

  Future<void> toggleFavorite(String id) async {
    onUserInteraction();
    final note = await _notesRepository.getNoteById(id);
    if (note != null) {
      await _notesRepository.toggleFavorite(id);
      await refreshStats();
      if (note.isFavorite) {
        AppSnackBar.info(
          title: 'Unfavorited',
          message: 'Removed from favorites',
        );
      } else {
        AppSnackBar.success(
          title: 'Favorited',
          message: 'Added to favorites',
        );
      }
    }
  }

  Future<void> archiveNote(String id) async {
    onUserInteraction();
    await _notesRepository.archiveNote(id);
    await refreshStats();
    AppSnackBar.success(
      title: 'Archived',
      message: 'Note archived',
    );
  }

  Future<void> restoreNote(String id) async {
    onUserInteraction();
    await _notesRepository.restoreNote(id);
    await refreshStats();
    AppSnackBar.success(
      title: 'Restored',
      message: 'Note restored',
    );
  }

  Future<void> softDeleteNote(String id) async {
    onUserInteraction();
    await _notesRepository.softDeleteNote(id);
    await refreshStats();
    AppSnackBar.success(
      title: 'Deleted',
      message: 'Moved to trash',
    );
  }

  Future<void> permanentlyDeleteNote(String id) async {
    onUserInteraction();
    await _notesRepository.permanentlyDeleteNote(id);
    await refreshStats();
    AppSnackBar.success(
      title: 'Purged',
      message: 'Permanently deleted.',
    );
  }

  Future<void> emptyTrash() async {
    onUserInteraction();
    await _notesRepository.emptyTrash();
    await refreshStats();
    AppSnackBar.success(
      title: 'Cleared',
      message: 'Vault trash cleared.',
    );
  }

  Future<List<HiddenNoteEntity>> searchNotes(String query) async {
    onUserInteraction();
    return _notesRepository.searchNotes(query);
  }

  List<HiddenNoteEntity> get filteredNotes {
    final catId = selectedCategoryId.value;
    if (catId == null) {
      return notes;
    }
    return notes.where((note) => note.categoryId == catId).toList();
  }

  void logout() {
    _sessionService.lockSession();
  }
}
