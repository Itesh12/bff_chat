import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/data/notes/notes_dao.dart';
import 'package:memovault/data/notes/notes_repository_impl.dart';

void main() {
  group('Public Notes Trash Flow Integration Tests', () {
    late AppDatabase db;
    late NotesRepositoryImpl repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = NotesRepositoryImpl(NotesDao(db));
    });

    tearDown(() async {
      await db.close();
    });

    test(
        'Full Trash Lifecycle: Create -> Soft Delete -> Restore -> Trash -> Empty',
        () async {
      // 1. Create note
      final note =
          await repo.createNote(title: 'Trash Note 1', body: 'Trash Content');
      final id = note.id;

      var activeList = await repo.watchAllNotes().first;
      expect(activeList.any((n) => n.id == id), true);

      // 2. Soft delete
      await repo.softDeleteNote(id);

      activeList = await repo.watchAllNotes().first;
      expect(activeList.any((n) => n.id == id), false);

      var trashedList = await repo.getTrashedNotes();
      expect(trashedList.any((n) => n.id == id), true);

      // 3. Restore
      await repo.restoreNote(id);

      activeList = await repo.watchAllNotes().first;
      expect(activeList.any((n) => n.id == id), true);

      trashedList = await repo.getTrashedNotes();
      expect(trashedList.any((n) => n.id == id), false);

      // 4. Soft delete again & empty trash
      await repo.softDeleteNote(id);
      await repo.emptyTrash();

      trashedList = await repo.getTrashedNotes();
      expect(trashedList.isEmpty, true);

      activeList = await repo.watchAllNotes().first;
      expect(activeList.isEmpty, true);

      final retrieved = await repo.getNoteById(id);
      expect(retrieved, isNull);
    });
  });
}
