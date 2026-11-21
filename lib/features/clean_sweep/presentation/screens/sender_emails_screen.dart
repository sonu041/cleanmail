import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../inbox/presentation/widgets/email_tile.dart';
import '../../../inbox/presentation/widgets/set_preferred_tag_dialog.dart';
import '../../../providers.dart';

class SenderEmailsScreen extends ConsumerWidget {
  final String senderEmail;
  final String senderName;

  const SenderEmailsScreen({
    super.key,
    required this.senderEmail,
    required this.senderName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(senderMessagesStreamProvider(senderEmail));
    final accounts = ref.watch(accountsStreamProvider).asData?.value ?? [];
    final isNerd = AppTheme.isNerd(context);
    final displayName = senderName.isNotEmpty ? senderName : senderEmail;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: AppTheme.fontFamily(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              senderEmail,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary(context),
                fontWeight: FontWeight.normal,
                fontFamily: AppTheme.fontFamily(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Preferred Tag
          IconButton(
            key: const ValueKey('sender_pref_tag_btn'),
            icon: const Icon(Icons.label_outlined),
            tooltip: 'Set preferred tag for sender',
            onPressed: () {
              final firstMsg = messagesAsync.valueOrNull?.firstOrNull;
              showSetPreferredTagDialog(
                context: context,
                ref: ref,
                senderEmail: senderEmail,
                senderName: senderName,
                currentCategory: firstMsg?.category,
                currentCustomTag: firstMsg?.customTag,
              );
            },
          ),
          // Delete All from this sender
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: isNerd ? AppTheme.nerdAccentRed : AppTheme.deleteColor,
            ),
            tooltip: 'Delete all from sender',
            onPressed: () => _handleDeleteAll(context, ref),
          ),
        ],
      ),
      body: messagesAsync.when(
        data: (messages) {
          if (messages.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: const Color(0xFF10B981).withOpacity(0.8),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isNerd ? '> ALL_EMAILS_SWEPT' : 'All Emails Swept!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppTheme.fontFamily(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No active messages remaining from $senderEmail.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary(context),
                        fontFamily: AppTheme.fontFamily(context),
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back to Sender Sweep'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            );
          }

          final unreadCount = messages.where((m) => !m.isRead).length;

          return Column(
            children: [
              // Summary Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.border(context).withOpacity(0.6),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.lightPrimary.withOpacity(0.12),
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.lightPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${messages.length} email${messages.length > 1 ? 's' : ''}'
                            '${unreadCount > 0 ? ' • $unreadCount unread' : ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Swipe left to delete',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary(context),
                              fontFamily: AppTheme.fontFamily(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('sender_header_pref_tag_btn'),
                      icon: const Icon(Icons.label_outline, size: 14),
                      label: const Text('Set Tag', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      onPressed: () {
                        final firstMsg = messages.firstOrNull;
                        showSetPreferredTagDialog(
                          context: context,
                          ref: ref,
                          senderEmail: senderEmail,
                          senderName: senderName,
                          currentCategory: firstMsg?.category,
                          currentCustomTag: firstMsg?.customTag,
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Email Tiles List
              Expanded(
                child: ListView.builder(
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
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            'Error loading emails: $err',
            style: TextStyle(fontFamily: AppTheme.fontFamily(context)),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDeleteAll(BuildContext context, WidgetRef ref) async {
    final isNerd = AppTheme.isNerd(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isNerd ? '> CONFIRM_PURGE_SENDER' : 'Delete all from $senderName?',
          style: TextStyle(fontFamily: AppTheme.fontFamily(context)),
        ),
        content: Text(
          'This will delete messages from $senderEmail.\n\nNote: Locked emails are protected and will NOT be deleted.',
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
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final count = await ref
          .read(messageRepositoryProvider)
          .deleteAllFromSender(senderEmail);
      if (context.mounted) {
        SnackBarUtils.showAutoHideSnackBar(
          messenger: ScaffoldMessenger.of(context),
          message: 'Deleted $count emails from $senderName',
          duration: const Duration(seconds: 5),
        );
      }
    }
  }
}
