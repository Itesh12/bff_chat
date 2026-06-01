import 'package:drift/drift.dart';

import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/storage/sqflite_cipher_executor.dart';
import 'package:memovault/core/storage/tables/app_metadata_table.dart';
import 'package:memovault/core/storage/tables/categories_table.dart';
import 'package:memovault/core/storage/tables/notes_table.dart';
import 'package:memovault/core/storage/tables/messaging_tables.dart';
import 'package:memovault/core/storage/tables/cryptographic_tables.dart';
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
  tables: [
    AppMetadata,
    CategoriesTable,
    NotesTable,
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
  daos: [NotesDao, CategoriesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        AppLogger.info('[AppDatabase] Creating database tables from scratch.');
        await m.createAll();
        AppLogger.info('[AppDatabase] Migration completed');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        AppLogger.info('[AppDatabase] Upgrading database from version $from to $to.');
        if (from < 2) {
          await m.createTable(categoriesTable);
          await m.createTable(notesTable);
        }
        if (from < 3) {
          await m.createTable(participantsTable);
          await m.createTable(conversationsTable);
          await m.createTable(messagesTable);
          await m.createTable(messageReceiptsTable);
          await m.createTable(attachmentsTable);
          await m.createTable(syncMetadataTable);
        } else if (from < 4) {
          await m.addColumn(participantsTable, participantsTable.trustState);
        }
        if (from < 5) {
          await m.createTable(signalSessionsTable);
          await m.createTable(signalOneTimePrekeysTable);
          await m.createTable(signalSkippedKeysTable);
        }
        if (from >= 3 && from < 6) {
          await m.addColumn(conversationsTable, conversationsTable.draft);
          await m.addColumn(conversationsTable, conversationsTable.isPinned);
          await m.addColumn(messagesTable, messagesTable.searchIndex);
          await m.deleteTable('attachments');
          await m.createTable(attachmentsTable);
        }
        if (from < 7) {
          if (from == 6) {
            await m.addColumn(attachmentsTable, attachmentsTable.uploadedBytes);
            await m.addColumn(attachmentsTable, attachmentsTable.totalBytes);
            await m.addColumn(attachmentsTable, attachmentsTable.encryptionVersion);
            await m.addColumn(attachmentsTable, attachmentsTable.checksumSha256);
          }
        }
        AppLogger.info('[AppDatabase] Migration completed');
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
  return SqfliteCipherQueryExecutor(
    path: dbPath,
    password: encryptionKey,
    singleInstance: true,
    onConfigure: (db) async {
      // rawQuery — returns rows (journal mode string), so execute() fails.
      await db.rawQuery('PRAGMA journal_mode=WAL;');
      AppLogger.info('[AppDatabase] WAL enabled');
      // execute — returns no rows, safe.
      await db.execute('PRAGMA foreign_keys=ON;');
      AppLogger.info('[AppDatabase] Foreign keys enabled');
    },
  );
}
