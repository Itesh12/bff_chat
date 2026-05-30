import 'dart:io';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';

void main() {
  group('HiddenVaultDatabase Schema Migration Tests (v1 to v2)', () {
    test('upgrades from v1 to v2 successfully and preserves data', () async {
      // Create a temporary file for the test database
      final tempDir = Directory.systemTemp.createTempSync('memo_migration_test');
      final dbFile = File('${tempDir.path}/test_hidden_vault.db');

      // 1. Setup v1 schema and data using raw SQL on executor 1
      final executorv1 = NativeDatabase(dbFile);
      await executorv1.ensureOpen(_FakeDbUser());
      await executorv1.runCustom('''
        CREATE TABLE hidden_notes (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          revision INTEGER NOT NULL,
          is_favorite INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          last_opened_at INTEGER
        );
      ''');
      await executorv1.runCustom('PRAGMA user_version = 1;');

      // Insert 3 test notes
      await executorv1.runCustom(
        'INSERT INTO hidden_notes (id, title, body, revision, is_favorite, created_at, updated_at) '
        "VALUES ('1', 'Note 1', 'Body 1', 1, 0, 1680000000, 1680000000);"
      );
      await executorv1.runCustom(
        'INSERT INTO hidden_notes (id, title, body, revision, is_favorite, created_at, updated_at) '
        "VALUES ('2', 'Note 2', 'Body 2', 2, 1, 1680000100, 1680000100);"
      );
      await executorv1.runCustom(
        'INSERT INTO hidden_notes (id, title, body, revision, is_favorite, created_at, updated_at) '
        "VALUES ('3', 'Note 3', 'Body 3', 3, 0, 1680000200, 1680000200);"
      );

      // Close the v1 connection
      await executorv1.close();

      // 2. Open the database as v2 using our actual Drift class HiddenVaultDatabase
      final executorv2 = NativeDatabase(dbFile);
      final db = HiddenVaultDatabase(executorv2);

      // 3. Assert schema version is 2
      expect(db.schemaVersion, 2);

      // 5. Query all notes and verify they exist and have correct values
      final notes = await db.hiddenNotesDao.watchAllNotes().first;
      expect(notes.length, 3);

      // Note 1
      final note1 = notes.firstWhere((n) => n.id == '1');
      expect(note1.title, 'Note 1');
      expect(note1.body, 'Body 1');
      expect(note1.isFavorite, false);
      expect(note1.isArchived, false); // Default value from migration
      expect(note1.isDeleted, false);  // Default value from migration
      expect(note1.deletedAt, isNull); // Default value from migration

      // Note 2
      final note2 = notes.firstWhere((n) => n.id == '2');
      expect(note2.title, 'Note 2');
      expect(note2.body, 'Body 2');
      expect(note2.isFavorite, true);
      expect(note2.isArchived, false);
      expect(note2.isDeleted, false);
      expect(note2.deletedAt, isNull);

      await db.close();
    });
  });
}

class _FakeDbUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
