import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/local/database.dart';
import '../../../../domain/models/account.dart';
import '../../../providers.dart';

enum DashboardDateRange {
  today('Today'),
  last7Days('7 Days'),
  last30Days('30 Days'),
  allTime('All Time');

  final String label;
  const DashboardDateRange(this.label);

  DateTime? get cutoffDate {
    final now = DateTime.now();
    switch (this) {
      case DashboardDateRange.today:
        return DateTime(now.year, now.month, now.day);
      case DashboardDateRange.last7Days:
        return now.subtract(const Duration(days: 7));
      case DashboardDateRange.last30Days:
        return now.subtract(const Duration(days: 30));
      case DashboardDateRange.allTime:
        return null;
    }
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardDateRange _selectedRange = DashboardDateRange.allTime;
  String? _selectedAccountId; // null means "All Inboxes"

  @override
  Widget build(BuildContext context) {
    final isNerd = AppTheme.isNerd(context);
    final db = ref.watch(databaseProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: TextStyle(
            fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading accounts: $err')),
        data: (loadedAccounts) {
          return StreamBuilder<List<MetricEventEntry>>(
            stream: db.watchMetricEvents(
              since: _selectedRange.cutoffDate,
              accountId: _selectedAccountId,
            ),
            builder: (context, snapshot) {
              final events = snapshot.data ?? [];

              // Calculate metrics from events
              int syncedCount = 0;
              int deletedCount = 0;
              int unsubscribedCount = 0;
              int lockActionsCount = 0;

              for (final ev in events) {
                switch (ev.eventType.toLowerCase()) {
                  case 'sync':
                    syncedCount += ev.count;
                    break;
                  case 'delete':
                    deletedCount += ev.count;
                    break;
                  case 'unsubscribe':
                    unsubscribedCount += ev.count;
                    break;
                  case 'lock':
                    lockActionsCount += ev.count;
                    break;
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. DATE RANGE FILTER
                    _buildSectionTitle(
                      context,
                      isNerd ? '// TIME PERIOD' : 'Time Period',
                      isNerd,
                    ),
                    const SizedBox(height: 8),
                    _buildDateRangeSelector(context, isNerd),
                    const SizedBox(height: 16),

                    // 2. MAILBOX / ACCOUNT FILTER
                    _buildSectionTitle(
                      context,
                      isNerd ? '// FILTER BY MAILBOX' : 'Filter by Mailbox',
                      isNerd,
                    ),
                    const SizedBox(height: 8),
                    _buildAccountFilterBar(context, loadedAccounts, isNerd),
                    const SizedBox(height: 20),

                    // 3. CORE METRIC TILES
                    _buildSectionTitle(
                      context,
                      isNerd ? '// CORE TRIAGE METRICS' : 'Core Metrics',
                      isNerd,
                    ),
                    const SizedBox(height: 10),
                    _buildCoreMetricCards(
                      context: context,
                      synced: syncedCount,
                      deleted: deletedCount,
                      unsubscribed: unsubscribedCount,
                      locked: lockActionsCount,
                      isNerd: isNerd,
                    ),
                    const SizedBox(height: 20),

                    // 4. EXTRA EFFICIENCY INSIGHTS
                    _buildSectionTitle(
                      context,
                      isNerd ? '// EFFICIENCY & HYGIENE INSIGHTS' : 'Efficiency & Inbox Insights',
                      isNerd,
                    ),
                    const SizedBox(height: 10),
                    _buildAdditionalInsights(
                      context: context,
                      db: db,
                      synced: syncedCount,
                      deleted: deletedCount,
                      unsubscribed: unsubscribedCount,
                      isNerd: isNerd,
                    ),
                    const SizedBox(height: 20),

                    // 5. RECENT ACTIVITY STREAM
                    _buildSectionTitle(
                      context,
                      isNerd ? '// RECENT TRIAGE ACTIVITY' : 'Recent Activity',
                      isNerd,
                    ),
                    const SizedBox(height: 10),
                    _buildRecentActivityList(
                      context,
                      events,
                      loadedAccounts,
                      isNerd,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, bool isNerd) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: isNerd ? AppTheme.nerdAccentCyan : AppTheme.textSecondary(context),
        letterSpacing: 0.8,
        fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
      ),
    );
  }

  Widget _buildDateRangeSelector(BuildContext context, bool isNerd) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DashboardDateRange.values.map((range) {
        final isSelected = _selectedRange == range;
        return ChoiceChip(
          key: ValueKey('dashboard_range_${range.name}'),
          label: Text(range.label),
          selected: isSelected,
          onSelected: (val) {
            if (val) setState(() => _selectedRange = range);
          },
          selectedColor: isNerd
              ? AppTheme.nerdPrimary.withOpacity(0.25)
              : Theme.of(context).colorScheme.primaryContainer,
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? (isNerd ? AppTheme.nerdPrimary : Theme.of(context).colorScheme.onPrimaryContainer)
                : AppTheme.textPrimary(context),
            fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isNerd ? 2 : 20),
            side: BorderSide(
              color: isSelected
                  ? (isNerd ? AppTheme.nerdPrimary : Theme.of(context).colorScheme.primary)
                  : AppTheme.border(context),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAccountFilterBar(
    BuildContext context,
    List<MailAccount> accounts,
    bool isNerd,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            key: const ValueKey('dashboard_account_all'),
            label: const Text('All Inboxes'),
            avatar: const Icon(Icons.all_inbox, size: 16),
            selected: _selectedAccountId == null,
            onSelected: (val) {
              if (val) setState(() => _selectedAccountId = null);
            },
            selectedColor: isNerd
                ? AppTheme.nerdAccentCyan.withOpacity(0.25)
                : Theme.of(context).colorScheme.secondaryContainer,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: _selectedAccountId == null ? FontWeight.bold : FontWeight.normal,
              color: _selectedAccountId == null
                  ? (isNerd ? AppTheme.nerdAccentCyan : Theme.of(context).colorScheme.onSecondaryContainer)
                  : AppTheme.textPrimary(context),
              fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isNerd ? 2 : 18),
              side: BorderSide(
                color: _selectedAccountId == null
                    ? (isNerd ? AppTheme.nerdAccentCyan : Theme.of(context).colorScheme.secondary)
                    : AppTheme.border(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ...accounts.map((acc) {
            final isSelected = _selectedAccountId == acc.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: ValueKey('dashboard_account_${acc.id}'),
                avatar: CircleAvatar(
                  radius: 8,
                  backgroundColor: Color(acc.avatarColorValue),
                  child: Text(
                    acc.displayName.isNotEmpty ? acc.displayName[0].toUpperCase() : 'M',
                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                label: Text(acc.email.isNotEmpty ? acc.email : acc.displayName),
                selected: isSelected,
                onSelected: (val) {
                  setState(() => _selectedAccountId = val ? acc.id : null);
                },
                selectedColor: isNerd
                    ? AppTheme.nerdAccentCyan.withOpacity(0.25)
                    : Theme.of(context).colorScheme.secondaryContainer,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? (isNerd ? AppTheme.nerdAccentCyan : Theme.of(context).colorScheme.onSecondaryContainer)
                      : AppTheme.textPrimary(context),
                  fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isNerd ? 2 : 18),
                  side: BorderSide(
                    color: isSelected
                        ? (isNerd ? AppTheme.nerdAccentCyan : Theme.of(context).colorScheme.secondary)
                        : AppTheme.border(context),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCoreMetricCards({
    required BuildContext context,
    required int synced,
    required int deleted,
    required int unsubscribed,
    required int locked,
    required bool isNerd,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              context: context,
              key: const ValueKey('metric_card_synced'),
              width: cardWidth,
              title: isNerd ? 'EMAILS_SYNCED' : 'Emails Synced',
              value: '$synced',
              icon: Icons.sync_rounded,
              iconColor: isNerd ? AppTheme.nerdAccentCyan : Colors.blue.shade700,
              bgColor: isNerd ? const Color(0xFF002233) : const Color(0xFFE3F2FD),
              subtitle: 'Indexed into CleanMail',
              isNerd: isNerd,
            ),
            _buildStatCard(
              context: context,
              key: const ValueKey('metric_card_deleted'),
              width: cardWidth,
              title: isNerd ? 'EMAILS_DELETED' : 'Emails Deleted',
              value: '$deleted',
              icon: Icons.delete_sweep_rounded,
              iconColor: isNerd ? AppTheme.nerdAccentRed : Colors.red.shade700,
              bgColor: isNerd ? const Color(0xFF330D0D) : const Color(0xFFFFEBEE),
              subtitle: 'Cleaned from inboxes',
              isNerd: isNerd,
            ),
            _buildStatCard(
              context: context,
              key: const ValueKey('metric_card_unsubscribed'),
              width: cardWidth,
              title: isNerd ? 'UNSUBSCRIBED' : 'Unsubscribed',
              value: '$unsubscribed',
              icon: Icons.unsubscribe_rounded,
              iconColor: isNerd ? AppTheme.nerdAccentYellow : Colors.deepOrange,
              bgColor: isNerd ? const Color(0xFF332200) : const Color(0xFFFFF3E0),
              subtitle: '1-tap unsubscribes',
              isNerd: isNerd,
            ),
            _buildStatCard(
              context: context,
              key: const ValueKey('metric_card_locked'),
              width: cardWidth,
              title: isNerd ? 'EMAILS_LOCKED' : 'Emails Locked',
              value: '$locked',
              icon: Icons.lock_rounded,
              iconColor: isNerd ? AppTheme.nerdPrimary : Colors.amber.shade800,
              bgColor: isNerd ? const Color(0xFF003311) : const Color(0xFFFFFDE7),
              subtitle: 'Deletion protected',
              isNerd: isNerd,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required Key key,
    required double width,
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String subtitle,
    required bool isNerd,
  }) {
    return Container(
      key: key,
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(isNerd ? 4 : 12),
        border: Border.all(
          color: isNerd ? iconColor.withOpacity(0.4) : AppTheme.border(context),
          width: isNerd ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(isNerd ? 2 : 8),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isNerd ? iconColor : AppTheme.textPrimary(context),
                  fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary(context),
              fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary(context),
              fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInsights({
    required BuildContext context,
    required AppDatabase db,
    required int synced,
    required int deleted,
    required int unsubscribed,
    required bool isNerd,
  }) {
    final cleanRatio = (synced + deleted) > 0
        ? ((deleted / (synced + deleted)) * 100).toStringAsFixed(1)
        : '0.0';

    // Estimated storage recovered: ~50KB per deleted email
    final totalKb = deleted * 50;
    final storageLiberated = totalKb >= 1024
        ? '${(totalKb / 1024).toStringAsFixed(1)} MB'
        : '$totalKb KB';

    return StreamBuilder<int>(
      stream: db.watchActiveMessagesCount(accountId: _selectedAccountId),
      builder: (context, activeSnapshot) {
        final activeCount = activeSnapshot.data ?? 0;

        return StreamBuilder<int>(
          stream: db.watchUnreadMessagesCount(accountId: _selectedAccountId),
          builder: (context, unreadSnapshot) {
            final unreadCount = unreadSnapshot.data ?? 0;
            final readCount = (activeCount - unreadCount).clamp(0, activeCount);

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(isNerd ? 4 : 12),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Column(
                children: [
                  _buildInsightRow(
                    context,
                    label: isNerd ? 'CLEAN_PURGE_RATIO' : 'Inbox Declutter Ratio',
                    value: '$cleanRatio% purged',
                    icon: Icons.pie_chart_outline_rounded,
                    color: Colors.teal,
                    isNerd: isNerd,
                  ),
                  const Divider(height: 20),
                  _buildInsightRow(
                    context,
                    label: isNerd ? 'STORAGE_RECLAIMED' : 'Estimated Storage Freed',
                    value: storageLiberated,
                    icon: Icons.storage_rounded,
                    color: Colors.indigo,
                    isNerd: isNerd,
                  ),
                  const Divider(height: 20),
                  _buildInsightRow(
                    context,
                    label: isNerd ? 'TRACKING_PIXELS_BLOCKED' : 'Privacy: Trackers Neutralized',
                    value: '${synced + deleted} blocked',
                    icon: Icons.security_rounded,
                    color: Colors.green,
                    isNerd: isNerd,
                  ),
                  const Divider(height: 20),
                  _buildInsightRow(
                    context,
                    label: isNerd ? 'ACTIVE_INBOX_VOLUME' : 'Current Active Mailbox',
                    value: '$activeCount emails',
                    subtitle: '$unreadCount unread • $readCount read',
                    icon: Icons.mark_email_read_outlined,
                    color: Colors.blueGrey,
                    isNerd: isNerd,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInsightRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isNerd,
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isNerd ? AppTheme.nerdAccentCyan : color,
                        fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary(context),
                    fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityList(
    BuildContext context,
    List<MetricEventEntry> events,
    List<MailAccount> accounts,
    bool isNerd,
  ) {
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(isNerd ? 4 : 10),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Text(
          isNerd ? '[EMPTY] NO ACTIVITY IN SELECTED PERIOD' : 'No activity recorded for this period.',
          style: TextStyle(
            fontSize: 12.5,
            color: AppTheme.textSecondary(context),
            fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
          ),
        ),
      );
    }

    final displayEvents = events.take(15).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(isNerd ? 4 : 12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: displayEvents.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final ev = displayEvents[index];
          final (icon, color) = _getEventIconAndColor(ev.eventType, isNerd);
          final accountEmail = _resolveAccountEmail(ev.accountId, accounts);

          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, size: 14, color: color),
            ),
            title: Text(
              ev.details ?? '${ev.eventType.toUpperCase()} (${ev.count})',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                if (accountEmail.isNotEmpty) ...[
                  Flexible(
                    child: Text(
                      accountEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary(context),
                        fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('•', style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 10)),
                  const SizedBox(width: 6),
                ],
                Text(
                  _formatRelativeTime(ev.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary(context),
                    fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                  ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '+${ev.count}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  (IconData, Color) _getEventIconAndColor(String type, bool isNerd) {
    switch (type.toLowerCase()) {
      case 'sync':
        return (Icons.sync_rounded, isNerd ? AppTheme.nerdAccentCyan : Colors.blue.shade700);
      case 'delete':
        return (Icons.delete_outline_rounded, isNerd ? AppTheme.nerdAccentRed : Colors.red.shade700);
      case 'unsubscribe':
        return (Icons.unsubscribe_rounded, isNerd ? AppTheme.nerdAccentYellow : Colors.deepOrange);
      case 'lock':
        return (Icons.lock_rounded, isNerd ? AppTheme.nerdPrimary : Colors.amber.shade800);
      default:
        return (Icons.check_circle_outline, Colors.teal);
    }
  }

  String _resolveAccountEmail(String? accountId, List<MailAccount> accounts) {
    if (accountId == null || accountId.isEmpty) return '';
    final matched = accounts.where((a) => a.id == accountId).firstOrNull;
    if (matched != null && matched.email.isNotEmpty) return matched.email;
    return accountId.replaceFirst('acc_', '').replaceFirst('google_', '');
  }

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes.clamp(1, 60)}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }
}
