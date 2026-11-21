import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleanmail/core/services/google_auth_service.dart';
import 'package:cleanmail/data/local/database.dart';
import 'package:cleanmail/data/repositories/account_repository_impl.dart';
import 'package:cleanmail/data/repositories/message_repository_impl.dart';
import 'package:cleanmail/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:cleanmail/features/providers.dart';

void main() {
  testWidgets('AccountsScreen renders seamlessly with legacy migrated accounts containing null values',
      (WidgetTester tester) async {
    final executor = NativeDatabase.memory();
    // 1. Manually create tables as they existed in schema v3 (no total_messages column)
    await executor.ensureOpen(_FakeUser());
    await executor.runCustom('''
      CREATE TABLE accounts_table (
        id TEXT NOT NULL PRIMARY KEY,
        email TEXT NOT NULL,
        display_name TEXT NOT NULL,
        provider TEXT NOT NULL,
        avatar_color_value INTEGER NOT NULL,
        last_synced_at INTEGER
      );
    ''');
    await executor.runCustom('''
      INSERT INTO accounts_table (id, email, display_name, provider, avatar_color_value)
      VALUES ('acc_legacy_1', 'legacy@example.com', 'Legacy User', 'gmail', 42);
    ''');
    await executor.runCustom('PRAGMA user_version = 3;');

    // 2. Open AppDatabase with schemaVersion 5 (will trigger migration and beforeOpen repair)
    final db = AppDatabase(executor);
    final accountRepo = AccountRepositoryImpl(db);
    final messageRepo = MessageRepositoryImpl(db, GoogleAuthService());

    // 3. Pump AccountsScreen widget
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountRepositoryProvider.overrideWithValue(accountRepo),
          messageRepositoryProvider.overrideWithValue(messageRepo),
        ],
        child: const MaterialApp(
          home: AccountsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AccountsScreen renders without throwing any _TypeError
    expect(find.byType(AccountsScreen), findsOneWidget);
    expect(find.text('Legacy User'), findsOneWidget);
    expect(find.text('legacy@example.com'), findsOneWidget);
    expect(find.text('0 of 0 synced (100%)'), findsOneWidget);

    await db.close();
  });
}

class _FakeUser extends QueryExecutorUser {
  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
  @override
  int get schemaVersion => 3;
}

