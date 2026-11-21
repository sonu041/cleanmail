import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/account.dart';
import '../../../../domain/models/category.dart';
import '../../../accounts/presentation/screens/accounts_screen.dart';
import '../../../clean_sweep/presentation/screens/clean_sweep_screen.dart';
import '../../../providers.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../widgets/email_tile.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final accountsAsync = ref.watch(accountsStreamProvider);
    final selectedAccountId = ref.watch(selectedAccountIdProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final messages = ref.watch(filteredMessagesProvider);
    final accounts = accountsAsync.asData?.value ?? [];

    // Find active account name
    String activeTitle = 'All Inboxes';
    if (selectedAccountId != null && accounts.isNotEmpty) {
      final acc = accounts.firstWhere(
        (a) => a.id == selectedAccountId,
        orElse: () => accounts.first,
      );
      activeTitle = acc.displayName;
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search text, sender, subject...',
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  ref.read(searchQueryProvider.notifier).state = val;
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTheme.isNerd(context) ? '> CleanMail [CLI]' : 'CleanMail',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      fontFamily: AppTheme.isNerd(context) ? 'monospace' : null,
                    ),
                  ),
                  Text(
                    AppTheme.isNerd(context) ? '// $activeTitle' : activeTitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary(context),
                      fontWeight: FontWeight.normal,
                      fontFamily: AppTheme.isNerd(context) ? 'monospace' : null,
                    ),
                  ),
                ],
              ),
        actions: [
          // Search Toggle
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Close Search' : 'Search',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                }
              });
            },
          ),

          // Sender Sweep (Easy-to-Clean)
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: 'Sender Sweep',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CleanSweepScreen()),
              );
            },
          ),

          // Accounts / Mailboxes
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Mailbox Accounts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountsScreen()),
              );
            },
          ),

          // Settings & Logs
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Logs',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Multi-Mailbox Single Pane Switcher (Account Chips)
          _buildAccountBar(context, ref, accounts, selectedAccountId),

          // Category Pills
          _buildCategoryBar(context, ref, selectedCategory),

          const Divider(height: 1, thickness: 1),

          // Messages List with Fast Swipe Triage & Pull-to-Refresh
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final accounts = ref.read(accountsStreamProvider).asData?.value ?? [];
                final googleAuth = ref.read(googleAuthServiceProvider);
                final messageRepo = ref.read(messageRepositoryProvider);
                for (final acc in accounts) {
                  if (acc.provider == MailProvider.gmail) {
                    await googleAuth.resyncAccount(account: acc, messageRepo: messageRepo);
                  }
                }
              },
              child: messages.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: _buildEmptyState(context, isDark),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final account = accounts.where((a) => a.id == msg.accountId).firstOrNull;
                        return EmailTile(
                          key: ValueKey(msg.id),
                          message: msg,
                          account: account,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountBar(
    BuildContext context,
    WidgetRef ref,
    List<MailAccount> accounts,
    String? selectedAccountId,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // "All Inboxes" chip
          ChoiceChip(
            label: const Text('All Inboxes'),
            selected: selectedAccountId == null,
            onSelected: (selected) {
              if (selected) {
                ref.read(selectedAccountIdProvider.notifier).state = null;
              }
            },
          ),
          const SizedBox(width: 8),

          // Individual account chips
          ...accounts.map((account) {
            final isSelected = selectedAccountId == account.id;
            final color = Color(account.avatarColorValue);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(account.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  ref.read(selectedAccountIdProvider.notifier).state =
                      selected ? account.id : null;
                },
              ),
            );
          }),

          // Add Account Icon Button
          ActionChip(
            avatar: const Icon(Icons.add, size: 16),
            label: const Text('Add Mailbox'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(
    BuildContext context,
    WidgetRef ref,
    MailCategory selectedCategory,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 8),
      child: Row(
        children: MailCategory.values.map((category) {
          final isSelected = selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(category.label),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) {
                ref.read(selectedCategoryProvider.notifier).state = category;
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
          const SizedBox(height: 14),
          const Text(
            'Inbox Zero',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'No messages in this category or mailbox.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
