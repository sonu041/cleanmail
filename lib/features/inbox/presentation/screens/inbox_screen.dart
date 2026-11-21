import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../domain/models/account.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/message.dart';
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

class _InboxScreenState extends ConsumerState<InboxScreen>
    with SingleTickerProviderStateMixin {
  bool _isSearching = false;
  bool _isSyncingOlder = false;
  bool _isFilterExpanded = false;
  late AnimationController _filterAnimController;
  late Animation<Offset> _filterSlideAnimation;
  late Animation<double> _filterSizeAnimation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filterAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _filterSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Starts from the right
      end: Offset.zero,              // Slides into place from right to left
    ).animate(CurvedAnimation(
      parent: _filterAnimController,
      curve: Curves.easeInOutCubic,
    ));

    _filterSizeAnimation = CurvedAnimation(
      parent: _filterAnimController,
      curve: Curves.easeInOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messageRepositoryProvider).deduplicateMessages();
    });
  }

  @override
  void dispose() {
    _filterAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFilterSection() {
    setState(() {
      _isFilterExpanded = !_isFilterExpanded;
      if (_isFilterExpanded) {
        _filterAnimController.forward();
      } else {
        _filterAnimController.reverse();
      }
    });
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
    final accountCounts = ref.watch(messageCountsByAccountProvider).asData?.value ?? {};
    final categoryCounts = ref.watch(messageCountsByCategoryProvider).asData?.value ?? {};
    final unreadCount = ref.watch(unreadCountProvider).asData?.value ?? 0;
    final isUnreadOnly = ref.watch(unreadOnlyFilterProvider);

    // Filter active status
    final hasActiveFilter = selectedAccountId != null ||
        selectedCategory != MailCategory.all ||
        isUnreadOnly;

    // Find active account email or title
    String activeTitle = 'All Inboxes';
    if (selectedAccountId != null && accounts.isNotEmpty) {
      final acc = accounts.firstWhere(
        (a) => a.id == selectedAccountId,
        orElse: () => accounts.first,
      );
      activeTitle = acc.email.isNotEmpty ? acc.email : acc.displayName;
    }

    // Multi-selection state
    final isSelectionMode = ref.watch(isSelectionModeProvider);
    final selectedIds = ref.watch(selectedMessageIdsProvider);

    return PopScope(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isSelectionMode) {
          ref.read(isSelectionModeProvider.notifier).state = false;
          ref.read(selectedMessageIdsProvider.notifier).state = <String>{};
        }
      },
      child: Scaffold(
        appBar: isSelectionMode
            ? _buildSelectionAppBar(context, ref, selectedIds, messages, isDark)
            : _buildNormalAppBar(
                context,
                ref,
                accounts,
                selectedAccountId,
                activeTitle,
                hasActiveFilter,
                isDark,
              ),
      body: Column(
        children: [
          // Collapsible Filter Section (animates in from right to left)
          SizeTransition(
            sizeFactor: _filterSizeAnimation,
            axisAlignment: -1.0,
            child: ClipRect(
              child: SlideTransition(
                position: _filterSlideAnimation,
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity != null && details.primaryVelocity! > 150) {
                      _toggleFilterSection();
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.border(context).withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Multi-Mailbox Single Pane Switcher (Account Chips)
                        _buildAccountBar(
                          context,
                          ref,
                          accounts,
                          selectedAccountId,
                          accountCounts,
                        ),

                        // Category Pills with Unread Filter
                        _buildCategoryBar(
                          context,
                          ref,
                          selectedCategory,
                          categoryCounts,
                          unreadCount,
                          isUnreadOnly,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

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
                await messageRepo.deduplicateMessages();
              },
              child: messages.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: _buildEmptyState(
                          context,
                          isDark,
                          ref,
                          accounts,
                          selectedAccountId,
                          isUnreadOnly,
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: messages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          return _buildSyncOlderEmailsFooter(
                            context,
                            ref,
                            accounts,
                            selectedAccountId,
                          );
                        }
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
    ),
  );
}

  AppBar _buildNormalAppBar(
    BuildContext context,
    WidgetRef ref,
    List<MailAccount> accounts,
    String? selectedAccountId,
    String activeTitle,
    bool hasActiveFilter,
    bool isDark,
  ) {
    return AppBar(
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
                  'CleanMail',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: AppTheme.fontFamily(context),
                  ),
                ),
                Text(
                  activeTitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary(context),
                    fontWeight: FontWeight.normal,
                    fontFamily: AppTheme.fontFamily(context),
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

        // Top-Right Filter Overflow Button (Toggles filter section with right-to-left animation)
        IconButton(
          key: const ValueKey('toggle_filters_btn'),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                _isFilterExpanded ? Icons.tune : Icons.tune_rounded,
                color: _isFilterExpanded
                    ? (AppTheme.isNerd(context)
                        ? AppTheme.nerdPrimary
                        : (isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary))
                    : null,
              ),
              if (hasActiveFilter && !_isFilterExpanded)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.isNerd(context)
                          ? AppTheme.nerdPrimary
                          : const Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          tooltip: _isFilterExpanded ? 'Collapse Filters' : 'Show Filters',
          onPressed: _toggleFilterSection,
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar(
    BuildContext context,
    WidgetRef ref,
    Set<String> selectedIds,
    List<MailMessage> messages,
    bool isDark,
  ) {
    final isNerd = AppTheme.isNerd(context);
    final allSelected = messages.isNotEmpty && selectedIds.length == messages.length;

    return AppBar(
      leading: IconButton(
        key: const ValueKey('exit_selection_mode_btn'),
        icon: const Icon(Icons.close),
        tooltip: 'Cancel selection',
        onPressed: () {
          ref.read(isSelectionModeProvider.notifier).state = false;
          ref.read(selectedMessageIdsProvider.notifier).state = <String>{};
        },
      ),
      title: Text(
        isNerd
            ? '> ${selectedIds.length}_SELECTED'
            : '${selectedIds.length} selected',
        style: TextStyle(
          fontFamily: AppTheme.fontFamily(context),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        // Select All / Deselect All
        IconButton(
          key: const ValueKey('select_all_toggle_btn'),
          icon: Icon(
            allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
          ),
          tooltip: allSelected ? 'Deselect All' : 'Select All',
          onPressed: () {
            if (allSelected) {
              ref.read(selectedMessageIdsProvider.notifier).state = <String>{};
            } else {
              ref.read(selectedMessageIdsProvider.notifier).state =
                  messages.map((m) => m.id).toSet();
            }
          },
        ),

        // Lock / Unlock Selected
        IconButton(
          key: const ValueKey('lock_toggle_selected_btn'),
          icon: const Icon(Icons.lock_outline),
          tooltip: 'Lock / Unlock selected',
          onPressed: selectedIds.isEmpty
              ? null
              : () => _handleToggleLockSelected(context, ref, selectedIds, messages),
        ),

        // Delete Selected
        IconButton(
          key: const ValueKey('delete_selected_btn'),
          icon: Icon(
            Icons.delete_outline_rounded,
            color: selectedIds.isEmpty
                ? (isDark ? Colors.white38 : Colors.black26)
                : (isNerd ? AppTheme.nerdAccentRed : AppTheme.deleteColor),
          ),
          tooltip: 'Delete selected',
          onPressed: selectedIds.isEmpty
              ? null
              : () => _handleDeleteSelected(context, ref, selectedIds, messages),
        ),
      ],
    );
  }

  Future<void> _handleToggleLockSelected(
    BuildContext context,
    WidgetRef ref,
    Set<String> selectedIds,
    List<MailMessage> messages,
  ) async {
    final selectedMsgs = messages.where((m) => selectedIds.contains(m.id)).toList();
    if (selectedMsgs.isEmpty) return;

    final anyUnlocked = selectedMsgs.any((m) => !m.isLocked);
    final targetLocked = anyUnlocked;

    final repo = ref.read(messageRepositoryProvider);
    for (final msg in selectedMsgs) {
      await repo.setLocked(msg.id, targetLocked);
    }

    if (context.mounted) {
      SnackBarUtils.showAutoHideSnackBar(
        messenger: ScaffoldMessenger.of(context),
        message: targetLocked
            ? 'Locked ${selectedMsgs.length} email(s)'
            : 'Unlocked ${selectedMsgs.length} email(s)',
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _handleDeleteSelected(
    BuildContext context,
    WidgetRef ref,
    Set<String> selectedIds,
    List<MailMessage> messages,
  ) async {
    final selectedMsgs = messages.where((m) => selectedIds.contains(m.id)).toList();
    if (selectedMsgs.isEmpty) return;

    final lockedMsgs = selectedMsgs.where((m) => m.isLocked).toList();
    final unlockedMsgs = selectedMsgs.where((m) => !m.isLocked).toList();

    if (lockedMsgs.isNotEmpty && unlockedMsgs.isEmpty) {
      SnackBarUtils.showAutoHideSnackBar(
        messenger: ScaffoldMessenger.of(context),
        message: 'Selected email(s) are locked. Unlock them first to delete.',
        duration: const Duration(seconds: 5),
      );
      return;
    }

    final isNerd = AppTheme.isNerd(context);
    final count = unlockedMsgs.length;

    final String dialogContent;
    if (lockedMsgs.isNotEmpty) {
      dialogContent = isNerd
          ? 'Notice: ${lockedMsgs.length} locked item(s) are protected and will NOT be deleted.\nMove $count unlocked item(s) to trash?'
          : 'Note: ${lockedMsgs.length} locked email${lockedMsgs.length > 1 ? 's are' : ' is'} protected and will not be deleted.\n\nAre you sure you want to delete the remaining $count unlocked email${count > 1 ? 's' : ''}?';
    } else {
      dialogContent = isNerd
          ? 'Move $count selected items to trash?'
          : 'Are you sure you want to delete $count selected email${count > 1 ? 's' : ''}?';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isNerd ? '> CONFIRM_BATCH_DELETE' : 'Delete $count email${count > 1 ? 's' : ''}?',
          style: TextStyle(fontFamily: AppTheme.fontFamily(context)),
        ),
        content: Text(
          dialogContent,
          style: TextStyle(fontFamily: AppTheme.fontFamily(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.deleteColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final repo = ref.read(messageRepositoryProvider);
      final messenger = ScaffoldMessenger.of(context);

      final deletedMessages = await repo.deleteMultiple(unlockedMsgs.map((m) => m.id).toList());

      // Exit selection mode
      ref.read(isSelectionModeProvider.notifier).state = false;
      ref.read(selectedMessageIdsProvider.notifier).state = <String>{};

      if (context.mounted) {
        final String messageText = lockedMsgs.isNotEmpty
            ? 'Deleted ${deletedMessages.length} email${deletedMessages.length > 1 ? 's' : ''} (${lockedMsgs.length} locked kept)'
            : 'Deleted ${deletedMessages.length} email${deletedMessages.length > 1 ? 's' : ''}';

        SnackBarUtils.showAutoHideSnackBar(
          messenger: messenger,
          message: messageText,
          onUndo: () {
            repo.restoreMessages(deletedMessages);
          },
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  Widget _buildAccountBar(
    BuildContext context,
    WidgetRef ref,
    List<MailAccount> accounts,
    String? selectedAccountId,
    Map<String, int> accountCounts,
  ) {
    final allCount = accountCounts.values.fold(0, (sum, c) => sum + c);
    final isNerd = AppTheme.isNerd(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // "All Inboxes" chip
          ChoiceChip(
            label: Text(isNerd ? 'All Inboxes [$allCount]' : 'All Inboxes ($allCount)'),
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
            final count = accountCounts[account.id] ?? 0;
            // Show only the first part of the email ID (e.g. 'sonu041' instead of 'sonu041@gmail.com')
            final chipPrefix = account.email.contains('@')
                ? account.email.split('@').first
                : (account.displayName.isNotEmpty ? account.displayName : account.email);
            final chipLabel = isNerd ? '$chipPrefix [$count]' : '$chipPrefix ($count)';

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
                label: Text(chipLabel),
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
          const SizedBox(width: 8),

          // Collapse Filters Button
          ActionChip(
            key: const ValueKey('hide_filters_btn'),
            avatar: const Icon(Icons.close, size: 14),
            label: Text(isNerd ? 'HIDE' : 'Hide'),
            tooltip: 'Collapse filters',
            onPressed: _toggleFilterSection,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(
    BuildContext context,
    WidgetRef ref,
    MailCategory selectedCategory,
    Map<String, int> categoryCounts,
    int unreadCount,
    bool isUnreadOnly,
  ) {
    final allCategoryCount = categoryCounts.values.fold(0, (sum, c) => sum + c);
    final isNerd = AppTheme.isNerd(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 8),
      child: Row(
        children: [
          // Unread Filter Button
          FilterChip(
            key: const ValueKey('unread_filter_btn'),
            avatar: isNerd
                ? Text(
                    isUnreadOnly ? '[*]' : '[ ]',
                    style: TextStyle(
                      fontFamily: AppTheme.nerdFontFamily,
                      fontSize: 11,
                      color: isUnreadOnly ? AppTheme.nerdPrimary : AppTheme.nerdTextSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isUnreadOnly
                          ? (isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary)
                          : const Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
            label: Text(
              isNerd ? 'UNREAD [$unreadCount]' : 'Unread ($unreadCount)',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily(context),
                fontWeight: isUnreadOnly ? FontWeight.bold : FontWeight.w600,
                color: isUnreadOnly
                    ? (isNerd
                        ? AppTheme.nerdPrimary
                        : (isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary))
                    : null,
              ),
            ),
            selected: isUnreadOnly,
            showCheckmark: false,
            onSelected: (selected) {
              ref.read(unreadOnlyFilterProvider.notifier).state = selected;
            },
          ),
          const SizedBox(width: 4),
          // Subtle vertical divider between Unread filter and Categories
          Container(
            height: 20,
            width: 1,
            color: AppTheme.border(context).withOpacity(0.4),
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          const SizedBox(width: 4),

          // Category Chips
          ...MailCategory.values.map((category) {
            final isSelected = selectedCategory == category;
            final count = category == MailCategory.all
                ? allCategoryCount
                : (categoryCounts[category.name.toLowerCase()] ?? 0);
            final labelText = isNerd
                ? '${category.label} [$count]'
                : '${category.label} ($count)';

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(labelText),
                selected: isSelected,
                showCheckmark: false,
                onSelected: (_) {
                  ref.read(selectedCategoryProvider.notifier).state = category;
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    WidgetRef ref,
    List<MailAccount> accounts,
    String? selectedAccountId,
    bool isUnreadOnly,
  ) {
    final hasGmailAccounts = accounts.any((a) => a.provider == MailProvider.gmail);
    final isNerd = AppTheme.isNerd(context);

    if (isUnreadOnly) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              size: 64,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              isNerd ? '> ALL_READ: ZERO_UNREAD' : 'All Caught Up!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: AppTheme.fontFamily(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isNerd
                  ? '// No unread messages in this view'
                  : 'No unread messages in this mailbox or category.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                fontFamily: AppTheme.fontFamily(context),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(unreadOnlyFilterProvider.notifier).state = false;
              },
              icon: const Icon(Icons.clear_all, size: 18),
              label: Text(
                isNerd ? '> SHOW_ALL_EMAILS' : 'Show All Emails',
                style: TextStyle(fontFamily: AppTheme.fontFamily(context)),
              ),
            ),
          ],
        ),
      );
    }

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
          if (hasGmailAccounts) ...[
            const SizedBox(height: 12),
            _buildSyncOlderEmailsFooter(context, ref, accounts, selectedAccountId),
          ],
        ],
      ),
    );
  }

  Future<void> _handleSyncOlderEmails(
    BuildContext context,
    WidgetRef ref,
    List<MailAccount> accounts,
    String? selectedAccountId,
  ) async {
    if (_isSyncingOlder) return;

    final googleAuth = ref.read(googleAuthServiceProvider);
    final messageRepo = ref.read(messageRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final isNerd = AppTheme.isNerd(context);
    final fontFamily = AppTheme.fontFamily(context);

    final targetAccounts = accounts.where((a) {
      if (a.provider != MailProvider.gmail) return false;
      if (selectedAccountId != null && selectedAccountId.isNotEmpty) {
        return a.id == selectedAccountId;
      }
      return true;
    }).toList();

    if (targetAccounts.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isNerd
                ? '> NO_GMAIL_ACCOUNT_CONNECTED'
                : 'No connected Gmail mailbox found to sync older emails.',
            style: TextStyle(fontFamily: fontFamily),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() {
      _isSyncingOlder = true;
    });

    int totalSynced = 0;
    String? syncError;

    try {
      for (final acc in targetAccounts) {
        final result = await googleAuth.syncOlderGmailMessages(
          account: acc,
          messageRepo: messageRepo,
          count: 20,
        );
        totalSynced += result.syncedCount;
        if (result.error != null) {
          syncError = result.error;
        }
      }

      if (!mounted) return;

      if (syncError != null && totalSynced == 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isNerd ? '> ERROR: $syncError' : 'Sync error: $syncError',
              style: TextStyle(fontFamily: fontFamily),
            ),
            backgroundColor: AppTheme.deleteColor,
            duration: const Duration(seconds: 5),
          ),
        );
      } else if (totalSynced > 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isNerd
                  ? '> SYNC_SUCCESS: $totalSynced older emails loaded'
                  : 'Synced $totalSynced older emails.',
              style: TextStyle(fontFamily: fontFamily),
            ),
            backgroundColor: isNerd ? AppTheme.nerdSurface : AppTheme.archiveColor,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isNerd ? '> NO_OLDER_EMAILS_FOUND' : 'No older emails found to sync.',
              style: TextStyle(fontFamily: fontFamily),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isNerd ? '> EXCEPTION: $e' : 'Failed to sync older emails: $e',
            style: TextStyle(fontFamily: fontFamily),
          ),
          backgroundColor: AppTheme.deleteColor,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingOlder = false;
        });
      }
    }
  }

  Widget _buildSyncOlderEmailsFooter(
    BuildContext context,
    WidgetRef ref,
    List<MailAccount> accounts,
    String? selectedAccountId,
  ) {
    final isNerd = AppTheme.isNerd(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: isNerd
            ? InkWell(
                key: const ValueKey('sync_older_emails_btn'),
                onTap: _isSyncingOlder
                    ? null
                    : () => _handleSyncOlderEmails(context, ref, accounts, selectedAccountId),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.nerdSurface,
                    border: Border.all(
                      color: _isSyncingOlder ? AppTheme.nerdTextSecondary : AppTheme.nerdPrimary,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSyncingOlder) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppTheme.nerdPrimary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          '> FETCHING_20_OLD_EMAILS...',
                          style: TextStyle(
                            fontFamily: AppTheme.nerdFontFamily,
                            fontSize: 13,
                            color: AppTheme.nerdPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.history,
                          size: 16,
                          color: AppTheme.nerdPrimary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '> SYNC_NEXT_20_OLD_EMAILS',
                          style: TextStyle(
                            fontFamily: AppTheme.nerdFontFamily,
                            fontSize: 13,
                            color: AppTheme.nerdPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : OutlinedButton.icon(
                key: const ValueKey('sync_older_emails_btn'),
                onPressed: _isSyncingOlder
                    ? null
                    : () => _handleSyncOlderEmails(context, ref, accounts, selectedAccountId),
                icon: _isSyncingOlder
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.history, size: 18),
                label: Text(
                  _isSyncingOlder ? 'Syncing next 20 older emails...' : 'Sync Next 20 Older Emails',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
      ),
    );
  }
}
