import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Renders fenced/indented code blocks with soft wrapping.
///
/// [flutter_markdown] defaults to a horizontal [SingleChildScrollView] for
/// `pre` nodes; this builder replaces that path so long lines wrap instead.
///
/// Uses an explicit [StrutStyle] so CJK text under `monospace` (which falls
/// back to a different font) cannot inflate the line gap.
///
/// Blank lines inside the fence are real line breaks in one text node, so
/// Markdown [blockSpacing] never applies. [paragraphSpacing] is added on top
/// of the normal empty-line box so the Markdown/HTML paragraph setting works.
class WrappingCodeBlockBuilder extends MarkdownElementBuilder {
  WrappingCodeBlockBuilder({
    required this.codeStyle,
    this.padding = const EdgeInsets.all(12),
    this.lineHeight = 1.35,
    this.paragraphSpacing = 0,
  });

  final TextStyle codeStyle;
  final EdgeInsets padding;
  final double lineHeight;
  final double paragraphSpacing;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    // Match flutter_markdown's formatText: drop a trailing newline only.
    final code = text.text.replaceAll(RegExp(r'\n$'), '');
    // Block chrome paints the fill; drop per-glyph backgroundColor so it
    // cannot add uneven gaps between wrapped lines.
    final style = codeStyle.copyWith(
      height: lineHeight,
      backgroundColor: null,
    );
    final fontSize = style.fontSize ?? 14;
    final strut = StrutStyle(
      fontSize: fontSize,
      height: lineHeight,
      forceStrutHeight: true,
      fontFamily: style.fontFamily,
    );
    final lines = code.split('\n');
    final children = <Widget>[
      for (final line in lines)
        if (line.isEmpty)
          SizedBox(height: fontSize * lineHeight + paragraphSpacing)
        else
          Text(
            line,
            style: style,
            softWrap: true,
            strutStyle: strut,
          ),
    ];

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
