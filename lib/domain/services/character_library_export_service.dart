import 'dart:io';

import 'package:native_tavern/data/repositories/character_folder_repository.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/domain/services/character_card_export_service.dart';
import 'package:path/path.dart' as p;

class CharacterLibraryExportProgress {
  const CharacterLibraryExportProgress({
    required this.total,
    required this.processed,
    required this.succeeded,
    required this.failed,
    this.currentName,
  });

  final int total;
  final int processed;
  final int succeeded;
  final int failed;
  final String? currentName;
}

class CharacterLibraryExportResult {
  const CharacterLibraryExportResult({
    required this.succeeded,
    required this.failed,
    this.errors = const [],
  });

  final int succeeded;
  final int failed;
  final List<String> errors;
}

/// Exports the whole character library to a directory tree matching folder
/// membership. Default format is PNG (same pipeline as single-card export).
class CharacterLibraryExportService {
  CharacterLibraryExportService({
    required CharacterRepository characterRepository,
    required CharacterFolderRepository folderRepository,
    required CharacterCardExportService exportService,
  })  : _characterRepository = characterRepository,
        _folderRepository = folderRepository,
        _exportService = exportService;

  final CharacterRepository _characterRepository;
  final CharacterFolderRepository _folderRepository;
  final CharacterCardExportService _exportService;

  Future<CharacterLibraryExportResult> exportToDirectory(
    String rootPath, {
    CharacterCardExportFormat format = CharacterCardExportFormat.png,
    void Function(CharacterLibraryExportProgress progress)? onProgress,
  }) async {
    final root = Directory(rootPath);
    await root.create(recursive: true);

    final characters = await _characterRepository.getAllCharacters();
    final membership = await _folderRepository.folderIdsByCharacter();
    final pathCache = <String, String>{};

    var succeeded = 0;
    var failed = 0;
    final errors = <String>[];
    final usedNamesByDir = <String, Set<String>>{};

    for (var i = 0; i < characters.length; i++) {
      final character = characters[i];
      onProgress?.call(
        CharacterLibraryExportProgress(
          total: characters.length,
          processed: i,
          succeeded: succeeded,
          failed: failed,
          currentName: character.name,
        ),
      );

      try {
        final folderId = membership[character.id];
        String relativeDir = '';
        if (folderId != null) {
          relativeDir = pathCache[folderId] ??=
              await _folderRepository.relativePathForFolder(folderId);
        }

        final outDir = relativeDir.isEmpty
            ? root
            : Directory(p.join(root.path, relativeDir));
        await outDir.create(recursive: true);

        final baseName = CharacterCardExportService.sanitizeFileName(
          character.name,
        );
        final extension = switch (format) {
          CharacterCardExportFormat.png => '.png',
          CharacterCardExportFormat.charx => '.charx',
          CharacterCardExportFormat.json => '.json',
        };
        final used = usedNamesByDir.putIfAbsent(outDir.path, () => <String>{});
        var fileName = '$baseName$extension';
        if (used.contains(fileName.toLowerCase())) {
          final shortId = character.id.length >= 8
              ? character.id.substring(0, 8)
              : character.id;
          fileName = '$baseName-$shortId$extension';
        }
        used.add(fileName.toLowerCase());

        final bytes = await _exportService.buildBytes(character, format);
        final outFile = File(p.join(outDir.path, fileName));
        await outFile.writeAsBytes(bytes, flush: true);
        succeeded++;
      } catch (e) {
        failed++;
        errors.add('${character.name}: $e');
      }
    }

    onProgress?.call(
      CharacterLibraryExportProgress(
        total: characters.length,
        processed: characters.length,
        succeeded: succeeded,
        failed: failed,
      ),
    );

    return CharacterLibraryExportResult(
      succeeded: succeeded,
      failed: failed,
      errors: errors,
    );
  }
}
