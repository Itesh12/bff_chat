import 'package:drift/drift.dart';

import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/storage/sqflite_cipher_executor.dart';
import 'package:memovault/core/storage/tables/messaging_tables.dart';
import 'package:memovault/core/storage/tables/cryptographic_tables.dart';
import 'package:memovault/features/hidden/data/hidden_notes_dao.dart';
import 'package:memovault/features/hidden/data/tables/hidden_notes_table.dart';
import 'package:memovault/features/hidden/data/tables/hidden_categories_table.dart';
import 'package:memovault/features/hidden/data/hidden_categories_dao.dart';

part 'hidden_vault_database.g.dart';

@DriftDatabase(
  tables: [
    HiddenNotesTable,
    HiddenCategoriesTable,
    ParticipantsTable,
    ConversationsTable,
    MessagesTable,
    MessageReceiptsTable,
    AttachmentsTable,
    SyncMetadataTable,
    SignalSessionsTable,
    SignalOneTimePrekeysTable,
    SignalSkippedKeysTable,
  ],
  daos: [HiddenNotesDao, HiddenCategoriesDao],
)
class HiddenVaultDatabase extends _$HiddenVaultDatabase {
  HiddenVaultDatabase(super.e);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        AppLogger.info('[HiddenVaultDatabase] Creating database tables from scratch (schema v8).');
        await m.createAll();
        AppLogger.info('[HiddenVaultDatabase] Schema v8 created.');
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
        if (from < 3) {
          // v2 → v3: add hidden categories and category reference
          await m.createTable(hiddenCategoriesTable);
          await m.addColumn(hiddenNotesTable, hiddenNotesTable.categoryId);
          
          AppLogger.info('[HiddenVaultDatabase] v3 migration: added hiddenCategoriesTable and categoryId column.');
        }
        if (from < 4) {
          // v3 → v4: add secure messaging tables
          await m.createTable(participantsTable);
          await m.createTable(conversationsTable);
          await m.createTable(messagesTable);
          await m.createTable(messageReceiptsTable);
          await m.createTable(attachmentsTable);
          await m.createTable(syncMetadataTable);
          
          AppLogger.info('[HiddenVaultDatabase] v4 migration: added secure messaging tables.');
        } else if (from < 5) {
          await m.addColumn(participantsTable, participantsTable.trustState);
          AppLogger.info('[HiddenVaultDatabase] v5 migration: added participantsTable.trustState column.');
        }
        if (from < 6) {
          await m.createTable(signalSessionsTable);
          await m.createTable(signalOneTimePrekeysTable);
          await m.createTable(signalSkippedKeysTable);
          AppLogger.info('[HiddenVaultDatabase] v6 migration: added cryptographic tables.');
        }
        if (from >= 4 && from < 7) {
          await m.addColumn(conversationsTable, conversationsTable.draft);
          await m.addColumn(conversationsTable, conversationsTable.isPinned);
          await m.addColumn(messagesTable, messagesTable.searchIndex);
          await m.deleteTable('attachments');
          await m.createTable(attachmentsTable);
          AppLogger.info('[HiddenVaultDatabase] v7 migration: added draft, isPinned, searchIndex, and recreated attachments.');
        }
        if (from < 8) {
          if (from == 7) {
            await m.addColumn(attachmentsTable, attachmentsTable.uploadedBytes);
            await m.addColumn(attachmentsTable, attachmentsTable.totalBytes);
            await m.addColumn(attachmentsTable, attachmentsTable.encryptionVersion);
            await m.addColumn(attachmentsTable, attachmentsTable.checksumSha256);
            AppLogger.info('[HiddenVaultDatabase] v8 migration: added progress, versioning, and checksum to attachments.');
          }
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
