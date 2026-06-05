import 'dart:convert';
import 'dart:io';
import 'package:memovault/core/config/env_config.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/domain/messaging/services/media_storage_service.dart';

class CloudinaryStorageServiceImpl implements MediaStorageService {
  static const String mockScheme = 'mock-cloudinary://';

  // Directory used to simulate storage in local/test/development configurations
  static Directory get _mockDirectory {
    final tempDir = Directory.systemTemp.path;
    final dir = Directory('$tempDir/memovault_mock_cloudinary');
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
      AppLogger.info('[CloudinaryStorageService] Performing mock upload for key: $objectKey');
      final mockFile = File('${_mockDirectory.path}/$objectKey');
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

    // Production / Staging Profile: Unsigned POST upload to Cloudinary (raw files)
    final cloudName = EnvConfig.cloudinaryCloudName;
    final uploadPreset = EnvConfig.cloudinaryUploadPreset;

    if (cloudName.isEmpty || uploadPreset.isEmpty) {
      throw StateError('[CloudinaryStorageService] Cloudinary configuration is missing.');
    }

    AppLogger.info('[CloudinaryStorageService] Uploading raw encrypted file to Cloudinary: $objectKey');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    try {
      final apiBaseUrl = EnvConfig.cloudinaryApiBaseUrl;
      final uri = Uri.parse('$apiBaseUrl/v1_1/$cloudName/raw/upload');
      final request = await client.postUrl(uri);
      
      final boundary = '----Boundary-${DateTime.now().millisecondsSinceEpoch}';
      request.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');

      final fields = {
        'upload_preset': uploadPreset,
        'public_id': objectKey,
      };

      final List<int> requestBody = [];
      
      for (final entry in fields.entries) {
        requestBody.addAll(utf8.encode('--$boundary\r\n'));
        requestBody.addAll(utf8.encode('Content-Disposition: form-data; name="${entry.key}"\r\n\r\n'));
        requestBody.addAll(utf8.encode('${entry.value}\r\n'));
      }

      requestBody.addAll(utf8.encode('--$boundary\r\n'));
      requestBody.addAll(utf8.encode('Content-Disposition: form-data; name="file"; filename="${file.path.split(RegExp(r"[/\\]")).last}"\r\n'));
      requestBody.addAll(utf8.encode('Content-Type: application/octet-stream\r\n\r\n'));

      final fileBytes = await file.readAsBytes();
      final footer = utf8.encode('\r\n--$boundary--\r\n');

      final totalBytes = requestBody.length + fileBytes.length + footer.length;
      request.contentLength = totalBytes;

      request.add(requestBody);
      
      var sentBytes = requestBody.length;
      const chunkSize = 64 * 1024;
      for (var i = 0; i < fileBytes.length; i += chunkSize) {
        final end = (i + chunkSize < fileBytes.length) ? i + chunkSize : fileBytes.length;
        final chunk = fileBytes.sublist(i, end);
        request.add(chunk);
        sentBytes += chunk.length;
        if (onProgress != null) {
          onProgress(sentBytes, totalBytes);
        }
      }

      request.add(footer);

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok && response.statusCode != HttpStatus.created) {
        final errorResponse = await response.transform(const Utf8Decoder()).join();
        throw HttpException(
          'Failed to upload to Cloudinary. HTTP Status: ${response.statusCode}, Response: $errorResponse',
          uri: uri,
        );
      }

      final responseBody = await response.transform(const Utf8Decoder()).join();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final secureUrl = data['secure_url'] as String?;
      if (secureUrl == null) {
        throw const HttpException('Cloudinary response did not contain "secure_url" key');
      }
      return secureUrl;
    } finally {
      client.close();
    }
  }

  @override
  Future<void> deleteBlob({required String objectKey}) async {
    // Delete is a secure no-op on the client side since Cloudinary unsigned deletes are not supported.
    AppLogger.warning('[CloudinaryStorageService] Client-side delete is a secure no-op. Key: $objectKey');
  }

  @override
  Future<void> downloadBlobToLocalFile({
    required String remoteUrl,
    required File destinationFile,
  }) async {
    if (remoteUrl.startsWith(mockScheme)) {
      final objectKey = remoteUrl.substring(mockScheme.length);
      final mockFile = File('${_mockDirectory.path}/$objectKey');
      if (!mockFile.existsSync()) {
        throw FileSystemException('Mock Cloudinary object does not exist: $objectKey');
      }
      await destinationFile.writeAsBytes(await mockFile.readAsBytes());
      return;
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(remoteUrl));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Failed to download media from Cloudinary. HTTP Status: ${response.statusCode}');
      }
      await response.pipe(destinationFile.openWrite());
    } finally {
      client.close();
    }
  }
}
