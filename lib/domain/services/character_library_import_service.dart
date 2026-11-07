import 'dart:io';

import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/models/regex_script.dart';
import 'package:native_tavern/data/repositories/character_folder_repository.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/data/repositories/world_info_repository.dart';
import 'package:native_tavern/domain/services/character_regex_import_service.dart';
import 'package:native_tavern/domain/services/import_service.dart';
import 'package:native_tavern/domain/services/world_info_import.dart';
import 'package:path/path.dart' as p;

class CharacterLibraryImportProgress {
  const CharacterLibraryImportProgress({
    required this.total,
    required this.processed,
    required this.succeeded,
    required this.failed,
    required this.skipped,
    this.currentFile,
  });

  final int total;
  final int processed;
  final int succeeded;
  final int failed;
  final int skipped;
  final String? currentFile;
}

class CharacterLibraryImportResult {
  const CharacterLibraryImportResult({
    required this.succeeded,
    required this.failed,
    required this.skipped,
    this.errors = const [],
  });

  final int succeeded;
  final int failed;
  final int skipped;
  final List<String> errors;
}

/// One-shot recursive folder import into DB, preserving relative paths as
/// nested [character_folders].
class CharacterLibraryImportService {
  CharacterLibraryImportService({
    required ImportService importService,
    required CharacterRepository characterRepository,
    required CharacterFolderRepository folderRepository,
    required WorldInfoRepository worldInfoRepository,
    required Future<void> Function(
      String characterId,
      List<RegexScript> scripts,
    ) importEmbeddedRegex,
  })  : _importService = importService,
        _characterRepository = characterRepository,
        _folderRepository = folderRepository,
        _worldInfoRepository = worldInfoRepository,
        _importEmbeddedRegex = importEmbeddedRegex;

  final ImportService _importService;
  final CharacterRepository _characterRepository;
  final CharacterFolderRepository _folderRepository;
  final WorldInfoRepository _worldInfoRepository;
  final Future<void> Function(String characterId, List<RegexScript> scripts)
      _importEmbeddedRegex;

  static const _supportedExtensions = {'.png', '.json', '.charx'};

  Future<CharacterLibraryImportResult> importFromDirectory(
    String rootPath, {
    void Function(CharacterLibraryImportProgress progress)? onProgress,
  }) async {
    final root = Directory(rootPath);
    if (!await root.exists()) {
      throw StateError('Directory not found');
    }

    final files = <File>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (!_supportedExtensions.contains(ext)) continue;
      files.add(entity);
    }
    files.sort((a, b) => a.path.compareTo(b.path));

    var succeeded = 0;
    var failed = 0;
    var skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final relative = p.normalize(p.relative(file.path, from: root.path));
      onProgress?.call(
        CharacterLibraryImportProgress(
          total: files.length,
          processed: i,
          succeeded: succeeded,
          failed: failed,
          skipped: skipped,
          currentFile: relative,
        ),
      );

      try {
        final character = await _decodeFile(file);
        if (character == null) {
          skipped++;
          continue;
        }

        final dirRelative = p.dirname(relative);
        final segments = (dirRelative == '.' || dirRelative.isEmpty)
            ? const <String>[]
            : p
                .split(dirRelative)
                .where((s) => s.isNotEmpty && s != '.')
                .toList(growable: false);
        final folderId = await _folderRepository.ensureFolderPath(segments);

        final created = await _characterRepository.createCharacter(character);
        if (folderId != null) {
          await _folderRepository.moveCharactersToFolder(
            [created.id],
            folderId: folderId,
          );
        }

        final embeddedRegex = parseEmbeddedRegexScripts(
          created.extensions,
          characterId: created.id,
        );
        if (embeddedRegex.isNotEmpty) {
          await _importEmbeddedRegex(created.id, embeddedRegex);
        }

        final book = created.characterBook;
        if (book != null && book.entries.isNotEmpty) {
          await _importEmbeddedLorebook(created.id, book, created.name);
        }

        succeeded++;
      } catch (e) {
        failed++;
        errors.add('$relative: $e');
      }
    }

    onProgress?.call(
      CharacterLibraryImportProgress(
        total: files.length,
        processed: files.length,
        succeeded: succeeded,
        failed: failed,
        skipped: skipped,
      ),
    );

    return CharacterLibraryImportResult(
      succeeded: succeeded,
      failed: failed,
      skipped: skipped,
      errors: errors,
    );
  }

  Future<Character?> _decodeFile(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    switch (ext) {
      case '.png':
        return _importService.importFromPng(file.path);
      case '.charx':
        return _importService.importFromCharX(file.path);
      case '.json':
        return _importService.importFromJson(await file.readAsString());
      default:
        return null;
    }
  }

  Future<void> _importEmbeddedLorebook(
    String characterId,
    CharacterBook characterBook,
    String characterName,
  ) async {
    final worldInfoName = characterBook.name ?? '$characterName Lorebook';
    final worldInfo = await _worldInfoRepository.createWorldInfo(
      name: worldInfoName,
      description:
          characterBook.description ?? 'Embedded lorebook from $characterName',
      isGlobal: false,
      characterId: characterId,
      recursionDepth: characterBook.recursiveScanning ? null : 0,
      extensions: {
        ...characterBook.extensions,
        'token_budget': characterBook.tokenBudget,
        'recursive_scanning': characterBook.recursiveScanning,
        'from_character_book': true,
      },
    );

    final parsedEntries = WorldInfoImport.parseCharacterBookEntries(
      characterBook,
      worldInfo.id,
    );

    for (final entry in parsedEntries) {
      final created = await _worldInfoRepository.addEntry(
        worldInfoId: worldInfo.id,
        keys: entry.keys,
        content: entry.content,
        secondaryKeys:
            entry.secondaryKeys.isNotEmpty ? entry.secondaryKeys : null,
        comment: entry.comment,
        position: entry.position,
        constant: entry.constant,
        selective: entry.selective,
        insertionOrder: entry.insertionOrder,
        depth: entry.depth,
      );
      await _worldInfoRepository.updateEntry(entry.copyWith(id: created.id));
    }
  }
}
