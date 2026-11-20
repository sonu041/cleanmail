class SenderSummary {
  final String senderEmail;
  final String senderName;
  final int totalCount;
  final int unreadCount;
  final DateTime lastReceivedAt;
  final String latestSubject;
  final String accountId;

  const SenderSummary({
    required this.senderEmail,
    required this.senderName,
    required this.totalCount,
    required this.unreadCount,
    required this.lastReceivedAt,
    required this.latestSubject,
    required this.accountId,
  });
}
