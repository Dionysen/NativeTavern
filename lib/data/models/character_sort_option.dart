/// Sort order for the character library browser.
enum CharacterSortOption {
  nameAsc,
  nameDesc,
  createdAtDesc,
  createdAtAsc,
  modifiedAtDesc,
  modifiedAtAsc,
}

extension CharacterSortOptionSql on CharacterSortOption {
  /// SQL ORDER BY expression. [alias] e.g. `c` or empty for bare table.
  String orderBySql({String alias = 'c'}) {
    final prefix = alias.isEmpty ? '' : '$alias.';
    switch (this) {
      case CharacterSortOption.nameAsc:
        return '${prefix}name COLLATE NOCASE ASC';
      case CharacterSortOption.nameDesc:
        return '${prefix}name COLLATE NOCASE DESC';
      case CharacterSortOption.createdAtDesc:
        return '${prefix}created_at DESC';
      case CharacterSortOption.createdAtAsc:
        return '${prefix}created_at ASC';
      case CharacterSortOption.modifiedAtDesc:
        return '${prefix}modified_at DESC';
      case CharacterSortOption.modifiedAtAsc:
        return '${prefix}modified_at ASC';
    }
  }
}
