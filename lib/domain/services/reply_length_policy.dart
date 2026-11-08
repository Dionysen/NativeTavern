/// Reply length constraints: prompt hint + post-generation check helpers.
///
/// Character count ignores whitespace so Chinese “字数” matches user expectation.
abstract final class ReplyLengthPolicy {
  static const maxExpandAttempts = 2;

  /// Non-whitespace character count.
  static int countChars(String text) {
    if (text.isEmpty) return 0;
    return text.replaceAll(RegExp(r'\s+'), '').length;
  }

  static bool isEnabled({required int minChars, required int maxChars}) =>
      minChars > 0 || maxChars > 0;

  /// Normalized pair: zeros mean “no limit”; min never exceeds max when both set.
  static ({int minChars, int maxChars}) normalize({
    required int minChars,
    required int maxChars,
  }) {
    var min = minChars < 0 ? 0 : minChars;
    var max = maxChars < 0 ? 0 : maxChars;
    if (min > 0 && max > 0 && min > max) {
      final tmp = min;
      min = max;
      max = tmp;
    }
    return (minChars: min, maxChars: max);
  }

  /// Soft instruction injected into the model context.
  static String? promptHint({required int minChars, required int maxChars}) {
    final bounds = normalize(minChars: minChars, maxChars: maxChars);
    if (!isEnabled(minChars: bounds.minChars, maxChars: bounds.maxChars)) {
      return null;
    }

    final buffer = StringBuffer(
      '[Reply length constraint]\n'
      'Write the next assistant reply so its visible body text (excluding '
      'thinking/reasoning) stays within the required character count. '
      'Count every non-whitespace character (Chinese characters, letters, '
      'digits, and punctuation).\n',
    );
    if (bounds.minChars > 0 && bounds.maxChars > 0) {
      buffer.write(
        'Required length: between ${bounds.minChars} and ${bounds.maxChars} '
        'characters.',
      );
    } else if (bounds.minChars > 0) {
      buffer.write(
        'Required length: at least ${bounds.minChars} characters.',
      );
    } else {
      buffer.write(
        'Required length: at most ${bounds.maxChars} characters.',
      );
    }
    return buffer.toString();
  }

  /// Instruction used when expanding a too-short reply.
  static String expandInstruction({
    required int currentChars,
    required int minChars,
    int maxChars = 0,
  }) {
    final maxClause = maxChars > 0
        ? ' Keep the complete reply at or below $maxChars characters.'
        : '';
    return '[Reply length repair]\n'
        'The previous assistant reply is only $currentChars characters, but it '
        'must be at least $minChars characters.$maxClause '
        'Rewrite the COMPLETE reply (not a short continuation only) so it '
        'meets the length requirement while staying in character and keeping '
        'the same plot direction. Output only the revised reply.';
  }

  /// Prefer cutting at a sentence/line boundary near [maxChars].
  static String truncateToMax(String text, int maxChars) {
    if (maxChars <= 0 || countChars(text) <= maxChars) return text;

    final units = text.runes.toList(growable: false);
    final buffer = StringBuffer();
    var counted = 0;
    var lastBreak = -1;
    var lastBreakCounted = 0;

    for (var i = 0; i < units.length; i++) {
      final ch = String.fromCharCode(units[i]);
      final isSpace = ch.trim().isEmpty;
      if (!isSpace) {
        if (counted >= maxChars) break;
        counted++;
      }
      buffer.write(ch);
      if (_isSoftBreak(ch)) {
        lastBreak = buffer.length;
        lastBreakCounted = counted;
      }
    }

    var truncated = buffer.toString();
    // Backtrack to a nearby break if we still kept most of the budget.
    if (lastBreak > 0 && lastBreakCounted >= (maxChars * 0.7).floor()) {
      truncated = truncated.substring(0, lastBreak).trimRight();
    } else {
      truncated = truncated.trimRight();
    }
    return truncated;
  }

  /// Rough token budget from a character cap (CJK-heavy replies).
  static int estimateMaxTokens(int maxChars, {required int currentMaxTokens}) {
    if (maxChars <= 0) return currentMaxTokens;
    final estimated = (maxChars * 2).clamp(128, currentMaxTokens);
    return estimated;
  }

  static bool _isSoftBreak(String ch) =>
      ch == '\n' ||
      ch == '。' ||
      ch == '！' ||
      ch == '？' ||
      ch == '；' ||
      ch == '.' ||
      ch == '!' ||
      ch == '?' ||
      ch == ';';
}
