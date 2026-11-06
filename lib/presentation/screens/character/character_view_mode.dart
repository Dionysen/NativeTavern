import 'package:flutter/material.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';

/// View mode for character list display
enum CharacterViewMode {
  /// Full list with avatar, description, and tags.
  list,

  /// Name-only list rows (no avatar / tags), fixed height.
  simpleList,

  /// Grid view with 2 columns (medium size)
  grid,

  /// Compact grid view with 3 columns (small size)
  compactGrid,
}

/// Avatar geometry for character list cards.
enum CharacterAvatarShape {
  circle,
  square,
  rectangle,
}

extension CharacterAvatarShapeExtension on CharacterAvatarShape {
  CharacterAvatarShape get next => switch (this) {
        CharacterAvatarShape.circle => CharacterAvatarShape.square,
        CharacterAvatarShape.square => CharacterAvatarShape.rectangle,
        CharacterAvatarShape.rectangle => CharacterAvatarShape.circle,
      };

  IconData get icon => switch (this) {
        CharacterAvatarShape.circle => Icons.circle_outlined,
        CharacterAvatarShape.square => Icons.square_outlined,
        CharacterAvatarShape.rectangle => Icons.crop_portrait_outlined,
      };

  String getDisplayName(AppLocalizations l10n) => switch (this) {
        CharacterAvatarShape.circle => l10n.characterAvatarShapeCircle,
        CharacterAvatarShape.square => l10n.characterAvatarShapeSquare,
        CharacterAvatarShape.rectangle => l10n.characterAvatarShapeRectangle,
      };
}

extension CharacterViewModeExtension on CharacterViewMode {
  /// Get the next view mode when cycling through modes
  CharacterViewMode get next {
    switch (this) {
      case CharacterViewMode.list:
        return CharacterViewMode.simpleList;
      case CharacterViewMode.simpleList:
        return CharacterViewMode.grid;
      case CharacterViewMode.grid:
        return CharacterViewMode.compactGrid;
      case CharacterViewMode.compactGrid:
        return CharacterViewMode.list;
    }
  }

  /// Icon for this view mode (AppBar + picker drawer).
  IconData get icon => switch (this) {
        CharacterViewMode.list => Icons.view_agenda_outlined,
        CharacterViewMode.simpleList => Icons.view_list_outlined,
        CharacterViewMode.grid => Icons.grid_view,
        CharacterViewMode.compactGrid => Icons.view_compact,
      };

  /// Get display name for this view mode
  String getDisplayName(AppLocalizations l10n) {
    switch (this) {
      case CharacterViewMode.list:
        return l10n.listView;
      case CharacterViewMode.simpleList:
        return l10n.simpleListView;
      case CharacterViewMode.grid:
        return l10n.gridView;
      case CharacterViewMode.compactGrid:
        return l10n.compactGridView;
    }
  }
}
