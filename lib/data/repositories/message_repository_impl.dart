import 'package:drift/drift.dart';
import '../../domain/models/category.dart';
import '../../domain/models/message.dart';
import '../../domain/models/sender_summary.dart';
import '../../domain/repositories/message_repository.dart';
import '../local/database.dart';

class MessageRepositoryImpl implements MessageRepository {
  final AppDatabase _db;

  MessageRepositoryImpl(this._db);

  @override
  Stream<List<MailMessage>> watchInbox({
    String? accountId,
    MailCategory? category,
  }) {
    final categoryString = (category == null || category == MailCategory.all)
        ? null
        : category.name;

    return _db
        .watchInboxMessages(
          accountId: accountId,
          category: categoryString,
        )
        .map((entries) => entries.map(_mapToDomain).toList());
  }

  @override
  Future<MailMessage?> getMessage(String id) async {
    final entry = await _db.getMessageById(id);
    return entry != null ? _mapToDomain(entry) : null;
  }

  @override
  Future<void> saveMessages(List<MailMessage> messages) async {
    final companions = messages.map((m) {
      return MessagesTableCompanion(
        id: Value(m.id),
        accountId: Value(m.accountId),
        remoteMessageId: Value(m.remoteMessageId),
        threadId: Value(m.threadId),
        senderEmail: Value(m.senderEmail),
        senderName: Value(m.senderName),
        subject: Value(m.subject),
        snippet: Value(m.snippet),
        plainTextBody: Value(m.plainTextBody),
        category: Value(m.category.name),
        unsubscribeUrl: Value(m.unsubscribeUrl),
        unsubscribeMailto: Value(m.unsubscribeMailto),
        isRead: Value(m.isRead),
        isArchived: Value(m.isArchived),
        isStarred: Value(m.isStarred),
        receivedAt: Value(m.receivedAt),
      );
    }).toList();

    await _db.insertOrUpdateMessages(companions);
  }

  @override
  Future<void> markRead(String messageId, bool isRead) async {
    await _db.markMessageRead(messageId, isRead);
  }

  @override
  Future<void> archive(String messageId, bool isArchived) async {
    await _db.archiveMessage(messageId, isArchived);
  }

  @override
  Future<void> delete(String messageId) async {
    await _db.deleteMessage(messageId);
  }

  @override
  Stream<List<SenderSummary>> watchSenderSummaries({String? accountId}) {
    return _db.watchSenderSummaries(accountId: accountId);
  }

  @override
  Future<int> archiveAllFromSender(String senderEmail) {
    return _db.archiveAllFromSender(senderEmail);
  }

  @override
  Future<int> deleteAllFromSender(String senderEmail) {
    return _db.deleteAllFromSender(senderEmail);
  }

  MailMessage _mapToDomain(MessageEntry entry) {
    return MailMessage(
      id: entry.id,
      accountId: entry.accountId,
      remoteMessageId: entry.remoteMessageId,
      threadId: entry.threadId,
      senderEmail: entry.senderEmail,
      senderName: entry.senderName,
      subject: entry.subject,
      snippet: entry.snippet,
      plainTextBody: entry.plainTextBody,
      category: MailCategory.fromString(entry.category),
      unsubscribeUrl: entry.unsubscribeUrl,
      unsubscribeMailto: entry.unsubscribeMailto,
      isRead: entry.isRead,
      isArchived: entry.isArchived,
      isStarred: entry.isStarred,
      receivedAt: entry.receivedAt,
    );
  }
}
