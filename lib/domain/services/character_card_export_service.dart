import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/domain/services/import_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum CharacterCardExportFormat { png, charx, json }

/// Saves / shares exported character cards with a safe filename from [Character.name].
class CharacterCardExportService {
  final ImportService _importService;

  CharacterCardExportService(this._importService);

  static String sanitizeFileName(String name) {
    final cleaned = name
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return 'character';
    return cleaned.length > 120 ? cleaned.substring(0, 120).trim() : cleaned;
  }

  String fileNameFor(Character character, CharacterCardExportFormat format) {
    final base = sanitizeFileName(character.name);
    return switch (format) {
      CharacterCardExportFormat.png => '$base.png',
      CharacterCardExportFormat.charx => '$base.charx',
      CharacterCardExportFormat.json => '$base.json',
    };
  }

  Future<Uint8List> buildBytes(
    Character character,
    CharacterCardExportFormat format,
  ) async {
    switch (format) {
      case CharacterCardExportFormat.png:
        return _importService.exportToPng(character, null);
      case CharacterCardExportFormat.charx:
        return _importService.exportToCharX(character, null);
      case CharacterCardExportFormat.json:
        return Uint8List.fromList(
          utf8.encode(_importService.exportToJson(character)),
        );
    }
  }

  /// Desktop: save dialog. Mobile: share sheet from a temp file.
  /// Returns the saved path when written locally; null if user cancelled share-only.
  Future<String?> export(
    Character character,
    CharacterCardExportFormat format, {
    Rect? sharePositionOrigin,
  }) async {
    final bytes = await buildBytes(character, format);
    final fileName = fileNameFor(character, format);
    final extension = p.extension(fileName).replaceFirst('.', '');

    final isMobile = Platform.isAndroid || Platform.isIOS;
    if (isMobile) {
      final tempDir = await getTemporaryDirectory();
      final file = File(p.join(tempDir.path, fileName));
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: character.name,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      return file.path;
    }

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Character Card',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );
    if (result == null) return null;

    // Some platforms write via [bytes]; others only return a path.
    final file = File(result);
    if (!await file.exists() || await file.length() == 0) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return result;
  }
}
