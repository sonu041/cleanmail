import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:cleanmail/core/constants/app_constants.dart';
import 'package:cleanmail/core/services/google_auth_service.dart';
import 'package:cleanmail/core/utils/heuristic_classifier.dart';
import 'package:cleanmail/core/utils/snackbar_utils.dart';
import 'package:cleanmail/data/local/database.dart';
import 'package:cleanmail/data/repositories/account_repository_impl.dart';
import 'package:cleanmail/data/repositories/message_repository_impl.dart';
import 'package:cleanmail/domain/models/account.dart';
import 'package:cleanmail/domain/models/category.dart';
import 'package:cleanmail/domain/models/message.dart';
import 'package:cleanmail/features/inbox/presentation/screens/inbox_screen.dart';
import 'package:cleanmail/features/inbox/presentation/widgets/email_tile.dart';
import 'package:cleanmail/features/providers.dart';
import 'package:cleanmail/features/reader/presentation/screens/reader_screen.dart';
import 'package:cleanmail/core/theme/app_theme.dart';

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
    final testAccountRepo = AccountRepositoryImpl(testDb);

    await testAccountRepo.saveAccount(
      const MailAccount(
        id: 'acc1',
        email: 'alex.chen@gmail.com',
        displayName: 'Alex Chen',
        provider: MailProvider.gmail,
        avatarColorValue: 0xFF2563EB,
      ),
    );

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
          databaseProvider.overrideWithValue(testDb),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
          accountRepositoryProvider.overrideWithValue(testAccountRepo),
        ],
        child: const MaterialApp(
          home: ReaderScreen(messageId: 'acc1_msg_reader'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial collapsed state: short date '3h' and to in collapsed header
    expect(find.text('3h'), findsOneWidget);
    expect(find.text('notifications@github.com • to: alex.chen@gmail.com'), findsOneWidget);
    expect(find.text('Sender Name:'), findsNothing);
    expect(find.text('From Email:'), findsNothing);
    expect(find.text('To:'), findsNothing);

    // Tap to expand
    await tester.tap(find.byKey(const ValueKey('reader_sender_box')));
    await tester.pumpAndSettle();

    // Verify expanded details are shown on separate lines with To placed after From Email
    expect(find.text('Sender Name:'), findsOneWidget);
    expect(find.text('From Email:'), findsOneWidget);
    expect(find.text('To:'), findsOneWidget);
    expect(find.text('Alex Chen <alex.chen@gmail.com>'), findsOneWidget);
    expect(find.text('Date & Time:'), findsOneWidget);
    expect(find.text('notifications@github.com'), findsWidgets);

    // Tap to collapse again
    await tester.tap(find.byKey(const ValueKey('reader_sender_box')));
    await tester.pumpAndSettle();

    // Verify collapsed again
    expect(find.text('Sender Name:'), findsNothing);
    expect(find.text('From Email:'), findsNothing);
    expect(find.text('To:'), findsNothing);
    expect(find.text('3h'), findsOneWidget);

    // Verify floating delete button is visible and present for short emails
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

    await testDb.close();
  });

  testWidgets('InboxScreen displays "Sync Next 20 Older Emails" footer button at the end of the email list',
      (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());
    final testMessageRepo = MessageRepositoryImpl(testDb, GoogleAuthService());
    final testAccountRepo = AccountRepositoryImpl(testDb);

    await testAccountRepo.saveAccount(
      const MailAccount(
        id: 'acc1',
        email: 'sonu041@gmail.com',
        displayName: 'Sonu',
        provider: MailProvider.gmail,
        avatarColorValue: 0xFF2563EB,
      ),
    );

    final message = MailMessage(
      id: 'acc1_msg1',
      accountId: 'acc1',
      remoteMessageId: 'remote1',
      senderEmail: 'newsletter@tech.com',
      senderName: 'Tech News',
      subject: 'Daily Digest',
      snippet: 'Here is your daily tech digest',
      plainTextBody: 'Here is your daily tech digest',
      category: MailCategory.newsletters,
      isRead: true,
      receivedAt: DateTime.now(),
    );

    await testMessageRepo.saveMessages([message]);

    // Standard Theme (Light)
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
          accountRepositoryProvider.overrideWithValue(testAccountRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const InboxScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify email tile is rendered
    expect(find.text('Tech News'), findsOneWidget);
    expect(find.text('Daily Digest'), findsOneWidget);

    // Verify mail filter buttons display the email count after the name
    expect(find.text('All Inboxes (1)'), findsOneWidget);
    expect(find.text('sonu041 (1)'), findsOneWidget);
    expect(find.text('Newsletters (1)'), findsOneWidget);
    expect(find.text('Personal (0)'), findsOneWidget);

    // Verify unread filter button is displayed
    expect(find.byKey(const ValueKey('unread_filter_btn')), findsOneWidget);
    expect(find.text('Unread (0)'), findsOneWidget);

    // Verify footer button exists at the end of the list
    expect(find.byKey(const ValueKey('sync_older_emails_btn')), findsOneWidget);
    expect(find.text('Sync Next 20 Older Emails'), findsOneWidget);

    // Nerd Theme
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
          accountRepositoryProvider.overrideWithValue(testAccountRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.nerdTheme,
          home: const InboxScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify mail filter buttons display the email count in Nerd format
    expect(find.text('All Inboxes [1]'), findsOneWidget);
    expect(find.text('sonu041 [1]'), findsOneWidget);
    expect(find.text('Newsletters [1]'), findsOneWidget);
    expect(find.text('Personal [0]'), findsOneWidget);
    expect(find.text('UNREAD [0]'), findsOneWidget);

    // Verify footer button with Nerd styling exists at the end of the list
    expect(find.byKey(const ValueKey('sync_older_emails_btn')), findsOneWidget);
    expect(find.text('> SYNC_NEXT_20_OLD_EMAILS'), findsOneWidget);

    await testDb.close();
  });

  testWidgets('Unread filter button filters messages to unread only and toggles back',
      (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());
    final testMessageRepo = MessageRepositoryImpl(testDb, GoogleAuthService());
    final testAccountRepo = AccountRepositoryImpl(testDb);

    await testAccountRepo.saveAccount(
      const MailAccount(
        id: 'acc1',
        email: 'sonu041@gmail.com',
        displayName: 'Sonu',
        provider: MailProvider.gmail,
        avatarColorValue: 0xFF2563EB,
      ),
    );

    final unreadMessage = MailMessage(
      id: 'acc1_unread',
      accountId: 'acc1',
      remoteMessageId: 'remote_u1',
      senderEmail: 'boss@work.com',
      senderName: 'Boss',
      subject: 'Urgent Task',
      snippet: 'Please check this asap',
      plainTextBody: 'Please check this asap',
      category: MailCategory.personal,
      isRead: false,
      receivedAt: DateTime.now(),
    );

    final readMessage = MailMessage(
      id: 'acc1_read',
      accountId: 'acc1',
      remoteMessageId: 'remote_r1',
      senderEmail: 'info@news.com',
      senderName: 'News Service',
      subject: 'Read Already Story',
      snippet: 'This story was already read',
      plainTextBody: 'This story was already read',
      category: MailCategory.newsletters,
      isRead: true,
      receivedAt: DateTime.now().subtract(const Duration(hours: 1)),
    );

    await testMessageRepo.saveMessages([unreadMessage, readMessage]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
          accountRepositoryProvider.overrideWithValue(testAccountRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const InboxScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Initially both emails are visible
    expect(find.text('Urgent Task'), findsOneWidget);
    expect(find.text('Read Already Story'), findsOneWidget);

    // Verify top-right filter overflow button exists
    expect(find.byKey(const ValueKey('toggle_filters_btn')), findsOneWidget);

    // Open filter section with right-to-left animation via top-right overflow button
    await tester.tap(find.byKey(const ValueKey('toggle_filters_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Unread (1)'), findsOneWidget);

    // Tap Unread filter button to filter only unread
    await tester.tap(find.byKey(const ValueKey('unread_filter_btn')));
    await tester.pumpAndSettle();

    // Now only the unread email is visible
    expect(find.text('Urgent Task'), findsOneWidget);
    expect(find.text('Read Already Story'), findsNothing);

    // Tap Unread filter button again to toggle OFF
    await tester.tap(find.byKey(const ValueKey('unread_filter_btn')));
    await tester.pumpAndSettle();

    // Both emails are visible again
    expect(find.text('Urgent Task'), findsOneWidget);
    expect(find.text('Read Already Story'), findsOneWidget);

    // Collapse filter section via the Hide chip in the filter section
    expect(find.byKey(const ValueKey('hide_filters_btn')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hide_filters_btn')));
    await tester.pumpAndSettle();

    // Re-open via top-right overflow button
    await tester.tap(find.byKey(const ValueKey('toggle_filters_btn')));
    await tester.pumpAndSettle();

    // Collapse via top-right overflow button
    await tester.tap(find.byKey(const ValueKey('toggle_filters_btn')));
    await tester.pumpAndSettle();

    await testDb.close();
  });

  testWidgets('SnackBarUtils auto-hides confirmation message after 5 seconds',
      (WidgetTester tester) async {
    bool undoTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                SnackBarUtils.showAutoHideSnackBar(
                  messenger: ScaffoldMessenger.of(ctx),
                  message: 'Deleted "Test Subject"',
                  onUndo: () {
                    undoTapped = true;
                  },
                );
              },
              child: const Text('Delete Email'),
            ),
          ),
        ),
      ),
    );

    // Tap delete button
    await tester.tap(find.text('Delete Email'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Deleted "Test Subject"'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // After 3 seconds, confirmation is still visible
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Deleted "Test Subject"'), findsOneWidget);

    // After another 2.1 seconds (total > 5 seconds), auto-hide triggers
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();

    expect(find.text('Deleted "Test Subject"'), findsNothing);
    expect(undoTapped, isFalse);
  });

  testWidgets('SnackBarUtils undo cancels timer and dismisses immediately',
      (WidgetTester tester) async {
    bool undoTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                SnackBarUtils.showAutoHideSnackBar(
                  messenger: ScaffoldMessenger.of(ctx),
                  message: 'Deleted "Test Subject"',
                  onUndo: () {
                    undoTapped = true;
                  },
                );
              },
              child: const Text('Delete Email'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Delete Email'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Deleted "Test Subject"'), findsOneWidget);

    // Tap Undo
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(undoTapped, isTrue);
    expect(find.text('Deleted "Test Subject"'), findsNothing);
  });

  testWidgets('ReaderScreen delete button shows confirmation that auto-hides after 5 seconds',
      (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());
    final testMessageRepo = MessageRepositoryImpl(testDb, GoogleAuthService());
    final testAccountRepo = AccountRepositoryImpl(testDb);

    await testAccountRepo.saveAccount(
      const MailAccount(
        id: 'acc1',
        email: 'alex.chen@gmail.com',
        displayName: 'Alex Chen',
        provider: MailProvider.gmail,
        avatarColorValue: 0xFF2563EB,
      ),
    );

    final message = MailMessage(
      id: 'acc1_msg_delete_test',
      accountId: 'acc1',
      remoteMessageId: 'remote_msg_delete',
      senderEmail: 'test@example.com',
      senderName: 'Test Sender',
      subject: 'Message to be deleted',
      snippet: 'This message will be deleted',
      plainTextBody: 'This message will be deleted',
      category: MailCategory.personal,
      isRead: false,
      receivedAt: DateTime.now(),
    );

    await testMessageRepo.saveMessages([message]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
          accountRepositoryProvider.overrideWithValue(testAccountRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => const ReaderScreen(messageId: 'acc1_msg_delete_test'),
                    ),
                  );
                },
                child: const Text('Open Reader'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Open ReaderScreen
    await tester.tap(find.text('Open Reader'));
    await tester.pumpAndSettle();

    // Verify ReaderScreen is open
    expect(find.text('Message to be deleted'), findsOneWidget);

    // Tap the floating delete button
    final deleteBtn = find.byKey(const ValueKey('reader_floating_delete_btn'));
    expect(deleteBtn, findsOneWidget);
    await tester.tap(deleteBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Confirmation SnackBar appears
    expect(find.text('Deleted "Message to be deleted"'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // Advance 3 seconds - still visible
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Deleted "Message to be deleted"'), findsOneWidget);

    // Advance another 2.1 seconds - auto-hides
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();
    expect(find.text('Deleted "Message to be deleted"'), findsNothing);

    await testDb.close();
  });

  testWidgets('InboxScreen multiselect emails and delete all selected with confirmation and undo',
      (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());
    final testMessageRepo = MessageRepositoryImpl(testDb, GoogleAuthService());
    final testAccountRepo = AccountRepositoryImpl(testDb);

    await testAccountRepo.saveAccount(
      const MailAccount(
        id: 'acc1',
        email: 'user@example.com',
        displayName: 'User',
        provider: MailProvider.gmail,
        avatarColorValue: 0xFF2563EB,
      ),
    );

    final msg1 = MailMessage(
      id: 'msg_multi_1',
      accountId: 'acc1',
      remoteMessageId: 'remote_1',
      senderEmail: 'alice@cleanmail.com',
      senderName: 'Alice',
      subject: 'First Topic',
      snippet: 'Snippet 1',
      plainTextBody: 'Body 1',
      category: MailCategory.personal,
      isRead: false,
      receivedAt: DateTime.now(),
    );

    final msg2 = MailMessage(
      id: 'msg_multi_2',
      accountId: 'acc1',
      remoteMessageId: 'remote_2',
      senderEmail: 'bob@cleanmail.com',
      senderName: 'Bob',
      subject: 'Second Topic',
      snippet: 'Snippet 2',
      plainTextBody: 'Body 2',
      category: MailCategory.personal,
      isRead: false,
      receivedAt: DateTime.now(),
    );

    await testMessageRepo.saveMessages([msg1, msg2]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
          accountRepositoryProvider.overrideWithValue(testAccountRepo),
        ],
        child: const MaterialApp(
          home: InboxScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify both emails are present
    expect(find.text('First Topic'), findsOneWidget);
    expect(find.text('Second Topic'), findsOneWidget);

    // Enter selection mode via toolbar button
    expect(find.byKey(const ValueKey('enter_selection_mode_btn')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('enter_selection_mode_btn')));
    await tester.pumpAndSettle();

    // Verify selection AppBar is shown with 0 selected
    expect(find.text('0 selected'), findsOneWidget);
    expect(find.byKey(const ValueKey('email_checkbox_msg_multi_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('email_checkbox_msg_multi_2')), findsOneWidget);

    // Tap first email to select it
    await tester.tap(find.text('First Topic'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    // Tap second email to select it
    await tester.tap(find.text('Second Topic'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    // Tap delete selected button
    expect(find.byKey(const ValueKey('delete_selected_btn')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delete_selected_btn')));
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.text('Delete 2 emails?'), findsOneWidget);

    // Confirm deletion
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Confirmation SnackBar appears
    expect(find.text('Deleted 2 emails'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // Emails are removed from list
    expect(find.text('First Topic'), findsNothing);
    expect(find.text('Second Topic'), findsNothing);

    // Tap Undo
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    // Emails are restored
    expect(find.text('First Topic'), findsOneWidget);
    expect(find.text('Second Topic'), findsOneWidget);

    // Flush any pending log debounce timers
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await testDb.close();
  });
}
