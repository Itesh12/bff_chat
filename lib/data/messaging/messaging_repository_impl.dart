import 'package:drift/drift.dart';
import 'package:memovault/core/services/database_service.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/domain/messaging/attachment_entity.dart';
import 'package:memovault/domain/messaging/conversation_entity.dart';
import 'package:memovault/domain/messaging/message_entity.dart';
import 'package:memovault/domain/messaging/message_receipt_entity.dart';
import 'package:memovault/domain/messaging/participant_entity.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart' as private_db;
import 'package:memovault/features/hidden/services/hidden_vault_service.dart';

class MessagingRepositoryImpl implements MessagingRepository {
  final DatabaseService _databaseService;
  final HiddenVaultService _hiddenVaultService;

  MessagingRepositoryImpl(this._databaseService, this._hiddenVaultService);

  // ─── Helpers ──────────────────────────────────────────────────────────────

  private_db.HiddenVaultDatabase _getPrivateDb() {
    final privateDb = _hiddenVaultService.db;
    if (privateDb == null) {
      throw StateError('Attempted to access encrypted HiddenVaultDatabase while session is locked.');
    }
    return privateDb;
  }

  Future<bool> _isConversationHidden(String conversationId) async {
    final privateDb = _hiddenVaultService.db;
    if (privateDb != null) {
      final query = privateDb.select(privateDb.conversationsTable)
        ..where((t) => t.id.equals(conversationId));
      final res = await query.getSingleOrNull();
      if (res != null) return true;
    } else {
      final publicDb = _databaseService.db;
      final query = publicDb.select(publicDb.conversationsTable)
        ..where((t) => t.id.equals(conversationId));
      final res = await query.getSingleOrNull();
      if (res == null) {
        throw StateError('Attempted to access encrypted HiddenVaultDatabase while session is locked.');
      }
    }
    return false;
  }

  ParticipantEntity _toParticipantEntityFromPublic(ParticipantRow row) {
    return ParticipantEntity(
      id: row.id,
      username: row.username,
      identityKeyPub: row.identityKeyPub,
    );
  }

  ParticipantEntity _toParticipantEntityFromPrivate(private_db.ParticipantRow row) {
    return ParticipantEntity(
      id: row.id,
      username: row.username,
      identityKeyPub: row.identityKeyPub,
    );
  }

  ConversationEntity _toConversationEntityFromPublic(ConversationRow row) {
    return ConversationEntity(
      id: row.id,
      participantId: row.participantId,
      lastMessageId: row.lastMessageId,
      updatedAt: row.updatedAt,
      unreadCount: row.unreadCount,
      isHidden: row.isHidden,
      isArchived: row.isArchived,
      isMuted: row.isMuted,
      isBlocked: row.isBlocked,
    );
  }

  ConversationEntity _toConversationEntityFromPrivate(private_db.ConversationRow row) {
    return ConversationEntity(
      id: row.id,
      participantId: row.participantId,
      lastMessageId: row.lastMessageId,
      updatedAt: row.updatedAt,
      unreadCount: row.unreadCount,
      isHidden: row.isHidden,
      isArchived: row.isArchived,
      isMuted: row.isMuted,
      isBlocked: row.isBlocked,
    );
  }

  MessageEntity _toMessageEntityFromPublic(MessageRow row) {
    return MessageEntity(
      id: row.id,
      conversationId: row.conversationId,
      senderId: row.senderId,
      encryptedContent: row.encryptedContent,
      nonce: row.nonce,
      state: row.state,
      messageType: row.messageType,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
      version: row.version,
      createdAt: row.createdAt,
    );
  }

  MessageEntity _toMessageEntityFromPrivate(private_db.MessageRow row) {
    return MessageEntity(
      id: row.id,
      conversationId: row.conversationId,
      senderId: row.senderId,
      encryptedContent: row.encryptedContent,
      nonce: row.nonce,
      state: row.state,
      messageType: row.messageType,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
      version: row.version,
      createdAt: row.createdAt,
    );
  }

  MessageReceiptEntity _toReceiptEntityFromPublic(MessageReceiptRow row) {
    return MessageReceiptEntity(
      id: row.id,
      messageId: row.messageId,
      participantId: row.participantId,
      status: row.status,
      timestamp: row.timestamp,
    );
  }

  MessageReceiptEntity _toReceiptEntityFromPrivate(private_db.MessageReceiptRow row) {
    return MessageReceiptEntity(
      id: row.id,
      messageId: row.messageId,
      participantId: row.participantId,
      status: row.status,
      timestamp: row.timestamp,
    );
  }

  AttachmentEntity _toAttachmentEntityFromPublic(AttachmentRow row) {
    return AttachmentEntity(
      id: row.id,
      messageId: row.messageId,
      encryptedRemoteUrl: row.encryptedRemoteUrl,
      keyPayload: row.keyPayload,
      localCachePath: row.localCachePath,
      sizeBytes: row.sizeBytes,
      state: row.state,
    );
  }

  AttachmentEntity _toAttachmentEntityFromPrivate(private_db.AttachmentRow row) {
    return AttachmentEntity(
      id: row.id,
      messageId: row.messageId,
      encryptedRemoteUrl: row.encryptedRemoteUrl,
      keyPayload: row.keyPayload,
      localCachePath: row.localCachePath,
      sizeBytes: row.sizeBytes,
      state: row.state,
    );
  }

  // ─── Participants ────────────────────────────────────────────────────────

  @override
  Future<ParticipantEntity?> getParticipantById(String id) async {
    final privateDb = _hiddenVaultService.db;
    if (privateDb != null) {
      final row = await (privateDb.select(privateDb.participantsTable)
        ..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row != null) return _toParticipantEntityFromPrivate(row);
    }
    final publicDb = _databaseService.db;
    final row = await (publicDb.select(publicDb.participantsTable)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row != null) return _toParticipantEntityFromPublic(row);
    return null;
  }

  @override
  Future<ParticipantEntity?> getParticipantByUsername(String username) async {
    final privateDb = _hiddenVaultService.db;
    if (privateDb != null) {
      final row = await (privateDb.select(privateDb.participantsTable)
        ..where((t) => t.username.equals(username))).getSingleOrNull();
      if (row != null) return _toParticipantEntityFromPrivate(row);
    }
    final publicDb = _databaseService.db;
    final row = await (publicDb.select(publicDb.participantsTable)
      ..where((t) => t.username.equals(username))).getSingleOrNull();
    if (row != null) return _toParticipantEntityFromPublic(row);
    return null;
  }

  @override
  Future<ParticipantEntity> createOrUpdateParticipant({
    required String id,
    required String username,
    required String identityKeyPub,
  }) async {
    final privateCompanion = private_db.ParticipantsTableCompanion(
      id: Value(id),
      username: Value(username),
      identityKeyPub: Value(identityKeyPub),
    );

    final publicCompanion = ParticipantsTableCompanion(
      id: Value(id),
      username: Value(username),
      identityKeyPub: Value(identityKeyPub),
    );

    final privateDb = _hiddenVaultService.db;
    if (privateDb != null) {
      await privateDb.into(privateDb.participantsTable).insertOnConflictUpdate(privateCompanion);
    }

    final publicDb = _databaseService.db;
    await publicDb.into(publicDb.participantsTable).insertOnConflictUpdate(publicCompanion);

    return ParticipantEntity(
      id: id,
      username: username,
      identityKeyPub: identityKeyPub,
    );
  }

  // ─── Conversations ───────────────────────────────────────────────────────

  @override
  Stream<List<ConversationEntity>> watchAllConversations({bool isHidden = false}) {
    if (isHidden) {
      final db = _getPrivateDb();
      return (db.select(db.conversationsTable)
        ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
        .watch()
        .map((rows) => rows.map<ConversationEntity>(_toConversationEntityFromPrivate).toList());
    } else {
      final db = _databaseService.db;
      return (db.select(db.conversationsTable)
        ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
        .watch()
        .map((rows) => rows.map<ConversationEntity>(_toConversationEntityFromPublic).toList());
    }
  }

  @override
  Future<ConversationEntity?> getConversationById(String id) async {
    final isHidden = await _isConversationHidden(id);
    if (isHidden) {
      final db = _getPrivateDb();
      final row = await (db.select(db.conversationsTable)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row != null) return _toConversationEntityFromPrivate(row);
    } else {
      final db = _databaseService.db;
      final row = await (db.select(db.conversationsTable)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row != null) return _toConversationEntityFromPublic(row);
    }
    return null;
  }

  @override
  Future<ConversationEntity> createConversation({
    required String id,
    required String participantId,
    required bool isHidden,
  }) async {
    final now = DateTime.now().toUtc();

    if (isHidden) {
      final db = _getPrivateDb();
      final privateCompanion = private_db.ConversationsTableCompanion(
        id: Value(id),
        participantId: Value(participantId),
        lastMessageId: const Value(null),
        updatedAt: Value(now),
        unreadCount: const Value(0),
        isHidden: Value(isHidden),
        isArchived: const Value(false),
        isMuted: const Value(false),
        isBlocked: const Value(false),
      );
      await db.into(db.conversationsTable).insert(privateCompanion);
    } else {
      final db = _databaseService.db;
      final publicCompanion = ConversationsTableCompanion(
        id: Value(id),
        participantId: Value(participantId),
        lastMessageId: const Value(null),
        updatedAt: Value(now),
        unreadCount: const Value(0),
        isHidden: Value(isHidden),
        isArchived: const Value(false),
        isMuted: const Value(false),
        isBlocked: const Value(false),
      );
      await db.into(db.conversationsTable).insert(publicCompanion);
    }

    return ConversationEntity(
      id: id,
      participantId: participantId,
      lastMessageId: null,
      updatedAt: now,
      unreadCount: 0,
      isHidden: isHidden,
      isArchived: false,
      isMuted: false,
      isBlocked: false,
    );
  }

  @override
  Future<void> updateConversationLastMessage(String id, String? lastMessageId) async {
    final isHidden = await _isConversationHidden(id);
    final now = DateTime.now().toUtc();

    if (isHidden) {
      final db = _getPrivateDb();
      final companion = private_db.ConversationsTableCompanion(
        lastMessageId: Value(lastMessageId),
        updatedAt: Value(now),
      );
      await (db.update(db.conversationsTable)..where((t) => t.id.equals(id))).write(companion);
    } else {
      final db = _databaseService.db;
      final companion = ConversationsTableCompanion(
        lastMessageId: Value(lastMessageId),
        updatedAt: Value(now),
      );
      await (db.update(db.conversationsTable)..where((t) => t.id.equals(id))).write(companion);
    }
  }

  @override
  Future<void> updateConversationUnreadCount(String id, int unreadCount) async {
    final isHidden = await _isConversationHidden(id);

    if (isHidden) {
      final db = _getPrivateDb();
      final companion = private_db.ConversationsTableCompanion(
        unreadCount: Value(unreadCount),
      );
      await (db.update(db.conversationsTable)..where((t) => t.id.equals(id))).write(companion);
    } else {
      final db = _databaseService.db;
      final companion = ConversationsTableCompanion(
        unreadCount: Value(unreadCount),
      );
      await (db.update(db.conversationsTable)..where((t) => t.id.equals(id))).write(companion);
    }
  }

  @override
  Future<void> toggleMuteConversation(String id) async {
    final conv = await getConversationById(id);
    if (conv == null) return;
    if (conv.isHidden) {
      final db = _getPrivateDb();
      final companion = private_db.ConversationsTableCompanion(
        isMuted: Value(!conv.isMuted),
      );
      await (db.update(db.conversationsTable)..where((t) => t.id.equals(id))).write(companion);
    } else {
      final db = _databaseService.db;
      final companion = ConversationsTableCompanion(
        isMuted: Value(!conv.isMuted),
      );
      await (db.update(db.conversationsTable)..where((t) => t.id.equals(id))).write(companion);
    }
  }

  @override
  Future<void> toggleBlockConversation(String id) async {
    final conv = await getConversationById(id);
    if (conv == null) return;
    if (conv.isHidden) {
      final db = _getPrivateDb();
      final companion = private_db.ConversationsTableCompanion(
        isBlocked: Value(!conv.isBlocked),
      );
      await (db.update(db.conversationsTable)..where((t) => t.id.equals(id))).write(companion);
    } else {
      final db = _databaseService.db;
      final companion = ConversationsTableCompanion(
        isBlocked: Value(!conv.isBlocked),
      );
      await (db.update(db.conversationsTable)..where((t) => t.id.equals(id))).write(companion);
    }
  }

  @override
  Future<void> toggleArchiveConversation(String id) async {
    final conv = await getConversationById(id);
    if (conv == null) return;
    if (conv.isHidden) {
      final db = _getPrivateDb();
      final companion = private_db.ConversationsTableCompanion(
        isArchived: Value(!conv.isArchived),
      );
      await (db.update(db.conversationsTable)..where((t) => t.id.equals(id))).write(companion);
    } else {
      final db = _databaseService.db;
      final companion = ConversationsTableCompanion(
        isArchived: Value(!conv.isArchived),
      );
      await (db.update(db.conversationsTable)..where((t) => t.id.equals(id))).write(companion);
    }
  }

  // ─── Messages ────────────────────────────────────────────────────────────

  @override
  Stream<List<MessageEntity>> watchMessagesForConversation(String conversationId) {
    final privateDb = _hiddenVaultService.db;
    if (privateDb != null) {
      return Stream.fromFuture(_isConversationHidden(conversationId)).asyncExpand((isHidden) {
        if (isHidden) {
          final db = _getPrivateDb();
          return (db.select(db.messagesTable)
            ..where((t) => t.conversationId.equals(conversationId))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
            .watch()
            .map((rows) => rows.map<MessageEntity>(_toMessageEntityFromPrivate).toList());
        } else {
          final db = _databaseService.db;
          return (db.select(db.messagesTable)
            ..where((t) => t.conversationId.equals(conversationId))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
            .watch()
            .map((rows) => rows.map<MessageEntity>(_toMessageEntityFromPublic).toList());
        }
      });
    } else {
      final db = _databaseService.db;
      return (db.select(db.messagesTable)
        ..where((t) => t.conversationId.equals(conversationId))
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .watch()
        .map((rows) => rows.map<MessageEntity>(_toMessageEntityFromPublic).toList());
    }
  }

  @override
  Future<List<MessageEntity>> getMessagesForConversation(String conversationId) async {
    final isHidden = await _isConversationHidden(conversationId);
    if (isHidden) {
      final db = _getPrivateDb();
      final rows = await (db.select(db.messagesTable)
        ..where((t) => t.conversationId.equals(conversationId))
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .get();
      return rows.map<MessageEntity>(_toMessageEntityFromPrivate).toList();
    } else {
      final db = _databaseService.db;
      final rows = await (db.select(db.messagesTable)
        ..where((t) => t.conversationId.equals(conversationId))
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .get();
      return rows.map<MessageEntity>(_toMessageEntityFromPublic).toList();
    }
  }

  @override
  Future<MessageEntity?> getMessageById(String id) async {
    final privateDb = _hiddenVaultService.db;
    if (privateDb != null) {
      final row = await (privateDb.select(privateDb.messagesTable)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row != null) return _toMessageEntityFromPrivate(row);
    }
    final publicDb = _databaseService.db;
    final row = await (publicDb.select(publicDb.messagesTable)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row != null) return _toMessageEntityFromPublic(row);
    return null;
  }

  @override
  Future<MessageEntity> insertMessage(MessageEntity message) async {
    // Sync Queue Idempotency / Duplicate-delivery protection
    final existing = await getMessageById(message.id);
    if (existing != null) {
      return existing;
    }

    final isHidden = await _isConversationHidden(message.conversationId);

    if (isHidden) {
      final db = _getPrivateDb();
      final privateCompanion = private_db.MessagesTableCompanion(
        id: Value(message.id),
        conversationId: Value(message.conversationId),
        senderId: Value(message.senderId),
        encryptedContent: Value(message.encryptedContent),
        nonce: Value(message.nonce),
        state: Value(message.state),
        messageType: Value(message.messageType),
        isDeleted: Value(message.isDeleted),
        deletedAt: Value(message.deletedAt),
        version: Value(message.version),
        createdAt: Value(message.createdAt),
      );
      await db.into(db.messagesTable).insert(privateCompanion);
    } else {
      final db = _databaseService.db;
      final publicCompanion = MessagesTableCompanion(
        id: Value(message.id),
        conversationId: Value(message.conversationId),
        senderId: Value(message.senderId),
        encryptedContent: Value(message.encryptedContent),
        nonce: Value(message.nonce),
        state: Value(message.state),
        messageType: Value(message.messageType),
        isDeleted: Value(message.isDeleted),
        deletedAt: Value(message.deletedAt),
        version: Value(message.version),
        createdAt: Value(message.createdAt),
      );
      await db.into(db.messagesTable).insert(publicCompanion);
    }

    return message;
  }

  @override
  Future<void> updateMessageState(String id, String state) async {
    final msg = await getMessageById(id);
    if (msg == null) return;
    final isHidden = await _isConversationHidden(msg.conversationId);

    if (isHidden) {
      final db = _getPrivateDb();
      final companion = private_db.MessagesTableCompanion(
        state: Value(state),
      );
      await (db.update(db.messagesTable)..where((t) => t.id.equals(id))).write(companion);
    } else {
      final db = _databaseService.db;
      final companion = MessagesTableCompanion(
        state: Value(state),
      );
      await (db.update(db.messagesTable)..where((t) => t.id.equals(id))).write(companion);
    }
  }

  @override
  Future<void> deleteMessage(String id) async {
    final msg = await getMessageById(id);
    if (msg == null) return;
    final isHidden = await _isConversationHidden(msg.conversationId);

    if (isHidden) {
      final db = _getPrivateDb();
      await (db.delete(db.messagesTable)..where((t) => t.id.equals(id))).go();
    } else {
      final db = _databaseService.db;
      await (db.delete(db.messagesTable)..where((t) => t.id.equals(id))).go();
    }
  }

  // ─── Receipts ────────────────────────────────────────────────────────────

  @override
  Stream<List<MessageReceiptEntity>> watchReceiptsForMessage(String messageId) {
    final privateDb = _hiddenVaultService.db;
    if (privateDb != null) {
      return Stream.fromFuture(getMessageById(messageId)).asyncExpand((msg) {
        if (msg == null) return Stream.value([]);
        return Stream.fromFuture(_isConversationHidden(msg.conversationId)).asyncExpand((isHidden) {
          if (isHidden) {
            final db = _getPrivateDb();
            return (db.select(db.messageReceiptsTable)
              ..where((t) => t.messageId.equals(messageId))
              ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.asc)]))
              .watch()
              .map((rows) => rows.map<MessageReceiptEntity>(_toReceiptEntityFromPrivate).toList());
          } else {
            final db = _databaseService.db;
            return (db.select(db.messageReceiptsTable)
              ..where((t) => t.messageId.equals(messageId))
              ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.asc)]))
              .watch()
              .map((rows) => rows.map<MessageReceiptEntity>(_toReceiptEntityFromPublic).toList());
          }
        });
      });
    } else {
      final db = _databaseService.db;
      return (db.select(db.messageReceiptsTable)
        ..where((t) => t.messageId.equals(messageId))
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.asc)]))
        .watch()
        .map((rows) => rows.map<MessageReceiptEntity>(_toReceiptEntityFromPublic).toList());
    }
  }

  @override
  Future<List<MessageReceiptEntity>> getReceiptsForMessage(String messageId) async {
    final msg = await getMessageById(messageId);
    if (msg == null) return [];
    final isHidden = await _isConversationHidden(msg.conversationId);

    if (isHidden) {
      final db = _getPrivateDb();
      final rows = await (db.select(db.messageReceiptsTable)
        ..where((t) => t.messageId.equals(messageId))
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.asc)]))
        .get();
      return rows.map<MessageReceiptEntity>(_toReceiptEntityFromPrivate).toList();
    } else {
      final db = _databaseService.db;
      final rows = await (db.select(db.messageReceiptsTable)
        ..where((t) => t.messageId.equals(messageId))
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.asc)]))
        .get();
      return rows.map<MessageReceiptEntity>(_toReceiptEntityFromPublic).toList();
    }
  }

  @override
  Future<void> insertReceipt(MessageReceiptEntity receipt) async {
    final msg = await getMessageById(receipt.messageId);
    if (msg == null) return;
    final isHidden = await _isConversationHidden(msg.conversationId);

    if (isHidden) {
      final db = _getPrivateDb();
      final privateCompanion = private_db.MessageReceiptsTableCompanion(
        id: Value(receipt.id),
        messageId: Value(receipt.messageId),
        participantId: Value(receipt.participantId),
        status: Value(receipt.status),
        timestamp: Value(receipt.timestamp),
      );
      await db.into(db.messageReceiptsTable).insert(privateCompanion);
    } else {
      final db = _databaseService.db;
      final publicCompanion = MessageReceiptsTableCompanion(
        id: Value(receipt.id),
        messageId: Value(receipt.messageId),
        participantId: Value(receipt.participantId),
        status: Value(receipt.status),
        timestamp: Value(receipt.timestamp),
      );
      await db.into(db.messageReceiptsTable).insert(publicCompanion);
    }
  }

  // ─── Attachments ─────────────────────────────────────────────────────────

  @override
  Future<List<AttachmentEntity>> getAttachmentsForMessage(String messageId) async {
    final msg = await getMessageById(messageId);
    if (msg == null) return [];
    final isHidden = await _isConversationHidden(msg.conversationId);

    if (isHidden) {
      final db = _getPrivateDb();
      final rows = await (db.select(db.attachmentsTable)..where((t) => t.messageId.equals(messageId))).get();
      return rows.map<AttachmentEntity>(_toAttachmentEntityFromPrivate).toList();
    } else {
      final db = _databaseService.db;
      final rows = await (db.select(db.attachmentsTable)..where((t) => t.messageId.equals(messageId))).get();
      return rows.map<AttachmentEntity>(_toAttachmentEntityFromPublic).toList();
    }
  }

  @override
  Future<AttachmentEntity?> getAttachmentById(String id) async {
    final privateDb = _hiddenVaultService.db;
    if (privateDb != null) {
      final row = await (privateDb.select(privateDb.attachmentsTable)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row != null) return _toAttachmentEntityFromPrivate(row);
    }
    final publicDb = _databaseService.db;
    final row = await (publicDb.select(publicDb.attachmentsTable)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row != null) return _toAttachmentEntityFromPublic(row);
    return null;
  }

  @override
  Future<AttachmentEntity> insertAttachment(AttachmentEntity attachment) async {
    final msg = await getMessageById(attachment.messageId);
    if (msg == null) throw StateError('Referenced message ${attachment.messageId} does not exist.');
    final isHidden = await _isConversationHidden(msg.conversationId);

    if (isHidden) {
      final db = _getPrivateDb();
      final privateCompanion = private_db.AttachmentsTableCompanion(
        id: Value(attachment.id),
        messageId: Value(attachment.messageId),
        encryptedRemoteUrl: Value(attachment.encryptedRemoteUrl),
        keyPayload: Value(attachment.keyPayload),
        localCachePath: Value(attachment.localCachePath),
        sizeBytes: Value(attachment.sizeBytes),
        state: Value(attachment.state),
      );
      await db.into(db.attachmentsTable).insert(privateCompanion);
    } else {
      final db = _databaseService.db;
      final publicCompanion = AttachmentsTableCompanion(
        id: Value(attachment.id),
        messageId: Value(attachment.messageId),
        encryptedRemoteUrl: Value(attachment.encryptedRemoteUrl),
        keyPayload: Value(attachment.keyPayload),
        localCachePath: Value(attachment.localCachePath),
        sizeBytes: Value(attachment.sizeBytes),
        state: Value(attachment.state),
      );
      await db.into(db.attachmentsTable).insert(publicCompanion);
    }

    return attachment;
  }

  @override
  Future<void> updateAttachmentState(String id, String state) async {
    final attach = await getAttachmentById(id);
    if (attach == null) return;
    final msg = await getMessageById(attach.messageId);
    if (msg == null) return;
    final isHidden = await _isConversationHidden(msg.conversationId);

    if (isHidden) {
      final db = _getPrivateDb();
      final companion = private_db.AttachmentsTableCompanion(
        state: Value(state),
      );
      await (db.update(db.attachmentsTable)..where((t) => t.id.equals(id))).write(companion);
    } else {
      final db = _databaseService.db;
      final companion = AttachmentsTableCompanion(
        state: Value(state),
      );
      await (db.update(db.attachmentsTable)..where((t) => t.id.equals(id))).write(companion);
    }
  }

  @override
  Future<void> updateAttachmentLocalPath(String id, String? localCachePath) async {
    final attach = await getAttachmentById(id);
    if (attach == null) return;
    final msg = await getMessageById(attach.messageId);
    if (msg == null) return;
    final isHidden = await _isConversationHidden(msg.conversationId);

    if (isHidden) {
      final db = _getPrivateDb();
      final companion = private_db.AttachmentsTableCompanion(
        localCachePath: Value(localCachePath),
      );
      await (db.update(db.attachmentsTable)..where((t) => t.id.equals(id))).write(companion);
    } else {
      final db = _databaseService.db;
      final companion = AttachmentsTableCompanion(
        localCachePath: Value(localCachePath),
      );
      await (db.update(db.attachmentsTable)..where((t) => t.id.equals(id))).write(companion);
    }
  }

  // ─── Sync Metadata ───────────────────────────────────────────────────────

  @override
  Future<String?> getSyncMetadata(String key) async {
    final privateDb = _hiddenVaultService.db;
    if (privateDb != null) {
      final row = await (privateDb.select(privateDb.syncMetadataTable)..where((t) => t.key.equals(key))).getSingleOrNull();
      if (row != null) return row.value;
    }
    final publicDb = _databaseService.db;
    final row = await (publicDb.select(publicDb.syncMetadataTable)..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row != null) return row.value;
    return null;
  }

  @override
  Future<void> setSyncMetadata(String key, String value) async {
    final now = DateTime.now().toUtc();

    final privateDb = _hiddenVaultService.db;
    if (privateDb != null) {
      final privateCompanion = private_db.SyncMetadataTableCompanion(
        key: Value(key),
        value: Value(value),
        updatedAt: Value(now),
      );
      await privateDb.into(privateDb.syncMetadataTable).insertOnConflictUpdate(privateCompanion);
    }

    final publicDb = _databaseService.db;
    final publicCompanion = SyncMetadataTableCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(now),
    );
    await publicDb.into(publicDb.syncMetadataTable).insertOnConflictUpdate(publicCompanion);
  }
}
