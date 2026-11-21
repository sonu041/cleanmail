import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../domain/models/sender_summary.dart';
import '../../../inbox/presentation/widgets/set_preferred_tag_dialog.dart';
import '../../../providers.dart';
import 'sender_emails_screen.dart';

class CleanSweepScreen extends ConsumerWidget {
  const CleanSweepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(senderSummariesStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isNerd = AppTheme.isNerd(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_delete_outlined, size: 22),
            SizedBox(width: 8),
            Text('Sender Sweep', style: TextStyle(fontSize: 19)),
          ],
        ),
      ),
      body: summariesAsync.when(
        data: (summaries) {
          if (summaries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: (isNerd ? AppTheme.nerdPrimary : const Color(0xFF10B981)).withOpacity(0.8),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Clutter Found!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All active senders have zero remaining messages.',
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      fontFamily: AppTheme.fontFamily(context),
                    ),
                  ),
                ],
              ),
            );
          }

          final totalMessages = summaries.fold<int>(0, (sum, s) => sum + s.totalCount);

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(AppTheme.isNerd(context) ? 4 : 12),
                  border: Border.all(
                    color: AppTheme.border(context),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.lightPrimary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cleaning_services_outlined,
                        color: AppTheme.lightPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$totalMessages emails across ${summaries.length} senders',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sweep out unwanted newsletters or bulk updates with 1 tap.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary(context),
                              fontFamily: AppTheme.fontFamily(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Top Senders by Volume',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),

              // Senders list
              ...summaries.map((summary) => _buildSenderCard(context, ref, summary, isDark)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading senders: $err')),
      ),
    );
  }

  Widget _buildSenderCard(
    BuildContext context,
    WidgetRef ref,
    SenderSummary summary,
    bool isDark,
  ) {
    void openSenderEmails() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SenderEmailsScreen(
            senderEmail: summary.senderEmail,
            senderName: summary.senderName,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('sender_card_${summary.senderEmail}'),
        onTap: openSenderEmails,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.lightPrimary.withOpacity(0.12),
                  child: Text(
                    summary.senderName.isNotEmpty
                        ? summary.senderName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.lightPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.senderName,
                        key: ValueKey('sender_title_${summary.senderEmail}'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        summary.senderEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.lightPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${summary.totalCount} emails',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppTheme.lightPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppTheme.textSecondary(context),
                ),
              ],
            ),
            if (summary.latestSubject.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Latest: "${summary.latestSubject}"',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            // Actions (Wrap to avoid overflow on narrow screens)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Set Preferred Tag
                  TextButton.icon(
                    key: ValueKey('pref_tag_btn_${summary.senderEmail}'),
                    icon: const Icon(Icons.label_outlined, size: 16),
                    label: const Text('Set Tag', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    onPressed: () {
                      showSetPreferredTagDialog(
                        context: context,
                        ref: ref,
                        senderEmail: summary.senderEmail,
                        senderName: summary.senderName,
                      );
                    },
                  ),
                  // Delete All
                  FilledButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete All', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.deleteColor,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Delete all from ${summary.senderName}?'),
                        content: Text(
                          'This will delete messages from ${summary.senderEmail}.\n\nNote: Locked emails are protected and will NOT be deleted.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.deleteColor),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete All'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      final count = await ref
                          .read(messageRepositoryProvider)
                          .deleteAllFromSender(summary.senderEmail);
                      if (context.mounted) {
                        SnackBarUtils.showAutoHideSnackBar(
                          messenger: ScaffoldMessenger.of(context),
                          message: 'Deleted $count emails from ${summary.senderName}',
                          duration: const Duration(seconds: 5),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
}
}
