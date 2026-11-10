import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:native_tavern/domain/services/image_generation_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// One saved generation in the on-device gallery.
class ImageGenHistoryEntry {
  const ImageGenHistoryEntry({
    required this.id,
    required this.createdAt,
    required this.imagePath,
    required this.format,
    required this.byteSize,
    required this.prompt,
    this.negativePrompt = '',
    required this.width,
    required this.height,
    required this.steps,
    required this.cfgScale,
    required this.sampler,
    this.scheduler,
    this.model,
    this.seed,
    this.provider,
    this.upscaled = false,
    this.upscaleScale,
    this.originalImagePath,
    this.originalWidth,
    this.originalHeight,
  });

  final String id;
  final DateTime createdAt;
  final String imagePath;
  final String format;
  final int byteSize;
  final String prompt;
  final String negativePrompt;
  final int width;
  final int height;
  final int steps;
  final double cfgScale;
  final String sampler;
  final String? scheduler;
  final String? model;
  final int? seed;
  final String? provider;
  final bool upscaled;
  final int? upscaleScale;

  /// Pre-upscale image path when [upscaled] is true.
  final String? originalImagePath;
  final int? originalWidth;
  final int? originalHeight;

  bool get hasComparableOriginal {
    final path = originalImagePath;
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }

  String get sizeLabel {
    if (byteSize < 1024) return '$byteSize B';
    if (byteSize < 1024 * 1024) {
      return '${(byteSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(byteSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'imagePath': imagePath,
        'format': format,
        'byteSize': byteSize,
        'prompt': prompt,
        'negativePrompt': negativePrompt,
        'width': width,
        'height': height,
        'steps': steps,
        'cfgScale': cfgScale,
        'sampler': sampler,
        'scheduler': scheduler,
        'model': model,
        'seed': seed,
        'provider': provider,
        'upscaled': upscaled,
        'upscaleScale': upscaleScale,
        if (originalImagePath != null) 'originalImagePath': originalImagePath,
        if (originalWidth != null) 'originalWidth': originalWidth,
        if (originalHeight != null) 'originalHeight': originalHeight,
      };

  factory ImageGenHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ImageGenHistoryEntry(
      id: json['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      imagePath: json['imagePath']?.toString() ?? '',
      format: json['format']?.toString() ?? 'png',
      byteSize: (json['byteSize'] as num?)?.toInt() ?? 0,
      prompt: json['prompt']?.toString() ?? '',
      negativePrompt: json['negativePrompt']?.toString() ?? '',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      cfgScale: (json['cfgScale'] as num?)?.toDouble() ?? 0,
      sampler: json['sampler']?.toString() ?? '',
      scheduler: json['scheduler']?.toString(),
      model: json['model']?.toString(),
      seed: (json['seed'] as num?)?.toInt(),
      provider: json['provider']?.toString(),
      upscaled: json['upscaled'] == true,
      upscaleScale: (json['upscaleScale'] as num?)?.toInt(),
      originalImagePath: json['originalImagePath']?.toString(),
      originalWidth: (json['originalWidth'] as num?)?.toInt(),
      originalHeight: (json['originalHeight'] as num?)?.toInt(),
    );
  }
}

/// Persists generated images + prompt/params for the settings gallery.
class ImageGenHistoryService {
  ImageGenHistoryService({Directory? rootOverride}) : _rootOverride = rootOverride;

  final Directory? _rootOverride;
  static const _uuid = Uuid();
  static const _folderName = 'image_gen_gallery';

  Future<Directory> _rootDir() async {
    final override = _rootOverride;
    if (override != null) return override;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _folderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<ImageGenHistoryEntry>> listEntries() async {
    final root = await _rootDir();
    final files = root
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    final entries = <ImageGenHistoryEntry>[];
    for (final file in files) {
      try {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final entry = ImageGenHistoryEntry.fromJson(json);
        if (entry.id.isEmpty) continue;
        if (!File(entry.imagePath).existsSync()) continue;
        entries.add(entry);
      } catch (e, st) {
        debugPrint('ImageGenHistory skip ${file.path}: $e\n$st');
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  /// Save each image from [result] with request parameters.
  ///
  /// When the result was upscaled, [sourceImages] are also saved so the gallery
  /// can compare before/after.
  Future<List<ImageGenHistoryEntry>> record({
    required ImageGenRequest request,
    required ImageGenResult result,
    required ImageGenSettings settings,
    List<Uint8List>? sourceImages,
    String sourceFormat = 'png',
  }) async {
    if (result.images.isEmpty) return const [];
    final root = await _rootDir();
    final created = <ImageGenHistoryEntry>[];
    final provider = settings.provider.id;
    final upscaled = result.metadata?['upscaled'] == true;
    final upscaleScale = (result.metadata?['upscaleScale'] as num?)?.toInt();
    final negative = request.negativePrompt ??
        settings.defaultNegativePrompt ??
        '';

    for (var i = 0; i < result.images.length; i++) {
      final bytes = result.images[i];
      final id = _uuid.v4();
      final format = result.format.isNotEmpty ? result.format : 'png';
      final imagePath = p.join(root.path, '$id.$format');
      await File(imagePath).writeAsBytes(bytes, flush: true);

      String? originalImagePath;
      if (upscaled &&
          sourceImages != null &&
          i < sourceImages.length &&
          sourceImages[i].isNotEmpty) {
        final origExt = sourceFormat.isNotEmpty ? sourceFormat : 'png';
        originalImagePath = p.join(root.path, '${id}_original.$origExt');
        await File(originalImagePath).writeAsBytes(sourceImages[i], flush: true);
      }

      final width = upscaled && upscaleScale != null
          ? request.width * upscaleScale
          : request.width;
      final height = upscaled && upscaleScale != null
          ? request.height * upscaleScale
          : request.height;

      final entry = ImageGenHistoryEntry(
        id: id,
        createdAt: DateTime.now(),
        imagePath: imagePath,
        format: format,
        byteSize: bytes.length,
        prompt: result.prompt.isNotEmpty ? result.prompt : request.prompt,
        negativePrompt: negative,
        width: width,
        height: height,
        steps: request.steps,
        cfgScale: request.cfgScale,
        sampler: request.sampler,
        scheduler: request.scheduler ?? settings.defaultScheduler,
        model: request.model ?? settings.model,
        seed: result.seed >= 0 ? result.seed : request.seed,
        provider: provider,
        upscaled: upscaled,
        upscaleScale: upscaleScale,
        originalImagePath: originalImagePath,
        originalWidth: originalImagePath != null ? request.width : null,
        originalHeight: originalImagePath != null ? request.height : null,
      );
      await File(p.join(root.path, '$id.json'))
          .writeAsString(jsonEncode(entry.toJson()), flush: true);
      created.add(entry);
    }
    return created;
  }

  Future<void> delete(String id) async {
    final root = await _rootDir();
    final meta = File(p.join(root.path, '$id.json'));
    if (await meta.exists()) {
      try {
        final json = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
        final path = json['imagePath']?.toString();
        if (path != null && path.isNotEmpty) {
          final image = File(path);
          if (await image.exists()) await image.delete();
        }
        final original = json['originalImagePath']?.toString();
        if (original != null && original.isNotEmpty) {
          final image = File(original);
          if (await image.exists()) await image.delete();
        }
      } catch (_) {}
      await meta.delete();
    }
    // Also remove any leftover image with this id.
    for (final file in root.listSync().whereType<File>()) {
      final name = p.basenameWithoutExtension(file.path);
      if ((name == id || name == '${id}_original') &&
          !file.path.endsWith('.json')) {
        await file.delete();
      }
    }
  }
}
