import 'dart:io';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';

void main() {
  group('HiddenVaultDatabase Schema Migration Tests', () {
    test('upgrades from v1 to v3 successfully and preserves data', () async {
      // Create a temporary file for the test database
      final tempDir = Directory.systemTemp.createTempSync('memo_migration_test');
      final dbFile = File('${tempDir.path}/test_hidden_vault.db');

      // 1. Setup v1 schema and data using raw SQL on executor 1
      final executorv1 = NativeDatabase(dbFile);
      await executorv1.ensureOpen(_FakeDbUser(1));
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

      // 2. Open the database using our actual Drift class HiddenVaultDatabase
      final executorv3 = NativeDatabase(dbFile);
      final db = HiddenVaultDatabase(executorv3);

      // 3. Assert schema version is 3
      expect(db.schemaVersion, 3);

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
      expect(note1.categoryId, isNull); // Default value from migration

      // Note 2
      final note2 = notes.firstWhere((n) => n.id == '2');
      expect(note2.title, 'Note 2');
      expect(note2.body, 'Body 2');
      expect(note2.isFavorite, true);
      expect(note2.isArchived, false);
      expect(note2.isDeleted, false);
      expect(note2.deletedAt, isNull);
      expect(note2.categoryId, isNull);

      await db.close();
    });

    test('upgrades from v2 to v3 successfully, creates hidden_categories table and categoryId column', () async {
      // Create a temporary file for the test database
      final tempDir = Directory.systemTemp.createTempSync('memo_migration_v3_test');
      final dbFile = File('${tempDir.path}/test_hidden_vault.db');

      // 1. Setup v2 schema and data using raw SQL on executor
      final executorv2 = NativeDatabase(dbFile);
      await executorv2.ensureOpen(_FakeDbUser(2));
      await executorv2.runCustom('''
        CREATE TABLE hidden_notes (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          revision INTEGER NOT NULL,
          is_favorite INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          last_opened_at INTEGER,
          is_archived INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          deleted_at INTEGER
        );
      ''');
      await executorv2.runCustom('PRAGMA user_version = 2;');

      // Insert 2 test notes
      await executorv2.runCustom(
        'INSERT INTO hidden_notes (id, title, body, revision, is_favorite, created_at, updated_at, is_archived, is_deleted) '
        "VALUES ('1', 'Note 1', 'Body 1', 1, 0, 1680000000, 1680000000, 0, 0);"
      );
      await executorv2.runCustom(
        'INSERT INTO hidden_notes (id, title, body, revision, is_favorite, created_at, updated_at, is_archived, is_deleted) '
        "VALUES ('2', 'Note 2', 'Body 2', 2, 1, 1680000100, 1680000100, 1, 0);"
      );

      // Close the connection
      await executorv2.close();

      // 2. Open using Drift class
      final executorv3 = NativeDatabase(dbFile);
      final db = HiddenVaultDatabase(executorv3);

      // Assert schema version is 3
      expect(db.schemaVersion, 3);

      // Verify categories table is created and writable
      await db.customStatement("INSERT INTO hidden_categories (id, name, color_hex, display_order, created_at) VALUES ('cat_1', 'Work', 'FF0000', 0, 1680000000);");
      final catRows = await db.customSelect('SELECT * FROM hidden_categories').get();
      expect(catRows.length, 1);
      expect(catRows.first.read<String>('name'), 'Work');

      // Verify categoryId column is added to hidden_notes table and references categories
      await db.customStatement("UPDATE hidden_notes SET category_id = 'cat_1' WHERE id = '1';");
      final noteRows = await db.customSelect('SELECT * FROM hidden_notes').get();
      expect(noteRows.length, 2);
      
      final note1 = noteRows.firstWhere((r) => r.read<String>('id') == '1');
      expect(note1.read<String>('category_id'), 'cat_1');

      final note2 = noteRows.firstWhere((r) => r.read<String>('id') == '2');
      expect(note2.read<String?>('category_id'), isNull);

      await db.close();
    });
  });
}

class _FakeDbUser extends QueryExecutorUser {
  @override
  final int schemaVersion;

  _FakeDbUser(this.schemaVersion);

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
