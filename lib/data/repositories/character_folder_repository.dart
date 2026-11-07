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

  static const _folderSelect = '''
      SELECT f.id AS id, f.name AS name, f.parent_id AS parent_id,
             f.sort_order AS sort_order, f.created_at AS created_at,
             (
               SELECT COUNT(*)
               FROM character_folder_members m
               INNER JOIN characters c ON c.id = m.character_id
               WHERE m.folder_id = f.id AND c.is_deleted = 0
             ) AS character_count
      FROM character_folders f
  ''';

  /// Lists folders under [parentId] (`null` = library root).
  Future<List<CharacterFolder>> listFolders({String? parentId}) async {
    final rows = await _db.customSelect(
      '''
      $_folderSelect
      WHERE ${parentId == null ? 'f.parent_id IS NULL' : 'f.parent_id = ?'}
      ORDER BY f.sort_order ASC, f.name ASC
      ''',
      variables: parentId == null ? const [] : [Variable<String>(parentId)],
      readsFrom: const {},
    ).get();
    return _hydrateFolders(rows);
  }

  /// Flat list of every folder (any depth).
  Future<List<CharacterFolder>> listAllFolders() async {
    final rows = await _db.customSelect(
      '''
      $_folderSelect
      ORDER BY f.sort_order ASC, f.name ASC
      ''',
      readsFrom: const {},
    ).get();
    return _hydrateFolders(rows);
  }

  Future<CharacterFolder?> getFolder(String id) async {
    final row = await _db.customSelect(
      '''
      $_folderSelect
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

  /// Name segments from library root to [folderId] (inclusive).
  Future<List<String>> pathSegmentsForFolder(String folderId) async {
    final segments = <String>[];
    String? currentId = folderId;
    final seen = <String>{};
    while (currentId != null) {
      if (!seen.add(currentId)) {
        throw StateError('Folder parent cycle detected');
      }
      final folder = await getFolder(currentId);
      if (folder == null) break;
      segments.insert(0, folder.name);
      currentId = folder.parentId;
    }
    return segments;
  }

  /// Relative path string using `/` separators, or empty for root.
  Future<String> relativePathForFolder(String? folderId) async {
    if (folderId == null) return '';
    return (await pathSegmentsForFolder(folderId)).join('/');
  }

  Future<CharacterFolder> createFolder(
    String name, {
    String? parentId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name cannot be empty');
    }
    if (parentId != null) {
      final parent = await getFolder(parentId);
      if (parent == null) {
        throw StateError('Parent folder not found');
      }
    }
    final existing = await _findChildByName(parentId, trimmed);
    if (existing != null) {
      return existing;
    }
    final maxOrder = await _maxSortOrder(parentId: parentId);
    final now = DateTime.now();
    final id = _uuid.v4();
    await _db.customStatement(
      'INSERT INTO character_folders '
      '(id, name, parent_id, sort_order, created_at) '
      'VALUES (?, ?, ?, ?, ?)',
      [id, trimmed, parentId, maxOrder + 1, now.millisecondsSinceEpoch],
    );
    return CharacterFolder(
      id: id,
      name: trimmed,
      parentId: parentId,
      sortOrder: maxOrder + 1,
      createdAt: now,
    );
  }

  /// Insert or update a folder row by stable [folder.id] (fast pack import).
  Future<void> upsertFolder(CharacterFolder folder) async {
    final trimmed = folder.name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name cannot be empty');
    }
    final existing = await getFolder(folder.id);
    if (existing == null) {
      await _db.customStatement(
        'INSERT INTO character_folders '
        '(id, name, parent_id, sort_order, created_at) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          folder.id,
          trimmed,
          folder.parentId,
          folder.sortOrder,
          folder.createdAt.millisecondsSinceEpoch,
        ],
      );
      return;
    }
    await _db.customStatement(
      'UPDATE character_folders '
      'SET name = ?, parent_id = ?, sort_order = ? '
      'WHERE id = ?',
      [trimmed, folder.parentId, folder.sortOrder, folder.id],
    );
  }

  /// Replaces folder membership for the given character ids.
  /// `null` folder id means the character returns to the library root.
  Future<void> replaceMemberships(
    Map<String, String?> characterIdToFolderId,
  ) async {
    if (characterIdToFolderId.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      for (final entry in characterIdToFolderId.entries) {
        final characterId = entry.key;
        final folderId = entry.value;
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
          [now, characterId],
        );
      }
    });
  }

  /// Ensures nested folders exist for [segments]; returns leaf id or null if empty.
  Future<String?> ensureFolderPath(List<String> segments) async {
    String? parentId;
    for (final raw in segments) {
      final name = raw.trim();
      if (name.isEmpty || name == '.' || name == '..') continue;
      final folder = await createFolder(name, parentId: parentId);
      parentId = folder.id;
    }
    return parentId;
  }

  Future<CharacterFolder> renameFolder(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name cannot be empty');
    }
    final current = await getFolder(id);
    if (current == null) {
      throw StateError('Folder not found');
    }
    final sibling = await _findChildByName(current.parentId, trimmed);
    if (sibling != null && sibling.id != id) {
      throw StateError('A folder with this name already exists here');
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

  /// Removes the folder only. Characters inside return to the library root.
  /// Child folders are reparented to this folder's parent.
  Future<void> dissolveFolder(String id) async {
    final folder = await getFolder(id);
    if (folder == null) return;
    await _db.transaction(() async {
      await _db.customStatement(
        'DELETE FROM character_folder_members WHERE folder_id = ?',
        [id],
      );
      await _db.customStatement(
        'UPDATE character_folders SET parent_id = ? WHERE parent_id = ?',
        [folder.parentId, id],
      );
      await _db.customStatement(
        'DELETE FROM character_folders WHERE id = ?',
        [id],
      );
    });
  }

  /// Deletes [id] and every descendant folder. Returns character ids that were
  /// members of the removed tree (caller should delete those characters).
  Future<List<String>> deleteFolderTree(String id) async {
    final folder = await getFolder(id);
    if (folder == null) return const [];
    final subtreeIds = await collectDescendantFolderIds(id);
    final characterIds = await characterIdsInFolders(subtreeIds);
    await _db.transaction(() async {
      for (final folderId in subtreeIds) {
        await _db.customStatement(
          'DELETE FROM character_folder_members WHERE folder_id = ?',
          [folderId],
        );
      }
      for (final folderId in subtreeIds.reversed) {
        await _db.customStatement(
          'DELETE FROM character_folders WHERE id = ?',
          [folderId],
        );
      }
    });
    return characterIds;
  }

  /// Depth-first list starting with [rootId], then descendants.
  Future<List<String>> collectDescendantFolderIds(String rootId) async {
    final ordered = <String>[];
    final queue = <String>[rootId];
    final seen = <String>{};
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (!seen.add(id)) continue;
      ordered.add(id);
      final children = await listFolders(parentId: id);
      for (final child in children) {
        queue.add(child.id);
      }
    }
    return ordered;
  }

  Future<List<String>> characterIdsInFolders(Iterable<String> folderIds) async {
    final ids = folderIds.toList(growable: false);
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await _db.customSelect(
      '''
      SELECT m.character_id AS character_id
      FROM character_folder_members m
      INNER JOIN characters c ON c.id = m.character_id
      WHERE m.folder_id IN ($placeholders) AND c.is_deleted = 0
      ''',
      variables: [for (final id in ids) Variable<String>(id)],
      readsFrom: const {},
    ).get();
    return rows
        .map((row) => row.read<String>('character_id'))
        .toList(growable: false);
  }

  /// Moves a folder under [parentId] (`null` = library root). Rejects cycles.
  Future<void> reparentFolder(String id, {String? parentId}) async {
    if (id == parentId) {
      throw StateError('Folder cannot be its own parent');
    }
    final folder = await getFolder(id);
    if (folder == null) {
      throw StateError('Folder not found');
    }
    if (parentId != null) {
      final parent = await getFolder(parentId);
      if (parent == null) {
        throw StateError('Parent folder not found');
      }
      final descendants = await collectDescendantFolderIds(id);
      if (descendants.contains(parentId)) {
        throw StateError('Cannot move a folder into its descendant');
      }
    }
    await _db.customStatement(
      'UPDATE character_folders SET parent_id = ? WHERE id = ?',
      [parentId, id],
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

  /// Map of character id → folder id for all memberships.
  Future<Map<String, String>> folderIdsByCharacter() async {
    final rows = await _db.customSelect(
      'SELECT character_id, folder_id FROM character_folder_members',
      readsFrom: const {},
    ).get();
    return {
      for (final row in rows)
        row.read<String>('character_id'): row.read<String>('folder_id'),
    };
  }

  Future<List<CharacterFolder>> _hydrateFolders(List<QueryRow> rows) async {
    final folders = rows.map(_folderFromRow).toList(growable: false);
    if (folders.isEmpty) return folders;
    final previews = await _loadPreviewCharactersByFolder(
      folderIds: folders.map((f) => f.id).toSet(),
    );
    return folders
        .map(
          (folder) => folder.copyWith(
            previewCharacters: previews[folder.id] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  Future<CharacterFolder?> _findChildByName(
    String? parentId,
    String name,
  ) async {
    final row = await _db.customSelect(
      '''
      $_folderSelect
      WHERE ${parentId == null ? 'f.parent_id IS NULL' : 'f.parent_id = ?'}
        AND f.name = ?
      LIMIT 1
      ''',
      variables: parentId == null
          ? [Variable<String>(name)]
          : [Variable<String>(parentId), Variable<String>(name)],
      readsFrom: const {},
    ).getSingleOrNull();
    return row == null ? null : _folderFromRow(row);
  }

  Future<int> _maxSortOrder({String? parentId}) async {
    final row = await _db.customSelect(
      '''
      SELECT MAX(sort_order) AS max_order FROM character_folders
      WHERE ${parentId == null ? 'parent_id IS NULL' : 'parent_id = ?'}
      ''',
      variables: parentId == null ? const [] : [Variable<String>(parentId)],
      readsFrom: const {},
    ).getSingleOrNull();
    return row?.read<int?>('max_order') ?? 0;
  }

  CharacterFolder _folderFromRow(QueryRow row) {
    final createdMs = row.read<int>('created_at');
    return CharacterFolder(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      parentId: row.read<String?>('parent_id'),
      sortOrder: row.read<int>('sort_order'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs),
      characterCount: row.read<int>('character_count'),
    );
  }

  Future<Map<String, List<CharacterFolderPreview>>>
      _loadPreviewCharactersByFolder({
    Set<String>? folderIds,
  }) async {
    if (folderIds != null && folderIds.isEmpty) {
      return const {};
    }

    final folderFilter = folderIds == null
        ? ''
        : 'AND m.folder_id IN (${List.filled(folderIds.length, '?').join(', ')})';
    final variables = folderIds == null
        ? const <Variable<Object>>[]
        : [for (final id in folderIds) Variable<String>(id)];

    final rows = await _db.customSelect(
      '''
      SELECT folder_id, id, name, avatar_path, assets_json
      FROM (
        SELECT m.folder_id AS folder_id,
               c.id AS id,
               c.name AS name,
               c.avatar_path AS avatar_path,
               c.assets_json AS assets_json,
               ROW_NUMBER() OVER (
                 PARTITION BY m.folder_id
                 ORDER BY c.modified_at DESC
               ) AS rn
        FROM character_folder_members m
        INNER JOIN characters c ON c.id = m.character_id
        WHERE c.is_deleted = 0
          $folderFilter
      )
      WHERE rn <= 4
      ''',
      variables: variables,
      readsFrom: const {},
    ).get();

    final grouped = <String, List<CharacterFolderPreview>>{};
    for (final row in rows) {
      final folderId = row.read<String>('folder_id');
      grouped.putIfAbsent(folderId, () => []).add(
            CharacterFolderPreview(
              id: row.read<String>('id'),
              name: row.read<String>('name'),
              avatarPath: row.read<String?>('avatar_path') ??
                  _avatarPathFromAssetsJson(
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
