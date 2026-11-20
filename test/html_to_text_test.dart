import 'package:flutter_test/flutter_test.dart';
import 'package:cleanmail/core/utils/html_to_text.dart';

void main() {
  group('HtmlToTextConverter Tests', () {
    test('converts basic paragraphs and breaks', () {
      const html = '<p>Hello world!</p><p>This is a second paragraph.</p>';
      final result = HtmlToTextConverter.convert(html);
      expect(result, contains('Hello world!'));
      expect(result, contains('This is a second paragraph.'));
    });

    test('strips styles and script tags completely', () {
      const html = '''
        <style>body { background-color: red; }</style>
        <script>console.log("malicious code");</script>
        <div>Legitimate email body here.</div>
      ''';
      final result = HtmlToTextConverter.convert(html);
      expect(result, equals('Legitimate email body here.'));
      expect(result, isNot(contains('background-color')));
      expect(result, isNot(contains('console.log')));
    });

    test('detects and eliminates 1x1 tracking pixels', () {
      const html = '''
        <p>Your subscription is active.</p>
        <img src="https://tracker.com/pixel.gif" width="1" height="1" alt="tracker" />
        <img src="https://tracker.com/open.aspx?id=123" style="display:none;" />
      ''';
      final result = HtmlToTextConverter.convert(html);
      expect(result, equals('Your subscription is active.'));
      expect(result, isNot(contains('tracker')));
      expect(result, isNot(contains('pixel.gif')));
    });

    test('formats links cleanly', () {
      const html = '<p>Click <a href="https://example.com/login">here to login</a> now.</p>';
      final result = HtmlToTextConverter.convert(html);
      expect(result, contains('here to login (https://example.com/login)'));
    });

    test('formats unordered list items', () {
      const html = '''
        <ul>
          <li>First item</li>
          <li>Second item</li>
        </ul>
      ''';
      final result = HtmlToTextConverter.convert(html);
      expect(result, contains('• First item'));
      expect(result, contains('• Second item'));
    });
  });
}
