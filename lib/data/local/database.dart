import 'package:drift/drift.dart';
import 'connection/connection.dart';
import 'tables/accounts_table.dart';
import 'tables/messages_table.dart';
import '../../domain/models/sender_summary.dart';

part 'database.g.dart';

@DriftDatabase(tables: [AccountsTable, MessagesTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  @override
  int get schemaVersion => 1;

  // ----------------------------------------------------
  // ACCOUNTS OPERATIONS
  // ----------------------------------------------------

  Stream<List<AccountEntry>> watchAllAccounts() {
    return select(accountsTable).watch();
  }

  Future<List<AccountEntry>> getAllAccounts() {
    return select(accountsTable).get();
  }

  Future<int> insertOrUpdateAccount(AccountsTableCompanion entry) {
    return into(accountsTable).insertOnConflictUpdate(entry);
  }

  Future<int> deleteAccountById(String id) async {
    // Delete account and all associated messages
    await transaction(() async {
      await (delete(messagesTable)..where((m) => m.accountId.equals(id))).go();
      await (delete(accountsTable)..where((a) => a.id.equals(id))).go();
    });
    return 1;
  }

  // ----------------------------------------------------
  // MESSAGES OPERATIONS
  // ----------------------------------------------------

  /// Streams messages for the unified inbox with optional account and category filters.
  Stream<List<MessageEntry>> watchInboxMessages({
    String? accountId,
    String? category,
    bool includeArchived = false,
  }) {
    final query = select(messagesTable)
      ..where((tbl) {
        Expression<bool> predicate = tbl.isArchived.equals(includeArchived);
        if (accountId != null && accountId.isNotEmpty) {
          predicate = predicate & tbl.accountId.equals(accountId);
        }
        if (category != null && category.isNotEmpty && category.toLowerCase() != 'all') {
          predicate = predicate & tbl.category.equals(category.toLowerCase());
        }
        return predicate;
      })
      ..orderBy([
        (t) => OrderingTerm(expression: t.receivedAt, mode: OrderingMode.desc),
      ]);

    return query.watch();
  }

  Future<MessageEntry?> getMessageById(String id) {
    return (select(messagesTable)..where((m) => m.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertOrUpdateMessages(List<MessagesTableCompanion> entries) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(messagesTable, entries);
    });
  }

  Future<void> markMessageRead(String id, bool isRead) async {
    await (update(messagesTable)..where((m) => m.id.equals(id))).write(
      MessagesTableCompanion(isRead: Value(isRead)),
    );
  }

  Future<void> archiveMessage(String id, bool isArchived) async {
    await (update(messagesTable)..where((m) => m.id.equals(id))).write(
      MessagesTableCompanion(isArchived: Value(isArchived)),
    );
  }

  Future<void> deleteMessage(String id) async {
    await (delete(messagesTable)..where((m) => m.id.equals(id))).go();
  }

  Future<int> deleteMessageByRemoteId(String remoteId) {
    return (delete(messagesTable)..where((m) => m.remoteMessageId.equals(remoteId))).go();
  }

  Future<int> deleteMessagesByRemoteIds(List<String> remoteIds) {
    if (remoteIds.isEmpty) return Future.value(0);
    return (delete(messagesTable)..where((m) => m.remoteMessageId.isIn(remoteIds))).go();
  }

  Future<MessageEntry?> getMessageByRemoteId(String remoteId) {
    return (select(messagesTable)..where((m) => m.remoteMessageId.equals(remoteId))).getSingleOrNull();
  }

  Future<List<MessageEntry>> getMessagesBySenderEmail(String senderEmail) {
    return (select(messagesTable)..where((m) => m.senderEmail.equals(senderEmail))).get();
  }

  Future<int> markMessageReadByRemoteId(String remoteId, bool isRead) {
    return (update(messagesTable)..where((m) => m.remoteMessageId.equals(remoteId))).write(
      MessagesTableCompanion(isRead: Value(isRead)),
    );
  }

  Future<int> archiveMessageByRemoteId(String remoteId, bool isArchived) {
    return (update(messagesTable)..where((m) => m.remoteMessageId.equals(remoteId))).write(
      MessagesTableCompanion(isArchived: Value(isArchived)),
    );
  }

  /// Returns a set of all remoteMessageIds currently stored for an account.
  Future<Set<String>> getExistingRemoteMessageIds(String accountId) async {
    final query = selectOnly(messagesTable)
      ..addColumns([messagesTable.remoteMessageId])
      ..where(messagesTable.accountId.equals(accountId));
    final rows = await query.get();
    return rows
        .map((r) => r.read(messagesTable.remoteMessageId))
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  /// Removes any duplicate messages across all mailboxes:
  /// 1. Global deduplication by remote_message_id (removes cross-account duplicate insertions)
  /// 2. Deduplication by identical content (subject, sender, received_at)
  Future<int> deduplicateMessages() async {
    int totalRemoved = 0;

    // 1. Remove duplicate remote_message_id records globally across all accounts,
    // keeping only the single earliest inserted record.
    final count1 = await customUpdate(
      '''
      DELETE FROM messages_table
      WHERE rowid NOT IN (
        SELECT MIN(rowid)
        FROM messages_table
        GROUP BY remote_message_id
      )
      ''',
      updates: {messagesTable},
    );
    totalRemoved += count1;

    // 2. Remove identical subject + sender + received_at cross-joined duplicates
    final count2 = await customUpdate(
      '''
      DELETE FROM messages_table
      WHERE rowid NOT IN (
        SELECT MIN(rowid)
        FROM messages_table
        GROUP BY subject, sender_email, received_at
      )
      ''',
      updates: {messagesTable},
    );
    totalRemoved += count2;

    return totalRemoved;
  }

  // ----------------------------------------------------
  // EASY-TO-CLEAN: SENDER SWEEP OPERATIONS
  // ----------------------------------------------------

  /// Aggregates emails grouped by sender, sorted by total message count descending.
  Stream<List<SenderSummary>> watchSenderSummaries({String? accountId}) {
    final whereClause = StringBuffer('WHERE is_archived = 0');
    if (accountId != null && accountId.isNotEmpty) {
      whereClause.write(" AND account_id = '$accountId'");
    }

    final query = customSelect(
      '''
      SELECT 
        sender_email,
        sender_name,
        account_id,
        COUNT(*) AS total_count,
        SUM(CASE WHEN is_read = 0 THEN 1 ELSE 0 END) AS unread_count,
        MAX(received_at) AS last_received_at,
        (
          SELECT subject FROM messages_table m2 
          WHERE m2.sender_email = messages_table.sender_email 
          ORDER BY m2.received_at DESC LIMIT 1
        ) AS latest_subject
      FROM messages_table
      $whereClause
      GROUP BY sender_email
      ORDER BY total_count DESC
      ''',
      readsFrom: {messagesTable},
    );

    return query.watch().map((rows) {
      return rows.map((row) {
        final rawLastReceived = row.read<dynamic>('last_received_at');
        DateTime lastDate;
        if (rawLastReceived is int) {
          lastDate = DateTime.fromMillisecondsSinceEpoch(rawLastReceived * 1000);
        } else if (rawLastReceived is String) {
          lastDate = DateTime.tryParse(rawLastReceived) ?? DateTime.now();
        } else {
          lastDate = DateTime.now();
        }

        return SenderSummary(
          senderEmail: row.read<String>('sender_email'),
          senderName: row.read<String>('sender_name'),
          totalCount: row.read<int>('total_count'),
          unreadCount: row.read<int>('unread_count'),
          lastReceivedAt: lastDate,
          latestSubject: row.read<String?>('latest_subject') ?? '',
          accountId: row.read<String>('account_id'),
        );
      }).toList();
    });
  }

  /// Bulk-archives all active messages from a specific sender.
  Future<int> archiveAllFromSender(String senderEmail) async {
    final statement = update(messagesTable)
      ..where((m) => m.senderEmail.equals(senderEmail) & m.isArchived.equals(false));
    return statement.write(const MessagesTableCompanion(isArchived: Value(true)));
  }

  /// Bulk-deletes all messages from a specific sender.
  Future<int> deleteAllFromSender(String senderEmail) async {
    final statement = delete(messagesTable)
      ..where((m) => m.senderEmail.equals(senderEmail));
    return statement.go();
  }
}
