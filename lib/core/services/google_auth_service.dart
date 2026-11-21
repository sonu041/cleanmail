import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/models/account.dart';
import '../../domain/models/message.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/message_repository.dart';
import '../constants/app_constants.dart';
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
  String _tokenKey(String accountId) => 'gmail_token_$accountId';

  Future<String?> getStoredHistoryId(String accountId) async {
    return await _storage.read(key: _historyKey(accountId));
  }

  Future<void> saveStoredHistoryId(String accountId, String historyId) async {
    await _storage.write(key: _historyKey(accountId), value: historyId);
  }

  Future<void> clearStoredHistoryId(String accountId) async {
    await _storage.delete(key: _historyKey(accountId));
  }

  Future<String?> getStoredToken(String accountId) async {
    return await _storage.read(key: _tokenKey(accountId));
  }

  Future<void> saveStoredToken(String accountId, String token) async {
    final bearerToken = token.startsWith('Bearer ') ? token : 'Bearer $token';
    await _storage.write(key: _tokenKey(accountId), value: bearerToken);
  }

  Future<void> clearStoredToken(String accountId) async {
    await _storage.delete(key: _tokenKey(accountId));
  }

  /// Fetches current mailbox historyId directly from Gmail profile.
  Future<String?> fetchCurrentHistoryId({
    required Map<String, String> authHeaders,
  }) async {
    try {
      final response = await _dio.get(
        'https://gmail.googleapis.com/gmail/v1/users/me/profile',
        options: Options(headers: authHeaders),
      );
      final historyId = response.data['historyId']?.toString();
      return historyId;
    } catch (e) {
      debugPrint('Error fetching Gmail profile historyId: $e');
      return null;
    }
  }

  /// Resolves valid OAuth Bearer headers for the specified [accountId] (or the current session).
  Future<Map<String, String>?> getAuthHeadersForAccount([String? accountId]) async {
    // 1. If active currentUser matches target account, use it directly (auto-refreshes)
    if (accountId != null && _googleSignInInstance?.currentUser != null) {
      final current = _googleSignInInstance!.currentUser!;
      final currentId = 'google_${current.id}';
      if (currentId == accountId || current.email.toLowerCase() == accountId.toLowerCase()) {
        final authHeaders = await current.authHeaders;
        final auth = await current.authentication;
        final headers = Map<String, String>.from(authHeaders);
        if (!headers.containsKey('Authorization') &&
            auth.accessToken != null &&
            auth.accessToken!.isNotEmpty) {
          headers['Authorization'] = 'Bearer ${auth.accessToken}';
        }
        if (headers['Authorization'] != null) {
          await saveStoredToken(accountId, headers['Authorization']!);
        }
        return headers;
      }
    }

    // 2. If accountId provided, check FlutterSecureStorage for cached Bearer token
    if (accountId != null) {
      final storedToken = await getStoredToken(accountId);
      if (storedToken != null && storedToken.isNotEmpty) {
        return {
          'Authorization': storedToken,
          'Accept': 'application/json',
        };
      }
    }

    // 3. Fallback to active Google Sign-In session
    return await _getValidAuthHeaders();
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
    try {
      final headers = await getAuthHeadersForAccount(accountId);
      if (headers == null) {
        debugPrint('Cannot trash Gmail message $remoteMessageId: no valid session.');
        return false;
      }

      final response = await _dio.post(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages/$remoteMessageId/trash',
        options: Options(headers: headers),
      );

      debugPrint('Moved Gmail message $remoteMessageId to Trash: status ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error trashing Gmail message $remoteMessageId: $e');
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
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error untrashing Gmail message $remoteMessageId: $e');
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
    try {
      final headers = await getAuthHeadersForAccount(accountId);
      if (headers == null) return false;

      final data = <String, dynamic>{};
      if (addLabelIds != null && addLabelIds.isNotEmpty) {
        data['addLabelIds'] = addLabelIds;
      }
      if (removeLabelIds != null && removeLabelIds.isNotEmpty) {
        data['removeLabelIds'] = removeLabelIds;
      }

      final response = await _dio.post(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages/$remoteMessageId/modify',
        data: data,
        options: Options(headers: headers),
      );

      debugPrint('Modified Gmail labels for $remoteMessageId: status ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error modifying Gmail labels for $remoteMessageId: $e');
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
    final MailAccount account;

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

    // If headers has no authorization token and hasAccess is false, fail fast
    if (!headers.containsKey('Authorization') && !hasAccess) {
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

      // Approach 2: Fetch and persist current historyId for future delta syncs
      final profileHistoryId = await fetchCurrentHistoryId(authHeaders: headers);
      if (profileHistoryId != null) {
        await saveStoredHistoryId(account.id, profileHistoryId);
        debugPrint('Initialized Gmail historyId $profileHistoryId for ${account.email}');
      }

      return (account: account, syncedCount: count, error: null, isAlreadyConnected: isAlreadyConnected);
    } catch (e) {
      debugPrint('Gmail Sync Error: $e');
      final humanError = _formatErrorMessage(e);
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

    final deletedRemoteIds = <String>{};
    final archivedRemoteIds = <String>{};
    final readRemoteIds = <String>{};
    final unreadRemoteIds = <String>{};
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
              }
            }

            // 3. Labels removed (e.g. INBOX -> archived, UNREAD -> read)
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
              }
            }

            // 4. Newly added messages
            final messagesAdded = record['messagesAdded'] as List<dynamic>? ?? [];
            for (final a in messagesAdded) {
              final msg = a['message'];
              final msgId = msg?['id'] as String?;
              final labelIds = (msg?['labelIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet();
              if (msgId != null && !labelIds.contains('TRASH') && !labelIds.contains('SPAM')) {
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
        final count = await _syncRecentGmailMessages(
          authHeaders: headers,
          account: account,
          messageRepo: messageRepo,
        );
        final freshHistoryId = await fetchCurrentHistoryId(authHeaders: headers);
        if (freshHistoryId != null) {
          await saveStoredHistoryId(account.id, freshHistoryId);
        }
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
            final parsedMsg = _parseGmailMessageDetail(
              detailResponse.data as Map<String, dynamic>,
              account.id,
            );
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
      }
    }

    // 5. Update checkpoint to latest historyId
    if (latestHistoryId != null && latestHistoryId.isNotEmpty) {
      await saveStoredHistoryId(account.id, latestHistoryId);
      debugPrint('Updated stored historyId for ${account.email} to: $latestHistoryId');
    }

    final totalDeltaChanges = newlyAddedCount + deletedRemoteIds.length + archivedRemoteIds.length;
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
        'maxResults': 20,
        'includeSpamTrash': false,
      },
      options: Options(headers: authHeaders),
    );

    final messageSummaries = listResponse.data['messages'] as List<dynamic>? ?? [];
    debugPrint('Found ${messageSummaries.length} Gmail messages for ${account.email}');

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
          final parsed = _parseGmailMessageDetail(
            detailResponse.data as Map<String, dynamic>,
            account.id,
          );
          fetchedMessages.add(parsed);
        }
      } catch (e) {
        debugPrint('Error fetching individual message $messageId: $e');
      }
    }

    if (fetchedMessages.isNotEmpty) {
      await messageRepo.saveMessages(fetchedMessages);
    }

    return fetchedMessages.length;
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
      receivedAt: receivedDate,
    );
  }

  String _formatErrorMessage(dynamic error) {
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

      if (statusCode == 403) {
        if (serverMessage.toLowerCase().contains('gmail api has not been used') ||
            serverMessage.toLowerCase().contains('disabled')) {
          return 'Gmail API is disabled in your Google Cloud project. Please go to Google Cloud Console > APIs & Services > Library, search for "Gmail API", and click Enable.';
        }
        if (serverMessage.toLowerCase().contains('insufficient') ||
            serverMessage.toLowerCase().contains('scope')) {
          return 'Permission denied: Please ensure the scope ".../auth/gmail.readonly" and ".../auth/gmail.modify" are enabled in your OAuth consent screen.';
        }
        return 'Google API 403 Forbidden: $serverMessage';
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
