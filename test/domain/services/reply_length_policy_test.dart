import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/domain/services/reply_length_policy.dart';

void main() {
  group('ReplyLengthPolicy', () {
    test('counts non-whitespace characters', () {
      expect(ReplyLengthPolicy.countChars('你好 世界'), 4);
      expect(ReplyLengthPolicy.countChars('a\nb c'), 3);
    });

    test('promptHint is null when both bounds are off', () {
      expect(
        ReplyLengthPolicy.promptHint(minChars: 0, maxChars: 0),
        isNull,
      );
    });

    test('promptHint mentions both bounds when set', () {
      final hint = ReplyLengthPolicy.promptHint(minChars: 100, maxChars: 500);
      expect(hint, isNotNull);
      expect(hint!, contains('100'));
      expect(hint, contains('500'));
    });

    test('truncateToMax prefers sentence boundary', () {
      final text = '第一句。第二句太长了还会继续写下去直到超过限制。';
      final truncated = ReplyLengthPolicy.truncateToMax(text, 4);
      expect(ReplyLengthPolicy.countChars(truncated), lessThanOrEqualTo(4));
      expect(truncated, contains('第一句'));
    });

    test('normalize swaps inverted bounds', () {
      final bounds =
          ReplyLengthPolicy.normalize(minChars: 800, maxChars: 200);
      expect(bounds.minChars, 200);
      expect(bounds.maxChars, 800);
    });
  });
}
