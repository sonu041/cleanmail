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

  // Movable Floating Delete Button State
  Offset? _buttonPosition;
  bool _isDragging = false;
  DateTime? _lastDeleteTapTime;
  static const double _buttonSize = 56.0;

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

          return Stack(
            children: [
              SingleChildScrollView(
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
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(AppTheme.isNerd(context) ? 4 : 10),
                border: Border.all(
                  color: AppTheme.border(context),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.isNerd(context)
                            ? const Color(0xFF003814)
                            : AppTheme.lightPrimary.withOpacity(0.2),
                        child: Text(
                          msg.senderName.isNotEmpty
                              ? msg.senderName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.isNerd(context) ? AppTheme.nerdPrimary : AppTheme.lightPrimary,
                            fontFamily: AppTheme.isNerd(context) ? 'monospace' : null,
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
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppTheme.textPrimary(context),
                                fontFamily: AppTheme.isNerd(context) ? 'monospace' : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              msg.senderEmail,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary(context),
                                fontFamily: AppTheme.isNerd(context) ? 'monospace' : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatFullDate(msg.receivedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary(context),
                          fontFamily: AppTheme.isNerd(context) ? 'monospace' : null,
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
                fontFamily: AppTheme.isNerd(context) ? 'monospace' : null,
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
                          fontFamily: AppTheme.isNerd(context) ? 'monospace' : null,
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
    final now = DateTime.now();
    if (_lastDeleteTapTime != null &&
        now.difference(_lastDeleteTapTime!).inMilliseconds < 500) {
      return;
    }
    _lastDeleteTapTime = now;

    final repo = ref.read(messageRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    await repo.delete(msg.id);
    if (!mounted) return;
    Navigator.pop(context);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted "${msg.subject}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            repo.restoreMessage(msg);
          },
        ),
        duration: const Duration(seconds: 4),
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
