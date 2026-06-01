import 'package:memovault/domain/messaging/attachment_type.dart';

class AttachmentEntity {
  final String id;
  final String messageId;
  final AttachmentType type;
  final String? fileName;
  final String? mimeType;
  final int size;
  final String? thumbnailPath;
  final String? localPath;
  final String? remotePath;
  final String? keyPayload;
  final String status;
  final DateTime createdAt;

  const AttachmentEntity({
    required this.id,
    required this.messageId,
    required this.type,
    this.fileName,
    this.mimeType,
    required this.size,
    this.thumbnailPath,
    this.localPath,
    this.remotePath,
    this.keyPayload,
    required this.status,
    required this.createdAt,
  });

  AttachmentEntity copyWith({
    String? id,
    String? messageId,
    AttachmentType? type,
    String? fileName,
    String? mimeType,
    int? size,
    String? thumbnailPath,
    String? localPath,
    String? remotePath,
    String? keyPayload,
    String? status,
    DateTime? createdAt,
  }) {
    return AttachmentEntity(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      type: type ?? this.type,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      localPath: localPath ?? this.localPath,
      remotePath: remotePath ?? this.remotePath,
      keyPayload: keyPayload ?? this.keyPayload,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
