import 'package:memovault/features/hidden/domain/entities/hidden_note_entity.dart';

abstract class HiddenNotesRepository {
  Stream<List<HiddenNoteEntity>> watchAllNotes();
  Future<HiddenNoteEntity?> getNoteById(String id);
  Future<HiddenNoteEntity> createNote({required String title, required String body});
  Future<HiddenNoteEntity> updateNote(HiddenNoteEntity note);
  Future<void> updateLastOpened(String id);
  Future<void> toggleFavorite(String id);
  Future<void> permanentlyDeleteNote(String id);
  Future<int> notesCount();
}
