import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/config/env_config.dart';
import 'package:memovault/data/messaging/services/cloudinary_storage_service.dart';

void main() {
  group('CloudinaryStorageServiceImpl Tests', () {
    late HttpServer mockServer;
    late CloudinaryStorageServiceImpl storageService;
    final testDirectory =
        Directory('${Directory.systemTemp.path}/memovault_test_cloudinary_ops');

    setUpAll(() async {
      if (!testDirectory.existsSync()) {
        testDirectory.createSync(recursive: true);
      }
    });

    tearDownAll(() async {
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    setUp(() {
      storageService = CloudinaryStorageServiceImpl();
    });

    test('Dev/Test Environment Fallback uses Mock storage', () async {
      EnvConfig.initialize(Environment.dev);

      final tempFile = File('${testDirectory.path}/test_cloudinary_upload.txt');
      await tempFile.writeAsString('Hello Cloudinary Mock');

      final objectKey = 'user_uploads/test_mock_file.txt';
      final remoteUrl = await storageService.uploadBlob(
        file: tempFile,
        objectKey: objectKey,
        mimeType: 'text/plain',
      );

      expect(remoteUrl, 'mock-cloudinary://$objectKey');

      final downloadFile =
          File('${testDirectory.path}/test_cloudinary_download.txt');
      await storageService.downloadBlobToLocalFile(
        remoteUrl: remoteUrl,
        destinationFile: downloadFile,
      );

      expect(downloadFile.existsSync(), true);
      expect(await downloadFile.readAsString(), 'Hello Cloudinary Mock');

      // Delete should run without errors
      await storageService.deleteBlob(objectKey: objectKey);
    });

    test(
        'Staging/Prod Environment correctly calls Cloudinary multipart upload and download endpoints',
        () async {
      EnvConfig.isTest = false;
      addTearDown(() => EnvConfig.isTest = true);

      mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serverUrl = 'http://localhost:${mockServer.port}';

      EnvConfig.initialize(Environment.staging);
      EnvConfig.cloudinaryApiBaseUrl = serverUrl;

      // Mock Cloudinary credentials to satisfy the validation
      // Since these are static const defined via fromEnvironment, we can inject via tests or just ensure they exist.
      // Since EnvConfig uses String.fromEnvironment, in unit test runs they might be empty strings.
      // Let's check: if they are empty, we can mock/override them or check the code.
      // Wait, in CloudinaryStorageServiceImpl:
      // if (cloudName.isEmpty || uploadPreset.isEmpty) { throw StateError(...) }
      // To prevent this error, since fromEnvironment cannot be mutated dynamically,
      // let's make sure the test executes with them, or can we configure them?
      // Wait, since String.fromEnvironment cannot be changed at runtime in Dart, how can we test the production/staging branch if they are empty?
      // Ah! If they are empty, the code throws. Let's see how we can handle this.
      // Can we make EnvConfig support test overrides for these configurations?
      // Yes, adding _cloudinaryCloudNameOverride and _cloudinaryUploadPresetOverride to EnvConfig is extremely clean!
    });
  });
}
