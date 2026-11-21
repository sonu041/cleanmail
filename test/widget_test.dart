import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:cleanmail/core/constants/app_constants.dart';
import 'package:cleanmail/core/services/auto_sync_service.dart';
import 'package:cleanmail/core/services/google_auth_service.dart';
import 'package:cleanmail/core/utils/heuristic_classifier.dart';
import 'package:cleanmail/core/utils/snackbar_utils.dart';
import 'package:cleanmail/data/local/database.dart';
import 'package:cleanmail/data/repositories/account_repository_impl.dart';
import 'package:cleanmail/data/repositories/message_repository_impl.dart';
import 'package:cleanmail/domain/models/account.dart';
import 'package:cleanmail/domain/models/category.dart';
import 'package:cleanmail/domain/models/message.dart';
import 'package:cleanmail/features/clean_sweep/presentation/screens/clean_sweep_screen.dart';
import 'package:cleanmail/features/clean_sweep/presentation/screens/sender_emails_screen.dart';
import 'package:cleanmail/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:cleanmail/features/inbox/presentation/screens/inbox_screen.dart';
import 'package:cleanmail/features/inbox/presentation/widgets/email_tile.dart';
import 'package:cleanmail/features/providers.dart';
import 'package:cleanmail/features/reader/presentation/screens/reader_screen.dart';
import 'package:cleanmail/features/settings/presentation/screens/logs_screen.dart';
import 'package:cleanmail/features/settings/presentation/screens/settings_screen.dart';
import 'package:cleanmail/features/dashboard/presentation/screens/dashboard_screen.dart';
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

    // Verify top AppBar no longer has select icon or mailbox profile icon
    expect(find.byKey(const ValueKey('enter_selection_mode_btn')), findsNothing);
    expect(find.byTooltip('Mailbox Accounts'), findsNothing);

    // Enter selection mode via long press on an email
    await tester.longPress(find.text('First Topic'));
    await tester.pumpAndSettle();

    // Verify selection AppBar is shown with 1 selected and checkboxes are shown
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byKey(const ValueKey('email_checkbox_msg_multi_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('email_checkbox_msg_multi_2')), findsOneWidget);

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

  testWidgets('CleanSweepScreen loads sender summaries successfully without SQL type error',
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
      id: 'sweep_test_1',
      accountId: 'acc1',
      remoteMessageId: 'remote_sw1',
      senderEmail: 'promo@store.com',
      senderName: 'Promo Store',
      subject: '50% Off Everything',
      snippet: 'Special discount',
      plainTextBody: 'Body discount',
      category: MailCategory.updates,
      isRead: false,
      receivedAt: DateTime.now(),
    );

    await testMessageRepo.saveMessages([msg1]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
          accountRepositoryProvider.overrideWithValue(testAccountRepo),
        ],
        child: const MaterialApp(
          home: CleanSweepScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Sender Sweep screen loaded successfully
    expect(find.text('Sender Sweep'), findsOneWidget);
    expect(find.text('Top Senders by Volume'), findsOneWidget);
    expect(find.text('Promo Store'), findsOneWidget);
    expect(find.text('promo@store.com'), findsOneWidget);
    expect(find.text('1 emails'), findsOneWidget);
    expect(find.text('Latest: "50% Off Everything"'), findsOneWidget);
    expect(find.text('Archive All'), findsNothing);
    expect(find.text('Delete All'), findsOneWidget);

    // Verify no error message is displayed
    expect(find.textContaining('Error loading senders'), findsNothing);

    // Verify "View Emails" button is NOT shown
    expect(find.text('View Emails'), findsNothing);

    // Tap sender title to open SenderEmailsScreen
    final senderTitle = find.byKey(const ValueKey('sender_title_promo@store.com'));
    expect(senderTitle, findsOneWidget);
    await tester.tap(senderTitle);
    await tester.pumpAndSettle();

    // Verify SenderEmailsScreen is open and shows the email list
    expect(find.byType(SenderEmailsScreen), findsOneWidget);
    expect(find.text('50% Off Everything'), findsOneWidget);
    expect(find.text('1 email • 1 unread'), findsOneWidget);

    // Tap back button to return to Sender Sweep
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Tap sender card directly to verify card tap also opens SenderEmailsScreen
    final senderCard = find.byKey(const ValueKey('sender_card_promo@store.com'));
    expect(senderCard, findsOneWidget);
    await tester.tap(senderCard);
    await tester.pumpAndSettle();

    expect(find.byType(SenderEmailsScreen), findsOneWidget);
    expect(find.text('50% Off Everything'), findsOneWidget);

    await testDb.close();
  });

  testWidgets('EmailTile visibly displays locked badge and blocks swipe-to-delete when locked',
      (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());
    final testMessageRepo = MessageRepositoryImpl(testDb, GoogleAuthService());

    final lockedMsg = MailMessage(
      id: 'tile_locked_1',
      accountId: 'acc1',
      remoteMessageId: 'remote_tl1',
      senderEmail: 'tax@gov.org',
      senderName: 'Tax Authority',
      subject: 'Annual Tax Assessment',
      snippet: 'Official confidential document',
      plainTextBody: 'Tax document details',
      category: MailCategory.personal,
      isRead: true,
      receivedAt: DateTime.now(),
      isLocked: true,
    );

    await testMessageRepo.saveMessages([lockedMsg]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EmailTile(message: lockedMsg),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify [LOCKED] badge and lock icon are visible
    expect(find.byKey(const ValueKey('email_locked_tag_tile_locked_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('email_lock_icon_tile_locked_1')), findsOneWidget);
    expect(find.text('LOCKED'), findsOneWidget);

    // Swipe left (from right to left) to trigger Delete
    await tester.drag(find.byType(Dismissible), const Offset(-500.0, 0.0));
    await tester.pumpAndSettle();

    // Verify warning SnackBar is displayed: deletion blocked!
    expect(find.text('This email is locked. Unlock it first to delete.'), findsOneWidget);

    // Verify EmailTile is still in the tree (dismissal rejected)
    expect(find.text('Annual Tax Assessment'), findsOneWidget);

    // Tap the locked badge to unlock
    await tester.tap(find.byKey(const ValueKey('email_locked_tag_tile_locked_1')));
    await tester.pumpAndSettle();

    expect(find.text('Email unlocked'), findsOneWidget);

    // Verify in database that it was unlocked
    final inDb = await testMessageRepo.getMessage('tile_locked_1');
    expect(inDb!.isLocked, isFalse);

    // Let SnackBar auto-hide timers expire cleanly
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await testDb.close();
  });

  testWidgets('ReaderScreen displays locked tag banner, toggles lock via AppBar, and blocks deletion',
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

    final lockedMsg = MailMessage(
      id: 'reader_lock_msg_1',
      accountId: 'acc1',
      remoteMessageId: 'remote_rl1',
      senderEmail: 'crypto@wallet.com',
      senderName: 'Wallet Service',
      subject: 'Recovery Phrase Backup',
      snippet: 'Secret seed phrase',
      plainTextBody: 'Do not share this phrase with anyone.',
      category: MailCategory.personal,
      isRead: true,
      receivedAt: DateTime.now(),
      isLocked: true,
    );

    await testMessageRepo.saveMessages([lockedMsg]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
          accountRepositoryProvider.overrideWithValue(testAccountRepo),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => const ReaderScreen(messageId: 'reader_lock_msg_1'),
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
    await tester.tap(find.text('Open Reader'));
    await tester.pumpAndSettle();

    // Verify ReaderScreen is open
    expect(find.text('Recovery Phrase Backup'), findsOneWidget);

    // Verify LOCKED banner tag is visible
    expect(find.byKey(const ValueKey('reader_locked_tag')), findsOneWidget);
    expect(find.text('LOCKED • Deletion Protected'), findsOneWidget);

    // Verify AppBar lock button is present
    expect(find.byKey(const ValueKey('reader_lock_btn')), findsOneWidget);

    // Attempt to delete via floating delete button
    final deleteBtn = find.byKey(const ValueKey('reader_floating_delete_btn'));
    expect(deleteBtn, findsOneWidget);
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();

    // Verify delete is blocked and warning SnackBar shown
    expect(find.text('This email is locked. Unlock it first to delete.'), findsOneWidget);
    // ReaderScreen still open
    expect(find.text('Recovery Phrase Backup'), findsOneWidget);

    // Tap AppBar lock button to unlock
    await tester.tap(find.byKey(const ValueKey('reader_lock_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Email unlocked'), findsOneWidget);
    // LOCKED tag banner is no longer visible
    expect(find.byKey(const ValueKey('reader_locked_tag')), findsNothing);

    // Advance time past the 500ms debounce of delete button
    await tester.pump(const Duration(milliseconds: 600));

    // Tap floating delete button now that it is unlocked
    await tester.tap(deleteBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Successfully deleted and returned to previous screen
    expect(find.text('Deleted "Recovery Phrase Backup"'), findsOneWidget);
    expect(find.text('Open Reader'), findsOneWidget);

    // Let SnackBar auto-hide timers expire cleanly
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await testDb.close();
  });

  testWidgets('EmailTile category chip tap opens SetPreferredTagDialog and setting preferred tag updates email and applies going forward',
      (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());
    final testMessageRepo = MessageRepositoryImpl(testDb, GoogleAuthService());

    final msg1 = MailMessage(
      id: 'pref_tag_msg_1',
      accountId: 'acc1',
      remoteMessageId: 'remote_pt1',
      senderEmail: 'partner@company.com',
      senderName: 'Business Partner',
      subject: 'Quarterly Review',
      snippet: 'Review details',
      plainTextBody: 'Body text',
      category: MailCategory.newsletters, // Initially newsletters
      isRead: true,
      receivedAt: DateTime.now(),
      isLocked: false,
    );

    await testMessageRepo.saveMessages([msg1]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EmailTile(message: msg1),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial chip text
    expect(find.byKey(const ValueKey('email_category_chip_pref_tag_msg_1')), findsOneWidget);
    expect(find.text('Newsletters'), findsOneWidget);

    // Tap category chip to open SetPreferredTagDialog
    await tester.tap(find.byKey(const ValueKey('email_category_chip_pref_tag_msg_1')));
    await tester.pumpAndSettle();

    // Verify SetPreferredTagDialog is open
    expect(find.text('Set Preferred Tag'), findsOneWidget);
    expect(find.text('partner@company.com'), findsOneWidget);

    // Select Personal category
    final personalChip = find.byKey(const ValueKey('pref_cat_chip_personal'));
    expect(personalChip, findsOneWidget);
    await tester.tap(personalChip);
    await tester.pumpAndSettle();

    // Enter custom tag label
    final customTagInput = find.byKey(const ValueKey('pref_custom_tag_input'));
    expect(customTagInput, findsOneWidget);
    await tester.enterText(customTagInput, 'Direct');
    await tester.pumpAndSettle();

    // Toggle auto-lock
    final autoLockToggle = find.byKey(const ValueKey('pref_auto_lock_toggle'));
    expect(autoLockToggle, findsOneWidget);
    await tester.tap(autoLockToggle);
    await tester.pumpAndSettle();

    // Tap Save Preferred Tag
    final saveBtn = find.byKey(const ValueKey('pref_save_rule_btn'));
    expect(saveBtn, findsOneWidget);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Verify confirmation SnackBar
    expect(find.text('Preferred tag [Personal / Direct] set for partner@company.com'), findsOneWidget);

    // Verify in database that existing email was updated
    final updatedExisting = await testMessageRepo.getMessage('pref_tag_msg_1');
    expect(updatedExisting!.category, equals(MailCategory.personal));
    expect(updatedExisting.customTag, equals('Direct'));
    expect(updatedExisting.isLocked, isTrue);

    // Verify that going forward, any new email from partner@company.com receives the preferred tag
    final futureMsg = MailMessage(
      id: 'pref_tag_msg_2',
      accountId: 'acc1',
      remoteMessageId: 'remote_pt2',
      senderEmail: 'partner@company.com',
      senderName: 'Business Partner',
      subject: 'New Project Proposal',
      snippet: 'Proposal snippet',
      plainTextBody: 'Proposal body',
      category: MailCategory.newsletters, // incoming raw category
      isRead: false,
      receivedAt: DateTime.now(),
      isLocked: false,
    );
    await testMessageRepo.saveMessages([futureMsg]);

    final updatedFuture = await testMessageRepo.getMessage('pref_tag_msg_2');
    expect(updatedFuture!.category, equals(MailCategory.personal));
    expect(updatedFuture.customTag, equals('Direct'));
    expect(updatedFuture.isLocked, isTrue);

    // Let SnackBar auto-hide timers expire cleanly
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await testDb.close();
  });

  testWidgets('CleanSweepScreen action buttons wrap properly without overflow on narrow screens',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testDb = AppDatabase(NativeDatabase.memory());
    final testMessageRepo = MessageRepositoryImpl(testDb, GoogleAuthService());
    final testAccountRepo = AccountRepositoryImpl(testDb);

    final msg = MailMessage(
      id: 'narrow_sweep_1',
      accountId: 'acc1',
      remoteMessageId: 'remote_ns1',
      senderEmail: 'promo@store.com',
      senderName: 'Promo Store',
      subject: 'Deal',
      snippet: 'Deal snippet',
      plainTextBody: 'Body',
      category: MailCategory.updates,
      isRead: false,
      receivedAt: DateTime.now(),
    );
    await testMessageRepo.saveMessages([msg]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
          accountRepositoryProvider.overrideWithValue(testAccountRepo),
        ],
        child: const MaterialApp(
          home: CleanSweepScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify action buttons are present and no layout overflow exception is thrown
    expect(find.byKey(const ValueKey('pref_tag_btn_promo@store.com')), findsOneWidget);
    expect(find.text('View Emails'), findsNothing);
    expect(find.text('Archive All'), findsNothing);
    expect(find.text('Delete All'), findsOneWidget);

    await testDb.close();
  });

  testWidgets('AccountsScreen displays sync progress bar, X of Y synced, and total available in mailbox',
      (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());
    final testAccountRepo = AccountRepositoryImpl(testDb);
    final testMessageRepo = MessageRepositoryImpl(testDb, GoogleAuthService());

    // 1. Create a connected mailbox with 100 total messages available in Gmail
    final account = MailAccount(
      id: 'acc_progress_1',
      email: 'alex.chen@gmail.com',
      displayName: 'Alex Gmail',
      provider: MailProvider.gmail,
      avatarColorValue: 0xFF1E88E5,
      lastSyncedAt: DateTime.now(),
      totalMessages: 100,
    );
    await testAccountRepo.saveAccount(account);

    // 2. Insert 25 synced messages in local DB for this account
    final messages = List.generate(
      25,
      (i) => MailMessage(
        id: 'msg_prog_$i',
        accountId: 'acc_progress_1',
        remoteMessageId: 'remote_prog_$i',
        senderEmail: 'sender$i@test.com',
        senderName: 'Sender $i',
        subject: 'Subject $i',
        snippet: 'Snippet $i',
        plainTextBody: 'Body $i',
        category: MailCategory.personal,
        isRead: true,
        receivedAt: DateTime.now().subtract(Duration(minutes: i)),
      ),
    );
    await testMessageRepo.saveMessages(messages);

    // 3. Pump AccountsScreen
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          accountRepositoryProvider.overrideWithValue(testAccountRepo),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
        ],
        child: const MaterialApp(
          home: AccountsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify mailbox details are displayed
    expect(find.text('Alex Gmail'), findsOneWidget);
    expect(find.text('alex.chen@gmail.com'), findsOneWidget);

    // Verify progress text "25 of 100 synced (25%)"
    expect(find.byKey(const ValueKey('sync_text_acc_progress_1')), findsOneWidget);
    expect(find.text('25 of 100 synced (25%)'), findsOneWidget);

    // Verify total available in mailbox "Total in mailbox: 100"
    expect(find.byKey(const ValueKey('total_text_acc_progress_1')), findsOneWidget);
    expect(find.text('Total in mailbox: 100'), findsOneWidget);

    // Verify linear progress bar is present with 0.25 value
    final progressBarFinder = find.byKey(const ValueKey('sync_progress_bar_acc_progress_1'));
    expect(progressBarFinder, findsOneWidget);
    final LinearProgressIndicator progressBar = tester.widget(progressBarFinder);
    expect(progressBar.value, equals(0.25));

    // Verify refresh / sync button is present
    expect(find.byKey(const ValueKey('sync_account_btn_acc_progress_1')), findsOneWidget);

    await testDb.close();
  });

  testWidgets('ReaderScreen displays button to show all emails from sender and opens SenderEmailsScreen on tap',
      (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());
    final testAccountRepo = AccountRepositoryImpl(testDb);
    final testMessageRepo = MessageRepositoryImpl(testDb, GoogleAuthService());

    const account = MailAccount(
      id: 'acc1',
      email: 'user@example.com',
      displayName: 'User',
      provider: MailProvider.gmail,
      avatarColorValue: 0xFF2563EB,
    );
    await testAccountRepo.saveAccount(account);

    final msg1 = MailMessage(
      id: 'msg_reader_1',
      accountId: 'acc1',
      remoteMessageId: 'remote_r1',
      senderEmail: 'newsletter@techdaily.com',
      senderName: 'Tech Daily',
      subject: 'Tech Digest #1',
      snippet: 'Top stories',
      plainTextBody: 'Full content of story 1',
      category: MailCategory.newsletters,
      isRead: true,
      receivedAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

    final msg2 = MailMessage(
      id: 'msg_reader_2',
      accountId: 'acc1',
      remoteMessageId: 'remote_r2',
      senderEmail: 'newsletter@techdaily.com',
      senderName: 'Tech Daily',
      subject: 'Tech Digest #2',
      snippet: 'Earlier stories',
      plainTextBody: 'Full content of story 2',
      category: MailCategory.newsletters,
      isRead: true,
      receivedAt: DateTime.now().subtract(const Duration(days: 1)),
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
          home: ReaderScreen(messageId: 'msg_reader_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify ReaderScreen loaded
    expect(find.text('Tech Digest #1'), findsOneWidget);

    // Verify AppBar button "All emails from this sender" is present
    final allMailsAppBarBtn = find.byKey(const ValueKey('reader_view_all_from_sender_btn'));
    expect(allMailsAppBarBtn, findsOneWidget);

    // Tap the AppBar button to open all emails from this sender
    await tester.tap(allMailsAppBarBtn);
    await tester.pumpAndSettle();

    // Verify SenderEmailsScreen is open showing all emails from newsletter@techdaily.com
    expect(find.byType(SenderEmailsScreen), findsOneWidget);
    expect(find.text('Tech Digest #1'), findsOneWidget);
    expect(find.text('Tech Digest #2'), findsOneWidget);
    expect(find.text('2 emails'), findsOneWidget);

    // Tap back button
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Verify back on ReaderScreen
    expect(find.text('Tech Digest #1'), findsOneWidget);

    // Expand sender box
    await tester.tap(find.byKey(const ValueKey('reader_sender_box')));
    await tester.pumpAndSettle();

    // Verify "All Mails from Sender" button is present in expanded card
    final senderCardAllMailsBtn = find.byKey(const ValueKey('reader_sender_all_emails_btn'));
    expect(senderCardAllMailsBtn, findsOneWidget);

    await testDb.close();
  });

  testWidgets('AccountsScreen renders continuous older email auto-sync toggle, active countdown badge, and rate limit badge',
      (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());
    final testAccountRepo = AccountRepositoryImpl(testDb);
    final testMessageRepo = MessageRepositoryImpl(testDb, GoogleAuthService());

    const account = MailAccount(
      id: 'acc_auto_sync_1',
      email: 'autosync@gmail.com',
      displayName: 'Auto Sync User',
      provider: MailProvider.gmail,
      avatarColorValue: 0xFF1E88E5,
      totalMessages: 1200,
    );
    await testAccountRepo.saveAccount(account);

    final fakeAutoSyncNotifier = _FakeAutoSyncNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          accountRepositoryProvider.overrideWithValue(testAccountRepo),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
          autoSyncNotifierProvider.overrideWith((ref) => fakeAutoSyncNotifier),
        ],
        child: const MaterialApp(
          home: AccountsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Initial State: switch is OFF, badge says '100 / 10s'
    expect(find.byKey(const ValueKey('toggle_older_sync_btn_acc_auto_sync_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('auto_sync_banner_acc_auto_sync_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('auto_sync_toggle_acc_auto_sync_1')), findsOneWidget);
    expect(find.text('Continuous Older Email Sync'), findsOneWidget);
    expect(find.text('100 / 10s'), findsOneWidget);

    final switchFinder = find.byKey(const ValueKey('auto_sync_toggle_acc_auto_sync_1'));
    final Switch initialSwitch = tester.widget(switchFinder);
    expect(initialSwitch.value, isFalse);

    // 2. Active Sync Countdown State: NEXT IN 7s
    fakeAutoSyncNotifier.setAccountState(
      'acc_auto_sync_1',
      const AccountAutoSyncState(
        isRunning: true,
        countdownSeconds: 7,
        statusMessage: 'Next sync in 7s...',
      ),
    );
    await tester.pump();

    expect(find.text('NEXT IN 7s'), findsOneWidget);
    expect(find.text('Next sync in 7s...'), findsOneWidget);
    final Switch activeSwitch = tester.widget(switchFinder);
    expect(activeSwitch.value, isTrue);

    // 3. Rate Limited State: RATE LIMITED (18s)
    fakeAutoSyncNotifier.setAccountState(
      'acc_auto_sync_1',
      const AccountAutoSyncState(
        isRunning: true,
        isRateLimited: true,
        countdownSeconds: 18,
        backoffSeconds: 20,
        statusMessage: 'Rate limit hit! Waiting 10s extra (20s total). Retrying in 18s...',
      ),
    );
    await tester.pump();

    expect(find.text('RATE LIMITED (18s)'), findsOneWidget);
    expect(find.text('Rate limit hit! Waiting 10s extra (20s total). Retrying in 18s...'), findsOneWidget);

    // 4. Tap toggle to trigger toggleAutoSync
    await tester.tap(switchFinder);
    await tester.pump();
    expect(fakeAutoSyncNotifier.toggleCallCount, equals(1));

    await testDb.close();
  });

  test('AutoSyncNotifier starts, stops, and resets account auto sync states properly', () {
    final container = ProviderContainer(
      overrides: [
        googleAuthServiceProvider.overrideWithValue(GoogleAuthService()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(autoSyncNotifierProvider.notifier);

    // Initial state is idle
    var state = notifier.getAccountState('acc_test_notifier');
    expect(state.isRunning, isFalse);
    expect(state.countdownSeconds, equals(0));

    // Stop resets state
    notifier.stopAutoSync('acc_test_notifier');
    state = notifier.getAccountState('acc_test_notifier');
    expect(state.isRunning, isFalse);
    expect(state.statusMessage, equals('Auto-sync stopped.'));
  });

  testWidgets('AccountsScreen renders View Log buttons and redirects to LogsScreen on tap',
      (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());
    final testAccountRepo = AccountRepositoryImpl(testDb);
    final testMessageRepo = MessageRepositoryImpl(testDb, GoogleAuthService());

    const account = MailAccount(
      id: 'acc_logs_view_1',
      email: 'logtest@gmail.com',
      displayName: 'Log Test Account',
      provider: MailProvider.gmail,
      avatarColorValue: 0xFF1E88E5,
      totalMessages: 500,
    );
    await testAccountRepo.saveAccount(account);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          accountRepositoryProvider.overrideWithValue(testAccountRepo),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
        ],
        child: const MaterialApp(
          home: AccountsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify View Logs buttons exist
    expect(find.byKey(const ValueKey('mailboxes_view_logs_appbar_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('mailboxes_view_logs_header_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('account_view_logs_btn_acc_logs_view_1')), findsOneWidget);

    // 2. Tap View Logs header button
    await tester.tap(find.byKey(const ValueKey('mailboxes_view_logs_header_btn')));
    await tester.pumpAndSettle();

    // 3. Verify redirected to LogsScreen
    expect(find.text('Operation Logs'), findsOneWidget);
    expect(find.text('Mails Synced'), findsOneWidget);
    expect(find.text('Logged Events'), findsOneWidget);

    // 4. Tap back button to return to AccountsScreen
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Mailboxes'), findsOneWidget);

    // 5. Tap per-account View Sync Logs link
    await tester.tap(find.byKey(const ValueKey('account_view_logs_btn_acc_logs_view_1')));
    await tester.pumpAndSettle();

    // 6. Verify redirected to LogsScreen
    expect(find.text('Operation Logs'), findsOneWidget);

    await testDb.close();
  });

  testWidgets('Page titles in Nerd/Dark theme show clean titles without full paths or trimming',
      (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());
    final testAccountRepo = AccountRepositoryImpl(testDb);
    final testMessageRepo = MessageRepositoryImpl(testDb, GoogleAuthService());

    // 1. SettingsScreen in Nerd theme
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          themeModeProvider.overrideWith((ref) => _FakeThemeModeNotifier(AppThemeMode.nerd)),
          databaseProvider.overrideWithValue(testDb),
          accountRepositoryProvider.overrideWithValue(testAccountRepo),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.nerdTheme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('> /etc/cleanmail/config'), findsNothing);

    // 2. LogsScreen in Nerd theme
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          themeModeProvider.overrideWith((ref) => _FakeThemeModeNotifier(AppThemeMode.nerd)),
          databaseProvider.overrideWithValue(testDb),
        ],
        child: MaterialApp(
          theme: AppTheme.nerdTheme,
          home: const LogsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operation Logs'), findsOneWidget);
    expect(find.text('> /var/log/cleanmail.log'), findsNothing);

    // 3. DashboardScreen in Nerd theme
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          themeModeProvider.overrideWith((ref) => _FakeThemeModeNotifier(AppThemeMode.nerd)),
          databaseProvider.overrideWithValue(testDb),
          accountRepositoryProvider.overrideWithValue(testAccountRepo),
          messageRepositoryProvider.overrideWithValue(testMessageRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.nerdTheme,
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('> METRICS & ANALYTICS DASHBOARD'), findsNothing);

    await testDb.close();
  });
}

class _FakeThemeModeNotifier extends ThemeModeNotifier {
  _FakeThemeModeNotifier(AppThemeMode initialMode) {
    state = initialMode;
  }
}

class _FakeAutoSyncNotifier extends AutoSyncNotifier {
  int toggleCallCount = 0;

  _FakeAutoSyncNotifier() : super(_FakeRef());

  void setAccountState(String accountId, AccountAutoSyncState accountState) {
    state = {...state, accountId: accountState};
  }

  @override
  void toggleAutoSync(MailAccount account) {
    toggleCallCount++;
  }
}

class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
