import 'dart:io';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/storage/app_database.dart';

void main() {
  group('AppDatabase Schema Migration Tests', () {
    test('upgrades from v2 to v3 successfully, preserves categories/notes, and creates messaging tables', () async {
      // Create a temporary file for the test database
      final tempDir = Directory.systemTemp.createTempSync('app_migration_v3_test');
      final dbFile = File('${tempDir.path}/test_app_database.db');

      // 1. Setup v2 schema and data using raw SQL on executor
      final executorv2 = NativeDatabase(dbFile);
      await executorv2.ensureOpen(_FakeDbUser(2));
      
      // Create v2 tables (AppMetadata, CategoriesTable, NotesTable)
      await executorv2.runCustom('''
        CREATE TABLE app_metadata (
          "key" TEXT NOT NULL PRIMARY KEY,
          "value" TEXT NOT NULL
        );
      ''');
      await executorv2.runCustom('''
        CREATE TABLE categories (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          color_hex TEXT NOT NULL,
          display_order INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        );
      ''');
      await executorv2.runCustom('''
        CREATE TABLE notes (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
          revision INTEGER NOT NULL DEFAULT 1,
          is_favorite INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          last_opened_at INTEGER
        );
      ''');
      
      await executorv2.runCustom('PRAGMA user_version = 2;');

      // Insert test category and note
      await executorv2.runCustom(
        'INSERT INTO categories (id, name, color_hex, display_order, created_at) '
        "VALUES ('cat_1', 'Personal', '00FF00', 1, 1680000000);"
      );
      await executorv2.runCustom(
        'INSERT INTO notes (id, title, body, category_id, created_at, updated_at) '
        "VALUES ('note_1', 'My Note', 'Hello World', 'cat_1', 1680000000, 1680000000);"
      );

      // Close the connection
      await executorv2.close();

      // 2. Open using actual Drift class AppDatabase
      final executorv3 = NativeDatabase(dbFile);
      final db = AppDatabase(executorv3);

      // Assert schema version is 5
      expect(db.schemaVersion, 5);

      // Verify category and note are preserved
      final catRows = await db.customSelect('SELECT * FROM categories').get();
      expect(catRows.length, 1);
      expect(catRows.first.read<String>('name'), 'Personal');

      final noteRows = await db.customSelect('SELECT * FROM notes').get();
      expect(noteRows.length, 1);
      expect(noteRows.first.read<String>('title'), 'My Note');
      expect(noteRows.first.read<String>('category_id'), 'cat_1');

      // Verify messaging tables are created and writable
      await db.customStatement("INSERT INTO participants (id, username, identity_key_pub, trust_state) VALUES ('p1', '@bob', 'pubkey_bob', 'accepted');");
      await db.customStatement("INSERT INTO conversations (id, participant_id, last_message_id, updated_at, unread_count, is_hidden, is_archived, is_muted, is_blocked) VALUES ('c1', 'p1', NULL, 1680000000, 0, 0, 0, 0, 0);");
      await db.customStatement("INSERT INTO messages (id, conversation_id, sender_id, encrypted_content, nonce, state, created_at) VALUES ('m1', 'c1', 'p1', 'enc_content', 'nonce_val', 'sent', 1680000000);");
      await db.customStatement("INSERT INTO message_receipts (id, message_id, participant_id, status, timestamp) VALUES ('r1', 'm1', 'p1', 'delivered', 1680000000);");
      await db.customStatement("INSERT INTO attachments (id, message_id, encrypted_remote_url, key_payload, local_cache_path, size_bytes, state) VALUES ('a1', 'm1', 'remote_url', 'key', NULL, 2048, 'uploading');");
      await db.customStatement("INSERT INTO sync_metadata (key, value, updated_at) VALUES ('cursor', '100', 1680000000);");

      // Verify new cryptographic tables are created and writable
      await db.customStatement("INSERT INTO signal_sessions (address_name, device_id, session_record) VALUES ('alice_bob', 1, x'1234');");
      await db.customStatement("INSERT INTO signal_one_time_prekeys (pre_key_id, pre_key_record) VALUES (1, x'5678');");
      await db.customStatement("INSERT INTO signal_skipped_keys (sender_id, ratchet_key, sequence_number, key_bytes, created_at) VALUES ('p1', 'ratchet_key_hex', 10, x'90ab', 1680000000);");

      final partRows = await db.customSelect('SELECT * FROM participants').get();
      expect(partRows.length, 1);
      expect(partRows.first.read<String>('username'), '@bob');
      expect(partRows.first.read<String>('trust_state'), 'accepted');

      final convRows = await db.customSelect('SELECT * FROM conversations').get();
      expect(convRows.length, 1);
      expect(convRows.first.read<String>('participant_id'), 'p1');

      final msgRows = await db.customSelect('SELECT * FROM messages').get();
      expect(msgRows.length, 1);
      expect(msgRows.first.read<String>('encrypted_content'), 'enc_content');

      final receiptRows = await db.customSelect('SELECT * FROM message_receipts').get();
      expect(receiptRows.length, 1);
      expect(receiptRows.first.read<String>('status'), 'delivered');

      final attachRows = await db.customSelect('SELECT * FROM attachments').get();
      expect(attachRows.length, 1);
      expect(attachRows.first.read<String>('encrypted_remote_url'), 'remote_url');

      final metaRows = await db.customSelect('SELECT * FROM sync_metadata').get();
      expect(metaRows.length, 1);
      expect(metaRows.first.read<String>('value'), '100');

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
