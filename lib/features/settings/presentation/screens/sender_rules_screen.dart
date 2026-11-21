import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../domain/models/sender_rule.dart';
import '../../../inbox/presentation/widgets/set_preferred_tag_dialog.dart';
import '../../../providers.dart';

class SenderRulesScreen extends ConsumerStatefulWidget {
  const SenderRulesScreen({super.key});

  @override
  ConsumerState<SenderRulesScreen> createState() => _SenderRulesScreenState();
}

class _SenderRulesScreenState extends ConsumerState<SenderRulesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddRulePrompt(BuildContext context) async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final email = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isNerd = AppTheme.isNerd(ctx);
        return AlertDialog(
          title: Text(
            isNerd ? '> ADD_SENDER_RULE' : 'Add Sender Rule',
            style: TextStyle(fontFamily: isNerd ? AppTheme.nerdFontFamily : null),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the sender email address to configure preferred category and auto-lock settings:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary(ctx),
                    fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: emailController,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Sender Email',
                    hintText: 'e.g. notifications@github.com',
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(isNerd ? 4 : 10),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter an email address';
                    }
                    if (!val.contains('@') || !val.contains('.')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
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
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(ctx, emailController.text.trim().toLowerCase());
                }
              },
              child: const Text('Next'),
            ),
          ],
        );
      },
    );

    if (email != null && email.isNotEmpty && mounted) {
      await showSetPreferredTagDialog(
        context: this.context,
        ref: ref,
        senderEmail: email,
      );
    }
  }

  Future<void> _confirmDeleteRule(BuildContext context, SenderRule rule) async {
    final isNerd = AppTheme.isNerd(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isNerd ? '> REMOVE_SENDER_RULE' : 'Remove Rule?',
          style: TextStyle(fontFamily: isNerd ? AppTheme.nerdFontFamily : null),
        ),
        content: Text(
          'Remove preferred tag rule for "${rule.senderEmail}"?\n\nFuture emails from this sender will be categorized automatically using standard classification.',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary(ctx),
            fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.deleteColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove Rule'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(this.context);
      await ref.read(messageRepositoryProvider).deleteSenderRule(rule.senderEmail);
      if (mounted) {
        SnackBarUtils.showAutoHideSnackBar(
          messenger: messenger,
          message: 'Removed preferred tag rule for ${rule.senderEmail}',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNerd = AppTheme.isNerd(context);
    final rulesAsync = ref.watch(senderRulesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isNerd ? 'Sender Tag Rules' : 'Sender Preferred Tags',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          IconButton(
            key: const ValueKey('add_sender_rule_appbar_btn'),
            icon: const Icon(Icons.add),
            tooltip: 'Add sender rule',
            onPressed: () => _showAddRulePrompt(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add_sender_rule_fab'),
        onPressed: () => _showAddRulePrompt(context),
        icon: const Icon(Icons.add),
        label: Text(
          isNerd ? 'ADD_RULE' : 'Add Rule',
          style: TextStyle(fontFamily: isNerd ? AppTheme.nerdFontFamily : null),
        ),
      ),
      body: rulesAsync.when(
        data: (allRules) {
          if (allRules.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: isNerd ? const Color(0xFF003311) : const Color(0xFFE8F5E9),
                      child: Icon(
                        Icons.rule_folder_outlined,
                        size: 36,
                        color: isNerd ? AppTheme.nerdPrimary : Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isNerd ? '> NO_SENDER_RULES_CONFIGURED' : 'No Sender Rules Configured',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Preferred tag rules let you automatically categorize and lock emails from specific senders.\n\nTap "+ Add Rule" or tap the category tag directly on any email to create a rule.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary(context),
                        fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => _showAddRulePrompt(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        isNerd ? 'CREATE_FIRST_RULE' : 'Create First Rule',
                        style: TextStyle(fontFamily: isNerd ? AppTheme.nerdFontFamily : null),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final filteredRules = allRules.where((rule) {
            if (_searchQuery.isEmpty) return true;
            final email = rule.senderEmail.toLowerCase();
            final cat = rule.preferredCategory.label.toLowerCase();
            final custom = rule.customTag?.toLowerCase() ?? '';
            return email.contains(_searchQuery) ||
                cat.contains(_searchQuery) ||
                custom.contains(_searchQuery);
          }).toList();

          return Column(
            children: [
              // Search & Filter Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: isNerd ? 'SEARCH_RULES...' : 'Search senders or tags...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(isNerd ? 4 : 10),
                    ),
                  ),
                ),
              ),

              // Summary counter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      isNerd
                          ? '// ${filteredRules.length} OF ${allRules.length} RULES'
                          : '${filteredRules.length} of ${allRules.length} rule${allRules.length == 1 ? "" : "s"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary(context),
                        fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                      ),
                    ),
                  ],
                ),
              ),

              // Rules List
              Expanded(
                child: filteredRules.isEmpty
                    ? Center(
                        child: Text(
                          isNerd ? '// NO RULES MATCH "$_searchQuery"' : 'No rules match "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary(context),
                            fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                        itemCount: filteredRules.length,
                        itemBuilder: (context, index) {
                          final rule = filteredRules[index];
                          return Card(
                            key: ValueKey('sender_rule_${rule.senderEmail}'),
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: AppTheme.border(context)),
                              borderRadius: BorderRadius.circular(isNerd ? 4 : 10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: AppTheme.lightPrimary.withOpacity(0.12),
                                        child: Text(
                                          rule.senderEmail.isNotEmpty
                                              ? rule.senderEmail[0].toUpperCase()
                                              : '@',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.lightPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          rule.senderEmail,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            fontFamily: isNerd ? AppTheme.nerdFontFamily : null,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        key: ValueKey('edit_rule_${rule.senderEmail}'),
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        tooltip: 'Edit rule',
                                        onPressed: () {
                                          showSetPreferredTagDialog(
                                            context: context,
                                            ref: ref,
                                            senderEmail: rule.senderEmail,
                                            currentCategory: rule.preferredCategory,
                                            currentCustomTag: rule.customTag,
                                          );
                                        },
                                      ),
                                      IconButton(
                                        key: ValueKey('delete_rule_${rule.senderEmail}'),
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.deleteColor),
                                        tooltip: 'Remove rule',
                                        onPressed: () => _confirmDeleteRule(context, rule),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.lightPrimary.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(isNerd ? 2 : 6),
                                        ),
                                        child: Text(
                                          rule.preferredCategory.label,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.lightPrimary,
                                          ),
                                        ),
                                      ),
                                      if (rule.customTag != null && rule.customTag!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isNerd
                                                ? AppTheme.nerdAccentCyan.withOpacity(0.15)
                                                : Colors.teal.shade50,
                                            borderRadius: BorderRadius.circular(isNerd ? 2 : 6),
                                            border: Border.all(
                                              color: isNerd ? AppTheme.nerdAccentCyan : Colors.teal.shade300,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            '🏷️ ${rule.customTag}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isNerd ? AppTheme.nerdAccentCyan : Colors.teal.shade800,
                                            ),
                                          ),
                                        ),
                                      if (rule.isAutoLocked)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isNerd
                                                ? AppTheme.nerdAccentYellow.withOpacity(0.15)
                                                : Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(isNerd ? 2 : 6),
                                            border: Border.all(
                                              color: isNerd ? AppTheme.nerdAccentYellow : Colors.amber.shade400,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.lock,
                                                size: 11,
                                                color: isNerd ? AppTheme.nerdAccentYellow : Colors.amber.shade800,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Auto-Locked',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isNerd ? AppTheme.nerdAccentYellow : Colors.amber.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading rules: $e')),
      ),
    );
  }
}
