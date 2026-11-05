import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/database/database.dart';
import 'package:native_tavern/data/models/character_folder.dart';
import 'package:uuid/uuid.dart';

final characterFolderRepositoryProvider =
    Provider<CharacterFolderRepository>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

class CharacterFolderRepository {
  CharacterFolderRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<CharacterFolder>> listFolders() async {
    final rows = await _db.customSelect(
      '''
      SELECT f.id AS id, f.name AS name, f.sort_order AS sort_order,
             f.created_at AS created_at,
             (
               SELECT COUNT(*)
               FROM character_folder_members m
               INNER JOIN characters c ON c.id = m.character_id
               WHERE m.folder_id = f.id AND c.is_deleted = 0
             ) AS character_count
      FROM character_folders f
      ORDER BY f.sort_order ASC, f.name ASC
      ''',
      readsFrom: const {},
    ).get();
    final previews = await _loadPreviewCharactersByFolder();
    return rows
        .map(_folderFromRow)
        .map(
          (folder) => folder.copyWith(
            previewCharacters: previews[folder.id] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  Future<CharacterFolder?> getFolder(String id) async {
    final row = await _db.customSelect(
      '''
      SELECT f.id AS id, f.name AS name, f.sort_order AS sort_order,
             f.created_at AS created_at,
             (
               SELECT COUNT(*)
               FROM character_folder_members m
               INNER JOIN characters c ON c.id = m.character_id
               WHERE m.folder_id = f.id AND c.is_deleted = 0
             ) AS character_count
      FROM character_folders f
      WHERE f.id = ?
      LIMIT 1
      ''',
      variables: [Variable<String>(id)],
      readsFrom: const {},
    ).getSingleOrNull();
    if (row == null) return null;
    final folder = _folderFromRow(row);
    final previews = await _loadPreviewCharactersByFolder(folderIds: {id});
    return folder.copyWith(
      previewCharacters: previews[id] ?? const [],
    );
  }

  Future<CharacterFolder> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name cannot be empty');
    }
    final maxOrder = await _maxSortOrder();
    final now = DateTime.now();
    final id = _uuid.v4();
    await _db.customStatement(
      'INSERT INTO character_folders (id, name, sort_order, created_at) '
      'VALUES (?, ?, ?, ?)',
      [id, trimmed, maxOrder + 1, now.millisecondsSinceEpoch],
    );
    return CharacterFolder(
      id: id,
      name: trimmed,
      sortOrder: maxOrder + 1,
      createdAt: now,
    );
  }

  Future<CharacterFolder> renameFolder(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name cannot be empty');
    }
    await _db.customStatement(
      'UPDATE character_folders SET name = ? WHERE id = ?',
      [trimmed, id],
    );
    final updated = await getFolder(id);
    if (updated == null) {
      throw StateError('Folder not found');
    }
    return updated;
  }

  Future<void> dissolveFolder(String id) async {
    await _db.customStatement(
      'DELETE FROM character_folder_members WHERE folder_id = ?',
      [id],
    );
    await _db.customStatement(
      'DELETE FROM character_folders WHERE id = ?',
      [id],
    );
  }

  Future<void> moveCharactersToFolder(
    Iterable<String> characterIds, {
    String? folderId,
  }) async {
    final ids = characterIds.toList(growable: false);
    if (ids.isEmpty) return;
    if (folderId != null) {
      final exists = await getFolder(folderId);
      if (exists == null) {
        throw StateError('Folder not found');
      }
    }
    await _db.transaction(() async {
      for (final characterId in ids) {
        await _db.customStatement(
          'DELETE FROM character_folder_members WHERE character_id = ?',
          [characterId],
        );
        if (folderId != null) {
          await _db.customStatement(
            'INSERT INTO character_folder_members (character_id, folder_id) '
            'VALUES (?, ?)',
            [characterId, folderId],
          );
        }
        await _db.customStatement(
          'UPDATE characters SET modified_at = ? WHERE id = ?',
          [DateTime.now().millisecondsSinceEpoch, characterId],
        );
      }
    });
  }

  Future<String?> folderIdForCharacter(String characterId) async {
    final row = await _db.customSelect(
      'SELECT folder_id FROM character_folder_members WHERE character_id = ?',
      variables: [Variable<String>(characterId)],
      readsFrom: const {},
    ).getSingleOrNull();
    return row?.read<String>('folder_id');
  }

  Future<int> _maxSortOrder() async {
    final row = await _db.customSelect(
      'SELECT MAX(sort_order) AS max_order FROM character_folders',
      readsFrom: const {},
    ).getSingleOrNull();
    return row?.read<int?>('max_order') ?? 0;
  }

  CharacterFolder _folderFromRow(QueryRow row) {
    final createdMs = row.read<int>('created_at');
    return CharacterFolder(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      sortOrder: row.read<int>('sort_order'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs),
      characterCount: row.read<int>('character_count'),
    );
  }

  Future<Map<String, List<CharacterFolderPreview>>> _loadPreviewCharactersByFolder({
    Set<String>? folderIds,
  }) async {
    final rows = await _db.customSelect(
      '''
      SELECT folder_id, id, name, assets_json
      FROM (
        SELECT m.folder_id AS folder_id,
               c.id AS id,
               c.name AS name,
               c.assets_json AS assets_json,
               ROW_NUMBER() OVER (
                 PARTITION BY m.folder_id
                 ORDER BY c.modified_at DESC
               ) AS rn
        FROM character_folder_members m
        INNER JOIN characters c ON c.id = m.character_id
        WHERE c.is_deleted = 0
      )
      WHERE rn <= 4
      ''',
      readsFrom: const {},
    ).get();

    final grouped = <String, List<CharacterFolderPreview>>{};
    for (final row in rows) {
      final folderId = row.read<String>('folder_id');
      if (folderIds != null && !folderIds.contains(folderId)) continue;
      grouped.putIfAbsent(folderId, () => []).add(
            CharacterFolderPreview(
              id: row.read<String>('id'),
              name: row.read<String>('name'),
              avatarPath: _avatarPathFromAssetsJson(
                row.read<String?>('assets_json'),
              ),
            ),
          );
    }
    return grouped;
  }

  String? _avatarPathFromAssetsJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return json['avatarPath'] as String?;
    } catch (_) {
      return null;
    }
  }
}
