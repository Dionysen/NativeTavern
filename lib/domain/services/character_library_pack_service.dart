import 'dart:convert';
import 'dart:io';

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

  /// `folders` | `characters` | `avatars` | `zip` | `import`
  final String phase;
  final String? currentName;
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

      final ndjson = StringBuffer();
      var avatarCount = 0;
      final usedAvatarNames = <String>{};

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

        ndjson.writeln(jsonEncode(exported.toJson()));
      }

      await File(p.join(staging.path, 'characters.ndjson'))
          .writeAsString(ndjson.toString());

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
    final packFile = File(packPath);
    if (!await packFile.exists()) {
      throw StateError('Pack file not found');
    }

    final tempRoot = await Directory.systemTemp.createTemp('ntchars_import_');
    try {
      final extractDir = Directory(p.join(tempRoot.path, 'pack'));
      await extractDir.create(recursive: true);

      final input = InputFileStream(packPath);
      final archive = ZipDecoder().decodeBuffer(input);
      for (final file in archive.files) {
        if (!file.isFile || file.name.isEmpty) continue;
        // Zip slip: keep entries under the extract directory.
        final outPath = p.normalize(p.join(extractDir.path, file.name));
        if (!p.isWithin(extractDir.path, outPath) &&
            outPath != extractDir.path) {
          continue;
        }
        final content = file.content;
        if (content is! List<int>) continue;
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(content, flush: true);
      }

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
      final lines = (await ndjsonFile.readAsLines())
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);

      var created = 0;
      var updated = 0;
      var failed = 0;
      var avatarCount = 0;
      final errors = <String>[];
      final importedCharacterIds = <String>{};

      for (var i = 0; i < lines.length; i++) {
        try {
          final json = jsonDecode(lines[i]) as Map<String, dynamic>;
          var character = Character.fromJson(json);
          if (character.id.isEmpty) {
            throw StateError('Character id missing');
          }
          onProgress?.call(
            CharacterLibraryPackProgress(
              total: lines.length,
              processed: i,
              phase: 'import',
              currentName: character.name,
            ),
          );

          final avatarRelative = character.assets?.avatarPath;
          if (avatarRelative != null && avatarRelative.trim().isNotEmpty) {
            final packed = File(p.join(staging.path, avatarRelative));
            if (await packed.exists()) {
              final destRelative = _normalizeAvatarRelative(
                characterId: character.id,
                packRelative: avatarRelative,
              );
              final dest = File(p.join(_dataPath, destRelative));
              await dest.parent.create(recursive: true);
              await packed.copy(dest.path);
              avatarCount++;
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
          errors.add('line ${i + 1}: $e');
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
          total: lines.length,
          processed: lines.length,
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
