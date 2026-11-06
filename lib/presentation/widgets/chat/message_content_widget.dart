import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';
import 'package:native_tavern/presentation/theme/zephyr_chat_chrome.dart';
import 'package:native_tavern/presentation/widgets/chat/dialogue_quote_style.dart';
import 'package:native_tavern/presentation/widgets/chat/html_webview_widget.dart';
import 'package:native_tavern/presentation/widgets/chat/wrapping_code_block_builder.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';

/// Widget that renders message content with support for Markdown
///
/// This widget renders content using Markdown renderer. For complex HTML content
/// (with flexbox, grid, shadows, etc.), it uses WebView for full CSS support.
/// Simple HTML tags are converted to Markdown equivalents.
/// - Markdown: bold, italic, strikethrough, code blocks, lists, links, etc.
/// - Complex HTML: rendered via WebView for full CSS support
/// - Touch: long-press opens [onLongPress] (message menu); double-tap arms
///   text selection. Desktop: drag-select + secondary-click menu.
class MessageContentWidget extends ConsumerStatefulWidget {
  final String content;
  final Color textColor;
  final bool selectable;
  final double? fontSize;
  final VoidCallback? onCopy;
  final void Function(String)? onCopySelection;
  final VoidCallback? onLongPress;
  /// Notifies parents when touch selection mode is armed/disarmed so outer
  /// long-press handlers can step aside.
  final ValueChanged<bool>? onSelectionModeChanged;
  /// Whether the message is currently being streamed (AI is still generating)
  /// When true, WebView will not be used even for complex HTML to avoid rendering issues
  final bool isStreaming;
  /// Optional message ID for tracking content changes and forcing re-renders
  final String? messageId;
  /// When true, quoted dialogue uses [ZephyrChatChrome.dialogueTextColor] for
  /// user bubbles; otherwise assistant styling is used.
  final bool isUser;

  const MessageContentWidget({
    super.key,
    required this.content,
    required this.textColor,
    this.selectable = true,
    this.fontSize,
    this.onCopy,
    this.onCopySelection,
    this.onLongPress,
    this.onSelectionModeChanged,
    this.isStreaming = false,
    this.messageId,
    this.isUser = false,
  });

  @override
  ConsumerState<MessageContentWidget> createState() =>
      _MessageContentWidgetState();
}

class _MessageContentWidgetState extends ConsumerState<MessageContentWidget> {
  String? _selectedText;
  /// Content key for forcing WebView re-render after streaming ends
  int _contentVersion = 0;

  /// Touch-only: SelectionArea is mounted after a double-tap so long-press can
  /// open the message menu instead of starting a text selection.
  bool _selectionArmed = false;

  /// Cached subtree: during streaming every chunk rebuilds all visible
  /// bubbles; returning an identical widget instance for unchanged content
  /// lets Flutter skip re-parsing markdown/HTML for those bubbles
  Widget? _cachedWidget;
  String? _cachedContent;
  bool? _cachedStreaming;
  Color? _cachedColor;
  bool? _cachedIsUser;
  int? _cachedVersion;
  Brightness? _cachedBrightness;
  bool? _cachedRenderHtml;
  bool? _cachedNeutralizeHtml;
  bool? _cachedSelectionArmed;

  bool get _isTouchPrimary {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return true;
      default:
        return false;
    }
  }

  /// Whether SelectionArea should be active for this build.
  bool get _selectionEnabled {
    if (!widget.selectable) return false;
    if (!_isTouchPrimary) return true;
    return _selectionArmed;
  }

  void _setSelectionArmed(bool armed) {
    if (_selectionArmed == armed) return;
    setState(() {
      _selectionArmed = armed;
      if (!armed) _selectedText = null;
    });
    widget.onSelectionModeChanged?.call(armed);
  }

  @override
  void didUpdateWidget(MessageContentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Detect when streaming ends - this is the key moment to re-render
    if (oldWidget.isStreaming && !widget.isStreaming) {
      // Streaming just ended, increment content version to force WebView reload
      setState(() {
        _contentVersion++;
      });
    }
  }

  /// Check if content contains HTML tags
  bool _containsHtml(String text) {
    // Common HTML tags used in SillyTavern
    final htmlPattern = RegExp(
      r'<\s*(b|i|u|s|em|strong|br|p|div|span|a|ul|ol|li|h[1-6]|blockquote|pre|code|hr|img|table|tr|td|th|font|center|sub|sup|mark|del|ins|small|big|q|cite|abbr|details|summary)(\s|>|/>)',
      caseSensitive: false,
    );
    return htmlPattern.hasMatch(text);
  }

  /// Theme-matching fill for HTML WebViews. Avoids a pure-white WebView plate
  /// on dark themes when the native surface cannot paint transparent.
  Color _htmlSurfaceColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chat = context.appChatColors;
    final base =
        widget.isUser ? chat.userBubble : chat.characterBubble;
    final dark = scheme.brightness == Brightness.dark;
    final luminance = base.computeLuminance();
    if (dark && luminance > 0.55) {
      return scheme.surfaceContainerHigh;
    }
    if (!dark && luminance < 0.2) {
      return scheme.surfaceContainerHigh;
    }
    return base;
  }

  /// Check if content contains Markdown syntax
  bool _containsMarkdown(String text) {
    // Simple check: if text contains any common Markdown markers, use Markdown renderer
    // The Markdown renderer will handle the actual parsing
    
    // Check for bold/italic markers
    if (text.contains('**') || text.contains('__')) return true;
    if (text.contains('~~')) return true; // Strikethrough
    if (text.contains('`')) return true; // Code
    
    // Check for single asterisk italic: *text* (but not * alone or **)
    // Match pattern: space or start, *, non-space, content, non-space, *, space or end
    if (RegExp(r'(?:^|[\s\(])\*[^\s*].*?[^\s*]\*(?:[\s\)\.,!?]|$)').hasMatch(text)) return true;
    // Also match short italic like *a*
    if (RegExp(r'(?:^|[\s\(])\*[^\s*]\*(?:[\s\)\.,!?]|$)').hasMatch(text)) return true;
    
    // Check for single underscore italic: _text_
    if (RegExp(r'(?:^|[\s\(])_[^\s_].*?[^\s_]_(?:[\s\)\.,!?]|$)').hasMatch(text)) return true;
    if (RegExp(r'(?:^|[\s\(])_[^\s_]_(?:[\s\)\.,!?]|$)').hasMatch(text)) return true;
    
    // Check for headers
    if (RegExp(r'^#{1,6}\s', multiLine: true).hasMatch(text)) return true;
    
    // Check for lists
    if (RegExp(r'^\s*[-*+]\s', multiLine: true).hasMatch(text)) return true;
    if (RegExp(r'^\s*\d+\.\s', multiLine: true).hasMatch(text)) return true;
    
    // Check for links and images
    if (RegExp(r'\[([^\]]+)\]\(([^)]+)\)').hasMatch(text)) return true;
    
    // Check for blockquote
    if (RegExp(r'^>\s', multiLine: true).hasMatch(text)) return true;
    
    // Check for horizontal rule
    if (RegExp(r'^---+$', multiLine: true).hasMatch(text)) return true;
    
    return false;
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.copiedToClipboard),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    // Leave touch selection mode before opening the message menu.
    if (_selectionArmed) {
      _setSelectionArmed(false);
    }

    // If onLongPress callback is provided, use it instead of showing copy menu
    if (widget.onLongPress != null) {
      widget.onLongPress!();
      return;
    }

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy, size: 20),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.copy),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy_all',
          child: Row(
            children: [
              const Icon(Icons.select_all, size: 20),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.copyAll),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'copy') {
        if (_selectedText != null && _selectedText!.isNotEmpty) {
          _copyToClipboard(_selectedText!);
          widget.onCopySelection?.call(_selectedText!);
        } else {
          _copyToClipboard(widget.content);
          widget.onCopy?.call();
        }
      } else if (value == 'copy_all') {
        _copyToClipboard(widget.content);
        widget.onCopy?.call();
      }
    });
  }

  void _armSelectionForTouch() {
    if (!_isTouchPrimary || !widget.selectable || _selectionArmed) return;
    _setSelectionArmed(true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).dragToSelectText),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _onContentTap() {
    if (!_selectionArmed) return;
    // Exit selection mode when there is nothing selected (handles are gone).
    if (_selectedText == null || _selectedText!.isEmpty) {
      _setSelectionArmed(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.content.isEmpty) {
      return const SizedBox.shrink();
    }

    final brightness = Theme.of(context).brightness;
    final renderHtml = ref.watch(
      appSettingsProvider.select((s) => s.renderMessageHtml),
    );
    final neutralizeHtml = ref.watch(
      appSettingsProvider.select((s) => s.neutralizeMessageHtmlStyle),
    );
    if (_cachedWidget != null &&
        _cachedContent == widget.content &&
        _cachedStreaming == widget.isStreaming &&
        _cachedColor == widget.textColor &&
        _cachedIsUser == widget.isUser &&
        _cachedVersion == _contentVersion &&
        _cachedBrightness == brightness &&
        _cachedRenderHtml == renderHtml &&
        _cachedNeutralizeHtml == neutralizeHtml &&
        _cachedSelectionArmed == _selectionArmed) {
      return _cachedWidget!;
    }

    final result = _buildContent(
      context,
      renderHtml: renderHtml,
      neutralizeHtml: neutralizeHtml,
    );
    _cachedWidget = result;
    _cachedContent = widget.content;
    _cachedStreaming = widget.isStreaming;
    _cachedColor = widget.textColor;
    _cachedIsUser = widget.isUser;
    _cachedVersion = _contentVersion;
    _cachedBrightness = brightness;
    _cachedRenderHtml = renderHtml;
    _cachedNeutralizeHtml = neutralizeHtml;
    _cachedSelectionArmed = _selectionArmed;
    return result;
  }

  Widget _buildContent(
    BuildContext context, {
    required bool renderHtml,
    required bool neutralizeHtml,
  }) {
    final hasHtml = renderHtml && _containsHtml(widget.content);
    final dialogueColor = ZephyrChatChrome.dialogueTextColor(
      context,
      isUser: widget.isUser,
    );
    final useWebView =
        hasHtml && !widget.isStreaming && isComplexHtml(widget.content);

    Widget contentWidget;

    // Complex HTML → WebView (own long-press; no double-tap selection arm).
    if (useWebView) {
      final contentKey =
          '${widget.messageId ?? widget.content.hashCode}_v$_contentVersion';
      final surface = _htmlSurfaceColor(context);
      return HtmlWebViewWidget(
        htmlContent: widget.content,
        backgroundColor: surface,
        textColor: widget.textColor,
        dialogueColor: dialogueColor,
        fontSize:
            widget.fontSize ?? ZephyrChatChrome.messageFontSize(context),
        onLongPress: widget.onLongPress,
        contentKey: contentKey,
        neutralizeStyle: neutralizeHtml,
      );
    }

    final processedContent =
        hasHtml ? _convertHtmlToMarkdown(widget.content) : widget.content;
    contentWidget = _buildMarkdownContent(
      context,
      processedContent,
      dialogueColor: dialogueColor,
      enableSelection: _selectionEnabled,
    );

    // Touch + selection armed: do not claim long-press — SelectionArea needs it.
    final claimLongPressForMenu = !_isTouchPrimary || !_selectionEnabled;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition),
      onLongPressStart: claimLongPressForMenu
          ? (details) => _showContextMenu(context, details.globalPosition)
          : null,
      onDoubleTap: _isTouchPrimary && widget.selectable
          ? _armSelectionForTouch
          : null,
      onTap: _selectionArmed ? _onContentTap : null,
      child: contentWidget,
    );
  }
  
  /// Convert simple HTML tags to Markdown equivalents
  String _convertHtmlToMarkdown(String html) {
    var result = html;
    
    // Convert bold tags
    result = result.replaceAllMapped(
      RegExp(r'<(b|strong)>(.*?)</\1>', caseSensitive: false, dotAll: true),
      (m) => '**${m.group(2)}**',
    );
    
    // Convert italic tags
    result = result.replaceAllMapped(
      RegExp(r'<(i|em)>(.*?)</\1>', caseSensitive: false, dotAll: true),
      (m) => '*${m.group(2)}*',
    );
    
    // Convert underline to bold (Markdown doesn't have underline)
    result = result.replaceAllMapped(
      RegExp(r'<u>(.*?)</u>', caseSensitive: false, dotAll: true),
      (m) => '**${m.group(1)}**',
    );
    
    // Convert strikethrough
    result = result.replaceAllMapped(
      RegExp(r'<(s|del|strike)>(.*?)</\1>', caseSensitive: false, dotAll: true),
      (m) => '~~${m.group(2)}~~',
    );
    
    // Convert code tags
    result = result.replaceAllMapped(
      RegExp(r'<code>(.*?)</code>', caseSensitive: false, dotAll: true),
      (m) => '`${m.group(1)}`',
    );
    
    // Convert pre tags to code blocks
    result = result.replaceAllMapped(
      RegExp(r'<pre>(.*?)</pre>', caseSensitive: false, dotAll: true),
      (m) => '\n```\n${m.group(1)}\n```\n',
    );
    
    // Convert headers
    result = result.replaceAllMapped(
      RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false, dotAll: true),
      (m) => '\n# ${m.group(1)}\n',
    );
    result = result.replaceAllMapped(
      RegExp(r'<h2[^>]*>(.*?)</h2>', caseSensitive: false, dotAll: true),
      (m) => '\n## ${m.group(1)}\n',
    );
    result = result.replaceAllMapped(
      RegExp(r'<h3[^>]*>(.*?)</h3>', caseSensitive: false, dotAll: true),
      (m) => '\n### ${m.group(1)}\n',
    );
    result = result.replaceAllMapped(
      RegExp(r'<h4[^>]*>(.*?)</h4>', caseSensitive: false, dotAll: true),
      (m) => '\n#### ${m.group(1)}\n',
    );
    result = result.replaceAllMapped(
      RegExp(r'<h5[^>]*>(.*?)</h5>', caseSensitive: false, dotAll: true),
      (m) => '\n##### ${m.group(1)}\n',
    );
    result = result.replaceAllMapped(
      RegExp(r'<h6[^>]*>(.*?)</h6>', caseSensitive: false, dotAll: true),
      (m) => '\n###### ${m.group(1)}\n',
    );
    
    // Convert links
    result = result.replaceAllMapped(
      RegExp(r'<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>', caseSensitive: false, dotAll: true),
      (m) => '[${m.group(2)}](${m.group(1)})',
    );
    
    // Convert images - keep as Markdown image syntax
    result = result.replaceAllMapped(
      RegExp(r'<img[^>]*src="([^"]*)"[^>]*/?\s*>', caseSensitive: false),
      (m) => '![image](${m.group(1)})',
    );
    
    // Convert blockquote
    result = result.replaceAllMapped(
      RegExp(r'<blockquote[^>]*>(.*?)</blockquote>', caseSensitive: false, dotAll: true),
      (m) {
        final content = m.group(1) ?? '';
        final lines = content.split('\n').map((line) => '> ${line.trim()}').join('\n');
        return '\n$lines\n';
      },
    );
    
    // Convert horizontal rule
    result = result.replaceAll(RegExp(r'<hr\s*/?\s*>', caseSensitive: false), '\n---\n');
    
    // Convert line breaks
    result = result.replaceAll(RegExp(r'<br\s*/?\s*>', caseSensitive: false), '\n');
    
    // Convert paragraphs
    result = result.replaceAllMapped(
      RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true),
      (m) => '\n${m.group(1)}\n',
    );
    
    // Convert divs to paragraphs
    result = result.replaceAllMapped(
      RegExp(r'<div[^>]*>(.*?)</div>', caseSensitive: false, dotAll: true),
      (m) => '\n${m.group(1)}\n',
    );
    
    // Convert unordered lists
    result = result.replaceAllMapped(
      RegExp(r'<ul[^>]*>(.*?)</ul>', caseSensitive: false, dotAll: true),
      (m) {
        final content = m.group(1) ?? '';
        return content.replaceAllMapped(
          RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
          (li) => '- ${li.group(1)?.trim()}\n',
        );
      },
    );
    
    // Convert ordered lists
    result = result.replaceAllMapped(
      RegExp(r'<ol[^>]*>(.*?)</ol>', caseSensitive: false, dotAll: true),
      (m) {
        final content = m.group(1) ?? '';
        var index = 1;
        return content.replaceAllMapped(
          RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
          (li) => '${index++}. ${li.group(1)?.trim()}\n',
        );
      },
    );
    
    // Remove remaining HTML tags (span, font, center, etc.)
    result = result.replaceAll(RegExp(r'<[^>]+>'), '');
    
    // Clean up multiple newlines
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    // Decode HTML entities
    result = _decodeHtmlEntities(result);
    
    return result.trim();
  }
  
  /// Decode common HTML entities
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '…')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&trade;', '™');
  }

  Widget _buildMarkdownContent(
    BuildContext context,
    String content, {
    required Color dialogueColor,
    required bool enableSelection,
  }) {
    final effectiveFontSize =
        widget.fontSize ?? ZephyrChatChrome.messageFontSize(context);
    final dialogueStyle = TextStyle(
      color: dialogueColor,
      fontSize: effectiveFontSize,
      fontWeight: ZephyrChatChrome.dialogueFontWeight,
    );
    final codeStyle = TextStyle(
      color: widget.textColor,
      backgroundColor: AppTheme.darkBackground.withValues(alpha: 0.5),
      fontFamily: 'monospace',
      fontSize: effectiveFontSize * 0.9,
    );
    const codeblockPadding = EdgeInsets.all(12);

    final markdown = MarkdownBody(
      data: content,
      // Must stay false when wrapped in SelectionArea to avoid conflict.
      selectable: false,
      shrinkWrap: true,
      softLineBreak: true,
      inlineSyntaxes: [DialogueQuoteSyntax()],
      builders: {
        'dialogue': DialogueQuoteBuilder(dialogueStyle),
        // Override default horizontal-scrolling pre/code blocks with wrap.
        'pre': WrappingCodeBlockBuilder(
          codeStyle: codeStyle,
          padding: codeblockPadding,
        ),
      },
      imageBuilder: (uri, title, alt) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: uri.toString(),
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                height: 200,
                color: AppTheme.darkBackground,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 150,
                color: AppTheme.darkBackground,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image, color: AppTheme.textMuted),
                    const SizedBox(height: 4),
                    Text(
                      'Image failed to load',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          color: widget.textColor,
          fontSize: effectiveFontSize,
        ),
        strong: TextStyle(
          color: widget.textColor,
          fontWeight: FontWeight.bold,
        ),
        em: TextStyle(
          color: widget.textColor,
          fontStyle: FontStyle.italic,
        ),
        del: TextStyle(
          color: widget.textColor,
          decoration: TextDecoration.lineThrough,
        ),
        code: codeStyle,
        codeblockDecoration: BoxDecoration(
          color: AppTheme.darkBackground.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: codeblockPadding,
        blockquote: TextStyle(
          color: AppTheme.textSecondary,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppTheme.primaryColor,
              width: 3,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        h1: TextStyle(
          color: widget.textColor,
          fontSize: effectiveFontSize * 1.8,
          fontWeight: FontWeight.bold,
        ),
        h2: TextStyle(
          color: widget.textColor,
          fontSize: effectiveFontSize * 1.5,
          fontWeight: FontWeight.bold,
        ),
        h3: TextStyle(
          color: widget.textColor,
          fontSize: effectiveFontSize * 1.3,
          fontWeight: FontWeight.bold,
        ),
        h4: TextStyle(
          color: widget.textColor,
          fontSize: effectiveFontSize * 1.1,
          fontWeight: FontWeight.bold,
        ),
        h5: TextStyle(
          color: widget.textColor,
          fontSize: effectiveFontSize,
          fontWeight: FontWeight.bold,
        ),
        h6: TextStyle(
          color: widget.textColor,
          fontSize: effectiveFontSize * 0.9,
          fontWeight: FontWeight.bold,
        ),
        a: TextStyle(
          color: AppTheme.primaryColor,
          decoration: TextDecoration.underline,
        ),
        listBullet: TextStyle(
          color: widget.textColor,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.darkDivider,
              width: 1,
            ),
          ),
        ),
      ),
      onTapLink: (text, href, title) {
        if (href != null) {
          _launchUrl(href);
        }
      },
    );

    if (!enableSelection) return markdown;

    return SelectionArea(
      onSelectionChanged: (selection) {
        _selectedText = selection?.plainText;
      },
      child: markdown,
    );
  }

  Widget _buildPlainText(BuildContext context) {
    final effectiveFontSize =
        widget.fontSize ?? ZephyrChatChrome.messageFontSize(context);
    final text = Text(
      widget.content,
      style: TextStyle(
        color: widget.textColor,
        fontSize: effectiveFontSize,
      ),
    );

    if (!widget.selectable || !_selectionEnabled) return text;

    return SelectionArea(
      onSelectionChanged: (selection) {
        _selectedText = selection?.plainText;
      },
      child: text,
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}