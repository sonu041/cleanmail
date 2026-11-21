import 'package:drift/drift.dart';
import '../../core/services/google_auth_service.dart';
import '../../core/services/log_service.dart';
import '../../domain/models/category.dart';
import '../../domain/models/message.dart';
import '../../domain/models/sender_summary.dart';
import '../../domain/repositories/message_repository.dart';
import '../local/database.dart';

class MessageRepositoryImpl implements MessageRepository {
  final AppDatabase _db;
  final GoogleAuthService _googleAuth;

  MessageRepositoryImpl(this._db, [GoogleAuthService? googleAuth])
      : _googleAuth = googleAuth ?? GoogleAuthService();

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
  Stream<Map<String, int>> watchMessageCountsByAccount() {
    return _db.watchMessageCountsByAccount();
  }

  @override
  Stream<Map<String, int>> watchMessageCountsByCategory({String? accountId}) {
    return _db.watchMessageCountsByCategory(accountId: accountId);
  }

  @override
  Stream<int> watchUnreadCount({String? accountId, String? category}) {
    return _db.watchUnreadCount(accountId: accountId, category: category);
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
    final entry = await _db.getMessageById(messageId);
    await _db.markMessageRead(messageId, isRead);
    AppLogger.info(
      'Message Status',
      'Marked "${entry?.subject ?? messageId}" as ${isRead ? "Read" : "Unread"}',
      category: LogCategory.triage,
    );

    // Two-way read sync: update read status in real Gmail
    if (entry != null && entry.remoteMessageId.isNotEmpty) {
      _googleAuth.markGmailMessageRead(
        remoteMessageId: entry.remoteMessageId,
        isRead: isRead,
        accountId: entry.accountId,
      ).ignore();
    }
  }

  @override
  Future<void> archive(String messageId, bool isArchived) async {
    final entry = await _db.getMessageById(messageId);
    await _db.archiveMessage(messageId, isArchived);
    AppLogger.info(
      'Message Archive',
      '${isArchived ? "Archived" : "Unarchived"} "${entry?.subject ?? messageId}"',
      category: LogCategory.triage,
    );

    // Two-way archive sync: update INBOX label in real Gmail
    if (entry != null && entry.remoteMessageId.isNotEmpty) {
      _googleAuth.archiveGmailMessage(
        remoteMessageId: entry.remoteMessageId,
        isArchived: isArchived,
        accountId: entry.accountId,
      ).ignore();
    }
  }

  @override
  Future<void> delete(String messageId) async {
    final entry = await _db.getMessageById(messageId);
    await _db.deleteMessage(messageId);
    AppLogger.info(
      'Message Trashed',
      'Deleted "${entry?.subject ?? messageId}" from local DB',
      category: LogCategory.triage,
    );

    // Two-way delete sync: if message came from Gmail, move it to Trash in Gmail
    if (entry != null && entry.remoteMessageId.isNotEmpty) {
      _googleAuth.trashGmailMessage(
        remoteMessageId: entry.remoteMessageId,
        accountId: entry.accountId,
      ).ignore();
    }
  }

  @override
  Future<List<MailMessage>> deleteMultiple(List<String> messageIds) async {
    if (messageIds.isEmpty) return [];

    final entries = await _db.getMessagesByIds(messageIds);
    final deletedMessages = entries.map(_mapToDomain).toList();
    final byAccount = <String, List<String>>{};

    for (final entry in entries) {
      if (entry.remoteMessageId.isNotEmpty) {
        byAccount.putIfAbsent(entry.accountId, () => []).add(entry.remoteMessageId);
      }
    }

    await _db.deleteMessages(messageIds);

    AppLogger.success(
      'Batch Delete',
      'Deleted ${deletedMessages.length} emails across ${byAccount.length} mailboxes',
      category: LogCategory.triage,
      metadata: {'count': deletedMessages.length},
    );

    // Two-way delete sync: move messages to Trash in Gmail
    for (final entry in byAccount.entries) {
      for (final remoteId in entry.value) {
        _googleAuth.trashGmailMessage(
          remoteMessageId: remoteId,
          accountId: entry.key,
        ).ignore();
      }
    }

    return deletedMessages;
  }

  @override
  Future<void> restoreMessage(MailMessage message) async {
    await saveMessages([message]);
    AppLogger.info(
      'Message Restored',
      'Restored "${message.subject}" from Trash',
      category: LogCategory.triage,
    );
    // Two-way restore sync: restore message in Gmail Trash
    if (message.remoteMessageId.isNotEmpty) {
      _googleAuth.untrashGmailMessage(
        remoteMessageId: message.remoteMessageId,
        accountId: message.accountId,
      ).ignore();
    }
  }

  @override
  Future<void> restoreMessages(List<MailMessage> messages) async {
    if (messages.isEmpty) return;
    await saveMessages(messages);
    AppLogger.info(
      'Messages Restored',
      'Restored ${messages.length} emails from Trash',
      category: LogCategory.triage,
    );
    for (final message in messages) {
      if (message.remoteMessageId.isNotEmpty) {
        _googleAuth.untrashGmailMessage(
          remoteMessageId: message.remoteMessageId,
          accountId: message.accountId,
        ).ignore();
      }
    }
  }

  // ----------------------------------------------------
  // DELTA HISTORY & REMOTE SYNC OPERATIONS
  // ----------------------------------------------------

  @override
  Future<int> deleteMessagesByRemoteIds(List<String> remoteIds) {
    return _db.deleteMessagesByRemoteIds(remoteIds);
  }

  @override
  Future<void> markMessageReadByRemoteId(String remoteId, bool isRead) async {
    await _db.markMessageReadByRemoteId(remoteId, isRead);
  }

  @override
  Future<void> archiveMessageByRemoteId(String remoteId, bool isArchived) async {
    await _db.archiveMessageByRemoteId(remoteId, isArchived);
  }

  @override
  Future<Set<String>> getExistingRemoteMessageIds(String accountId) {
    return _db.getExistingRemoteMessageIds(accountId);
  }

  @override
  Future<DateTime?> getOldestMessageTimestamp([String? accountId]) {
    return _db.getOldestMessageTimestamp(accountId);
  }

  @override
  Future<int> deduplicateMessages() {
    return _db.deduplicateMessages();
  }

  // ----------------------------------------------------
  // EASY-TO-CLEAN: SENDER SWEEP OPERATIONS
  // ----------------------------------------------------

  @override
  Stream<List<SenderSummary>> watchSenderSummaries({String? accountId}) {
    return _db.watchSenderSummaries(accountId: accountId);
  }

  @override
  Future<int> archiveAllFromSender(String senderEmail) async {
    final entries = await _db.getMessagesBySenderEmail(senderEmail);
    final byAccount = <String, List<String>>{};
    for (final e in entries) {
      if (!e.isArchived && e.remoteMessageId.isNotEmpty) {
        byAccount.putIfAbsent(e.accountId, () => []).add(e.remoteMessageId);
      }
    }

    final count = await _db.archiveAllFromSender(senderEmail);
    AppLogger.success(
      'Sender Sweep Archive',
      'Archived $count emails from $senderEmail across ${byAccount.length} mailboxes',
      category: LogCategory.triage,
      metadata: {'count': count, 'sender': senderEmail},
    );

    for (final entry in byAccount.entries) {
      for (final remoteId in entry.value) {
        _googleAuth.archiveGmailMessage(
          remoteMessageId: remoteId,
          isArchived: true,
          accountId: entry.key,
        ).ignore();
      }
    }

    return count;
  }

  @override
  Future<int> deleteAllFromSender(String senderEmail) async {
    // 1. Collect all remote IDs from this sender grouped by accountId
    final entries = await _db.getMessagesBySenderEmail(senderEmail);
    final byAccount = <String, List<String>>{};
    for (final e in entries) {
      if (e.remoteMessageId.isNotEmpty) {
        byAccount.putIfAbsent(e.accountId, () => []).add(e.remoteMessageId);
      }
    }

    // 2. Delete locally from SQLite
    final count = await _db.deleteAllFromSender(senderEmail);
    AppLogger.success(
      'Sender Sweep Delete',
      'Purged $count emails from $senderEmail across ${byAccount.length} mailboxes',
      category: LogCategory.triage,
      metadata: {'count': count, 'sender': senderEmail},
    );

    // 3. Two-way bulk delete: trash remote messages in Gmail for each account
    for (final entry in byAccount.entries) {
      _googleAuth.batchTrashGmailMessages(
        remoteMessageIds: entry.value,
        accountId: entry.key,
      ).ignore();
    }

    return count;
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
