import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum LogLevel {
  info('INFO', 'Information'),
  success('SUCCESS', 'Success'),
  warning('WARNING', 'Warning'),
  error('ERROR', 'Error');

  final String code;
  final String label;
  const LogLevel(this.code, this.label);
}

enum LogCategory {
  all('ALL', 'All Categories'),
  sync('SYNC', 'Mailbox & Delta Sync'),
  auth('AUTH', 'Authentication & Tokens'),
  triage('TRIAGE', 'Read, Trash & Archive'),
  pipeline('PIPELINE', 'Text Parsing & Privacy'),
  system('SYSTEM', 'System & Preferences');

  final String code;
  final String label;
  const LogCategory(this.code, this.label);
}

class AppLog {
  final String id;
  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String title;
  final String details;
  final Map<String, dynamic>? metadata;

  AppLog({
    String? id,
    DateTime? timestamp,
    required this.level,
    required this.category,
    required this.title,
    required this.details,
    this.metadata,
  })  : id = id ?? '${DateTime.now().microsecondsSinceEpoch}',
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'category': category.name,
        'title': title,
        'details': details,
        if (metadata != null) 'metadata': metadata,
      };

  factory AppLog.fromJson(Map<String, dynamic> json) {
    return AppLog(
      id: json['id'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      level: LogLevel.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => LogLevel.info,
      ),
      category: LogCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => LogCategory.system,
      ),
      title: json['title'] as String? ?? 'Log Entry',
      details: json['details'] as String? ?? '',
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
    );
  }
}

/// Centralized operation log service for tracking syncs, token refreshes, and app operations.
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  static const _storageKey = 'cleanmail_app_logs_v1';
  static const _statsKey = 'cleanmail_app_stats_v1';
  static const int _maxInMemoryLogs = 500;
  static const int _maxPersistedLogs = 200;
  static const int _maxInfoSuccessLogs = 100;

  int get maxInfoSuccessLogs => _maxInfoSuccessLogs;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final List<AppLog> _logs = [];
  final StreamController<List<AppLog>> _streamController =
      StreamController<List<AppLog>>.broadcast();

  // Statistics trackers
  int _totalMailsSynced = 0;
  DateTime? _lastLoginOrTokenRefresh;
  DateTime? _lastSyncTime;
  String? _lastSyncStatus;

  int get totalMailsSynced => _totalMailsSynced;
  DateTime? get lastLoginOrTokenRefresh => _lastLoginOrTokenRefresh;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastSyncStatus => _lastSyncStatus;

  List<AppLog> get logs => List.unmodifiable(_logs);
  Stream<List<AppLog>> get logsStream => _streamController.stream;

  bool _initialized = false;
  Timer? _persistDebounce;

  /// Loads previously persisted logs and stats on startup.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final rawStats = await _storage.read(key: _statsKey);
      if (rawStats != null && rawStats.isNotEmpty) {
        final decoded = jsonDecode(rawStats) as Map<String, dynamic>;
        _totalMailsSynced = (decoded['totalMailsSynced'] as num?)?.toInt() ?? 0;
        if (decoded['lastLogin'] != null) {
          _lastLoginOrTokenRefresh = DateTime.tryParse(decoded['lastLogin'].toString());
        }
        if (decoded['lastSync'] != null) {
          _lastSyncTime = DateTime.tryParse(decoded['lastSync'].toString());
        }
        _lastSyncStatus = decoded['lastSyncStatus'] as String?;
      }

      final rawLogs = await _storage.read(key: _storageKey);
      if (rawLogs != null && rawLogs.isNotEmpty) {
        final list = jsonDecode(rawLogs) as List<dynamic>;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            _logs.add(AppLog.fromJson(item));
          }
        }
        purgeOldInfoAndSuccessLogs();
      }
    } catch (e) {
      debugPrint('LogService init note: $e');
    }

    _notify();
  }

  /// Automatically purges info and success messages older than 100 entries.
  /// Warnings and errors are preserved for diagnostics and troubleshooting.
  void purgeOldInfoAndSuccessLogs({bool notify = false}) {
    int infoSuccessCount = 0;
    final kept = <AppLog>[];

    for (final log in _logs) {
      if (log.level == LogLevel.info || log.level == LogLevel.success) {
        infoSuccessCount++;
        if (infoSuccessCount <= _maxInfoSuccessLogs) {
          kept.add(log);
        }
        // When infoSuccessCount > _maxInfoSuccessLogs (older than 100), the entry is purged
      } else {
        // Warning and Error logs are always preserved
        kept.add(log);
      }
    }

    if (kept.length > _maxInMemoryLogs) {
      kept.removeRange(_maxInMemoryLogs, kept.length);
    }

    _logs.clear();
    _logs.addAll(kept);

    if (notify) {
      _notify();
    }
  }

  /// Records a new application operation.
  void addLog({
    required LogLevel level,
    required LogCategory category,
    required String title,
    required String details,
    Map<String, dynamic>? metadata,
  }) {
    final entry = AppLog(
      level: level,
      category: category,
      title: title,
      details: details,
      metadata: metadata,
    );

    _logs.insert(0, entry);
    purgeOldInfoAndSuccessLogs();

    // Update aggregate stats based on events
    if (category == LogCategory.sync) {
      _lastSyncTime = entry.timestamp;
      _lastSyncStatus = title;
      if (metadata != null && metadata.containsKey('syncedCount')) {
        final count = (metadata['syncedCount'] as num?)?.toInt() ?? 0;
        if (count > 0) {
          _totalMailsSynced += count;
        }
      }
    }

    if (category == LogCategory.auth) {
      _lastLoginOrTokenRefresh = entry.timestamp;
    }

    _notify();
    _schedulePersist();

    debugPrint('[${level.code}] [${category.code}] $title - $details');
  }

  void _notify() {
    if (!_streamController.isClosed) {
      _streamController.add(List.unmodifiable(_logs));
    }
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final toPersist = _logs.take(_maxPersistedLogs).map((e) => e.toJson()).toList();
        await _storage.write(key: _storageKey, value: jsonEncode(toPersist));

        final statsMap = {
          'totalMailsSynced': _totalMailsSynced,
          if (_lastLoginOrTokenRefresh != null)
            'lastLogin': _lastLoginOrTokenRefresh!.toIso8601String(),
          if (_lastSyncTime != null)
            'lastSync': _lastSyncTime!.toIso8601String(),
          if (_lastSyncStatus != null) 'lastSyncStatus': _lastSyncStatus,
        };
        await _storage.write(key: _statsKey, value: jsonEncode(statsMap));
      } catch (e) {
        debugPrint('Error persisting logs: $e');
      }
    });
  }

  /// Clears all recorded operation logs and resets live counters.
  Future<void> clearLogs() async {
    _logs.clear();
    _totalMailsSynced = 0;
    _lastSyncStatus = null;
    _notify();
    try {
      await _storage.delete(key: _storageKey);
      await _storage.delete(key: _statsKey);
    } catch (_) {}
  }

  /// Exports all current logs as a formatted text block suitable for clipboard or sharing.
  String exportLogsAsText() {
    if (_logs.isEmpty) return 'CleanMail Operation Logs: (No logs recorded yet)';

    final buf = StringBuffer();
    buf.writeln('========================================');
    buf.writeln('CLEANMAIL OPERATION LOG REPORT');
    buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buf.writeln('Total Mails Synced: $_totalMailsSynced');
    buf.writeln('Last Login / Token Refresh: ${_lastLoginOrTokenRefresh?.toIso8601String() ?? "N/A"}');
    buf.writeln('Last Sync Time: ${_lastSyncTime?.toIso8601String() ?? "N/A"}');
    buf.writeln('Total Log Records: ${_logs.length}');
    buf.writeln('========================================\n');

    for (final log in _logs) {
      final ts = log.timestamp.toIso8601String();
      buf.writeln('[$ts] [${log.level.code}] [${log.category.code}] ${log.title}');
      if (log.details.isNotEmpty) {
        buf.writeln('  Details: ${log.details}');
      }
      if (log.metadata != null && log.metadata!.isNotEmpty) {
        buf.writeln('  Metadata: ${jsonEncode(log.metadata)}');
      }
      buf.writeln('----------------------------------------');
    }

    return buf.toString();
  }
}

/// Convenience static logging API available anywhere in the codebase.
class AppLogger {
  const AppLogger._();

  static void info(
    String title,
    String details, {
    LogCategory category = LogCategory.system,
    Map<String, dynamic>? metadata,
  }) {
    LogService().addLog(
      level: LogLevel.info,
      category: category,
      title: title,
      details: details,
      metadata: metadata,
    );
  }

  static void success(
    String title,
    String details, {
    LogCategory category = LogCategory.system,
    Map<String, dynamic>? metadata,
  }) {
    LogService().addLog(
      level: LogLevel.success,
      category: category,
      title: title,
      details: details,
      metadata: metadata,
    );
  }

  static void warning(
    String title,
    String details, {
    LogCategory category = LogCategory.system,
    Map<String, dynamic>? metadata,
  }) {
    LogService().addLog(
      level: LogLevel.warning,
      category: category,
      title: title,
      details: details,
      metadata: metadata,
    );
  }

  static void error(
    String title,
    String details, {
    LogCategory category = LogCategory.system,
    Map<String, dynamic>? metadata,
  }) {
    LogService().addLog(
      level: LogLevel.error,
      category: category,
      title: title,
      details: details,
      metadata: metadata,
    );
  }
}
