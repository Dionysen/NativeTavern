import 'dart:typed_data';

/// Capability report for a platform-specific upscale backend.
class ImageUpscaleCapability {
  final bool available;
  final String? soc;
  final String? modelSuffix;
  final bool hasNativeRuntime;
  final bool modelReady;
  final String? reason;

  const ImageUpscaleCapability({
    required this.available,
    this.soc,
    this.modelSuffix,
    this.hasNativeRuntime = false,
    this.modelReady = false,
    this.reason,
  });

  const ImageUpscaleCapability.unavailable([this.reason])
      : available = false,
        soc = null,
        modelSuffix = null,
        hasNativeRuntime = false,
        modelReady = false;
}

/// One image to upscale.
class ImageUpscaleRequest {
  final Uint8List bytes;
  final int width;
  final int height;

  /// Desired output scale relative to the source (2, 3, or 4).
  /// Native anime QNN models always run at 4×; smaller scales are resized.
  final int targetScale;

  const ImageUpscaleRequest({
    required this.bytes,
    required this.width,
    required this.height,
    this.targetScale = 4,
  });
}

/// Platform-specific super-resolution backend.
abstract class ImageUpscaleBackend {
  const ImageUpscaleBackend();

  Future<ImageUpscaleCapability> getCapability();

  /// Download / prepare weights when the device can run upscale.
  Future<void> ensureReady();

  /// Upscale a single encoded image. Returns encoded bytes (typically JPEG).
  Future<Uint8List> upscale(ImageUpscaleRequest request);

  Future<void> dispose() async {}
}
