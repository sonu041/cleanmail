import 'package:drift/drift.dart';

@DataClassName('MessageEntry')
class MessagesTable extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get remoteMessageId => text()();
  TextColumn get threadId => text().nullable()();
  TextColumn get senderEmail => text()();
  TextColumn get senderName => text()();
  TextColumn get subject => text()();
  TextColumn get snippet => text()();
  TextColumn get plainTextBody => text()();
  TextColumn get category => text()(); // 'personal', 'newsletters', 'transactions', 'updates'
  TextColumn get customTag => text().nullable()();
  TextColumn get unsubscribeUrl => text().nullable()();
  TextColumn get unsubscribeMailto => text().nullable()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get receivedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
