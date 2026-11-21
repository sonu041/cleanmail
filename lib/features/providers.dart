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
