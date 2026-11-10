import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Saves an on-device image into the public NativeTavern folder when possible.
///
/// Preference order:
/// 1. `Download/NativeTavern` (Android MediaStore / desktop Downloads)
/// 2. Gallery album `NativeTavern` via [Gal] (iOS / fallback)
class ImageSaveUtils {
  static const albumName = 'NativeTavern';
  static const downloadsFolderName = 'NativeTavern';
  static const _androidMediaChannel = MethodChannel('com.nativetavern/media');

  /// Copy [sourcePath] into Download/NativeTavern or the NativeTavern album.
  ///
  /// Throws on failure after permission/request attempts are exhausted.
  static Future<ImageSaveResult> saveImage(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('Image file not found');
    }

    final fileName = _uniqueFileName(p.basename(sourcePath));

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final saved = await _androidMediaChannel.invokeMethod<String>(
          'saveImageToDownloads',
          {
            'sourcePath': sourcePath,
            'fileName': fileName,
          },
        );
        return ImageSaveResult(
          path: saved,
          destination: ImageSaveDestination.downloadsFolder,
        );
      } catch (_) {
        // Fall through to gallery album if MediaStore write fails.
      }
    }

    final downloadsDir = await resolveNativeTavernDownloadsDirectory();
    if (downloadsDir != null) {
      final destPath = p.join(downloadsDir.path, fileName);
      await source.copy(destPath);
      return ImageSaveResult(
        path: destPath,
        destination: ImageSaveDestination.downloadsFolder,
      );
    }

    final hasAccess = await Gal.hasAccess(toAlbum: true).timeout(
      const Duration(seconds: 8),
    );
    if (!hasAccess) {
      final granted = await Gal.requestAccess(toAlbum: true).timeout(
        const Duration(seconds: 8),
      );
      if (!granted) {
        throw StateError('Photo library access denied');
      }
    }
    await Gal.putImage(sourcePath, album: albumName).timeout(
      const Duration(seconds: 15),
    );
    return const ImageSaveResult(
      destination: ImageSaveDestination.galleryAlbum,
    );
  }

  /// Public `Downloads/NativeTavern` when the platform allows creating it.
  ///
  /// Android uses a MethodChannel (MediaStore) instead of this path probe.
  static Future<Directory?> resolveNativeTavernDownloadsDirectory() async {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) return null;

    final downloads = await getDownloadsDirectory();
    if (downloads == null) return null;
    return _tryCreateWritableDirectory(
      p.join(downloads.path, downloadsFolderName),
    );
  }

  static Future<Directory?> _tryCreateWritableDirectory(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final probe = File(
        p.join(
          dir.path,
          '.nt_write_probe_${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return dir;
    } catch (_) {
      return null;
    }
  }

  static String _uniqueFileName(String originalName) {
    final ext = p.extension(originalName);
    final stem = p.basenameWithoutExtension(originalName);
    final safeStem = stem.trim().isEmpty ? 'image' : stem;
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    return '${safeStem}_$stamp$ext';
  }
}

enum ImageSaveDestination {
  downloadsFolder,
  galleryAlbum,
}

class ImageSaveResult {
  const ImageSaveResult({
    required this.destination,
    this.path,
  });

  final ImageSaveDestination destination;
  final String? path;
}
