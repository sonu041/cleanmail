import 'package:uuid/uuid.dart';
import '../../domain/models/account.dart';
import '../../domain/models/category.dart';
import '../../domain/models/message.dart';
import '../repositories/account_repository_impl.dart';
import '../repositories/message_repository_impl.dart';

class SampleDataSeeder {
  static const _uuid = Uuid();

  static Future<void> seedIfEmpty({
    required AccountRepositoryImpl accountRepo,
    required MessageRepositoryImpl messageRepo,
  }) async {
    final existingAccounts = await accountRepo.getAccounts();
    if (existingAccounts.isNotEmpty) {
      return; // Already seeded or user has accounts
    }

    // 1. Create two realistic accounts (Gmail & Outlook)
    final personalAccount = MailAccount(
      id: 'acc_personal_gmail',
      email: 'alex.dev@gmail.com',
      displayName: 'Alex (Personal)',
      provider: MailProvider.gmail,
      avatarColorValue: 0xFF1E88E5, // Clean Blue
      lastSyncedAt: DateTime.now(),
    );

    final workAccount = MailAccount(
      id: 'acc_work_outlook',
      email: 'alex.chen@innovatecorp.com',
      displayName: 'Alex (Work)',
      provider: MailProvider.outlook,
      avatarColorValue: 0xFF8E24AA, // Clean Purple
      lastSyncedAt: DateTime.now(),
    );

    await accountRepo.saveAccount(personalAccount);
    await accountRepo.saveAccount(workAccount);

    // 2. Create diverse realistic sample emails across categories and senders
    final now = DateTime.now();

    final sampleMessages = [
      // --- NEWSLETTERS (With Unsubscribe options & multiple emails for Sender Sweep) ---
      MailMessage(
        id: _uuid.v4(),
        accountId: personalAccount.id,
        remoteMessageId: 'msg_001',
        senderEmail: 'digest@tldr.tech',
        senderName: 'TLDR Tech',
        subject: 'TLDR Tech: The AI chip race intensifies & Flutter 3.50 updates',
        snippet: 'Today\'s top stories: Massive LLM efficiency breakthroughs, new open-source models...',
        plainTextBody: '''TLDR TECH — NOVEMBER 2026

1. BIG TECH & HARDWARE
The next-generation neural architecture shows 4x inference efficiency compared to last year's flagship. Major cloud providers are immediately adopting the new hardware spec.

2. SOFTWARE ENGINEERING
Flutter 3.50 introduces substantial Impeller rendering engine speedups across desktop and mobile platforms, bringing smoother scroll performance and tighter multi-window support.

3. DEV PICKS & ARTICLES
• Deep dive into SQLite query planning and index optimization (https://sqlite.org/queryplanner.html)
• Why text-only interfaces are making a quiet comeback among developers (https://example.com/text-revival)

To unsubscribe from future digests:
Use the 1-tap unsubscribe button above or visit: https://tldr.tech/unsubscribe?id=alex99''',
        category: MailCategory.newsletters,
        unsubscribeUrl: 'https://tldr.tech/unsubscribe?id=alex99',
        isRead: false,
        receivedAt: now.subtract(const Duration(minutes: 18)),
      ),

      MailMessage(
        id: _uuid.v4(),
        accountId: personalAccount.id,
        remoteMessageId: 'msg_002',
        senderEmail: 'digest@tldr.tech',
        senderName: 'TLDR Tech',
        subject: 'TLDR Tech: Breakthroughs in edge computing',
        snippet: 'Yesterday\'s roundup: Low-power edge neural engines and offline data caching strategies...',
        plainTextBody: '''TLDR TECH — YESTERDAY ROUNDUP

• Edge computing frameworks now run quantized weights in under 50MB of RAM.
• Offline-first mobile apps see 70% higher user retention during low-bandwidth transit.

Read more at https://tldr.tech/archive/2026-11-19''',
        category: MailCategory.newsletters,
        unsubscribeUrl: 'https://tldr.tech/unsubscribe?id=alex99',
        isRead: true,
        receivedAt: now.subtract(const Duration(hours: 26)),
      ),

      MailMessage(
        id: _uuid.v4(),
        accountId: personalAccount.id,
        remoteMessageId: 'msg_003',
        senderEmail: 'newsletter@bytes.dev',
        senderName: 'Bytes by Tyler',
        subject: 'Bytes #312: The death of unnecessary JavaScript webviews',
        snippet: 'Why native lightweight clients always win over bloated wrappers. Plus: weekly quiz...',
        plainTextBody: '''Hey Alex,

Today we are talking about UI weight. Did you know that the average HTML email now triggers over 45 HTTP requests just for hidden analytics, tracking pixels, and remote font families?

Stripping that down to pure semantic text:
1. Saves mobile data
2. Preserves battery life
3. Respects reader privacy 100%

Have a great weekend,
Tyler

Unsubscribe: https://bytes.dev/unsub?user=alex''',
        category: MailCategory.newsletters,
        unsubscribeUrl: 'https://bytes.dev/unsub?user=alex',
        isRead: false,
        receivedAt: now.subtract(const Duration(hours: 3)),
      ),

      MailMessage(
        id: _uuid.v4(),
        accountId: personalAccount.id,
        remoteMessageId: 'msg_004',
        senderEmail: 'promo@shopdeals.com',
        senderName: 'ShopDeals Daily',
        subject: 'Mega Weekend Flash Sale: 40% off electronics',
        snippet: 'Exclusive discount code inside. Valid for the next 48 hours only on select devices...',
        plainTextBody: '''SHOPDEALS WEEKEND FLASH SALE

Save up to 40% on mechanical keyboards, ergonomic monitors, and noise-canceling headphones.

Use code: CLEAN40 at checkout.
Offer ends Sunday midnight.

Unsubscribe: https://shopdeals.com/optout''',
        category: MailCategory.newsletters,
        unsubscribeUrl: 'https://shopdeals.com/optout',
        isRead: false,
        receivedAt: now.subtract(const Duration(hours: 5)),
      ),

      MailMessage(
        id: _uuid.v4(),
        accountId: personalAccount.id,
        remoteMessageId: 'msg_005',
        senderEmail: 'promo@shopdeals.com',
        senderName: 'ShopDeals Daily',
        subject: 'Reminder: Your cart items are selling out fast',
        snippet: 'Items in your saved list are almost out of stock. Complete your order today...',
        plainTextBody: '''Hi Alex,

You left a USB-C Hub in your cart. Only 3 units remain in stock!

Return to cart: https://shopdeals.com/cart''',
        category: MailCategory.newsletters,
        unsubscribeUrl: 'https://shopdeals.com/optout',
        isRead: true,
        receivedAt: now.subtract(const Duration(days: 2)),
      ),

      // --- TRANSACTIONS (Receipts, Invoices, Billing) ---
      MailMessage(
        id: _uuid.v4(),
        accountId: personalAccount.id,
        remoteMessageId: 'msg_006',
        senderEmail: 'receipts@uber.com',
        senderName: 'Uber Receipts',
        subject: 'Your Thursday evening trip with Uber',
        snippet: 'Total: \$18.45. Thanks for riding with Uber. View your breakdown and driver rating...',
        plainTextBody: '''UBER TRIP RECEIPT

Date: November 19, 2026
Trip: Downtown Office -> 4th Avenue
Driver: Michael (Toyota Camry)

Fare Breakdown:
• Base Fare: \$3.50
• Distance & Time: \$12.10
• Taxes & Fees: \$2.85
--------------------------------
TOTAL CHARGED: \$18.45
Payment Method: Apple Pay (Visa ending in 4112)

Need help with this trip? Contact support at https://help.uber.com''',
        category: MailCategory.transactions,
        isRead: true,
        receivedAt: now.subtract(const Duration(hours: 14)),
      ),

      MailMessage(
        id: _uuid.v4(),
        accountId: workAccount.id,
        remoteMessageId: 'msg_007',
        senderEmail: 'billing@github.com',
        senderName: 'GitHub Billing',
        subject: 'Payment Confirmation: GitHub Team Subscription',
        snippet: 'Receipt #INV-2026-8819 for InnovateCorp. Amount paid: \$84.00. Thank you for your business...',
        plainTextBody: '''GITHUB PAYMENT RECEIPT

Invoice Number: INV-2026-8819
Organization: InnovateCorp
Plan: GitHub Team (12 seats)
Billing Period: Nov 20, 2026 - Dec 20, 2026

Amount Charged: \$84.00 USD
Card: Mastercard ending in 9021

Download full PDF tax invoice: https://github.com/organizations/InnovateCorp/billing''',
        category: MailCategory.transactions,
        isRead: false,
        receivedAt: now.subtract(const Duration(hours: 7)),
      ),

      // --- PERSONAL (Direct communications) ---
      MailMessage(
        id: _uuid.v4(),
        accountId: workAccount.id,
        remoteMessageId: 'msg_008',
        senderEmail: 'sarah.miller@innovatecorp.com',
        senderName: 'Sarah Miller',
        subject: 'Architecture review for the new caching layer',
        snippet: 'Hey Alex, I looked over the SQLite / Drift schema RFC. Have a quick question about migrations...',
        plainTextBody: '''Hey Alex,

I went through your RFC for the local cache synchronization. The approach to use SQLite with Drift reactive queries looks very solid.

One question: for background sweeps, are we running the vacuum command periodically or relying on auto_vacuum?

Let's do a 15-minute sync tomorrow morning if you have time.

Best,
Sarah''',
        category: MailCategory.personal,
        isRead: false,
        isStarred: true,
        receivedAt: now.subtract(const Duration(minutes: 42)),
      ),

      MailMessage(
        id: _uuid.v4(),
        accountId: personalAccount.id,
        remoteMessageId: 'msg_009',
        senderEmail: 'marcus.dev@gmail.com',
        senderName: 'Marcus Vance',
        subject: 'Coffee catch-up next Tuesday?',
        snippet: 'Long time no see! Are you free around 10am next Tuesday near the downtown market?',
        plainTextBody: '''Hey Alex,

Hope everything is going well with you!

I'm going to be in your neighborhood next Tuesday for a client meeting. Let me know if you are free for coffee around 10:00 AM. 

Let me know!
Marcus''',
        category: MailCategory.personal,
        isRead: true,
        isStarred: true,
        receivedAt: now.subtract(const Duration(days: 1)),
      ),

      // --- UPDATES (Notifications, Security Alerts) ---
      MailMessage(
        id: _uuid.v4(),
        accountId: workAccount.id,
        remoteMessageId: 'msg_010',
        senderEmail: 'notifications@github.com',
        senderName: 'GitHub Notifications',
        subject: '[InnovateCorp/cleanmail] PR #44 merged: "Optimize text sanitizer"',
        snippet: 'Merged by @sarahmiller into main: 4 commits, 12 files changed (+184, -42)...',
        plainTextBody: '''PR #44: Optimize text sanitizer and eliminate tracking pixels
Status: MERGED by sarahmiller into main

Review comments:
• "Clean regex and traversal logic, tests pass cleanly on mobile and desktop."

View pull request: https://github.com/InnovateCorp/cleanmail/pull/44''',
        category: MailCategory.updates,
        isRead: true,
        receivedAt: now.subtract(const Duration(hours: 4)),
      ),
    ];

    await messageRepo.saveMessages(sampleMessages);
  }
}
