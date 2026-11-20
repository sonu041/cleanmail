import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/database.dart';
import '../data/repositories/account_repository_impl.dart';
import '../data/repositories/message_repository_impl.dart';
import '../domain/models/account.dart';
import '../domain/models/category.dart';
import '../domain/models/message.dart';
import '../domain/models/sender_summary.dart';

// Database instance provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Repositories
final accountRepositoryProvider = Provider<AccountRepositoryImpl>((ref) {
  final db = ref.watch(databaseProvider);
  return AccountRepositoryImpl(db);
});

final messageRepositoryProvider = Provider<MessageRepositoryImpl>((ref) {
  final db = ref.watch(databaseProvider);
  return MessageRepositoryImpl(db);
});

// Accounts stream
final accountsStreamProvider = StreamProvider<List<MailAccount>>((ref) {
  final repo = ref.watch(accountRepositoryProvider);
  return repo.watchAccounts();
});

// Selected account filter (null = "All Inboxes")
final selectedAccountIdProvider = StateProvider<String?>((ref) => null);

// Selected category filter (default = MailCategory.all)
final selectedCategoryProvider = StateProvider<MailCategory>((ref) => MailCategory.all);

// Reactive unified inbox messages
final inboxMessagesStreamProvider = StreamProvider<List<MailMessage>>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  final accountId = ref.watch(selectedAccountIdProvider);
  final category = ref.watch(selectedCategoryProvider);

  return repo.watchInbox(
    accountId: accountId,
    category: category,
  );
});

// Reactive sender summaries for Sender Sweep
final senderSummariesStreamProvider = StreamProvider<List<SenderSummary>>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  final accountId = ref.watch(selectedAccountIdProvider);

  return repo.watchSenderSummaries(accountId: accountId);
});

// Search query provider for filtering inbox on the fly
final searchQueryProvider = StateProvider<String>((ref) => '');

// Filtered messages with search query applied
final filteredMessagesProvider = Provider<List<MailMessage>>((ref) {
  final messagesAsync = ref.watch(inboxMessagesStreamProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  return messagesAsync.maybeWhen(
    data: (messages) {
      if (query.isEmpty) return messages;
      return messages.where((m) {
        return m.subject.toLowerCase().contains(query) ||
            m.senderName.toLowerCase().contains(query) ||
            m.senderEmail.toLowerCase().contains(query) ||
            m.snippet.toLowerCase().contains(query);
      }).toList();
    },
    orElse: () => [],
  );
});
