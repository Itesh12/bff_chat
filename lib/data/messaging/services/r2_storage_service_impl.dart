import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:memovault/core/config/env_config.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/domain/messaging/services/media_storage_service.dart';

class R2StorageServiceImpl implements MediaStorageService {
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
    
    final presignedUrl = await _fetchPresignedUploadUrl(objectKey);

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
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

    AppLogger.info('[R2StorageService] Deleting blob via worker for key: $objectKey');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = Uri.parse('${EnvConfig.r2WorkerBaseUrl}/delete');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;

      if (Firebase.apps.isNotEmpty) {
        final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (idToken != null) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
        }
      }

      final bodyBytes = utf8.encode(jsonEncode({'key': objectKey}));
      request.contentLength = bodyBytes.length;
      request.add(bodyBytes);

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok && response.statusCode != HttpStatus.noContent) {
        throw HttpException(
          'Failed to delete blob from R2 via worker. HTTP Status: ${response.statusCode}',
          uri: uri,
        );
      }
    } finally {
      client.close();
    }
  }

  // ─── Helpers for Mock/Presigned URL Resolves ────────────────────────

  static Future<String> _fetchPresignedUploadUrl(String objectKey) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = Uri.parse('${EnvConfig.r2WorkerBaseUrl}/presigned-put?key=$objectKey');
      final request = await client.getUrl(uri);
      
      if (Firebase.apps.isNotEmpty) {
        final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (idToken != null) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
        }
      }
      
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Failed to fetch presigned upload URL from worker. HTTP Status: ${response.statusCode}',
          uri: uri,
        );
      }
      
      final body = await response.transform(const Utf8Decoder()).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final url = data['url'] as String?;
      if (url == null) {
        throw const HttpException('Presigned URL response did not contain "url" key');
      }
      return url;
    } finally {
      client.close();
    }
  }

  static Future<String> _fetchPresignedDownloadUrl(String objectKey) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = Uri.parse('${EnvConfig.r2WorkerBaseUrl}/presigned-get?key=$objectKey');
      final request = await client.getUrl(uri);
      
      if (Firebase.apps.isNotEmpty) {
        final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (idToken != null) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
        }
      }
      
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Failed to fetch presigned download URL from worker. HTTP Status: ${response.statusCode}',
          uri: uri,
        );
      }
      
      final body = await response.transform(const Utf8Decoder()).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final url = data['url'] as String?;
      if (url == null) {
        throw const HttpException('Presigned URL response did not contain "url" key');
      }
      return url;
    } finally {
      client.close();
    }
  }

  static String _getPublicRemoteUrl(String objectKey) {
    return '${EnvConfig.r2CdnBaseUrl}/$objectKey';
  }

  /// Downloads a mock or real R2 blob into a destination local file path.
  @override
  Future<void> downloadBlobToLocalFile({
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

    final objectKey = remoteUrl.split('/').last;
    AppLogger.info('[R2StorageService] Fetching presigned download URL for key: $objectKey');
    final presignedGetUrl = await _fetchPresignedDownloadUrl(objectKey);

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(presignedGetUrl));
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
