import 'package:memovault/domain/messaging/participant_entity.dart';
import 'package:memovault/domain/messaging/conversation_entity.dart';
import 'package:memovault/domain/messaging/message_entity.dart';
import 'package:memovault/domain/messaging/message_receipt_entity.dart';
import 'package:memovault/domain/messaging/attachment_entity.dart';

abstract class MessagingRepository {
  // ─── Participants ────────────────────────────────────────────────────────
  Future<ParticipantEntity?> getParticipantById(String id);
  Future<ParticipantEntity?> getParticipantByUsername(String username);
  Future<ParticipantEntity> createOrUpdateParticipant({
    required String id,
    required String username,
    required String identityKeyPub,
    String? trustState,
  });
  Future<void> updateParticipantTrustState(String id, String trustState);

  // ─── Conversations ───────────────────────────────────────────────────────
  Stream<List<ConversationEntity>> watchAllConversations({bool isHidden = false});
  Future<ConversationEntity?> getConversationById(String id);
  Future<ConversationEntity> createConversation({
    required String id,
    required String participantId,
    required bool isHidden,
  });
  Future<void> updateConversationLastMessage(String id, String? lastMessageId);
  Future<void> updateConversationUnreadCount(String id, int unreadCount);
  Future<void> toggleMuteConversation(String id);
  Future<void> toggleBlockConversation(String id);
  Future<void> toggleArchiveConversation(String id);

  // ─── Messages ────────────────────────────────────────────────────────────
  Stream<List<MessageEntity>> watchMessagesForConversation(String conversationId);
  Future<List<MessageEntity>> getMessagesForConversation(String conversationId);
  Future<MessageEntity?> getMessageById(String id);
  Future<MessageEntity> insertMessage(MessageEntity message);
  Future<void> updateMessageState(String id, String state);
  Future<void> deleteMessage(String id);

  // ─── Receipts ────────────────────────────────────────────────────────────
  Stream<List<MessageReceiptEntity>> watchReceiptsForMessage(String messageId);
  Future<List<MessageReceiptEntity>> getReceiptsForMessage(String messageId);
  Future<void> insertReceipt(MessageReceiptEntity receipt);

  // ─── Attachments ─────────────────────────────────────────────────────────
  Future<List<AttachmentEntity>> getAttachmentsForMessage(String messageId);
  Future<AttachmentEntity?> getAttachmentById(String id);
  Future<AttachmentEntity> insertAttachment(AttachmentEntity attachment);
  Future<void> updateAttachmentState(String id, String state);
  Future<void> updateAttachmentLocalPath(String id, String? localCachePath);

  // ─── Sync Metadata ───────────────────────────────────────────────────────
  Future<String?> getSyncMetadata(String key);
  Future<void> setSyncMetadata(String key, String value);
  Future<void> deleteExpiredHandshakes();
}
