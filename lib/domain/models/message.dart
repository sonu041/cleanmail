import 'category.dart';

class MailMessage {
  final String id;
  final String accountId;
  final String remoteMessageId;
  final String? threadId;
  final String senderEmail;
  final String senderName;
  final String subject;
  final String snippet;
  final String plainTextBody;
  final MailCategory category;
  final String? customTag;
  final String? unsubscribeUrl;
  final String? unsubscribeMailto;
  final bool isRead;
  final bool isArchived;
  final bool isStarred;
  final bool isLocked;
  final DateTime receivedAt;

  const MailMessage({
    required this.id,
    required this.accountId,
    required this.remoteMessageId,
    this.threadId,
    required this.senderEmail,
    required this.senderName,
    required this.subject,
    required this.snippet,
    required this.plainTextBody,
    required this.category,
    this.customTag,
    this.unsubscribeUrl,
    this.unsubscribeMailto,
    this.isRead = false,
    this.isArchived = false,
    this.isStarred = false,
    this.isLocked = false,
    required this.receivedAt,
  });

  bool get hasUnsubscribeOption =>
      (unsubscribeUrl != null && unsubscribeUrl!.isNotEmpty) ||
      (unsubscribeMailto != null && unsubscribeMailto!.isNotEmpty);

  MailMessage copyWith({
    String? id,
    String? accountId,
    String? remoteMessageId,
    String? threadId,
    String? senderEmail,
    String? senderName,
    String? subject,
    String? snippet,
    String? plainTextBody,
    MailCategory? category,
    String? customTag,
    String? unsubscribeUrl,
    String? unsubscribeMailto,
    bool? isRead,
    bool? isArchived,
    bool? isStarred,
    bool? isLocked,
    DateTime? receivedAt,
  }) {
    return MailMessage(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      remoteMessageId: remoteMessageId ?? this.remoteMessageId,
      threadId: threadId ?? this.threadId,
      senderEmail: senderEmail ?? this.senderEmail,
      senderName: senderName ?? this.senderName,
      subject: subject ?? this.subject,
      snippet: snippet ?? this.snippet,
      plainTextBody: plainTextBody ?? this.plainTextBody,
      category: category ?? this.category,
      customTag: customTag ?? this.customTag,
      unsubscribeUrl: unsubscribeUrl ?? this.unsubscribeUrl,
      unsubscribeMailto: unsubscribeMailto ?? this.unsubscribeMailto,
      isRead: isRead ?? this.isRead,
      isArchived: isArchived ?? this.isArchived,
      isStarred: isStarred ?? this.isStarred,
      isLocked: isLocked ?? this.isLocked,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }
}
