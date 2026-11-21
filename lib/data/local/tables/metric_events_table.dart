import 'package:drift/drift.dart';

@DataClassName('MetricEventEntry')
class MetricEventsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get eventType => text()(); // 'sync', 'delete', 'unsubscribe', 'lock'
  IntColumn get count => integer().withDefault(const Constant(1))();
  TextColumn get accountId => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get details => text().nullable()();
}
