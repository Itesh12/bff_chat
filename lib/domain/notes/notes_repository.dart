import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/note_sort_mode.dart';

abstract class NotesRepository {
  // Queries
  Stream<List<NoteEntity>> watchAllNotes({NoteSortMode sort = NoteSortMode.updatedDesc});
  Stream<List<NoteEntity>> watchFavoriteNotes({NoteSortMode sort = NoteSortMode.updatedDesc});
  Future<List<NoteEntity>> getArchivedNotes({NoteSortMode sort = NoteSortMode.updatedDesc});
  Future<List<NoteEntity>> getTrashedNotes({NoteSortMode sort = NoteSortMode.updatedDesc});
  Future<List<NoteEntity>> searchNotes(String query, {NoteSortMode sort = NoteSortMode.updatedDesc});
  Future<NoteEntity?> getNoteById(String id);

  // Mutations
  Future<NoteEntity> createNote({required String title, required String body, String? categoryId});
  Future<NoteEntity> updateNote(NoteEntity note);  // auto-increments revision + sets updatedAt
  Future<void> updateLastOpened(String id);        // updates lastOpenedAt
  Future<void> toggleFavorite(String id);
  Future<void> archiveNote(String id);
  Future<void> restoreNote(String id);
  Future<void> softDeleteNote(String id);
  Future<void> permanentlyDeleteNote(String id);
  Future<void> emptyTrash();

  // Statistics
  Future<int> notesCount();
  Future<int> favoritesCount();
  Future<int> archivedCount();
  Future<int> trashedCount();
}
