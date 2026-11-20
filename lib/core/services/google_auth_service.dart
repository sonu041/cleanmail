import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';
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
  static const _uuid = Uuid();
  final Dio _dio = Dio();

  GoogleSignIn? _googleSignInInstance;

  static const List<String> gmailScopes = [
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.modify',
  ];

  GoogleSignIn _getGoogleSignIn(String? clientId) {
    return GoogleSignIn(
      clientId: (clientId != null && clientId.isNotEmpty) ? clientId : null,
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

  /// Launches Google OAuth Sign-In flow and synchronizes recent emails.
  Future<({MailAccount? account, int syncedCount, String? error})> signInAndSync({
    required AccountRepository accountRepo,
    required MessageRepository messageRepo,
    String? explicitClientId,
    GoogleSignInAccount? preAuthenticatedAccount,
  }) async {
    final clientId = explicitClientId ?? await getClientId();
    _googleSignInInstance = _getGoogleSignIn(clientId);

    final googleAccount = preAuthenticatedAccount ?? await _googleSignInInstance!.signIn();
    if (googleAccount == null) {
      // User cancelled sign in
      return (account: null, syncedCount: 0, error: null);
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

    final account = MailAccount(
      id: 'google_${googleAccount.id}',
      email: googleAccount.email,
      displayName: googleAccount.displayName ?? googleAccount.email.split('@').first,
      provider: MailProvider.gmail,
      avatarColorValue: 0xFF1E88E5, // Clean Google Blue
      lastSyncedAt: DateTime.now(),
    );

    await accountRepo.saveAccount(account);

    // If headers has no authorization token and hasAccess is false, fail fast
    if (!headers.containsKey('Authorization') && !hasAccess) {
      return (
        account: account,
        syncedCount: 0,
        error:
            'Gmail permissions were not granted. If a popup was blocked by your browser, please allow popups for this site and try again.',
      );
    }

    // Fetch and sync recent messages via Gmail REST API
    try {
      final count = await _syncRecentGmailMessages(
        authHeaders: headers,
        account: account,
        messageRepo: messageRepo,
      );
      return (account: account, syncedCount: count, error: null);
    } catch (e) {
      debugPrint('Gmail Sync Error: $e');
      final humanError = _formatErrorMessage(e);
      return (account: account, syncedCount: 0, error: humanError);
    }
  }

  /// Syncs an existing account again
  Future<({int syncedCount, String? error})> resyncAccount({
    required MailAccount account,
    required MessageRepository messageRepo,
  }) async {
    final clientId = await getClientId();
    _googleSignInInstance ??= _getGoogleSignIn(clientId);

    final googleAccount = _googleSignInInstance!.currentUser ??
        await _googleSignInInstance!.signInSilently();

    if (googleAccount == null) {
      return (syncedCount: 0, error: 'Session expired. Please tap Connect Gmail Account to sign in.');
    }

    bool hasAccess = false;
    try {
      hasAccess = await _googleSignInInstance!.canAccessScopes(gmailScopes);
      if (!hasAccess) {
        hasAccess = await _googleSignInInstance!.requestScopes(gmailScopes);
      }
    } catch (e) {
      debugPrint('Resync scope note: $e');
    }

    final authHeaders = await googleAccount.authHeaders;
    final auth = await googleAccount.authentication;
    final headers = Map<String, String>.from(authHeaders);
    if (!headers.containsKey('Authorization') && auth.accessToken != null && auth.accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${auth.accessToken}';
    }

    if (!headers.containsKey('Authorization') && !hasAccess) {
      return (
        syncedCount: 0,
        error: 'Gmail permissions were not granted. Please allow access in the popup.',
      );
    }

    try {
      final count = await _syncRecentGmailMessages(
        authHeaders: headers,
        account: account,
        messageRepo: messageRepo,
      );
      return (syncedCount: count, error: null);
    } catch (e) {
      return (syncedCount: 0, error: _formatErrorMessage(e));
    }
  }

  Future<int> _syncRecentGmailMessages({
    required Map<String, String> authHeaders,
    required MailAccount account,
    required MessageRepository messageRepo,
  }) async {
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

    final List<MailMessage> fetchedMessages = [];

    for (final item in messageSummaries) {
      final messageId = item['id'] as String;
      try {
        final detailResponse = await _dio.get(
          'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId',
          queryParameters: {'format': 'full'},
          options: Options(headers: authHeaders),
        );

        final payload = detailResponse.data['payload'] as Map<String, dynamic>? ?? {};
        final headersList = payload['headers'] as List<dynamic>? ?? [];

        String subject = '(No Subject)';
        String senderRaw = 'Unknown Sender';
        String? unsubscribeHeader;
        String? precedenceHeader;
        DateTime receivedDate = DateTime.now();

        // Use internalDate (epoch milliseconds) for exact timestamp
        final internalDateStr = detailResponse.data['internalDate'] as String?;
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
        final rawSnippet = detailResponse.data['snippet'] as String? ?? '';
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

        final mailMessage = MailMessage(
          id: _uuid.v4(),
          accountId: account.id,
          remoteMessageId: messageId,
          threadId: detailResponse.data['threadId'] as String?,
          senderEmail: senderParsed.email,
          senderName: senderParsed.name,
          subject: subject,
          snippet: rawSnippet,
          plainTextBody: cleanTextBody,
          category: category,
          unsubscribeUrl: unsubLinks.url,
          unsubscribeMailto: unsubLinks.mailto,
          isRead: false,
          receivedAt: receivedDate,
        );

        fetchedMessages.add(mailMessage);
      } catch (e) {
        debugPrint('Error fetching individual message $messageId: $e');
      }
    }

    if (fetchedMessages.isNotEmpty) {
      await messageRepo.saveMessages(fetchedMessages);
    }

    return fetchedMessages.length;
  }

  String _formatErrorMessage(dynamic error) {
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
          return 'Permission denied: Please ensure the scope ".../auth/gmail.readonly" is enabled in your OAuth consent screen.';
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
