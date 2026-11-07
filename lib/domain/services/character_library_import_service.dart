import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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

class _DecodedImport {
  const _DecodedImport({
    required this.relative,
    required this.folderKey,
    this.character,
    this.error,
    this.skipped = false,
  });

  final String relative;
  final String folderKey;
  final Character? character;
  final Object? error;
  final bool skipped;
}

/// One-shot recursive folder import into DB, preserving relative paths as
/// nested [character_folders].
///
/// File decode / avatar write runs with bounded concurrency; folder ensure and
/// DB writes stay serialized to avoid SQLite and path races.
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
    int? concurrency,
  })  : _importService = importService,
        _characterRepository = characterRepository,
        _folderRepository = folderRepository,
        _worldInfoRepository = worldInfoRepository,
        _importEmbeddedRegex = importEmbeddedRegex,
        _concurrency = concurrency ?? _defaultConcurrency();

  final ImportService _importService;
  final CharacterRepository _characterRepository;
  final CharacterFolderRepository _folderRepository;
  final WorldInfoRepository _worldInfoRepository;
  final Future<void> Function(String characterId, List<RegexScript> scripts)
      _importEmbeddedRegex;
  final int _concurrency;

  static const _supportedExtensions = {'.png', '.json', '.charx'};

  static int _defaultConcurrency() {
    final cpus = Platform.numberOfProcessors;
    return math.max(2, math.min(8, cpus));
  }

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

    if (files.isEmpty) {
      onProgress?.call(
        const CharacterLibraryImportProgress(
          total: 0,
          processed: 0,
          succeeded: 0,
          failed: 0,
          skipped: 0,
        ),
      );
      return const CharacterLibraryImportResult(
        succeeded: 0,
        failed: 0,
        skipped: 0,
      );
    }

    // Pre-create unique folder paths once (avoids races under parallel workers).
    final folderIdsByKey = <String, String?>{};
    for (final file in files) {
      final relative = p.normalize(p.relative(file.path, from: root.path));
      final key = _folderKeyForRelative(relative);
      if (folderIdsByKey.containsKey(key)) continue;
      folderIdsByKey[key] = await _folderRepository.ensureFolderPath(
        _segmentsForFolderKey(key),
      );
    }

    var succeeded = 0;
    var failed = 0;
    var skipped = 0;
    var processed = 0;
    final errors = <String>[];
    Future<void> persistChain = Future<void>.value();

    void report(String? currentFile) {
      onProgress?.call(
        CharacterLibraryImportProgress(
          total: files.length,
          processed: processed,
          succeeded: succeeded,
          failed: failed,
          skipped: skipped,
          currentFile: currentFile,
        ),
      );
    }

    report(null);

    Future<void> enqueuePersist(Future<void> Function() work) {
      final previous = persistChain;
      final done = Completer<void>();
      persistChain = done.future;
      return previous.then((_) => work()).whenComplete(done.complete);
    }

    await _forEachPool(
      files,
      concurrency: _concurrency,
      action: (file) async {
        final relative = p.normalize(p.relative(file.path, from: root.path));
        final folderKey = _folderKeyForRelative(relative);

        _DecodedImport decoded;
        try {
          final character = await _decodeFile(file);
          if (character == null) {
            decoded = _DecodedImport(
              relative: relative,
              folderKey: folderKey,
              skipped: true,
            );
          } else {
            decoded = _DecodedImport(
              relative: relative,
              folderKey: folderKey,
              character: character,
            );
          }
        } catch (e) {
          decoded = _DecodedImport(
            relative: relative,
            folderKey: folderKey,
            error: e,
          );
        }

        await enqueuePersist(() async {
          try {
            if (decoded.error != null) {
              failed++;
              errors.add('${decoded.relative}: ${decoded.error}');
            } else if (decoded.skipped || decoded.character == null) {
              skipped++;
            } else {
              final created = await _characterRepository
                  .createCharacter(decoded.character!);
              final folderId = folderIdsByKey[decoded.folderKey];
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
            }
          } catch (e) {
            failed++;
            errors.add('${decoded.relative}: $e');
          } finally {
            processed++;
            report(decoded.relative);
          }
        });
      },
    );

    await persistChain;

    report(null);

    return CharacterLibraryImportResult(
      succeeded: succeeded,
      failed: failed,
      skipped: skipped,
      errors: errors,
    );
  }

  static String _folderKeyForRelative(String relative) {
    final dirRelative = p.dirname(relative);
    if (dirRelative == '.' || dirRelative.isEmpty) return '';
    return p.normalize(dirRelative);
  }

  static List<String> _segmentsForFolderKey(String key) {
    if (key.isEmpty) return const [];
    return p
        .split(key)
        .where((s) => s.isNotEmpty && s != '.')
        .toList(growable: false);
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

Future<void> _forEachPool<T>(
  List<T> items, {
  required int concurrency,
  required Future<void> Function(T item) action,
}) async {
  if (items.isEmpty) return;
  var next = 0;

  Future<void> worker() async {
    while (true) {
      final index = next;
      next++;
      if (index >= items.length) return;
      await action(items[index]);
    }
  }

  await Future.wait(
    List.generate(
      math.min(concurrency, items.length),
      (_) => worker(),
    ),
  );
}
