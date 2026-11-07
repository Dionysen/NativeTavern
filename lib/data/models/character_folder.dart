/// A slot in the folder cover mosaic (up to four characters).
class CharacterFolderPreview {
  const CharacterFolderPreview({
    required this.id,
    required this.name,
    this.avatarPath,
  });

  final String id;
  final String name;
  final String? avatarPath;
}

/// A user folder grouping character cards in the browser.
class CharacterFolder {
  const CharacterFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.sortOrder = 0,
    required this.createdAt,
    this.characterCount = 0,
    this.previewCharacters = const [],
  });

  final String id;
  final String name;

  /// null = top-level folder under the library root.
  final String? parentId;

  final int sortOrder;
  final DateTime createdAt;

  /// Populated by list queries for display (direct members only).
  final int characterCount;

  /// Up to four characters for folder cover mosaic, newest first.
  final List<CharacterFolderPreview> previewCharacters;

  CharacterFolder copyWith({
    String? id,
    String? name,
    String? parentId,
    bool clearParentId = false,
    int? sortOrder,
    DateTime? createdAt,
    int? characterCount,
    List<CharacterFolderPreview>? previewCharacters,
  }) =>
      CharacterFolder(
        id: id ?? this.id,
        name: name ?? this.name,
        parentId: clearParentId ? null : (parentId ?? this.parentId),
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        characterCount: characterCount ?? this.characterCount,
        previewCharacters: previewCharacters ?? this.previewCharacters,
      );
}
