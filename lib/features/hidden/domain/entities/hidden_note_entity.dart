class HiddenNoteEntity {
  final String id;
  final String title;
  final String body;
  final int revision;
  final bool isFavorite;
  final bool isArchived;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? lastOpenedAt;

  const HiddenNoteEntity({
    required this.id,
    required this.title,
    required this.body,
    required this.revision,
    required this.isFavorite,
    this.isArchived = false,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.lastOpenedAt,
  });

  HiddenNoteEntity copyWith({
    String? id,
    String? title,
    String? body,
    int? revision,
    bool? isFavorite,
    bool? isArchived,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? lastOpenedAt,
  }) {
    return HiddenNoteEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      revision: revision ?? this.revision,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }
}
