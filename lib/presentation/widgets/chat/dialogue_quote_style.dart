import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Matches spoken dialogue wrapped in common quotation marks.
///
/// Supports ASCII `"..."`, curly `“...”`, and CJK `「...」`.
final RegExp dialogueQuotePattern = RegExp(
  r'"([^"\n]{1,800})"'
  r'|“([^”\n]{1,800})”'
  r'|「([^」\n]{1,800})」',
);

/// Theme-aware color for quoted dialogue inside chat bubbles.
///
/// Prefer [ZephyrChatChrome.dialogueTextColor]; this helper remains for
/// call sites that only have a [ColorScheme].
Color dialogueQuoteColor(ColorScheme scheme, {required bool isUser}) {
  if (isUser) {
    return Color.lerp(scheme.onPrimaryContainer, scheme.tertiary, 0.55)!;
  }
  return scheme.tertiary;
}

/// Markdown inline syntax that tags quoted dialogue for custom styling.
class DialogueQuoteSyntax extends md.InlineSyntax {
  DialogueQuoteSyntax() : super(dialogueQuotePattern.pattern);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('dialogue', match[0]!));
    return true;
  }
}

/// Renders [DialogueQuoteSyntax] nodes with [style].
class DialogueQuoteBuilder extends MarkdownElementBuilder {
  DialogueQuoteBuilder(this.style);

  final TextStyle style;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // Must use Text.rich so textSpan is non-null. flutter_markdown's
    // _mergeInlineChildren does `last.textSpan!` when combining adjacent
    // inline widgets; Text(data) leaves textSpan null and crashes.
    return Text.rich(
      TextSpan(
        text: element.textContent,
        style: (preferredStyle ?? const TextStyle()).merge(style),
      ),
    );
  }
}

/// Wraps quoted dialogue in text nodes with `<span class="nt-dialogue">`.
///
/// Tag interiors are left untouched so attributes like `href="..."` stay valid.
String wrapDialogueQuotesInHtml(String html) {
  if (!dialogueQuotePattern.hasMatch(html)) return html;

  final buffer = StringBuffer();
  final tagOrText = RegExp(r'<[^>]+>|[^<]+');
  for (final match in tagOrText.allMatches(html)) {
    final part = match.group(0)!;
    if (part.startsWith('<')) {
      buffer.write(part);
      continue;
    }
    buffer.write(
      part.replaceAllMapped(
        dialogueQuotePattern,
        (m) => '<span class="nt-dialogue">${m[0]}</span>',
      ),
    );
  }
  return buffer.toString();
}
