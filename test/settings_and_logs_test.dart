import 'package:cleanmail/core/services/auto_sync_service.dart';
import 'package:cleanmail/core/services/google_auth_service.dart';
import 'package:cleanmail/core/services/log_service.dart';
import 'package:cleanmail/core/theme/app_theme.dart';
import 'package:dio/dio.dart';
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

    test('Auto purge info and success logs older than 100 entries while keeping the 100 newest', () async {
      await logService.clearLogs();

      // Add 120 info & success logs (60 info, 60 success)
      for (int i = 1; i <= 60; i++) {
        AppLogger.info('Info Event $i', 'Detail info $i');
      }
      for (int i = 1; i <= 60; i++) {
        AppLogger.success('Success Event $i', 'Detail success $i');
      }

      // Total info & success logs should be auto-purged to exactly 100
      expect(logService.logs.length, equals(100));

      // The newest 60 are Success Event 60 down to 1
      expect(logService.logs[0].title, equals('Success Event 60'));
      expect(logService.logs[59].title, equals('Success Event 1'));

      // The remaining 40 slots are Info Event 60 down to 21
      expect(logService.logs[60].title, equals('Info Event 60'));
      expect(logService.logs[99].title, equals('Info Event 21'));

      // Info events 1 through 20 (older than 100) were purged
      final hasOldInfo1 = logService.logs.any((l) => l.title == 'Info Event 1');
      final hasOldInfo20 = logService.logs.any((l) => l.title == 'Info Event 20');
      expect(hasOldInfo1, isFalse);
      expect(hasOldInfo20, isFalse);
    });

    test('Warnings and Errors are preserved when info and success messages older than 100 are purged', () async {
      await logService.clearLogs();

      // 1. Add critical warning and error first
      AppLogger.warning('Critical Warning', 'Important rate limit warning');
      AppLogger.error('Critical Error', 'Database auth error');

      // 2. Add 110 info messages (which would exceed 100 and trigger purge)
      for (int i = 1; i <= 110; i++) {
        AppLogger.info('Sync Batch $i', 'Processed message $i');
      }

      // 100 info messages kept + 2 warning/error preserved = 102 total logs
      expect(logService.logs.length, equals(102));

      // Info batches 101 to 110 were purged, batches 11 to 110 are kept
      expect(logService.logs.first.title, equals('Sync Batch 110'));
      expect(logService.logs.any((l) => l.title == 'Sync Batch 1'), isFalse);
      expect(logService.logs.any((l) => l.title == 'Sync Batch 10'), isFalse);
      expect(logService.logs.any((l) => l.title == 'Sync Batch 11'), isTrue);

      // Warning and error are preserved even though older than 100 info messages
      expect(logService.logs.any((l) => l.title == 'Critical Warning'), isTrue);
      expect(logService.logs.any((l) => l.title == 'Critical Error'), isTrue);
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

  group('Rate Limit & Error Formatting Tests', () {
    test('AutoSyncNotifier.isRateLimitError identifies 403, 429, and quota errors', () {
      expect(AutoSyncNotifier.isRateLimitError('Rate limit reached (403/429): Gmail API quota exceeded.'), isTrue);
      expect(AutoSyncNotifier.isRateLimitError('DioException [bad response]: status code of 403'), isTrue);
      expect(AutoSyncNotifier.isRateLimitError('Error 429 Too Many Requests'), isTrue);
      expect(AutoSyncNotifier.isRateLimitError('userRateLimitExceeded'), isTrue);
      expect(AutoSyncNotifier.isRateLimitError('Quota exceeded for quota metric'), isTrue);
      expect(AutoSyncNotifier.isRateLimitError('Unauthorized (401). Token was rejected or expired.'), isFalse);
      expect(AutoSyncNotifier.isRateLimitError('Network connection timed out'), isFalse);
    });

    test('GoogleAuthService.formatErrorMessage properly categorizes 403 quota and rate limits', () {
      final dioRateLimit403 = DioException(
        requestOptions: RequestOptions(path: 'https://gmail.googleapis.com/gmail/v1/users/me/messages'),
        response: Response(
          requestOptions: RequestOptions(path: 'https://gmail.googleapis.com/gmail/v1/users/me/messages'),
          statusCode: 403,
          data: {
            'error': {
              'message': 'User-rate limit exceeded. Retry later.',
            }
          },
        ),
      );
      final msg = GoogleAuthService.formatErrorMessage(dioRateLimit403);
      expect(msg, contains('Rate limit reached (403)'));

      final dio429 = DioException(
        requestOptions: RequestOptions(path: 'https://gmail.googleapis.com/gmail/v1/users/me/messages'),
        response: Response(
          requestOptions: RequestOptions(path: 'https://gmail.googleapis.com/gmail/v1/users/me/messages'),
          statusCode: 429,
        ),
      );
      expect(GoogleAuthService.formatErrorMessage(dio429), contains('Rate limit reached (429)'));
    });
  });
}
