import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/message.dart';
import '../../../providers.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String messageId;

  const ReaderScreen({
    super.key,
    required this.messageId,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  MailMessage? _message;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessage();
  }

  Future<void> _loadMessage() async {
    final msg = await ref.read(messageRepositoryProvider).getMessage(widget.messageId);
    if (mounted) {
      setState(() {
        _message = msg;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Viewer', style: TextStyle(fontSize: 18)),
        actions: [
          // Archive
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archive',
            onPressed: () async {
              await ref.read(messageRepositoryProvider).archive(msg.id, true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message archived')),
                );
                Navigator.pop(context);
              }
            },
          ),
          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.deleteColor),
            tooltip: 'Delete',
            onPressed: () async {
              await ref.read(messageRepositoryProvider).delete(msg.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message deleted')),
                );
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject header
            Text(
              msg.subject,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 14),

            // Sender & Date Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.lightPrimary.withOpacity(0.2),
                        child: Text(
                          msg.senderName.isNotEmpty
                              ? msg.senderName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.lightPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.senderName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              msg.senderEmail,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatFullDate(msg.receivedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // One-Tap Unsubscribe Banner (if available)
            if (msg.hasUnsubscribeOption) ...[
              const SizedBox(height: 14),
              _buildUnsubscribeBanner(context, msg),
            ],

            const SizedBox(height: 20),
            Divider(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
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
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
                fontFamilyFallback: const ['Roboto', 'Segoe UI', 'sans-serif'],
              ),
            ),

            const SizedBox(height: 40),
            // Privacy watermark
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 14,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Rendered pure text. Tracking pixels blocked.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unsubscribed from ${msg.senderName}'),
            action: SnackBarAction(
              label: 'Archive past',
              onPressed: () async {
                await ref.read(messageRepositoryProvider).archiveAllFromSender(msg.senderEmail);
              },
            ),
          ),
        );
      }
    }
  }

  String _formatFullDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
