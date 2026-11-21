import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import '../../domain/models/account.dart';
import '../../domain/models/message.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/message_repository.dart';
import '../constants/app_constants.dart';
import '../services/log_service.dart';
import '../utils/heuristic_classifier.dart';
import '../utils/html_to_text.dart';

class GoogleAuthService {
  static const _storage = FlutterSecureStorage();
  static const _clientIdKey = 'cleanmail_google_client_id';
  final Dio _dio;

  GoogleSignIn? _googleSignInInstance;

  GoogleAuthService([Dio? dio]) : _dio = dio ?? Dio();

  static const List<String> gmailScopes = [
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.modify',
  ];

  GoogleSignIn _getGoogleSignIn(String? clientId) {
    final effectiveClientId = (clientId != null && clientId.trim().isNotEmpty) ? clientId.trim() : null;

    return GoogleSignIn(
      // On Web, clientId is required.
      // On Android/iOS, passing clientId overrides Google Play Services resolution and throws
      // PlatformException(sign_in_failed).
      clientId: kIsWeb ? effectiveClientId : null,
      serverClientId: !kIsWeb ? effectiveClientId : null,
      scopes: [
        'email',
        ...gmailScopes,
      ],
    );
  }

  /// Retrieve the configured Google Client ID.
  Future<String> getClientId() async {
    final stored = await _storage.read(key: _clientIdKey);
    if (stored != null && stored.trim().isNotEmpty) {
      return stored.trim();
    }
    return AppConstants.googleClientId;
  }

  /// Store or update the Google Client ID securely on device.
  Future<void> setClientId(String clientId) async {
    await _storage.write(key: _clientIdKey, value: clientId.trim());
    _googleSignInInstance = null; // Reset instance so new client ID is picked up
  }

  Stream<GoogleSignInAccount?> get onCurrentUserChanged {
    _googleSignInInstance ??= _getGoogleSignIn(AppConstants.googleClientId);
    return _googleSignInInstance!.onCurrentUserChanged;
  }

  // --------------------------------------------------------------------------
  // TOKEN & HISTORY ID STORAGE (PER-ACCOUNT OAUTH & APPROACH 2 DELTA SYNC)
  // --------------------------------------------------------------------------

  String _historyKey(String accountId) => 'gmail_history_$accountId';
  String _pageTokenKey(String accountId) => 'gmail_page_token_$accountId';
  String _tokenKey(String accountId) => 'gmail_token_$accountId';
  String _tokenTimeKey(String accountId) => 'gmail_token_time_$accountId';

  Future<String?> getStoredHistoryId(String accountId) async {
    return await _storage.read(key: _historyKey(accountId));
  }

  Future<void> saveStoredHistoryId(String accountId, String historyId) async {
    await _storage.write(key: _historyKey(accountId), value: historyId);
  }

  Future<void> clearStoredHistoryId(String accountId) async {
    await _storage.delete(key: _historyKey(accountId));
  }

  Future<String?> getStoredPageToken(String accountId) async {
    return await _storage.read(key: _pageTokenKey(accountId));
  }

  Future<void> saveStoredPageToken(String accountId, String pageToken) async {
    await _storage.write(key: _pageTokenKey(accountId), value: pageToken);
  }

  Future<void> clearStoredPageToken(String accountId) async {
    await _storage.delete(key: _pageTokenKey(accountId));
  }

  Future<String?> getStoredToken(String accountId) async {
    final direct = await _storage.read(key: _tokenKey(accountId));
    if (direct != null && direct.isNotEmpty) return direct;

    final lower = await _storage.read(key: _tokenKey(accountId.toLowerCase()));
    if (lower != null && lower.isNotEmpty) return lower;

    if (accountId.startsWith('google_')) {
      final stripped = accountId.replaceFirst('google_', '');
      final alt = await _storage.read(key: _tokenKey(stripped));
      if (alt != null && alt.isNotEmpty) return alt;
    } else {
      final alt = await _storage.read(key: _tokenKey('google_$accountId'));
      if (alt != null && alt.isNotEmpty) return alt;
    }
    return null;
  }

  Future<void> saveStoredToken(String accountId, String token) async {
    final bearerToken = token.startsWith('Bearer ') ? token : 'Bearer $token';
    final nowMs = DateTime.now().millisecondsSinceEpoch.toString();

    final keys = <String>{accountId};
    if (accountId.startsWith('google_')) {
      keys.add(accountId.replaceFirst('google_', ''));
    } else {
      keys.add('google_$accountId');
    }
    keys.add(accountId.toLowerCase());

    for (final k in keys) {
      await _storage.write(key: _tokenKey(k), value: bearerToken);
      await _storage.write(key: _tokenTimeKey(k), value: nowMs);
    }
  }

  Future<void> clearStoredToken(String accountId, [String? tokenToInvalidate]) async {
    final token = tokenToInvalidate ?? await getStoredToken(accountId);
    final keys = <String>{accountId};
    if (accountId.startsWith('google_')) {
      keys.add(accountId.replaceFirst('google_', ''));
    } else {
      keys.add('google_$accountId');
    }
    keys.add(accountId.toLowerCase());

    for (final k in keys) {
      await _storage.delete(key: _tokenKey(k));
      await _storage.delete(key: _tokenTimeKey(k));
    }

    if (token != null && token.isNotEmpty) {
      try {
        final rawToken = token.startsWith('Bearer ') ? token.substring(7) : token;
        await GoogleSignInPlatform.instance.clearAuthCache(token: rawToken);
        debugPrint('Cleared Google Play Services auth cache for token.');
      } catch (e) {
        debugPrint('clearAuthCache note: $e');
      }
    }
  }

  /// Checks if the cached access token is expired (>50 minutes old).
  /// Google OAuth2 access tokens expire after 3600 seconds (1 hour).
  Future<bool> isStoredTokenExpired(String accountId) async {
    final token = await getStoredToken(accountId);
    if (token == null || token.isEmpty) return true; // No token stored at all

    String? timeStr = await _storage.read(key: _tokenTimeKey(accountId));
    timeStr ??= await _storage.read(key: _tokenTimeKey(accountId.toLowerCase()));
    if (timeStr == null && accountId.startsWith('google_')) {
      timeStr = await _storage.read(key: _tokenTimeKey(accountId.replaceFirst('google_', '')));
    }
    if (timeStr == null) return false; // Legacy token without timestamp: treat as fresh until 401
    final timestamp = int.tryParse(timeStr);
    if (timestamp == null) return false;
    final ageMs = DateTime.now().millisecondsSinceEpoch - timestamp;
    // 50 minutes buffer (Google access token lifetime is 60 minutes / 3600s)
    return ageMs > 50 * 60 * 1000;
  }

  /// Fetches current mailbox profile (historyId and messagesTotal) directly from Gmail.
  Future<({String? historyId, int? messagesTotal})> fetchCurrentProfile({
    required Map<String, String> authHeaders,
  }) async {
    try {
      final response = await _dio.get(
        'https://gmail.googleapis.com/gmail/v1/users/me/profile',
        options: Options(headers: authHeaders),
      );
      final historyId = response.data['historyId']?.toString();
      final messagesTotal = (response.data['messagesTotal'] as num?)?.toInt();
      return (historyId: historyId, messagesTotal: messagesTotal);
    } catch (e) {
      debugPrint('Error fetching Gmail profile: $e');
      return (historyId: null, messagesTotal: null);
    }
  }

  /// Fetches current mailbox historyId directly from Gmail profile.
  Future<String?> fetchCurrentHistoryId({
    required Map<String, String> authHeaders,
  }) async {
    final profile = await fetchCurrentProfile(authHeaders: authHeaders);
    return profile.historyId;
  }

  /// Resolves valid OAuth Bearer headers for the specified [accountId] (or the current session).
  /// Proactively refreshes expired tokens (>50m old) and manages token caching.
  Future<Map<String, String>?> getAuthHeadersForAccount([String? accountId]) async {
    final clientId = await getClientId();
    _googleSignInInstance ??= _getGoogleSignIn(clientId);

    // 1. If stored token exists and is still fresh (<50m old), use it directly
    if (accountId != null) {
      final isExpired = await isStoredTokenExpired(accountId);
      if (!isExpired) {
        final storedToken = await getStoredToken(accountId);
        if (storedToken != null && storedToken.isNotEmpty) {
          return {
            'Authorization': storedToken,
            'Accept': 'application/json',
          };
        }
      }
    }

    // 2. Token is missing or expired (>50m old): Attempt silent refresh with Google Sign-In SDK
    try {
      var current = _googleSignInInstance!.currentUser;
      current ??= await _googleSignInInstance!.signInSilently();

      if (current != null) {
        final currentEmail = current.email.toLowerCase();
        final currentId1 = 'google_${current.id}';
        final currentId2 = 'google_${currentEmail.replaceAll('@', '_').replaceAll('.', '_')}';
        final target = accountId?.toLowerCase();

        final matchesTarget = target == null ||
            currentId1 == target ||
            currentId2 == target ||
            currentEmail == target ||
            target.contains(currentEmail.split('@').first);

        if (matchesTarget) {
          final authHeaders = await current.authHeaders;
          final auth = await current.authentication;
          final headers = Map<String, String>.from(authHeaders);
          if (!headers.containsKey('Authorization') &&
              auth.accessToken != null &&
              auth.accessToken!.isNotEmpty) {
            headers['Authorization'] = 'Bearer ${auth.accessToken}';
          }
          if (headers['Authorization'] != null) {
            await saveStoredToken(accountId ?? currentId2, headers['Authorization']!);
            AppLogger.info(
              'OAuth Token Refreshed',
              'Refreshed 1-hour access token for ${current.email}',
              category: LogCategory.auth,
            );
          }
          return headers;
        }
      }
    } catch (e) {
      debugPrint('Silent token refresh attempt note: $e');
    }

    // 3. Fallback: if silent refresh couldn't match a different accountId,
    // check if a stored token exists anyway as last resort (even if age unknown)
    if (accountId != null) {
      final storedToken = await getStoredToken(accountId);
      if (storedToken != null && storedToken.isNotEmpty) {
        return {
          'Authorization': storedToken,
          'Accept': 'application/json',
        };
      }
    }

    // 4. Fallback: active Google session headers ONLY IF accountId is unspecified.
    // When accountId is provided, we MUST NOT use a mismatched session's credentials,
    // to strictly prevent cross-mailbox email pollution and duplicate insertions!
    if (accountId == null) {
      try {
        final fallback = await _getValidAuthHeaders();
        if (fallback != null) return fallback;
      } catch (e) {
        debugPrint('Fallback auth header note: $e');
      }
    }

    return null;
  }

  /// Retrieves valid OAuth bearer headers for the current Google session.
  Future<Map<String, String>?> _getValidAuthHeaders() async {
    final clientId = await getClientId();
    _googleSignInInstance ??= _getGoogleSignIn(clientId);

    final googleAccount = _googleSignInInstance!.currentUser ??
        await _googleSignInInstance!.signInSilently();

    if (googleAccount == null) {
      debugPrint('No active Google session found.');
      return null;
    }

    try {
      final hasAccess = await _googleSignInInstance!.canAccessScopes(gmailScopes);
      if (!hasAccess) {
        await _googleSignInInstance!.requestScopes(gmailScopes);
      }
    } catch (e) {
      debugPrint('Auth header scope check note: $e');
    }

    final authHeaders = await googleAccount.authHeaders;
    final auth = await googleAccount.authentication;
    final headers = Map<String, String>.from(authHeaders);
    if (!headers.containsKey('Authorization') &&
        auth.accessToken != null &&
        auth.accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${auth.accessToken}';
    }
    return headers;
  }

  // --------------------------------------------------------------------------
  // TWO-WAY DELETE SYNC (CLEANMAIL -> GMAIL TRASH)
  // --------------------------------------------------------------------------

  /// Moves a message to Trash in real Gmail via `POST /messages/{id}/trash`.
  Future<bool> trashGmailMessage({
    required String remoteMessageId,
    String? accountId,
  }) async {
    Map<String, String>? headers;
    try {
      headers = await getAuthHeadersForAccount(accountId);
      headers ??= await _getValidAuthHeaders();
      if (headers == null) {
        debugPrint('Cannot trash Gmail message $remoteMessageId: no valid session.');
        AppLogger.warning('Trash Sync Blocked', 'No active session for account $accountId', category: LogCategory.triage);
        return false;
      }

      final response = await _dio.post(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages/$remoteMessageId/trash',
        options: Options(headers: headers),
      );

      debugPrint('Moved Gmail message $remoteMessageId to Trash: status ${response.statusCode}');
      if (response.statusCode == 200) {
        AppLogger.info('Message Trashed', 'Moved message $remoteMessageId to Gmail Trash', category: LogCategory.triage);
      }
      return response.statusCode == 200;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        debugPrint('401 in trashGmailMessage for $remoteMessageId. Attempting automatic recovery...');
        if (headers != null && headers['Authorization'] != null) {
          final old = headers['Authorization']!;
          final raw = old.startsWith('Bearer ') ? old.substring(7) : old;
          try {
            await GoogleSignInPlatform.instance.clearAuthCache(token: raw);
          } catch (_) {}
        }
        if (accountId != null) {
          await _storage.delete(key: _tokenKey(accountId));
          await _storage.delete(key: _tokenTimeKey(accountId));
        }
        final refreshedHeaders = await getAuthHeadersForAccount(accountId) ?? await _getValidAuthHeaders();
        if (refreshedHeaders != null) {
          try {
            final retryRes = await _dio.post(
              'https://gmail.googleapis.com/gmail/v1/users/me/messages/$remoteMessageId/trash',
              options: Options(headers: refreshedHeaders),
            );
            if (retryRes.statusCode == 200) {
              AppLogger.info(
                'Message Trashed (Auto-Recovered)',
                'Moved message $remoteMessageId to Gmail Trash after auto-refreshing token',
                category: LogCategory.triage,
              );
              return true;
            }
          } catch (_) {}
        }
      }
      debugPrint('Error trashing Gmail message $remoteMessageId: $e');
      AppLogger.error('Trash Sync Error', 'Failed to trash $remoteMessageId: $e', category: LogCategory.triage);
      return false;
    }
  }

  /// Restores a trashed message in real Gmail via `POST /messages/{id}/untrash`.
  Future<bool> untrashGmailMessage({
    required String remoteMessageId,
    String? accountId,
  }) async {
    try {
      final headers = await getAuthHeadersForAccount(accountId);
      if (headers == null) return false;

      final response = await _dio.post(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages/$remoteMessageId/untrash',
        options: Options(headers: headers),
      );

      debugPrint('Untrashed Gmail message $remoteMessageId: status ${response.statusCode}');
      if (response.statusCode == 200) {
        AppLogger.info('Message Untrashed', 'Restored message $remoteMessageId from Gmail Trash', category: LogCategory.triage);
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error untrashing Gmail message $remoteMessageId: $e');
      AppLogger.error('Untrash Error', 'Failed to restore $remoteMessageId: $e', category: LogCategory.triage);
      return false;
    }
  }

  /// Bulk-trashes multiple remote messages in Gmail in small parallel batches.
  Future<int> batchTrashGmailMessages({
    required List<String> remoteMessageIds,
    String? accountId,
  }) async {
    if (remoteMessageIds.isEmpty) return 0;
    final headers = await getAuthHeadersForAccount(accountId);
    if (headers == null) return 0;

    int successCount = 0;
    const chunkSize = 5;
    for (int i = 0; i < remoteMessageIds.length; i += chunkSize) {
      final chunk = remoteMessageIds.sublist(
        i,
        i + chunkSize > remoteMessageIds.length ? remoteMessageIds.length : i + chunkSize,
      );
      await Future.wait(chunk.map((remoteId) async {
        try {
          final res = await _dio.post(
            'https://gmail.googleapis.com/gmail/v1/users/me/messages/$remoteId/trash',
            options: Options(headers: headers),
          );
          if (res.statusCode == 200) successCount++;
        } catch (e) {
          debugPrint('Error batch-trashing message $remoteId: $e');
        }
      }));
    }
    AppLogger.success('Bulk Trash Sync', 'Batch-trashed $successCount of ${remoteMessageIds.length} emails in Gmail', category: LogCategory.triage);
    return successCount;
  }

  // --------------------------------------------------------------------------
  // TWO-WAY READ & ARCHIVE LABEL SYNC (CLEANMAIL -> GMAIL)
  // --------------------------------------------------------------------------

  /// Modifies labels on a Gmail message (e.g. read/unread, archive).
  Future<bool> modifyGmailMessageLabels({
    required String remoteMessageId,
    List<String>? addLabelIds,
    List<String>? removeLabelIds,
    String? accountId,
  }) async {
    final data = <String, dynamic>{};
    if (addLabelIds != null && addLabelIds.isNotEmpty) {
      data['addLabelIds'] = addLabelIds;
    }
    if (removeLabelIds != null && removeLabelIds.isNotEmpty) {
      data['removeLabelIds'] = removeLabelIds;
    }

    Map<String, String>? headers;
    try {
      headers = await getAuthHeadersForAccount(accountId);
      headers ??= await _getValidAuthHeaders();
      if (headers == null) return false;

      final response = await _dio.post(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages/$remoteMessageId/modify',
        data: data,
        options: Options(headers: headers),
      );

      debugPrint('Modified Gmail labels for $remoteMessageId: status ${response.statusCode}');
      if (response.statusCode == 200) {
        AppLogger.info('Label Modified', 'Updated labels on $remoteMessageId (add: $addLabelIds, remove: $removeLabelIds)', category: LogCategory.triage);
      }
      return response.statusCode == 200;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        debugPrint('401 in modifyGmailMessageLabels for $remoteMessageId. Attempting automatic recovery...');
        if (headers != null && headers['Authorization'] != null) {
          final old = headers['Authorization']!;
          final raw = old.startsWith('Bearer ') ? old.substring(7) : old;
          try {
            await GoogleSignInPlatform.instance.clearAuthCache(token: raw);
          } catch (_) {}
        }
        if (accountId != null) {
          await _storage.delete(key: _tokenKey(accountId));
          await _storage.delete(key: _tokenTimeKey(accountId));
        }
        final refreshedHeaders = await getAuthHeadersForAccount(accountId) ?? await _getValidAuthHeaders();
        if (refreshedHeaders != null) {
          try {
            final retryRes = await _dio.post(
              'https://gmail.googleapis.com/gmail/v1/users/me/messages/$remoteMessageId/modify',
              data: data,
              options: Options(headers: refreshedHeaders),
            );
            if (retryRes.statusCode == 200) {
              AppLogger.info(
                'Label Modified (Auto-Recovered)',
                'Updated labels on $remoteMessageId after auto-refreshing token',
                category: LogCategory.triage,
              );
              return true;
            }
          } catch (_) {}
        }
      }
      debugPrint('Error modifying Gmail labels for $remoteMessageId: $e');
      AppLogger.error('Label Modify Error', 'Failed to update labels on $remoteMessageId: $e', category: LogCategory.triage);
      return false;
    }
  }

  /// Marks a message as read or unread in real Gmail (removes or adds 'UNREAD' label).
  Future<bool> markGmailMessageRead({
    required String remoteMessageId,
    required bool isRead,
    String? accountId,
  }) {
    return modifyGmailMessageLabels(
      remoteMessageId: remoteMessageId,
      addLabelIds: isRead ? null : ['UNREAD'],
      removeLabelIds: isRead ? ['UNREAD'] : null,
      accountId: accountId,
    );
  }

  /// Archives or unarchives a message in real Gmail (removes or adds 'INBOX' label).
  Future<bool> archiveGmailMessage({
    required String remoteMessageId,
    required bool isArchived,
    String? accountId,
  }) {
    return modifyGmailMessageLabels(
      remoteMessageId: remoteMessageId,
      addLabelIds: isArchived ? null : ['INBOX'],
      removeLabelIds: isArchived ? ['INBOX'] : null,
      accountId: accountId,
    );
  }

  /// Stars or unstars a message in real Gmail (adds or removes 'STARRED' label).
  Future<bool> starGmailMessage({
    required String remoteMessageId,
    required bool isStarred,
    String? accountId,
  }) {
    return modifyGmailMessageLabels(
      remoteMessageId: remoteMessageId,
      addLabelIds: isStarred ? ['STARRED'] : null,
      removeLabelIds: isStarred ? null : ['STARRED'],
      accountId: accountId,
    );
  }

  // --------------------------------------------------------------------------
  // AUTH & INITIAL SYNC
  // --------------------------------------------------------------------------

  /// Launches Google OAuth Sign-In flow and synchronizes recent emails.
  /// Signing out first clears cached credentials and forces the system Account Chooser
  /// ("Choose an account" / "Add another account") to display, enabling multiple Gmail mailboxes.
  Future<({MailAccount? account, int syncedCount, String? error, bool isAlreadyConnected})> signInAndSync({
    required AccountRepository accountRepo,
    required MessageRepository messageRepo,
    String? explicitClientId,
    GoogleSignInAccount? preAuthenticatedAccount,
  }) async {
    final clientId = explicitClientId ?? await getClientId();
    _googleSignInInstance = _getGoogleSignIn(clientId);

    GoogleSignInAccount? googleAccount;
    try {
      if (preAuthenticatedAccount == null) {
        // Crucial for multi-account: clear active session cache so the native
        // account chooser dialog is presented every time "Connect Gmail Account" is tapped.
        try {
          await _googleSignInInstance!.signOut();
        } catch (_) {}
      }
      googleAccount = preAuthenticatedAccount ?? await _googleSignInInstance!.signIn();
    } catch (e) {
      debugPrint('Google Sign-In Native Exception: $e');
      return (account: null, syncedCount: 0, error: _formatErrorMessage(e), isAlreadyConnected: false);
    }

    if (googleAccount == null) {
      // User cancelled sign in
      return (account: null, syncedCount: 0, error: null, isAlreadyConnected: false);
    }

    // On Web (Google Identity Services), authorization of sensitive scopes
    // is separate from authentication. We explicitly check and request Gmail scopes.
    bool hasAccess = false;
    try {
      hasAccess = await _googleSignInInstance!.canAccessScopes(gmailScopes);
      if (!hasAccess) {
        debugPrint('Requesting Gmail OAuth scopes via popup...');
        hasAccess = await _googleSignInInstance!.requestScopes(gmailScopes);
      }
    } catch (e) {
      debugPrint('Scope request note: $e');
    }

    // Retrieve headers and token
    final authHeaders = await googleAccount.authHeaders;
    final auth = await googleAccount.authentication;
    final headers = Map<String, String>.from(authHeaders);
    if (!headers.containsKey('Authorization') && auth.accessToken != null && auth.accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${auth.accessToken}';
    }

    final targetAccountId = googleAccount.id.isNotEmpty
        ? 'google_${googleAccount.id}'
        : 'google_${googleAccount.email.replaceAll('@', '_').replaceAll('.', '_')}';

    // Persist per-account token securely
    if (headers['Authorization'] != null) {
      await saveStoredToken(targetAccountId, headers['Authorization']!);
    }

    // Multi-mailbox handling: Check if account already exists
    final existingAccounts = await accountRepo.getAccounts();
    final existingAccount = existingAccounts.where(
      (a) => a.id == targetAccountId || a.email.toLowerCase() == googleAccount!.email.toLowerCase(),
    ).firstOrNull;

    final bool isAlreadyConnected = existingAccount != null;
    MailAccount account;

    if (isAlreadyConnected) {
      account = existingAccount.copyWith(
        displayName: googleAccount.displayName ?? existingAccount.displayName,
        lastSyncedAt: DateTime.now(),
      );
    } else {
      // Assign distinct badge color by cycling through palette
      final colorIndex = existingAccounts.length % AppConstants.accountBadgeColors.length;
      final assignedColor = AppConstants.accountBadgeColors[colorIndex];

      account = MailAccount(
        id: targetAccountId,
        email: googleAccount.email,
        displayName: googleAccount.displayName ?? googleAccount.email.split('@').first,
        provider: MailProvider.gmail,
        avatarColorValue: assignedColor,
        lastSyncedAt: DateTime.now(),
      );
    }

    await accountRepo.saveAccount(account);
    AppLogger.success(
      'Mailbox Connected',
      isAlreadyConnected
          ? 'Refreshed credentials and re-synced ${account.email}'
          : 'Connected new Gmail mailbox: ${account.email}',
      category: LogCategory.auth,
      metadata: {'email': account.email, 'accountId': account.id},
    );

    // If headers has no authorization token and hasAccess is false, fail fast
    if (!headers.containsKey('Authorization') && !hasAccess) {
      AppLogger.warning('Scope Notice', 'Gmail permissions not yet granted for ${account.email}', category: LogCategory.auth);
      return (
        account: account,
        syncedCount: 0,
        error:
            'Gmail permissions were not granted. If a popup was blocked by your browser, please allow popups for this site and try again.',
        isAlreadyConnected: isAlreadyConnected,
      );
    }

    // Fetch and sync initial recent messages via Gmail REST API
    try {
      final count = await _syncRecentGmailMessages(
        authHeaders: headers,
        account: account,
        messageRepo: messageRepo,
      );

      // Fetch and persist current historyId and total messages in mailbox
      final profile = await fetchCurrentProfile(authHeaders: headers);
      if (profile.historyId != null) {
        await saveStoredHistoryId(account.id, profile.historyId!);
        debugPrint('Initialized Gmail historyId ${profile.historyId} for ${account.email}');
      }
      if (profile.messagesTotal != null && profile.messagesTotal! > 0) {
        account = account.copyWith(totalMessages: profile.messagesTotal!);
        await accountRepo.saveAccount(account);
      }

      AppLogger.success(
        'Initial Gmail Sync',
        'Fetched and indexed $count recent emails for ${account.email}',
        category: LogCategory.sync,
        metadata: {'syncedCount': count, 'account': account.email},
      );

      return (account: account, syncedCount: count, error: null, isAlreadyConnected: isAlreadyConnected);
    } catch (e) {
      debugPrint('Gmail Sync Error: $e');
      final humanError = _formatErrorMessage(e);
      AppLogger.error(
        'Gmail Sync Error',
        'Failed to sync ${account.email}: $humanError',
        category: LogCategory.sync,
        metadata: {'account': account.email, 'error': humanError},
      );
      return (account: account, syncedCount: 0, error: humanError, isAlreadyConnected: isAlreadyConnected);
    }
  }

  // --------------------------------------------------------------------------
  // APPROACH 2: DELTA HISTORY SYNC (GMAIL -> CLEANMAIL)
  // --------------------------------------------------------------------------

  /// Resyncs an existing account. If a `startHistoryId` exists, uses Approach 2
  /// Delta History Sync (`users.history.list`) to fetch only changes in ~100ms.
  Future<({int syncedCount, String? error})> resyncAccount({
    required MailAccount account,
    required MessageRepository messageRepo,
  }) async {
    final headers = await getAuthHeadersForAccount(account.id);
    if (headers == null) {
      return (
        syncedCount: 0,
        error: 'Session expired for ${account.email}. Please tap Connect Gmail Account to sign in.',
      );
    }

    try {
      return await syncGmailHistory(
        account: account,
        messageRepo: messageRepo,
        authHeaders: headers,
      );
    } on DioException catch (e) {
      // Automatic 401 retry: clear dead token, silent re-auth, retry once
      if (e.response?.statusCode == 401) {
        debugPrint('401 detected in resyncAccount for ${account.email}. Attempting automatic token recovery...');
        await clearStoredToken(account.id);
        final refreshedHeaders = await getAuthHeadersForAccount(account.id);
        if (refreshedHeaders != null) {
          try {
            AppLogger.info(
              'Token Auto-Refreshed',
              'Auto-recovered from 401 and retrying sync for ${account.email}',
              category: LogCategory.auth,
            );
            return await syncGmailHistory(
              account: account,
              messageRepo: messageRepo,
              authHeaders: refreshedHeaders,
            );
          } catch (retryErr) {
            return (syncedCount: 0, error: _formatErrorMessage(retryErr));
          }
        }
      }
      return (syncedCount: 0, error: _formatErrorMessage(e));
    } catch (e) {
      return (syncedCount: 0, error: _formatErrorMessage(e));
    }
  }

  /// Approach 2: Synchronizes deltas via Gmail `users.history.list`.
  /// Handles deleted messages, new messages, and read/archive label updates.
  Future<({int syncedCount, String? error})> syncGmailHistory({
    required MailAccount account,
    required MessageRepository messageRepo,
    Map<String, String>? authHeaders,
  }) async {
    final headers = authHeaders ?? await getAuthHeadersForAccount(account.id);
    if (headers == null) {
      return (
        syncedCount: 0,
        error: 'Cannot authenticate Gmail session for ${account.email}. Please sign in again.',
      );
    }

    final startHistoryId = await getStoredHistoryId(account.id);

    // If no historyId is stored yet, perform initial windowed sync and establish baseline
    if (startHistoryId == null || startHistoryId.isEmpty) {
      debugPrint('No startHistoryId found for ${account.email}. Performing initial windowed sync.');
      final count = await _syncRecentGmailMessages(
        authHeaders: headers,
        account: account,
        messageRepo: messageRepo,
      );
      final profileHistoryId = await fetchCurrentHistoryId(authHeaders: headers);
      if (profileHistoryId != null) {
        await saveStoredHistoryId(account.id, profileHistoryId);
      }
      return (syncedCount: count, error: null);
    }

    debugPrint('Starting Approach 2 Delta Sync for ${account.email} from historyId: $startHistoryId');
    AppLogger.info('Delta Sync Started', 'Checking updates for ${account.email} from historyId $startHistoryId', category: LogCategory.sync);

    final deletedRemoteIds = <String>{};
    final archivedRemoteIds = <String>{};
    final readRemoteIds = <String>{};
    final unreadRemoteIds = <String>{};
    final starredRemoteIds = <String>{};
    final unstarredRemoteIds = <String>{};
    final addedRemoteIds = <String>{};
    String? latestHistoryId;
    String? pageToken;
    int pageCount = 0;

    try {
      do {
        pageCount++;
        final response = await _dio.get(
          'https://gmail.googleapis.com/gmail/v1/users/me/history',
          queryParameters: {
            'startHistoryId': startHistoryId,
            'maxResults': 500,
            if (pageToken != null) 'pageToken': pageToken,
          },
          options: Options(headers: headers),
        );

        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['historyId'] != null) {
            latestHistoryId = data['historyId'].toString();
          }

          final historyList = data['history'] as List<dynamic>? ?? [];
          for (final record in historyList) {
            if (record is! Map<String, dynamic>) continue;

            // 1. Permanently deleted messages in Gmail
            final messagesDeleted = record['messagesDeleted'] as List<dynamic>? ?? [];
            for (final d in messagesDeleted) {
              final msgId = d['message']?['id'] as String?;
              if (msgId != null) deletedRemoteIds.add(msgId);
            }

            // 2. Labels added (e.g. TRASH, SPAM, UNREAD)
            final labelsAdded = record['labelsAdded'] as List<dynamic>? ?? [];
            for (final l in labelsAdded) {
              final msgId = l['message']?['id'] as String?;
              final labelIds = (l['labelIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet();
              if (msgId != null) {
                if (labelIds.contains('TRASH') || labelIds.contains('SPAM')) {
                  deletedRemoteIds.add(msgId);
                }
                if (labelIds.contains('UNREAD')) {
                  unreadRemoteIds.add(msgId);
                }
                if (labelIds.contains('STARRED')) {
                  starredRemoteIds.add(msgId);
                }
              }
            }

            // 3. Labels removed (e.g. INBOX -> archived, UNREAD -> read, STARRED -> unstarred)
            final labelsRemoved = record['labelsRemoved'] as List<dynamic>? ?? [];
            for (final l in labelsRemoved) {
              final msgId = l['message']?['id'] as String?;
              final labelIds = (l['labelIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet();
              if (msgId != null) {
                if (labelIds.contains('INBOX') && !deletedRemoteIds.contains(msgId)) {
                  archivedRemoteIds.add(msgId);
                }
                if (labelIds.contains('UNREAD')) {
                  readRemoteIds.add(msgId);
                }
                if (labelIds.contains('STARRED')) {
                  unstarredRemoteIds.add(msgId);
                }
              }
            }

            // 4. Newly added messages
            final messagesAdded = record['messagesAdded'] as List<dynamic>? ?? [];
            for (final a in messagesAdded) {
              final msg = a['message'];
              final msgId = msg?['id'] as String?;
              final labelIds = (msg?['labelIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet();
              if (msgId != null &&
                  !labelIds.contains('TRASH') &&
                  !labelIds.contains('SPAM') &&
                  (labelIds.isEmpty || labelIds.contains('INBOX') || !labelIds.contains('SENT'))) {
                addedRemoteIds.add(msgId);
              }
            }
          }

          pageToken = data['nextPageToken'] as String?;
        } else {
          break;
        }
      } while (pageToken != null && pageCount < 10);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // startHistoryId is expired (>30 days or invalid). Gracefully recover via windowed resync.
        debugPrint('Gmail historyId expired (HTTP 404). Falling back to windowed resync.');
        AppLogger.warning(
          'HistoryId Expired',
          'Gmail checkpoint expired for ${account.email} (HTTP 404). Performing automatic windowed resync',
          category: LogCategory.sync,
        );
        final count = await _syncRecentGmailMessages(
          authHeaders: headers,
          account: account,
          messageRepo: messageRepo,
        );
        final freshHistoryId = await fetchCurrentHistoryId(authHeaders: headers);
        if (freshHistoryId != null) {
          await saveStoredHistoryId(account.id, freshHistoryId);
        }
        AppLogger.success(
          'Windowed Resync Complete',
          'Recovered ${account.email} with $count messages. Fresh checkpoint: $freshHistoryId',
          category: LogCategory.sync,
          metadata: {'syncedCount': count, 'account': account.email, 'checkpoint': freshHistoryId},
        );
        return (syncedCount: count, error: null);
      }
      rethrow;
    }

    // Exclude messages that were added and deleted in the same delta,
    // or that are already present in the local database (duplicate prevention)
    final existingRemoteIds = await messageRepo.getExistingRemoteMessageIds(account.id);
    addedRemoteIds.removeWhere((id) => deletedRemoteIds.contains(id) || existingRemoteIds.contains(id));

    // Deduplicate any legacy duplicate rows
    await messageRepo.deduplicateMessages();

    // Apply delta updates to local database:
    // 1. Delete messages removed or trashed in Gmail
    if (deletedRemoteIds.isNotEmpty) {
      final count = await messageRepo.deleteMessagesByRemoteIds(deletedRemoteIds.toList());
      debugPrint('Delta Sync: Deleted $count messages from local DB (remote deletions in Gmail).');
    }

    // 2. Mark messages archived if INBOX label was removed in Gmail
    for (final id in archivedRemoteIds) {
      await messageRepo.archiveMessageByRemoteId(id, true);
    }

    // 3. Mark read / unread
    for (final id in readRemoteIds) {
      await messageRepo.markMessageReadByRemoteId(id, true);
    }
    for (final id in unreadRemoteIds) {
      await messageRepo.markMessageReadByRemoteId(id, false);
    }

    // 4. Mark starred / unstarred
    for (final id in starredRemoteIds) {
      await messageRepo.markMessageStarredByRemoteId(id, true);
    }
    for (final id in unstarredRemoteIds) {
      await messageRepo.markMessageStarredByRemoteId(id, false);
    }

    // 4. Fetch details for newly added messages (up to 50)
    int newlyAddedCount = 0;
    if (addedRemoteIds.isNotEmpty) {
      final List<MailMessage> newMessages = [];
      for (final msgId in addedRemoteIds.take(50)) {
        try {
          final detailResponse = await _dio.get(
            'https://gmail.googleapis.com/gmail/v1/users/me/messages/$msgId',
            queryParameters: {'format': 'full'},
            options: Options(headers: headers),
          );
          if (detailResponse.data is Map<String, dynamic>) {
            final data = detailResponse.data as Map<String, dynamic>;
            final labelIds = (data['labelIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet();
            final isInbox = labelIds.contains('INBOX');
            final isSent = labelIds.contains('SENT');
            if (isSent && !isInbox) {
              continue;
            }
            final parsedMsg = _parseGmailMessageDetail(data, account.id);
            newMessages.add(parsedMsg);
          }
        } catch (e) {
          debugPrint('Error fetching delta new message $msgId: $e');
        }
      }

      if (newMessages.isNotEmpty) {
        await messageRepo.saveMessages(newMessages);
        newlyAddedCount = newMessages.length;
        debugPrint('Delta Sync: Added $newlyAddedCount new messages to local DB.');
        await messageRepo.deduplicateMessages();
      }
    }

    // 5. Update checkpoint to latest historyId
    if (latestHistoryId != null && latestHistoryId.isNotEmpty) {
      await saveStoredHistoryId(account.id, latestHistoryId);
      debugPrint('Updated stored historyId for ${account.email} to: $latestHistoryId');
    }

    final totalDeltaChanges = newlyAddedCount + deletedRemoteIds.length + archivedRemoteIds.length;
    if (totalDeltaChanges > 0) {
      AppLogger.success(
        'Delta Sync Complete',
        'Applied $totalDeltaChanges changes ($newlyAddedCount new, ${deletedRemoteIds.length} deleted, ${archivedRemoteIds.length} archived, ${readRemoteIds.length + unreadRemoteIds.length} read status) for ${account.email}',
        category: LogCategory.sync,
        metadata: {
          'syncedCount': totalDeltaChanges,
          'account': account.email,
          'checkpoint': latestHistoryId,
        },
      );
    } else {
      AppLogger.info(
        'Mailbox Up to Date',
        '${account.email} is synchronized at checkpoint $latestHistoryId',
        category: LogCategory.sync,
      );
    }

    return (syncedCount: totalDeltaChanges, error: null);
  }

  // --------------------------------------------------------------------------
  // WINDOWED FALLBACK SYNC & PARSING HELPERS
  // --------------------------------------------------------------------------

  Future<int> _syncRecentGmailMessages({
    required Map<String, String> authHeaders,
    required MailAccount account,
    required MessageRepository messageRepo,
  }) async {
    // 1. Clean up any historical duplicate entries
    await messageRepo.deduplicateMessages();

    final listResponse = await _dio.get(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages',
      queryParameters: {
        'maxResults': 30,
        'includeSpamTrash': false,
        'q': 'in:inbox',
      },
      options: Options(headers: authHeaders),
    );

    final messageSummaries = listResponse.data['messages'] as List<dynamic>? ?? [];
    debugPrint('Found ${messageSummaries.length} Gmail messages for ${account.email}');

    final nextPageToken = listResponse.data['nextPageToken'] as String?;
    if (nextPageToken != null && nextPageToken.isNotEmpty) {
      await saveStoredPageToken(account.id, nextPageToken);
      debugPrint('Saved initial Gmail nextPageToken for ${account.email}');
    }

    // 2. Fetch existing message IDs to avoid re-fetching or duplicating
    final existingRemoteIds = await messageRepo.getExistingRemoteMessageIds(account.id);

    final List<MailMessage> fetchedMessages = [];

    for (final item in messageSummaries) {
      final messageId = item['id'] as String;

      // Duplicate prevention: skip messages already in local DB
      if (existingRemoteIds.contains(messageId)) {
        continue;
      }

      try {
        final detailResponse = await _dio.get(
          'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId',
          queryParameters: {'format': 'full'},
          options: Options(headers: authHeaders),
        );

        if (detailResponse.data is Map<String, dynamic>) {
          final data = detailResponse.data as Map<String, dynamic>;
          final labelIds = (data['labelIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet();
          final isInbox = labelIds.contains('INBOX');
          final isSent = labelIds.contains('SENT');
          if (isSent && !isInbox) {
            // Sent-only message not in inbox, skip importing into inbox view
            continue;
          }
          final parsed = _parseGmailMessageDetail(data, account.id);
          fetchedMessages.add(parsed);
        }
      } catch (e) {
        debugPrint('Error fetching individual message $messageId: $e');
      }
    }

    if (fetchedMessages.isNotEmpty) {
      await messageRepo.saveMessages(fetchedMessages);
      await messageRepo.deduplicateMessages();
    }

    return fetchedMessages.length;
  }

  /// Synchronizes the next [count] (default 20, or 100 for batch sync) older messages from Gmail.
  /// Uses the stored [pageToken] if available, otherwise queries `before:<oldest_timestamp_epoch_seconds>`.
  Future<({int syncedCount, bool hasMore, String? error})> syncOlderGmailMessages({
    required MailAccount account,
    required MessageRepository messageRepo,
    int count = 20,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    final headers = await getAuthHeadersForAccount(account.id);
    if (headers == null) {
      return (
        syncedCount: 0,
        hasMore: false,
        error: 'Session expired for ${account.email}. Please tap Connect Gmail Account to sign in.',
      );
    }

    try {
      return await _fetchAndSaveOlderGmailMessages(
        account: account,
        messageRepo: messageRepo,
        headers: headers,
        count: count,
        onProgress: onProgress,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        debugPrint('401 detected in syncOlderGmailMessages for ${account.email}. Attempting automatic recovery...');
        await clearStoredToken(account.id);
        final refreshedHeaders = await getAuthHeadersForAccount(account.id);
        if (refreshedHeaders != null) {
          try {
            return await _fetchAndSaveOlderGmailMessages(
              account: account,
              messageRepo: messageRepo,
              headers: refreshedHeaders,
              count: count,
              onProgress: onProgress,
            );
          } catch (retryErr) {
            return (syncedCount: 0, hasMore: false, error: _formatErrorMessage(retryErr));
          }
        }
      }
      return (syncedCount: 0, hasMore: false, error: _formatErrorMessage(e));
    } catch (e) {
      return (syncedCount: 0, hasMore: false, error: _formatErrorMessage(e));
    }
  }

  Future<({int syncedCount, bool hasMore, String? error})> _fetchAndSaveOlderGmailMessages({
    required MailAccount account,
    required MessageRepository messageRepo,
    required Map<String, String> headers,
    required int count,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    final storedPageToken = await getStoredPageToken(account.id);
    final queryParams = <String, dynamic>{
      'maxResults': count,
      'includeSpamTrash': false,
    };

    if (storedPageToken != null && storedPageToken.isNotEmpty) {
      queryParams['pageToken'] = storedPageToken;
      queryParams['q'] = 'in:inbox';
    } else {
      final oldestTimestamp = await messageRepo.getOldestMessageTimestamp(account.id);
      if (oldestTimestamp != null) {
        final epochSeconds = (oldestTimestamp.millisecondsSinceEpoch / 1000).floor();
        queryParams['q'] = 'in:inbox before:$epochSeconds';
      } else {
        queryParams['q'] = 'in:inbox';
      }
    }

    final listResponse = await _dio.get(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages',
      queryParameters: queryParams,
      options: Options(headers: headers),
    );

    final data = listResponse.data;
    if (data is! Map<String, dynamic>) {
      return (syncedCount: 0, hasMore: false, error: 'Invalid response from Gmail');
    }

    final nextPageToken = data['nextPageToken'] as String?;
    if (nextPageToken != null && nextPageToken.isNotEmpty) {
      await saveStoredPageToken(account.id, nextPageToken);
    } else {
      await clearStoredPageToken(account.id);
    }

    final messageSummaries = data['messages'] as List<dynamic>? ?? [];
    if (messageSummaries.isEmpty) {
      return (syncedCount: 0, hasMore: false, error: null);
    }

    final existingRemoteIds = await messageRepo.getExistingRemoteMessageIds(account.id);
    final toFetch = messageSummaries
        .where((item) {
          final id = item['id'] as String?;
          return id != null && !existingRemoteIds.contains(id);
        })
        .toList();

    if (toFetch.isEmpty) {
      return (
        syncedCount: 0,
        hasMore: nextPageToken != null && nextPageToken.isNotEmpty,
        error: null,
      );
    }

    final List<MailMessage> fetchedMessages = [];
    const chunkSize = 5;
    bool rateLimitHit = false;

    for (var i = 0; i < toFetch.length; i += chunkSize) {
      if (rateLimitHit) break;

      final end = (i + chunkSize < toFetch.length) ? i + chunkSize : toFetch.length;
      final chunk = toFetch.sublist(i, end);

      final chunkResults = await Future.wait(chunk.map((item) async {
        final messageId = item['id'] as String;
        for (int attempt = 0; attempt < 2; attempt++) {
          try {
            final detailResponse = await _dio.get(
              'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId',
              queryParameters: {'format': 'full'},
              options: Options(headers: headers),
            );

            if (detailResponse.data is Map<String, dynamic>) {
              final detailData = detailResponse.data as Map<String, dynamic>;
              final labelIds = (detailData['labelIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet();
              final isInbox = labelIds.contains('INBOX');
              final isSent = labelIds.contains('SENT');
              if (isSent && !isInbox) {
                return null;
              }
              return _parseGmailMessageDetail(detailData, account.id);
            }
          } on DioException catch (e) {
            final status = e.response?.statusCode;
            final isThrottled = status == 403 || status == 429;
            if (isThrottled) {
              rateLimitHit = true;
              if (attempt == 0) {
                // Transient concurrency burst: pause 600ms and retry once
                await Future.delayed(const Duration(milliseconds: 600));
                continue;
              }
              debugPrint('Gmail API Rate Limit (HTTP $status) on message $messageId');
            } else {
              debugPrint('Error fetching older message detail $messageId: ${e.message ?? e.toString()}');
              break;
            }
          } catch (e) {
            debugPrint('Error fetching older message detail $messageId: $e');
            break;
          }
        }
        return null;
      }));

      final validMessages = chunkResults.whereType<MailMessage>().toList();
      if (validMessages.isNotEmpty) {
        fetchedMessages.addAll(validMessages);
        await messageRepo.saveMessages(validMessages);
      }

      onProgress?.call(
        fetchedMessages.length,
        toFetch.length,
        'Syncing older emails: ${fetchedMessages.length} of ${toFetch.length}...',
      );

      if (rateLimitHit) {
        break;
      }

      if (end < toFetch.length) {
        await Future.delayed(const Duration(milliseconds: 60));
      }
    }

    if (fetchedMessages.isNotEmpty) {
      await messageRepo.deduplicateMessages();
    }

    if (rateLimitHit) {
      AppLogger.warning(
        'Gmail Rate Limit (403/429)',
        'Quota reached while fetching older emails for ${account.email}. Pausing before next retry.',
        category: LogCategory.sync,
        metadata: {'account': account.email, 'syncedCount': fetchedMessages.length},
      );

      return (
        syncedCount: fetchedMessages.length,
        hasMore: true,
        error: 'Rate limit reached (403/429): Gmail API quota exceeded. Waiting before retry.',
      );
    }

    AppLogger.info(
      'Older Emails Synced',
      'Fetched ${fetchedMessages.length} older emails for ${account.email}',
      category: LogCategory.sync,
      metadata: {
        'count': fetchedMessages.length,
        'account': account.email,
        'hasMore': nextPageToken != null && nextPageToken.isNotEmpty,
      },
    );

    return (
      syncedCount: fetchedMessages.length,
      hasMore: nextPageToken != null && nextPageToken.isNotEmpty,
      error: null,
    );
  }

  /// Performs smart sync for [account]:
  /// 1. Updates mailbox profile to get total available emails.
  /// 2. First syncs the latest emails (delta sync).
  /// 3. If all latest emails are synced, fetches a batch of 100 older un-synced emails.
  Future<({
    int syncedCount,
    int totalAvailable,
    bool olderSynced,
    bool hasMoreOlder,
    String? error,
  })> syncMailboxSmart({
    required MailAccount account,
    required MessageRepository messageRepo,
    required AccountRepository accountRepo,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    final headers = await getAuthHeadersForAccount(account.id);
    if (headers == null) {
      return (
        syncedCount: 0,
        totalAvailable: account.totalMessages,
        olderSynced: false,
        hasMoreOlder: true,
        error: 'Session expired for ${account.email}. Please tap Connect Gmail Account to sign in.',
      );
    }

    int currentTotalAvailable = account.totalMessages;

    // 1. Fetch current profile from Gmail to update total email count available in mailbox
    try {
      final profile = await fetchCurrentProfile(authHeaders: headers);
      if (profile.messagesTotal != null && profile.messagesTotal! > 0) {
        currentTotalAvailable = profile.messagesTotal!;
        await accountRepo.updateTotalMessages(account.id, currentTotalAvailable);
      }
    } catch (e) {
      debugPrint('Note: unable to fetch profile total: $e');
    }

    onProgress?.call(0, 0, 'Checking for latest emails...');

    // 2. First sync latest emails via delta history sync
    final deltaResult = await resyncAccount(
      account: account,
      messageRepo: messageRepo,
    );

    if (deltaResult.error != null) {
      return (
        syncedCount: 0,
        totalAvailable: currentTotalAvailable,
        olderSynced: false,
        hasMoreOlder: true,
        error: deltaResult.error,
      );
    }

    // If new latest emails were found and synced, update last synced time and finish
    if (deltaResult.syncedCount > 0) {
      await accountRepo.updateSyncTime(account.id, DateTime.now());
      return (
        syncedCount: deltaResult.syncedCount,
        totalAvailable: currentTotalAvailable,
        olderSynced: false,
        hasMoreOlder: true,
        error: null,
      );
    }

    // 3. All latest emails are already synced! Look for older emails that are not synced in batches of 100
    onProgress?.call(0, 100, 'Latest emails up to date. Fetching older emails (batch of 100)...');

    final olderResult = await syncOlderGmailMessages(
      account: account,
      messageRepo: messageRepo,
      count: 100,
      onProgress: onProgress,
    );

    await accountRepo.updateSyncTime(account.id, DateTime.now());

    return (
      syncedCount: olderResult.syncedCount,
      totalAvailable: currentTotalAvailable,
      olderSynced: true,
      hasMoreOlder: olderResult.hasMore,
      error: olderResult.error,
    );
  }

  /// Parses a raw Gmail message API JSON payload into a clean [MailMessage].
  MailMessage _parseGmailMessageDetail(Map<String, dynamic> detailData, String accountId) {
    final messageId = detailData['id'] as String;
    final payload = detailData['payload'] as Map<String, dynamic>? ?? {};
    final headersList = payload['headers'] as List<dynamic>? ?? [];

    String subject = '(No Subject)';
    String senderRaw = 'Unknown Sender';
    String? unsubscribeHeader;
    String? precedenceHeader;
    DateTime receivedDate = DateTime.now();

    // Use internalDate (epoch milliseconds) for exact timestamp
    final internalDateStr = detailData['internalDate'] as String?;
    if (internalDateStr != null) {
      final millis = int.tryParse(internalDateStr);
      if (millis != null) {
        receivedDate = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }

    for (final h in headersList) {
      final name = (h['name'] as String? ?? '').toLowerCase();
      final val = h['value'] as String? ?? '';

      if (name == 'subject') subject = val;
      if (name == 'from') senderRaw = val;
      if (name == 'list-unsubscribe') unsubscribeHeader = val;
      if (name == 'precedence') precedenceHeader = val;
    }

    final senderParsed = _parseSender(senderRaw);
    final rawSnippet = detailData['snippet'] as String? ?? '';
    final bodyText = _extractBody(payload);

    // Strip HTML to clean text
    final cleanTextBody = HtmlToTextConverter.convert(bodyText.isNotEmpty ? bodyText : rawSnippet);

    // Extract clean unsubscribe link/mailto
    final unsubLinks = _parseUnsubscribeHeader(unsubscribeHeader);

    // Classify using heuristic categorizer
    final category = HeuristicClassifier.classify(
      senderEmail: senderParsed.email,
      subject: subject,
      snippet: rawSnippet,
      unsubscribeHeader: unsubscribeHeader,
      precedenceHeader: precedenceHeader,
    );

    final labelIds = (detailData['labelIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet();
    final isRead = !labelIds.contains('UNREAD');
    final isInbox = labelIds.contains('INBOX');

    // Deterministic ID ensures duplicate imports never create duplicate records
    final deterministicId = '${accountId}_$messageId';

    return MailMessage(
      id: deterministicId,
      accountId: accountId,
      remoteMessageId: messageId,
      threadId: detailData['threadId'] as String?,
      senderEmail: senderParsed.email,
      senderName: senderParsed.name,
      subject: subject,
      snippet: rawSnippet,
      plainTextBody: cleanTextBody,
      category: category,
      unsubscribeUrl: unsubLinks.url,
      unsubscribeMailto: unsubLinks.mailto,
      isRead: isRead,
      isArchived: !isInbox,
      receivedAt: receivedDate,
    );
  }

  static String formatErrorMessage(dynamic error) {
    if (error is PlatformException) {
      if (error.code.contains('sign_in_failed') || error.message?.contains('10') == true) {
        return 'Android Google Sign-In requires your app\'s SHA-1 fingerprint and package name to be registered in Google Cloud Console:\n\n'
            '1. Go to Google Cloud Console > APIs & Services > Credentials.\n'
            '2. Create an OAuth 2.0 Client ID with Application type: Android.\n'
            '3. Set Package Name: com.shuvankar.cleanmail\n'
            '4. Set SHA-1 Certificate Fingerprint:\n'
            '   09:C2:9D:D4:63:78:55:CB:81:E8:FC:34:84:88:C3:8C:BA:09:52:D2\n\n'
            '5. Under OAuth Consent Screen > Test Users, ensure your Google email is added.';
      }
      return 'Platform Sign-In Error (${error.code}): ${error.message ?? error.details}';
    }

    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final responseData = error.response?.data;

      String serverMessage = '';
      if (responseData is Map && responseData['error'] != null) {
        final errObj = responseData['error'];
        if (errObj is Map && errObj['message'] != null) {
          serverMessage = errObj['message'].toString();
        }
      }

      if (statusCode == 429) {
        return 'Rate limit reached (429): Gmail API quota exceeded.';
      }

      if (statusCode == 403) {
        final lower = serverMessage.toLowerCase();
        if (lower.contains('gmail api has not been used') ||
            lower.contains('disabled')) {
          return 'Gmail API is disabled in your Google Cloud project. Please go to Google Cloud Console > APIs & Services > Library, search for "Gmail API", and click Enable.';
        }
        if (lower.contains('insufficient') ||
            lower.contains('scope')) {
          return 'Permission denied: Please ensure the scope ".../auth/gmail.readonly" and ".../auth/gmail.modify" are enabled in your OAuth consent screen.';
        }
        if (lower.contains('rate limit') ||
            lower.contains('ratelimit') ||
            lower.contains('quota') ||
            lower.contains('userratelimitexceeded') ||
            lower.contains('concurrent') ||
            serverMessage.isEmpty) {
          return 'Rate limit reached (403): Gmail API quota or concurrent request limit exceeded. Waiting before retry.';
        }
        return 'Rate limit / Forbidden (403): ${serverMessage.isNotEmpty ? serverMessage : "Gmail API request throttled. Waiting before retry."}';
      }

      if (statusCode == 401) {
        return 'Unauthorized (401). Token was rejected or expired.';
      }

      if (kIsWeb && error.type == DioExceptionType.connectionError) {
        return 'Web CORS Error: Please ensure your current web address (${Uri.base.origin}) is added to "Authorized JavaScript origins" under your OAuth Client ID in Google Cloud Console.';
      }

      return 'Network Error (${statusCode ?? error.type}): ${serverMessage.isNotEmpty ? serverMessage : error.message}';
    }

    return error.toString();
  }

  String _formatErrorMessage(dynamic error) => formatErrorMessage(error);

  ({String name, String email}) _parseSender(String raw) {
    if (raw.contains('<') && raw.contains('>')) {
      final name = raw.substring(0, raw.indexOf('<')).trim().replaceAll('"', '');
      final email = raw.substring(raw.indexOf('<') + 1, raw.indexOf('>')).trim();
      return (name: name.isNotEmpty ? name : email, email: email);
    }
    return (name: raw.trim(), email: raw.trim());
  }

  String _extractBody(Map<String, dynamic> payload) {
    // 1. Direct body data
    final bodyData = payload['body']?['data'] as String?;
    if (bodyData != null && bodyData.isNotEmpty) {
      return _decodeBase64Url(bodyData);
    }

    // 2. Multipart parts
    final parts = payload['parts'] as List<dynamic>?;
    if (parts != null && parts.isNotEmpty) {
      // Prioritize plain text first
      for (final p in parts) {
        final mimeType = p['mimeType'] as String? ?? '';
        final data = p['body']?['data'] as String?;
        if (mimeType.contains('text/plain') && data != null) {
          return _decodeBase64Url(data);
        }
      }
      // If no plain text, take HTML
      for (final p in parts) {
        final mimeType = p['mimeType'] as String? ?? '';
        final data = p['body']?['data'] as String?;
        if (mimeType.contains('text/html') && data != null) {
          return _decodeBase64Url(data);
        }
      }
    }
    return '';
  }

  String _decodeBase64Url(String input) {
    try {
      String normalized = input.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      return utf8.decode(base64.decode(normalized));
    } catch (_) {
      return '';
    }
  }

  ({String? url, String? mailto}) _parseUnsubscribeHeader(String? header) {
    if (header == null) return (url: null, mailto: null);
    String? url;
    String? mailto;

    final regex = RegExp(r'<([^>]+)>');
    final matches = regex.allMatches(header);
    for (final m in matches) {
      final link = m.group(1);
      if (link != null) {
        if (link.startsWith('http://') || link.startsWith('https://')) {
          url = link;
        } else if (link.startsWith('mailto:')) {
          mailto = link;
        }
      }
    }
    return (url: url, mailto: mailto);
  }
}
