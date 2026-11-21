import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../../../core/services/log_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../accounts/presentation/screens/accounts_screen.dart';
import '../../../providers.dart';
import 'logs_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final logService = ref.watch(logServiceProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final accounts = accountsAsync.asData?.value ?? [];
    final isNerd = AppTheme.isNerd(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isNerd ? '> /etc/cleanmail/config' : 'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // ----------------------------------------------------
          // 1. THEME SELECTION SECTION
          // ----------------------------------------------------
          _buildSectionHeader(
            context,
            title: isNerd ? 'SECTION: THEME_PREFERENCES' : 'Appearance & Theme',
            subtitle: isNerd
                ? '> Select display buffer & color palette'
                : 'Choose the visual theme for CleanMail',
            isNerd: isNerd,
          ),
          const SizedBox(height: 8),

          ...AppThemeMode.values.map((mode) {
            final isSelected = currentTheme == mode;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: isSelected
                      ? (isNerd ? AppTheme.nerdPrimary : Theme.of(context).colorScheme.primary)
                      : AppTheme.border(context),
                  width: isSelected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(isNerd ? 4 : 10),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _themeIconBg(mode, isNerd),
                    borderRadius: BorderRadius.circular(isNerd ? 4 : 8),
                  ),
                  child: Icon(
                    mode.icon,
                    size: 20,
                    color: _themeIconColor(mode, isNerd),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        mode.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (mode == AppThemeMode.system) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'DEFAULT',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    if (mode == AppThemeMode.nerd) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF66).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF00FF66), width: 0.8),
                        ),
                        child: const Text(
                          'HACKER',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00FF66),
                            fontFamily: AppTheme.nerdFontFamily,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  mode.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary(context),
                    fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle,
                        color: isNerd ? AppTheme.nerdPrimary : Theme.of(context).colorScheme.primary,
                      )
                    : const Icon(Icons.circle_outlined, color: Colors.grey, size: 20),
                onTap: () {
                  ref.read(themeModeProvider.notifier).setTheme(mode);
                },
              ),
            );
          }),

          const SizedBox(height: 20),

          // ----------------------------------------------------
          // 2. LOG VIEWER & AUDIT TRAIL
          // ----------------------------------------------------
          _buildSectionHeader(
            context,
            title: isNerd ? 'SECTION: DIAGNOSTICS_AND_AUDIT' : 'Diagnostics & Audit Trail',
            subtitle: isNerd
                ? '> Track background jobs, token refreshes & delta syncs'
                : 'Inspect all operations, sync events, and OAuth tokens',
            isNerd: isNerd,
          ),
          const SizedBox(height: 8),

          Card(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: AppTheme.border(context)),
              borderRadius: BorderRadius.circular(isNerd ? 4 : 10),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isNerd ? const Color(0xFF003814) : const Color(0xFFE8F5E9),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: isNerd ? AppTheme.nerdPrimary : AppTheme.archiveColor,
                ),
              ),
              title: Text(
                isNerd ? 'LOG_VIEWER (Operation Logs)' : 'Operation Log Viewer',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                ),
              ),
              subtitle: Text(
                '${logService.totalMailsSynced} mails synced • ${logService.logs.length} logged events',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary(context),
                  fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LogsScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ----------------------------------------------------
          // 3. MAILBOXES & CLOUD CONNECTIONS
          // ----------------------------------------------------
          _buildSectionHeader(
            context,
            title: isNerd ? 'SECTION: MAILBOX_MANAGEMENT' : 'Mailboxes & Cloud',
            subtitle: isNerd
                ? '> Manage connected Gmail mailboxes and credentials'
                : 'Connect and configure multi-mailbox accounts',
            isNerd: isNerd,
          ),
          const SizedBox(height: 8),

          Card(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: AppTheme.border(context)),
              borderRadius: BorderRadius.circular(isNerd ? 4 : 10),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isNerd ? const Color(0xFF002233) : const Color(0xFFE3F2FD),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  color: isNerd ? AppTheme.nerdAccentCyan : AppTheme.lightPrimary,
                ),
              ),
              title: Text(
                isNerd ? 'CONNECTED_MAILBOXES' : 'Manage Connected Mailboxes',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                ),
              ),
              subtitle: Text(
                '${accounts.length} mailboxes active (${accounts.map((a) => a.displayName).join(", ")})',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary(context),
                  fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountsScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          Card(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: AppTheme.border(context)),
              borderRadius: BorderRadius.circular(isNerd ? 4 : 10),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isNerd ? const Color(0xFF261D00) : const Color(0xFFFFF8E1),
                child: Icon(
                  Icons.key_outlined,
                  color: isNerd ? AppTheme.nerdAccentYellow : Colors.amber.shade900,
                ),
              ),
              title: Text(
                isNerd ? 'GOOGLE_OAUTH_CLIENT_ID' : 'Google OAuth Client ID',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                ),
              ),
              subtitle: Text(
                'Configure Google Cloud OAuth 2.0 Web Client ID',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary(context),
                  fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                ),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => _showGoogleClientIdDialog(context),
            ),
          ),

          const SizedBox(height: 24),

          // ----------------------------------------------------
          // 4. ABOUT & PRIVACY ARCHITECTURE
          // ----------------------------------------------------
          _buildSectionHeader(
            context,
            title: isNerd ? 'SECTION: PRIVACY_SHIELD_SPECS' : 'Privacy & Design Specs',
            subtitle: isNerd
                ? '> Strict text-only isolation. Zero WebViews. Zero tracking pixels.'
                : 'How CleanMail protects your privacy and device resources',
            isNerd: isNerd,
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(isNerd ? 4 : 10),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _specItem(
                  context,
                  icon: Icons.shield_outlined,
                  title: 'Tracking Pixel Eliminator',
                  desc: 'All 1x1 tracking beacons and third-party analytics telemetry stripped.',
                  isNerd: isNerd,
                ),
                const SizedBox(height: 10),
                _specItem(
                  context,
                  icon: Icons.history_toggle_off,
                  title: 'Approach 2 Delta Sync',
                  desc: 'Syncs changes in ~100ms via users.history.list using 2 quota units.',
                  isNerd: isNerd,
                ),
                const SizedBox(height: 10),
                _specItem(
                  context,
                  icon: Icons.storage_outlined,
                  title: 'Local SQLite Engine',
                  desc: 'Drift ORM with full offline caching and instant sender sweep cleanup.',
                  isNerd: isNerd,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Footer
          Center(
            child: Column(
              children: [
                Text(
                  isNerd
                      ? '> CleanMail [Version 1.0.0+1] // Build: PROD'
                      : '${AppConstants.appName} • ${AppConstants.appTagline}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary(context),
                    fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Distraction-Free Text Mail Client',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary(context).withOpacity(0.7),
                    fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isNerd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isNerd ? AppTheme.nerdPrimary : AppTheme.textPrimary(context),
            fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
            letterSpacing: isNerd ? 0.8 : 0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary(context),
            fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
          ),
        ),
      ],
    );
  }

  Widget _specItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
    required bool isNerd,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: isNerd ? AppTheme.nerdPrimary : AppTheme.archiveColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary(context),
                  fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _themeIconBg(AppThemeMode mode, bool isNerd) {
    if (isNerd) return const Color(0xFF003814);
    switch (mode) {
      case AppThemeMode.system:
        return const Color(0xFFECEFF1);
      case AppThemeMode.light:
        return const Color(0xFFFFF8E1);
      case AppThemeMode.dark:
        return const Color(0xFF263238);
      case AppThemeMode.nerd:
        return const Color(0xFF003814);
    }
  }

  Color _themeIconColor(AppThemeMode mode, bool isNerd) {
    if (isNerd) return AppTheme.nerdPrimary;
    switch (mode) {
      case AppThemeMode.system:
        return Colors.blueGrey;
      case AppThemeMode.light:
        return Colors.amber.shade800;
      case AppThemeMode.dark:
        return Colors.blue.shade200;
      case AppThemeMode.nerd:
        return const Color(0xFF00FF66);
    }
  }

  Future<void> _showGoogleClientIdDialog(BuildContext context) async {
    final googleAuth = GoogleAuthService();
    final currentId = await googleAuth.getClientId();
    final controller = TextEditingController(text: currentId);

    if (!context.mounted) return;

    showDialog<bool>(
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
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await googleAuth.setClientId(controller.text);
              AppLogger.info('Client ID Updated', 'Configured new Google Client ID', category: LogCategory.auth);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Client ID'),
          ),
        ],
      ),
    );
  }
}
