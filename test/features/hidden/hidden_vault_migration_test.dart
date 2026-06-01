import 'dart:io';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';

void main() {
  group('HiddenVaultDatabase Schema Migration Tests', () {
    test('upgrades from v1 to v7 successfully and preserves data', () async {
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
      final executorv7 = NativeDatabase(dbFile);
      final db = HiddenVaultDatabase(executorv7);

      // 3. Assert schema version is 8
      expect(db.schemaVersion, 8);

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

    test('upgrades from v2 to v7 successfully, creates hidden_categories, messaging, and cryptographic tables', () async {
      // Create a temporary file for the test database
      final tempDir = Directory.systemTemp.createTempSync('memo_migration_v4_test');
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
      final executorv7 = NativeDatabase(dbFile);
      final db = HiddenVaultDatabase(executorv7);

      // Assert schema version is 8
      expect(db.schemaVersion, 8);

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

      // Verify messaging tables are created and writable
      await db.customStatement("INSERT INTO participants (id, username, identity_key_pub, trust_state) VALUES ('p1', '@alice', 'pubkey_alice', 'accepted');");
      await db.customStatement("INSERT INTO conversations (id, participant_id, last_message_id, updated_at, unread_count, is_hidden, is_archived, is_muted, is_blocked) VALUES ('c1', 'p1', NULL, 1680000000, 0, 1, 0, 0, 0);");
      await db.customStatement("INSERT INTO messages (id, conversation_id, sender_id, encrypted_content, nonce, state, created_at) VALUES ('m1', 'c1', 'p1', 'enc_data', 'nonce_val', 'sent', 1680000000);");
      await db.customStatement("INSERT INTO message_receipts (id, message_id, participant_id, status, timestamp) VALUES ('r1', 'm1', 'p1', 'read', 1680000000);");
      await db.customStatement("INSERT INTO attachments (id, message_id, type, file_name, mime_type, size, thumbnail_path, local_path, remote_path, key_payload, status, created_at) VALUES ('a1', 'm1', 'image', 'test.jpg', 'image/jpeg', 1024, NULL, '/cache', 'url', 'key', 'completed', 1680000000);");
      await db.customStatement("INSERT INTO sync_metadata (key, value, updated_at) VALUES ('last_sync', '1680000000', 1680000000);");

      // Verify cryptographic tables are created and writable
      await db.customStatement("INSERT INTO signal_sessions (address_name, device_id, session_record) VALUES ('alice_bob', 1, x'1234');");
      await db.customStatement("INSERT INTO signal_one_time_prekeys (pre_key_id, pre_key_record) VALUES (1, x'5678');");
      await db.customStatement("INSERT INTO signal_skipped_keys (sender_id, ratchet_key, sequence_number, key_bytes, created_at) VALUES ('p1', 'ratchet_key_hex', 10, x'90ab', 1680000000);");

      final partRows = await db.customSelect('SELECT * FROM participants').get();
      expect(partRows.length, 1);
      expect(partRows.first.read<String>('username'), '@alice');
      expect(partRows.first.read<String>('trust_state'), 'accepted');

      final convRows = await db.customSelect('SELECT * FROM conversations').get();
      expect(convRows.length, 1);
      expect(convRows.first.read<String>('participant_id'), 'p1');

      final msgRows = await db.customSelect('SELECT * FROM messages').get();
      expect(msgRows.length, 1);
      expect(msgRows.first.read<String>('encrypted_content'), 'enc_data');

      final receiptRows = await db.customSelect('SELECT * FROM message_receipts').get();
      expect(receiptRows.length, 1);
      expect(receiptRows.first.read<String>('status'), 'read');

      final attachRows = await db.customSelect('SELECT * FROM attachments').get();
      expect(attachRows.length, 1);
      expect(attachRows.first.read<String>('remote_path'), 'url');

      final metaRows = await db.customSelect('SELECT * FROM sync_metadata').get();
      expect(metaRows.length, 1);
      expect(metaRows.first.read<String>('value'), '1680000000');

      final sessionRows = await db.customSelect('SELECT * FROM signal_sessions').get();
      expect(sessionRows.length, 1);
      expect(sessionRows.first.read<String>('address_name'), 'alice_bob');
      expect(sessionRows.first.read<Uint8List>('session_record'), [0x12, 0x34]);

      final otpRows = await db.customSelect('SELECT * FROM signal_one_time_prekeys').get();
      expect(otpRows.length, 1);
      expect(otpRows.first.read<int>('pre_key_id'), 1);
      expect(otpRows.first.read<Uint8List>('pre_key_record'), [0x56, 0x78]);

      final skippedRows = await db.customSelect('SELECT * FROM signal_skipped_keys').get();
      expect(skippedRows.length, 1);
      expect(skippedRows.first.read<String>('sender_id'), 'p1');
      expect(skippedRows.first.read<Uint8List>('key_bytes'), [0x90, 0xab]);

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
