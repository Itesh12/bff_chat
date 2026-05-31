class MessageEntity {
  final String id;
  final String conversationId;
  final String senderId;
  final String encryptedContent;
  final String nonce;
  final String state; // pending, sending, sent, delivered, read, failed, expired
  final String messageType; // text, image, video, file, voice, system, handshake
  final bool isDeleted;
  final DateTime? deletedAt;
  final int version;
  final DateTime createdAt;

  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.encryptedContent,
    required this.nonce,
    required this.state,
    this.messageType = 'text',
    this.isDeleted = false,
    this.deletedAt,
    this.version = 1,
    required this.createdAt,
  });

  MessageEntity copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? encryptedContent,
    String? nonce,
    String? state,
    String? messageType,
    bool? isDeleted,
    DateTime? deletedAt,
    int? version,
    DateTime? createdAt,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      nonce: nonce ?? this.nonce,
      state: state ?? this.state,
      messageType: messageType ?? this.messageType,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
