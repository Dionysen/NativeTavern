import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/chat_background.dart';
import '../../../core/utils/path_utils.dart';
import '../../providers/background_providers.dart';
import '../../theme/native_tavern_theme.dart';
import '../common/character_avatar_image.dart';

Color parseBackgroundHexColor(String? hexColor) {
  if (hexColor == null || hexColor.isEmpty) return Colors.transparent;
  var hex = hexColor.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

/// Continuous angle → alignment. 0° = top, clockwise.
Alignment backgroundAngleToAlignment(double angle) {
  final rad = angle * math.pi / 180.0;
  return Alignment(math.sin(rad), -math.cos(rad));
}

/// Builds a Flutter [Gradient] from [ChatBackground] gradient fields.
Gradient backgroundFillGradient(ChatBackground background) {
  final colors = (background.gradientColors ?? ['#000000', '#333333'])
      .map(parseBackgroundHexColor)
      .toList();
  if (background.gradientStyle == BackgroundGradientStyle.radial) {
    return RadialGradient(
      center: Alignment.center,
      radius: background.gradientRadius.clamp(0.15, 2.0),
      colors: colors,
    );
  }
  final angle = background.gradientAngle ?? 180;
  return LinearGradient(
    begin: backgroundAngleToAlignment(angle),
    end: backgroundAngleToAlignment(angle + 180),
    colors: colors,
  );
}

/// Widget that renders a chat background
class ChatBackgroundWidget extends ConsumerWidget {
  final String? characterId;
  final Widget child;

  const ChatBackgroundWidget({
    super.key,
    this.characterId,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundAsync = ref.watch(effectiveBackgroundProvider(characterId));
    final chatBackground = context.appChatColors.chatBackground;

    Widget withBase(Widget foreground) => Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: chatBackground),
            foreground,
          ],
        );

    return backgroundAsync.when(
      data: (background) {
        if (background.type == BackgroundType.none) {
          return withBase(child);
        }

        return withBase(
          Stack(
            fit: StackFit.expand,
            children: [
              _BackgroundRenderer(background: background),
              child,
            ],
          ),
        );
      },
      loading: () => withBase(child),
      error: (_, __) => withBase(child),
    );
  }
}

class _BackgroundRenderer extends StatelessWidget {
  final ChatBackground background;

  const _BackgroundRenderer({required this.background});

  @override
  Widget build(BuildContext context) {
    Widget backgroundWidget;

    switch (background.type) {
      case BackgroundType.none:
        return const SizedBox.shrink();

      case BackgroundType.color:
        backgroundWidget = Container(
          color: _parseColor(background.color),
        );
        break;

      case BackgroundType.gradient:
        backgroundWidget = Container(
          decoration: BoxDecoration(
            gradient: backgroundFillGradient(background),
          ),
        );
        break;

      case BackgroundType.image:
        backgroundWidget = _buildImageBackground();
        break;
    }

    // Apply opacity
    if (background.opacity < 1.0) {
      backgroundWidget = Opacity(
        opacity: background.opacity,
        child: backgroundWidget,
      );
    }

    // Apply blur
    if (background.blur && background.blurAmount > 0) {
      backgroundWidget = Stack(
        fit: StackFit.expand,
        children: [
          backgroundWidget,
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: background.blurAmount,
              sigmaY: background.blurAmount,
            ),
            child: Container(color: Colors.transparent),
          ),
        ],
      );
    }

    return backgroundWidget;
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return Colors.transparent;
    }

    String hex = hexColor.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  Widget _buildImageBackground() {
    if (background.imagePath != null && background.imagePath!.isNotEmpty) {
      // Use CharacterBackgroundImage for automatic path resolution
      return CharacterBackgroundImage(
        imagePath: background.imagePath!,
        errorBuilder: (context, error, stackTrace) {
          return Container(color: Colors.black);
        },
      );
    }

    if (background.imageUrl != null && background.imageUrl!.isNotEmpty) {
      return Image.network(
        background.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(color: Colors.black);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }

    return Container(color: Colors.black);
  }
}

/// Preview widget for background selection
class BackgroundPreview extends StatelessWidget {
  final ChatBackground background;
  final double size;
  final bool selected;
  final VoidCallback? onTap;

  const BackgroundPreview({
    super.key,
    required this.background,
    this.size = 60,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = 8.0;
    final borderWidth = selected ? 3.0 : 1.0;
    // Keep border and clip on separate layers — clipping the same box that
    // paints the border leaves gaps at rounded corners.
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outline.withValues(alpha: 0.35),
              width: borderWidth,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(borderWidth),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                (radius - borderWidth).clamp(0, radius),
              ),
              child: _buildPreview(scheme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(ColorScheme scheme) {
    switch (background.type) {
      case BackgroundType.none:
        return ColoredBox(
          color: scheme.surfaceContainerHigh,
          child: Center(
            child: Icon(Icons.block, color: scheme.onSurfaceVariant),
          ),
        );

      case BackgroundType.color:
        return Container(
          color: _parseColor(background.color),
        );

      case BackgroundType.gradient:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: backgroundFillGradient(background),
          ),
        );

      case BackgroundType.image:
        if (background.imagePath != null) {
          return FutureBuilder<String>(
            future: PathUtils.toAbsolutePath(background.imagePath!),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Image.file(
                  File(snapshot.data!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey[800]),
                );
              }
              return Container(color: Colors.grey[800]);
            },
          );
        }
        if (background.imageUrl != null) {
          return Image.network(
            background.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.grey[800]),
          );
        }
        return Container(color: Colors.grey[800]);
    }
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return Colors.transparent;
    }

    String hex = hexColor.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}