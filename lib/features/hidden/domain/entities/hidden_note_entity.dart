import 'package:memovault/domain/notes/note_entity.dart';

class HiddenNoteEntity {
  final String id;
  final String title;
  final String body;
  final String? categoryId;
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
    this.categoryId,
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
    String? categoryId,
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
      categoryId: categoryId ?? this.categoryId,
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

  NoteEntity toNoteEntity() {
    return NoteEntity(
      id: id,
      title: title,
      body: body,
      categoryId: categoryId,
      revision: revision,
      isFavorite: isFavorite,
      isArchived: isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastOpenedAt: lastOpenedAt,
    );
  }
}
