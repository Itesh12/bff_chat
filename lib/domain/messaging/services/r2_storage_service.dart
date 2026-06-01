import 'dart:io';

abstract class R2StorageService {
  Future<String> uploadBlob({
    required File file,
    required String objectKey,
    required String mimeType,
  });

  Future<void> deleteBlob({
    required String objectKey,
  });
}
