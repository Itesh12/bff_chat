import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';
import 'package:memovault/features/hidden/data/repositories/hidden_notes_repository_impl.dart';

void main() {
  group('Hidden Vault Archive Flow Integration Tests', () {
    late HiddenVaultDatabase db;
    late HiddenNotesRepositoryImpl repo;

    setUp(() {
      db = HiddenVaultDatabase(NativeDatabase.memory());
      repo = HiddenNotesRepositoryImpl(db.hiddenNotesDao);
    });

    tearDown(() async {
      await db.close();
    });

    test('Hidden Vault Archive Lifecycle: Create -> Archive -> Restore', () async {
      // 1. Create note
      final note = await repo.createNote(title: 'Secret Note 1', body: 'Classified');
      final id = note.id;

      var activeList = await repo.watchAllNotes().first;
      expect(activeList.any((n) => n.id == id), true);

      // 2. Archive note
      await repo.archiveNote(id);

      activeList = await repo.watchAllNotes().first;
      expect(activeList.any((n) => n.id == id), false);

      var archivedList = await repo.getArchivedNotes();
      expect(archivedList.any((n) => n.id == id), true);

      // 3. Restore note
      await repo.restoreNote(id);

      activeList = await repo.watchAllNotes().first;
      expect(activeList.any((n) => n.id == id), true);

      archivedList = await repo.getArchivedNotes();
      expect(archivedList.any((n) => n.id == id), false);
    });
  });
}
