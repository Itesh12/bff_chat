import 'dart:io';

abstract class MediaStorageService {
  Future<String> uploadBlob({
    required File file,
    required String objectKey,
    required String mimeType,
    void Function(int sentBytes, int totalBytes)? onProgress,
  });

  Future<void> deleteBlob({
    required String objectKey,
  });

  Future<void> downloadBlobToLocalFile({
    required String remoteUrl,
    required File destinationFile,
  });
}
