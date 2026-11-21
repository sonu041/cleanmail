import '../models/message.dart';
import '../models/category.dart';
import '../models/sender_summary.dart';

abstract class MessageRepository {
  Stream<List<MailMessage>> watchInbox({
    String? accountId,
    MailCategory? category,
  });

  Future<MailMessage?> getMessage(String id);
  Future<void> saveMessages(List<MailMessage> messages);
  Future<void> markRead(String messageId, bool isRead);
  Future<void> archive(String messageId, bool isArchived);
  Future<void> delete(String messageId);
  Future<void> restoreMessage(MailMessage message);

  // Delta History & Remote Sync operations
  Future<int> deleteMessagesByRemoteIds(List<String> remoteIds);
  Future<void> markMessageReadByRemoteId(String remoteId, bool isRead);
  Future<void> archiveMessageByRemoteId(String remoteId, bool isArchived);
  Future<Set<String>> getExistingRemoteMessageIds(String accountId);
  Future<int> deduplicateMessages();

  // Easy-to-clean: Sender Sweep
  Stream<List<SenderSummary>> watchSenderSummaries({String? accountId});
  Future<int> archiveAllFromSender(String senderEmail);
  Future<int> deleteAllFromSender(String senderEmail);
}
