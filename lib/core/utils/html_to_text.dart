import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

/// Robust utility to convert arbitrary email HTML into clean, readable,
/// distraction-free plain text.
///
/// Strips scripts, styles, embedded forms, tracking pixels (1x1), and
/// normalizes whitespace, headings, lists, and links.
class HtmlToTextConverter {
  const HtmlToTextConverter._();

  static const Set<String> _ignoredTags = {
    'head',
    'style',
    'script',
    'svg',
    'canvas',
    'iframe',
    'noscript',
    'link',
    'meta',
    'object',
    'embed',
  };

  /// Main entry point to convert an HTML or plain text string into clean text.
  static String convert(String? rawHtml) {
    if (rawHtml == null || rawHtml.trim().isEmpty) {
      return '';
    }

    // If it does not contain any HTML tags, return normalized plain text directly.
    if (!rawHtml.contains('<') || !rawHtml.contains('>')) {
      return _normalizeWhitespace(rawHtml);
    }

    try {
      final document = html_parser.parse(rawHtml);
      final body = document.body ?? document.documentElement;
      if (body == null) return _normalizeWhitespace(rawHtml);

      final buffer = StringBuffer();
      _traverseNode(body, buffer);

      return _normalizeWhitespace(buffer.toString());
    } catch (_) {
      // Fallback: strip tags via regex if DOM parsing encounters unexpected error
      final stripped = rawHtml
          .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'");
      return _normalizeWhitespace(stripped);
    }
  }

  static void _traverseNode(dom.Node node, StringBuffer buffer) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.isNotEmpty) {
        buffer.write(text);
      }
      return;
    }

    if (node is dom.Element) {
      final tagName = node.localName?.toLowerCase() ?? '';

      // Skip non-visible or script/style tags
      if (_ignoredTags.contains(tagName)) {
        return;
      }

      // Detect and eliminate tracking pixels
      if (tagName == 'img') {
        if (_isTrackingPixel(node)) {
          return;
        }
        final alt = node.attributes['alt']?.trim();
        if (alt != null && alt.isNotEmpty) {
          buffer.write(' [$alt] ');
        }
        return;
      }

      // Handle hyperlinks
      if (tagName == 'a') {
        final href = node.attributes['href']?.trim();
        final anchorText = node.text.trim();

        if (href != null && href.isNotEmpty) {
          if (anchorText.isEmpty || anchorText.toLowerCase() == href.toLowerCase()) {
            buffer.write(' $href ');
          } else {
            // Display anchor text with link reference
            buffer.write(' $anchorText ($href) ');
          }
          return;
        }
      }

      // Block-level element pre-newlines
      final isBlock = _isBlockElement(tagName);
      if (isBlock) {
        buffer.write('\n');
      }

      if (tagName == 'li') {
        buffer.write('• ');
      }

      for (final child in node.nodes) {
        _traverseNode(child, buffer);
      }

      // Block-level element post-newlines
      if (isBlock) {
        buffer.write('\n');
      } else if (tagName == 'br') {
        buffer.write('\n');
      }
    }
  }

  static bool _isBlockElement(String tag) {
    switch (tag) {
      case 'p':
      case 'div':
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
      case 'ul':
      case 'ol':
      case 'li':
      case 'table':
      case 'tr':
      case 'blockquote':
      case 'section':
      case 'header':
      case 'footer':
      case 'article':
        return true;
      default:
        return false;
    }
  }

  static bool _isTrackingPixel(dom.Element img) {
    final width = img.attributes['width']?.trim();
    final height = img.attributes['height']?.trim();
    final style = img.attributes['style']?.toLowerCase() ?? '';
    final src = img.attributes['src']?.toLowerCase() ?? '';

    // Check dimensions (1x1, 0x0)
    if (width == '1' || width == '0' || height == '1' || height == '0') {
      return true;
    }

    // Check inline style visibility
    if (style.contains('display:none') ||
        style.contains('display: none') ||
        style.contains('visibility:hidden') ||
        style.contains('visibility: hidden') ||
        style.contains('width:1px') ||
        style.contains('width: 1px')) {
      return true;
    }

    // Check common pixel filenames
    if (src.contains('open.aspx') ||
        src.contains('/track') ||
        src.contains('pixel.gif') ||
        src.contains('1x1.gif')) {
      return true;
    }

    return false;
  }

  static String _normalizeWhitespace(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        // Replace non-breaking spaces with standard space
        .replaceAll('\u00A0', ' ')
        // Replace multiple horizontal spaces with single space
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        // Strip trailing spaces on lines
        .replaceAll(RegExp(r' +\n'), '\n')
        // Strip leading spaces on lines
        .replaceAll(RegExp(r'\n +'), '\n')
        // Collapse 3 or more newlines to at most 2
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
