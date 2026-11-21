import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/sender_rule.dart';
import '../../../providers.dart';

/// Shows a dialog or modal bottom sheet to configure a sender's preferred tag rule.
Future<void> showSetPreferredTagDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String senderEmail,
  String? senderName,
  MailCategory? currentCategory,
  String? currentCustomTag,
}) async {
  final repo = ref.read(messageRepositoryProvider);
  final existingRule = await repo.getSenderRule(senderEmail);

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => SetPreferredTagDialog(
      senderEmail: senderEmail,
      senderName: senderName ?? '',
      initialCategory: existingRule?.preferredCategory ?? currentCategory ?? MailCategory.personal,
      initialCustomTag: existingRule?.customTag ?? currentCustomTag,
      initialAutoLocked: existingRule?.isAutoLocked ?? false,
      existingRule: existingRule,
    ),
  );
}

class SetPreferredTagDialog extends ConsumerStatefulWidget {
  final String senderEmail;
  final String senderName;
  final MailCategory initialCategory;
  final String? initialCustomTag;
  final bool initialAutoLocked;
  final SenderRule? existingRule;

  const SetPreferredTagDialog({
    super.key,
    required this.senderEmail,
    required this.senderName,
    required this.initialCategory,
    this.initialCustomTag,
    this.initialAutoLocked = false,
    this.existingRule,
  });

  @override
  ConsumerState<SetPreferredTagDialog> createState() => _SetPreferredTagDialogState();
}

class _SetPreferredTagDialogState extends ConsumerState<SetPreferredTagDialog> {
  late MailCategory _selectedCategory;
  late TextEditingController _customTagController;
  late bool _autoLock;
  bool _applyToExisting = true;
  bool _isSaving = false;

  final List<MailCategory> _availableCategories = const [
    MailCategory.personal,
    MailCategory.newsletters,
    MailCategory.transactions,
    MailCategory.updates,
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _customTagController = TextEditingController(text: widget.initialCustomTag ?? '');
    _autoLock = widget.initialAutoLocked;
  }

  @override
  void dispose() {
    _customTagController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(MailCategory cat) {
    switch (cat) {
      case MailCategory.personal:
        return Icons.person_outline_rounded;
      case MailCategory.newsletters:
        return Icons.newspaper_rounded;
      case MailCategory.transactions:
        return Icons.receipt_long_rounded;
      case MailCategory.updates:
        return Icons.notifications_none_rounded;
      case MailCategory.all:
        return Icons.all_inbox_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNerd = AppTheme.isNerd(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isNerd ? AppTheme.nerdPrimary : (isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary);

    final displayName = widget.senderName.isNotEmpty ? widget.senderName : widget.senderEmail;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.label_outlined, color: primaryColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isNerd ? '> SET_PREFERRED_TAG' : 'Set Preferred Tag',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: AppTheme.fontFamily(context),
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Target sender banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(isNerd ? 2 : 8),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sender:',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary(context),
                        fontFamily: AppTheme.fontFamily(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textPrimary(context),
                        fontFamily: AppTheme.fontFamily(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.senderEmail,
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryColor,
                        fontFamily: AppTheme.fontFamily(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Choose Preferred Tag / Category:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                  fontFamily: AppTheme.fontFamily(context),
                ),
              ),
              const SizedBox(height: 8),

              // Category choice chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableCategories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    key: ValueKey('pref_cat_chip_${cat.name}'),
                    avatar: Icon(
                      _getCategoryIcon(cat),
                      size: 16,
                      color: isSelected
                          ? (isNerd ? Colors.black : Colors.white)
                          : primaryColor,
                    ),
                    label: Text(
                      isNerd ? '[${cat.name.toUpperCase()}]' : cat.label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontFamily: AppTheme.fontFamily(context),
                        color: isSelected
                            ? (isNerd ? Colors.black : Colors.white)
                            : AppTheme.textPrimary(context),
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: primaryColor,
                    backgroundColor: AppTheme.surface(context),
                    onSelected: (_) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Optional Custom Tag
              Text(
                'Custom Tag Label (Optional):',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary(context),
                  fontFamily: AppTheme.fontFamily(context),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('pref_custom_tag_input'),
                controller: _customTagController,
                decoration: InputDecoration(
                  hintText: 'e.g. Work, Finance, VIP, Receipts',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary(context).withOpacity(0.5),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(isNerd ? 2 : 8),
                  ),
                ),
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: AppTheme.fontFamily(context),
                ),
              ),
              const SizedBox(height: 14),

              // Auto-Lock toggle
              CheckboxListTile(
                key: const ValueKey('pref_auto_lock_toggle'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _autoLock,
                activeColor: primaryColor,
                secondary: Icon(
                  Icons.lock_outline,
                  size: 20,
                  color: _autoLock
                      ? (isNerd ? AppTheme.nerdAccentRed : Colors.amber.shade800)
                      : AppTheme.textSecondary(context),
                ),
                title: Text(
                  'Auto-Lock emails from this sender',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: AppTheme.fontFamily(context),
                  ),
                ),
                subtitle: Text(
                  'Automatically locks incoming emails so they are protected from accidental deletion.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary(context),
                    fontFamily: AppTheme.fontFamily(context),
                  ),
                ),
                onChanged: (val) => setState(() => _autoLock = val ?? false),
              ),

              // Apply to existing emails checkbox
              CheckboxListTile(
                key: const ValueKey('pref_apply_existing_toggle'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _applyToExisting,
                activeColor: primaryColor,
                title: Text(
                  'Apply to all existing emails from this sender',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: AppTheme.fontFamily(context),
                  ),
                ),
                subtitle: Text(
                  'Also re-tags current messages from ${widget.senderEmail} in your inbox.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary(context),
                    fontFamily: AppTheme.fontFamily(context),
                  ),
                ),
                onChanged: (val) => setState(() => _applyToExisting = val ?? true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existingRule != null)
          TextButton(
            key: const ValueKey('pref_remove_rule_btn'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.deleteColor),
            onPressed: _isSaving ? null : () => _handleRemoveRule(context),
            child: const Text('Remove Rule'),
          ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('pref_save_rule_btn'),
          style: FilledButton.styleFrom(backgroundColor: primaryColor),
          onPressed: _isSaving ? null : () => _handleSaveRule(context),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save Preferred Tag'),
        ),
      ],
    );
  }

  Future<void> _handleSaveRule(BuildContext context) async {
    setState(() => _isSaving = true);
    final repo = ref.read(messageRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final rawCustomTag = _customTagController.text.trim();
    final customTag = rawCustomTag.isNotEmpty ? rawCustomTag : null;
    final now = DateTime.now();

    final rule = SenderRule(
      senderEmail: widget.senderEmail.toLowerCase().trim(),
      preferredCategory: _selectedCategory,
      customTag: customTag,
      isAutoLocked: _autoLock,
      createdAt: widget.existingRule?.createdAt ?? now,
      updatedAt: now,
    );

    await repo.setSenderRule(rule, applyToExisting: _applyToExisting);

    if (mounted) {
      navigator.pop();
      final tagLabel = customTag != null
          ? '${_selectedCategory.label} / $customTag'
          : _selectedCategory.label;
      SnackBarUtils.showAutoHideSnackBar(
        messenger: messenger,
        message: 'Preferred tag [$tagLabel] set for ${widget.senderEmail}',
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> _handleRemoveRule(BuildContext context) async {
    setState(() => _isSaving = true);
    final repo = ref.read(messageRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await repo.deleteSenderRule(widget.senderEmail);

    if (mounted) {
      navigator.pop();
      SnackBarUtils.showAutoHideSnackBar(
        messenger: messenger,
        message: 'Preferred tag rule removed for ${widget.senderEmail}',
        duration: const Duration(seconds: 4),
      );
    }
  }
}
