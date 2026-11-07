import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:native_tavern/core/utils/path_utils.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/models/character_folder.dart';
import 'package:native_tavern/data/repositories/character_folder_repository.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:path/path.dart' as p;

class CharacterLibraryPackProgress {
  const CharacterLibraryPackProgress({
    required this.total,
    required this.processed,
    required this.phase,
    this.currentName,
  });

  final int total;
  final int processed;

  /// `preparing` | `folders` | `characters` | `avatars` | `zip` | `import`
  final String phase;
  final String? currentName;

  bool get isIndeterminate =>
      phase == 'preparing' || total <= 0 || processed < 0;
}

class CharacterLibraryPackExportResult {
  const CharacterLibraryPackExportResult({
    required this.path,
    required this.characterCount,
    required this.folderCount,
    required this.avatarCount,
  });

  final String path;
  final int characterCount;
  final int folderCount;
  final int avatarCount;
}

class CharacterLibraryPackImportResult {
  const CharacterLibraryPackImportResult({
    required this.created,
    required this.updated,
    required this.failed,
    required this.folderCount,
    required this.avatarCount,
    this.errors = const [],
  });

  final int created;
  final int updated;
  final int failed;
  final int folderCount;
  final int avatarCount;
  final List<String> errors;
}

/// Fast single-file character library backup (`.ntchars` zip).
///
/// Contains character rows, folder tree, membership, and raw avatar files.
/// Skips PNG card encode/decode used by the folder tree export.
class CharacterLibraryPackService {
  CharacterLibraryPackService({
    required CharacterRepository characterRepository,
    required CharacterFolderRepository folderRepository,
    required String dataPath,
  })  : _characterRepository = characterRepository,
        _folderRepository = folderRepository,
        _dataPath = dataPath;

  static const formatName = 'ntchars';
  static const formatVersion = 1;
  static const fileExtension = 'ntchars';

  final CharacterRepository _characterRepository;
  final CharacterFolderRepository _folderRepository;
  final String _dataPath;

  Future<CharacterLibraryPackExportResult> exportToFile(
    String outputPath, {
    void Function(CharacterLibraryPackProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      const CharacterLibraryPackProgress(
        total: 0,
        processed: 0,
        phase: 'preparing',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final tempRoot = await Directory.systemTemp.createTemp('ntchars_export_');
    try {
      final staging = Directory(p.join(tempRoot.path, 'pack'));
      await staging.create(recursive: true);
      final avatarsDir = Directory(p.join(staging.path, 'avatars'));
      await avatarsDir.create(recursive: true);

      final folders = await _folderRepository.listAllFolders();
      onProgress?.call(
        CharacterLibraryPackProgress(
          total: folders.length,
          processed: folders.length,
          phase: 'folders',
        ),
      );

      final characters = await _characterRepository.getAllCharacters();
      final membership = await _folderRepository.folderIdsByCharacter();

      final foldersJson = folders
          .map(
            (folder) => {
              'id': folder.id,
              'name': folder.name,
              'parentId': folder.parentId,
              'sortOrder': folder.sortOrder,
              'createdAt': folder.createdAt.toIso8601String(),
            },
          )
          .toList(growable: false);
      await File(p.join(staging.path, 'folders.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(foldersJson),
      );

      final characterIds = {for (final c in characters) c.id};
      final membersJson = [
        for (final entry in membership.entries)
          if (characterIds.contains(entry.key))
            {'characterId': entry.key, 'folderId': entry.value},
      ];
      await File(p.join(staging.path, 'members.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(membersJson),
      );

      final ndjsonFile = File(p.join(staging.path, 'characters.ndjson'));
      final ndjsonSink = ndjsonFile.openWrite();
      var avatarCount = 0;
      final usedAvatarNames = <String>{};

      try {
        for (var i = 0; i < characters.length; i++) {
          final character = characters[i];
          onProgress?.call(
            CharacterLibraryPackProgress(
              total: characters.length,
              processed: i,
              phase: 'characters',
              currentName: character.name,
            ),
          );

          var exported = character;
          final sourcePath = character.assets?.avatarPath;
          if (sourcePath != null && sourcePath.trim().isNotEmpty) {
            final absolute = await _resolveExistingAvatar(sourcePath);
            if (absolute != null) {
              final packRelative = _uniqueAvatarPackPath(
                characterId: character.id,
                sourceAbsolute: absolute,
                usedNames: usedAvatarNames,
              );
              final dest = File(p.join(staging.path, packRelative));
              await dest.parent.create(recursive: true);
              await File(absolute).copy(dest.path);
              avatarCount++;
              exported = character.copyWith(
                assets: (character.assets ?? const CharacterAssets()).copyWith(
                  avatarPath: packRelative,
                ),
              );
              onProgress?.call(
                CharacterLibraryPackProgress(
                  total: characters.length,
                  processed: i,
                  phase: 'avatars',
                  currentName: character.name,
                ),
              );
            }
          }

          ndjsonSink.writeln(jsonEncode(exported.toJson()));
          if (i % 32 == 0) {
            await Future<void>.delayed(Duration.zero);
          }
        }
      } finally {
        await ndjsonSink.close();
      }

      final manifest = {
        'format': formatName,
        'version': formatVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'characterCount': characters.length,
        'folderCount': folders.length,
        'avatarCount': avatarCount,
      };
      await File(p.join(staging.path, 'manifest.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
      );

      onProgress?.call(
        const CharacterLibraryPackProgress(
          total: 1,
          processed: 0,
          phase: 'zip',
        ),
      );

      final outFile = File(outputPath);
      await outFile.parent.create(recursive: true);
      if (await outFile.exists()) {
        await outFile.delete();
      }

      // STORE: avatars are already compressed; skip re-gzip for speed.
      // Use sync zipDirectory — async addDirectory writes entries in parallel
      // and can corrupt the central directory.
      ZipFileEncoder().zipDirectory(
        staging,
        filename: outputPath,
        level: ZipFileEncoder.STORE,
      );

      onProgress?.call(
        const CharacterLibraryPackProgress(
          total: 1,
          processed: 1,
          phase: 'zip',
        ),
      );

      return CharacterLibraryPackExportResult(
        path: outputPath,
        characterCount: characters.length,
        folderCount: folders.length,
        avatarCount: avatarCount,
      );
    } finally {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    }
  }

  Future<CharacterLibraryPackImportResult> importFromFile(
    String packPath, {
    void Function(CharacterLibraryPackProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      const CharacterLibraryPackProgress(
        total: 0,
        processed: 0,
        phase: 'preparing',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final packFile = File(packPath);
    if (!await packFile.exists()) {
      throw StateError('Pack file not found');
    }

    final tempRoot = await Directory.systemTemp.createTemp('ntchars_import_');
    try {
      final extractDir = Directory(p.join(tempRoot.path, 'pack'));
      await extractDir.create(recursive: true);

      onProgress?.call(
        const CharacterLibraryPackProgress(
          total: 0,
          processed: 0,
          phase: 'preparing',
          currentName: 'zip',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      // Stream zip entries to disk — never materialize the whole  archive in RAM.
      // Avatar entries go straight into the app data dir to avoid a second copy.
      final extractedAvatarRelPaths = await _extractPackStreaming(
        packPath: packPath,
        metadataDir: extractDir,
        onProgress: onProgress,
      );

      final staging = await _resolvePackRoot(extractDir);
      final manifestFile = File(p.join(staging.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        throw StateError('Invalid character library pack');
      }
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      if (manifest['format'] != formatName) {
        throw StateError('Unsupported pack format');
      }
      final version = manifest['version'];
      if (version is! int || version > formatVersion) {
        throw StateError('Unsupported pack version');
      }
      final characterTotal = manifest['characterCount'] is int
          ? manifest['characterCount'] as int
          : 0;

      final foldersRaw =
          jsonDecode(await File(p.join(staging.path, 'folders.json')).readAsString())
              as List<dynamic>;
      final folders = foldersRaw
          .map((raw) => _folderFromJson(raw as Map<String, dynamic>))
          .toList(growable: false);
      final orderedFolders = _foldersParentsFirst(folders);

      for (var i = 0; i < orderedFolders.length; i++) {
        final folder = orderedFolders[i];
        onProgress?.call(
          CharacterLibraryPackProgress(
            total: orderedFolders.length,
            processed: i,
            phase: 'folders',
            currentName: folder.name,
          ),
        );
        await _folderRepository.upsertFolder(folder);
      }

      final existingIds = await _characterRepository.listAllCharacterIds();
      final ndjsonFile = File(p.join(staging.path, 'characters.ndjson'));

      var created = 0;
      var updated = 0;
      var failed = 0;
      var avatarCount = 0;
      var processed = 0;
      final errors = <String>[];
      final importedCharacterIds = <String>{};

      await for (final line in ndjsonFile
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        processed++;
        try {
          final json = jsonDecode(trimmed) as Map<String, dynamic>;
          var character = Character.fromJson(json);
          if (character.id.isEmpty) {
            throw StateError('Character id missing');
          }
          onProgress?.call(
            CharacterLibraryPackProgress(
              total: characterTotal == 0 ? processed : characterTotal,
              processed: processed - 1,
              phase: 'import',
              currentName: character.name,
            ),
          );

          final avatarRelative = character.assets?.avatarPath?.trim();
          if (avatarRelative != null && avatarRelative.isNotEmpty) {
            final destRelative = _normalizeAvatarRelative(
              characterId: character.id,
              packRelative: avatarRelative,
            );
            final dest = File(p.join(_dataPath, destRelative));
            // Prefer the entry already streamed into dataPath; fall back to
            // metadata-dir extract for older/odd packs.
            if (!await dest.exists()) {
              final packed = File(p.join(staging.path, avatarRelative));
              if (await packed.exists()) {
                await dest.parent.create(recursive: true);
                await packed.copy(dest.path);
              }
            }
            if (await dest.exists()) {
              avatarCount++;
              extractedAvatarRelPaths.remove(avatarRelative.replaceAll('\\', '/'));
              character = character.copyWith(
                assets: (character.assets ?? const CharacterAssets()).copyWith(
                  avatarPath: destRelative,
                ),
              );
            }
          }

          final existed = existingIds.contains(character.id);
          await _characterRepository.upsertCharacter(character);
          importedCharacterIds.add(character.id);
          if (existed) {
            updated++;
          } else {
            created++;
            existingIds.add(character.id);
          }
        } catch (e) {
          failed++;
          if (errors.length < 50) {
            errors.add('line $processed: $e');
          }
        }
        if (processed % 16 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      final membersRaw = jsonDecode(
        await File(p.join(staging.path, 'members.json')).readAsString(),
      ) as List<dynamic>;
      final membership = <String, String?>{
        for (final id in importedCharacterIds) id: null,
      };
      for (final raw in membersRaw) {
        final map = raw as Map<String, dynamic>;
        final characterId = map['characterId'] as String?;
        final folderId = map['folderId'] as String?;
        if (characterId == null || !importedCharacterIds.contains(characterId)) {
          continue;
        }
        membership[characterId] = folderId;
      }
      await _folderRepository.replaceMemberships(membership);

      onProgress?.call(
        CharacterLibraryPackProgress(
          total: processed,
          processed: processed,
          phase: 'import',
        ),
      );

      return CharacterLibraryPackImportResult(
        created: created,
        updated: updated,
        failed: failed,
        folderCount: orderedFolders.length,
        avatarCount: avatarCount,
        errors: errors,
      );
    } finally {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    }
  }

  /// Extracts `.ntchars` without loading the whole archive into memory.
  ///
  /// Heavy zip work runs in a background isolate so the UI can show a preparing
  /// progress bar instead of freezing on large packs.
  Future<Set<String>> _extractPackStreaming({
    required String packPath,
    required Directory metadataDir,
    void Function(CharacterLibraryPackProgress progress)? onProgress,
  }) async {
    final receive = ReceivePort();
    final isolate = await Isolate.spawn(
      _extractPackIsolateMain,
      _ExtractPackIsolateRequest(
        sendPort: receive.sendPort,
        packPath: packPath,
        metadataDirPath: metadataDir.path,
        dataPath: _dataPath,
      ),
    );

    try {
      await for (final message in receive) {
        if (message is _ExtractPackProgressMessage) {
          onProgress?.call(
            CharacterLibraryPackProgress(
              total: message.total,
              processed: message.processed,
              phase: message.phase,
              currentName: message.currentName,
            ),
          );
          continue;
        }
        if (message is _ExtractPackDoneMessage) {
          if (message.error != null) {
            throw StateError(message.error!);
          }
          return message.avatarPaths.toSet();
        }
      }
      throw StateError('Pack extract isolate ended unexpectedly');
    } finally {
      receive.close();
      isolate.kill(priority: Isolate.immediate);
    }
  }

  /// Suggested filename for a new pack export.
  static String suggestedFileName([DateTime? at]) {
    final stamp = (at ?? DateTime.now())
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .split('.')
        .first;
    return 'NativeTavern_characters_$stamp.$fileExtension';
  }

  Future<String?> _resolveExistingAvatar(String storedPath) async {
    try {
      final absolute = await PathUtils.toAbsolutePath(storedPath);
      if (await File(absolute).exists()) return absolute;
    } catch (_) {}
    if (p.isAbsolute(storedPath) && await File(storedPath).exists()) {
      return storedPath;
    }
    final joined = p.join(_dataPath, storedPath);
    if (await File(joined).exists()) return joined;
    return null;
  }

  String _uniqueAvatarPackPath({
    required String characterId,
    required String sourceAbsolute,
    required Set<String> usedNames,
  }) {
    final ext = p.extension(sourceAbsolute);
    final safeExt = ext.isEmpty ? '.png' : ext.toLowerCase();
    var name = '$characterId$safeExt';
    if (usedNames.contains(name)) {
      name = '${characterId}_${usedNames.length}$safeExt';
    }
    usedNames.add(name);
    return p.join('avatars', name);
  }

  String _normalizeAvatarRelative({
    required String characterId,
    required String packRelative,
  }) {
    final ext = p.extension(packRelative);
    final safeExt = ext.isEmpty ? '.png' : ext.toLowerCase();
    return p.join('avatars', '$characterId$safeExt');
  }

  CharacterFolder _folderFromJson(Map<String, dynamic> json) {
    return CharacterFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parentId'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  List<CharacterFolder> _foldersParentsFirst(List<CharacterFolder> folders) {
    final byId = {for (final folder in folders) folder.id: folder};
    final remaining = folders.map((f) => f.id).toSet();
    final ordered = <CharacterFolder>[];
    while (remaining.isNotEmpty) {
      final ready = remaining.where((id) {
        final parentId = byId[id]!.parentId;
        return parentId == null || !remaining.contains(parentId);
      }).toList(growable: false);
      if (ready.isEmpty) {
        // Cycle / missing parent — append rest as-is.
        ordered.addAll(remaining.map((id) => byId[id]!));
        break;
      }
      for (final id in ready) {
        ordered.add(byId[id]!);
        remaining.remove(id);
      }
    }
    return ordered;
  }

  Future<Directory> _resolvePackRoot(Directory extractDir) async {
    final direct = File(p.join(extractDir.path, 'manifest.json'));
    if (await direct.exists()) return extractDir;
    await for (final entity in extractDir.list()) {
      if (entity is Directory) {
        final nested = File(p.join(entity.path, 'manifest.json'));
        if (await nested.exists()) return entity;
      }
    }
    return extractDir;
  }
}

class _ExtractPackIsolateRequest {
  const _ExtractPackIsolateRequest({
    required this.sendPort,
    required this.packPath,
    required this.metadataDirPath,
    required this.dataPath,
  });

  final SendPort sendPort;
  final String packPath;
  final String metadataDirPath;
  final String dataPath;
}

class _ExtractPackProgressMessage {
  const _ExtractPackProgressMessage({
    required this.phase,
    required this.total,
    required this.processed,
    this.currentName,
  });

  final String phase;
  final int total;
  final int processed;
  final String? currentName;
}

class _ExtractPackDoneMessage {
  const _ExtractPackDoneMessage({
    required this.avatarPaths,
    this.error,
  });

  final List<String> avatarPaths;
  final String? error;
}

void _extractPackIsolateMain(_ExtractPackIsolateRequest request) {
  final send = request.sendPort;
  try {
    send.send(
      const _ExtractPackProgressMessage(
        phase: 'preparing',
        total: 0,
        processed: 0,
      ),
    );

    final input = InputFileStream(request.packPath);
    try {
      final archive = ZipDecoder().decodeBuffer(input);
      final files = archive.files;
      final total = files.length;
      final extractedAvatars = <String>[];

      send.send(
        _ExtractPackProgressMessage(
          phase: 'avatars',
          total: total,
          processed: 0,
        ),
      );

      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        if (!file.isFile || file.name.isEmpty) {
          file.clear();
          continue;
        }
        final relative = p.normalize(file.name.replaceAll('\\', '/'));
        if (relative.isEmpty ||
            relative == '.' ||
            relative.startsWith('../') ||
            relative.contains('/../')) {
          file.clear();
          continue;
        }

        final isAvatar =
            relative == 'avatars' || relative.startsWith('avatars/');
        final outPath = isAvatar
            ? p.normalize(p.join(request.dataPath, relative))
            : p.normalize(p.join(request.metadataDirPath, relative));
        final root = isAvatar ? request.dataPath : request.metadataDirPath;
        if (!p.isWithin(root, outPath) && outPath != root) {
          file.clear();
          continue;
        }

        Directory(p.dirname(outPath)).createSync(recursive: true);
        final output = OutputFileStream(outPath);
        try {
          file.writeContent(output);
        } finally {
          output.closeSync();
          file.clear();
        }
        if (isAvatar) {
          extractedAvatars.add(relative);
        }

        if (i % 8 == 0 || i == files.length - 1) {
          send.send(
            _ExtractPackProgressMessage(
              phase: 'avatars',
              total: total,
              processed: i + 1,
              currentName: relative,
            ),
          );
        }
      }
      archive.clear();
      send.send(_ExtractPackDoneMessage(avatarPaths: extractedAvatars));
    } finally {
      input.closeSync();
    }
  } catch (e) {
    send.send(
      _ExtractPackDoneMessage(avatarPaths: const [], error: '$e'),
    );
  }
}
