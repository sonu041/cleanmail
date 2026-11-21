import 'package:cleanmail/core/services/google_auth_service.dart';
import 'package:cleanmail/data/local/database.dart';
import 'package:cleanmail/data/repositories/message_repository_impl.dart';
import 'package:cleanmail/domain/models/category.dart';
import 'package:cleanmail/domain/models/message.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGoogleAuthService extends GoogleAuthService {
  final List<String> trashedRemoteIds = [];
  final List<String?> trashedAccountIds = [];
  final List<String> untrashedRemoteIds = [];
  final List<String?> untrashedAccountIds = [];
  final List<String> batchTrashedRemoteIds = [];
  final List<String?> batchTrashedAccountIds = [];
  final List<String> readMarkedRemoteIds = [];
  final List<String?> readMarkedAccountIds = [];
  final List<String> unreadMarkedRemoteIds = [];
  final List<String> archivedRemoteIds = [];
  final List<String?> archivedAccountIds = [];

  @override
  Future<bool> trashGmailMessage({required String remoteMessageId, String? accountId}) async {
    trashedRemoteIds.add(remoteMessageId);
    trashedAccountIds.add(accountId);
    return true;
  }

  @override
  Future<bool> untrashGmailMessage({required String remoteMessageId, String? accountId}) async {
    untrashedRemoteIds.add(remoteMessageId);
    untrashedAccountIds.add(accountId);
    return true;
  }

  @override
  Future<int> batchTrashGmailMessages({required List<String> remoteMessageIds, String? accountId}) async {
    batchTrashedRemoteIds.addAll(remoteMessageIds);
    batchTrashedAccountIds.add(accountId);
    return remoteMessageIds.length;
  }

  @override
  Future<bool> markGmailMessageRead({required String remoteMessageId, required bool isRead, String? accountId}) async {
    if (isRead) {
      readMarkedRemoteIds.add(remoteMessageId);
      readMarkedAccountIds.add(accountId);
    } else {
      unreadMarkedRemoteIds.add(remoteMessageId);
    }
    return true;
  }

  @override
  Future<bool> archiveGmailMessage({required String remoteMessageId, required bool isArchived, String? accountId}) async {
    if (isArchived) {
      archivedRemoteIds.add(remoteMessageId);
      archivedAccountIds.add(accountId);
    }
    return true;
  }
}

void main() {
  late AppDatabase db;
  late FakeGoogleAuthService fakeGoogleAuth;
  late MessageRepositoryImpl messageRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    fakeGoogleAuth = FakeGoogleAuthService();
    messageRepo = MessageRepositoryImpl(db, fakeGoogleAuth);
  });

  tearDown(() async {
    await db.close();
  });

  final testMessage1 = MailMessage(
    id: 'local_1',
    accountId: 'google_user1',
    remoteMessageId: 'remote_gmail_101',
    senderEmail: 'promo@newsletter.com',
    senderName: 'Newsletter Promo',
    subject: '50% off everything',
    snippet: 'Don not miss out',
    plainTextBody: '50% off everything today only',
    category: MailCategory.newsletters,
    isRead: false,
    receivedAt: DateTime(2026, 11, 20, 10, 0),
  );

  final testMessage2 = MailMessage(
    id: 'local_2',
    accountId: 'google_user1',
    remoteMessageId: 'remote_gmail_102',
    senderEmail: 'promo@newsletter.com',
    senderName: 'Newsletter Promo',
    subject: 'Last chance for discount',
    snippet: 'Sale ends tonight',
    plainTextBody: 'Sale ends tonight at midnight',
    category: MailCategory.newsletters,
    isRead: false,
    receivedAt: DateTime(2026, 11, 20, 15, 0),
  );

  final testMessage3 = MailMessage(
    id: 'local_3',
    accountId: 'google_user1',
    remoteMessageId: 'remote_gmail_103',
    senderEmail: 'alice@work.com',
    senderName: 'Alice Work',
    subject: 'Meeting notes',
    snippet: 'Here are the notes',
    plainTextBody: 'Meeting went well today',
    category: MailCategory.personal,
    isRead: false,
    receivedAt: DateTime(2026, 11, 20, 16, 0),
  );

  test('Local DB remoteId operations: delete, mark read, archive', () async {
    await messageRepo.saveMessages([testMessage1, testMessage2, testMessage3]);

    final inboxBefore = await db.watchInboxMessages().first;
    expect(inboxBefore.length, equals(3));

    // Delete by remote ID (delta sync from Gmail)
    final deletedCount = await messageRepo.deleteMessagesByRemoteIds(['remote_gmail_101']);
    expect(deletedCount, equals(1));

    final inboxAfterDelete = await db.watchInboxMessages().first;
    expect(inboxAfterDelete.length, equals(2));
    expect(inboxAfterDelete.any((m) => m.remoteMessageId == 'remote_gmail_101'), isFalse);

    // Mark read by remote ID
    await messageRepo.markMessageReadByRemoteId('remote_gmail_102', true);
    final readMsg = await db.getMessageByRemoteId('remote_gmail_102');
    expect(readMsg?.isRead, isTrue);

    // Archive by remote ID
    await messageRepo.archiveMessageByRemoteId('remote_gmail_103', true);
    final archivedMsg = await db.getMessageByRemoteId('remote_gmail_103');
    expect(archivedMsg?.isArchived, isTrue);
  });

  test('Two-way delete: deleting locally sends remote trash command to Gmail', () async {
    await messageRepo.saveMessages([testMessage1]);

    // Perform local delete
    await messageRepo.delete('local_1');

    // Message should be gone locally
    final found = await messageRepo.getMessage('local_1');
    expect(found, isNull);

    // Remote trash should have been triggered
    expect(fakeGoogleAuth.trashedRemoteIds, contains('remote_gmail_101'));
  });

  test('Two-way restore: restoring locally sends untrash command to Gmail', () async {
    await messageRepo.saveMessages([testMessage1]);
    await messageRepo.delete('local_1');

    // Restore via Undo action
    await messageRepo.restoreMessage(testMessage1);

    // Message should be present locally again
    final found = await messageRepo.getMessage('local_1');
    expect(found, isNotNull);
    expect(found?.remoteMessageId, equals('remote_gmail_101'));

    // Remote untrash should have been triggered
    expect(fakeGoogleAuth.untrashedRemoteIds, contains('remote_gmail_101'));
  });

  test('Two-way bulk delete: Sender Sweep deletes all locally and batch-trashes in Gmail', () async {
    await messageRepo.saveMessages([testMessage1, testMessage2, testMessage3]);

    // Bulk delete all messages from promo@newsletter.com
    final count = await messageRepo.deleteAllFromSender('promo@newsletter.com');
    expect(count, equals(2));

    // Verify local DB
    final remaining = await db.watchInboxMessages().first;
    expect(remaining.length, equals(1));
    expect(remaining.first.senderEmail, equals('alice@work.com'));

    // Verify Gmail remote batch trash received both remote IDs
    expect(fakeGoogleAuth.batchTrashedRemoteIds, containsAll(['remote_gmail_101', 'remote_gmail_102']));
    expect(fakeGoogleAuth.batchTrashedRemoteIds, isNot(contains('remote_gmail_103')));
  });

  test('Two-way read sync: markRead locally triggers Gmail label update', () async {
    await messageRepo.saveMessages([testMessage1]);

    // Mark as read in CleanMail (e.g. user tapped email to read)
    await messageRepo.markRead('local_1', true);

    // Verify local DB
    final readMsg = await db.getMessageById('local_1');
    expect(readMsg?.isRead, isTrue);

    // Verify Gmail remote modify received removal of UNREAD label
    expect(fakeGoogleAuth.readMarkedRemoteIds, contains('remote_gmail_101'));
  });

  test('Two-way archive sync: archive locally triggers Gmail INBOX label removal', () async {
    await messageRepo.saveMessages([testMessage1]);

    // Archive in CleanMail (e.g. swipe right)
    await messageRepo.archive('local_1', true);

    // Verify local DB
    final archivedMsg = await db.getMessageById('local_1');
    expect(archivedMsg?.isArchived, isTrue);

    // Verify Gmail remote modify received removal of INBOX label
    expect(fakeGoogleAuth.archivedRemoteIds, contains('remote_gmail_101'));
  });

  test('Deduplication: re-importing identical message updates rather than creating duplicate', () async {
    // 1. First import
    await messageRepo.saveMessages([testMessage1]);
    var inbox = await db.watchInboxMessages().first;
    expect(inbox.length, equals(1));

    // 2. Second import of same message with updated subject
    final updatedMessage1 = testMessage1.copyWith(subject: 'Updated subject without duplicate');
    await messageRepo.saveMessages([updatedMessage1]);

    inbox = await db.watchInboxMessages().first;
    expect(inbox.length, equals(1)); // Still exactly 1 message
    expect(inbox.first.subject, equals('Updated subject without duplicate'));

    // 3. Verify getExistingRemoteMessageIds
    final existingIds = await messageRepo.getExistingRemoteMessageIds('google_user1');
    expect(existingIds, contains('remote_gmail_101'));
  });

  test('Deduplication: deduplicateMessages removes any legacy duplicate rows', () async {
    // Insert two entries with different primary keys but identical accountId & remoteMessageId
    final dup1 = testMessage1.copyWith(id: 'legacy_uuid_1');
    final dup2 = testMessage1.copyWith(id: 'legacy_uuid_2');
    await messageRepo.saveMessages([dup1, dup2]);

    var allMessages = await db.watchInboxMessages().first;
    expect(allMessages.length, equals(2)); // Duplicates exist

    // Run deduplication
    final deletedDuplicates = await messageRepo.deduplicateMessages();
    expect(deletedDuplicates, equals(1));

    allMessages = await db.watchInboxMessages().first;
    expect(allMessages.length, equals(1)); // Duplicates successfully removed
  });

  test('Deduplication: removes cross-account duplicate emails with identical remoteMessageId', () async {
    // Simulate a message accidentally synced into multiple mailboxes (cross join)
    final acc1Msg = testMessage1.copyWith(id: 'acc1_dup_msg', accountId: 'google_account_1');
    final acc2Dup = testMessage1.copyWith(id: 'acc2_dup_msg', accountId: 'google_account_2');
    final acc3Dup = testMessage1.copyWith(id: 'acc3_dup_msg', accountId: 'google_account_3');

    await messageRepo.saveMessages([acc1Msg, acc2Dup, acc3Dup]);

    var allMessages = await db.watchInboxMessages().first;
    expect(allMessages.length, equals(3)); // 3 cross-joined duplicate rows

    // Run deduplication
    final deleted = await messageRepo.deduplicateMessages();
    expect(deleted, equals(2)); // Purged 2 cross-joined duplicates

    allMessages = await db.watchInboxMessages().first;
    expect(allMessages.length, equals(1)); // Only single clean copy remains
    expect(allMessages.first.remoteMessageId, equals(testMessage1.remoteMessageId));
  });

  test('Multi-account: two-way operations dispatch to correct accountId', () async {
    final account1Msg = MailMessage(
      id: 'acc1_msg1',
      accountId: 'google_account_1',
      remoteMessageId: 'remote_101',
      senderEmail: 'colleague@work.com',
      senderName: 'Colleague',
      subject: 'Work Task',
      snippet: 'Task info',
      plainTextBody: 'Task info',
      category: MailCategory.personal,
      isRead: false,
      receivedAt: DateTime(2026, 11, 20, 10, 0),
    );

    final account2Msg = MailMessage(
      id: 'acc2_msg2',
      accountId: 'google_account_2',
      remoteMessageId: 'remote_202',
      senderEmail: 'promo@personal.com',
      senderName: 'Promo',
      subject: 'Personal Sale',
      snippet: 'Sale info',
      plainTextBody: 'Sale info',
      category: MailCategory.newsletters,
      isRead: false,
      receivedAt: DateTime(2026, 11, 20, 11, 0),
    );

    await messageRepo.saveMessages([account1Msg, account2Msg]);

    // Archive message in Account 1
    await messageRepo.archive('acc1_msg1', true);
    expect(fakeGoogleAuth.archivedRemoteIds, contains('remote_101'));
    expect(fakeGoogleAuth.archivedAccountIds, contains('google_account_1'));

    // Mark read message in Account 2
    await messageRepo.markRead('acc2_msg2', true);
    expect(fakeGoogleAuth.readMarkedRemoteIds, contains('remote_202'));
    expect(fakeGoogleAuth.readMarkedAccountIds, contains('google_account_2'));

    // Delete message in Account 1
    await messageRepo.delete('acc1_msg1');
    expect(fakeGoogleAuth.trashedRemoteIds, contains('remote_101'));
    expect(fakeGoogleAuth.trashedAccountIds, contains('google_account_1'));

    // Restore message in Account 2
    await messageRepo.restoreMessage(account2Msg);
    expect(fakeGoogleAuth.untrashedRemoteIds, contains('remote_202'));
    expect(fakeGoogleAuth.untrashedAccountIds, contains('google_account_2'));
  });

  test('Multi-account: bulk sweep operations group and dispatch per accountId', () async {
    final senderMsgAcc1 = MailMessage(
      id: 'acc1_sender1',
      accountId: 'google_account_1',
      remoteMessageId: 'remote_s1',
      senderEmail: 'shared@service.com',
      senderName: 'Shared Service',
      subject: 'Bill 1',
      snippet: 'Bill info',
      plainTextBody: 'Bill info',
      category: MailCategory.updates,
      isRead: false,
      receivedAt: DateTime(2026, 11, 20, 10, 0),
    );

    final senderMsgAcc2 = MailMessage(
      id: 'acc2_sender2',
      accountId: 'google_account_2',
      remoteMessageId: 'remote_s2',
      senderEmail: 'shared@service.com',
      senderName: 'Shared Service',
      subject: 'Bill 2',
      snippet: 'Bill info 2',
      plainTextBody: 'Bill info 2',
      category: MailCategory.updates,
      isRead: false,
      receivedAt: DateTime(2026, 11, 20, 11, 0),
    );

    await messageRepo.saveMessages([senderMsgAcc1, senderMsgAcc2]);

    // Bulk delete from shared sender across both mailboxes
    await messageRepo.deleteAllFromSender('shared@service.com');

    // Both messages should be bulk trashed
    expect(fakeGoogleAuth.batchTrashedRemoteIds, containsAll(['remote_s1', 'remote_s2']));
    // And each was dispatched with its specific accountId
    expect(fakeGoogleAuth.batchTrashedAccountIds, containsAll(['google_account_1', 'google_account_2']));
  });
}
