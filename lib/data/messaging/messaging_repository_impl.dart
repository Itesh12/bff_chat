import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:memovault/core/services/database_service.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/domain/messaging/attachment_entity.dart';
import 'package:memovault/domain/messaging/attachment_type.dart';
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

  MessagingRepositoryImpl(this._databaseService, this._hiddenVaultService) {
    deleteExpiredHandshakes().catchError((e) {
      // Ignore background cleanup failures on startup
    });
    deleteExpiredSkippedKeys().catchError((e) {
      // Ignore background cleanup failures on startup
    });
  }

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
      trustState: row.trustState,
    );
  }

  ParticipantEntity _toParticipantEntityFromPrivate(private_db.ParticipantRow row) {
    return ParticipantEntity(
      id: row.id,
      username: row.username,
      identityKeyPub: row.identityKeyPub,
      trustState: row.trustState,
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
      draft: row.draft,
      isPinned: row.isPinned,
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
      draft: row.draft,
      isPinned: row.isPinned,
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
      searchIndex: row.searchIndex,
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
      searchIndex: row.searchIndex,
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
      type: AttachmentType.fromJson(row.type),
      fileName: row.fileName,
      mimeType: row.mimeType,
      size: row.size,
      thumbnailPath: row.thumbnailPath,
      localPath: row.localPath,
      remotePath: row.remotePath,
      keyPayload: row.keyPayload,
      status: row.status,
      uploadedBytes: row.uploadedBytes,
      totalBytes: row.totalBytes,
      encryptionVersion: row.encryptionVersion,
      checksumSha256: row.checksumSha256,
      duration: row.duration,
      waveform: row.waveform,
      createdAt: row.createdAt,
    );
  }

  AttachmentEntity _toAttachmentEntityFromPrivate(private_db.AttachmentRow row) {
    return AttachmentEntity(
      id: row.id,
      messageId: row.messageId,
      type: AttachmentType.fromJson(row.type),
      fileName: row.fileName,
      mimeType: row.mimeType,
      size: row.size,
      thumbnailPath: row.thumbnailPath,
      localPath: row.localPath,
      remotePath: row.remotePath,
      keyPayload: row.keyPayload,
      status: row.status,
      uploadedBytes: row.uploadedBytes,
      totalBytes: row.totalBytes,
      encryptionVersion: row.encryptionVersion,
      checksumSha256: row.checksumSha256,
      duration: row.duration,
      waveform: row.waveform,
      createdAt: row.createdAt,
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
    String? trustState,
  }) async {
    final privateCompanion = private_db.ParticipantsTableCompanion(
      id: Value(id),
      username: Value(username),
      identityKeyPub: Value(identityKeyPub),
      trustState: trustState != null ? Value(trustState) : const Value.absent(),
    );

    final publicCompanion = ParticipantsTableCompanion(
      id: Value(id),
      username: Value(username),
      identityKeyPub: Value(identityKeyPub),
      trustState: trustState != null ? Value(trustState) : const Value.absent(),
    );

    final privateDb = _hiddenVaultService.db;
    if (privateDb != null) {
      await privateDb.into(privateDb.participantsTable).insertOnConflictUpdate(privateCompanion);
    }

    final publicDb = _databaseService.db;
    await publicDb.into(publicDb.participantsTable).insertOnConflictUpdate(publicCompanion);

    final resolved = await getParticipantById(id);
    return resolved ?? ParticipantEntity(
      id: id,
      username: username,
      identityKeyPub: identityKeyPub,
      trustState: trustState ?? 'unknown',
    );
  }

  @override
  Future<void> updateParticipantTrustState(String id, String trustState) async {
    final privateDb = _hiddenVaultService.db;
    if (privateDb != null) {
      final companion = private_db.ParticipantsTableCompanion(
        trustState: Value(trustState),
      );
      await (privateDb.update(privateDb.participantsTable)..where((t) => t.id.equals(id))).write(companion);
    }
    final publicDb = _databaseService.db;
    final companion = ParticipantsTableCompanion(
      trustState: Value(trustState),
    );
    await (publicDb.update(publicDb.participantsTable)..where((t) => t.id.equals(id))).write(companion);
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
    try {
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
    } on StateError catch (e) {
      if (e.message.contains('Attempted to access encrypted HiddenVaultDatabase')) {
        return null;
      }
      rethrow;
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
            ..where((t) => t.conversationId.equals(conversationId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
            .watch()
            .map((rows) => rows.map<MessageEntity>(_toMessageEntityFromPrivate).toList());
        } else {
          final db = _databaseService.db;
          return (db.select(db.messagesTable)
            ..where((t) => t.conversationId.equals(conversationId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
            .watch()
            .map((rows) => rows.map<MessageEntity>(_toMessageEntityFromPublic).toList());
        }
      });
    } else {
      final db = _databaseService.db;
      return (db.select(db.messagesTable)
        ..where((t) => t.conversationId.equals(conversationId) & t.isDeleted.equals(false))
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
        ..where((t) => t.conversationId.equals(conversationId) & t.isDeleted.equals(false))
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .get();
      return rows.map<MessageEntity>(_toMessageEntityFromPrivate).toList();
    } else {
      final db = _databaseService.db;
      final rows = await (db.select(db.messagesTable)
        ..where((t) => t.conversationId.equals(conversationId) & t.isDeleted.equals(false))
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

    final normalizedIndex = message.searchIndex ??
        (message.encryptedContent.isNotEmpty ? _normalizeForSearch(message.encryptedContent) : null);
    final messageWithSearch = message.copyWith(searchIndex: normalizedIndex);

    if (isHidden) {
      final db = _getPrivateDb();
      final privateCompanion = private_db.MessagesTableCompanion(
        id: Value(messageWithSearch.id),
        conversationId: Value(messageWithSearch.conversationId),
        senderId: Value(messageWithSearch.senderId),
        encryptedContent: Value(messageWithSearch.encryptedContent),
        nonce: Value(messageWithSearch.nonce),
        state: Value(messageWithSearch.state),
        messageType: Value(messageWithSearch.messageType),
        isDeleted: Value(messageWithSearch.isDeleted),
        deletedAt: Value(messageWithSearch.deletedAt),
        version: Value(messageWithSearch.version),
        createdAt: Value(messageWithSearch.createdAt),
        searchIndex: Value(messageWithSearch.searchIndex),
      );
      await db.into(db.messagesTable).insert(privateCompanion);
    } else {
      final db = _databaseService.db;
      final publicCompanion = MessagesTableCompanion(
        id: Value(messageWithSearch.id),
        conversationId: Value(messageWithSearch.conversationId),
        senderId: Value(messageWithSearch.senderId),
        encryptedContent: Value(messageWithSearch.encryptedContent),
        nonce: Value(messageWithSearch.nonce),
        state: Value(messageWithSearch.state),
        messageType: Value(messageWithSearch.messageType),
        isDeleted: Value(messageWithSearch.isDeleted),
        deletedAt: Value(messageWithSearch.deletedAt),
        version: Value(messageWithSearch.version),
        createdAt: Value(messageWithSearch.createdAt),
        searchIndex: Value(messageWithSearch.searchIndex),
      );
      await db.into(db.messagesTable).insert(publicCompanion);
    }

    return messageWithSearch;
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
        type: Value(attachment.type.name),
        fileName: Value(attachment.fileName),
        mimeType: Value(attachment.mimeType),
        size: Value(attachment.size),
        thumbnailPath: Value(attachment.thumbnailPath),
        localPath: Value(attachment.localPath),
        remotePath: Value(attachment.remotePath),
        keyPayload: Value(attachment.keyPayload),
        status: Value(attachment.status),
        uploadedBytes: Value(attachment.uploadedBytes),
        totalBytes: Value(attachment.totalBytes),
        encryptionVersion: Value(attachment.encryptionVersion),
        checksumSha256: Value(attachment.checksumSha256),
        duration: Value(attachment.duration),
        waveform: Value(attachment.waveform),
        createdAt: Value(attachment.createdAt),
      );
      await db.into(db.attachmentsTable).insertOnConflictUpdate(privateCompanion);
    } else {
      final db = _databaseService.db;
      final publicCompanion = AttachmentsTableCompanion(
        id: Value(attachment.id),
        messageId: Value(attachment.messageId),
        type: Value(attachment.type.name),
        fileName: Value(attachment.fileName),
        mimeType: Value(attachment.mimeType),
        size: Value(attachment.size),
        thumbnailPath: Value(attachment.thumbnailPath),
        localPath: Value(attachment.localPath),
        remotePath: Value(attachment.remotePath),
        keyPayload: Value(attachment.keyPayload),
        status: Value(attachment.status),
        uploadedBytes: Value(attachment.uploadedBytes),
        totalBytes: Value(attachment.totalBytes),
        encryptionVersion: Value(attachment.encryptionVersion),
        checksumSha256: Value(attachment.checksumSha256),
        duration: Value(attachment.duration),
        waveform: Value(attachment.waveform),
        createdAt: Value(attachment.createdAt),
      );
      await db.into(db.attachmentsTable).insertOnConflictUpdate(publicCompanion);
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
        status: Value(state),
      );
      await (db.update(db.attachmentsTable)..where((t) => t.id.equals(id))).write(companion);
    } else {
      final db = _databaseService.db;
      final companion = AttachmentsTableCompanion(
        status: Value(state),
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
        localPath: Value(localCachePath),
      );
      await (db.update(db.attachmentsTable)..where((t) => t.id.equals(id))).write(companion);
    } else {
      final db = _databaseService.db;
      final companion = AttachmentsTableCompanion(
        localPath: Value(localCachePath),
      );
      await (db.update(db.attachmentsTable)..where((t) => t.id.equals(id))).write(companion);
    }
  }

  @override
  Future<void> updateAttachmentProgress(String id, int uploadedBytes, int totalBytes, String status) async {
    final attach = await getAttachmentById(id);
    if (attach == null) return;
    final msg = await getMessageById(attach.messageId);
    if (msg == null) return;
    final isHidden = await _isConversationHidden(msg.conversationId);

    if (isHidden) {
      final db = _getPrivateDb();
      final companion = private_db.AttachmentsTableCompanion(
        uploadedBytes: Value(uploadedBytes),
        totalBytes: Value(totalBytes),
        status: Value(status),
      );
      await (db.update(db.attachmentsTable)..where((t) => t.id.equals(id))).write(companion);
    } else {
      final db = _databaseService.db;
      final companion = AttachmentsTableCompanion(
        uploadedBytes: Value(uploadedBytes),
        totalBytes: Value(totalBytes),
        status: Value(status),
      );
      await (db.update(db.attachmentsTable)..where((t) => t.id.equals(id))).write(companion);
    }
  }

  @override
  Future<void> updateAttachmentRemotePaths(String id, String? remotePath, String? thumbnailPath) async {
    final attach = await getAttachmentById(id);
    if (attach == null) return;
    final msg = await getMessageById(attach.messageId);
    if (msg == null) return;
    final isHidden = await _isConversationHidden(msg.conversationId);

    if (isHidden) {
      final db = _getPrivateDb();
      final companion = private_db.AttachmentsTableCompanion(
        remotePath: Value(remotePath),
        thumbnailPath: Value(thumbnailPath),
      );
      await (db.update(db.attachmentsTable)..where((t) => t.id.equals(id))).write(companion);
    } else {
      final db = _databaseService.db;
      final companion = AttachmentsTableCompanion(
        remotePath: Value(remotePath),
        thumbnailPath: Value(thumbnailPath),
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

  @override
  Future<void> deleteExpiredHandshakes() async {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 7));

    // Purge public db
    final publicDb = _databaseService.db;
    await (publicDb.delete(publicDb.messagesTable)
          ..where((t) => t.messageType.equals('handshake') & t.createdAt.isSmallerThan(Variable(cutoff))))
        .go();

    // Purge private db if open
    final privateDb = _hiddenVaultService.db;
    if (privateDb != null) {
      await (privateDb.delete(privateDb.messagesTable)
            ..where((t) => t.messageType.equals('handshake') & t.createdAt.isSmallerThan(Variable(cutoff))))
          .go();
    }
  }

  @override
  Future<void> deleteExpiredSkippedKeys() async {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30));

    // Purge public db
    final publicDb = _databaseService.db;
    await (publicDb.delete(publicDb.signalSkippedKeysTable)
          ..where((t) => t.createdAt.isSmallerThan(Variable(cutoff))))
        .go();

    // Purge private db if open
    final privateDb = _hiddenVaultService.db;
    if (privateDb != null) {
      await (privateDb.delete(privateDb.signalSkippedKeysTable)
            ..where((t) => t.createdAt.isSmallerThan(Variable(cutoff))))
          .go();
    }
  }

  // ─── E2EE Crypto Storage Implementation ───────────────────────────────────

  @override
  Future<Uint8List?> loadSession(String addressName, int deviceId, bool isHidden) async {
    if (isHidden) {
      final db = _getPrivateDb();
      final row = await (db.select(db.signalSessionsTable)
            ..where((t) => t.addressName.equals(addressName) & t.deviceId.equals(deviceId)))
          .getSingleOrNull();
      return row != null ? Uint8List.fromList(row.sessionRecord) : null;
    } else {
      final db = _databaseService.db;
      final row = await (db.select(db.signalSessionsTable)
            ..where((t) => t.addressName.equals(addressName) & t.deviceId.equals(deviceId)))
          .getSingleOrNull();
      return row != null ? Uint8List.fromList(row.sessionRecord) : null;
    }
  }

  @override
  Future<void> storeSession(String addressName, int deviceId, Uint8List sessionRecord, bool isHidden) async {
    if (isHidden) {
      final db = _getPrivateDb();
      await db.into(db.signalSessionsTable).insertOnConflictUpdate(
        private_db.SignalSessionsTableCompanion(
          addressName: Value(addressName),
          deviceId: Value(deviceId),
          sessionRecord: Value(sessionRecord),
        ),
      );
    } else {
      final db = _databaseService.db;
      await db.into(db.signalSessionsTable).insertOnConflictUpdate(
        SignalSessionsTableCompanion(
          addressName: Value(addressName),
          deviceId: Value(deviceId),
          sessionRecord: Value(sessionRecord),
        ),
      );
    }
  }

  @override
  Future<bool> containsSession(String addressName, int deviceId, bool isHidden) async {
    if (isHidden) {
      final db = _hiddenVaultService.db;
      if (db == null) return false;
      final row = await (db.select(db.signalSessionsTable)
            ..where((t) => t.addressName.equals(addressName) & t.deviceId.equals(deviceId)))
          .getSingleOrNull();
      return row != null;
    } else {
      final db = _databaseService.db;
      final row = await (db.select(db.signalSessionsTable)
            ..where((t) => t.addressName.equals(addressName) & t.deviceId.equals(deviceId)))
          .getSingleOrNull();
      return row != null;
    }
  }

  @override
  Future<void> deleteSession(String addressName, int deviceId, bool isHidden) async {
    if (isHidden) {
      final db = _getPrivateDb();
      await (db.delete(db.signalSessionsTable)
            ..where((t) => t.addressName.equals(addressName) & t.deviceId.equals(deviceId)))
          .go();
    } else {
      final db = _databaseService.db;
      await (db.delete(db.signalSessionsTable)
            ..where((t) => t.addressName.equals(addressName) & t.deviceId.equals(deviceId)))
          .go();
    }
  }

  @override
  Future<void> deleteAllSessions(String name, bool isHidden) async {
    if (isHidden) {
      final db = _getPrivateDb();
      await (db.delete(db.signalSessionsTable)..where((t) => t.addressName.equals(name))).go();
    } else {
      final db = _databaseService.db;
      await (db.delete(db.signalSessionsTable)..where((t) => t.addressName.equals(name))).go();
    }
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name, bool isHidden) async {
    if (isHidden) {
      final db = _hiddenVaultService.db;
      if (db == null) return [];
      final rows = await (db.select(db.signalSessionsTable)
            ..where((t) => t.addressName.equals(name) & t.deviceId.equals(1).not()))
          .get();
      return rows.map((r) => r.deviceId).toList();
    } else {
      final db = _databaseService.db;
      final rows = await (db.select(db.signalSessionsTable)
            ..where((t) => t.addressName.equals(name) & t.deviceId.equals(1).not()))
          .get();
      return rows.map((r) => r.deviceId).toList();
    }
  }

  @override
  Future<Uint8List?> loadPreKey(int preKeyId, bool isHidden) async {
    if (isHidden) {
      final db = _getPrivateDb();
      final row = await (db.select(db.signalOneTimePrekeysTable)..where((t) => t.preKeyId.equals(preKeyId)))
          .getSingleOrNull();
      return row != null ? Uint8List.fromList(row.preKeyRecord) : null;
    } else {
      final db = _databaseService.db;
      final row = await (db.select(db.signalOneTimePrekeysTable)..where((t) => t.preKeyId.equals(preKeyId)))
          .getSingleOrNull();
      return row != null ? Uint8List.fromList(row.preKeyRecord) : null;
    }
  }

  @override
  Future<void> storePreKey(int preKeyId, Uint8List preKeyRecord, bool isHidden) async {
    if (isHidden) {
      final db = _getPrivateDb();
      await db.into(db.signalOneTimePrekeysTable).insertOnConflictUpdate(
        private_db.SignalOneTimePrekeysTableCompanion(
          preKeyId: Value(preKeyId),
          preKeyRecord: Value(preKeyRecord),
        ),
      );
    } else {
      final db = _databaseService.db;
      await db.into(db.signalOneTimePrekeysTable).insertOnConflictUpdate(
        SignalOneTimePrekeysTableCompanion(
          preKeyId: Value(preKeyId),
          preKeyRecord: Value(preKeyRecord),
        ),
      );
    }
  }

  @override
  Future<bool> containsPreKey(int preKeyId, bool isHidden) async {
    if (isHidden) {
      final db = _hiddenVaultService.db;
      if (db == null) return false;
      final row = await (db.select(db.signalOneTimePrekeysTable)..where((t) => t.preKeyId.equals(preKeyId)))
          .getSingleOrNull();
      return row != null;
    } else {
      final db = _databaseService.db;
      final row = await (db.select(db.signalOneTimePrekeysTable)..where((t) => t.preKeyId.equals(preKeyId)))
          .getSingleOrNull();
      return row != null;
    }
  }

  @override
  Future<void> removePreKey(int preKeyId, bool isHidden) async {
    if (isHidden) {
      final db = _getPrivateDb();
      await (db.delete(db.signalOneTimePrekeysTable)..where((t) => t.preKeyId.equals(preKeyId))).go();
    } else {
      final db = _databaseService.db;
      await (db.delete(db.signalOneTimePrekeysTable)..where((t) => t.preKeyId.equals(preKeyId))).go();
    }
  }

  @override
  Future<List<int>> getAllPreKeyIds(bool isHidden) async {
    if (isHidden) {
      final db = _hiddenVaultService.db;
      if (db == null) return [];
      final rows = await db.select(db.signalOneTimePrekeysTable).get();
      return rows.map((r) => r.preKeyId).toList();
    } else {
      final db = _databaseService.db;
      final rows = await db.select(db.signalOneTimePrekeysTable).get();
      return rows.map((r) => r.preKeyId).toList();
    }
  }

  @override
  Future<bool> checkSkippedKeyExists(String senderId, String ratchetKey, int sequenceNumber, bool isHidden) async {
    if (isHidden) {
      final db = _hiddenVaultService.db;
      if (db == null) return false;
      final row = await (db.select(db.signalSkippedKeysTable)
            ..where((t) => t.senderId.equals(senderId) & t.ratchetKey.equals(ratchetKey) & t.sequenceNumber.equals(sequenceNumber)))
          .getSingleOrNull();
      return row != null;
    } else {
      final db = _databaseService.db;
      final row = await (db.select(db.signalSkippedKeysTable)
            ..where((t) => t.senderId.equals(senderId) & t.ratchetKey.equals(ratchetKey) & t.sequenceNumber.equals(sequenceNumber)))
          .getSingleOrNull();
      return row != null;
    }
  }

  @override
  Future<int> getSkippedKeysCount(String senderId, bool isHidden) async {
    if (isHidden) {
      final db = _hiddenVaultService.db;
      if (db == null) return 0;
      final list = await (db.select(db.signalSkippedKeysTable)..where((t) => t.senderId.equals(senderId))).get();
      return list.length;
    } else {
      final db = _databaseService.db;
      final list = await (db.select(db.signalSkippedKeysTable)..where((t) => t.senderId.equals(senderId))).get();
      return list.length;
    }
  }

  @override
  Future<void> insertSkippedKey(String senderId, String ratchetKey, int sequenceNumber, bool isHidden) async {
    if (isHidden) {
      final db = _getPrivateDb();
      await db.into(db.signalSkippedKeysTable).insert(
        private_db.SignalSkippedKeysTableCompanion(
          senderId: Value(senderId),
          ratchetKey: Value(ratchetKey),
          sequenceNumber: Value(sequenceNumber),
          keyBytes: Value(Uint8List(0)),
          createdAt: Value(DateTime.now().toUtc()),
        ),
      );
    } else {
      final db = _databaseService.db;
      await db.into(db.signalSkippedKeysTable).insert(
        SignalSkippedKeysTableCompanion(
          senderId: Value(senderId),
          ratchetKey: Value(ratchetKey),
          sequenceNumber: Value(sequenceNumber),
          keyBytes: Value(Uint8List(0)),
          createdAt: Value(DateTime.now().toUtc()),
        ),
      );
    }
  }

  @override
  Future<void> deleteSkippedKey(String senderId, String ratchetKey, int sequenceNumber, bool isHidden) async {
    if (isHidden) {
      final db = _getPrivateDb();
      await (db.delete(db.signalSkippedKeysTable)
            ..where((t) => t.senderId.equals(senderId) & t.ratchetKey.equals(ratchetKey) & t.sequenceNumber.equals(sequenceNumber)))
          .go();
    } else {
      final db = _databaseService.db;
      await (db.delete(db.signalSkippedKeysTable)
            ..where((t) => t.senderId.equals(senderId) & t.ratchetKey.equals(ratchetKey) & t.sequenceNumber.equals(sequenceNumber)))
          .go();
    }
  }

  @override
  Future<void> updateConversationDraft(String id, String? draft) async {
    final isHidden = await _isConversationHidden(id);
    if (isHidden) {
      final db = _getPrivateDb();
      final companion = private_db.ConversationsTableCompanion(
        draft: Value(draft),
      );
      await (db.update(db.conversationsTable)..where((t) => t.id.equals(id))).write(companion);
    } else {
      final db = _databaseService.db;
      final companion = ConversationsTableCompanion(
        draft: Value(draft),
      );
      await (db.update(db.conversationsTable)..where((t) => t.id.equals(id))).write(companion);
    }
  }

  @override
  Future<void> updateConversationPinnedState(String id, bool isPinned) async {
    final isHidden = await _isConversationHidden(id);
    if (isHidden) {
      final db = _getPrivateDb();
      final companion = private_db.ConversationsTableCompanion(
        isPinned: Value(isPinned),
      );
      await (db.update(db.conversationsTable)..where((t) => t.id.equals(id))).write(companion);
    } else {
      final db = _databaseService.db;
      final companion = ConversationsTableCompanion(
        isPinned: Value(isPinned),
      );
      await (db.update(db.conversationsTable)..where((t) => t.id.equals(id))).write(companion);
    }
  }

  @override
  Future<void> clearChatHistory(String conversationId) async {
    final isHidden = await _isConversationHidden(conversationId);
    final now = DateTime.now().toUtc();
    if (isHidden) {
      final db = _getPrivateDb();
      final companion = private_db.MessagesTableCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
      );
      await (db.update(db.messagesTable)
            ..where((t) => t.conversationId.equals(conversationId)))
          .write(companion);
    } else {
      final db = _databaseService.db;
      final companion = MessagesTableCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
      );
      await (db.update(db.messagesTable)
            ..where((t) => t.conversationId.equals(conversationId)))
          .write(companion);
    }
  }

  @override
  Future<List<MessageEntity>> searchLocalMessages(String query, {bool isHidden = false}) async {
    if (query.trim().isEmpty) return [];
    final cleanQuery = '%${_normalizeForSearch(query)}%';
    if (isHidden) {
      final db = _getPrivateDb();
      final rows = await (db.select(db.messagesTable)
            ..where((t) => t.searchIndex.like(cleanQuery) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
          .get();
      return rows.map<MessageEntity>(_toMessageEntityFromPrivate).toList();
    } else {
      final db = _databaseService.db;
      final rows = await (db.select(db.messagesTable)
            ..where((t) => t.searchIndex.like(cleanQuery) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
          .get();
      return rows.map<MessageEntity>(_toMessageEntityFromPublic).toList();
    }
  }

  String _normalizeForSearch(String text) {
    return text.toLowerCase().replaceAll(RegExp(r"[^\w\s]"), "");
  }
}
