import '../models/account.dart';

abstract class AccountRepository {
  Stream<List<MailAccount>> watchAccounts();
  Future<List<MailAccount>> getAccounts();
  Future<void> saveAccount(MailAccount account);
  Future<void> deleteAccount(String id);
  Future<void> updateSyncTime(String accountId, DateTime timestamp);
}
