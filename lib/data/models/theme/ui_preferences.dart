/// Shell chrome typography and shape, independent of semantic color tokens.
class UiPreferences {
  const UiPreferences({
    required this.fontSize,
    this.fontFamily,
    this.fontPath,
    required this.cornerRadius,
    required this.chatBubbleCornerRadius,
    required this.showBorders,
    required this.chatLineHeight,
    required this.chatParagraphSpacing,
    required this.markdownLineHeight,
    required this.markdownParagraphSpacing,
  });

  static const defaults = UiPreferences(
    fontSize: 16,
    fontFamily: null,
    fontPath: null,
    cornerRadius: 4,
    chatBubbleCornerRadius: 30,
    showBorders: false,
    chatLineHeight: 1.4,
    chatParagraphSpacing: 8,
    markdownLineHeight: 1.5,
    markdownParagraphSpacing: 8,
  );

  static const referenceFontSize = 15.0;
  static const minCornerRadius = 0.0;
  static const maxCornerRadius = 20.0;
  static const minChatBubbleCornerRadius = 0.0;
  static const maxChatBubbleCornerRadius = 50.0;
  static const minFontSize = 11.0;
  static const maxFontSize = 18.0;
  static const minLineHeight = 1.0;
  static const maxLineHeight = 2.5;
  static const minParagraphSpacing = 0.0;
  static const maxParagraphSpacing = 24.0;

  final double fontSize;

  /// Registered [FontLoader] family, or a generic family like `serif`.
  final String? fontFamily;

  /// Durable font file identity used to re-register [fontFamily] on launch.
  final String? fontPath;

  /// Shared corner radius for chrome controls, menus, cards, and dialogs.
  final double cornerRadius;

  /// Chat bubble corner radius.
  final double chatBubbleCornerRadius;

  /// When false, chrome controls omit outline borders.
  final bool showBorders;

  /// Line height multiplier for Markdown chat body text.
  final double chatLineHeight;

  /// Space between Markdown paragraphs / blocks, in logical pixels.
  final double chatParagraphSpacing;

  /// Line height multiplier for HTML (WebView) message rendering.
  final double markdownLineHeight;

  /// Space between HTML paragraphs, in logical pixels.
  final double markdownParagraphSpacing;

  double get scale => fontSize / referenceFontSize;

  UiPreferences copyWith({
    double? fontSize,
    String? fontFamily,
    String? fontPath,
    bool clearFont = false,
    double? cornerRadius,
    double? chatBubbleCornerRadius,
    bool? showBorders,
    double? chatLineHeight,
    double? chatParagraphSpacing,
    double? markdownLineHeight,
    double? markdownParagraphSpacing,
  }) =>
      UiPreferences(
        fontSize: fontSize ?? this.fontSize,
        fontFamily: clearFont ? null : fontFamily ?? this.fontFamily,
        fontPath: clearFont ? null : fontPath ?? this.fontPath,
        cornerRadius: cornerRadius ?? this.cornerRadius,
        chatBubbleCornerRadius:
            chatBubbleCornerRadius ?? this.chatBubbleCornerRadius,
        showBorders: showBorders ?? this.showBorders,
        chatLineHeight: chatLineHeight ?? this.chatLineHeight,
        chatParagraphSpacing:
            chatParagraphSpacing ?? this.chatParagraphSpacing,
        markdownLineHeight: markdownLineHeight ?? this.markdownLineHeight,
        markdownParagraphSpacing:
            markdownParagraphSpacing ?? this.markdownParagraphSpacing,
      );

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (fontPath != null) 'fontPath': fontPath,
        'cornerRadius': cornerRadius,
        'chatBubbleCornerRadius': chatBubbleCornerRadius,
        'showBorders': showBorders,
        'chatLineHeight': chatLineHeight,
        'chatParagraphSpacing': chatParagraphSpacing,
        'markdownLineHeight': markdownLineHeight,
        'markdownParagraphSpacing': markdownParagraphSpacing,
      };

  factory UiPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;

    String? fontFamily = json['fontFamily'] as String?;
    String? fontPath = json['fontPath'] as String?;

    // Legacy generic picker ids (pre–font library).
    final legacyId = json['fontFamilyId'] as String?;
    if (fontPath == null && fontFamily == null && legacyId != null) {
      fontFamily = switch (legacyId) {
        'serif' => 'serif',
        'monospace' => 'monospace',
        _ => null,
      };
    }

    return UiPreferences(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? defaults.fontSize,
      fontFamily: fontFamily,
      fontPath: fontPath,
      cornerRadius:
          (json['cornerRadius'] as num?)?.toDouble() ?? defaults.cornerRadius,
      chatBubbleCornerRadius:
          (json['chatBubbleCornerRadius'] as num?)?.toDouble() ??
              defaults.chatBubbleCornerRadius,
      showBorders: json['showBorders'] as bool? ?? defaults.showBorders,
      chatLineHeight: (json['chatLineHeight'] as num?)?.toDouble() ??
          defaults.chatLineHeight,
      chatParagraphSpacing:
          (json['chatParagraphSpacing'] as num?)?.toDouble() ??
              defaults.chatParagraphSpacing,
      markdownLineHeight: (json['markdownLineHeight'] as num?)?.toDouble() ??
          defaults.markdownLineHeight,
      markdownParagraphSpacing:
          (json['markdownParagraphSpacing'] as num?)?.toDouble() ??
              defaults.markdownParagraphSpacing,
    );
  }
}
