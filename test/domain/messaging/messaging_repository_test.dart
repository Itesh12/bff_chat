import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/services/database_service.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/data/messaging/messaging_repository_impl.dart';
import 'package:memovault/domain/messaging/attachment_entity.dart';
import 'package:memovault/domain/messaging/attachment_type.dart';
import 'package:memovault/domain/messaging/message_entity.dart';
import 'package:memovault/domain/messaging/message_receipt_entity.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';
import 'package:memovault/features/hidden/services/hidden_vault_service.dart';

// Light compile-safe fake adapters using standard implements mapping
class _FakeDatabaseService implements DatabaseService {
  @override
  final AppDatabase db;
  _FakeDatabaseService(this.db);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHiddenVaultService implements HiddenVaultService {
  @override
  HiddenVaultDatabase? db;
  _FakeHiddenVaultService(this.db);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('MessagingRepositoryImpl Integration Tests', () {
    late AppDatabase publicDb;
    late HiddenVaultDatabase privateDb;
    late _FakeDatabaseService fakeDbService;
    late _FakeHiddenVaultService fakeHiddenVaultService;
    late MessagingRepositoryImpl repo;

    setUp(() async {
      publicDb = AppDatabase(NativeDatabase.memory());
      privateDb = HiddenVaultDatabase(NativeDatabase.memory());
      fakeDbService = _FakeDatabaseService(publicDb);
      fakeHiddenVaultService = _FakeHiddenVaultService(privateDb);
      repo = MessagingRepositoryImpl(fakeDbService, fakeHiddenVaultService);

      // Suppress Drift warnings for multiple DBs in tests
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    tearDown(() async {
      await publicDb.close();
      await privateDb.close();
    });

    test('should create, retrieve, and update participants across both databases', () async {
      final p1 = await repo.createOrUpdateParticipant(
        id: 'p_1',
        username: '@alice',
        identityKeyPub: 'alice_pubkey',
      );

      expect(p1.id, 'p_1');
      expect(p1.username, '@alice');

      // Verify participant exists in public DB
      final pPublic = await repo.getParticipantById('p_1');
      expect(pPublic, isNotNull);
      expect(pPublic!.username, '@alice');

      // Verify participant exists in private DB as well (since unlocked)
      final pPrivate = await repo.getParticipantByUsername('@alice');
      expect(pPrivate, isNotNull);
      expect(pPrivate!.id, 'p_1');
    });

    test('should successfully perform public conversation CRUD and messaging operations', () async {
      // 1. Setup participant
      await repo.createOrUpdateParticipant(
        id: 'bob_id',
        username: '@bob',
        identityKeyPub: 'bob_key',
      );

      // 2. Create public conversation
      final conv = await repo.createConversation(
        id: 'c_public',
        participantId: 'bob_id',
        isHidden: false,
      );

      expect(conv.id, 'c_public');
      expect(conv.isHidden, false);

      // 3. Send message (state = sending)
      final now = DateTime.now().toUtc();
      final msg = MessageEntity(
        id: 'm_1',
        conversationId: 'c_public',
        senderId: 'bob_id',
        encryptedContent: 'encrypted_data',
        nonce: 'nonce_123',
        state: 'sending',
        createdAt: now,
      );
      await repo.insertMessage(msg);

      // 4. Verify message exists and check status
      final msgFetched = await repo.getMessageById('m_1');
      expect(msgFetched, isNotNull);
      expect(msgFetched!.encryptedContent, 'encrypted_data');
      expect(msgFetched.state, 'sending');

      // 5. Update message state to 'sent'
      await repo.updateMessageState('m_1', 'sent');
      final msgUpdated = await repo.getMessageById('m_1');
      expect(msgUpdated!.state, 'sent');

      // 6. Add message receipt
      final receipt = MessageReceiptEntity(
        id: 'r_1',
        messageId: 'm_1',
        participantId: 'bob_id',
        status: 'delivered',
        timestamp: now,
      );
      await repo.insertReceipt(receipt);

      final receipts = await repo.getReceiptsForMessage('m_1');
      expect(receipts.length, 1);
      expect(receipts.first.status, 'delivered');

      // 7. Add attachment
      final attachment = AttachmentEntity(
        id: 'a_1',
        messageId: 'm_1',
        type: AttachmentType.file,
        fileName: 'test.txt',
        mimeType: 'text/plain',
        size: 2048,
        remotePath: 'remote_url',
        keyPayload: 'payload_key',
        status: 'uploading',
        createdAt: now,
      );
      await repo.insertAttachment(attachment);

      final attachments = await repo.getAttachmentsForMessage('m_1');
      expect(attachments.length, 1);
      expect(attachments.first.size, 2048);

      // Update attachment local cache path
      await repo.updateAttachmentLocalPath('a_1', '/cache/path');
      final attachmentUpdated = await repo.getAttachmentById('a_1');
      expect(attachmentUpdated!.localPath, '/cache/path');
    });

    test('should securely separate and isolate hidden vault messaging threads', () async {
      // 1. Setup participant
      await repo.createOrUpdateParticipant(
        id: 'charlie_id',
        username: '@charlie',
        identityKeyPub: 'charlie_key',
      );

      // 2. Create private/hidden conversation
      final conv = await repo.createConversation(
        id: 'c_hidden',
        participantId: 'charlie_id',
        isHidden: true,
      );

      expect(conv.id, 'c_hidden');
      expect(conv.isHidden, true);

      // 3. Send message in hidden conversation
      final now = DateTime.now().toUtc();
      final msg = MessageEntity(
        id: 'm_hidden',
        conversationId: 'c_hidden',
        senderId: 'charlie_id',
        encryptedContent: 'secure_content',
        nonce: 'nonce_secret',
        state: 'sending',
        createdAt: now,
      );
      await repo.insertMessage(msg);

      // 4. Assert message is inside private vault database
      final privateRows = await privateDb.customSelect('SELECT * FROM messages').get();
      expect(privateRows.length, 1);
      expect(privateRows.first.read<String>('encrypted_content'), 'secure_content');

      // 5. Assert public database is absolutely EMPTY of this message
      final publicRows = await publicDb.customSelect('SELECT * FROM messages').get();
      expect(publicRows.isEmpty, true);

      // 6. Lock the vault (simulate setting the service DB reference to null)
      fakeHiddenVaultService.db = null;

      // 7. Verify accessing hidden conversation throws error or fails safely
      expect(
        () async => await repo.getMessagesForConversation('c_hidden'),
        throwsStateError,
      );
    });

    test('should successfully write and read sync metadata cursor offsets', () async {
      await repo.setSyncMetadata('sync_cursor_v1', 'sequence_450');

      final value = await repo.getSyncMetadata('sync_cursor_v1');
      expect(value, 'sequence_450');
    });

    test('should support message types, soft delete, message versioning and duplicate idempotency', () async {
      // 1. Setup participant and conversation
      await repo.createOrUpdateParticipant(
        id: 'user_a',
        username: '@alice_t',
        identityKeyPub: 'alice_key',
      );
      await repo.createConversation(
        id: 'c_test_fields',
        participantId: 'user_a',
        isHidden: false,
      );

      // 2. Test MessageType, Version, isDeleted defaults
      final now = DateTime.now().toUtc();
      final msgDefault = MessageEntity(
        id: 'msg_default',
        conversationId: 'c_test_fields',
        senderId: 'user_a',
        encryptedContent: 'content',
        nonce: 'nonce',
        state: 'sent',
        createdAt: now,
      );
      await repo.insertMessage(msgDefault);

      final msgDefaultFetched = await repo.getMessageById('msg_default');
      expect(msgDefaultFetched, isNotNull);
      expect(msgDefaultFetched!.messageType, 'text');
      expect(msgDefaultFetched.version, 1);
      expect(msgDefaultFetched.isDeleted, false);
      expect(msgDefaultFetched.deletedAt, isNull);

      // 3. Test non-default MessageType and Version fields
      final msgCustom = MessageEntity(
        id: 'msg_custom',
        conversationId: 'c_test_fields',
        senderId: 'user_a',
        encryptedContent: 'image_bytes',
        nonce: 'nonce_img',
        state: 'sent',
        messageType: 'image',
        isDeleted: true,
        deletedAt: now,
        version: 3,
        createdAt: now,
      );
      await repo.insertMessage(msgCustom);

      final msgCustomFetched = await repo.getMessageById('msg_custom');
      expect(msgCustomFetched, isNotNull);
      expect(msgCustomFetched!.messageType, 'image');
      expect(msgCustomFetched.version, 3);
      expect(msgCustomFetched.isDeleted, true);
      expect(msgCustomFetched.deletedAt, isNotNull);

      // 4. Test Idempotency (Inserting a message with duplicate ID)
      final duplicateMsg = MessageEntity(
        id: 'msg_default',
        conversationId: 'c_test_fields',
        senderId: 'user_a',
        encryptedContent: 'new_content_which_should_be_ignored',
        nonce: 'new_nonce',
        state: 'delivered',
        createdAt: now,
      );
      final result = await repo.insertMessage(duplicateMsg);
      
      // Should return the original matching message from DB instead of inserting a duplicate or crashing
      expect(result.id, 'msg_default');
      expect(result.encryptedContent, 'content');
      expect(result.state, 'sent');
      
      final msgDefaultFetchedAgain = await repo.getMessageById('msg_default');
      expect(msgDefaultFetchedAgain!.encryptedContent, 'content');
    });
  });
}
