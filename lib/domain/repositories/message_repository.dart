import '../models/message.dart';
import '../models/category.dart';
import '../models/sender_rule.dart';
import '../models/sender_summary.dart';

abstract class MessageRepository {
  Stream<List<MailMessage>> watchInbox({
    String? accountId,
    MailCategory? category,
  });

  Stream<Map<String, int>> watchMessageCountsByAccount();
  Stream<Map<String, int>> watchMessageCountsByCategory({String? accountId});
  Stream<int> watchUnreadCount({String? accountId, String? category});
  Stream<int> watchStarredCount({String? accountId, String? category});

  Future<MailMessage?> getMessage(String id);
  Future<void> saveMessages(List<MailMessage> messages);
  Future<void> markRead(String messageId, bool isRead);
  Future<void> archive(String messageId, bool isArchived);
  Future<void> setLocked(String messageId, bool isLocked);
  Future<void> setStarred(String messageId, bool isStarred);
  Future<void> delete(String messageId);
  Future<List<MailMessage>> deleteMultiple(List<String> messageIds);
  Future<void> restoreMessage(MailMessage message);
  Future<void> restoreMessages(List<MailMessage> messages);

  // Delta History & Remote Sync operations
  Future<int> deleteMessagesByRemoteIds(List<String> remoteIds);
  Future<void> markMessageReadByRemoteId(String remoteId, bool isRead);
  Future<void> archiveMessageByRemoteId(String remoteId, bool isArchived);
  Future<void> markMessageStarredByRemoteId(String remoteId, bool isStarred);
  Future<Set<String>> getExistingRemoteMessageIds(String accountId);
  Future<DateTime?> getOldestMessageTimestamp([String? accountId]);
  Future<int> deduplicateMessages();

  // Easy-to-clean: Sender Sweep
  Stream<List<SenderSummary>> watchSenderSummaries({String? accountId});
  Stream<List<MailMessage>> watchMessagesBySender(String senderEmail);
  Future<int> archiveAllFromSender(String senderEmail);
  Future<int> deleteAllFromSender(String senderEmail);

  // Preferred Tags & Sender Rules
  Future<void> setSenderRule(SenderRule rule, {bool applyToExisting = true});
  Future<SenderRule?> getSenderRule(String senderEmail);
  Stream<List<SenderRule>> watchSenderRules();
  Future<void> deleteSenderRule(String senderEmail);
}
