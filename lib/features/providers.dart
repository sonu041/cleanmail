import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/services/google_auth_service.dart';
import '../core/services/log_service.dart';
import '../core/theme/app_theme.dart';
import '../data/local/database.dart';
import '../data/repositories/account_repository_impl.dart';
import '../data/repositories/message_repository_impl.dart';
import '../domain/models/account.dart';
import '../domain/models/category.dart';
import '../domain/models/message.dart';
import '../domain/models/sender_rule.dart';
import '../domain/models/sender_summary.dart';

// ----------------------------------------------------
// THEME & PREFERENCES
// ----------------------------------------------------

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  static const _themeStorageKey = 'cleanmail_theme_mode';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ThemeModeNotifier() : super(AppThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final saved = await _storage.read(key: _themeStorageKey);
      if (saved != null) {
        state = AppThemeMode.fromString(saved);
      }
    } catch (_) {}
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    try {
      await _storage.write(key: _themeStorageKey, value: mode.name);
      AppLogger.info('Theme Changed', 'Switched app appearance to ${mode.label}', category: LogCategory.system);
    } catch (_) {}
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier();
});

// ----------------------------------------------------
// OPERATION LOGS & AUDIT TRAIL
// ----------------------------------------------------

final logServiceProvider = Provider<LogService>((ref) {
  return LogService();
});

final logsStreamProvider = StreamProvider<List<AppLog>>((ref) {
  final service = ref.watch(logServiceProvider);
  return service.logsStream;
});

// Google Auth & Remote Sync Service provider
final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

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
  final googleAuth = ref.watch(googleAuthServiceProvider);
  return MessageRepositoryImpl(db, googleAuth);
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

// Multi-selection state for batch triage operations
final isSelectionModeProvider = StateProvider<bool>((ref) => false);
final selectedMessageIdsProvider = StateProvider<Set<String>>((ref) => <String>{});

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

// Reactive message counts grouped by accountId
final messageCountsByAccountProvider = StreamProvider<Map<String, int>>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  return repo.watchMessageCountsByAccount();
});

// Reactive total synced message counts (including all messages in local DB) grouped by accountId
final syncedMessageCountsByAccountProvider = StreamProvider<Map<String, int>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchSyncedMessageCountsByAccount();
});

// Reactive message counts grouped by category for the selected account
final messageCountsByCategoryProvider = StreamProvider<Map<String, int>>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  final accountId = ref.watch(selectedAccountIdProvider);
  return repo.watchMessageCountsByCategory(accountId: accountId);
});

// Selected unread-only filter (default = false)
final unreadOnlyFilterProvider = StateProvider<bool>((ref) => false);

// Selected starred-only filter (default = false)
final starredOnlyFilterProvider = StateProvider<bool>((ref) => false);

// Reactive unread count for the current account and category
final unreadCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  final accountId = ref.watch(selectedAccountIdProvider);
  final category = ref.watch(selectedCategoryProvider);
  return repo.watchUnreadCount(
    accountId: accountId,
    category: category == MailCategory.all ? null : category.name,
  );
});

// Reactive starred count for the current account and category
final starredCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  final accountId = ref.watch(selectedAccountIdProvider);
  final category = ref.watch(selectedCategoryProvider);
  return repo.watchStarredCount(
    accountId: accountId,
    category: category == MailCategory.all ? null : category.name,
  );
});

// Reactive sender summaries for Sender Sweep
final senderSummariesStreamProvider = StreamProvider<List<SenderSummary>>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  final accountId = ref.watch(selectedAccountIdProvider);

  return repo.watchSenderSummaries(accountId: accountId);
});

// Reactive sender rules stream
final senderRulesStreamProvider = StreamProvider<List<SenderRule>>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  return repo.watchSenderRules();
});

// Single sender rule provider
final senderRuleProvider = FutureProvider.family<SenderRule?, String>((ref, senderEmail) {
  final repo = ref.watch(messageRepositoryProvider);
  return repo.getSenderRule(senderEmail);
});

// Reactive stream of active messages from a specific sender
final senderMessagesStreamProvider =
    StreamProvider.family<List<MailMessage>, String>((ref, senderEmail) {
  final repo = ref.watch(messageRepositoryProvider);
  return repo.watchMessagesBySender(senderEmail);
});

// Search query provider for filtering inbox on the fly
final searchQueryProvider = StateProvider<String>((ref) => '');

// Filtered messages with search query applied
final filteredMessagesProvider = Provider<List<MailMessage>>((ref) {
  final messagesAsync = ref.watch(inboxMessagesStreamProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final unreadOnly = ref.watch(unreadOnlyFilterProvider);
  final starredOnly = ref.watch(starredOnlyFilterProvider);

  return messagesAsync.maybeWhen(
    data: (messages) {
      var result = messages;
      if (unreadOnly) {
        result = result.where((m) => !m.isRead).toList();
      }
      if (starredOnly) {
        result = result.where((m) => m.isStarred).toList();
      }
      if (query.isNotEmpty) {
        result = result.where((m) {
          return m.subject.toLowerCase().contains(query) ||
              m.senderName.toLowerCase().contains(query) ||
              m.senderEmail.toLowerCase().contains(query) ||
              m.snippet.toLowerCase().contains(query);
        }).toList();
      }
      return result;
    },
    orElse: () => [],
  );
});
