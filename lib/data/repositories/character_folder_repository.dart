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

  /// Library root is depth 0; a folder directly under root is depth 1.
  static const maxFolderDepth = 5;

  static const _folderSelect = '''
      SELECT f.id AS id, f.name AS name, f.parent_id AS parent_id,
             f.sort_order AS sort_order, f.created_at AS created_at,
             (
               SELECT COUNT(*)
               FROM character_folder_members m
               INNER JOIN characters c ON c.id = m.character_id
               WHERE m.folder_id = f.id AND c.is_deleted = 0
             ) AS character_count,
             (
               SELECT COUNT(*)
               FROM character_folders child
               WHERE child.parent_id = f.id
             ) AS child_folder_count
      FROM character_folders f
  ''';

  /// Lists folders under [parentId] (`null` = library root).
  ///
  /// Cover previews are opt-in: browsing loads metadata first, then attaches
  /// mosaics after the first frame so enter/leave stays responsive.
  Future<List<CharacterFolder>> listFolders({
    String? parentId,
    bool includePreviews = false,
  }) async {
    final rows = await _db.customSelect(
      '''
      $_folderSelect
      WHERE ${parentId == null ? 'f.parent_id IS NULL' : 'f.parent_id = ?'}
      ORDER BY f.sort_order ASC, f.name ASC
      ''',
      variables: parentId == null ? const [] : [Variable<String>(parentId)],
      readsFrom: const {},
    ).get();
    final folders = rows.map(_folderFromRow).toList(growable: false);
    if (!includePreviews || folders.isEmpty) return folders;
    return attachPreviews(folders);
  }

  /// Fills cover mosaics for already-loaded folder rows.
  Future<List<CharacterFolder>> attachPreviews(
    List<CharacterFolder> folders,
  ) async {
    if (folders.isEmpty) return folders;
    final previews = await _loadPreviewItemsByFolder(
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

  /// Flat list of every folder (any depth). Skips cover previews.
  Future<List<CharacterFolder>> listAllFolders() async {
    final rows = await _db.customSelect(
      '''
      $_folderSelect
      ORDER BY f.sort_order ASC, f.name ASC
      ''',
      readsFrom: const {},
    ).get();
    return rows.map(_folderFromRow).toList(growable: false);
  }

  /// Folder row by id. Cover previews are opt-in (expensive on large libraries).
  Future<CharacterFolder?> getFolder(
    String id, {
    bool includePreviews = false,
  }) async {
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
    if (!includePreviews) return folder;
    final previews = await _loadPreviewItemsByFolder(folderIds: {id});
    return folder.copyWith(
      previewCharacters: previews[id] ?? const [],
    );
  }

  /// Parent id only — used when leaving a browse folder.
  Future<String?> parentIdOfFolder(String id) async {
    final row = await _db.customSelect(
      'SELECT parent_id AS parent_id FROM character_folders WHERE id = ? LIMIT 1',
      variables: [Variable<String>(id)],
      readsFrom: const {},
    ).getSingleOrNull();
    return row?.read<String?>('parent_id');
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
      final parentDepth = await depthOfFolder(parentId);
      if (parentDepth >= maxFolderDepth) {
        throw StateError('Folder depth limit is $maxFolderDepth');
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
  /// Paths deeper than [maxFolderDepth] stop at the depth limit (extra segments
  /// are ignored so imported cards land in the deepest allowed folder).
  Future<String?> ensureFolderPath(List<String> segments) async {
    String? parentId;
    var depth = 0;
    for (final raw in segments) {
      final name = raw.trim();
      if (name.isEmpty || name == '.' || name == '..') continue;
      if (depth >= maxFolderDepth) break;
      final folder = await createFolder(name, parentId: parentId);
      parentId = folder.id;
      depth += 1;
    }
    return parentId;
  }

  /// Depth of [folderId] (root children = 1). Null / missing → 0.
  Future<int> depthOfFolder(String? folderId) async {
    if (folderId == null) return 0;
    var depth = 0;
    String? currentId = folderId;
    final seen = <String>{};
    while (currentId != null) {
      if (!seen.add(currentId)) {
        throw StateError('Folder parent cycle detected');
      }
      depth += 1;
      currentId = await parentIdOfFolder(currentId);
    }
    return depth;
  }

  /// Moves characters from folders deeper than [maxFolderDepth] into their
  /// depth-[maxFolderDepth] ancestor, then deletes the excess folders.
  ///
  /// Returns how many folders were removed.
  Future<int> enforceMaxFolderDepth({int maxDepth = maxFolderDepth}) async {
    if (maxDepth < 1) {
      throw ArgumentError.value(maxDepth, 'maxDepth', 'must be >= 1');
    }

    final rows = await _db.customSelect(
      'SELECT id AS id, parent_id AS parent_id FROM character_folders',
      readsFrom: const {},
    ).get();
    if (rows.isEmpty) return 0;

    final parentById = <String, String?>{
      for (final row in rows)
        row.read<String>('id'): row.read<String?>('parent_id'),
    };
    final childrenByParent = <String?, List<String>>{};
    for (final entry in parentById.entries) {
      childrenByParent.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    final depthById = <String, int>{};
    void walk(String? parentId, int depth) {
      for (final id in childrenByParent[parentId] ?? const <String>[]) {
        depthById[id] = depth;
        walk(id, depth + 1);
      }
    }

    walk(null, 1);

    final overflowIds = depthById.entries
        .where((e) => e.value > maxDepth)
        .map((e) => e.key)
        .toList(growable: false);
    if (overflowIds.isEmpty) return 0;

    String ancestorAtDepth(String id, int targetDepth) {
      var current = id;
      while ((depthById[current] ?? 0) > targetDepth) {
        final parentId = parentById[current];
        if (parentId == null) break;
        current = parentId;
      }
      return current;
    }

    await _db.transaction(() async {
      for (final folderId in overflowIds) {
        final targetId = ancestorAtDepth(folderId, maxDepth);
        if (targetId == folderId) continue;
        final memberRows = await _db.customSelect(
          'SELECT character_id AS character_id '
          'FROM character_folder_members WHERE folder_id = ?',
          variables: [Variable<String>(folderId)],
          readsFrom: const {},
        ).get();
        for (final row in memberRows) {
          final characterId = row.read<String>('character_id');
          await _db.customStatement(
            'DELETE FROM character_folder_members WHERE character_id = ?',
            [characterId],
          );
          await _db.customStatement(
            'INSERT INTO character_folder_members (character_id, folder_id) '
            'VALUES (?, ?)',
            [characterId, targetId],
          );
        }
      }

      // Delete deepest folders first so parent_id FKs (if any) stay valid.
      final ordered = overflowIds.toList()
        ..sort((a, b) => (depthById[b] ?? 0).compareTo(depthById[a] ?? 0));
      for (final folderId in ordered) {
        await _db.customStatement(
          'DELETE FROM character_folder_members WHERE folder_id = ?',
          [folderId],
        );
        await _db.customStatement(
          'DELETE FROM character_folders WHERE id = ?',
          [folderId],
        );
      }
    });

    return overflowIds.length;
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
      final childRows = await _db.customSelect(
        'SELECT id AS id FROM character_folders WHERE parent_id = ? '
        'ORDER BY sort_order ASC, name ASC',
        variables: [Variable<String>(id)],
        readsFrom: const {},
      ).get();
      for (final row in childRows) {
        queue.add(row.read<String>('id'));
      }
    }
    return ordered;
  }

  /// Relative height of a folder tree (folder itself = 1).
  Future<int> _subtreeHeight(String rootId) async {
    final ids = await collectDescendantFolderIds(rootId);
    if (ids.isEmpty) return 0;
    final parentById = <String, String?>{};
    final rows = await _db.customSelect(
      'SELECT id AS id, parent_id AS parent_id FROM character_folders '
      'WHERE id IN (${List.filled(ids.length, '?').join(', ')})',
      variables: [for (final id in ids) Variable<String>(id)],
      readsFrom: const {},
    ).get();
    for (final row in rows) {
      parentById[row.read<String>('id')] = row.read<String?>('parent_id');
    }
    var maxDepth = 1;
    for (final id in ids) {
      var depth = 0;
      String? current = id;
      final seen = <String>{};
      while (current != null && ids.contains(current)) {
        if (!seen.add(current)) break;
        depth += 1;
        current = parentById[current];
      }
      if (depth > maxDepth) maxDepth = depth;
    }
    return maxDepth;
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
    final parentDepth = await depthOfFolder(parentId);
    final height = await _subtreeHeight(id);
    if (parentDepth + height > maxFolderDepth) {
      throw StateError('Folder depth limit is $maxFolderDepth');
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
      childFolderCount: row.read<int>('child_folder_count'),
    );
  }

  static const _previewSlots = 4;
  static const _previewMaxFoldersPerRoot = 48;

  /// Cover mosaic: BFS for character avatars only.
  ///
  /// Loads at most [_previewSlots] characters per visited folder and stops a
  /// root once it has four slots — never scans an entire descendant member set.
  Future<Map<String, List<CharacterFolderPreview>>> _loadPreviewItemsByFolder({
    required Set<String> folderIds,
  }) async {
    if (folderIds.isEmpty) {
      return const {};
    }

    final result = <String, List<CharacterFolderPreview>>{
      for (final id in folderIds) id: <CharacterFolderPreview>[],
    };
    final seen = <String, Set<String>>{
      for (final id in folderIds) id: <String>{},
    };
    final visited = <String, int>{
      for (final id in folderIds) id: 0,
    };

    // (rootId, folderId) pairs to search this round.
    var queue = <(String, String)>[
      for (final id in folderIds) (id, id),
    ];

    while (queue.isNotEmpty) {
      final active = <(String, String)>[
        for (final pair in queue)
          if (result[pair.$1]!.length < _previewSlots &&
              visited[pair.$1]! < _previewMaxFoldersPerRoot)
            pair,
      ];
      if (active.isEmpty) break;

      for (final pair in active) {
        visited[pair.$1] = visited[pair.$1]! + 1;
      }

      final batchFolderIds = {for (final pair in active) pair.$2};
      final charactersByFolder = await _loadPreviewCharactersByFolder(
        folderIds: batchFolderIds,
        limitPerFolder: _previewSlots,
      );

      for (final (rootId, folderId) in active) {
        final out = result[rootId]!;
        final rootSeen = seen[rootId]!;
        for (final preview
            in charactersByFolder[folderId] ?? const <CharacterFolderPreview>[]) {
          if (out.length >= _previewSlots) break;
          if (!rootSeen.add(preview.id)) continue;
          out.add(preview);
        }
      }

      final parentsNeedingChildren = <String>{
        for (final (rootId, folderId) in active)
          if (result[rootId]!.length < _previewSlots) folderId,
      };
      if (parentsNeedingChildren.isEmpty) break;

      final childrenByParent =
          await _childFolderIdsByParent(parentsNeedingChildren);
      final nextQueue = <(String, String)>[];
      for (final (rootId, folderId) in active) {
        if (result[rootId]!.length >= _previewSlots) continue;
        if (visited[rootId]! >= _previewMaxFoldersPerRoot) continue;
        for (final childId
            in childrenByParent[folderId] ?? const <String>[]) {
          nextQueue.add((rootId, childId));
        }
      }
      queue = nextQueue;
    }

    return {
      for (final entry in result.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value,
    };
  }

  Future<Map<String, List<String>>> _childFolderIdsByParent(
    Set<String> parentIds,
  ) async {
    if (parentIds.isEmpty) return const {};
    final placeholders = List.filled(parentIds.length, '?').join(', ');
    final rows = await _db.customSelect(
      '''
      SELECT parent_id AS parent_id, id AS id
      FROM character_folders
      WHERE parent_id IN ($placeholders)
      ORDER BY sort_order ASC, name ASC
      ''',
      variables: [for (final id in parentIds) Variable<String>(id)],
      readsFrom: const {},
    ).get();
    final grouped = <String, List<String>>{};
    for (final row in rows) {
      grouped
          .putIfAbsent(row.read<String>('parent_id'), () => [])
          .add(row.read<String>('id'));
    }
    return grouped;
  }

  Future<Map<String, List<CharacterFolderPreview>>>
      _loadPreviewCharactersByFolder({
    required Set<String> folderIds,
    int limitPerFolder = _previewSlots,
  }) async {
    if (folderIds.isEmpty) {
      return const {};
    }

    // Per-folder LIMIT (via UNION ALL) so SQLite can stop after N hits instead
    // of window-ranking every member in a 5k-card folder.
    final parts = <String>[];
    final variables = <Variable<Object>>[];
    for (final id in folderIds) {
      parts.add('''
        SELECT folder_id, id, name, avatar_path, assets_json FROM (
          SELECT m.folder_id AS folder_id,
                 c.id AS id,
                 c.name AS name,
                 c.avatar_path AS avatar_path,
                 CASE
                   WHEN c.avatar_path IS NULL OR c.avatar_path = ''
                   THEN c.assets_json
                   ELSE NULL
                 END AS assets_json
          FROM character_folder_members m
          INNER JOIN characters c ON c.id = m.character_id
          WHERE c.is_deleted = 0
            AND m.folder_id = ?
          ORDER BY c.modified_at DESC
          LIMIT ?
        )
      ''');
      variables
        ..add(Variable<String>(id))
        ..add(Variable<int>(limitPerFolder));
    }

    final rows = await _db.customSelect(
      parts.join(' UNION ALL '),
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
