enum MailProvider {
  gmail('Gmail', 'Google Workspace / Gmail'),
  outlook('Outlook', 'Microsoft 365 / Outlook');

  final String label;
  final String description;

  const MailProvider(this.label, this.description);

  static MailProvider fromString(String value) {
    return MailProvider.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => MailProvider.gmail,
    );
  }
}

class MailAccount {
  final String id;
  final String email;
  final String displayName;
  final MailProvider provider;
  final int avatarColorValue;
  final DateTime? lastSyncedAt;

  const MailAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.provider,
    required this.avatarColorValue,
    this.lastSyncedAt,
  });

  MailAccount copyWith({
    String? id,
    String? email,
    String? displayName,
    MailProvider? provider,
    int? avatarColorValue,
    DateTime? lastSyncedAt,
  }) {
    return MailAccount(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      provider: provider ?? this.provider,
      avatarColorValue: avatarColorValue ?? this.avatarColorValue,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
