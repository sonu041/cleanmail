import '../../domain/models/category.dart';

/// Client-side heuristic categorizer for incoming emails.
/// Operates completely on-device with zero network latency.
class HeuristicClassifier {
  const HeuristicClassifier._();

  static const List<String> _transactionSubjectKeywords = [
    'receipt',
    'invoice',
    'order confirmation',
    'your order',
    'payment received',
    'payment confirmed',
    'payment processed',
    'billing statement',
    'subscription renewed',
    'your purchase',
    'order placed',
    'tracking number',
    'shipment',
    'delivered',
    'dispatched',
    'refund processed',
    'e-receipt',
  ];

  static const List<String> _transactionSenderKeywords = [
    'orders@',
    'order@',
    'billing@',
    'receipts@',
    'receipt@',
    'invoices@',
    'invoice@',
    'payments@',
    'payment@',
    'payments-noreply@',
    'transfers@',
  ];

  static const List<String> _updateSenderKeywords = [
    'notifications@',
    'notification@',
    'no-reply@',
    'noreply@',
    'alerts@',
    'alert@',
    'security@',
    'updates@',
    'system@',
  ];

  static const List<String> _updateDomains = [
    'github.com',
    'linkedin.com',
    'slack.com',
    'atlassian.net',
    'jira.com',
    'trello.com',
    'calendar.google.com',
    'gitlab.com',
  ];

  static const List<String> _newsletterDomains = [
    'substack.com',
    'mailchimp.com',
    'beehiiv.com',
    'medium.com',
    'convertkit.com',
    'buttondown.email',
    'campaign-archive.com',
  ];

  /// Classifies an email into a [MailCategory] based on MIME headers,
  /// sender, and subject.
  static MailCategory classify({
    required String senderEmail,
    required String subject,
    required String snippet,
    String? unsubscribeHeader,
    String? precedenceHeader,
    Map<String, String>? rawHeaders,
  }) {
    final lowerSender = senderEmail.toLowerCase();
    final lowerSubject = subject.toLowerCase();
    final lowerSnippet = snippet.toLowerCase();

    // 1. Newsletters: Explicit unsubscribe or bulk headers
    if (unsubscribeHeader != null && unsubscribeHeader.trim().isNotEmpty) {
      return MailCategory.newsletters;
    }

    if (precedenceHeader != null &&
        (precedenceHeader.toLowerCase().contains('bulk') ||
            precedenceHeader.toLowerCase().contains('list'))) {
      return MailCategory.newsletters;
    }

    for (final domain in _newsletterDomains) {
      if (lowerSender.contains(domain)) {
        return MailCategory.newsletters;
      }
    }

    // 2. Transactions / Receipts
    for (final kw in _transactionSenderKeywords) {
      if (lowerSender.contains(kw)) {
        return MailCategory.transactions;
      }
    }

    for (final kw in _transactionSubjectKeywords) {
      if (lowerSubject.contains(kw) || lowerSnippet.contains(kw)) {
        return MailCategory.transactions;
      }
    }

    // 3. Updates / Automated Notifications
    for (final domain in _updateDomains) {
      if (lowerSender.contains(domain)) {
        return MailCategory.updates;
      }
    }

    for (final kw in _updateSenderKeywords) {
      if (lowerSender.contains(kw)) {
        return MailCategory.updates;
      }
    }

    if (lowerSubject.contains('security alert') ||
        lowerSubject.contains('login alert') ||
        lowerSubject.contains('verification code') ||
        lowerSubject.contains('password reset') ||
        lowerSubject.contains('daily digest')) {
      return MailCategory.updates;
    }

    // 4. Default: Personal / Direct Communication
    return MailCategory.personal;
  }
}
