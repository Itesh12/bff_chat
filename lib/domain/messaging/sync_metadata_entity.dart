class SyncMetadataEntity {
  final String key;
  final String value;
  final DateTime updatedAt;

  const SyncMetadataEntity({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  SyncMetadataEntity copyWith({
    String? key,
    String? value,
    DateTime? updatedAt,
  }) {
    return SyncMetadataEntity(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
