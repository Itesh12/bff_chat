class NoteEntity {
  final String id;          // Client UUID
  final String title;
  final String body;
  final String? categoryId;
  final int revision;       // Starts at 1, increments on every update
  final bool isFavorite;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt; // Nullable, updated when viewed

  const NoteEntity({
    required this.id,
    required this.title,
    required this.body,
    this.categoryId,
    required this.revision,
    required this.isFavorite,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedAt,
  });

  NoteEntity copyWith({
    String? id,
    String? title,
    String? body,
    String? categoryId,
    int? revision,
    bool? isFavorite,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
  }) {
    return NoteEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      categoryId: categoryId ?? this.categoryId,
      revision: revision ?? this.revision,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }
}
