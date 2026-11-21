import 'package:drift/drift.dart';

@DataClassName('SenderRuleEntry')
class SenderRulesTable extends Table {
  TextColumn get senderEmail => text()(); // Primary key (lowercase)
  TextColumn get preferredCategory => text()(); // 'personal', 'newsletters', 'transactions', 'updates'
  TextColumn get customTag => text().nullable()(); // Optional custom tag
  BoolColumn get isAutoLocked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {senderEmail};
}
