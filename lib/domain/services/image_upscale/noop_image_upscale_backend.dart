import 'dart:typed_data';

import 'package:native_tavern/domain/services/image_upscale/image_upscale_backend.dart';

/// Default backend: never available, so the upscale stage is skipped.
class NoopImageUpscaleBackend implements ImageUpscaleBackend {
  const NoopImageUpscaleBackend();

  @override
  Future<ImageUpscaleCapability> getCapability() async {
    return const ImageUpscaleCapability.unavailable(
      'Upscale is not implemented on this platform.',
    );
  }

  @override
  Future<void> ensureReady() async {}

  @override
  Future<Uint8List> upscale(ImageUpscaleRequest request) {
    throw UnsupportedError('NoopImageUpscaleBackend cannot upscale.');
  }

  @override
  Future<void> dispose() async {}
}
