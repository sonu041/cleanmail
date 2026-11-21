import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../../../core/services/auto_sync_service.dart';
import '../../../../core/services/log_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/local/sample_data.dart';
import '../../../../domain/models/account.dart';
import '../../../providers.dart';
import '../../../settings/presentation/screens/logs_screen.dart';
import '../widgets/gsi_button.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final GoogleAuthService _googleAuth = GoogleAuthService();
  bool _isConnecting = false;
  String? _syncingAccountId;
  String? _syncStatusMessage;
  double? _syncProgressValue;
  bool _isGsiInitialized = false;

  @override
  void initState() {
    super.initState();
    _initGsi();
    _googleAuth.onCurrentUserChanged.listen((googleAccount) async {
      if (googleAccount != null && mounted && !_isConnecting) {
        final accounts = await ref.read(accountRepositoryProvider).getAccounts();
        final alreadyAdded = accounts.any((a) => a.email.toLowerCase() == googleAccount.email.toLowerCase());
        if (!alreadyAdded) {
          _handleConnectGoogle(preAuthenticatedAccount: googleAccount);
        }
      }
    });
  }

  Future<void> _initGsi() async {
    if (!kIsWeb) return;
    try {
      final clientId = await _googleAuth.getClientId();
      await GoogleSignInPlatform.instance.init(
        scopes: [
          'email',
          'https://www.googleapis.com/auth/gmail.readonly',
          'https://www.googleapis.com/auth/gmail.modify',
        ],
        clientId: clientId.isNotEmpty ? clientId : null,
      );
      if (mounted) {
        setState(() => _isGsiInitialized = true);
      }
    } catch (e) {
      debugPrint('GSI Init Note: $e');
    }
  }

  void _openLogsScreen({LogCategory? category}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogsScreen(initialCategory: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final syncedCounts = ref.watch(syncedMessageCountsByAccountProvider).asData?.value ?? <String, int>{};
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mailboxes', style: TextStyle(fontSize: 19)),
        actions: [
          IconButton(
            key: const ValueKey('mailboxes_view_logs_appbar_btn'),
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'View Operation & Sync Logs',
            onPressed: () => _openLogsScreen(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configure Google Client ID',
            onPressed: () => _showGoogleClientIdDialog(),
          ),
        ],
      ),
      body: _isConnecting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Connecting & syncing Gmail...', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('Fetching recent messages & converting to clean text', style: TextStyle(fontSize: 12)),
                ],
              ),
            )
          : accountsAsync.when(
              data: (accounts) {
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Connected Mailboxes',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        TextButton.icon(
                          key: const ValueKey('mailboxes_view_logs_header_btn'),
                          icon: const Icon(Icons.receipt_long_outlined, size: 16),
                          label: const Text('View Logs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          onPressed: () => _openLogsScreen(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (accounts.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surface(context),
                          borderRadius: BorderRadius.circular(AppTheme.isNerd(context) ? 4 : 10),
                          border: Border.all(
                            color: AppTheme.border(context),
                          ),
                        ),
                        child: const Center(
                          child: Text('No mailboxes connected yet.'),
                        ),
                      ),
                    ] else ...[
                      ...accounts.map((account) => _buildAccountTile(context, account, syncedCounts)),
                    ],

                    const SizedBox(height: 24),
                    const Text(
                      'Add Mailbox',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 10),

                    // Web Google Identity Services (GIS) Button
                    if (kIsWeb && _isGsiInitialized) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: buildPlatformGsiButton(),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Connect Google Account Card
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8F0FE),
                          child: Icon(Icons.mail_outline, color: Color(0xFF1A73E8)),
                        ),
                        title: const Text('Connect Gmail Account'),
                        subtitle: const Text('Google Workspace or personal @gmail.com'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => _handleConnectGoogle(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Connect Microsoft 365 Card
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF3E8FD),
                          child: Icon(Icons.business_outlined, color: Color(0xFF8E24AA)),
                        ),
                        title: const Text('Connect Outlook / M365'),
                        subtitle: const Text('Microsoft 365, Outlook.com, or Hotmail'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Outlook OAuth connector will be available in next phase.'),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),
                    // Quick Settings Card for Client ID
                    Card(
                      color: isDark ? AppTheme.darkSurface : const Color(0xFFF8F9FA),
                      child: ListTile(
                        leading: const Icon(Icons.key_outlined, color: Colors.blueGrey),
                        title: const Text('Google Client ID Configuration', style: TextStyle(fontSize: 14)),
                        subtitle: const Text('Set or update your Google Cloud OAuth Client ID', style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.edit_outlined, size: 18),
                        onTap: () => _showGoogleClientIdDialog(),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Demo Seeder Button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text('Reload Demo Mailboxes & Sample Emails'),
                      onPressed: () async {
                        await SampleDataSeeder.seedIfEmpty(
                          accountRepo: ref.read(accountRepositoryProvider),
                          messageRepo: ref.read(messageRepositoryProvider),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Demo mailboxes and sample messages loaded!')),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Deduplicate Messages Button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Clean Up Duplicate Emails Across Mailboxes'),
                      onPressed: () async {
                        final removed = await ref.read(messageRepositoryProvider).deduplicateMessages();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                removed > 0
                                    ? 'Cleaned up $removed duplicate email${removed == 1 ? "" : "s"}.'
                                    : 'No duplicate emails found. All mailboxes are clean!',
                              ),
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // View Operation & Sync Logs Button
                    OutlinedButton.icon(
                      key: const ValueKey('mailboxes_view_logs_btn'),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('View Operation & Sync Logs'),
                      onPressed: () => _openLogsScreen(),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
    );
  }

  Future<void> _handleConnectGoogle({GoogleSignInAccount? preAuthenticatedAccount}) async {
    final existingClientId = await _googleAuth.getClientId();

    if (existingClientId.isEmpty) {
      if (!mounted) return;
      final configured = await _showGoogleClientIdDialog();
      if (configured != true) return;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isConnecting = true);

    try {
      final result = await _googleAuth.signInAndSync(
        accountRepo: ref.read(accountRepositoryProvider),
        messageRepo: ref.read(messageRepositoryProvider),
        preAuthenticatedAccount: preAuthenticatedAccount,
      );

      if (!mounted) return;

      if (result.error != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Text('Google Sign-In Notice', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: SelectableText(
              result.account != null
                  ? 'Signed in as ${result.account!.email}, but Gmail sync failed:\n\n${result.error}'
                  : result.error!,
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (result.account != null) {
        final message = result.isAlreadyConnected
            ? '${result.account!.email} is already connected. Re-synced ${result.syncedCount} emails.'
            : 'Connected ${result.account!.email} and synced ${result.syncedCount} emails!';
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.archiveColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: $e'),
            backgroundColor: AppTheme.deleteColor,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _handleSmartSyncAccount(MailAccount account) async {
    setState(() {
      _syncingAccountId = account.id;
      _syncStatusMessage = 'Checking for latest emails...';
      _syncProgressValue = null;
    });
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await _googleAuth.syncMailboxSmart(
        account: account,
        messageRepo: ref.read(messageRepositoryProvider),
        accountRepo: ref.read(accountRepositoryProvider),
        onProgress: (current, total, status) {
          if (mounted) {
            setState(() {
              _syncStatusMessage = status;
              if (total > 0) {
                _syncProgressValue = (current / total).clamp(0.0, 1.0);
              }
            });
          }
        },
      );

      if (!mounted) return;

      if (result.error != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sync Error'),
            content: Text(result.error!),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      } else {
        final syncedInDb = await ref
            .read(databaseProvider)
            .getSyncedMessageCountForAccount(account.id);
        final totalAvail = result.totalAvailable > 0
            ? result.totalAvailable
            : (syncedInDb > 0 ? syncedInDb : 0);

        String message;
        if (result.olderSynced) {
          if (result.syncedCount > 0) {
            message = 'Latest emails up to date. Synced ${result.syncedCount} older emails for ${account.email} ($syncedInDb of $totalAvail synced)';
          } else {
            message = 'All emails in ${account.email} are synced ($syncedInDb of $totalAvail synced)';
          }
        } else {
          if (result.syncedCount > 0) {
            message = 'Synced ${result.syncedCount} latest emails for ${account.email} ($syncedInDb of $totalAvail synced)';
          } else {
            message = 'Mailbox ${account.email} is completely up to date ($syncedInDb of $totalAvail synced)';
          }
        }

        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: AppTheme.deleteColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncingAccountId = null;
          _syncStatusMessage = null;
          _syncProgressValue = null;
        });
      }
    }
  }

  Future<bool?> _showGoogleClientIdDialog() async {
    final currentId = await _googleAuth.getClientId();
    final controller = TextEditingController(text: currentId);

    if (!mounted) return false;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Google OAuth Client ID', style: TextStyle(fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste your OAuth 2.0 Web Client ID from Google Cloud Console:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'e.g. 12345678-abc.apps.googleusercontent.com',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              if (kIsWeb) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Web Origin Required:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'In Google Cloud Console, add this exact URL under "Authorized JavaScript origins":\n${Uri.base.origin}',
                        style: const TextStyle(fontSize: 12, fontFamily: AppTheme.nerdFontFamily),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const Text(
                'Format: [project-id]-[hash].apps.googleusercontent.com\nStored securely on-device with Flutter Secure Storage.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _googleAuth.setClientId(controller.text);
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Save Client ID'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(
    BuildContext context,
    MailAccount account,
    Map<String, int> syncedCounts,
  ) {
    final isSyncing = _syncingAccountId == account.id;
    final autoSyncState = ref.watch(autoSyncNotifierProvider)[account.id] ?? const AccountAutoSyncState();
    final isAutoSyncing = autoSyncState.isRunning;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNerd = AppTheme.isNerd(context);

    // Number of emails currently synced in local DB for this mailbox (X)
    final syncedCount = syncedCounts[account.id] ?? 0;

    // Total emails available in mailbox (Y)
    final totalAvailable = account.totalMessages > 0
        ? account.totalMessages
        : (syncedCount > 0 ? syncedCount : 0);

    // Calculate progress ratio (0.0 to 1.0) and percentage
    final double progress = totalAvailable > 0
        ? (syncedCount / totalAvailable).clamp(0.0, 1.0)
        : 1.0;
    final int percentage = totalAvailable > 0
        ? ((syncedCount / totalAvailable) * 100).clamp(0, 100).toInt()
        : 100;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Account Identity & Actions
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(account.avatarColorValue),
                  child: Text(
                    account.displayName.isNotEmpty ? account.displayName[0].toUpperCase() : '@',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Text(
                            account.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: (isNerd ? AppTheme.nerdPrimary : AppTheme.lightPrimary).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              account.provider.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isNerd ? AppTheme.nerdPrimary : AppTheme.lightPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account.email,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Resync button (manual sync)
                if (account.provider == MailProvider.gmail) ...[
                  IconButton(
                    key: ValueKey('sync_account_btn_${account.id}'),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, color: AppTheme.lightPrimary),
                    tooltip: 'Sync Emails Now (Manual)',
                    onPressed: isSyncing ? null : () => _handleSmartSyncAccount(account),
                  ),
                  // Separate Old Mail Auto-Sync Toggle Button
                  IconButton(
                    key: ValueKey('toggle_older_sync_btn_${account.id}'),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: isAutoSyncing
                        ? Icon(Icons.autorenew_rounded,
                            color: isNerd ? AppTheme.nerdAccentCyan : AppTheme.lightPrimary)
                        : Icon(Icons.history_toggle_off_rounded,
                            color: AppTheme.textSecondary(context)),
                    tooltip: isAutoSyncing
                        ? 'Auto-Sync Older Mails (100 / 10s): ON'
                        : 'Auto-Sync Older Mails (100 / 10s): OFF',
                    onPressed: () {
                      ref.read(autoSyncNotifierProvider.notifier).toggleAutoSync(account);
                    },
                  ),
                ],
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.delete_outline, color: AppTheme.deleteColor),
                  tooltip: 'Disconnect Account',
                  onPressed: () => _handleDisconnectAccount(account),
                ),
              ],
            ),

            // Separate Auto-Sync Older Emails Toggle Control Banner
            if (account.provider == MailProvider.gmail) ...[
              Container(
                key: ValueKey('auto_sync_banner_${account.id}'),
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isAutoSyncing
                      ? (isNerd
                          ? AppTheme.nerdAccentCyan.withOpacity(0.12)
                          : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35))
                      : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                  borderRadius: BorderRadius.circular(isNerd ? 2 : 8),
                  border: Border.all(
                    color: isAutoSyncing
                        ? (isNerd ? AppTheme.nerdAccentCyan : Theme.of(context).colorScheme.primary)
                        : AppTheme.border(context),
                    width: isAutoSyncing ? 1.2 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAutoSyncing ? Icons.autorenew_rounded : Icons.history_rounded,
                      size: 17,
                      color: isAutoSyncing
                          ? (isNerd ? AppTheme.nerdAccentCyan : Theme.of(context).colorScheme.primary)
                          : AppTheme.textSecondary(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              Text(
                                'Continuous Older Email Sync',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isAutoSyncing
                                      ? (isNerd ? AppTheme.nerdAccentCyan : AppTheme.textPrimary(context))
                                      : AppTheme.textPrimary(context),
                                  fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isAutoSyncing
                                      ? (autoSyncState.isRateLimited
                                          ? Colors.orange.withOpacity(0.25)
                                          : Colors.green.withOpacity(0.2))
                                      : Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  isAutoSyncing
                                      ? (autoSyncState.isRateLimited
                                          ? 'RATE LIMITED (${autoSyncState.countdownSeconds}s)'
                                          : (autoSyncState.countdownSeconds > 0
                                              ? 'NEXT IN ${autoSyncState.countdownSeconds}s'
                                              : 'SYNCING 100...'))
                                      : '100 / 10s',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: isAutoSyncing
                                        ? (autoSyncState.isRateLimited
                                            ? (isNerd ? AppTheme.nerdAccentRed : Colors.orange.shade800)
                                            : (isNerd ? AppTheme.nerdPrimary : Colors.green.shade800))
                                        : AppTheme.textSecondary(context),
                                    fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (autoSyncState.statusMessage != null && isAutoSyncing) ...[
                            const SizedBox(height: 2),
                            Text(
                              autoSyncState.statusMessage!,
                              key: ValueKey('auto_sync_status_${account.id}'),
                              style: TextStyle(
                                fontSize: 11,
                                color: autoSyncState.isRateLimited
                                    ? (isNerd ? AppTheme.nerdAccentRed : Colors.orange.shade800)
                                    : (isNerd ? AppTheme.nerdAccentCyan : AppTheme.lightPrimary),
                                fontWeight: FontWeight.w600,
                                fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      key: ValueKey('auto_sync_toggle_${account.id}'),
                      value: isAutoSyncing,
                      activeColor: isNerd ? AppTheme.nerdAccentCyan : null,
                      onChanged: (val) {
                        ref.read(autoSyncNotifierProvider.notifier).toggleAutoSync(account);
                      },
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 6),

            // 3. Sync Progress Bar & Stats
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    '$syncedCount of $totalAvailable synced ($percentage%)',
                    key: ValueKey('sync_text_${account.id}'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isNerd ? AppTheme.nerdPrimary : null,
                    ),
                  ),
                  Text(
                    'Total in mailbox: $totalAvailable',
                    key: ValueKey('total_text_${account.id}'),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // 4. Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                key: ValueKey('sync_progress_bar_${account.id}'),
                value: isSyncing && _syncProgressValue != null ? _syncProgressValue : progress,
                minHeight: 6,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isNerd
                      ? AppTheme.nerdPrimary
                      : (progress >= 1.0 ? const Color(0xFF10B981) : AppTheme.lightPrimary),
                ),
              ),
            ),

            // 5. Live Sync Status Message (during manual sync)
            if (isSyncing && _syncStatusMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _syncStatusMessage!,
                key: ValueKey('sync_status_${account.id}'),
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isNerd ? AppTheme.nerdAccentCyan : AppTheme.lightPrimary,
                ),
              ),
            ],

            const SizedBox(height: 6),

            // 6. View Sync Logs Link for this mailbox
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  key: ValueKey('account_view_logs_btn_${account.id}'),
                  onTap: () => _openLogsScreen(category: LogCategory.sync),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 13,
                          color: isNerd ? AppTheme.nerdAccentCyan : AppTheme.lightPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'View Sync Logs',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isNerd ? AppTheme.nerdAccentCyan : AppTheme.lightPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDisconnectAccount(MailAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Disconnect ${account.displayName}?'),
        content: const Text('This will remove the mailbox and cached emails from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.deleteColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(autoSyncNotifierProvider.notifier).stopAutoSync(account.id);
      await ref.read(accountRepositoryProvider).deleteAccount(account.id);
      await _googleAuth.clearStoredHistoryId(account.id);
      await _googleAuth.clearStoredToken(account.id);
      AppLogger.warning(
        'Mailbox Disconnected',
        'Disconnected ${account.displayName} (${account.email}), purged local cache, token, and delta checkpoint',
        category: LogCategory.auth,
        metadata: {'email': account.email, 'accountId': account.id},
      );
    }
  }
}
