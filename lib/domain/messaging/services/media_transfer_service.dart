import 'dart:io';
import 'package:memovault/domain/messaging/attachment_entity.dart';

abstract class MediaTransferService {
  Future<AttachmentEntity> uploadEncryptedFile({
    required String messageId,
    required File file,
    required String fileType,
  });

  Future<File> downloadAndDecryptFile({
    required AttachmentEntity attachment,
  });
}
