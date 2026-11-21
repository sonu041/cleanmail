import 'package:cleanmail/core/services/google_auth_service.dart';
import 'package:cleanmail/core/services/log_service.dart';
import 'package:cleanmail/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Token Expiration & Storage Tests', () {
    test('GoogleAuthService detects expired token and manages storage', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({});
      final authService = GoogleAuthService();
      const testAccountId = 'test_acc_exp_123';

      await authService.clearStoredToken(testAccountId);

      // Initially no token exists -> treated as expired
      final initiallyExpired = await authService.isStoredTokenExpired(testAccountId);
      expect(initiallyExpired, isTrue);

      // Save a fresh token
      await authService.saveStoredToken(testAccountId, 'sample_bearer_token');

      // Stored token is now fresh (<50m)
      final afterSaveExpired = await authService.isStoredTokenExpired(testAccountId);
      expect(afterSaveExpired, isFalse);

      final token = await authService.getStoredToken(testAccountId);
      expect(token, equals('Bearer sample_bearer_token'));

      // Clean up
      await authService.clearStoredToken(testAccountId);
      final afterClearExpired = await authService.isStoredTokenExpired(testAccountId);
      expect(afterClearExpired, isTrue);
    });
  });
  group('LogService & AppLogger Tests', () {
    late LogService logService;

    setUp(() async {
      logService = LogService();
      await logService.clearLogs();
    });

    tearDown(() async {
      await logService.clearLogs();
    });

    test('Initial log service is empty with zero metrics', () {
      expect(logService.logs, isEmpty);
      expect(logService.totalMailsSynced, equals(0));
      expect(logService.lastLoginOrTokenRefresh, isNull);
      expect(logService.lastSyncTime, isNull);
    });

    test('Recording sync log updates sync metrics and adds entry', () {
      AppLogger.success(
        'Gmail Sync Complete',
        'Synced 25 new emails for user@gmail.com',
        category: LogCategory.sync,
        metadata: {'syncedCount': 25, 'account': 'user@gmail.com'},
      );

      expect(logService.logs.length, equals(1));
      final firstLog = logService.logs.first;
      expect(firstLog.title, equals('Gmail Sync Complete'));
      expect(firstLog.category, equals(LogCategory.sync));
      expect(firstLog.level, equals(LogLevel.success));
      expect(logService.totalMailsSynced, equals(25));
      expect(logService.lastSyncTime, isNotNull);
    });

    test('Recording auth log updates lastLoginOrTokenRefresh', () {
      AppLogger.info(
        'OAuth Token Refreshed',
        'Valid bearer token cached for work@gmail.com',
        category: LogCategory.auth,
      );

      expect(logService.logs.length, equals(1));
      expect(logService.lastLoginOrTokenRefresh, isNotNull);
      expect(logService.logs.first.category, equals(LogCategory.auth));
    });

    test('Multiple logs maintain newest-first order and cap properly', () {
      AppLogger.info('Event 1', 'Detail 1');
      AppLogger.warning('Event 2', 'Detail 2');
      AppLogger.error('Event 3', 'Detail 3');

      expect(logService.logs.length, equals(3));
      expect(logService.logs[0].title, equals('Event 3'));
      expect(logService.logs[1].title, equals('Event 2'));
      expect(logService.logs[2].title, equals('Event 1'));
    });

    test('Exporting logs creates formatted report text', () {
      AppLogger.success(
        'Initial Sync',
        'Synced 12 emails',
        category: LogCategory.sync,
        metadata: {'syncedCount': 12},
      );

      final report = logService.exportLogsAsText();
      expect(report, contains('CLEANMAIL OPERATION LOG REPORT'));
      expect(report, contains('Initial Sync'));
      expect(report, contains('Synced 12 emails'));
      expect(report, contains('Total Mails Synced: 12'));
    });

    test('clearLogs clears in-memory logs and resets metrics', () async {
      AppLogger.success(
        'Sync Complete',
        'Synced 40 emails',
        category: LogCategory.sync,
        metadata: {'syncedCount': 40},
      );
      expect(logService.logs.length, equals(1));
      expect(logService.totalMailsSynced, equals(40));

      await logService.clearLogs();
      expect(logService.logs, isEmpty);
      expect(logService.totalMailsSynced, equals(0));
    });
  });

  group('AppTheme & Nerd Theme Tests', () {
    test('AppThemeMode system is the default', () {
      expect(AppThemeMode.fromString(null), equals(AppThemeMode.system));
      expect(AppThemeMode.fromString('system'), equals(AppThemeMode.system));
      expect(AppThemeMode.fromString('nerd'), equals(AppThemeMode.nerd));
      expect(AppThemeMode.fromString('light'), equals(AppThemeMode.light));
      expect(AppThemeMode.fromString('dark'), equals(AppThemeMode.dark));
    });

    test('Nerd theme has dark brightness, JetBrains Mono font, and phosphor green primary', () {
      final nerd = AppTheme.nerdTheme;
      expect(nerd.brightness, equals(Brightness.dark));
      expect(nerd.colorScheme.primary, equals(AppTheme.nerdPrimary));
      expect(nerd.colorScheme.primary, equals(const Color(0xFF00FF66)));
      expect(nerd.scaffoldBackgroundColor, equals(AppTheme.nerdBg));
      expect(nerd.textTheme.bodyLarge?.fontFamily, equals(AppTheme.nerdFontFamily));
      expect(nerd.textTheme.headlineMedium?.fontFamily, equals(AppTheme.nerdFontFamily));
      expect(nerd.appBarTheme.titleTextStyle?.fontFamily, equals(AppTheme.nerdFontFamily));
    });

    test('Light and Dark themes maintain clean standard styling', () {
      final light = AppTheme.lightTheme;
      expect(light.brightness, equals(Brightness.light));
      expect(light.colorScheme.primary, equals(AppTheme.lightPrimary));

      final dark = AppTheme.darkTheme;
      expect(dark.brightness, equals(Brightness.dark));
      expect(dark.colorScheme.primary, equals(AppTheme.darkPrimary));
    });
  });
}
