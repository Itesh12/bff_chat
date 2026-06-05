import 'package:drift/drift.dart';

@DataClassName('ParticipantRow')
class ParticipantsTable extends Table {
  @override
  String get tableName => 'participants';

  TextColumn get id => text()();
  TextColumn get username => text().unique()();
  TextColumn get identityKeyPub => text()();
  TextColumn get trustState => text().withDefault(const Constant('unknown'))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ConversationRow')
class ConversationsTable extends Table {
  @override
  String get tableName => 'conversations';

  TextColumn get id => text()();
  TextColumn get participantId => text().references(ParticipantsTable, #id)();
  TextColumn get lastMessageId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
  BoolColumn get isBlocked => boolean().withDefault(const Constant(false))();
  TextColumn get draft => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MessageRow')
class MessagesTable extends Table {
  @override
  String get tableName => 'messages';

  TextColumn get id => text()();
  TextColumn get conversationId => text().references(ConversationsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get senderId => text().references(ParticipantsTable, #id)();
  TextColumn get encryptedContent => text()();
  TextColumn get nonce => text()();
  TextColumn get state => text()(); // queued, sending, sent, delivered, read, failed, expired
  TextColumn get messageType => text().withDefault(const Constant('text'))(); // text, image, video, file, voice, system, handshake
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get searchIndex => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MessageReceiptRow')
class MessageReceiptsTable extends Table {
  @override
  String get tableName => 'message_receipts';

  TextColumn get id => text()();
  TextColumn get messageId => text().references(MessagesTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get participantId => text().references(ParticipantsTable, #id)();
  TextColumn get status => text()(); // delivered, read
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AttachmentRow')
class AttachmentsTable extends Table {
  @override
  String get tableName => 'attachments';

  TextColumn get id => text()();
  TextColumn get messageId => text().references(MessagesTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()(); // image, video, voice, file
  TextColumn get fileName => text().nullable()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get size => integer()();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get localPath => text().nullable()();
  TextColumn get remotePath => text().nullable()();
  TextColumn get keyPayload => text().nullable()(); // AES key encrypted with E2E session key
  TextColumn get status => text()(); // queued, uploading, completed, decrypting, failed
  IntColumn get uploadedBytes => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  IntColumn get encryptionVersion => integer().withDefault(const Constant(1))();
  TextColumn get checksumSha256 => text().nullable()();
  IntColumn get duration => integer().nullable()();
  TextColumn get waveform => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyncMetadataRow')
class SyncMetadataTable extends Table {
  @override
  String get tableName => 'sync_metadata';

  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
