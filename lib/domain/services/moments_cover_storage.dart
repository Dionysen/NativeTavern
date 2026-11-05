import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-disk moments cover image, one file per persona.
class MomentsCoverStorage {
  MomentsCoverStorage._();

  static Future<File> _coverFile(String personaId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(appDir.path, 'NativeTavern', 'personas', personaId),
    );
    await dir.create(recursive: true);
    return File(p.join(dir.path, 'moments_cover.jpg'));
  }

  static Future<String?> existingCoverPath(String personaId) async {
    final file = await _coverFile(personaId);
    if (await file.exists()) return file.path;
    return null;
  }

  static Future<String> saveCover(String personaId, String sourcePath) async {
    final file = await _coverFile(personaId);
    await File(sourcePath).copy(file.path);
    return file.path;
  }
}
