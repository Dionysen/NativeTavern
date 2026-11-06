import 'dart:convert';

/// Types of chat backgrounds
enum BackgroundType {
  none,
  color,
  gradient,
  image,
}

/// Gradient geometry for [BackgroundType.gradient].
enum BackgroundGradientStyle {
  linear,
  radial,
}

/// Chat background configuration
class ChatBackground {
  final BackgroundType type;
  final String? color; // Hex color for solid color background
  final List<String>? gradientColors; // Hex colors for gradient
  final double? gradientAngle; // Angle for linear gradient (0-360)
  final BackgroundGradientStyle gradientStyle;
  /// Radial gradient radius (Flutter [RadialGradient.radius]), typically 0.2–1.5.
  final double gradientRadius;
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
    this.gradientStyle = BackgroundGradientStyle.linear,
    this.gradientRadius = 1.05,
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
    BackgroundGradientStyle style = BackgroundGradientStyle.linear,
    double radius = 1.05,
    double opacity = 1.0,
  }) {
    return ChatBackground(
      type: BackgroundType.gradient,
      gradientColors: colors,
      gradientAngle: angle,
      gradientStyle: style,
      gradientRadius: radius,
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
    BackgroundGradientStyle? gradientStyle,
    double? gradientRadius,
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
      gradientStyle: gradientStyle ?? this.gradientStyle,
      gradientRadius: gradientRadius ?? this.gradientRadius,
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
      'gradientStyle': gradientStyle.name,
      'gradientRadius': gradientRadius,
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
      gradientStyle: BackgroundGradientStyle.values.firstWhere(
        (s) => s.name == json['gradientStyle'],
        orElse: () => BackgroundGradientStyle.linear,
      ),
      gradientRadius: (json['gradientRadius'] as num?)?.toDouble() ?? 1.05,
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

/// Curated chat background presets — visually distinct only, no near-duplicates.
class BackgroundPresets {
  BackgroundPresets._();

  /// Distinctive two-stop gradients (dark + tinted light).
  static const List<ChatBackground> gradients = [
    ChatBackground(
      type: BackgroundType.gradient,
      gradientColors: ['#1F1F1F', '#313131'],
      gradientAngle: 180,
      bubbleOpacity: 1.0,
    ),
    ChatBackground(
      type: BackgroundType.gradient,
      gradientColors: ['#10131B', '#2A3348'],
      gradientAngle: 180,
      bubbleOpacity: 1.0,
    ),
    ChatBackground(
      type: BackgroundType.gradient,
      gradientColors: ['#1A1025', '#3D2A55'],
      gradientAngle: 160,
      bubbleOpacity: 1.0,
    ),
    ChatBackground(
      type: BackgroundType.gradient,
      gradientColors: ['#0F1A18', '#1F3A34'],
      gradientAngle: 180,
      bubbleOpacity: 1.0,
    ),
    ChatBackground(
      type: BackgroundType.gradient,
      gradientColors: ['#1A1210', '#4A2E24'],
      gradientAngle: 145,
      bubbleOpacity: 1.0,
    ),
    ChatBackground(
      type: BackgroundType.gradient,
      gradientColors: ['#F1F3F6', '#FFFFFF'],
      gradientAngle: 180,
      bubbleOpacity: 1.0,
    ),
    ChatBackground(
      type: BackgroundType.gradient,
      gradientColors: ['#F4F0E9', '#FCFAF7'],
      gradientAngle: 180,
      bubbleOpacity: 1.0,
    ),
    ChatBackground(
      type: BackgroundType.gradient,
      gradientColors: ['#E5F2EC', '#FBFDFC'],
      gradientAngle: 180,
      bubbleOpacity: 1.0,
    ),
    ChatBackground(
      type: BackgroundType.gradient,
      gradientColors: ['#F0E6FB', '#FCF9FF'],
      gradientAngle: 180,
      bubbleOpacity: 1.0,
    ),
    ChatBackground(
      type: BackgroundType.gradient,
      gradientColors: ['#DBEAFE', '#EFF6FF'],
      gradientAngle: 180,
      bubbleOpacity: 1.0,
    ),
    ChatBackground(
      type: BackgroundType.gradient,
      gradientColors: ['#FEE2E2', '#FFF7ED'],
      gradientAngle: 145,
      bubbleOpacity: 1.0,
    ),
  ];

  /// Distinctive solid fills spanning dark neutrals and tinted lights.
  static const List<ChatBackground> solidColors = [
    ChatBackground(type: BackgroundType.color, color: '#1F1F1F', bubbleOpacity: 1.0),
    ChatBackground(type: BackgroundType.color, color: '#10131B', bubbleOpacity: 1.0),
    ChatBackground(type: BackgroundType.color, color: '#2A1F3D', bubbleOpacity: 1.0),
    ChatBackground(type: BackgroundType.color, color: '#1B2D2A', bubbleOpacity: 1.0),
    ChatBackground(type: BackgroundType.color, color: '#3A241C', bubbleOpacity: 1.0),
    ChatBackground(type: BackgroundType.color, color: '#FFFFFF', bubbleOpacity: 1.0),
    ChatBackground(type: BackgroundType.color, color: '#F4F0E9', bubbleOpacity: 1.0),
    ChatBackground(type: BackgroundType.color, color: '#E5F2EC', bubbleOpacity: 1.0),
    ChatBackground(type: BackgroundType.color, color: '#F0E6FB', bubbleOpacity: 1.0),
    ChatBackground(type: BackgroundType.color, color: '#DBEAFE', bubbleOpacity: 1.0),
    ChatBackground(type: BackgroundType.color, color: '#FEE2E2', bubbleOpacity: 1.0),
    ChatBackground(type: BackgroundType.color, color: '#FFF7ED', bubbleOpacity: 1.0),
  ];

  static bool isPresetColor(String? hex) {
    if (hex == null) return false;
    final normalized = hex.toUpperCase();
    return solidColors.any((bg) => bg.color?.toUpperCase() == normalized);
  }

  static bool isPresetGradient(List<String>? colors) {
    if (colors == null || colors.isEmpty) return false;
    final key = colors.map((c) => c.toUpperCase()).join(',');
    return gradients.any(
      (bg) =>
          (bg.gradientColors?.map((c) => c.toUpperCase()).join(',') ?? '') ==
          key,
    );
  }
}