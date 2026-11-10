import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:native_tavern/domain/services/image_upscale/image_upscale_backend.dart';
import 'package:native_tavern/domain/services/image_upscale/noop_image_upscale_backend.dart';

/// Result of running the independent upscale stage.
class ImageUpscaleStageResult {
  final List<Uint8List> images;
  final int scale;
  final bool didUpscale;

  const ImageUpscaleStageResult({
    required this.images,
    required this.scale,
    required this.didUpscale,
  });
}

/// Independent post-generation stage: optionally upscale before chat display.
///
/// Failures and unsupported devices return [didUpscale] false with the
/// original image bytes unchanged.
class ImageUpscaleStage {
  static const maxInputLongSide = 1024;
  static const nativeScale = 4;

  final ImageUpscaleBackend backend;
  final void Function(double progress)? onProgress;

  const ImageUpscaleStage({
    this.backend = const NoopImageUpscaleBackend(),
    this.onProgress,
  });

  Future<ImageUpscaleStageResult> apply({
    required List<Uint8List> images,
    required bool enabled,
    required int targetScale,
  }) async {
    if (!enabled || images.isEmpty) {
      return ImageUpscaleStageResult(
        images: images,
        scale: targetScale,
        didUpscale: false,
      );
    }

    final scale = targetScale.clamp(2, nativeScale);
    try {
      final capability = await backend.getCapability();
      if (!capability.available) {
        debugPrint(
          'ImageUpscaleStage skipped: ${capability.reason ?? "unavailable"}',
        );
        return ImageUpscaleStageResult(
          images: images,
          scale: scale,
          didUpscale: false,
        );
      }

      onProgress?.call(0.86);
      await backend.ensureReady();
      onProgress?.call(0.90);

      final out = <Uint8List>[];
      var anyUpscaled = false;
      for (var i = 0; i < images.length; i++) {
        final bytes = images[i];
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          out.add(bytes);
          continue;
        }
        final longSide =
            decoded.width > decoded.height ? decoded.width : decoded.height;
        if (longSide > maxInputLongSide) {
          debugPrint(
            'ImageUpscaleStage skip image $i: long side $longSide > $maxInputLongSide',
          );
          out.add(bytes);
          continue;
        }

        try {
          var upscaled = await backend.upscale(
            ImageUpscaleRequest(
              bytes: bytes,
              width: decoded.width,
              height: decoded.height,
              targetScale: scale,
            ),
          );
          if (scale != nativeScale) {
            upscaled = _resizeEncoded(
              upscaled,
              decoded.width * scale,
              decoded.height * scale,
            );
          }
          out.add(upscaled);
          anyUpscaled = true;
        } catch (error, stack) {
          debugPrint('ImageUpscaleStage image $i failed: $error\n$stack');
          out.add(bytes);
        }
        final t = 0.90 + (0.09 * ((i + 1) / images.length));
        onProgress?.call(t.clamp(0.0, 0.99));
      }

      onProgress?.call(1.0);
      return ImageUpscaleStageResult(
        images: out,
        scale: scale,
        didUpscale: anyUpscaled,
      );
    } catch (error, stack) {
      debugPrint('ImageUpscaleStage failed: $error\n$stack');
      return ImageUpscaleStageResult(
        images: images,
        scale: scale,
        didUpscale: false,
      );
    }
  }

  static Uint8List _resizeEncoded(Uint8List bytes, int width, int height) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    if (decoded.width == width && decoded.height == height) return bytes;
    final resized = img.copyResize(
      decoded,
      width: width,
      height: height,
      interpolation: img.Interpolation.cubic,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 92));
  }
}
