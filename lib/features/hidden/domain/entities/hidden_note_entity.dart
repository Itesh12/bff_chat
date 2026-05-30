class HiddenNoteEntity {
  final String id;
  final String title;
  final String body;
  final int revision;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;

  const HiddenNoteEntity({
    required this.id,
    required this.title,
    required this.body,
    required this.revision,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedAt,
  });

  HiddenNoteEntity copyWith({
    String? id,
    String? title,
    String? body,
    int? revision,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
  }) {
    return HiddenNoteEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      revision: revision ?? this.revision,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }
}
