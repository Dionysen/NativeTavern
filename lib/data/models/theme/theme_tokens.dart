import 'dart:math' as math;

/// Semantic color roles used by the app chrome.
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
  cursor,
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
  const ThemeTokens({
    required this.editorSurface,
    required this.sidebarSurface,
    required this.controlSurface,
    required this.border,
    required this.divider,
    required this.primaryText,
    required this.mutedText,
    required this.accent,
    required this.cursor,
  });

  /// Accent for light presets — clear blue that reads well on pale chrome.
  static const lightAccent = 0xFF3376CE;

  /// Cursor / VS Code “Sync Changes” button blue.
  static const darkModernAccent = 0xFF3376CE;

  /// Default dark pack (Dark Modern).
  static const defaults = ThemeTokens(
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

  static const presets = <ThemePreset, ThemeTokens>{
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
  final int cursor;

  ThemePreset? get preset => ThemePreset.values
      .where((candidate) => presets[candidate] == this)
      .firstOrNull;

  /// Relative luminance of [editorSurface] in 0…1 (sRGB).
  double get surfaceLuminance {
    final c = editorSurface & 0xFFFFFF;
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

  bool get isLight => surfaceLuminance > 0.5;

  int valueOf(ThemeToken token) => switch (token) {
        ThemeToken.editorSurface => editorSurface,
        ThemeToken.sidebarSurface => sidebarSurface,
        ThemeToken.controlSurface => controlSurface,
        ThemeToken.border => border,
        ThemeToken.divider => divider,
        ThemeToken.primaryText => primaryText,
        ThemeToken.mutedText => mutedText,
        ThemeToken.accent => accent,
        ThemeToken.cursor => cursor,
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
        ThemeToken.cursor => copyWith(cursor: value),
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
    int? cursor,
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
        cursor: cursor ?? this.cursor,
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
        'cursor': cursor,
      };

  factory ThemeTokens.fromJson(Map<String, dynamic> json) => ThemeTokens(
        editorSurface: json['editorSurface'] as int,
        sidebarSurface: json['sidebarSurface'] as int,
        controlSurface: json['controlSurface'] as int,
        border: json['border'] as int,
        divider: json['divider'] as int,
        primaryText: json['primaryText'] as int,
        mutedText: json['mutedText'] as int,
        accent: json['accent'] as int,
        cursor: json['cursor'] as int,
      );

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
      cursor == other.cursor;

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
        cursor,
      );
}
