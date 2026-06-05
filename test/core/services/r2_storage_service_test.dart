import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/config/env_config.dart';
import 'package:memovault/data/messaging/services/r2_storage_service_impl.dart';

void main() {
  group('R2StorageServiceImpl Tests', () {
    late HttpServer mockServer;
    late R2StorageServiceImpl storageService;
    final testDirectory = Directory('${Directory.systemTemp.path}/memovault_test_r2_ops');

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
      storageService = R2StorageServiceImpl();
    });

    test('Dev/Test Environment Fallback uses Mock storage', () async {
      EnvConfig.initialize(Environment.dev);

      final tempFile = File('${testDirectory.path}/test_upload.txt');
      await tempFile.writeAsString('Hello R2 Mock');

      final objectKey = 'user_uploads/test_mock_file.txt';
      final remoteUrl = await storageService.uploadBlob(
        file: tempFile,
        objectKey: objectKey,
        mimeType: 'text/plain',
      );

      expect(remoteUrl, 'mock-r2://$objectKey');

      final downloadFile = File('${testDirectory.path}/test_download.txt');
      await R2StorageServiceImpl.downloadBlobToLocalFile(
        remoteUrl: remoteUrl,
        destinationFile: downloadFile,
      );

      expect(downloadFile.existsSync(), true);
      expect(await downloadFile.readAsString(), 'Hello R2 Mock');

      await storageService.deleteBlob(objectKey: objectKey);
    });

    test('Staging/Prod Environment correctly calls Cloudflare Worker endpoints', () async {
      EnvConfig.isTest = false;
      addTearDown(() => EnvConfig.isTest = true);

      mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serverUrl = 'http://localhost:${mockServer.port}';

      EnvConfig.initialize(Environment.staging);
      EnvConfig.r2WorkerBaseUrl = serverUrl;
      EnvConfig.r2CdnBaseUrl = serverUrl;

      mockServer.listen((HttpRequest request) async {
        try {
          if (request.uri.path == '/presigned-put') {
            expect(request.method, 'GET');
            expect(request.uri.queryParameters['key'], 'test_blob.enc');
            
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'url': '$serverUrl/r2-mock-bucket/test_blob.enc'}));
            await request.response.close();
          } else if (request.uri.path == '/r2-mock-bucket/test_blob.enc') {
            if (request.method == 'PUT') {
              expect(request.headers.contentType?.mimeType, 'application/octet-stream');
              final bodyBytes = await request.fold<List<int>>([], (prev, elem) => prev..addAll(elem));
              expect(utf8.decode(bodyBytes), 'encrypted-payload-content');
              
              request.response.statusCode = HttpStatus.ok;
              await request.response.close();
            } else if (request.method == 'GET') {
              request.response
                ..statusCode = HttpStatus.ok
                ..headers.contentType = ContentType.binary
                ..add(utf8.encode('encrypted-payload-content'));
              await request.response.close();
            }
          } else if (request.uri.path == '/presigned-get') {
            expect(request.method, 'GET');
            expect(request.uri.queryParameters['key'], 'test_blob.enc');
            
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'url': '$serverUrl/r2-mock-bucket/test_blob.enc'}));
            await request.response.close();
          } else if (request.uri.path == '/delete') {
            expect(request.method, 'POST');
            expect(request.headers.contentType?.mimeType, 'application/json');
            
            final bodyStr = await utf8.decodeStream(request);
            final body = jsonDecode(bodyStr) as Map<String, dynamic>;
            expect(body['key'], 'test_blob.enc');
            
            request.response.statusCode = HttpStatus.ok;
            await request.response.close();
          } else {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
          }
        } catch (e) {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write(e.toString());
          await request.response.close();
        }
      });

      final fileToUpload = File('${testDirectory.path}/test_upload_real.enc');
      await fileToUpload.writeAsString('encrypted-payload-content');

      final remoteUrl = await storageService.uploadBlob(
        file: fileToUpload,
        objectKey: 'test_blob.enc',
        mimeType: 'application/octet-stream',
      );

      expect(remoteUrl, '$serverUrl/test_blob.enc');

      final downloadFile = File('${testDirectory.path}/test_download_real.enc');
      await R2StorageServiceImpl.downloadBlobToLocalFile(
        remoteUrl: remoteUrl,
        destinationFile: downloadFile,
      );

      expect(downloadFile.existsSync(), true);
      expect(await downloadFile.readAsString(), 'encrypted-payload-content');

      await storageService.deleteBlob(objectKey: 'test_blob.enc');

      await mockServer.close();
    });

    group('R2StorageServiceImpl Timeout & Errors', () {
      late HttpServer mockServer;
      late R2StorageServiceImpl storageService;

      setUp(() {
        storageService = R2StorageServiceImpl();
      });

      test('Staging/Prod handles error status code correctly', () async {
        EnvConfig.isTest = false;
        addTearDown(() => EnvConfig.isTest = true);

        mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final serverUrl = 'http://localhost:${mockServer.port}';

        EnvConfig.initialize(Environment.staging);
        EnvConfig.r2WorkerBaseUrl = serverUrl;

        mockServer.listen((HttpRequest request) async {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
        });

        final fileToUpload = File('${testDirectory.path}/err.enc');
        if (!fileToUpload.parent.existsSync()) {
          fileToUpload.parent.createSync(recursive: true);
        }
        await fileToUpload.writeAsString('data');

        await expectLater(
          () => storageService.uploadBlob(
            file: fileToUpload,
            objectKey: 'err.enc',
            mimeType: 'application/octet-stream',
          ),
          throwsA(isA<HttpException>()),
        );

        await mockServer.close();
      });
    });
  });
}
