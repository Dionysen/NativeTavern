import 'dart:convert';

import 'package:native_tavern/data/models/theme/theme_tokens.dart';

/// Types of chat backgrounds
enum BackgroundType {
  none,
  color,
  gradient,
  image,
}

/// Chat background configuration
class ChatBackground {
  final BackgroundType type;
  final String? color; // Hex color for solid color background
  final List<String>? gradientColors; // Hex colors for gradient
  final double? gradientAngle; // Angle for linear gradient (0-360)
  final String? imagePath; // Local path to image
  final String? imageUrl; // URL for remote image
  final double opacity; // Background opacity (0.0 - 1.0)
  final bool blur; // Whether to blur the background
  final double blurAmount; // Blur amount (0-20)
  final double bubbleOpacity; // Opacity of chat bubbles (0.0 - 1.0)

  const ChatBackground({
    this.type = BackgroundType.none,
    this.color,
    this.gradientColors,
    this.gradientAngle,
    this.imagePath,
    this.imageUrl,
    this.opacity = 1.0,
    this.blur = false,
    this.blurAmount = 5.0,
    this.bubbleOpacity = 0.8,
  });

  /// Default (no background)
  static const ChatBackground none = ChatBackground(type: BackgroundType.none);

  /// Create a solid color background
  factory ChatBackground.color(String hexColor, {double opacity = 1.0}) {
    return ChatBackground(
      type: BackgroundType.color,
      color: hexColor,
      opacity: opacity,
      bubbleOpacity: 1.0,
    );
  }

  /// Create a gradient background
  factory ChatBackground.gradient(
    List<String> colors, {
    double angle = 180,
    double opacity = 1.0,
  }) {
    return ChatBackground(
      type: BackgroundType.gradient,
      gradientColors: colors,
      gradientAngle: angle,
      opacity: opacity,
      bubbleOpacity: 1.0,
    );
  }

  /// Create an image background from local path
  factory ChatBackground.imagePath(
    String path, {
    double opacity = 1.0,
    bool blur = false,
    double blurAmount = 5.0,
    double bubbleOpacity = 0.8,
  }) {
    return ChatBackground(
      type: BackgroundType.image,
      imagePath: path,
      opacity: opacity,
      blur: blur,
      blurAmount: blurAmount,
      bubbleOpacity: bubbleOpacity,
    );
  }

  /// Create an image background from URL
  factory ChatBackground.imageUrl(
    String url, {
    double opacity = 1.0,
    bool blur = false,
    double blurAmount = 5.0,
    double bubbleOpacity = 0.8,
  }) {
    return ChatBackground(
      type: BackgroundType.image,
      imageUrl: url,
      opacity: opacity,
      blur: blur,
      blurAmount: blurAmount,
      bubbleOpacity: bubbleOpacity,
    );
  }

  ChatBackground copyWith({
    BackgroundType? type,
    String? color,
    List<String>? gradientColors,
    double? gradientAngle,
    String? imagePath,
    String? imageUrl,
    double? opacity,
    bool? blur,
    double? blurAmount,
    double? bubbleOpacity,
  }) {
    return ChatBackground(
      type: type ?? this.type,
      color: color ?? this.color,
      gradientColors: gradientColors ?? this.gradientColors,
      gradientAngle: gradientAngle ?? this.gradientAngle,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      opacity: opacity ?? this.opacity,
      blur: blur ?? this.blur,
      blurAmount: blurAmount ?? this.blurAmount,
      bubbleOpacity: bubbleOpacity ?? this.bubbleOpacity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'color': color,
      'gradientColors': gradientColors,
      'gradientAngle': gradientAngle,
      'imagePath': imagePath,
      'imageUrl': imageUrl,
      'opacity': opacity,
      'blur': blur,
      'blurAmount': blurAmount,
      'bubbleOpacity': bubbleOpacity,
    };
  }

  factory ChatBackground.fromJson(Map<String, dynamic> json) {
    return ChatBackground(
      type: BackgroundType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => BackgroundType.none,
      ),
      color: json['color'] as String?,
      gradientColors: (json['gradientColors'] as List<dynamic>?)?.cast<String>(),
      gradientAngle: (json['gradientAngle'] as num?)?.toDouble(),
      imagePath: json['imagePath'] as String?,
      imageUrl: json['imageUrl'] as String?,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      blur: json['blur'] as bool? ?? false,
      blurAmount: (json['blurAmount'] as num?)?.toDouble() ?? 5.0,
      bubbleOpacity: (json['bubbleOpacity'] as num?)?.toDouble() ?? 0.8,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ChatBackground.fromJsonString(String jsonString) {
    return ChatBackground.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatBackground &&
        other.type == type &&
        other.color == color &&
        other.imagePath == imagePath &&
        other.imageUrl == imageUrl &&
        other.opacity == opacity;
  }

  @override
  int get hashCode => Object.hash(type, color, imagePath, imageUrl, opacity);
}

/// Preset backgrounds derived from built-in [ThemeTokens] packs.
class BackgroundPresets {
  static String _hex(int argb) {
    final rgb = argb & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Soft vertical / diagonal gradients from each theme pack's surfaces.
  static List<ChatBackground> get gradients {
    final seen = <String>{};
    final out = <ChatBackground>[];

    void add(List<String> colors, double angle) {
      if (colors.length < 2) return;
      if (colors.toSet().length < 2) return;
      final key = '${colors.join(',')}|$angle';
      if (!seen.add(key)) return;
      out.add(ChatBackground.gradient(colors, angle: angle));
    }

    for (final tokens in ThemeTokens.presets.values) {
      final sidebar = _hex(tokens.sidebarSurface);
      final editor = _hex(tokens.editorSurface);
      final control = _hex(tokens.controlSurface);
      final accent = _hex(tokens.accent);
      add([sidebar, editor], 180);
      add([editor, control], 135);
      if (!tokens.isLight) {
        add([editor, accent], 160);
      } else {
        add([sidebar, accent], 145);
      }
    }
    return out;
  }

  /// Solid fills from theme pack surfaces (deduped).
  static List<ChatBackground> get solidColors {
    final seen = <String>{};
    final out = <ChatBackground>[];

    void add(int argb) {
      final hex = _hex(argb);
      if (!seen.add(hex)) return;
      out.add(ChatBackground.color(hex));
    }

    for (final tokens in ThemeTokens.presets.values) {
      add(tokens.editorSurface);
      add(tokens.sidebarSurface);
      add(tokens.controlSurface);
    }
    return out;
  }
}