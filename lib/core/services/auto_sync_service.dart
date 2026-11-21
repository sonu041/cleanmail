import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/account.dart';
import '../services/log_service.dart';
import '../../../features/providers.dart';

class AccountAutoSyncState {
  final bool isRunning;
  final bool isRateLimited;
  final int countdownSeconds;
  final int backoffSeconds;
  final String? statusMessage;
  final int totalSyncedThisSession;
  final String? error;

  const AccountAutoSyncState({
    this.isRunning = false,
    this.isRateLimited = false,
    this.countdownSeconds = 0,
    this.backoffSeconds = 10,
    this.statusMessage,
    this.totalSyncedThisSession = 0,
    this.error,
  });

  AccountAutoSyncState copyWith({
    bool? isRunning,
    bool? isRateLimited,
    int? countdownSeconds,
    int? backoffSeconds,
    String? statusMessage,
    int? totalSyncedThisSession,
    String? error,
  }) {
    return AccountAutoSyncState(
      isRunning: isRunning ?? this.isRunning,
      isRateLimited: isRateLimited ?? this.isRateLimited,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      backoffSeconds: backoffSeconds ?? this.backoffSeconds,
      statusMessage: statusMessage ?? this.statusMessage,
      totalSyncedThisSession: totalSyncedThisSession ?? this.totalSyncedThisSession,
      error: error,
    );
  }
}

class AutoSyncNotifier extends StateNotifier<Map<String, AccountAutoSyncState>> {
  final Ref _ref;
  final Map<String, Timer?> _countdownTimers = {};
  bool _isDisposed = false;

  AutoSyncNotifier(this._ref) : super({});

  AccountAutoSyncState getAccountState(String accountId) {
    return state[accountId] ?? const AccountAutoSyncState();
  }

  void toggleAutoSync(MailAccount account) {
    final current = getAccountState(account.id);
    if (current.isRunning) {
      stopAutoSync(account.id);
    } else {
      startAutoSync(account);
    }
  }

  void startAutoSync(MailAccount account) {
    _cancelTimer(account.id);
    state = {
      ...state,
      account.id: const AccountAutoSyncState(
        isRunning: true,
        statusMessage: 'Starting auto-sync for older emails...',
        backoffSeconds: 10,
      ),
    };
    _executeBatch(account);
  }

  void stopAutoSync(String accountId) {
    _cancelTimer(accountId);
    final current = getAccountState(accountId);
    state = {
      ...state,
      accountId: current.copyWith(
        isRunning: false,
        isRateLimited: false,
        countdownSeconds: 0,
        statusMessage: 'Auto-sync stopped.',
      ),
    };
  }

  Future<void> _executeBatch(MailAccount account) async {
    if (_isDisposed) return;
    final current = getAccountState(account.id);
    if (!current.isRunning) return;

    state = {
      ...state,
      account.id: current.copyWith(
        statusMessage: 'Syncing older emails (batch of 100)...',
        countdownSeconds: 0,
      ),
    };

    final googleAuth = _ref.read(googleAuthServiceProvider);
    final messageRepo = _ref.read(messageRepositoryProvider);
    final accountRepo = _ref.read(accountRepositoryProvider);

    try {
      final result = await googleAuth.syncOlderGmailMessages(
        account: account,
        messageRepo: messageRepo,
        count: 100,
        onProgress: (currentCount, totalCount, progressStatus) {
          if (!getAccountState(account.id).isRunning) return;
          state = {
            ...state,
            account.id: getAccountState(account.id).copyWith(
              statusMessage: progressStatus,
            ),
          };
        },
      );

      if (!getAccountState(account.id).isRunning) return;

      if (result.error != null) {
        final isRateLimit = _isRateLimitError(result.error!);
        if (isRateLimit) {
          // Rate limit encountered: wait for 10 more seconds before retry
          final newBackoff = current.backoffSeconds + 10;
          AppLogger.warning(
            'Sync Rate Limited',
            'Gmail API rate limit encountered for ${account.email}. Waiting ${newBackoff}s before retry.',
            category: LogCategory.sync,
            metadata: {'account': account.email, 'backoffSeconds': newBackoff},
          );

          state = {
            ...state,
            account.id: current.copyWith(
              isRateLimited: true,
              backoffSeconds: newBackoff,
              countdownSeconds: newBackoff,
              statusMessage: 'Rate limit hit! Waiting 10s extra (${newBackoff}s total). Retrying in ${newBackoff}s...',
            ),
          };

          _startCountdown(account, newBackoff, isRateLimit: true);
          return;
        } else {
          // Other error (e.g. auth expired)
          state = {
            ...state,
            account.id: current.copyWith(
              isRunning: false,
              statusMessage: 'Sync paused: ${result.error}',
              error: result.error,
            ),
          };
          return;
        }
      }

      // Success: update sync time
      await accountRepo.updateSyncTime(account.id, DateTime.now());
      final newTotalSynced = current.totalSyncedThisSession + result.syncedCount;

      // Check if all older emails in mailbox are finished
      if (!result.hasMore || (result.syncedCount == 0 && !result.hasMore)) {
        state = {
          ...state,
          account.id: current.copyWith(
            isRunning: false,
            isRateLimited: false,
            countdownSeconds: 0,
            backoffSeconds: 10,
            totalSyncedThisSession: newTotalSynced,
            statusMessage: 'All older emails synced! ($newTotalSynced emails synced this session)',
          ),
        };
        return;
      }

      // Successful batch and more emails exist: wait 10 seconds for next batch
      const normalDelay = 10;
      state = {
        ...state,
        account.id: current.copyWith(
          isRateLimited: false,
          backoffSeconds: normalDelay,
          countdownSeconds: normalDelay,
          totalSyncedThisSession: newTotalSynced,
          statusMessage: 'Batch complete (+${result.syncedCount}). Next batch of 100 in ${normalDelay}s...',
        ),
      };

      _startCountdown(account, normalDelay, isRateLimit: false);
    } catch (e) {
      if (!getAccountState(account.id).isRunning) return;
      final isRateLimit = _isRateLimitError(e.toString());
      if (isRateLimit) {
        final newBackoff = current.backoffSeconds + 10;
        state = {
          ...state,
          account.id: current.copyWith(
            isRateLimited: true,
            backoffSeconds: newBackoff,
            countdownSeconds: newBackoff,
            statusMessage: 'Rate limit hit! Waiting 10s extra (${newBackoff}s total). Retrying in ${newBackoff}s...',
          ),
        };
        _startCountdown(account, newBackoff, isRateLimit: true);
      } else {
        state = {
          ...state,
          account.id: current.copyWith(
            isRunning: false,
            statusMessage: 'Error during sync: $e',
            error: e.toString(),
          ),
        };
      }
    }
  }

  void _startCountdown(MailAccount account, int seconds, {required bool isRateLimit}) {
    _cancelTimer(account.id);
    var remaining = seconds;

    _countdownTimers[account.id] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || !getAccountState(account.id).isRunning) {
        timer.cancel();
        return;
      }

      remaining--;
      if (remaining > 0) {
        final msg = isRateLimit
            ? 'Rate limit hit! Waiting 10s extra. Retrying in ${remaining}s...'
            : 'Next batch of 100 older emails in ${remaining}s...';
        state = {
          ...state,
          account.id: getAccountState(account.id).copyWith(
            countdownSeconds: remaining,
            statusMessage: msg,
          ),
        };
      } else {
        timer.cancel();
        _countdownTimers[account.id] = null;
        _executeBatch(account);
      }
    });
  }

  void _cancelTimer(String accountId) {
    _countdownTimers[accountId]?.cancel();
    _countdownTimers[accountId] = null;
  }

  bool _isRateLimitError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('429') ||
        lower.contains('403') ||
        lower.contains('rate limit') ||
        lower.contains('ratelimit') ||
        lower.contains('quota exceeded') ||
        lower.contains('quota') ||
        lower.contains('userratelimitexceeded') ||
        lower.contains('too many requests');
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final timer in _countdownTimers.values) {
      timer?.cancel();
    }
    _countdownTimers.clear();
    super.dispose();
  }
}

final autoSyncNotifierProvider =
    StateNotifierProvider<AutoSyncNotifier, Map<String, AccountAutoSyncState>>((ref) {
  return AutoSyncNotifier(ref);
});
