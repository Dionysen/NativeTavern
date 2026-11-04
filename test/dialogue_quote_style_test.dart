import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/presentation/widgets/chat/dialogue_quote_style.dart';

void main() {
  group('dialogueQuotePattern', () {
    test('matches ascii curly and cjk quotes', () {
      expect(dialogueQuotePattern.hasMatch('She said "hello" softly.'), isTrue);
      expect(dialogueQuotePattern.hasMatch('他说：“你好”'), isTrue);
      expect(dialogueQuotePattern.hasMatch('她说「晚上好」'), isTrue);
      expect(dialogueQuotePattern.hasMatch('No quotes here'), isFalse);
    });
  });

  group('wrapDialogueQuotesInHtml', () {
    test('wraps quotes in text nodes only', () {
      final html = wrapDialogueQuotesInHtml(
        '<p>She smiled. "Hello!"</p><a href="https://example.com">link</a>',
      );
      expect(html, contains('<span class="nt-dialogue">"Hello!"</span>'));
      expect(html, contains('href="https://example.com"'));
      expect(html, isNot(contains('nt-dialogue">https://')));
    });
  });

  group('dialogueQuoteColor', () {
    test('returns theme-derived colors', () {
      const scheme = ColorScheme.dark();
      expect(
        dialogueQuoteColor(scheme, isUser: false),
        scheme.tertiary,
      );
      expect(
        dialogueQuoteColor(scheme, isUser: true),
        isNot(scheme.onPrimaryContainer),
      );
    });
  });
}
