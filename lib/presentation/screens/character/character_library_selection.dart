import 'package:flutter/foundation.dart';

/// Multi-select state for the character library browser.
class LibrarySelectionController extends ChangeNotifier {
  bool selectionMode = false;
  final Set<String> characterIds = <String>{};
  final Set<String> folderIds = <String>{};

  int get selectedItemCount => characterIds.length + folderIds.length;

  bool get hasSelection => selectedItemCount > 0;

  void exit() {
    if (!selectionMode && characterIds.isEmpty && folderIds.isEmpty) return;
    selectionMode = false;
    characterIds.clear();
    folderIds.clear();
    notifyListeners();
  }

  void enter({String? characterId, String? folderId}) {
    selectionMode = true;
    characterIds
      ..clear()
      ..addAll(characterId == null ? const <String>[] : [characterId]);
    folderIds
      ..clear()
      ..addAll(folderId == null ? const <String>[] : [folderId]);
    notifyListeners();
  }

  void toggleCharacter(String characterId) {
    if (characterIds.contains(characterId)) {
      characterIds.remove(characterId);
    } else {
      characterIds.add(characterId);
    }
    // Stay in selection mode even at 0 checked items until explicit exit.
    notifyListeners();
  }

  void toggleFolder(String folderId) {
    if (folderIds.contains(folderId)) {
      folderIds.remove(folderId);
    } else {
      folderIds.add(folderId);
    }
    notifyListeners();
  }

  void toggleSelectAll({
    required List<String> characterIds,
    required List<String> folderIds,
  }) {
    final allSelected = characterIds.every(this.characterIds.contains) &&
        folderIds.every(this.folderIds.contains) &&
        this.characterIds.length == characterIds.length &&
        this.folderIds.length == folderIds.length &&
        (characterIds.isNotEmpty || folderIds.isNotEmpty);
    if (allSelected) {
      this.characterIds.clear();
      this.folderIds.clear();
      selectionMode = true;
      notifyListeners();
      return;
    }
    selectionMode = true;
    this.characterIds
      ..clear()
      ..addAll(characterIds);
    this.folderIds
      ..clear()
      ..addAll(folderIds);
    notifyListeners();
  }
}
