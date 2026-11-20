import 'package:drift/drift.dart';
import '../../domain/models/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../local/database.dart';

class AccountRepositoryImpl implements AccountRepository {
  final AppDatabase _db;

  AccountRepositoryImpl(this._db);

  @override
  Stream<List<MailAccount>> watchAccounts() {
    return _db.watchAllAccounts().map((entries) {
      return entries.map(_mapToDomain).toList();
    });
  }

  @override
  Future<List<MailAccount>> getAccounts() async {
    final entries = await _db.getAllAccounts();
    return entries.map(_mapToDomain).toList();
  }

  @override
  Future<void> saveAccount(MailAccount account) async {
    await _db.insertOrUpdateAccount(
      AccountsTableCompanion(
        id: Value(account.id),
        email: Value(account.email),
        displayName: Value(account.displayName),
        provider: Value(account.provider.name),
        avatarColorValue: Value(account.avatarColorValue),
        lastSyncedAt: Value(account.lastSyncedAt),
      ),
    );
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _db.deleteAccountById(id);
  }

  @override
  Future<void> updateSyncTime(String accountId, DateTime timestamp) async {
    final account = (await getAccounts()).firstWhere((a) => a.id == accountId);
    await saveAccount(account.copyWith(lastSyncedAt: timestamp));
  }

  MailAccount _mapToDomain(AccountEntry entry) {
    return MailAccount(
      id: entry.id,
      email: entry.email,
      displayName: entry.displayName,
      provider: MailProvider.fromString(entry.provider),
      avatarColorValue: entry.avatarColorValue,
      lastSyncedAt: entry.lastSyncedAt,
    );
  }
}
