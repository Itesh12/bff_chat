import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/crypto/media_cryptor.dart';
import 'package:memovault/data/messaging/services/r2_storage_service_impl.dart';
import 'package:memovault/domain/messaging/attachment_entity.dart';
import 'package:memovault/domain/messaging/attachment_type.dart';
import 'package:memovault/domain/messaging/services/media_transfer_service.dart';
import 'package:memovault/domain/messaging/services/r2_storage_service.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';
import 'dart:typed_data';

class MediaTransferServiceImpl implements MediaTransferService {
  final R2StorageService _r2storageService;
  final MessagingRepository _messagingRepository;

  MediaTransferServiceImpl(this._r2storageService, this._messagingRepository);

  static Future<Directory> get _decryptedCacheDirectory async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/decrypted_media');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Purges all local decrypted cache files
  static Future<void> purgeDecryptedCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory('${tempDir.path}/decrypted_media');
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
        AppLogger.info('[MediaTransferService] Ephemeral decrypted cache directory purged.');
      }
    } catch (e) {
      AppLogger.error('[MediaTransferService] Failed to purge decrypted cache: $e');
    }
  }

  @override
  Future<AttachmentEntity> uploadEncryptedFile({
    required String messageId,
    required File file,
    required String fileType,
  }) async {
    final attachmentId = const Uuid().v4();
    final originalBytes = await file.readAsBytes();
    final totalSize = originalBytes.length;

    AppLogger.info('[MediaTransferService] Encrypting file: $attachmentId, Size: $totalSize bytes');

    // 1. Generate Media Key and Checksum
    final mediaKey = MediaCryptor.generateMediaKey();
    final checksum = sha256.convert(originalBytes).toString();

    // 2. Generate and encrypt thumbnail for images
    Uint8List? encryptedThumbnailBytes;
    if (fileType.startsWith('image/')) {
      try {
        final decodedImage = img.decodeImage(originalBytes);
        if (decodedImage != null) {
          final thumbnail = img.copyResize(decodedImage, width: 256, height: 256);
          final rawThumbnail = Uint8List.fromList(img.encodeJpg(thumbnail));
          encryptedThumbnailBytes = await MediaCryptor.encryptFileBytes(rawThumbnail, mediaKey);
          AppLogger.info('[MediaTransferService] Generated and encrypted thumbnail for image.');
        }
      } catch (e) {
        AppLogger.warning('[MediaTransferService] Thumbnail generation failed: $e');
      }
    }

    // 3. Encrypt original file
    final encryptedOriginalBytes = await MediaCryptor.encryptFileBytes(originalBytes, mediaKey);

    // 4. Create local draft attachment record
    final hexMediaKey = _bytesToHex(mediaKey);
    final localAttachment = AttachmentEntity(
      id: attachmentId,
      messageId: messageId,
      type: AttachmentType.fromJson(fileType.startsWith('image/') ? 'image' : 'file'),
      fileName: file.path.split(RegExp(r'[/\\]')).last,
      mimeType: fileType,
      size: totalSize,
      status: 'encrypting',
      uploadedBytes: 0,
      totalBytes: encryptedOriginalBytes.length,
      encryptionVersion: 1,
      checksumSha256: checksum,
      keyPayload: hexMediaKey,
      createdAt: DateTime.now().toUtc(),
    );
    await _messagingRepository.insertAttachment(localAttachment);

    // 5. Upload thumbnail if present
    String? remoteThumbnailPath;
    if (encryptedThumbnailBytes != null) {
      final thumbnailKey = 'thumbnails/$attachmentId.enc';
      final tempThumbFile = File('${Directory.systemTemp.path}/$thumbnailKey');
      if (!tempThumbFile.parent.existsSync()) {
        tempThumbFile.parent.createSync(recursive: true);
      }
      await tempThumbFile.writeAsBytes(encryptedThumbnailBytes);
      
      try {
        remoteThumbnailPath = await _r2storageService.uploadBlob(
          file: tempThumbFile,
          objectKey: thumbnailKey,
          mimeType: 'application/octet-stream',
        );
      } finally {
        if (tempThumbFile.existsSync()) {
          tempThumbFile.deleteSync();
        }
      }
    }

    // 6. Upload original encrypted file with progress tracking
    final originalKey = 'attachments/$attachmentId.enc';
    final tempOriginalFile = File('${Directory.systemTemp.path}/$originalKey');
    if (!tempOriginalFile.parent.existsSync()) {
      tempOriginalFile.parent.createSync(recursive: true);
    }
    await tempOriginalFile.writeAsBytes(encryptedOriginalBytes);

    String remotePath = '';
    try {
      await _messagingRepository.updateAttachmentProgress(
        attachmentId,
        0,
        encryptedOriginalBytes.length,
        'uploading',
      );

      remotePath = await _r2storageService.uploadBlob(
        file: tempOriginalFile,
        objectKey: originalKey,
        mimeType: 'application/octet-stream',
        onProgress: (sent, total) {
          _messagingRepository.updateAttachmentProgress(
            attachmentId,
            sent,
            total,
            'uploading',
          ).catchError((e) {
            AppLogger.error('[MediaTransferService] Failed to update progress: $e');
          });
        },
      );

      // Finalize progress
      await _messagingRepository.updateAttachmentProgress(
        attachmentId,
        encryptedOriginalBytes.length,
        encryptedOriginalBytes.length,
        'completed',
      );
    } catch (e) {
      await _messagingRepository.updateAttachmentProgress(
        attachmentId,
        0,
        encryptedOriginalBytes.length,
        'failed',
      );
      rethrow;
    } finally {
      if (tempOriginalFile.existsSync()) {
        tempOriginalFile.deleteSync();
      }
    }

    // 7. Update database with paths and final completed status
    final completedAttachment = localAttachment.copyWith(
      status: 'completed',
      uploadedBytes: encryptedOriginalBytes.length,
      remotePath: remotePath,
      thumbnailPath: remoteThumbnailPath,
      localPath: file.path,
    );
    // Persist local and remote path updates in the database
    await _messagingRepository.updateAttachmentLocalPath(attachmentId, file.path);
    await _messagingRepository.updateAttachmentRemotePaths(attachmentId, remotePath, remoteThumbnailPath);

    return completedAttachment;
  }

  @override
  Future<File> downloadAndDecryptFile({
    required AttachmentEntity attachment,
  }) async {
    final hexMediaKey = attachment.keyPayload;
    if (hexMediaKey == null || hexMediaKey.isEmpty) {
      throw StateError('Missing decryption Media Key (keyPayload) for attachment: ${attachment.id}');
    }

    final mediaKey = _hexToBytes(hexMediaKey);
    final cacheDir = await _decryptedCacheDirectory;
    final decryptedFile = File('${cacheDir.path}/${attachment.id}_${attachment.fileName}');

    // If already downloaded and decrypted, return immediately
    if (decryptedFile.existsSync()) {
      return decryptedFile;
    }

    final remotePath = attachment.remotePath;
    if (remotePath == null || remotePath.isEmpty) {
      throw StateError('Missing remote storage path for attachment: ${attachment.id}');
    }

    AppLogger.info('[MediaTransferService] Downloading encrypted attachment: ${attachment.id}');
    await _messagingRepository.updateAttachmentState(attachment.id, 'decrypting');

    final tempEncFile = File('${Directory.systemTemp.path}/download_${attachment.id}.enc');
    try {
      // 1. Download encrypted blob to temporary file
      await R2StorageServiceImpl.downloadBlobToLocalFile(
        remoteUrl: remotePath,
        destinationFile: tempEncFile,
      );

      // 2. Decrypt downloaded ciphertext
      final encryptedBytes = await tempEncFile.readAsBytes();
      final decryptedBytes = await MediaCryptor.decryptFileBytes(encryptedBytes, mediaKey);

      // 3. Optional: Verify SHA-256 checksum to prevent corruption/tampering
      if (attachment.checksumSha256 != null) {
        final checksum = sha256.convert(decryptedBytes).toString();
        if (checksum != attachment.checksumSha256) {
          throw StateError('Attachment checksum mismatch. File may be corrupted or tampered.');
        }
      }

      // 4. Save decrypted bytes to cache
      await decryptedFile.writeAsBytes(decryptedBytes);
      await _messagingRepository.updateAttachmentLocalPath(attachment.id, decryptedFile.path);
      await _messagingRepository.updateAttachmentState(attachment.id, 'completed');

      return decryptedFile;
    } catch (e) {
      await _messagingRepository.updateAttachmentState(attachment.id, 'failed');
      rethrow;
    } finally {
      if (tempEncFile.existsSync()) {
        tempEncFile.deleteSync();
      }
    }
  }

  // ─── Hex Helpers ──────────────────────────────────────────────────────────

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _hexToBytes(String hex) {
    final length = hex.length;
    final bytes = Uint8List(length ~/ 2);
    for (var i = 0; i < length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }
}
