import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Renders fenced/indented code blocks with soft wrapping.
///
/// [flutter_markdown] defaults to a horizontal [SingleChildScrollView] for
/// `pre` nodes; this builder replaces that path so long lines wrap instead.
class WrappingCodeBlockBuilder extends MarkdownElementBuilder {
  WrappingCodeBlockBuilder({
    required this.codeStyle,
    this.padding = const EdgeInsets.all(12),
  });

  final TextStyle codeStyle;
  final EdgeInsets padding;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    // Match flutter_markdown's formatText: drop a trailing newline only.
    final code = text.text.replaceAll(RegExp(r'\n$'), '');
    return Padding(
      padding: padding,
      child: Text.rich(
        TextSpan(
          style: codeStyle,
          text: code,
        ),
        softWrap: true,
      ),
    );
  }
}
