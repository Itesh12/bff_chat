class MessageReceiptEntity {
  final String id;
  final String messageId;
  final String participantId;
  final String status; // delivered, read
  final DateTime timestamp;

  const MessageReceiptEntity({
    required this.id,
    required this.messageId,
    required this.participantId,
    required this.status,
    required this.timestamp,
  });

  MessageReceiptEntity copyWith({
    String? id,
    String? messageId,
    String? participantId,
    String? status,
    DateTime? timestamp,
  }) {
    return MessageReceiptEntity(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      participantId: participantId ?? this.participantId,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
