import 'dart:io';

import 'package:path/path.dart' as p;

/// On-disk moments cover image, one file per persona.
class MomentsCoverStorage {
  MomentsCoverStorage._();

  static String coverFilePath(String dataPath, String personaId) {
    return p.join(dataPath, 'personas', personaId, 'moments_cover.jpg');
  }

  /// Resolves the cover path synchronously when [dataPath] is already known.
  static String? existingCoverPathSync(String dataPath, String personaId) {
    final file = File(coverFilePath(dataPath, personaId));
    if (file.existsSync()) return file.path;
    return null;
  }

  static Future<String> saveCover(
    String dataPath,
    String personaId,
    String sourcePath,
  ) async {
    final file = File(coverFilePath(dataPath, personaId));
    await file.parent.create(recursive: true);
    await File(sourcePath).copy(file.path);
    return file.path;
  }
}
