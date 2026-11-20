import 'package:drift/drift.dart';

@DataClassName('AccountEntry')
class AccountsTable extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text()();
  TextColumn get provider => text()(); // 'gmail', 'outlook'
  IntColumn get avatarColorValue => integer()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
