import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/log_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../providers.dart';

class LogsScreen extends ConsumerStatefulWidget {
  final LogCategory? initialCategory;
  final LogLevel? initialLevel;

  const LogsScreen({
    super.key,
    this.initialCategory,
    this.initialLevel,
  });

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  late LogCategory _selectedCategory;
  LogLevel? _selectedLevel;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? LogCategory.all;
    _selectedLevel = widget.initialLevel;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logService = ref.watch(logServiceProvider);
    final logsAsync = ref.watch(logsStreamProvider);
    final allLogs = logsAsync.value ?? logService.logs;
    final isNerd = AppTheme.isNerd(context);

    // Apply filtering
    final filteredLogs = allLogs.where((log) {
      if (_selectedCategory != LogCategory.all && log.category != _selectedCategory) {
        return false;
      }
      if (_selectedLevel != null && log.level != _selectedLevel) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = log.title.toLowerCase().contains(q);
        final matchesDetails = log.details.toLowerCase().contains(q);
        final matchesCat = log.category.label.toLowerCase().contains(q);
        if (!matchesTitle && !matchesDetails && !matchesCat) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Operation Logs',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copy All Logs to Clipboard',
            onPressed: () => _copyAllLogs(context, logService),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear All Logs',
            onPressed: allLogs.isEmpty ? null : () => _confirmClearLogs(context, logService),
          ),
        ],
      ),
      body: Column(
        children: [
          // KPI / Operation Summary Cards
          _buildMetricsHeader(context, logService, allLogs.length, isNerd),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: isNerd ? 'grep "query"...' : 'Search operations, errors, emails...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),

          // Category & Severity Filter Chips
          _buildFilterBar(context, isNerd),

          const Divider(height: 1),

          // Logs List View
          Expanded(
            child: filteredLogs.isEmpty
                ? _buildEmptyState(context, isNerd)
                : ListView.builder(
                    itemCount: filteredLogs.length,
                    itemBuilder: (ctx, index) {
                      final item = filteredLogs[index];
                      return _buildLogTile(ctx, item, isNerd);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsHeader(
    BuildContext context,
    LogService logService,
    int totalCount,
    bool isNerd,
  ) {
    final dateFormat = DateFormat('HH:mm:ss');
    final lastAuthStr = logService.lastLoginOrTokenRefresh != null
        ? dateFormat.format(logService.lastLoginOrTokenRefresh!)
        : 'None yet';
    final lastSyncStr = logService.lastSyncTime != null
        ? dateFormat.format(logService.lastSyncTime!)
        : 'None yet';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppTheme.surface(context),
      child: Column(
        children: [
          Row(
            children: [
              _buildMetricCard(
                context,
                title: isNerd ? 'MAILS_SYNCED' : 'Mails Synced',
                value: '${logService.totalMailsSynced}',
                icon: Icons.sync,
                color: isNerd ? AppTheme.nerdPrimary : AppTheme.lightPrimary,
                isNerd: isNerd,
              ),
              const SizedBox(width: 8),
              _buildMetricCard(
                context,
                title: isNerd ? 'LAST_TOKEN_AUTH' : 'Last Auth/Token',
                value: lastAuthStr,
                icon: Icons.key_outlined,
                color: isNerd ? AppTheme.nerdAccentCyan : AppTheme.archiveColor,
                isNerd: isNerd,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMetricCard(
                context,
                title: isNerd ? 'LAST_DELTA_SYNC' : 'Last Delta Sync',
                value: lastSyncStr,
                icon: Icons.cloud_done_outlined,
                color: isNerd ? AppTheme.nerdAccentYellow : Colors.blueGrey,
                isNerd: isNerd,
              ),
              const SizedBox(width: 8),
              _buildMetricCard(
                context,
                title: isNerd ? 'LOG_ENTRIES' : 'Logged Events',
                value: '$totalCount',
                icon: Icons.receipt_long_outlined,
                color: isNerd ? AppTheme.nerdTextPrimary : Colors.deepOrange,
                isNerd: isNerd,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_delete_outlined,
                size: 13,
                color: AppTheme.textSecondary(context),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  isNerd
                      ? 'AUTO_PURGE: INFO & SUCCESS > 100 PURGED | WARNING & ERROR PRESERVED'
                      : 'Auto-purging info & success logs older than 100 (Warnings & Errors preserved)',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary(context),
                    fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isNerd,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isNerd ? AppTheme.nerdBg : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(isNerd ? 4 : 8),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary(context),
                      fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                      fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, bool isNerd) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          // Category Chips
          ...LogCategory.values.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(isNerd ? '[${cat.code}]' : cat.label),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedCategory = cat);
                },
              ),
            );
          }),

          const SizedBox(width: 8),
          // Level Filters (Errors only, Warnings, etc.)
          ...LogLevel.values.map((lvl) {
            final isSelected = _selectedLevel == lvl;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                avatar: Icon(
                  _levelIcon(lvl),
                  size: 14,
                  color: _levelColor(lvl, isNerd),
                ),
                label: Text(lvl.code),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedLevel = selected ? lvl : null);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLogTile(BuildContext context, AppLog log, bool isNerd) {
    final timeStr = DateFormat('HH:mm:ss').format(log.timestamp);
    final dateStr = DateFormat('MMM dd').format(log.timestamp);
    final color = _levelColor(log.level, isNerd);

    return InkWell(
      onTap: () => _showLogDetailDialog(context, log, isNerd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.border(context), width: 0.8),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Icon & Category tag
            Container(
              margin: const EdgeInsets.only(top: 2, right: 10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(_levelIcon(log.level), size: 16, color: color),
            ),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Category Tag
                      Text(
                        isNerd ? '[${log.category.code}]' : log.category.code,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isNerd ? AppTheme.nerdAccentCyan : color,
                          fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log.title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary(context),
                            fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$timeStr • $dateStr',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary(context),
                          fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                        ),
                      ),
                    ],
                  ),
                  if (log.details.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      log.details,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary(context),
                        fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isNerd) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isNerd ? Icons.terminal : Icons.receipt_long_outlined,
            size: 48,
            color: AppTheme.textSecondary(context).withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            isNerd ? '> [LOGS EMPTY] Zero operations found.' : 'No operation logs found',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppTheme.textPrimary(context),
              fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Operations like email syncs, logins, and label modifications appear here.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary(context),
              fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showLogDetailDialog(BuildContext context, AppLog log, bool isNerd) {
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(log.timestamp);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(_levelIcon(log.level), color: _levelColor(log.level, isNerd), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                log.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Timestamp', timeStr, isNerd),
              _detailRow('Category', log.category.label, isNerd),
              _detailRow('Severity', log.level.label, isNerd),
              const SizedBox(height: 10),
              const Text('Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isNerd ? Colors.black : Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: SelectableText(
                  log.details.isNotEmpty ? log.details : '(No additional details)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontFamily: AppTheme.nerdFontFamily,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
              if (log.metadata != null && log.metadata!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Metadata (JSON):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isNerd ? Colors.black : Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(log.metadata),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFamily: AppTheme.nerdFontFamily,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Entry'),
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: '[$timeStr] [${log.level.code}] [${log.category.code}] ${log.title}\n${log.details}\n${log.metadata != null ? jsonEncode(log.metadata) : ""}',
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log entry copied to clipboard')),
              );
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isNerd) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary(context),
                fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyAllLogs(BuildContext context, LogService logService) {
    final report = logService.exportLogsAsText();
    Clipboard.setData(ClipboardData(text: report));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All operation logs copied to clipboard!'),
        backgroundColor: AppTheme.archiveColor,
      ),
    );
  }

  Future<void> _confirmClearLogs(BuildContext context, LogService logService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Operation Logs?'),
        content: const Text(
          'This will purge all recorded audit logs and reset the sync metrics counters.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.deleteColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await logService.clearLogs();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All logs cleared.')),
      );
    }
  }

  IconData _levelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Icons.error_outline;
      case LogLevel.warning:
        return Icons.warning_amber_rounded;
      case LogLevel.success:
        return Icons.check_circle_outline;
      case LogLevel.info:
        return Icons.info_outline;
    }
  }

  Color _levelColor(LogLevel level, bool isNerd) {
    if (isNerd) {
      switch (level) {
        case LogLevel.error:
          return AppTheme.nerdAccentRed;
        case LogLevel.warning:
          return AppTheme.nerdAccentYellow;
        case LogLevel.success:
          return AppTheme.nerdPrimary;
        case LogLevel.info:
          return AppTheme.nerdAccentCyan;
      }
    } else {
      switch (level) {
        case LogLevel.error:
          return AppTheme.deleteColor;
        case LogLevel.warning:
          return Colors.amber.shade800;
        case LogLevel.success:
          return AppTheme.archiveColor;
        case LogLevel.info:
          return AppTheme.lightPrimary;
      }
    }
  }
}
