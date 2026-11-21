import 'package:drift/drift.dart';
import 'connection/connection.dart';
import 'tables/accounts_table.dart';
import 'tables/messages_table.dart';
import 'tables/sender_rules_table.dart';
import 'tables/metric_events_table.dart';
import '../../domain/models/sender_summary.dart';

part 'database.g.dart';

@DriftDatabase(tables: [AccountsTable, MessagesTable, SenderRulesTable, MetricEventsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(messagesTable, messagesTable.isLocked);
      }
      if (from < 3) {
        await m.addColumn(messagesTable, messagesTable.customTag);
        await m.createTable(senderRulesTable);
      }
      if (from < 4) {
        await m.addColumn(accountsTable, accountsTable.totalMessages);
      }
      if (from < 5) {
        await m.createTable(metricEventsTable);
      }
    },
    beforeOpen: (details) async {
      try {
        await customStatement('UPDATE accounts_table SET total_messages = 0 WHERE total_messages IS NULL');
      } catch (_) {}
      try {
        await customStatement('UPDATE messages_table SET is_locked = 0 WHERE is_locked IS NULL');
      } catch (_) {}
    },
  );

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

  /// Streams non-archived messages from a specific sender ordered newest first.
  Stream<List<MessageEntry>> watchMessagesBySenderEmail(String senderEmail, {bool includeArchived = false}) {
    final query = select(messagesTable)
      ..where((tbl) {
        Expression<bool> predicate = tbl.senderEmail.equals(senderEmail);
        if (!includeArchived) {
          predicate = predicate & tbl.isArchived.equals(false);
        }
        return predicate;
      })
      ..orderBy([
        (t) => OrderingTerm(expression: t.receivedAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  /// Watches active (non-archived) message counts grouped by account_id.
  Stream<Map<String, int>> watchMessageCountsByAccount() {
    final query = customSelect(
      'SELECT account_id, COUNT(*) AS cnt FROM messages_table WHERE is_archived = 0 GROUP BY account_id',
      readsFrom: {messagesTable},
    );
    return query.watch().map((rows) {
      final map = <String, int>{};
      for (final row in rows) {
        final accId = row.readNullable<String>('account_id') ?? '';
        if (accId.isNotEmpty) {
          map[accId] = row.readNullable<int>('cnt') ??
              (row.data['cnt'] as num?)?.toInt() ??
              0;
        }
      }
      return map;
    });
  }

  /// Watches total synced message counts currently in local DB grouped by account_id.
  Stream<Map<String, int>> watchSyncedMessageCountsByAccount() {
    final query = customSelect(
      'SELECT account_id, COUNT(*) AS cnt FROM messages_table GROUP BY account_id',
      readsFrom: {messagesTable},
    );
    return query.watch().map((rows) {
      final map = <String, int>{};
      for (final row in rows) {
        final accId = row.readNullable<String>('account_id') ?? '';
        if (accId.isNotEmpty) {
          map[accId] = row.readNullable<int>('cnt') ??
              (row.data['cnt'] as num?)?.toInt() ??
              0;
        }
      }
      return map;
    });
  }

  /// Returns the current total count of synced messages in local DB for an account.
  Future<int> getSyncedMessageCountForAccount(String accountId) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS cnt FROM messages_table WHERE account_id = ?',
      variables: [Variable.withString(accountId)],
      readsFrom: {messagesTable},
    ).getSingleOrNull();
    return row?.readNullable<int>('cnt') ??
        (row?.data['cnt'] as num?)?.toInt() ??
        0;
  }

  /// Watches active (non-archived) message counts grouped by category,
  /// optionally filtered by accountId.
  Stream<Map<String, int>> watchMessageCountsByCategory({String? accountId}) {
    final whereClause = StringBuffer('WHERE is_archived = 0');
    if (accountId != null && accountId.isNotEmpty) {
      whereClause.write(" AND account_id = '$accountId'");
    }
    final query = customSelect(
      'SELECT category, COUNT(*) AS cnt FROM messages_table $whereClause GROUP BY category',
      readsFrom: {messagesTable},
    );
    return query.watch().map((rows) {
      final map = <String, int>{};
      for (final row in rows) {
        final cat = (row.readNullable<String>('category') ?? '').toLowerCase();
        if (cat.isNotEmpty) {
          map[cat] = row.readNullable<int>('cnt') ??
              (row.data['cnt'] as num?)?.toInt() ??
              0;
        }
      }
      return map;
    });
  }

  /// Watches the active (non-archived) unread message count.
  Stream<int> watchUnreadCount({String? accountId, String? category}) {
    final whereClause = StringBuffer('WHERE is_archived = 0 AND is_read = 0');
    if (accountId != null && accountId.isNotEmpty) {
      whereClause.write(" AND account_id = '$accountId'");
    }
    if (category != null && category.isNotEmpty && category.toLowerCase() != 'all') {
      whereClause.write(" AND category = '${category.toLowerCase()}'");
    }
    final query = customSelect(
      'SELECT COUNT(*) AS cnt FROM messages_table $whereClause',
      readsFrom: {messagesTable},
    );
    return query.watchSingle().map((row) =>
        row.readNullable<int>('cnt') ??
        (row.data['cnt'] as num?)?.toInt() ??
        0);
  }

  /// Watches the active (non-archived) starred message count.
  Stream<int> watchStarredCount({String? accountId, String? category}) {
    final whereClause = StringBuffer('WHERE is_archived = 0 AND is_starred = 1');
    if (accountId != null && accountId.isNotEmpty) {
      whereClause.write(" AND account_id = '$accountId'");
    }
    if (category != null && category.isNotEmpty && category.toLowerCase() != 'all') {
      whereClause.write(" AND category = '${category.toLowerCase()}'");
    }
    final query = customSelect(
      'SELECT COUNT(*) AS cnt FROM messages_table $whereClause',
      readsFrom: {messagesTable},
    );
    return query.watchSingle().map((row) =>
        row.readNullable<int>('cnt') ??
        (row.data['cnt'] as num?)?.toInt() ??
        0);
  }

  Future<MessageEntry?> getMessageById(String id) {
    return (select(messagesTable)..where((m) => m.id.equals(id))).getSingleOrNull();
  }

  Future<List<MessageEntry>> getMessagesByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value([]);
    return (select(messagesTable)..where((m) => m.id.isIn(ids))).get();
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

  Future<void> setLocked(String id, bool isLocked) async {
    await (update(messagesTable)..where((m) => m.id.equals(id))).write(
      MessagesTableCompanion(isLocked: Value(isLocked)),
    );
  }

  Future<void> setStarred(String id, bool isStarred) async {
    await (update(messagesTable)..where((m) => m.id.equals(id))).write(
      MessagesTableCompanion(isStarred: Value(isStarred)),
    );
  }

  Future<void> setStarredByRemoteId(String remoteId, bool isStarred) async {
    await (update(messagesTable)..where((m) => m.remoteMessageId.equals(remoteId))).write(
      MessagesTableCompanion(isStarred: Value(isStarred)),
    );
  }

  Future<void> deleteMessage(String id) async {
    await (delete(messagesTable)..where((m) => m.id.equals(id) & m.isLocked.equals(false))).go();
  }

  Future<int> deleteMessages(List<String> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (delete(messagesTable)..where((m) => m.id.isIn(ids) & m.isLocked.equals(false))).go();
  }

  Future<int> deleteMessageByRemoteId(String remoteId) {
    return (delete(messagesTable)..where((m) => m.remoteMessageId.equals(remoteId) & m.isLocked.equals(false))).go();
  }

  Future<int> deleteMessagesByRemoteIds(List<String> remoteIds) {
    if (remoteIds.isEmpty) return Future.value(0);
    return (delete(messagesTable)..where((m) => m.remoteMessageId.isIn(remoteIds) & m.isLocked.equals(false))).go();
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

  /// Returns the receivedAt timestamp of the oldest stored message (optionally filtered by accountId).
  Future<DateTime?> getOldestMessageTimestamp([String? accountId]) async {
    final query = select(messagesTable)
      ..where((tbl) {
        if (accountId != null && accountId.isNotEmpty) {
          return tbl.accountId.equals(accountId);
        }
        return const Constant(true);
      })
      ..orderBy([(tbl) => OrderingTerm(expression: tbl.receivedAt, mode: OrderingMode.asc)])
      ..limit(1);
    final oldest = await query.getSingleOrNull();
    return oldest?.receivedAt;
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
        COALESCE(SUM(CASE WHEN is_read = 0 THEN 1 ELSE 0 END), 0) AS unread_count,
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
        final rawLastReceived = row.data['last_received_at'];
        DateTime lastDate;
        if (rawLastReceived is int) {
          lastDate = rawLastReceived < 10000000000
              ? DateTime.fromMillisecondsSinceEpoch(rawLastReceived * 1000)
              : DateTime.fromMillisecondsSinceEpoch(rawLastReceived);
        } else if (rawLastReceived is String) {
          lastDate = DateTime.tryParse(rawLastReceived) ?? DateTime.now();
        } else if (rawLastReceived is DateTime) {
          lastDate = rawLastReceived;
        } else {
          lastDate = DateTime.now();
        }

        return SenderSummary(
          senderEmail: row.readNullable<String>('sender_email') ?? '',
          senderName: row.readNullable<String>('sender_name') ?? '',
          totalCount: row.readNullable<int>('total_count') ??
              (row.data['total_count'] as num?)?.toInt() ??
              0,
          unreadCount: row.readNullable<int>('unread_count') ??
              (row.data['unread_count'] as num?)?.toInt() ??
              0,
          lastReceivedAt: lastDate,
          latestSubject: row.readNullable<String>('latest_subject') ?? '',
          accountId: row.readNullable<String>('account_id') ?? '',
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

  /// Bulk-deletes all non-locked messages from a specific sender.
  Future<int> deleteAllFromSender(String senderEmail) async {
    final statement = delete(messagesTable)
      ..where((m) => m.senderEmail.equals(senderEmail) & m.isLocked.equals(false));
    return statement.go();
  }

  // ----------------------------------------------------
  // SENDER RULES & PREFERRED TAGS
  // ----------------------------------------------------

  Stream<List<SenderRuleEntry>> watchAllSenderRules() {
    return (select(senderRulesTable)..orderBy([(t) => OrderingTerm.asc(t.senderEmail)])).watch();
  }

  Future<List<SenderRuleEntry>> getAllSenderRules() {
    return (select(senderRulesTable)..orderBy([(t) => OrderingTerm.asc(t.senderEmail)])).get();
  }

  Future<SenderRuleEntry?> getSenderRule(String senderEmail) {
    final lower = senderEmail.toLowerCase().trim();
    return (select(senderRulesTable)..where((t) => t.senderEmail.equals(lower))).getSingleOrNull();
  }

  Future<Map<String, SenderRuleEntry>> getSenderRulesForEmails(List<String> senderEmails) async {
    final normalized = senderEmails.map((e) => e.toLowerCase().trim()).toSet();
    if (normalized.isEmpty) return {};
    final entries = await (select(senderRulesTable)..where((t) => t.senderEmail.isIn(normalized))).get();
    return {for (final e in entries) e.senderEmail: e};
  }

  Future<int> insertOrUpdateSenderRule(SenderRulesTableCompanion entry) {
    return into(senderRulesTable).insertOnConflictUpdate(entry);
  }

  Future<int> deleteSenderRule(String senderEmail) {
    final lower = senderEmail.toLowerCase().trim();
    return (delete(senderRulesTable)..where((t) => t.senderEmail.equals(lower))).go();
  }

  /// Updates existing messages from a specific sender with their preferred tag/category.
  Future<int> updateExistingMessagesFromSender({
    required String senderEmail,
    required String category,
    String? customTag,
    bool isAutoLocked = false,
  }) {
    final lower = senderEmail.toLowerCase().trim();
    final companion = MessagesTableCompanion(
      category: Value(category),
      customTag: Value(customTag),
      isLocked: isAutoLocked ? const Value(true) : const Value.absent(),
    );
    return (update(messagesTable)
          ..where((m) => m.senderEmail.equals(senderEmail) | m.senderEmail.equals(lower)))
        .write(companion);
  }

  // ----------------------------------------------------
  // METRICS & DASHBOARD OPERATIONS
  // ----------------------------------------------------

  /// Records a triage or sync metric event (e.g. sync, delete, unsubscribe, lock).
  Future<int> recordMetricEvent({
    required String eventType,
    int count = 1,
    String? accountId,
    String? details,
    DateTime? timestamp,
  }) {
    return into(metricEventsTable).insert(
      MetricEventsTableCompanion(
        eventType: Value(eventType),
        count: Value(count),
        accountId: Value(accountId),
        timestamp: Value(timestamp ?? DateTime.now()),
        details: Value(details),
      ),
    );
  }

  /// Streams metric events matching optional time threshold and account filter.
  Stream<List<MetricEventEntry>> watchMetricEvents({DateTime? since, String? accountId}) {
    final query = select(metricEventsTable);
    if (since != null || (accountId != null && accountId.isNotEmpty)) {
      query.where((t) {
        Expression<bool> predicate = const Constant(true);
        if (since != null) {
          predicate = predicate & t.timestamp.isBiggerOrEqualValue(since);
        }
        if (accountId != null && accountId.isNotEmpty) {
          predicate = predicate & t.accountId.equals(accountId);
        }
        return predicate;
      });
    }
    query.orderBy([(t) => OrderingTerm.desc(t.timestamp)]);
    return query.watch();
  }

  /// Gets metric events matching optional time threshold and account filter.
  Future<List<MetricEventEntry>> getMetricEvents({DateTime? since, String? accountId}) {
    final query = select(metricEventsTable);
    if (since != null || (accountId != null && accountId.isNotEmpty)) {
      query.where((t) {
        Expression<bool> predicate = const Constant(true);
        if (since != null) {
          predicate = predicate & t.timestamp.isBiggerOrEqualValue(since);
        }
        if (accountId != null && accountId.isNotEmpty) {
          predicate = predicate & t.accountId.equals(accountId);
        }
        return predicate;
      });
    }
    query.orderBy([(t) => OrderingTerm.desc(t.timestamp)]);
    return query.get();
  }

  /// Watches the current count of locked messages.
  Stream<int> watchLockedMessagesCount({String? accountId}) {
    final query = selectOnly(messagesTable)
      ..addColumns([messagesTable.id.count()])
      ..where(messagesTable.isLocked.equals(true));
    if (accountId != null && accountId.isNotEmpty) {
      query.where(messagesTable.accountId.equals(accountId));
    }
    return query.map((row) => row.read(messagesTable.id.count()) ?? 0).watchSingle();
  }

  /// Watches current total message count in local storage.
  Stream<int> watchActiveMessagesCount({String? accountId}) {
    final query = selectOnly(messagesTable)
      ..addColumns([messagesTable.id.count()])
      ..where(messagesTable.isArchived.equals(false));
    if (accountId != null && accountId.isNotEmpty) {
      query.where(messagesTable.accountId.equals(accountId));
    }
    return query.map((row) => row.read(messagesTable.id.count()) ?? 0).watchSingle();
  }

  /// Watches current unread message count in local storage.
  Stream<int> watchUnreadMessagesCount({String? accountId}) {
    final query = selectOnly(messagesTable)
      ..addColumns([messagesTable.id.count()])
      ..where(messagesTable.isRead.equals(false) & messagesTable.isArchived.equals(false));
    if (accountId != null && accountId.isNotEmpty) {
      query.where(messagesTable.accountId.equals(accountId));
    }
    return query.map((row) => row.read(messagesTable.id.count()) ?? 0).watchSingle();
  }
}
