import 'package:flutter/foundation.dart';
import 'package:native_tavern/domain/services/image_upscale/image_upscale_backend.dart';
import 'package:native_tavern_qnn_upscale/native_tavern_qnn_upscale.dart';

/// Android Snapdragon backend that talks to the QNN anime upscaler plugin.
class QnnAnimeUpscaleBackend implements ImageUpscaleBackend {
  final NativeTavernQnnUpscale _plugin;

  QnnAnimeUpscaleBackend({NativeTavernQnnUpscale? plugin})
      : _plugin = plugin ?? const NativeTavernQnnUpscale();

  @override
  Future<ImageUpscaleCapability> getCapability() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const ImageUpscaleCapability.unavailable(
        'QNN anime upscale is Android Snapdragon only.',
      );
    }
    try {
      final map = await _plugin.getCapability();
      final available = map['available'] == true;
      return ImageUpscaleCapability(
        available: available,
        soc: map['soc'] as String?,
        modelSuffix: map['modelSuffix'] as String?,
        hasNativeRuntime: map['hasNativeRuntime'] == true,
        modelReady: map['modelReady'] == true,
        reason: map['reason'] as String?,
      );
    } catch (error) {
      return ImageUpscaleCapability.unavailable('$error');
    }
  }

  @override
  Future<void> ensureReady() => _plugin.ensureModel();

  @override
  Future<Uint8List> upscale(ImageUpscaleRequest request) {
    return _plugin.upscale(
      bytes: request.bytes,
      width: request.width,
      height: request.height,
      targetScale: request.targetScale,
    );
  }

  @override
  Future<void> dispose() => _plugin.disposeBackend();
}
