import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../../../core/services/log_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/local/sample_data.dart';
import '../../../../domain/models/account.dart';
import '../../../providers.dart';
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

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mailboxes', style: TextStyle(fontSize: 19)),
        actions: [
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
                    const Text(
                      'Connected Mailboxes',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                      ...accounts.map((account) => _buildAccountTile(context, account)),
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

  Future<void> _handleResyncAccount(MailAccount account) async {
    setState(() => _syncingAccountId = account.id);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await _googleAuth.resyncAccount(
        account: account,
        messageRepo: ref.read(messageRepositoryProvider),
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
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result.syncedCount > 0
                  ? 'Delta Sync complete: synced ${result.syncedCount} changes for ${account.email}!'
                  : 'Delta Sync complete: ${account.email} is already up to date!',
            ),
            backgroundColor: AppTheme.archiveColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingAccountId = null);
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

  Widget _buildAccountTile(BuildContext context, MailAccount account) {
    final isSyncing = _syncingAccountId == account.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(account.avatarColorValue),
          child: Text(
            account.displayName.isNotEmpty ? account.displayName[0].toUpperCase() : '@',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(account.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(account.email),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Resync button
            if (account.provider == MailProvider.gmail)
              IconButton(
                icon: isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, color: AppTheme.lightPrimary),
                tooltip: 'Sync Emails Now',
                onPressed: isSyncing ? null : () => _handleResyncAccount(account),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.deleteColor),
              tooltip: 'Disconnect Account',
              onPressed: () async {
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
              },
            ),
          ],
        ),
      ),
    );
  }
}
