import 'package:flutter_test/flutter_test.dart';
import 'package:cleanmail/core/constants/app_constants.dart';
import 'package:cleanmail/domain/models/category.dart';
import 'package:cleanmail/core/utils/heuristic_classifier.dart';

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
}
