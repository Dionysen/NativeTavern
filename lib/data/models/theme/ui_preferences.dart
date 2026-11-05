import 'app_font_family.dart';

/// Shell chrome typography and shape, independent of semantic color tokens.
class UiPreferences {
  const UiPreferences({
    required this.fontSize,
    required this.fontFamilyId,
    required this.cornerRadius,
    required this.barCornerRadius,
    required this.chatBubbleCornerRadius,
    required this.showBorders,
  });

  static const defaults = UiPreferences(
    fontSize: 16,
    fontFamilyId: AppFontFamily.system,
    cornerRadius: 4,
    barCornerRadius: 4,
    chatBubbleCornerRadius: 30,
    showBorders: false,
  );

  static const referenceFontSize = 15.0;
  static const minCornerRadius = 0.0;
  static const maxCornerRadius = 20.0;
  static const minBarCornerRadius = 0.0;
  static const maxBarCornerRadius = 24.0;
  static const minChatBubbleCornerRadius = 0.0;
  static const maxChatBubbleCornerRadius = 50.0;
  static const minFontSize = 11.0;
  static const maxFontSize = 18.0;

  final double fontSize;

  /// [AppFontFamily] id; system uses the platform default face.
  final String fontFamilyId;

  /// Shared corner radius for chrome controls, menus, cards, and dialogs.
  final double cornerRadius;

  /// Corner radius for app bars and floating bars.
  final double barCornerRadius;

  /// Chat bubble corner radius.
  final double chatBubbleCornerRadius;

  /// When false, chrome controls omit outline borders.
  final bool showBorders;

  double get scale => fontSize / referenceFontSize;

  String? get fontFamily => AppFontFamily.resolve(fontFamilyId);

  UiPreferences copyWith({
    double? fontSize,
    String? fontFamilyId,
    double? cornerRadius,
    double? barCornerRadius,
    double? chatBubbleCornerRadius,
    bool? showBorders,
  }) =>
      UiPreferences(
        fontSize: fontSize ?? this.fontSize,
        fontFamilyId: fontFamilyId ?? this.fontFamilyId,
        cornerRadius: cornerRadius ?? this.cornerRadius,
        barCornerRadius: barCornerRadius ?? this.barCornerRadius,
        chatBubbleCornerRadius:
            chatBubbleCornerRadius ?? this.chatBubbleCornerRadius,
        showBorders: showBorders ?? this.showBorders,
      );

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'fontFamilyId': fontFamilyId,
        'cornerRadius': cornerRadius,
        'barCornerRadius': barCornerRadius,
        'chatBubbleCornerRadius': chatBubbleCornerRadius,
        'showBorders': showBorders,
      };

  factory UiPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    final rawFamily = json['fontFamilyId'] as String?;
    return UiPreferences(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? defaults.fontSize,
      fontFamilyId: AppFontFamily.ids.contains(rawFamily)
          ? rawFamily!
          : defaults.fontFamilyId,
      cornerRadius:
          (json['cornerRadius'] as num?)?.toDouble() ?? defaults.cornerRadius,
      barCornerRadius: (json['barCornerRadius'] as num?)?.toDouble() ??
          defaults.barCornerRadius,
      chatBubbleCornerRadius:
          (json['chatBubbleCornerRadius'] as num?)?.toDouble() ??
              defaults.chatBubbleCornerRadius,
      showBorders: json['showBorders'] as bool? ?? defaults.showBorders,
    );
  }
}
