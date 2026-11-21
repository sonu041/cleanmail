import 'category.dart';

/// Preference rule specifying how incoming emails from a specific sender should be tagged.
class SenderRule {
  final String senderEmail;
  final MailCategory preferredCategory;
  final String? customTag;
  final bool isAutoLocked;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SenderRule({
    required this.senderEmail,
    required this.preferredCategory,
    this.customTag,
    this.isAutoLocked = false,
    required this.createdAt,
    required this.updatedAt,
  });

  SenderRule copyWith({
    String? senderEmail,
    MailCategory? preferredCategory,
    String? customTag,
    bool? isAutoLocked,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SenderRule(
      senderEmail: senderEmail ?? this.senderEmail,
      preferredCategory: preferredCategory ?? this.preferredCategory,
      customTag: customTag ?? this.customTag,
      isAutoLocked: isAutoLocked ?? this.isAutoLocked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SenderRule &&
          runtimeType == other.runtimeType &&
          senderEmail.toLowerCase() == other.senderEmail.toLowerCase() &&
          preferredCategory == other.preferredCategory &&
          customTag == other.customTag &&
          isAutoLocked == other.isAutoLocked;

  @override
  int get hashCode =>
      senderEmail.toLowerCase().hashCode ^
      preferredCategory.hashCode ^
      customTag.hashCode ^
      isAutoLocked.hashCode;
}
