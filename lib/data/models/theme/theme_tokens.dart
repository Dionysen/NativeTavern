import 'dart:math' as math;

/// Semantic color roles used by the app chrome and chat surfaces.
///
/// Values are opaque ARGB integers so this model stays independent from
/// Flutter's rendering library and can be stored by any platform adapter.
enum ThemeToken {
  editorSurface,
  sidebarSurface,
  controlSurface,
  border,
  divider,
  primaryText,
  mutedText,
  accent,
  secondaryAccent,
  tertiaryAccent,
  cursor,
  chatBackground,
  characterBubble,
  userBubble,
  chatText,
  dialogueText,
}

enum ThemePreset {
  light,
  grey,
  slate,
  claude,
  mint,
  purple,
  hermes,
  ocean,
  darkModern;
}

class ThemeTokens {
  ThemeTokens({
    required this.editorSurface,
    required this.sidebarSurface,
    required this.controlSurface,
    required this.border,
    required this.divider,
    required this.primaryText,
    required this.mutedText,
    required this.accent,
    this.secondaryAccent = defaultSecondaryAccent,
    this.tertiaryAccent = defaultTertiaryAccent,
    required this.cursor,
    int? chatBackground,
    int? characterBubble,
    int? userBubble,
    int? chatText,
    int? dialogueText,
  })  : chatBackground = chatBackground ?? editorSurface,
        characterBubble = characterBubble ?? controlSurface,
        userBubble = userBubble ??
            blendOnto(
              accent,
              editorSurface,
              surfaceLuminanceOf(editorSurface) > 0.5 ? 0.18 : 0.28,
            ),
        chatText = chatText ?? primaryText,
        // Soft orange tertiary keeps quoted speech distinct from narration.
        dialogueText = dialogueText ?? tertiaryAccent;

  /// Accent for light presets — clear blue that reads well on pale chrome.
  static const lightAccent = 0xFF3376CE;

  /// Cursor / VS Code “Sync Changes” button blue.
  static const darkModernAccent = 0xFF3376CE;

  /// Second accent for section/action differentiation (teal).
  static const defaultSecondaryAccent = 0xFF1ABC9C;

  /// Third accent for section/action differentiation (soft orange).
  static const defaultTertiaryAccent = 0xFFE09A5A;

  /// Default dark pack (Dark Modern).
  static final defaults = ThemeTokens(
    editorSurface: 0xFF1F1F1F,
    sidebarSurface: 0xFF181818,
    controlSurface: 0xFF313131,
    border: 0xFF2B2B2B,
    divider: 0xFF2B2B2B,
    primaryText: 0xFFCCCCCC,
    mutedText: 0xFF9D9D9D,
    accent: darkModernAccent,
    cursor: 0xFFFFFFFF,
  );

  static final presets = <ThemePreset, ThemeTokens>{
    ThemePreset.light: ThemeTokens(
      editorSurface: 0xFFF9F9FA,
      sidebarSurface: 0xFFF1F3F6,
      controlSurface: 0xFFFFFFFF,
      border: 0xFFE1E4E8,
      divider: 0xFFE4E6EA,
      primaryText: 0xFF25272A,
      mutedText: 0xFF70757D,
      accent: lightAccent,
      cursor: 0xFF25272A,
    ),
    ThemePreset.grey: ThemeTokens(
      editorSurface: 0xFFF8FAFC,
      sidebarSurface: 0xFFF0F3F7,
      controlSurface: 0xFFFFFFFF,
      border: 0xFFDDE3EA,
      divider: 0xFFE0E4EA,
      primaryText: 0xFF293241,
      mutedText: 0xFF718096,
      accent: lightAccent,
      cursor: 0xFF293241,
    ),
    ThemePreset.slate: ThemeTokens(
      editorSurface: 0xFFFAFAFA,
      sidebarSurface: 0xFFF3F4F6,
      controlSurface: 0xFFFFFFFF,
      border: 0xFFE5E5E5,
      divider: 0xFFE8E8E8,
      primaryText: 0xFF34343A,
      mutedText: 0xFF777780,
      accent: lightAccent,
      cursor: 0xFF34343A,
    ),
    ThemePreset.claude: ThemeTokens(
      editorSurface: 0xFFFCFAF7,
      sidebarSurface: 0xFFF4F0E9,
      controlSurface: 0xFFFFFFFF,
      border: 0xFFE7E0D5,
      divider: 0xFFEBE4D9,
      primaryText: 0xFF39312B,
      mutedText: 0xFF82756A,
      accent: lightAccent,
      cursor: 0xFF39312B,
    ),
    ThemePreset.mint: ThemeTokens(
      editorSurface: 0xFFFBFDFC,
      sidebarSurface: 0xFFE5F2EC,
      controlSurface: 0xFFFFFFFF,
      border: 0xFFD2E5DC,
      divider: 0xFFDCE8E2,
      primaryText: 0xFF253A32,
      mutedText: 0xFF6A8277,
      accent: lightAccent,
      cursor: 0xFF253A32,
    ),
    ThemePreset.purple: ThemeTokens(
      editorSurface: 0xFFFCF9FF,
      sidebarSurface: 0xFFF0E6FB,
      controlSurface: 0xFFFFFFFF,
      border: 0xFFE5D9F2,
      divider: 0xFFE8DFF2,
      primaryText: 0xFF382D4A,
      mutedText: 0xFF7E708F,
      accent: lightAccent,
      cursor: 0xFF382D4A,
    ),
    ThemePreset.hermes: ThemeTokens(
      editorSurface: 0xFFF7F7FF,
      sidebarSurface: 0xFFE9EAFA,
      controlSurface: 0xFFFFFFFF,
      border: 0xFFDCDDFA,
      divider: 0xFFE2E3F5,
      primaryText: 0xFF252D50,
      mutedText: 0xFF70769A,
      accent: lightAccent,
      cursor: 0xFF252D50,
    ),
    ThemePreset.ocean: ThemeTokens(
      editorSurface: 0xFF161923,
      sidebarSurface: 0xFF10131B,
      controlSurface: 0xFF202531,
      border: 0xFF303847,
      divider: 0xFF1C2230,
      primaryText: 0xFFE4E8F0,
      mutedText: 0xFF8B95A7,
      accent: darkModernAccent,
      cursor: 0xFFFFFFFF,
    ),
    ThemePreset.darkModern: defaults,
  };

  final int editorSurface;
  final int sidebarSurface;
  final int controlSurface;
  final int border;
  final int divider;
  final int primaryText;
  final int mutedText;
  final int accent;
  final int secondaryAccent;
  final int tertiaryAccent;
  final int cursor;
  final int chatBackground;
  final int characterBubble;
  final int userBubble;
  final int chatText;
  final int dialogueText;

  ThemePreset? get preset => ThemePreset.values
      .where((candidate) => presets[candidate] == this)
      .firstOrNull;

  /// Relative luminance of [editorSurface] in 0…1 (sRGB).
  double get surfaceLuminance => surfaceLuminanceOf(editorSurface);

  bool get isLight => surfaceLuminance > 0.5;

  static double surfaceLuminanceOf(int argb) {
    final c = argb & 0xFFFFFF;
    double linearize(int value) {
      final v = value / 255.0;
      return v <= 0.04045
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = linearize((c >> 16) & 0xFF);
    final g = linearize((c >> 8) & 0xFF);
    final b = linearize(c & 0xFF);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Opaque alpha-blend of [foreground] onto [background].
  static int blendOnto(int foreground, int background, double alpha) {
    final t = alpha.clamp(0.0, 1.0);
    int channel(int shift) {
      final fg = (foreground >> shift) & 0xFF;
      final bg = (background >> shift) & 0xFF;
      return (fg * t + bg * (1 - t)).round().clamp(0, 255);
    }

    return 0xFF000000 |
        (channel(16) << 16) |
        (channel(8) << 8) |
        channel(0);
  }

  int valueOf(ThemeToken token) => switch (token) {
        ThemeToken.editorSurface => editorSurface,
        ThemeToken.sidebarSurface => sidebarSurface,
        ThemeToken.controlSurface => controlSurface,
        ThemeToken.border => border,
        ThemeToken.divider => divider,
        ThemeToken.primaryText => primaryText,
        ThemeToken.mutedText => mutedText,
        ThemeToken.accent => accent,
        ThemeToken.secondaryAccent => secondaryAccent,
        ThemeToken.tertiaryAccent => tertiaryAccent,
        ThemeToken.cursor => cursor,
        ThemeToken.chatBackground => chatBackground,
        ThemeToken.characterBubble => characterBubble,
        ThemeToken.userBubble => userBubble,
        ThemeToken.chatText => chatText,
        ThemeToken.dialogueText => dialogueText,
      };

  ThemeTokens withValue(ThemeToken token, int value) => switch (token) {
        ThemeToken.editorSurface => copyWith(editorSurface: value),
        ThemeToken.sidebarSurface => copyWith(sidebarSurface: value),
        ThemeToken.controlSurface => copyWith(controlSurface: value),
        ThemeToken.border => copyWith(border: value),
        ThemeToken.divider => copyWith(divider: value),
        ThemeToken.primaryText => copyWith(primaryText: value),
        ThemeToken.mutedText => copyWith(mutedText: value),
        ThemeToken.accent => copyWith(accent: value),
        ThemeToken.secondaryAccent => copyWith(secondaryAccent: value),
        ThemeToken.tertiaryAccent => copyWith(tertiaryAccent: value),
        ThemeToken.cursor => copyWith(cursor: value),
        ThemeToken.chatBackground => copyWith(chatBackground: value),
        ThemeToken.characterBubble => copyWith(characterBubble: value),
        ThemeToken.userBubble => copyWith(userBubble: value),
        ThemeToken.chatText => copyWith(chatText: value),
        ThemeToken.dialogueText => copyWith(dialogueText: value),
      };

  ThemeTokens copyWith({
    int? editorSurface,
    int? sidebarSurface,
    int? controlSurface,
    int? border,
    int? divider,
    int? primaryText,
    int? mutedText,
    int? accent,
    int? secondaryAccent,
    int? tertiaryAccent,
    int? cursor,
    int? chatBackground,
    int? characterBubble,
    int? userBubble,
    int? chatText,
    int? dialogueText,
  }) =>
      ThemeTokens(
        editorSurface: editorSurface ?? this.editorSurface,
        sidebarSurface: sidebarSurface ?? this.sidebarSurface,
        controlSurface: controlSurface ?? this.controlSurface,
        border: border ?? this.border,
        divider: divider ?? this.divider,
        primaryText: primaryText ?? this.primaryText,
        mutedText: mutedText ?? this.mutedText,
        accent: accent ?? this.accent,
        secondaryAccent: secondaryAccent ?? this.secondaryAccent,
        tertiaryAccent: tertiaryAccent ?? this.tertiaryAccent,
        cursor: cursor ?? this.cursor,
        chatBackground: chatBackground ?? this.chatBackground,
        characterBubble: characterBubble ?? this.characterBubble,
        userBubble: userBubble ?? this.userBubble,
        chatText: chatText ?? this.chatText,
        dialogueText: dialogueText ?? this.dialogueText,
      );

  Map<String, dynamic> toJson() => {
        'editorSurface': editorSurface,
        'sidebarSurface': sidebarSurface,
        'controlSurface': controlSurface,
        'border': border,
        'divider': divider,
        'primaryText': primaryText,
        'mutedText': mutedText,
        'accent': accent,
        'secondaryAccent': secondaryAccent,
        'tertiaryAccent': tertiaryAccent,
        'cursor': cursor,
        'chatBackground': chatBackground,
        'characterBubble': characterBubble,
        'userBubble': userBubble,
        'chatText': chatText,
        'dialogueText': dialogueText,
      };

  factory ThemeTokens.fromJson(Map<String, dynamic> json) {
    final editorSurface = json['editorSurface'] as int;
    final controlSurface = json['controlSurface'] as int;
    final primaryText = json['primaryText'] as int;
    final accent = json['accent'] as int;
    return ThemeTokens(
      editorSurface: editorSurface,
      sidebarSurface: json['sidebarSurface'] as int,
      controlSurface: controlSurface,
      border: json['border'] as int,
      divider: json['divider'] as int,
      primaryText: primaryText,
      mutedText: json['mutedText'] as int,
      accent: accent,
      secondaryAccent:
          json['secondaryAccent'] as int? ?? defaultSecondaryAccent,
      tertiaryAccent: json['tertiaryAccent'] as int? ?? defaultTertiaryAccent,
      cursor: json['cursor'] as int,
      chatBackground: json['chatBackground'] as int?,
      characterBubble: json['characterBubble'] as int?,
      userBubble: json['userBubble'] as int?,
      chatText: json['chatText'] as int?,
      dialogueText: json['dialogueText'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeTokens &&
      editorSurface == other.editorSurface &&
      sidebarSurface == other.sidebarSurface &&
      controlSurface == other.controlSurface &&
      border == other.border &&
      divider == other.divider &&
      primaryText == other.primaryText &&
      mutedText == other.mutedText &&
      accent == other.accent &&
      secondaryAccent == other.secondaryAccent &&
      tertiaryAccent == other.tertiaryAccent &&
      cursor == other.cursor &&
      chatBackground == other.chatBackground &&
      characterBubble == other.characterBubble &&
      userBubble == other.userBubble &&
      chatText == other.chatText &&
      dialogueText == other.dialogueText;

  @override
  int get hashCode => Object.hash(
        editorSurface,
        sidebarSurface,
        controlSurface,
        border,
        divider,
        primaryText,
        mutedText,
        accent,
        secondaryAccent,
        tertiaryAccent,
        cursor,
        chatBackground,
        characterBubble,
        userBubble,
        chatText,
        dialogueText,
      );
}
