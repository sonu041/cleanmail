import 'package:cleanmail/core/services/google_auth_service.dart';
import 'package:cleanmail/data/local/database.dart';
import 'package:cleanmail/data/repositories/account_repository_impl.dart';
import 'package:cleanmail/data/repositories/message_repository_impl.dart';
import 'package:cleanmail/domain/models/account.dart';
import 'package:cleanmail/domain/models/category.dart';
import 'package:cleanmail/domain/models/message.dart';
import 'package:cleanmail/domain/models/sender_rule.dart';
import 'package:cleanmail/domain/repositories/message_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  final List<String> starredRemoteIds = [];
  final List<String> unstarredRemoteIds = [];
  bool failBatchTrash = false;
  List<String> Function(List<String> inputIds)? batchTrashFilter;

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
  Future<int> batchTrashGmailMessages({
    required List<String> remoteMessageIds,
    String? accountId,
    void Function(int current, int total)? onProgress,
    Future<void> Function(List<String> successfulRemoteIds)? onChunkSuccess,
  }) async {
    if (failBatchTrash) {
      onProgress?.call(0, remoteMessageIds.length);
      return 0;
    }
    final effectiveIds = batchTrashFilter != null
        ? batchTrashFilter!(remoteMessageIds)
        : remoteMessageIds;

    batchTrashedRemoteIds.addAll(effectiveIds);
    batchTrashedAccountIds.add(accountId);
    if (effectiveIds.isNotEmpty) {
      await onChunkSuccess?.call(effectiveIds);
    }
    onProgress?.call(effectiveIds.length, remoteMessageIds.length);
    return effectiveIds.length;
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

  @override
  Future<bool> starGmailMessage({required String remoteMessageId, required bool isStarred, String? accountId}) async {
    if (isStarred) {
      starredRemoteIds.add(remoteMessageId);
    } else {
      unstarredRemoteIds.add(remoteMessageId);
    }
    return true;
  }
}

class SmartSyncFakeGoogleAuthService extends GoogleAuthService {
  int resyncCallCount = 0;
  int syncOlderCallCount = 0;
  int syncOlderRequestedCount = 0;
  int resyncReturnCount = 0;
  int olderReturnCount = 100;
  int profileMessagesTotal = 500;

  @override
  Future<Map<String, String>?> getAuthHeadersForAccount([String? accountId]) async {
    return {'Authorization': 'Bearer fake_token'};
  }

  @override
  Future<({String? historyId, int? messagesTotal})> fetchCurrentProfile({
    required Map<String, String> authHeaders,
  }) async {
    return (historyId: 'fake_hist_1', messagesTotal: profileMessagesTotal);
  }

  @override
  Future<({int syncedCount, String? error})> resyncAccount({
    required MailAccount account,
    required MessageRepository messageRepo,
  }) async {
    resyncCallCount++;
    return (syncedCount: resyncReturnCount, error: null);
  }

  @override
  Future<({int syncedCount, bool hasMore, String? error})> syncOlderGmailMessages({
    required MailAccount account,
    required MessageRepository messageRepo,
    int count = 20,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    syncOlderCallCount++;
    syncOlderRequestedCount = count;
    onProgress?.call(olderReturnCount, count, 'Syncing older emails: $olderReturnCount of $count...');
    return (syncedCount: olderReturnCount, hasMore: true, error: null);
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

  test('getOldestMessageTimestamp returns oldest message receivedAt timestamp', () async {
    final t1 = DateTime(2026, 11, 15, 10, 0);
    final t2 = DateTime(2026, 11, 18, 14, 0);
    final t3 = DateTime(2026, 11, 20, 8, 0);

    // Empty DB returns null
    final emptyOldest = await messageRepo.getOldestMessageTimestamp();
    expect(emptyOldest, isNull);

    final msg1 = MailMessage(
      id: 'acc1_m1',
      accountId: 'account_1',
      remoteMessageId: 'rem_1',
      senderEmail: 'test1@mail.com',
      senderName: 'Test 1',
      subject: 'Oldest Msg 1',
      snippet: 'Snippet 1',
      plainTextBody: 'Body 1',
      category: MailCategory.personal,
      isRead: true,
      receivedAt: t1,
    );

    final msg2 = MailMessage(
      id: 'acc1_m2',
      accountId: 'account_1',
      remoteMessageId: 'rem_2',
      senderEmail: 'test2@mail.com',
      senderName: 'Test 2',
      subject: 'Newer Msg 2',
      snippet: 'Snippet 2',
      plainTextBody: 'Body 2',
      category: MailCategory.personal,
      isRead: false,
      receivedAt: t2,
    );

    final msgAcc2 = MailMessage(
      id: 'acc2_m3',
      accountId: 'account_2',
      remoteMessageId: 'rem_3',
      senderEmail: 'test3@mail.com',
      senderName: 'Test 3',
      subject: 'Account 2 Msg 3',
      snippet: 'Snippet 3',
      plainTextBody: 'Body 3',
      category: MailCategory.personal,
      isRead: false,
      receivedAt: t3,
    );

    await messageRepo.saveMessages([msg1, msg2, msgAcc2]);

    // Global oldest
    final globalOldest = await messageRepo.getOldestMessageTimestamp();
    expect(globalOldest, equals(t1));

    // Account 1 oldest
    final acc1Oldest = await messageRepo.getOldestMessageTimestamp('account_1');
    expect(acc1Oldest, equals(t1));

    // Account 2 oldest
    final acc2Oldest = await messageRepo.getOldestMessageTimestamp('account_2');
    expect(acc2Oldest, equals(t3));
  });

  test('watchMessageCountsByAccount and watchMessageCountsByCategory emit accurate active counts', () async {
    final msg1 = MailMessage(
      id: 'cnt_acc1_m1',
      accountId: 'account_1',
      remoteMessageId: 'rem_c1',
      senderEmail: 'test1@mail.com',
      senderName: 'Test 1',
      subject: 'Msg 1',
      snippet: 'Snippet 1',
      plainTextBody: 'Body 1',
      category: MailCategory.personal,
      isRead: true,
      receivedAt: DateTime.now(),
    );

    final msg2 = MailMessage(
      id: 'cnt_acc1_m2',
      accountId: 'account_1',
      remoteMessageId: 'rem_c2',
      senderEmail: 'test2@mail.com',
      senderName: 'Test 2',
      subject: 'Msg 2',
      snippet: 'Snippet 2',
      plainTextBody: 'Body 2',
      category: MailCategory.personal,
      isRead: false,
      receivedAt: DateTime.now(),
    );

    final msgAcc2 = MailMessage(
      id: 'cnt_acc2_m3',
      accountId: 'account_2',
      remoteMessageId: 'rem_c3',
      senderEmail: 'test3@mail.com',
      senderName: 'Test 3',
      subject: 'Msg 3',
      snippet: 'Snippet 3',
      plainTextBody: 'Body 3',
      category: MailCategory.personal,
      isRead: false,
      receivedAt: DateTime.now(),
    );

    await messageRepo.saveMessages([msg1, msg2, msgAcc2]);

    final accCounts = await messageRepo.watchMessageCountsByAccount().first;
    expect(accCounts['account_1'], equals(2));
    expect(accCounts['account_2'], equals(1));

    final catCounts = await messageRepo.watchMessageCountsByCategory().first;
    expect(catCounts['personal'], equals(3));

    // When an email is archived, active count decreases
    await messageRepo.archive('cnt_acc1_m1', true);

    final updatedAccCounts = await messageRepo.watchMessageCountsByAccount().first;
    expect(updatedAccCounts['account_1'], equals(1));
    expect(updatedAccCounts['account_2'], equals(1));

    final updatedCatCounts = await messageRepo.watchMessageCountsByCategory().first;
    expect(updatedCatCounts['personal'], equals(2));
  });

  test('watchUnreadCount accurately tracks unread emails and updates on read status changes', () async {
    final unreadMsg1 = MailMessage(
      id: 'unr_1',
      accountId: 'account_1',
      remoteMessageId: 'rem_unr1',
      senderEmail: 'dev1@cleanmail.com',
      senderName: 'Dev 1',
      subject: 'Unread 1',
      snippet: 'Unread snippet 1',
      plainTextBody: 'Unread body 1',
      category: MailCategory.personal,
      isRead: false,
      receivedAt: DateTime.now(),
    );

    final unreadMsg2 = MailMessage(
      id: 'unr_2',
      accountId: 'account_1',
      remoteMessageId: 'rem_unr2',
      senderEmail: 'dev2@cleanmail.com',
      senderName: 'Dev 2',
      subject: 'Unread 2',
      snippet: 'Unread snippet 2',
      plainTextBody: 'Unread body 2',
      category: MailCategory.newsletters,
      isRead: false,
      receivedAt: DateTime.now(),
    );

    final readMsg = MailMessage(
      id: 'rd_3',
      accountId: 'account_1',
      remoteMessageId: 'rem_rd3',
      senderEmail: 'dev3@cleanmail.com',
      senderName: 'Dev 3',
      subject: 'Read 3',
      snippet: 'Read snippet 3',
      plainTextBody: 'Read body 3',
      category: MailCategory.personal,
      isRead: true,
      receivedAt: DateTime.now(),
    );

    await messageRepo.saveMessages([unreadMsg1, unreadMsg2, readMsg]);

    // Overall unread count is 2
    final totalUnread = await messageRepo.watchUnreadCount().first;
    expect(totalUnread, equals(2));

    // Category specific unread count
    final personalUnread = await messageRepo.watchUnreadCount(category: 'personal').first;
    expect(personalUnread, equals(1));
    final newsletterUnread = await messageRepo.watchUnreadCount(category: 'newsletters').first;
    expect(newsletterUnread, equals(1));

    // Marking message as read reactively decrements unread count
    await messageRepo.markRead('unr_1', true);
    final updatedUnread = await messageRepo.watchUnreadCount().first;
    expect(updatedUnread, equals(1));
  });

  test('Page token storage persists, retrieves, and clears token per account', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    final authService = GoogleAuthService();
    const testAccount = 'acc_page_token_test';

    await authService.saveStoredPageToken(testAccount, 'token_xyz_123');
    final retrieved = await authService.getStoredPageToken(testAccount);
    expect(retrieved, equals('token_xyz_123'));

    await authService.clearStoredPageToken(testAccount);
    final cleared = await authService.getStoredPageToken(testAccount);
    expect(cleared, isNull);
  });

  test('Two-way multiselect batch delete and restore', () async {
    await messageRepo.saveMessages([testMessage1, testMessage2]);

    final initialCount = (await db.getMessagesByIds([testMessage1.id, testMessage2.id])).length;
    expect(initialCount, equals(2));

    // Delete multiple selected messages
    final deleted = await messageRepo.deleteMultiple([testMessage1.id, testMessage2.id]);
    expect(deleted.length, equals(2));

    // Verify removed from local DB
    final afterDelete = await db.getMessagesByIds([testMessage1.id, testMessage2.id]);
    expect(afterDelete, isEmpty);

    // Verify remote trash commands dispatched
    expect(fakeGoogleAuth.trashedRemoteIds, containsAll(['remote_gmail_101', 'remote_gmail_102']));

    // Restore multiple messages
    await messageRepo.restoreMessages(deleted);

    // Verify restored in local DB
    final afterRestore = await db.getMessagesByIds([testMessage1.id, testMessage2.id]);
    expect(afterRestore.length, equals(2));

    // Verify remote untrash commands dispatched
    expect(fakeGoogleAuth.untrashedRemoteIds, containsAll(['remote_gmail_101', 'remote_gmail_102']));
  });

  test('watchSenderSummaries loads aggregated senders without SQL type errors', () async {
    final senderMsg1 = MailMessage(
      id: 'sweep_1',
      accountId: 'acc1',
      remoteMessageId: 'rem_sw1',
      senderEmail: 'promo@store.com',
      senderName: 'Promo Store',
      subject: 'Weekly Deals',
      snippet: 'Big savings',
      plainTextBody: 'Deals here',
      category: MailCategory.updates,
      isRead: false,
      receivedAt: DateTime(2026, 11, 20, 12, 0),
    );

    final senderMsg2 = MailMessage(
      id: 'sweep_2',
      accountId: 'acc1',
      remoteMessageId: 'rem_sw2',
      senderEmail: 'promo@store.com',
      senderName: 'Promo Store',
      subject: 'Final Hours',
      snippet: 'Ending soon',
      plainTextBody: 'Final hours here',
      category: MailCategory.updates,
      isRead: true,
      receivedAt: DateTime(2026, 11, 21, 8, 0),
    );

    await messageRepo.saveMessages([senderMsg1, senderMsg2]);

    final summaries = await messageRepo.watchSenderSummaries().first;
    expect(summaries.length, equals(1));
    final promoSummary = summaries.first;
    expect(promoSummary.senderEmail, equals('promo@store.com'));
    expect(promoSummary.senderName, equals('Promo Store'));
    expect(promoSummary.totalCount, equals(2));
    expect(promoSummary.unreadCount, equals(1));
    expect(promoSummary.latestSubject, equals('Final Hours'));
    expect(promoSummary.lastReceivedAt.isAfter(DateTime(2026, 11, 20)), isTrue);
  });

  test('watchMessagesBySender reactively streams active messages for a specific sender', () async {
    final senderMsg1 = MailMessage(
      id: 'sender_mail_1',
      accountId: 'acc1',
      remoteMessageId: 'rem_sm1',
      senderEmail: 'author@news.com',
      senderName: 'Author',
      subject: 'Newsletter #1',
      snippet: 'News 1',
      plainTextBody: 'Body 1',
      category: MailCategory.newsletters,
      isRead: false,
      receivedAt: DateTime(2026, 11, 20, 10, 0),
    );

    final senderMsg2 = MailMessage(
      id: 'sender_mail_2',
      accountId: 'acc1',
      remoteMessageId: 'rem_sm2',
      senderEmail: 'author@news.com',
      senderName: 'Author',
      subject: 'Newsletter #2',
      snippet: 'News 2',
      plainTextBody: 'Body 2',
      category: MailCategory.newsletters,
      isRead: true,
      receivedAt: DateTime(2026, 11, 21, 10, 0),
    );

    final otherMsg = MailMessage(
      id: 'sender_mail_3',
      accountId: 'acc1',
      remoteMessageId: 'rem_sm3',
      senderEmail: 'other@service.com',
      senderName: 'Other',
      subject: 'Service Alert',
      snippet: 'Alert',
      plainTextBody: 'Alert body',
      category: MailCategory.updates,
      isRead: false,
      receivedAt: DateTime(2026, 11, 21, 11, 0),
    );

    await messageRepo.saveMessages([senderMsg1, senderMsg2, otherMsg]);

    final authorMessages = await messageRepo.watchMessagesBySender('author@news.com').first;
    expect(authorMessages.length, equals(2));
    expect(authorMessages.first.subject, equals('Newsletter #2'));
    expect(authorMessages.last.subject, equals('Newsletter #1'));

    // Archive one message
    await messageRepo.archive('sender_mail_2', true);
    final remaining = await messageRepo.watchMessagesBySender('author@news.com').first;
    expect(remaining.length, equals(1));
    expect(remaining.first.id, equals('sender_mail_1'));
  });

  test('Email locking: setLocked toggles lock state and prevents single delete', () async {
    final lockedMessage = MailMessage(
      id: 'lock_test_1',
      accountId: 'account_1',
      remoteMessageId: 'rem_lock_1',
      senderEmail: 'bank@secure.com',
      senderName: 'Bank Alerts',
      subject: 'Important Statement',
      snippet: 'Your statement is ready',
      plainTextBody: 'Statement details',
      category: MailCategory.transactions,
      isRead: true,
      receivedAt: DateTime.now(),
      isLocked: false,
    );

    await messageRepo.saveMessages([lockedMessage]);

    // Lock the email
    await messageRepo.setLocked('lock_test_1', true);
    var fetched = await messageRepo.getMessage('lock_test_1');
    expect(fetched, isNotNull);
    expect(fetched!.isLocked, isTrue);

    // Attempt to delete locked email: must be prevented!
    await messageRepo.delete('lock_test_1');

    // Message must still exist in DB
    fetched = await messageRepo.getMessage('lock_test_1');
    expect(fetched, isNotNull);
    expect(fetched!.isLocked, isTrue);
    expect(fakeGoogleAuth.trashedRemoteIds, isNot(contains('rem_lock_1')));

    // Unlock the email
    await messageRepo.setLocked('lock_test_1', false);
    fetched = await messageRepo.getMessage('lock_test_1');
    expect(fetched!.isLocked, isFalse);

    // Now delete succeeds
    await messageRepo.delete('lock_test_1');
    fetched = await messageRepo.getMessage('lock_test_1');
    expect(fetched, isNull);
    expect(fakeGoogleAuth.trashedRemoteIds, contains('rem_lock_1'));
  });

  test('Email locking: deleteMultiple and deleteAllFromSender preserve locked emails', () async {
    final lockedMsg = MailMessage(
      id: 'locked_multi_1',
      accountId: 'account_1',
      remoteMessageId: 'rem_lm1',
      senderEmail: 'promo@shop.com',
      senderName: 'Shop',
      subject: 'Keep This Receipt',
      snippet: 'Receipt details',
      plainTextBody: 'Receipt',
      category: MailCategory.transactions,
      isRead: true,
      receivedAt: DateTime.now(),
      isLocked: true,
    );

    final unlockedMsg = MailMessage(
      id: 'unlocked_multi_2',
      accountId: 'account_1',
      remoteMessageId: 'rem_um2',
      senderEmail: 'promo@shop.com',
      senderName: 'Shop',
      subject: 'Spam Offer',
      snippet: 'Spam snippet',
      plainTextBody: 'Spam',
      category: MailCategory.updates,
      isRead: false,
      receivedAt: DateTime.now(),
      isLocked: false,
    );

    await messageRepo.saveMessages([lockedMsg, unlockedMsg]);

    // deleteMultiple: only unlocked message is deleted
    final deleted = await messageRepo.deleteMultiple(['locked_multi_1', 'unlocked_multi_2']);
    expect(deleted.map((m) => m.id), contains('unlocked_multi_2'));
    expect(deleted.map((m) => m.id), isNot(contains('locked_multi_1')));

    // lockedMsg still exists
    var fetchedLocked = await messageRepo.getMessage('locked_multi_1');
    expect(fetchedLocked, isNotNull);
    expect(fetchedLocked!.isLocked, isTrue);

    // Add another unlocked message from same sender
    final unlockedMsg2 = MailMessage(
      id: 'unlocked_multi_3',
      accountId: 'account_1',
      remoteMessageId: 'rem_um3',
      senderEmail: 'promo@shop.com',
      senderName: 'Shop',
      subject: 'Another Offer',
      snippet: 'Another offer',
      plainTextBody: 'Body',
      category: MailCategory.updates,
      isRead: false,
      receivedAt: DateTime.now(),
      isLocked: false,
    );
    await messageRepo.saveMessages([unlockedMsg2]);

    // deleteAllFromSender: deletes only unlocked, keeps locked!
    final sweepDeletedCount = await messageRepo.deleteAllFromSender('promo@shop.com');
    expect(sweepDeletedCount, equals(1)); // only unlockedMsg2 was deleted

    // lockedMsg is STILL preserved!
    fetchedLocked = await messageRepo.getMessage('locked_multi_1');
    expect(fetchedLocked, isNotNull);
    expect(fetchedLocked!.isLocked, isTrue);
  });

  test('Sender rules: setSenderRule updates existing emails and going forward automatically tags incoming emails', () async {
    // 1. Initial message classified as newsletters by default
    final initialMsg = MailMessage(
      id: 'rule_msg_1',
      accountId: 'account_1',
      remoteMessageId: 'rem_rule_1',
      senderEmail: 'boss@corp.com',
      senderName: 'The Boss',
      subject: 'Weekly Team Newsletter',
      snippet: 'Important team announcements',
      plainTextBody: 'Announcements here',
      category: MailCategory.newsletters, // misclassified
      isRead: false,
      receivedAt: DateTime.now(),
      isLocked: false,
    );
    await messageRepo.saveMessages([initialMsg]);

    var fetched1 = await messageRepo.getMessage('rule_msg_1');
    expect(fetched1!.category, equals(MailCategory.newsletters));
    expect(fetched1.customTag, isNull);
    expect(fetched1.isLocked, isFalse);

    // 2. Set preferred tag rule for 'boss@corp.com' to Personal, with custom tag 'VIP', and autoLock = true
    final rule = SenderRule(
      senderEmail: 'boss@corp.com',
      preferredCategory: MailCategory.personal,
      customTag: 'VIP',
      isAutoLocked: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await messageRepo.setSenderRule(rule, applyToExisting: true);

    // 3. Existing message was updated
    fetched1 = await messageRepo.getMessage('rule_msg_1');
    expect(fetched1!.category, equals(MailCategory.personal));
    expect(fetched1.customTag, equals('VIP'));
    expect(fetched1.isLocked, isTrue);

    // 4. Going forward: new email comes in from 'boss@corp.com' with default/heuristic category 'newsletters'
    final incomingMsg = MailMessage(
      id: 'rule_msg_2',
      accountId: 'account_1',
      remoteMessageId: 'rem_rule_2',
      senderEmail: 'boss@corp.com',
      senderName: 'The Boss',
      subject: 'Urgent Task',
      snippet: 'Please complete this today',
      plainTextBody: 'Task details',
      category: MailCategory.newsletters, // raw incoming category from heuristic
      isRead: false,
      receivedAt: DateTime.now(),
      isLocked: false,
    );
    await messageRepo.saveMessages([incomingMsg]);

    // Verify incoming email automatically received preferred category Personal, customTag 'VIP', and isLocked = true!
    final fetched2 = await messageRepo.getMessage('rule_msg_2');
    expect(fetched2!.category, equals(MailCategory.personal));
    expect(fetched2.customTag, equals('VIP'));
    expect(fetched2.isLocked, isTrue);

    // 5. Querying and removing rule
    final retrievedRule = await messageRepo.getSenderRule('boss@corp.com');
    expect(retrievedRule, isNotNull);
    expect(retrievedRule!.preferredCategory, equals(MailCategory.personal));
    expect(retrievedRule.customTag, equals('VIP'));
    expect(retrievedRule.isAutoLocked, isTrue);

    await messageRepo.deleteSenderRule('boss@corp.com');
    final afterDeleteRule = await messageRepo.getSenderRule('boss@corp.com');
    expect(afterDeleteRule, isNull);
  });

  test('Smart Sync: refresh first syncs latest emails, and if already synced, syncs a batch of 100 older emails', () async {
    final testDb = AppDatabase(NativeDatabase.memory());
    final testAccountRepo = AccountRepositoryImpl(testDb);
    final smartAuth = SmartSyncFakeGoogleAuthService();
    final testMessageRepo = MessageRepositoryImpl(testDb, smartAuth);

    const account = MailAccount(
      id: 'acc_smart_1',
      email: 'work@corp.com',
      displayName: 'Work Mailbox',
      provider: MailProvider.gmail,
      avatarColorValue: 0xFF1E88E5,
      totalMessages: 0,
    );
    await testAccountRepo.saveAccount(account);

    // Case 1: Latest emails are available (resyncReturnCount = 5)
    smartAuth.resyncReturnCount = 5;
    smartAuth.profileMessagesTotal = 350;

    final result1 = await smartAuth.syncMailboxSmart(
      account: account,
      messageRepo: testMessageRepo,
      accountRepo: testAccountRepo,
    );

    expect(smartAuth.resyncCallCount, equals(1));
    expect(smartAuth.syncOlderCallCount, equals(0)); // Did not need to fetch older
    expect(result1.syncedCount, equals(5));
    expect(result1.olderSynced, isFalse);
    expect(result1.totalAvailable, equals(350));

    // Verify account's totalMessages was updated
    final updatedAccount = (await testAccountRepo.getAccounts()).firstWhere((a) => a.id == 'acc_smart_1');
    expect(updatedAccount.totalMessages, equals(350));

    // Case 2: Latest emails are already synced (resyncReturnCount = 0)
    // Should proceed to fetch older emails in a batch of 100
    smartAuth.resyncReturnCount = 0;
    smartAuth.olderReturnCount = 100;
    smartAuth.profileMessagesTotal = 350;

    String? lastProgressStatus;
    final result2 = await smartAuth.syncMailboxSmart(
      account: updatedAccount,
      messageRepo: testMessageRepo,
      accountRepo: testAccountRepo,
      onProgress: (current, total, status) {
        lastProgressStatus = status;
      },
    );

    expect(smartAuth.resyncCallCount, equals(2)); // Called resync first
    expect(smartAuth.syncOlderCallCount, equals(1)); // Proceeded to fetch older
    expect(smartAuth.syncOlderRequestedCount, equals(100)); // Batch of 100
    expect(result2.syncedCount, equals(100));
    expect(result2.olderSynced, isTrue);
    expect(lastProgressStatus, contains('Syncing older emails'));

    await testDb.close();
  });

  group('Two-Way Star Sync & Starred Tracking Tests', () {
    late AppDatabase testDb;
    late FakeGoogleAuthService fakeAuth;
    late MessageRepositoryImpl messageRepo;

    setUp(() {
      testDb = AppDatabase(NativeDatabase.memory());
      fakeAuth = FakeGoogleAuthService();
      messageRepo = MessageRepositoryImpl(testDb, fakeAuth);
    });

    tearDown(() async {
      await testDb.close();
    });

    test('Toggling star updates local DB and syncs to Gmail', () async {
      final msg = MailMessage(
        id: 'acc1_star1',
        accountId: 'acc1',
        remoteMessageId: 'rem_star_1',
        senderEmail: 'boss@corp.com',
        senderName: 'The Boss',
        subject: 'Important Q4 Strategy',
        snippet: 'Please review',
        plainTextBody: 'Please review',
        category: MailCategory.personal,
        isStarred: false,
        receivedAt: DateTime.now(),
      );
      await messageRepo.saveMessages([msg]);

      // Initially not starred
      final initial = await messageRepo.getMessage('acc1_star1');
      expect(initial?.isStarred, isFalse);

      // Star the message
      await messageRepo.setStarred('acc1_star1', true);

      // Local DB is updated
      final updated = await messageRepo.getMessage('acc1_star1');
      expect(updated?.isStarred, isTrue);

      // Remote sync was triggered
      expect(fakeAuth.starredRemoteIds, contains('rem_star_1'));
      expect(fakeAuth.unstarredRemoteIds, isEmpty);

      // Unstar the message
      await messageRepo.setStarred('acc1_star1', false);
      final unstarred = await messageRepo.getMessage('acc1_star1');
      expect(unstarred?.isStarred, isFalse);
      expect(fakeAuth.unstarredRemoteIds, contains('rem_star_1'));
    });

    test('markMessageStarredByRemoteId updates message from delta sync', () async {
      final msg = MailMessage(
        id: 'acc1_star2',
        accountId: 'acc1',
        remoteMessageId: 'rem_star_2',
        senderEmail: 'investor@fund.com',
        senderName: 'Investor',
        subject: 'Term Sheet',
        snippet: 'Signed document',
        plainTextBody: 'Signed document',
        category: MailCategory.transactions,
        isStarred: false,
        receivedAt: DateTime.now(),
      );
      await messageRepo.saveMessages([msg]);

      await messageRepo.markMessageStarredByRemoteId('rem_star_2', true);
      final updated = await messageRepo.getMessage('acc1_star2');
      expect(updated?.isStarred, isTrue);

      await messageRepo.markMessageStarredByRemoteId('rem_star_2', false);
      final reverted = await messageRepo.getMessage('acc1_star2');
      expect(reverted?.isStarred, isFalse);
    });

    test('watchStarredCount accurately reflects active starred emails', () async {
      final m1 = MailMessage(
        id: 'acc1_m1',
        accountId: 'acc1',
        remoteMessageId: 'r1',
        senderEmail: 'a@b.com',
        senderName: 'A',
        subject: 'Sub 1',
        snippet: '',
        plainTextBody: '',
        category: MailCategory.personal,
        isStarred: true,
        receivedAt: DateTime.now(),
      );
      final m2 = MailMessage(
        id: 'acc1_m2',
        accountId: 'acc1',
        remoteMessageId: 'r2',
        senderEmail: 'b@b.com',
        senderName: 'B',
        subject: 'Sub 2',
        snippet: '',
        plainTextBody: '',
        category: MailCategory.personal,
        isStarred: false,
        receivedAt: DateTime.now(),
      );
      await messageRepo.saveMessages([m1, m2]);

      final count = await messageRepo.watchStarredCount(accountId: 'acc1').first;
      expect(count, equals(1));

      await messageRepo.setStarred('acc1_m2', true);
      final countAfter = await messageRepo.watchStarredCount(accountId: 'acc1').first;
      expect(countAfter, equals(2));
    });

    test('deleteAllFromSender preserves messages locally if remote batch trashing fails', () async {
      fakeAuth.failBatchTrash = true;

      final m1 = MailMessage(
        id: 'fail_m1',
        accountId: 'acc1',
        remoteMessageId: 'rem_fail_1',
        senderEmail: 'spammer@ad.com',
        senderName: 'Spam Co',
        subject: 'Deal 1',
        snippet: '',
        plainTextBody: '',
        category: MailCategory.updates,
        receivedAt: DateTime.now(),
      );
      final m2 = MailMessage(
        id: 'fail_m2',
        accountId: 'acc1',
        remoteMessageId: 'rem_fail_2',
        senderEmail: 'spammer@ad.com',
        senderName: 'Spam Co',
        subject: 'Deal 2',
        snippet: '',
        plainTextBody: '',
        category: MailCategory.updates,
        receivedAt: DateTime.now(),
      );
      await messageRepo.saveMessages([m1, m2]);

      final progressUpdates = <({int current, int total})>[];
      final deletedCount = await messageRepo.deleteAllFromSender(
        'spammer@ad.com',
        onProgress: (current, total) => progressUpdates.add((current: current, total: total)),
      );

      // Since remote trashing failed, 0 messages were deleted
      expect(deletedCount, equals(0));

      // Messages are safely preserved in local DB and NOT removed from the screen!
      final preservedM1 = await messageRepo.getMessage('fail_m1');
      final preservedM2 = await messageRepo.getMessage('fail_m2');
      expect(preservedM1, isNotNull);
      expect(preservedM2, isNotNull);

      // Verify progress callback was triggered
      expect(progressUpdates, isNotEmpty);
      expect(progressUpdates.first.total, equals(2));

      fakeAuth.failBatchTrash = false;
    });

    test('deleteAllFromSender only deletes confirmed remote-trashed messages when partial failure occurs', () async {
      // Simulate partial failure: only rem_part_1 succeeds, rem_part_2 fails
      fakeAuth.batchTrashFilter = (ids) => ids.where((id) => id == 'rem_part_1').toList();

      final m1 = MailMessage(
        id: 'part_m1',
        accountId: 'acc1',
        remoteMessageId: 'rem_part_1',
        senderEmail: 'partial@sender.com',
        senderName: 'Partial Sender',
        subject: 'Part 1',
        snippet: '',
        plainTextBody: '',
        category: MailCategory.updates,
        receivedAt: DateTime.now(),
      );
      final m2 = MailMessage(
        id: 'part_m2',
        accountId: 'acc1',
        remoteMessageId: 'rem_part_2',
        senderEmail: 'partial@sender.com',
        senderName: 'Partial Sender',
        subject: 'Part 2',
        snippet: '',
        plainTextBody: '',
        category: MailCategory.updates,
        receivedAt: DateTime.now(),
      );
      await messageRepo.saveMessages([m1, m2]);

      final deletedCount = await messageRepo.deleteAllFromSender('partial@sender.com');

      // Exactly 1 message confirmed deleted
      expect(deletedCount, equals(1));

      // m1 (confirmed remote deleted) was removed from SQLite
      final fetchedM1 = await messageRepo.getMessage('part_m1');
      expect(fetchedM1, isNull);

      // m2 (remote delete failed) is PRESERVED in SQLite!
      final fetchedM2 = await messageRepo.getMessage('part_m2');
      expect(fetchedM2, isNotNull);

      fakeAuth.batchTrashFilter = null;
    });
  });
}
