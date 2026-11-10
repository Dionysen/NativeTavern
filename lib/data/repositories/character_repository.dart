import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/database/database.dart' hide Character;
import 'package:native_tavern/data/database/database.dart' as db;
import 'package:native_tavern/data/models/character.dart' as models;
import 'package:native_tavern/data/models/character_sort_option.dart';
import 'package:native_tavern/data/models/character_card_codec.dart';
import 'package:native_tavern/core/utils/png_text_chunks.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Provider for character repository
final characterRepositoryProvider = Provider<CharacterRepository>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// Repository for managing character data
class CharacterRepository {
  final AppDatabase _db;
  final String _dataPath;
  static const _uuid = Uuid();

  CharacterRepository(this._db, this._dataPath);

  static String _browseOrderBy(
    CharacterSortOption sort, {
    String alias = 'c',
  }) =>
      sort.orderBySql(alias: alias);

  /// Get all characters
  Future<List<models.Character>> getAllCharacters() async {
    final rows = await _db.select(_db.characters).get();
    return rows.where((row) => !row.isDeleted).map(_characterFromRow).toList();
  }

  /// Load characters by id (skips missing / soft-deleted).
  Future<List<models.Character>> getCharactersByIds(
    Iterable<String> ids,
  ) async {
    final unique = ids.toSet().toList(growable: false);
    if (unique.isEmpty) return const [];
    final driftRows = await (_db.select(_db.characters)
          ..where((t) => t.id.isIn(unique) & t.isDeleted.equals(false)))
        .get();
    final byId = <String, models.Character>{
      for (final row in driftRows) row.id: _characterFromRow(row),
    };
    return [
      for (final id in unique)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }

  /// All character ids matching the current browser filter (no pagination).
  Future<List<String>> listBrowseCharacterIds({
    String query = '',
    String? browseFolderId,
    bool searchGlobally = true,
    List<String> requiredTags = const [],
    CharacterSortOption sort = CharacterSortOption.modifiedAtDesc,
  }) async {
    final normalized = query.trim();
    final tags = _normalizedTagFilter(requiredTags);
    if (normalized.isEmpty && browseFolderId != null) {
      return _characterIdsInFolder(
        folderId: browseFolderId,
        requiredTags: tags,
        sort: sort,
      );
    }
    if (normalized.isEmpty && browseFolderId == null) {
      return _characterIdsAtRoot(requiredTags: tags, sort: sort);
    }
    if (normalized.isNotEmpty &&
        browseFolderId != null &&
        !searchGlobally) {
      return _searchIdsInFolder(
        folderId: browseFolderId,
        query: normalized,
        requiredTags: tags,
        sort: sort,
      );
    }
    final pattern = '%$normalized%';
    final (tagSql, tagVars) = _sqlTagFilters('characters', tags);
    final orderBy = _browseOrderBy(sort, alias: '');
    final idRows = await _db.customSelect(
      '''
      SELECT id AS id
      FROM characters
      WHERE is_deleted = 0
        AND (name LIKE ? OR description LIKE ?)
        $tagSql
      ORDER BY $orderBy
      ''',
      variables: [
        Variable<String>(pattern),
        Variable<String>(pattern),
        ...tagVars,
      ],
      readsFrom: {_db.characters},
    ).get();
    return idRows.map((row) => row.read<String>('id')).toList(growable: false);
  }

  /// Loads a bounded page for the character browser. Full character reads are
  /// still available for chat/runtime callers that need complete data.
  Future<List<models.Character>> getCharactersPage({
    int limit = 40,
    int offset = 0,
    String query = '',
    String? browseFolderId,
    bool searchGlobally = true,
    List<String> requiredTags = const [],
    CharacterSortOption sort = CharacterSortOption.modifiedAtDesc,
  }) async {
    final normalized = query.trim();
    final tags = _normalizedTagFilter(requiredTags);
    if (normalized.isEmpty && browseFolderId != null) {
      return _charactersInFolderPage(
        folderId: browseFolderId,
        limit: limit,
        offset: offset,
        requiredTags: tags,
        sort: sort,
      );
    }
    if (normalized.isEmpty && browseFolderId == null) {
      return _charactersAtRootPage(
        limit: limit,
        offset: offset,
        requiredTags: tags,
        sort: sort,
      );
    }
    if (normalized.isNotEmpty &&
        browseFolderId != null &&
        !searchGlobally) {
      return _searchInFolderPage(
        folderId: browseFolderId,
        query: normalized,
        limit: limit,
        offset: offset,
        requiredTags: tags,
        sort: sort,
      );
    }
    final pattern = '%$normalized%';
    final (tagSql, tagVars) = _sqlTagFilters('characters', tags);
    final orderBy = _browseOrderBy(sort, alias: '');
    final idRows = await _db.customSelect(
      '''
      SELECT id AS id
      FROM characters
      WHERE is_deleted = 0
        AND (name LIKE ? OR description LIKE ?)
        $tagSql
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
      ''',
      variables: [
        Variable<String>(pattern),
        Variable<String>(pattern),
        ...tagVars,
        Variable<int>(limit),
        Variable<int>(offset < 0 ? 0 : offset),
      ],
      readsFrom: {_db.characters},
    ).get();
    return _characterBrowseSummariesByIds(
      idRows.map((row) => row.read<String>('id')).toList(growable: false),
    );
  }

  /// Distinct tag labels used on characters (JSON tags and linked tag names).
  Future<List<String>> listDistinctCharacterTagLabels() async {
    final rows = await _db.customSelect(
      '''
      SELECT label FROM (
        SELECT DISTINCT trim(je.value) AS label
        FROM characters c
        INNER JOIN json_each(c.tags) je
        WHERE c.is_deleted = 0
          AND je.value IS NOT NULL
          AND trim(je.value) != ''
        UNION
        SELECT DISTINCT t.name AS label
        FROM tags t
        INNER JOIN character_tags ct ON ct.tag_id = t.id
        INNER JOIN characters c ON c.id = ct.character_id
        WHERE c.is_deleted = 0
      )
      ORDER BY label COLLATE NOCASE
      ''',
      readsFrom: const {},
    ).get();
    return rows.map((row) => row.read<String>('label')).toList(growable: false);
  }

  List<String> _normalizedTagFilter(List<String> tags) {
    return tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();
  }

  (String, List<Variable<Object>>) _sqlTagFilters(
    String tableAlias,
    List<String> tags,
  ) {
    if (tags.isEmpty) {
      return ('', const []);
    }
    final buffer = StringBuffer();
    final variables = <Variable<Object>>[];
    for (final tag in tags) {
      buffer.write(
        ' AND (EXISTS (SELECT 1 FROM json_each($tableAlias.tags) AS tag_row '
        'WHERE tag_row.value = ?) '
        'OR EXISTS (SELECT 1 FROM character_tags ct '
        'INNER JOIN tags t ON t.id = ct.tag_id '
        'WHERE ct.character_id = $tableAlias.id AND t.name = ?))',
      );
      variables.add(Variable<String>(tag));
      variables.add(Variable<String>(tag));
    }
    return (buffer.toString(), variables);
  }

  Future<List<String>> _characterIdsAtRoot({
    List<String> requiredTags = const [],
    CharacterSortOption sort = CharacterSortOption.modifiedAtDesc,
  }) async {
    final tags = _normalizedTagFilter(requiredTags);
    final (tagSql, tagVars) = _sqlTagFilters('c', tags);
    final orderBy = _browseOrderBy(sort);
    final idRows = await _db.customSelect(
      '''
      SELECT c.id AS id
      FROM characters c
      LEFT JOIN character_folder_members m ON m.character_id = c.id
      WHERE c.is_deleted = 0 AND m.character_id IS NULL
      $tagSql
      ORDER BY $orderBy
      ''',
      variables: [...tagVars],
      readsFrom: {_db.characters},
    ).get();
    return idRows.map((row) => row.read<String>('id')).toList(growable: false);
  }

  Future<List<models.Character>> _charactersAtRootPage({
    required int limit,
    required int offset,
    List<String> requiredTags = const [],
    CharacterSortOption sort = CharacterSortOption.modifiedAtDesc,
  }) async {
    final tags = _normalizedTagFilter(requiredTags);
    final (tagSql, tagVars) = _sqlTagFilters('c', tags);
    final orderBy = _browseOrderBy(sort);
    final idRows = await _db.customSelect(
      '''
      SELECT c.id AS id
      FROM characters c
      LEFT JOIN character_folder_members m ON m.character_id = c.id
      WHERE c.is_deleted = 0 AND m.character_id IS NULL
      $tagSql
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
      ''',
      variables: [
        ...tagVars,
        Variable<int>(limit),
        Variable<int>(offset < 0 ? 0 : offset),
      ],
      readsFrom: {_db.characters},
    ).get();
    return _characterBrowseSummariesByIds(
      idRows.map((row) => row.read<String>('id')).toList(growable: false),
    );
  }

  Future<List<String>> _searchIdsInFolder({
    required String folderId,
    required String query,
    List<String> requiredTags = const [],
    CharacterSortOption sort = CharacterSortOption.modifiedAtDesc,
  }) async {
    final pattern = '%$query%';
    final tags = _normalizedTagFilter(requiredTags);
    final (tagSql, tagVars) = _sqlTagFilters('c', tags);
    final orderBy = _browseOrderBy(sort);
    final idRows = await _db.customSelect(
      '''
      SELECT c.id AS id
      FROM characters c
      INNER JOIN character_folder_members m ON m.character_id = c.id
      WHERE c.is_deleted = 0 AND m.folder_id = ?
        AND (c.name LIKE ? OR c.description LIKE ?)
        $tagSql
      ORDER BY $orderBy
      ''',
      variables: [
        Variable<String>(folderId),
        Variable<String>(pattern),
        Variable<String>(pattern),
        ...tagVars,
      ],
      readsFrom: {_db.characters},
    ).get();
    return idRows.map((row) => row.read<String>('id')).toList(growable: false);
  }

  Future<List<models.Character>> _searchInFolderPage({
    required String folderId,
    required String query,
    required int limit,
    required int offset,
    List<String> requiredTags = const [],
    CharacterSortOption sort = CharacterSortOption.modifiedAtDesc,
  }) async {
    final pattern = '%$query%';
    final tags = _normalizedTagFilter(requiredTags);
    final (tagSql, tagVars) = _sqlTagFilters('c', tags);
    final orderBy = _browseOrderBy(sort);
    final idRows = await _db.customSelect(
      '''
      SELECT c.id AS id
      FROM characters c
      INNER JOIN character_folder_members m ON m.character_id = c.id
      WHERE c.is_deleted = 0 AND m.folder_id = ?
        AND (c.name LIKE ? OR c.description LIKE ?)
        $tagSql
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
      ''',
      variables: [
        Variable<String>(folderId),
        Variable<String>(pattern),
        Variable<String>(pattern),
        ...tagVars,
        Variable<int>(limit),
        Variable<int>(offset < 0 ? 0 : offset),
      ],
      readsFrom: {_db.characters},
    ).get();
    return _characterBrowseSummariesByIds(
      idRows.map((row) => row.read<String>('id')).toList(growable: false),
    );
  }

  Future<List<String>> _characterIdsInFolder({
    required String folderId,
    List<String> requiredTags = const [],
    CharacterSortOption sort = CharacterSortOption.modifiedAtDesc,
  }) async {
    final tags = _normalizedTagFilter(requiredTags);
    final (tagSql, tagVars) = _sqlTagFilters('c', tags);
    final orderBy = _browseOrderBy(sort);
    final idRows = await _db.customSelect(
      '''
      SELECT c.id AS id
      FROM characters c
      INNER JOIN character_folder_members m ON m.character_id = c.id
      WHERE c.is_deleted = 0 AND m.folder_id = ?
      $tagSql
      ORDER BY $orderBy
      ''',
      variables: [
        Variable<String>(folderId),
        ...tagVars,
      ],
      readsFrom: {_db.characters},
    ).get();
    return idRows.map((row) => row.read<String>('id')).toList(growable: false);
  }

  Future<List<models.Character>> _charactersInFolderPage({
    required String folderId,
    required int limit,
    required int offset,
    List<String> requiredTags = const [],
    CharacterSortOption sort = CharacterSortOption.modifiedAtDesc,
  }) async {
    final tags = _normalizedTagFilter(requiredTags);
    final (tagSql, tagVars) = _sqlTagFilters('c', tags);
    final orderBy = _browseOrderBy(sort);
    final idRows = await _db.customSelect(
      '''
      SELECT c.id AS id
      FROM characters c
      INNER JOIN character_folder_members m ON m.character_id = c.id
      WHERE c.is_deleted = 0 AND m.folder_id = ?
      $tagSql
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
      ''',
      variables: [
        Variable<String>(folderId),
        ...tagVars,
        Variable<int>(limit),
        Variable<int>(offset < 0 ? 0 : offset),
      ],
      readsFrom: {_db.characters},
    ).get();
    return _characterBrowseSummariesByIds(
      idRows.map((row) => row.read<String>('id')).toList(growable: false),
    );
  }

  /// Browser list rows: id/name/short description/tags/creator/avatar only.
  /// Skips character book, extensions, and other chat-runtime fields.
  Future<List<models.Character>> _characterBrowseSummariesByIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await _db.customSelect(
      '''
      SELECT id, name,
             substr(description, 1, 280) AS description,
             tags, creator, avatar_path,
             CASE
               WHEN avatar_path IS NULL OR avatar_path = ''
               THEN assets_json
               ELSE NULL
             END AS assets_json,
             created_at, modified_at
      FROM characters
      WHERE id IN ($placeholders)
      ''',
      variables: [for (final id in ids) Variable<String>(id)],
      readsFrom: {_db.characters},
    ).get();
    final byId = <String, models.Character>{};
    for (final row in rows) {
      final id = row.read<String>('id');
      final avatarPath = row.read<String?>('avatar_path') ??
          _avatarPathFromAssetsJson(row.read<String?>('assets_json'));
      byId[id] = models.Character(
        id: id,
        name: row.read<String>('name'),
        description: row.read<String>('description'),
        tags: _parseJsonList(row.read<String>('tags')),
        creator: row.read<String>('creator'),
        assets: avatarPath == null
            ? null
            : models.CharacterAssets(avatarPath: avatarPath),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.read<int>('created_at'),
        ),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(
          row.read<int>('modified_at'),
        ),
      );
    }
    return [
      for (final id in ids)
        if (byId.containsKey(id)) byId[id]!,
    ];
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

  /// Get character by ID
  Future<models.Character?> getCharacter(String id) async {
    final row = await (_db.select(_db.characters)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _characterFromRow(row) : null;
  }

  /// Search characters by name
  Future<List<models.Character>> searchCharacters(String query) async {
    final rows = await (_db.select(_db.characters)
          ..where((t) => t.name.like('%$query%')))
        .get();
    return rows.where((row) => !row.isDeleted).map(_characterFromRow).toList();
  }

  /// Get characters by tags
  Future<List<models.Character>> getCharactersByTag(String tag) async {
    final rows = await _db.select(_db.characters).get();
    return rows
        .where((row) => !row.isDeleted)
        .map(_characterFromRow)
        .where((c) => c.tags.contains(tag))
        .toList();
  }

  /// Get favorite characters
  Future<List<models.Character>> getFavoriteCharacters() async {
    final rows = await (_db.select(_db.characters)
          ..where((t) => t.isFavorite.equals(true) & t.isDeleted.equals(false)))
        .get();
    return rows.map(_characterFromRow).toList();
  }

  /// Toggle character favorite status
  Future<models.Character> toggleFavorite(String characterId) async {
    final character = await getCharacter(characterId);
    if (character == null) {
      throw Exception('Character not found');
    }

    final updatedCharacter = character.copyWith(
      isFavorite: !character.isFavorite,
      modifiedAt: DateTime.now(),
    );

    await (_db.update(_db.characters)..where((t) => t.id.equals(characterId)))
        .write(_characterToCompanion(updatedCharacter));

    return updatedCharacter;
  }

  /// Set character favorite status
  Future<models.Character> setFavorite(
      String characterId, bool isFavorite) async {
    final character = await getCharacter(characterId);
    if (character == null) {
      throw Exception('Character not found');
    }

    final updatedCharacter = character.copyWith(
      isFavorite: isFavorite,
      modifiedAt: DateTime.now(),
    );

    await (_db.update(_db.characters)..where((t) => t.id.equals(characterId)))
        .write(_characterToCompanion(updatedCharacter));

    return updatedCharacter;
  }

  /// Create a new character
  Future<models.Character> createCharacter(models.Character character) async {
    final id = character.id.isEmpty ? _uuid.v4() : character.id;
    final now = DateTime.now();

    final newCharacter = character.copyWith(
      id: id,
      createdAt: now,
      modifiedAt: now,
    );

    await _db.into(_db.characters).insert(_characterToCompanion(newCharacter));
    return newCharacter;
  }

  /// Update an existing character
  Future<models.Character> updateCharacter(models.Character character) async {
    final updatedCharacter = character.copyWith(modifiedAt: DateTime.now());

    await (_db.update(_db.characters)..where((t) => t.id.equals(character.id)))
        .write(_characterToCompanion(updatedCharacter));

    return updatedCharacter;
  }

  /// All character ids currently in the table (including soft-deleted).
  Future<Set<String>> listAllCharacterIds() async {
    final rows = await _db.customSelect(
      'SELECT id AS id FROM characters',
      readsFrom: {_db.characters},
    ).get();
    return rows.map((row) => row.read<String>('id')).toSet();
  }

  /// Insert or overwrite a character by stable id (fast pack import).
  Future<models.Character> upsertCharacter(models.Character character) async {
    final id = character.id.isEmpty ? _uuid.v4() : character.id;
    final now = DateTime.now();
    final existing = await getCharacter(id);
    if (existing == null) {
      final created = character.copyWith(
        id: id,
        isDeleted: false,
        createdAt: character.createdAt,
        modifiedAt: now,
      );
      await _db.into(_db.characters).insert(_characterToCompanion(created));
      return created;
    }
    final updated = character.copyWith(
      id: id,
      isDeleted: false,
      createdAt: existing.createdAt,
      modifiedAt: now,
    );
    await (_db.update(_db.characters)..where((t) => t.id.equals(id)))
        .write(_characterToCompanion(updated));
    return updated;
  }

  /// Soft-delete a character and remove its 1:1 chats.
  ///
  /// The character row is kept (with [Characters.isDeleted]) so moment links
  /// and group-chat history that still reference the id remain usable.
  /// Solo chats for this character are hard-deleted with their messages.
  Future<void> deleteCharacter(String id) async {
    await _db.transaction(() async {
      final chatRows = await (_db.select(_db.chats)
            ..where(
              (t) => t.characterId.equals(id) & t.groupId.isNull(),
            ))
          .get();
      for (final chat in chatRows) {
        await (_db.delete(_db.bookmarks)
              ..where((t) => t.chatId.equals(chat.id)))
            .go();
        await (_db.delete(_db.messages)
              ..where((t) => t.chatId.equals(chat.id)))
            .go();
        await (_db.delete(_db.chats)..where((t) => t.id.equals(chat.id))).go();
      }

      await (_db.update(_db.characters)..where((t) => t.id.equals(id))).write(
        CharactersCompanion(
          isDeleted: const Value(true),
          modifiedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Save character avatar
  Future<String> saveAvatar(String characterId, Uint8List imageData) async {
    final avatarDir = Directory(p.join(_dataPath, 'avatars'));
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    final avatarPath = p.join(avatarDir.path, '$characterId.png');
    await File(avatarPath).writeAsBytes(imageData);

    // Update character with avatar path
    await (_db.update(_db.characters)..where((t) => t.id.equals(characterId)))
        .write(CharactersCompanion(avatarPath: Value(avatarPath)));

    return avatarPath;
  }

  /// Get character count
  Future<int> getCharacterCount() async {
    final count = await (_db.select(_db.characters)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    return count.length;
  }

  /// Load built-in characters from PNG assets under [assets/characters/images/].
  /// Drop SillyTavern-style PNGs there to ship more built-in cards later.
  Future<void> loadBuiltInCharacters() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final builtInCharacterFiles = manifest
          .listAssets()
          .where((path) => path.startsWith('assets/characters/images/'))
          .where((path) => path.toLowerCase().endsWith('.png'))
          .toList()
        ..sort();

      if (builtInCharacterFiles.isEmpty) {
        debugPrint('No built-in character PNGs under assets/characters/images/');
        return;
      }

      for (final assetPath in builtInCharacterFiles) {
        try {
          // Load PNG bytes from assets
          final byteData = await rootBundle.load(assetPath);
          final bytes = byteData.buffer.asUint8List();

          // Extract character data from PNG tEXt chunk
          final base64Data = extractPngTextChunk(bytes, 'ccv3') ??
              extractPngTextChunk(bytes, 'chara');
          if (base64Data == null) {
            debugPrint('No character data found in $assetPath');
            continue;
          }

          // Decode base64 and parse JSON (V2/V3 character card format)
          final jsonString = utf8.decode(base64Decode(base64Data));
          final json = jsonDecode(jsonString) as Map<String, dynamic>;

          // Extract character ID from embedded data (V2/V3 format has it in data.id)
          final data = json['data'] as Map<String, dynamic>? ?? json;
          final characterId = data['id'] as String? ?? _uuid.v4();

          final existing = await getCharacter(characterId);
          if (existing != null) {
            // Character already exists, skip
            continue;
          }

          // Parse character card (V2/V3 format) - same logic as importFromJson
          final character = _parseCharacterCard(json, characterId);

          // Save avatar image
          final avatarPath = await _saveBuiltInAvatar(characterId, bytes);
          final characterWithAvatar = character.copyWith(
            assets: models.CharacterAssets(avatarPath: avatarPath),
          );

          await createCharacter(characterWithAvatar);

          debugPrint('Loaded built-in character: ${character.name}');
        } catch (e) {
          debugPrint('Failed to load built-in character from $assetPath: $e');
        }
      }
    } catch (e) {
      debugPrint('Failed to load built-in characters: $e');
    }
  }

  /// Parse character card from V1/V2/V3 format JSON
  models.Character _parseCharacterCard(
      Map<String, dynamic> json, String characterId) {
    return CharacterCardCodec.parse(
      json,
      generateId: () => characterId,
    );
  }

  /// Save built-in avatar to data directory
  Future<String> _saveBuiltInAvatar(
      String characterId, Uint8List imageData) async {
    final avatarDir = Directory(p.join(_dataPath, 'avatars'));
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    final avatarPath = p.join(avatarDir.path, '$characterId.png');
    await File(avatarPath).writeAsBytes(imageData);

    return avatarPath;
  }

  /// Import character from JSON data
  Future<models.Character> importFromJson(Map<String, dynamic> json) async {
    final character = _parseCharacterCard(json, _uuid.v4());
    return createCharacter(character);
  }

  /// Export character to JSON (V3 format)
  Map<String, dynamic> exportToJson(models.Character character) {
    return CharacterCardCodec.toV3Json(character);
  }

  // Private helpers

  models.Character _characterFromRow(db.Character row) {
    final storedAssets =
        models.CharacterAssets.fromJson(_parseJsonMap(row.assetsJson));
    final assets = models.CharacterAssets(
      avatarPath: row.avatarPath ?? storedAssets.avatarPath,
      avatarUrl: storedAssets.avatarUrl,
      expressionPack: storedAssets.expressionPack,
      live2d: storedAssets.live2d,
    );
    final storedExtensions = _parseJsonMap(row.extensionsJson);
    final split =
        CharacterCardCodec.splitStoredExtensions(storedExtensions);
    return models.Character(
      id: row.id,
      name: row.name,
      description: row.description,
      personality: row.personality,
      scenario: row.scenario,
      firstMessage: row.firstMessage,
      alternateGreetings: _parseJsonList(row.alternateGreetings),
      exampleMessages: row.exampleDialogue,
      systemPrompt: row.systemPrompt,
      postHistoryInstructions: row.postHistoryInstructions,
      creatorNotes: row.creatorNotes,
      tags: _parseJsonList(row.tags),
      creator: row.creator,
      version: row.characterVersion,
      assets: assets.hasAssets ? assets : null,
      characterBook: _parseCharacterBook(row.characterBookJson),
      cardExtras: split.$2,
      extensions: split.$1,
      isFavorite: row.isFavorite,
      isDeleted: row.isDeleted,
      depthPrompt:
          models.Character.depthPromptFromExtensions(split.$1),
      talkativeness:
          models.Character.talkativenessFromExtensions(split.$1),
      createdAt: row.createdAt,
      modifiedAt: row.modifiedAt,
    );
  }

  CharactersCompanion _characterToCompanion(models.Character character) {
    return CharactersCompanion(
      id: Value(character.id),
      name: Value(character.name),
      description: Value(character.description),
      personality: Value(character.personality),
      scenario: Value(character.scenario),
      firstMessage: Value(character.firstMessage),
      alternateGreetings: Value(jsonEncode(character.alternateGreetings)),
      exampleDialogue: Value(character.exampleMessages),
      systemPrompt: Value(character.systemPrompt),
      postHistoryInstructions: Value(character.postHistoryInstructions),
      creatorNotes: Value(character.creatorNotes),
      tags: Value(jsonEncode(character.tags)),
      creator: Value(character.creator),
      characterVersion: Value(character.version),
      avatarPath: Value(character.assets?.avatarPath),
      assetsJson: Value(jsonEncode(character.assets?.toJson() ?? const {})),
      characterBookJson:
          Value(_serializeCharacterBook(character.characterBook)),
      extensionsJson:
          Value(jsonEncode(CharacterCardCodec.extensionsForStorage(character))),
      isFavorite: Value(character.isFavorite),
      isDeleted: Value(character.isDeleted),
      createdAt: Value(character.createdAt),
      modifiedAt: Value(character.modifiedAt),
    );
  }

  List<String> _parseJsonList(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _parseJsonMap(String json) {
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  models.CharacterBook? _parseCharacterBook(String json) {
    if (json.isEmpty) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return models.CharacterBook.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  String _serializeCharacterBook(models.CharacterBook? book) {
    if (book == null) return '';
    return jsonEncode(book.toJson());
  }

  Future<void> _deleteCharacterAvatar(String characterId) async {
    try {
      final avatarPath = p.join(_dataPath, 'avatars', '$characterId.png');
      final file = File(avatarPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete avatar: $e');
    }
  }
}
