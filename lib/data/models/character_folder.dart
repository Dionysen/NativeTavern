/// A character slot in the folder cover mosaic (up to four).
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
    this.childFolderCount = 0,
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

  /// Direct child folders of this folder.
  final int childFolderCount;

  /// Up to four character avatars for the cover mosaic.
  /// Prefers direct members, then walks child folders recursively.
  final List<CharacterFolderPreview> previewCharacters;

  CharacterFolder copyWith({
    String? id,
    String? name,
    String? parentId,
    bool clearParentId = false,
    int? sortOrder,
    DateTime? createdAt,
    int? characterCount,
    int? childFolderCount,
    List<CharacterFolderPreview>? previewCharacters,
  }) =>
      CharacterFolder(
        id: id ?? this.id,
        name: name ?? this.name,
        parentId: clearParentId ? null : (parentId ?? this.parentId),
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        characterCount: characterCount ?? this.characterCount,
        childFolderCount: childFolderCount ?? this.childFolderCount,
        previewCharacters: previewCharacters ?? this.previewCharacters,
      );
}
