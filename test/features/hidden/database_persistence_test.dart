import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/data/notes/notes_dao.dart';
import 'package:memovault/data/notes/notes_repository_impl.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';
import 'package:memovault/features/hidden/data/repositories/hidden_notes_repository_impl.dart';

void main() {
  group('Database Persistence & State Survival Tests', () {
    late Directory tempDir;
    late File publicDbFile;
    late File hiddenDbFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('memo_persistence_test');
      publicDbFile = File('${tempDir.path}/public_notes.db');
      hiddenDbFile = File('${tempDir.path}/hidden_vault.db');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    // 1. Create Note (Public)
    test('Scenario 1: Create public note survives database restart', () async {
      // Step 1: Open public database and create a note
      var db = AppDatabase(NativeDatabase(publicDbFile));
      var repo = NotesRepositoryImpl(NotesDao(db));
      final note = await repo.createNote(title: 'Public Note 1', body: 'Content 1');
      final noteId = note.id;
      await db.close();

      // Step 2: Restart database and retrieve note
      db = AppDatabase(NativeDatabase(publicDbFile));
      repo = NotesRepositoryImpl(NotesDao(db));
      final retrieved = await repo.getNoteById(noteId);
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Public Note 1');
      expect(retrieved.body, 'Content 1');
      expect(retrieved.isArchived, false);
      await db.close();
    });

    // 2. Archive Note (Public)
    test('Scenario 2: Archive public note survives database restart', () async {
      // Step 1: Create and archive note
      var db = AppDatabase(NativeDatabase(publicDbFile));
      var repo = NotesRepositoryImpl(NotesDao(db));
      final note = await repo.createNote(title: 'Public Note 2', body: 'Content 2');
      final noteId = note.id;
      await repo.archiveNote(noteId);
      await db.close();

      // Step 2: Restart database and verify archived state
      db = AppDatabase(NativeDatabase(publicDbFile));
      repo = NotesRepositoryImpl(NotesDao(db));
      final retrieved = await repo.getNoteById(noteId);
      expect(retrieved, isNotNull);
      expect(retrieved!.isArchived, true);
      await db.close();
    });

    // 3. Soft Delete Note (Public)
    test('Scenario 3: Soft deleted public note survives database restart', () async {
      // Step 1: Create and soft delete note
      var db = AppDatabase(NativeDatabase(publicDbFile));
      var repo = NotesRepositoryImpl(NotesDao(db));
      final note = await repo.createNote(title: 'Public Note 3', body: 'Content 3');
      final noteId = note.id;
      await repo.softDeleteNote(noteId);
      await db.close();

      // Step 2: Restart database and verify soft deleted state
      db = AppDatabase(NativeDatabase(publicDbFile));
      repo = NotesRepositoryImpl(NotesDao(db));
      final retrieved = await repo.getNoteById(noteId);
      expect(retrieved, isNotNull);
      expect(retrieved!.isArchived, false);
      
      final activeNotes = await repo.watchAllNotes().first;
      expect(activeNotes.any((n) => n.id == noteId), false);
      
      final trashed = await repo.getTrashedNotes();
      expect(trashed.any((n) => n.id == noteId), true);
      await db.close();
    });

    // 4. Favorite Note (Public)
    test('Scenario 4: Favorited public note survives database restart', () async {
      // Step 1: Create and favorite note
      var db = AppDatabase(NativeDatabase(publicDbFile));
      var repo = NotesRepositoryImpl(NotesDao(db));
      final note = await repo.createNote(title: 'Public Note 4', body: 'Content 4');
      final noteId = note.id;
      await repo.toggleFavorite(noteId);
      await db.close();

      // Step 2: Restart database and verify favorite state
      db = AppDatabase(NativeDatabase(publicDbFile));
      repo = NotesRepositoryImpl(NotesDao(db));
      final retrieved = await repo.getNoteById(noteId);
      expect(retrieved, isNotNull);
      expect(retrieved!.isFavorite, true);
      await db.close();
    });

    // 5. Create Hidden Note (Hidden)
    test('Scenario 5: Create hidden note survives database restart', () async {
      // Step 1: Create note in hidden database
      var db = HiddenVaultDatabase(NativeDatabase(hiddenDbFile));
      var repo = HiddenNotesRepositoryImpl(db.hiddenNotesDao);
      final note = await repo.createNote(title: 'Hidden Note 1', body: 'Secret Content 1');
      final noteId = note.id;
      await db.close();

      // Step 2: Restart database and retrieve note
      db = HiddenVaultDatabase(NativeDatabase(hiddenDbFile));
      repo = HiddenNotesRepositoryImpl(db.hiddenNotesDao);
      final retrieved = await repo.getNoteById(noteId);
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Hidden Note 1');
      expect(retrieved.body, 'Secret Content 1');
      expect(retrieved.isArchived, false);
      expect(retrieved.isDeleted, false);
      await db.close();
    });

    // 6. Archive Hidden Note (Hidden)
    test('Scenario 6: Archive hidden note survives database restart', () async {
      // Step 1: Create and archive hidden note
      var db = HiddenVaultDatabase(NativeDatabase(hiddenDbFile));
      var repo = HiddenNotesRepositoryImpl(db.hiddenNotesDao);
      final note = await repo.createNote(title: 'Hidden Note 2', body: 'Secret Content 2');
      final noteId = note.id;
      await repo.archiveNote(noteId);
      await db.close();

      // Step 2: Restart database and verify archived state
      db = HiddenVaultDatabase(NativeDatabase(hiddenDbFile));
      repo = HiddenNotesRepositoryImpl(db.hiddenNotesDao);
      final retrieved = await repo.getNoteById(noteId);
      expect(retrieved, isNotNull);
      expect(retrieved!.isArchived, true);
      expect(retrieved.isDeleted, false);
      await db.close();
    });
  });
}
