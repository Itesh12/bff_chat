// ignore_for_file: avoid_print
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/data/notes/notes_dao.dart';
import 'package:memovault/data/notes/notes_repository_impl.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';
import 'package:memovault/features/hidden/data/repositories/hidden_notes_repository_impl.dart';
import 'package:memovault/features/hidden/data/hidden_notes_dao.dart';

import '../helpers/note_seeder.dart';

void main() {
  group('Database & Search Performance Benchmarks', () {
    test('Public Notes Benchmarks — 100 / 500 / 1000 notes', () async {
      // 1. Setup in-memory DB & Repo
      final db = AppDatabase(NativeDatabase.memory());
      final dao = NotesDao(db);
      final repo = NotesRepositoryImpl(dao);

      // Measure 100 notes cold load
      await NoteSeeder.seedPublicNotes(db, 100);
      final stopwatch100 = Stopwatch()..start();
      final notes100 = await repo.watchAllNotes().first;
      stopwatch100.stop();
      expect(notes100.length, 100);
      print('Public Notes 100 cold load time: ${stopwatch100.elapsedMilliseconds}ms');
      expect(stopwatch100.elapsedMilliseconds, lessThan(300)); // Threshold: < 300ms

      // Measure 500 notes cold load (total 500 notes, seed 400 more)
      await NoteSeeder.seedPublicNotes(db, 400);
      final stopwatch500 = Stopwatch()..start();
      final notes500 = await repo.watchAllNotes().first;
      stopwatch500.stop();
      expect(notes500.length, 500);
      print('Public Notes 500 cold load time: ${stopwatch500.elapsedMilliseconds}ms');
      expect(stopwatch500.elapsedMilliseconds, lessThan(600)); // Threshold: < 600ms

      // Measure 1000 notes cold load (total 1000 notes, seed 500 more)
      await NoteSeeder.seedPublicNotes(db, 500);
      final stopwatch1000 = Stopwatch()..start();
      final notes1000 = await repo.watchAllNotes().first;
      stopwatch1000.stop();
      expect(notes1000.length, 1000);
      print('Public Notes 1000 cold load time: ${stopwatch1000.elapsedMilliseconds}ms');
      expect(stopwatch1000.elapsedMilliseconds, lessThan(1200)); // Threshold: < 1200ms

      // Measure 2-character query search at 1000 notes
      final stopwatchSearch = Stopwatch()..start();
      final results = await repo.searchNotes('Title'); // Matches "Title" in seeded titles
      stopwatchSearch.stop();
      expect(results.length, 1000);
      print('Public Notes 1000 search query time: ${stopwatchSearch.elapsedMilliseconds}ms');
      expect(stopwatchSearch.elapsedMilliseconds, lessThan(500)); // Threshold: < 500ms

      await db.close();
    });

    test('Hidden Vault Notes Benchmarks — 100 / 500 / 1000 notes', () async {
      // 1. Setup in-memory Hidden DB & Repo
      final db = HiddenVaultDatabase(NativeDatabase.memory());
      final dao = HiddenNotesDao(db);
      final repo = HiddenNotesRepositoryImpl(dao);

      // Measure 100 notes cold load
      await NoteSeeder.seedHiddenNotes(db, 100);
      final stopwatch100 = Stopwatch()..start();
      final notes100 = await repo.watchAllNotes().first;
      stopwatch100.stop();
      expect(notes100.length, 100);
      print('Hidden Notes 100 cold load time: ${stopwatch100.elapsedMilliseconds}ms');
      expect(stopwatch100.elapsedMilliseconds, lessThan(300)); // Threshold: < 300ms

      // Measure 500 notes cold load
      await NoteSeeder.seedHiddenNotes(db, 400);
      final stopwatch500 = Stopwatch()..start();
      final notes500 = await repo.watchAllNotes().first;
      stopwatch500.stop();
      expect(notes500.length, 500);
      print('Hidden Notes 500 cold load time: ${stopwatch500.elapsedMilliseconds}ms');
      expect(stopwatch500.elapsedMilliseconds, lessThan(600)); // Threshold: < 600ms

      // Measure 1000 notes cold load
      await NoteSeeder.seedHiddenNotes(db, 500);
      final stopwatch1000 = Stopwatch()..start();
      final notes1000 = await repo.watchAllNotes().first;
      stopwatch1000.stop();
      expect(notes1000.length, 1000);
      print('Hidden Notes 1000 cold load time: ${stopwatch1000.elapsedMilliseconds}ms');
      expect(stopwatch1000.elapsedMilliseconds, lessThan(1200)); // Threshold: < 1200ms

      // Measure 2-character query search at 1000 notes
      final stopwatchSearch = Stopwatch()..start();
      final results = await repo.searchNotes('confidential'); // Matches "confidential" in bodies
      stopwatchSearch.stop();
      expect(results.length, 1000);
      print('Hidden Notes 1000 search query time: ${stopwatchSearch.elapsedMilliseconds}ms');
      expect(stopwatchSearch.elapsedMilliseconds, lessThan(500)); // Threshold: < 500ms

      await db.close();
    });
  });
}
