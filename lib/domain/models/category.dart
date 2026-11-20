/// Email categorization buckets supported by CleanMail.
enum MailCategory {
  all('All', 'All Inboxes'),
  personal('Personal', 'Direct & Personal'),
  newsletters('Newsletters', 'Newsletters & Subscriptions'),
  transactions('Transactions', 'Receipts & Orders'),
  updates('Updates', 'Notifications & Alerts');

  final String label;
  final String description;

  const MailCategory(this.label, this.description);

  static MailCategory fromString(String? value) {
    if (value == null) return MailCategory.personal;
    return MailCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => MailCategory.personal,
    );
  }
}
