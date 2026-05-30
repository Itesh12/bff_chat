import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:memovault/core/storage/tables/app_metadata_table.dart';
import 'package:memovault/core/storage/tables/categories_table.dart';
import 'package:memovault/core/storage/tables/notes_table.dart';
import 'package:memovault/data/notes/notes_dao.dart';
import 'package:memovault/data/notes/categories_dao.dart';

part 'app_database.g.dart';

/// The single Drift database instance for MemoVault.
///
/// Contains infrastructure and feature tables:
///   - [AppMetadata] — internal key-value config store
///   - [CategoriesTable] — notes categories
///   - [NotesTable] — encrypted notes repository
///
/// Schema version history must be documented and migrated here.
@DriftDatabase(
  tables: [AppMetadata, CategoriesTable, NotesTable],
  daos: [NotesDao, CategoriesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(categoriesTable);
          await m.createTable(notesTable);
        }
      },
    );
  }
}

/// Builds the encrypted [QueryExecutor] for [AppDatabase].
///
/// WAL note: `PRAGMA journal_mode=WAL;` returns a result row, so it MUST
/// use [Database.rawQuery] rather than [Database.execute] (which forbids
/// result-returning statements in the Android sqflite plugin).
///
/// Foreign-key enforcement is set via [Database.execute] because
/// `PRAGMA foreign_keys=ON;` returns no rows.
QueryExecutor buildEncryptedExecutor(String dbPath, String encryptionKey) {
  return SqfliteQueryExecutor.inDatabaseFolder(
    path: dbPath,
    singleInstance: true,
    creator: (File file) async {
      await openDatabase(
        file.path,
        password: encryptionKey,
        version: 1,
        onConfigure: (db) async {
          // rawQuery — returns rows (journal mode string), so execute() fails.
          await db.rawQuery('PRAGMA journal_mode=WAL;');
          // execute — returns no rows, safe.
          await db.execute('PRAGMA foreign_keys=ON;');
        },
      );
    },
  );
}
