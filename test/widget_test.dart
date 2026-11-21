import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:cleanmail/core/constants/app_constants.dart';
import 'package:cleanmail/core/services/google_auth_service.dart';
import 'package:cleanmail/core/utils/heuristic_classifier.dart';
import 'package:cleanmail/data/local/database.dart';
import 'package:cleanmail/data/repositories/message_repository_impl.dart';
import 'package:cleanmail/domain/models/category.dart';
import 'package:cleanmail/domain/models/message.dart';
import 'package:cleanmail/features/inbox/presentation/widgets/email_tile.dart';
import 'package:cleanmail/features/providers.dart';
import 'package:cleanmail/features/reader/presentation/screens/reader_screen.dart';

void main() {
  test('App constants are properly configured', () {
    expect(AppConstants.appName, equals('CleanMail'));
    expect(AppConstants.accountBadgeColors, isNotEmpty);
  });

  test('HeuristicClassifier categorizes newsletter with unsubscribe header', () {
    final cat = HeuristicClassifier.classify(
      senderEmail: 'newsletter@substack.com',
      subject: 'Weekly Tech News',
      snippet: 'Here is your update',
      unsubscribeHeader: '<https://substack.com/unsubscribe>',
    );
    expect(cat, equals(MailCategory.newsletters));
  });

  test('HeuristicClassifier categorizes receipts and transactions', () {
    final cat = HeuristicClassifier.classify(
      senderEmail: 'receipts@uber.com',
      subject: 'Your trip receipt with Uber',
      snippet: 'Total charged: \$14.50',
    );
    expect(cat, equals(MailCategory.transactions));
  });

  test('HeuristicClassifier categorizes personal mail correctly', () {
    final cat = HeuristicClassifier.classify(
      senderEmail: 'colleague@company.com',
      subject: 'Lunch tomorrow?',
      snippet: 'Hey are you free for a quick chat over lunch?',
    );
    expect(cat, equals(MailCategory.personal));
  });

  testWidgets('EmailTile displays green dot next to sender name for unread emails',
      (WidgetTester tester) async {
    final unreadMessage = MailMessage(
      id: 'acc1_msg1',
      accountId: 'acc1',
      remoteMessageId: 'msg1',
      senderEmail: 'dev@github.com',
      senderName: 'GitHub',
      subject: 'New release available',
      snippet: 'Check out the latest release notes',
      plainTextBody: 'Check out the latest release notes',
      category: MailCategory.personal,
      isRead: false,
      receivedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EmailTile(message: unreadMessage),
          ),
        ),
      ),
    );

    expect(find.text('GitHub'), findsOneWidget);
    expect(find.byKey(const ValueKey('unread_indicator_dot')), findsOneWidget);
  });

  testWidgets('EmailTile does not display green dot for read emails',
      (WidgetTester tester) async {
    final readMessage = MailMessage(
      id: 'acc1_msg2',
      accountId: 'acc1',
      remoteMessageId: 'msg2',
      senderEmail: 'dev@github.com',
      senderName: 'GitHub',
      subject: 'Old release',
      snippet: 'Previous release notes',
      plainTextBody: 'Previous release notes',
      category: MailCategory.personal,
      isRead: true,
      receivedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EmailTile(message: readMessage),
          ),
        ),
      ),
    );

    expect(find.text('GitHub'), findsOneWidget);
    expect(find.byKey(const ValueKey('unread_indicator_dot')), findsNothing);
  });

  testWidgets('ReaderScreen shows short date initially and expands/collapses details on tap',
      (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());
    final testMessageRepo = MessageRepositoryImpl(testDb, GoogleAuthService());

    final message = MailMessage(
      id: 'acc1_msg_reader',
      accountId: 'acc1',
      remoteMessageId: 'remote_msg_reader',
      senderEmail: 'notifications@github.com',
      senderName: 'GitHub Team',
      subject: 'Security Alert on CleanMail',
      snippet: 'A new security update is available',
      plainTextBody: 'A new security update is available for your repository.',
      category: MailCategory.updates,
      isRead: false,
      receivedAt: DateTime.now().subtract(const Duration(hours: 3)),
    );

    await testMessageRepo.saveMessages([message]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
        ],
        child: const MaterialApp(
          home: ReaderScreen(messageId: 'acc1_msg_reader'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial collapsed state: short date '3h' is visible
    expect(find.text('3h'), findsOneWidget);
    expect(find.text('Sender Name:'), findsNothing);
    expect(find.text('Email Address:'), findsNothing);

    // Tap to expand
    await tester.tap(find.byKey(const ValueKey('reader_sender_box')));
    await tester.pumpAndSettle();

    // Verify expanded details are shown on separate lines
    expect(find.text('Sender Name:'), findsOneWidget);
    expect(find.text('Email Address:'), findsOneWidget);
    expect(find.text('Date & Time:'), findsOneWidget);
    expect(find.text('notifications@github.com'), findsWidgets);

    // Tap to collapse again
    await tester.tap(find.byKey(const ValueKey('reader_sender_box')));
    await tester.pumpAndSettle();

    // Verify collapsed again
    expect(find.text('Sender Name:'), findsNothing);
    expect(find.text('Email Address:'), findsNothing);
    expect(find.text('3h'), findsOneWidget);

    await testDb.close();
  });
}
