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
  final int uploadedBytes;
  final int totalBytes;
  final int encryptionVersion;
  final String? checksumSha256;
  final int? duration;
  final String? waveform;
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
    this.uploadedBytes = 0,
    this.totalBytes = 0,
    this.encryptionVersion = 1,
    this.checksumSha256,
    this.duration,
    this.waveform,
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
    int? uploadedBytes,
    int? totalBytes,
    int? encryptionVersion,
    String? checksumSha256,
    int? duration,
    String? waveform,
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
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      encryptionVersion: encryptionVersion ?? this.encryptionVersion,
      checksumSha256: checksumSha256 ?? this.checksumSha256,
      duration: duration ?? this.duration,
      waveform: waveform ?? this.waveform,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
