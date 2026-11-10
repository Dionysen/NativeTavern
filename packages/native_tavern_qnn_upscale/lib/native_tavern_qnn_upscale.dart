import 'dart:async';

import 'package:flutter/services.dart';

/// Thin MethodChannel client for Android Qualcomm QNN upscale + local SD1.5 gen.
class NativeTavernQnnUpscale {
  static const channelName = 'native_tavern_qnn_upscale';
  static const eventChannelName = 'native_tavern_qnn_upscale/events';
  static const MethodChannel _channel = MethodChannel(channelName);
  static const EventChannel _events = EventChannel(eventChannelName);

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
        'generationAvailable': false,
        'hasNativeRuntime': false,
        'modelReady': false,
        'reason': 'Plugin not registered on this platform.',
      };
    }
  }

  Future<List<LocalQnnCatalogModel>> listModels() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('listModels');
      if (raw == null) return const [];
      return raw
          .whereType<Map<Object?, Object?>>()
          .map((m) => LocalQnnCatalogModel.fromMap(_stringKeyMap(m)))
          .toList();
    } on MissingPluginException {
      return const [];
    }
  }

  Future<void> downloadModel(String modelId) async {
    await _channel.invokeMethod<void>('downloadModel', {'modelId': modelId});
  }

  Future<void> cancelDownload() async {
    try {
      await _channel.invokeMethod<void>('cancelDownload');
    } on MissingPluginException {
      // ignore
    }
  }

  Future<LocalQnnBackendStatus> startModel(String modelId) async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'startModel',
      {'modelId': modelId},
    );
    return LocalQnnBackendStatus.fromMap(_stringKeyMap(raw));
  }

  Future<LocalQnnBackendStatus> stopModel() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'stopModel',
      );
      return LocalQnnBackendStatus.fromMap(_stringKeyMap(raw));
    } on MissingPluginException {
      return LocalQnnBackendStatus.idle;
    }
  }

  Future<LocalQnnBackendStatus> getBackendStatus() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getBackendStatus',
      );
      return LocalQnnBackendStatus.fromMap(_stringKeyMap(raw));
    } on MissingPluginException {
      return LocalQnnBackendStatus.idle;
    }
  }

  Stream<LocalQnnBackendStatus> backendEvents() {
    return _events.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return LocalQnnBackendStatus.fromMap(
          _stringKeyMap(Map<Object?, Object?>.from(event)),
        );
      }
      return LocalQnnBackendStatus.idle;
    });
  }

  Future<LocalQnnGenerateResult> generate({
    required String prompt,
    String negativePrompt = '',
    int steps = 20,
    double cfg = 7.0,
    int width = 512,
    int height = 512,
    int? seed,
    String scheduler = 'dpm',
  }) async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'generate',
      <String, dynamic>{
        'prompt': prompt,
        'negativePrompt': negativePrompt,
        'steps': steps,
        'cfg': cfg,
        'width': width,
        'height': height,
        'seed': seed,
        'scheduler': scheduler,
      },
    );
    final map = _stringKeyMap(raw);
    final bytes = map['bytes'];
    if (bytes is! Uint8List || bytes.isEmpty) {
      throw StateError('Empty generate response');
    }
    return LocalQnnGenerateResult(
      bytes: bytes,
      seed: map['seed'] is int ? map['seed'] as int : null,
      width: map['width'] is int ? map['width'] as int : width,
      height: map['height'] is int ? map['height'] as int : height,
      format: map['format']?.toString() ?? 'jpg',
    );
  }

  Future<void> stopGenerate() async {
    try {
      await _channel.invokeMethod<void>('stopGenerate');
    } on MissingPluginException {
      // ignore
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

class LocalQnnCatalogModel {
  const LocalQnnCatalogModel({
    required this.id,
    required this.name,
    required this.approximateSize,
    required this.downloaded,
    this.defaultPrompt = '',
    this.defaultNegativePrompt = '',
  });

  final String id;
  final String name;
  final String approximateSize;
  final bool downloaded;
  final String defaultPrompt;
  final String defaultNegativePrompt;

  factory LocalQnnCatalogModel.fromMap(Map<String, dynamic> map) {
    return LocalQnnCatalogModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      approximateSize: map['approximateSize']?.toString() ?? '',
      downloaded: map['downloaded'] == true,
      defaultPrompt: map['defaultPrompt']?.toString() ?? '',
      defaultNegativePrompt: map['defaultNegativePrompt']?.toString() ?? '',
    );
  }
}

class LocalQnnBackendStatus {
  const LocalQnnBackendStatus({
    required this.state,
    this.modelId,
    this.modelName,
    this.progress,
    this.message,
  });

  static const idle = LocalQnnBackendStatus(state: 'idle');

  final String state;
  final String? modelId;
  final String? modelName;
  final double? progress;
  final String? message;

  bool get isReady => state == 'ready';
  bool get isLoading =>
      state == 'starting' || state == 'loading' || state == 'stopping';
  bool get isBusy =>
      isLoading || state == 'downloading' || state == 'generating';

  factory LocalQnnBackendStatus.fromMap(Map<String, dynamic> map) {
    final progressRaw = map['progress'];
    return LocalQnnBackendStatus(
      state: map['state']?.toString() ?? 'idle',
      modelId: map['modelId']?.toString(),
      modelName: map['modelName']?.toString(),
      progress: progressRaw is num ? progressRaw.toDouble() : null,
      message: map['message']?.toString(),
    );
  }
}

class LocalQnnGenerateResult {
  const LocalQnnGenerateResult({
    required this.bytes,
    this.seed,
    required this.width,
    required this.height,
    this.format = 'jpg',
  });

  final Uint8List bytes;
  final int? seed;
  final int width;
  final int height;
  final String format;
}
