import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../domain/models/account.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/message.dart';
import '../../../providers.dart';
import '../../../reader/presentation/screens/reader_screen.dart';

class EmailTile extends ConsumerWidget {
  final MailMessage message;
  final MailAccount? account;

  const EmailTile({
    super.key,
    required this.message,
    this.account,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Multi-selection state
    final isSelectionMode = ref.watch(isSelectionModeProvider);
    final selectedIds = ref.watch(selectedMessageIdsProvider);
    final isSelected = selectedIds.contains(message.id);
    final isNerd = AppTheme.isNerd(context);

    // Account color indicator
    final accountColor = account != null
        ? Color(account!.avatarColorValue)
        : AppTheme.lightPrimary;

    return Dismissible(
      key: Key(message.id),
      direction: isSelectionMode ? DismissDirection.none : DismissDirection.horizontal,
      background: _buildSwipeAction(
        alignment: Alignment.centerLeft,
        color: AppTheme.archiveColor,
        icon: Icons.archive_outlined,
        label: 'Archive',
      ),
      secondaryBackground: _buildSwipeAction(
        alignment: Alignment.centerRight,
        color: AppTheme.deleteColor,
        icon: Icons.delete_outline,
        label: 'Delete',
      ),
      confirmDismiss: (direction) async {
        final messageRepo = ref.read(messageRepositoryProvider);
        final messenger = ScaffoldMessenger.of(context);

        if (direction == DismissDirection.startToEnd) {
          // Archive
          await messageRepo.archive(message.id, true);
          SnackBarUtils.showAutoHideSnackBar(
            messenger: messenger,
            message: 'Archived "${message.subject}"',
            onUndo: () {
              messageRepo.archive(message.id, false);
            },
            duration: const Duration(seconds: 5),
          );
          return true;
        } else {
          // Delete
          await messageRepo.delete(message.id);
          SnackBarUtils.showAutoHideSnackBar(
            messenger: messenger,
            message: 'Deleted "${message.subject}"',
            onUndo: () {
              messageRepo.restoreMessage(message);
            },
            duration: const Duration(seconds: 5),
          );
          return true;
        }
      },
      child: InkWell(
        onLongPress: () {
          final updated = Set<String>.from(selectedIds);
          if (!isSelectionMode) {
            ref.read(isSelectionModeProvider.notifier).state = true;
            updated.add(message.id);
          } else {
            if (isSelected) {
              updated.remove(message.id);
            } else {
              updated.add(message.id);
            }
          }
          ref.read(selectedMessageIdsProvider.notifier).state = updated;
        },
        onTap: () {
          if (isSelectionMode) {
            final updated = Set<String>.from(selectedIds);
            if (isSelected) {
              updated.remove(message.id);
            } else {
              updated.add(message.id);
            }
            ref.read(selectedMessageIdsProvider.notifier).state = updated;
            return;
          }

          // Mark as read
          if (!message.isRead) {
            ref.read(messageRepositoryProvider).markRead(message.id, true);
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReaderScreen(
                messageId: message.id,
                account: account,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? (isNerd
                    ? AppTheme.nerdPrimary.withOpacity(0.08)
                    : Theme.of(context).primaryColor.withOpacity(0.08))
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: AppTheme.border(context),
                width: 0.8,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selection checkbox indicator in multi-selection mode
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    key: ValueKey('email_checkbox_${message.id}'),
                    size: 20,
                    color: isSelected
                        ? (isNerd ? AppTheme.nerdPrimary : Theme.of(context).primaryColor)
                        : AppTheme.textSecondary(context).withOpacity(0.5),
                  ),
                ),

              // Account dot indicator
              Container(
                margin: const EdgeInsets.only(top: 4, right: 12),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accountColor,
                  shape: BoxShape.circle,
                ),
              ),

              // Email content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sender name & time row
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  message.senderName,
                                  style: TextStyle(
                                    fontWeight: message.isRead
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                    fontSize: 15,
                                    color: AppTheme.textPrimary(context),
                                    fontFamily: AppTheme.fontFamily(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!message.isRead) ...[
                                const SizedBox(width: 6),
                                Container(
                                  key: const ValueKey('unread_indicator_dot'),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppTheme.isNerd(context)
                                        ? AppTheme.nerdPrimary
                                        : const Color(0xFF00C853),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          _formatDate(message.receivedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary(context),
                            fontFamily: AppTheme.fontFamily(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Subject line
                    Text(
                      message.subject,
                      style: TextStyle(
                        fontWeight: message.isRead
                            ? FontWeight.normal
                            : FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary(context),
                        fontFamily: AppTheme.fontFamily(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Pure text snippet
                    Text(
                      message.snippet,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary(context),
                        fontFamily: AppTheme.fontFamily(context),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Badges (Category & 1-Tap Unsubscribe indicator)
                    Row(
                      children: [
                        _buildCategoryChip(context, message.category),
                        if (message.hasUnsubscribeOption) ...[
                          const SizedBox(width: 8),
                          _buildUnsubscribeIndicator(context),
                        ],
                      ],
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

  Widget _buildSwipeAction({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context, MailCategory category) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color fg;

    if (AppTheme.isNerd(context)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFF00220B),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFF005522), width: 0.8),
        ),
        child: Text(
          '[${category.name.toUpperCase()}]',
          style: const TextStyle(
            color: AppTheme.nerdPrimary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: AppTheme.nerdFontFamily,
          ),
        ),
      );
    }

    switch (category) {
      case MailCategory.newsletters:
        bg = isDark ? const Color(0xFF1B3B2B) : const Color(0xFFE8F5E9);
        fg = isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
        break;
      case MailCategory.transactions:
        bg = isDark ? const Color(0xFF3B2B1B) : const Color(0xFFFFF3E0);
        fg = isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100);
        break;
      case MailCategory.updates:
        bg = isDark ? const Color(0xFF1B2B3B) : const Color(0xFFE3F2FD);
        fg = isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
        break;
      case MailCategory.personal:
      case MailCategory.all:
        bg = isDark ? const Color(0xFF2C2F33) : const Color(0xFFF0F0F0);
        fg = AppTheme.textSecondary(context);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildUnsubscribeIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.withOpacity(0.4), width: 0.8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.unsubscribe_outlined, size: 11, color: Colors.deepOrange),
          SizedBox(width: 4),
          Text(
            'Unsub available',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.deepOrange,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
