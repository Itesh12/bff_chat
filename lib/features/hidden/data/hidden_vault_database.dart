import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
    );
  }
}

/// Builds the encrypted [QueryExecutor] for the separate [HiddenVaultDatabase].
QueryExecutor buildHiddenEncryptedExecutor(String dbPath, String encryptionKey) {
  return SqfliteQueryExecutor.inDatabaseFolder(
    path: dbPath,
    singleInstance: true,
    creator: (File file) async {
      await openDatabase(
        file.path,
        password: encryptionKey,
        version: 1,
        onConfigure: (db) async {
          // Journal mode set to WAL for concurrency
          await db.rawQuery('PRAGMA journal_mode=WAL;');
          // Enforce foreign key constraints
          await db.execute('PRAGMA foreign_keys=ON;');
        },
      );
    },
  );
}
