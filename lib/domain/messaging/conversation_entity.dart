class ConversationEntity {
  final String id;
  final String participantId;
  final String? lastMessageId;
  final DateTime updatedAt;
  final int unreadCount;
  final bool isHidden;
  final bool isArchived;
  final bool isMuted;
  final bool isBlocked;
  final String? draft;
  final bool isPinned;

  const ConversationEntity({
    required this.id,
    required this.participantId,
    this.lastMessageId,
    required this.updatedAt,
    required this.unreadCount,
    required this.isHidden,
    required this.isArchived,
    required this.isMuted,
    required this.isBlocked,
    this.draft,
    this.isPinned = false,
  });

  ConversationEntity copyWith({
    String? id,
    String? participantId,
    String? lastMessageId,
    DateTime? updatedAt,
    int? unreadCount,
    bool? isHidden,
    bool? isArchived,
    bool? isMuted,
    bool? isBlocked,
    String? draft,
    bool? isPinned,
  }) {
    return ConversationEntity(
      id: id ?? this.id,
      participantId: participantId ?? this.participantId,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isHidden: isHidden ?? this.isHidden,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      isBlocked: isBlocked ?? this.isBlocked,
      draft: draft ?? this.draft,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
