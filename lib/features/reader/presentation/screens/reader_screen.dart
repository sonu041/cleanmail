import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../domain/models/account.dart';
import '../../../../domain/models/message.dart';
import '../../../clean_sweep/presentation/screens/sender_emails_screen.dart';
import '../../../inbox/presentation/widgets/set_preferred_tag_dialog.dart';
import '../../../providers.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String messageId;
  final MailAccount? account;

  const ReaderScreen({
    super.key,
    required this.messageId,
    this.account,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  MailMessage? _message;
  MailAccount? _account;
  bool _isLoading = true;
  bool _isSenderExpanded = false;

  // Movable Floating Delete Button State
  Offset? _buttonPosition;
  bool _isDragging = false;
  DateTime? _lastDeleteTapTime;
  static const double _buttonSize = 56.0;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    _loadMessage();
  }

  Future<void> _loadMessage() async {
    final msg = await ref.read(messageRepositoryProvider).getMessage(widget.messageId);
    MailAccount? acc = _account;
    if (msg != null && acc == null) {
      try {
        final accounts = await ref.read(accountRepositoryProvider).getAccounts();
        acc = accounts.where((a) => a.id == msg.accountId).firstOrNull;
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _message = msg;
        _account = acc;
        _isLoading = false;
      });
    }
  }

  void _openSenderEmails() {
    if (_message == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SenderEmailsScreen(
          senderEmail: _message!.senderEmail,
          senderName: _message!.senderName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_message == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Message not found.')),
      );
    }

    final msg = _message!;
    final isNerd = AppTheme.isNerd(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Viewer', style: TextStyle(fontSize: 18)),
        actions: [
          // All emails from this sender
          IconButton(
            key: const ValueKey('reader_view_all_from_sender_btn'),
            icon: const Icon(Icons.all_inbox_outlined),
            tooltip: 'All emails from ${msg.senderEmail}',
            onPressed: _openSenderEmails,
          ),
          // Preferred Tag for sender
          IconButton(
            key: const ValueKey('reader_pref_tag_btn'),
            icon: const Icon(Icons.label_outlined),
            tooltip: 'Set preferred tag for sender',
            onPressed: () async {
              await showSetPreferredTagDialog(
                context: context,
                ref: ref,
                senderEmail: msg.senderEmail,
                senderName: msg.senderName,
                currentCategory: msg.category,
                currentCustomTag: msg.customTag,
              );
              _loadMessage();
            },
          ),
          // Lock / Unlock toggle
          IconButton(
            key: const ValueKey('reader_lock_btn'),
            icon: Icon(msg.isLocked ? Icons.lock : Icons.lock_open_outlined),
            color: msg.isLocked
                ? (isNerd ? AppTheme.nerdAccentRed : Colors.amber.shade800)
                : null,
            tooltip: msg.isLocked ? 'Unlock email' : 'Lock email',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final newLocked = !msg.isLocked;
              await ref.read(messageRepositoryProvider).setLocked(msg.id, newLocked);
              if (mounted) {
                setState(() {
                  _message = msg.copyWith(isLocked: newLocked);
                });
                SnackBarUtils.showAutoHideSnackBar(
                  messenger: messenger,
                  message: newLocked
                      ? 'Email locked (deletion protected)'
                      : 'Email unlocked',
                  duration: const Duration(seconds: 3),
                );
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Initialize near right thumb: ~72% down, 18px from right edge
          _buttonPosition ??= Offset(
            constraints.maxWidth - _buttonSize - 18.0,
            constraints.maxHeight * 0.72,
          );

          // Re-clamp in case screen rotated or resized
          _buttonPosition = Offset(
            _buttonPosition!.dx.clamp(10.0, constraints.maxWidth - _buttonSize - 10.0),
            _buttonPosition!.dy.clamp(10.0, constraints.maxHeight - _buttonSize - 10.0),
          );

          final isNerd = AppTheme.isNerd(context);
          final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
          final currentAccount = widget.account ??
              _account ??
              accounts.where((a) => a.id == msg.accountId).firstOrNull;
          final toAddress = _resolveToAddress(msg.accountId, accounts, currentAccount);
          final toDisplay = (currentAccount != null &&
                  currentAccount.displayName.isNotEmpty &&
                  currentAccount.displayName != toAddress &&
                  !toAddress.contains(currentAccount.displayName))
              ? '${currentAccount.displayName} <$toAddress>'
              : toAddress;

          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Locked tag banner
                    if (msg.isLocked) ...[
                      Container(
                        key: const ValueKey('reader_locked_tag'),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isNerd ? AppTheme.nerdAccentRed : Colors.amber.shade800).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(isNerd ? 2 : 6),
                          border: Border.all(
                            color: isNerd ? AppTheme.nerdAccentRed : Colors.amber.shade800,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock,
                              size: 14,
                              color: isNerd ? AppTheme.nerdAccentRed : Colors.amber.shade800,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isNerd ? '[LOCKED] DELETION PROTECTED' : 'LOCKED • Deletion Protected',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                                color: isNerd ? AppTheme.nerdAccentRed : Colors.amber.shade800,
                                fontFamily: AppTheme.fontFamily(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Subject header
                    Text(
                      msg.subject,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 14),

            // Sender & Date Card (Tappable to expand / collapse)
            Material(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(isNerd ? 4 : 10),
              child: InkWell(
                key: const ValueKey('reader_sender_box'),
                onTap: () {
                  setState(() {
                    _isSenderExpanded = !_isSenderExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(isNerd ? 4 : 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isNerd ? 4 : 10),
                    border: Border.all(
                      color: AppTheme.border(context),
                    ),
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Collapsed Header Row
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isNerd
                                  ? const Color(0xFF003814)
                                  : AppTheme.lightPrimary.withOpacity(0.2),
                              child: Text(
                                msg.senderName.isNotEmpty
                                    ? msg.senderName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isNerd ? AppTheme.nerdPrimary : AppTheme.lightPrimary,
                                  fontFamily: AppTheme.fontFamily(context),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.senderName.isNotEmpty ? msg.senderName : msg.senderEmail,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppTheme.textPrimary(context),
                                      fontFamily: AppTheme.fontFamily(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '${msg.senderEmail} • to: $toAddress',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary(context),
                                      fontFamily: AppTheme.fontFamily(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatShortDate(msg.receivedAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary(context),
                                    fontFamily: AppTheme.fontFamily(context),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  _isSenderExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Expanded Full Details on separate lines
                        if (_isSenderExpanded) ...[
                          const SizedBox(height: 12),
                          Divider(
                            color: AppTheme.border(context),
                            height: 1,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailLine(
                            context,
                            label: isNerd ? 'FROM NAME:' : 'Sender Name:',
                            value: msg.senderName,
                            isNerd: isNerd,
                          ),
                          const SizedBox(height: 8),
                          _buildDetailLine(
                            context,
                            label: isNerd ? 'FROM EMAIL:' : 'From Email:',
                            value: msg.senderEmail,
                            isNerd: isNerd,
                          ),
                          const SizedBox(height: 8),
                          _buildDetailLine(
                            context,
                            label: isNerd ? 'TO:' : 'To:',
                            value: toDisplay,
                            isNerd: isNerd,
                          ),
                          const SizedBox(height: 8),
                          _buildDetailLine(
                            context,
                            label: isNerd ? 'DATE & TIME:' : 'Date & Time:',
                            value: _formatFullDate(msg.receivedAt, isNerd),
                            isNerd: isNerd,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                key: const ValueKey('reader_sender_all_emails_btn'),
                                icon: const Icon(Icons.list_alt_rounded, size: 16),
                                label: const Text('All Mails from Sender', style: TextStyle(fontSize: 12)),
                                onPressed: _openSenderEmails,
                              ),
                              OutlinedButton.icon(
                                key: const ValueKey('reader_sender_tag_btn'),
                                icon: const Icon(Icons.label_outlined, size: 16),
                                label: Text(
                                  msg.customTag != null
                                      ? 'Set Tag (${msg.category.label} • ${msg.customTag})'
                                      : 'Set Tag (${msg.category.label})',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () async {
                                  await showSetPreferredTagDialog(
                                    context: context,
                                    ref: ref,
                                    senderEmail: msg.senderEmail,
                                    senderName: msg.senderName,
                                    currentCategory: msg.category,
                                    currentCustomTag: msg.customTag,
                                  );
                                  _loadMessage();
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // One-Tap Unsubscribe Banner (if available)
            if (msg.hasUnsubscribeOption) ...[
              const SizedBox(height: 14),
              _buildUnsubscribeBanner(context, msg),
            ],

            const SizedBox(height: 20),
            Divider(
              color: AppTheme.border(context),
              height: 1,
            ),
            const SizedBox(height: 20),

            // Pure Text Body (Distraction-free)
            SelectableText(
              msg.plainTextBody.isNotEmpty
                  ? msg.plainTextBody
                  : msg.snippet,
              style: TextStyle(
                fontSize: 15.5,
                height: 1.65,
                color: AppTheme.textPrimary(context),
                fontFamily: AppTheme.fontFamily(context),
                fontFamilyFallback: const ['Roboto', 'Segoe UI', 'sans-serif'],
              ),
            ),

            const SizedBox(height: 40),
            // Privacy watermark
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: AppTheme.textSecondary(context),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        AppTheme.isNerd(context)
                            ? '> [SHIELD] Pure text. Zero webviews. Zero tracking pixels.'
                            : 'Rendered pure text. Tracking pixels blocked.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary(context),
                          fontFamily: AppTheme.fontFamily(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      // Floating movable delete button positioned near right thumb
      Positioned(
        left: _buttonPosition!.dx,
        top: _buttonPosition!.dy,
        child: _buildMovableDeleteButton(context, msg, constraints, isNerd),
      ),
    ],
  ),
);
},
),
);
}

  Widget _buildMovableDeleteButton(
    BuildContext context,
    MailMessage msg,
    BoxConstraints constraints,
    bool isNerd,
  ) {
    return GestureDetector(
      key: const ValueKey('reader_floating_delete_btn'),
      onPanStart: (_) {
        _isDragging = false;
      },
      onPanUpdate: (details) {
        if (details.delta.distanceSquared > 0.5) {
          if (!_isDragging) {
            setState(() => _isDragging = true);
          }
        }
        setState(() {
          final newX = _buttonPosition!.dx + details.delta.dx;
          final newY = _buttonPosition!.dy + details.delta.dy;
          _buttonPosition = Offset(
            newX.clamp(10.0, constraints.maxWidth - _buttonSize - 10.0),
            newY.clamp(10.0, constraints.maxHeight - _buttonSize - 10.0),
          );
        });
      },
      onPanEnd: (_) {
        if (_isDragging) {
          setState(() => _isDragging = false);
        }
      },
      onTap: () => _handleDelete(msg),
      child: AnimatedScale(
        scale: _isDragging ? 1.10 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: _buttonSize,
          height: _buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isNerd ? const Color(0xFF1E0808) : AppTheme.deleteColor,
            border: isNerd
                ? Border.all(color: AppTheme.nerdAccentRed, width: 1.5)
                : Border.all(color: Colors.white.withOpacity(0.25), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: (isNerd ? AppTheme.nerdAccentRed : AppTheme.deleteColor)
                    .withOpacity(_isDragging ? 0.50 : 0.35),
                blurRadius: _isDragging ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: isNerd ? AppTheme.nerdAccentRed : Colors.white,
                size: 26,
              ),
              // Subtle grip indicator showing button is movable
              Positioned(
                top: 7,
                right: 9,
                child: Icon(
                  Icons.drag_indicator,
                  size: 11,
                  color: (isNerd ? AppTheme.nerdAccentRed : Colors.white)
                      .withOpacity(0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDelete(MailMessage msg) async {
    final messenger = ScaffoldMessenger.of(context);

    if (msg.isLocked) {
      SnackBarUtils.showAutoHideSnackBar(
        messenger: messenger,
        message: 'This email is locked. Unlock it first to delete.',
        duration: const Duration(seconds: 5),
      );
      return;
    }

    final now = DateTime.now();
    if (_lastDeleteTapTime != null &&
        now.difference(_lastDeleteTapTime!).inMilliseconds < 500) {
      return;
    }
    _lastDeleteTapTime = now;

    final repo = ref.read(messageRepositoryProvider);

    await repo.delete(msg.id);
    if (!mounted) return;
    Navigator.pop(context);

    SnackBarUtils.showAutoHideSnackBar(
      messenger: messenger,
      message: 'Deleted "${msg.subject}"',
      onUndo: () {
        repo.restoreMessage(msg);
      },
      duration: const Duration(seconds: 5),
    );
  }

  Widget _buildUnsubscribeBanner(BuildContext context, MailMessage msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.unsubscribe_outlined, color: Colors.deepOrange, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mailing List Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'One-tap unsubscribe from this sender',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _handleUnsubscribe(context, msg),
            child: const Text('Unsubscribe', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUnsubscribe(BuildContext context, MailMessage msg) async {
    final targetUrl = msg.unsubscribeUrl ?? msg.unsubscribeMailto;
    if (targetUrl == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Unsubscribe'),
        content: Text(
          'CleanMail will launch the provider unsubscribe handler for:\n${msg.senderName} (${msg.senderEmail})\n\nTarget: $targetUrl',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed & Unsubscribe'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uri = Uri.tryParse(targetUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (context.mounted) {
        // Record unsubscribe metric event
        ref.read(databaseProvider).recordMetricEvent(
          eventType: 'unsubscribe',
          count: 1,
          accountId: msg.accountId,
          details: 'Unsubscribed from ${msg.senderName} (${msg.senderEmail})',
        ).ignore();

        SnackBarUtils.showAutoHideSnackBar(
          messenger: ScaffoldMessenger.of(context),
          message: 'Unsubscribed from ${msg.senderName}',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  Widget _buildDetailLine(
    BuildContext context, {
    required String label,
    required String value,
    required bool isNerd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isNerd ? AppTheme.nerdAccentCyan : AppTheme.textSecondary(context),
            fontFamily: AppTheme.fontFamily(context),
            letterSpacing: isNerd ? 0.6 : 0,
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(
          value.isNotEmpty ? value : '(None)',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary(context),
            fontFamily: AppTheme.fontFamily(context),
          ),
        ),
      ],
    );
  }

  String _formatShortDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes.clamp(1, 60)}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  String _formatFullDate(DateTime date, bool isNerd) {
    if (isNerd) {
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
    }
    return DateFormat('EEEE, MMM d, yyyy • h:mm a').format(date);
  }

  String _resolveToAddress(
    String accountId,
    List<MailAccount> accounts,
    MailAccount? fallbackAccount,
  ) {
    if (fallbackAccount != null && fallbackAccount.email.isNotEmpty) {
      return fallbackAccount.email;
    }
    final matched = accounts.where((a) => a.id == accountId).firstOrNull;
    if (matched != null && matched.email.isNotEmpty) {
      return matched.email;
    }
    for (final acc in accounts) {
      if (accountId.contains(acc.email) || accountId.contains(acc.id)) {
        return acc.email;
      }
    }
    if (accounts.isNotEmpty && accounts.first.email.isNotEmpty) {
      return accounts.first.email;
    }
    final cleaned = accountId.replaceFirst('google_', '');
    if (cleaned.contains('@')) {
      return cleaned;
    }
    return accountId.isNotEmpty ? accountId : 'me';
  }
}
