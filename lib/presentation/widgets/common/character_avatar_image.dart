import 'dart:io';
import 'package:flutter/material.dart';
import 'package:native_tavern/core/utils/path_utils.dart';

/// Widget that displays character avatar image
/// Handles both absolute and relative paths for mobile compatibility
class CharacterAvatarImage extends StatelessWidget {
  final String imagePath;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Widget Function(BuildContext, Object?, StackTrace?)? errorBuilder;

  const CharacterAvatarImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: PathUtils.toAbsolutePath(imagePath),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final file = File(snapshot.data!);
          return Image.file(
            file,
            fit: fit,
            alignment: alignment,
            errorBuilder: errorBuilder,
          );
        } else if (snapshot.hasError) {
          // Path resolution failed, try original path as fallback
          final file = File(imagePath);
          return Image.file(
            file,
            fit: fit,
            alignment: alignment,
            errorBuilder: errorBuilder,
          );
        } else {
          // Loading
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
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
    final fallback = ColoredBox(
      color: fallbackColor ?? scheme.primary,
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
class CharacterBackgroundImage extends StatelessWidget {
  final String imagePath;
  final Widget Function(BuildContext, Object?, StackTrace?)? errorBuilder;

  const CharacterBackgroundImage({
    super.key,
    required this.imagePath,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: PathUtils.toAbsolutePath(imagePath),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final file = File(snapshot.data!);
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: errorBuilder ?? (_, __, ___) => Container(color: Colors.black),
          );
        } else if (snapshot.hasError) {
          final file = File(imagePath);
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: errorBuilder ?? (_, __, ___) => Container(color: Colors.black),
          );
        } else {
          return Container(color: Colors.black);
        }
      },
    );
  }
}
