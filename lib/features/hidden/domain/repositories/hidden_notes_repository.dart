import 'package:memovault/features/hidden/domain/entities/hidden_note_entity.dart';

abstract class HiddenNotesRepository {
  // --- Active notes (excludes archived and deleted) ---
  Stream<List<HiddenNoteEntity>> watchAllNotes();

  // --- Favorites stream (active + favorited) ---
  Stream<List<HiddenNoteEntity>> watchFavoriteNotes();

  // --- Queries ---
  Future<HiddenNoteEntity?> getNoteById(String id);
  Future<List<HiddenNoteEntity>> getArchivedNotes();
  Future<List<HiddenNoteEntity>> getTrashedNotes();
  Future<List<HiddenNoteEntity>> searchNotes(String query);

  // --- Mutations ---
  Future<HiddenNoteEntity> createNote({required String title, required String body, String? categoryId});
  Future<HiddenNoteEntity> updateNote(HiddenNoteEntity note);
  Future<void> updateLastOpened(String id);
  Future<void> toggleFavorite(String id);
  Future<void> archiveNote(String id);
  Future<void> restoreNote(String id);       // clears isArchived + isDeleted
  Future<void> softDeleteNote(String id);    // sets isDeleted=true, deletedAt=now
  Future<void> permanentlyDeleteNote(String id);
  Future<void> emptyTrash();                 // hard-deletes all isDeleted=true rows

  // --- Statistics ---
  Future<int> notesCount();
  Future<int> favoritesCount();
  Future<int> archivedCount();
  Future<int> trashedCount();
}
