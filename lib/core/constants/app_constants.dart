class AppConstants {
  const AppConstants._();

  static const String appName = 'CleanMail';
  static const String appTagline = 'Distraction-Free Text Mail';

  // Account badge colors (hex integer values)
  static const List<int> accountBadgeColors = [
    0xFF1E88E5, // Blue
    0xFF8E24AA, // Purple
    0xFF00897B, // Teal
    0xFFE65100, // Deep Orange
    0xFF43A047, // Green
    0xFF3949AB, // Indigo
  ];

  // OAuth Scopes
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );

  static const List<String> googleScopes = [
    'email',
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.modify',
  ];

  static const List<String> microsoftScopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
    'Mail.ReadWrite',
  ];
}
