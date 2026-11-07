import 'dart:io';

import 'package:flutter/material.dart';
import 'package:native_tavern/core/utils/path_utils.dart';
import 'package:path/path.dart' as p;

/// Fill color for characters that have no avatar image.
/// Built-in assistants keep distinct accents; everyone else uses the theme primary.
Color characterAvatarFallbackColor(ColorScheme scheme, [String? characterId]) {
  switch (characterId) {
    case 'builtin_coding_assistant':
      return const Color(0xFF2196F3);
    case 'builtin_image_gen_assistant':
      return const Color(0xFFE91E63);
    case 'builtin_xiaohongshu_copywriter':
      return const Color(0xFFFF5722);
    default:
      return scheme.primary;
  }
}

IconData characterAvatarFallbackIcon([String? characterId]) {
  switch (characterId) {
    case 'builtin_coding_assistant':
      return Icons.code;
    case 'builtin_image_gen_assistant':
      return Icons.image;
    case 'builtin_xiaohongshu_copywriter':
      return Icons.edit_note;
    default:
      return Icons.person;
  }
}

final Map<String, Future<String?>> _avatarPathResolveCache = {};

/// Resolves a stored avatar path (relative or absolute) to a readable file path.
///
/// Returns null when the file cannot be found so callers never pass a bare
/// relative path like `avatars/…` into [Image.file] / [FileImage].
Future<String?> resolveAvatarFilePath(String imagePath) {
  final trimmed = imagePath.trim();
  if (trimmed.isEmpty) return Future<String?>.value(null);
  return _avatarPathResolveCache.putIfAbsent(trimmed, () async {
    try {
      final absolute = await PathUtils.toAbsolutePath(trimmed);
      if (await File(absolute).exists()) return absolute;
    } catch (_) {
      // Fall through to direct absolute check.
    }
    if (p.isAbsolute(trimmed)) {
      try {
        if (await File(trimmed).exists()) return trimmed;
      } catch (_) {}
    }
    return null;
  });
}

int? _decodePixels(BuildContext context, double? logicalSize) {
  if (logicalSize == null || logicalSize <= 0) return null;
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (logicalSize * dpr).round().clamp(1, 4096);
}

/// Widget that displays character avatar image
/// Handles both absolute and relative paths for mobile compatibility
class CharacterAvatarImage extends StatefulWidget {
  final String imagePath;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Widget Function(BuildContext, Object?, StackTrace?)? errorBuilder;

  /// Logical width used for [Image.file] decode downsampling.
  final double? cacheWidth;

  /// Logical height used for [Image.file] decode downsampling.
  final double? cacheHeight;

  const CharacterAvatarImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.errorBuilder,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  State<CharacterAvatarImage> createState() => _CharacterAvatarImageState();
}

class _CharacterAvatarImageState extends State<CharacterAvatarImage> {
  Future<String?>? _resolvedPath;
  bool _decodeEnabled = false;

  @override
  void initState() {
    super.initState();
    // Defer path resolve + decode until after the first frame so opening the
    // character tab can paint placeholders without a decode storm.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _decodeEnabled = true;
        _resolvedPath = resolveAvatarFilePath(widget.imagePath);
      });
    });
  }

  @override
  void didUpdateWidget(covariant CharacterAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _resolvedPath = resolveAvatarFilePath(widget.imagePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Solid placeholder only — dozens of CircularProgressIndicators on first
    // open were a major source of jank.
    final loading = ColoredBox(color: scheme.surfaceContainerHigh);
    final missing = widget.errorBuilder?.call(
          context,
          StateError('Avatar file missing'),
          StackTrace.empty,
        ) ??
        ColoredBox(color: scheme.surfaceContainerHigh);

    if (!_decodeEnabled || _resolvedPath == null) {
      return loading;
    }

    return FutureBuilder<String?>(
      future: _resolvedPath,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return loading;
        }
        final path = snapshot.data;
        if (path == null) {
          return missing;
        }
        return Image.file(
          File(path),
          fit: widget.fit,
          alignment: widget.alignment,
          cacheWidth: _decodePixels(context, widget.cacheWidth),
          cacheHeight: _decodePixels(context, widget.cacheHeight),
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          errorBuilder: widget.errorBuilder ?? (_, __, ___) => missing,
        );
      },
    );
  }
}

/// Circular avatar variant
class CharacterAvatarCircle extends StatelessWidget {
  final String imagePath;
  final double radius;
  final Widget Function(BuildContext, Object?, StackTrace?)? errorBuilder;

  const CharacterAvatarCircle({
    super.key,
    required this.imagePath,
    this.radius = 28,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return CharacterAvatarShaped(
      imagePath: imagePath,
      width: radius * 2,
      height: radius * 2,
      shape: BoxShape.circle,
      errorBuilder: errorBuilder,
    );
  }
}

/// Avatar clipped as circle, rounded square, or portrait rectangle.
class CharacterAvatarShaped extends StatelessWidget {
  final String? imagePath;
  final double width;
  final double height;
  final BoxShape shape;
  final double borderRadius;
  final Color? fallbackColor;
  final IconData fallbackIcon;
  final Widget Function(BuildContext, Object?, StackTrace?)? errorBuilder;

  const CharacterAvatarShaped({
    super.key,
    this.imagePath,
    required this.width,
    required this.height,
    this.shape = BoxShape.circle,
    this.borderRadius = 8,
    this.fallbackColor,
    this.fallbackIcon = Icons.person,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = fallbackColor ?? scheme.primary;
    final fallback = ColoredBox(
      color: fill,
      child: Center(
        child: Icon(
          fallbackIcon,
          color: scheme.onPrimary,
          size: width * 0.45,
        ),
      ),
    );

    final child = imagePath == null
        ? fallback
        : CharacterAvatarImage(
            imagePath: imagePath!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            cacheWidth: width,
            cacheHeight: height,
            errorBuilder: errorBuilder ?? (_, __, ___) => fallback,
          );

    return SizedBox(
      width: width,
      height: height,
      child: shape == BoxShape.circle
          ? ClipOval(child: child)
          : ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: child,
            ),
    );
  }
}

/// Background image variant
class CharacterBackgroundImage extends StatefulWidget {
  final String imagePath;
  final Widget Function(BuildContext, Object?, StackTrace?)? errorBuilder;

  const CharacterBackgroundImage({
    super.key,
    required this.imagePath,
    this.errorBuilder,
  });

  @override
  State<CharacterBackgroundImage> createState() =>
      _CharacterBackgroundImageState();
}

class _CharacterBackgroundImageState extends State<CharacterBackgroundImage> {
  late Future<String?> _resolvedPath;

  @override
  void initState() {
    super.initState();
    _resolvedPath = resolveAvatarFilePath(widget.imagePath);
  }

  @override
  void didUpdateWidget(covariant CharacterBackgroundImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _resolvedPath = resolveAvatarFilePath(widget.imagePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.errorBuilder?.call(
          context,
          StateError('Background missing'),
          StackTrace.empty,
        ) ??
        const ColoredBox(color: Colors.black);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cacheW = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : null;
        final cacheH =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : null;
        return FutureBuilder<String?>(
          future: _resolvedPath,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ColoredBox(color: Colors.black);
            }
            final path = snapshot.data;
            if (path == null) {
              return fallback;
            }
            return Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: _decodePixels(context, cacheW),
              cacheHeight: _decodePixels(context, cacheH),
              filterQuality: FilterQuality.medium,
              errorBuilder: widget.errorBuilder ?? (_, __, ___) => fallback,
            );
          },
        );
      },
    );
  }
}
