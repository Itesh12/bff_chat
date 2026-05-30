import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'tables/app_metadata_table.dart';

part 'app_database.g.dart';

/// The single Drift database instance for MemoVault.
///
/// Contains only infrastructure tables at Phase 1.4:
///   - [AppMetadata] — internal key-value config store
///
/// Feature tables (Notes, Vault, Messages, Media) are added in later phases.
/// Schema version history must be documented and migrated here.
@DriftDatabase(tables: [AppMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  /// No migrations needed yet. Stubs here to ease future additions.
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
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
    creator: (File file) {
      return openDatabase(
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
