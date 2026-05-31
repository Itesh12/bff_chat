class AttachmentEntity {
  final String id;
  final String messageId;
  final String encryptedRemoteUrl;
  final String keyPayload; // AES key encrypted with E2E session key
  final String? localCachePath;
  final int sizeBytes;
  final String state; // uploading, uploaded, decrypting, completed, failed

  const AttachmentEntity({
    required this.id,
    required this.messageId,
    required this.encryptedRemoteUrl,
    required this.keyPayload,
    this.localCachePath,
    required this.sizeBytes,
    required this.state,
  });

  AttachmentEntity copyWith({
    String? id,
    String? messageId,
    String? encryptedRemoteUrl,
    String? keyPayload,
    String? localCachePath,
    int? sizeBytes,
    String? state,
  }) {
    return AttachmentEntity(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      encryptedRemoteUrl: encryptedRemoteUrl ?? this.encryptedRemoteUrl,
      keyPayload: keyPayload ?? this.keyPayload,
      localCachePath: localCachePath ?? this.localCachePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      state: state ?? this.state,
    );
  }
}
