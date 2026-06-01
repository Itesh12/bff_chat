enum AttachmentType {
  image,
  video,
  voice,
  file;

  String toJson() => name;

  static AttachmentType fromJson(String value) {
    return AttachmentType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => AttachmentType.file,
    );
  }
}
