import 'package:drift/drift.dart';

@DataClassName('AccountEntry')
class AccountsTable extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text()();
  TextColumn get provider => text()(); // 'gmail', 'outlook'
  IntColumn get avatarColorValue => integer()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  IntColumn get totalMessages => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
