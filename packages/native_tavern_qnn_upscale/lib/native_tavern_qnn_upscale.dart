import 'package:flutter/services.dart';

/// Thin MethodChannel client for the Android Qualcomm anime upscaler.
class NativeTavernQnnUpscale {
  static const channelName = 'native_tavern_qnn_upscale';
  static const MethodChannel _channel = MethodChannel(channelName);

  const NativeTavernQnnUpscale();

  Future<Map<String, dynamic>> getCapability() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getCapability',
      );
      return _stringKeyMap(raw);
    } on MissingPluginException {
      return const {
        'available': false,
        'hasNativeRuntime': false,
        'modelReady': false,
        'reason': 'Plugin not registered on this platform.',
      };
    }
  }

  Future<void> ensureModel() async {
    await _channel.invokeMethod<void>('ensureModel');
  }

  /// Upscales an encoded image. Native always returns JPEG at 4×.
  Future<Uint8List> upscale({
    required Uint8List bytes,
    required int width,
    required int height,
    int targetScale = 4,
  }) async {
    final raw = await _channel.invokeMethod<Uint8List>(
      'upscale',
      <String, dynamic>{
        'bytes': bytes,
        'width': width,
        'height': height,
        'targetScale': targetScale,
      },
    );
    if (raw == null || raw.isEmpty) {
      throw StateError('Empty upscale response');
    }
    return raw;
  }

  Future<void> disposeBackend() async {
    try {
      await _channel.invokeMethod<void>('dispose');
    } on MissingPluginException {
      // Ignore on platforms without the plugin.
    }
  }

  static Map<String, dynamic> _stringKeyMap(Map<Object?, Object?>? raw) {
    if (raw == null) return const {};
    return {
      for (final entry in raw.entries) entry.key.toString(): entry.value,
    };
  }
}
