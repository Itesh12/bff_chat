import 'package:drift/drift.dart';

import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/storage/sqflite_cipher_executor.dart';
import 'package:memovault/features/hidden/data/hidden_notes_dao.dart';
import 'package:memovault/features/hidden/data/tables/hidden_notes_table.dart';

part 'hidden_vault_database.g.dart';

@DriftDatabase(
  tables: [HiddenNotesTable],
  daos: [HiddenNotesDao],
)
class HiddenVaultDatabase extends _$HiddenVaultDatabase {
  HiddenVaultDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        AppLogger.info('[HiddenVaultDatabase] Creating database tables from scratch (schema v2).');
        await m.createAll();
        AppLogger.info('[HiddenVaultDatabase] Schema v2 created.');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        AppLogger.info('[HiddenVaultDatabase] Upgrading schema from v$from to v$to.');
        if (from < 2) {
          // v1 → v2: add archive/trash/delete tracking columns
          await m.addColumn(hiddenNotesTable, hiddenNotesTable.isArchived);
          await m.addColumn(hiddenNotesTable, hiddenNotesTable.isDeleted);
          await m.addColumn(hiddenNotesTable, hiddenNotesTable.deletedAt);
          
          // Populate defaults for existing rows to avoid NULL values which break WHERE filters
          await m.database.customStatement('UPDATE hidden_notes SET is_archived = 0, is_deleted = 0;');
          
          AppLogger.info('[HiddenVaultDatabase] v2 migration: added isArchived, isDeleted, deletedAt.');
        }
      },
    );
  }
}

/// Builds the encrypted [QueryExecutor] for the separate [HiddenVaultDatabase].
QueryExecutor buildHiddenEncryptedExecutor(String dbPath, String encryptionKey) {
  return SqfliteCipherQueryExecutor(
    path: dbPath,
    password: encryptionKey,
    singleInstance: true,
    onConfigure: (db) async {
      // Journal mode set to WAL for concurrency
      await db.rawQuery('PRAGMA journal_mode=WAL;');
      AppLogger.info('[HiddenVaultDatabase] WAL enabled');
      // Enforce foreign key constraints
      await db.execute('PRAGMA foreign_keys=ON;');
      AppLogger.info('[HiddenVaultDatabase] Foreign keys enabled');
    },
  );
}
