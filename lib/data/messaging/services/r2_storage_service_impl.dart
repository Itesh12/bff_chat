import 'dart:io';
import 'package:memovault/core/config/env_config.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/domain/messaging/services/r2_storage_service.dart';

class R2StorageServiceImpl implements R2StorageService {
  static const String mockScheme = 'mock-r2://';

  // Directory used to simulate R2 storage in local/test/development configurations
  static Directory get _mockR2Directory {
    final tempDir = Directory.systemTemp.path;
    final dir = Directory('$tempDir/memovault_mock_r2');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  @override
  Future<String> uploadBlob({
    required File file,
    required String objectKey,
    required String mimeType,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async {
    // If running in development/test profiles without Firebase, use the local mock simulator
    if (EnvConfig.isTest || EnvConfig.isDevelopment) {
      AppLogger.info('[R2StorageService] Performing mock upload for key: $objectKey');
      final mockFile = File('${_mockR2Directory.path}/$objectKey');
      if (mockFile.parent.existsSync() == false) {
        mockFile.parent.createSync(recursive: true);
      }

      final bytes = await file.readAsBytes();
      final totalBytes = bytes.length;
      
      // Simulate progress callback
      if (onProgress != null) {
        onProgress(0, totalBytes);
        await Future.delayed(const Duration(milliseconds: 50));
        onProgress(totalBytes ~/ 2, totalBytes);
        await Future.delayed(const Duration(milliseconds: 50));
        onProgress(totalBytes, totalBytes);
      }

      await mockFile.writeAsBytes(bytes);
      return '$mockScheme$objectKey';
    }

    // Production / Staging Profile: Fetch presigned URL and PUT blob
    AppLogger.info('[R2StorageService] Fetching presigned upload URL for key: $objectKey');
    
    // Note: The presigned URL must be generated via a secure backend function/worker.
    // Here we outline the client execution flow.
    final presignedUrl = await _fetchPresignedUploadUrl(objectKey);

    final client = HttpClient();
    try {
      final request = await client.putUrl(Uri.parse(presignedUrl));
      request.headers.contentType = ContentType.parse(mimeType);
      request.contentLength = file.lengthSync();

      final totalBytes = file.lengthSync();
      var sentBytes = 0;

      final fileStream = file.openRead();
      await request.addStream(fileStream.map((chunk) {
        sentBytes += chunk.length;
        if (onProgress != null) {
          onProgress(sentBytes, totalBytes);
        }
        return chunk;
      }));

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok && response.statusCode != HttpStatus.noContent) {
        throw HttpException(
          'Failed to upload blob to R2. HTTP Status: ${response.statusCode}',
          uri: Uri.parse(presignedUrl),
        );
      }

      // Return the public/remote URL for reference
      return _getPublicRemoteUrl(objectKey);
    } finally {
      client.close();
    }
  }

  @override
  Future<void> deleteBlob({required String objectKey}) async {
    if (EnvConfig.isTest || EnvConfig.isDevelopment) {
      AppLogger.info('[R2StorageService] Performing mock delete for key: $objectKey');
      final mockFile = File('${_mockR2Directory.path}/$objectKey');
      if (mockFile.existsSync()) {
        mockFile.deleteSync();
      }
      return;
    }

    final presignedDeleteUrl = await _fetchPresignedDeleteUrl(objectKey);
    final client = HttpClient();
    try {
      final request = await client.deleteUrl(Uri.parse(presignedDeleteUrl));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok && response.statusCode != HttpStatus.noContent) {
        throw HttpException(
          'Failed to delete blob from R2. HTTP Status: ${response.statusCode}',
          uri: Uri.parse(presignedDeleteUrl),
        );
      }
    } finally {
      client.close();
    }
  }

  // ─── Help Helpers for Mock/Presigned URL Resolves ────────────────────────

  Future<String> _fetchPresignedUploadUrl(String objectKey) async {
    // In staging/production, make a secure HTTP request to your Cloudflare Worker / backend
    // to retrieve a presigned PUT URL. For demonstration:
    return 'https://media-api.memovault.com/presigned-put/$objectKey';
  }

  Future<String> _fetchPresignedDeleteUrl(String objectKey) async {
    return 'https://media-api.memovault.com/presigned-delete/$objectKey';
  }

  String _getPublicRemoteUrl(String objectKey) {
    return 'https://media.memovault.com/$objectKey';
  }

  /// Downloads a mock or real R2 blob into a destination local file path.
  static Future<void> downloadBlobToLocalFile({
    required String remoteUrl,
    required File destinationFile,
  }) async {
    if (remoteUrl.startsWith(mockScheme)) {
      final objectKey = remoteUrl.substring(mockScheme.length);
      final mockFile = File('${_mockR2Directory.path}/$objectKey');
      if (!mockFile.existsSync()) {
        throw FileSystemException('Mock R2 object does not exist: $objectKey');
      }
      await destinationFile.writeAsBytes(await mockFile.readAsBytes());
      return;
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(remoteUrl));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Failed to download media blob from R2. HTTP Status: ${response.statusCode}');
      }
      await response.pipe(destinationFile.openWrite());
    } finally {
      client.close();
    }
  }
}
