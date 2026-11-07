import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/character_folder.dart';
import 'package:native_tavern/data/repositories/character_folder_repository.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';

/// null = library root; otherwise the open folder id.
final characterBrowseFolderIdProvider = StateProvider<String?>((ref) => null);

/// When true inside a folder, character search spans the whole library.
final characterSearchGlobalProvider = StateProvider<bool>((ref) => false);

/// Metadata for the currently open browse folder (null at library root).
final characterBrowseFolderProvider =
    FutureProvider<CharacterFolder?>((ref) async {
  final id = ref.watch(characterBrowseFolderIdProvider);
  if (id == null) return null;
  return ref.read(characterFolderRepositoryProvider).getFolder(id);
});

/// Child folders of the current browse location.
final characterFoldersProvider =
    AsyncNotifierProvider<CharacterFoldersNotifier, List<CharacterFolder>>(
  CharacterFoldersNotifier.new,
);

class CharacterFoldersNotifier extends AsyncNotifier<List<CharacterFolder>> {
  @override
  Future<List<CharacterFolder>> build() async {
    final parentId = ref.watch(characterBrowseFolderIdProvider);
    return ref
        .read(characterFolderRepositoryProvider)
        .listFolders(parentId: parentId);
  }

  Future<void> refresh() async {
    final parentId = ref.read(characterBrowseFolderIdProvider);
    state = await AsyncValue.guard(
      () => ref
          .read(characterFolderRepositoryProvider)
          .listFolders(parentId: parentId),
    );
  }

  Future<CharacterFolder> createFolder(
    String name, {
    String? parentId,
  }) async {
    final folder = await ref.read(characterFolderRepositoryProvider).createFolder(
          name,
          parentId: parentId ?? ref.read(characterBrowseFolderIdProvider),
        );
    await refresh();
    return folder;
  }

  Future<CharacterFolder> renameFolder(String id, String name) async {
    final folder = await ref
        .read(characterFolderRepositoryProvider)
        .renameFolder(id, name);
    await refresh();
    return folder;
  }

  Future<void> dissolveFolder(String id) async {
    final repo = ref.read(characterFolderRepositoryProvider);
    final folder = await repo.getFolder(id);
    final parentId = folder?.parentId;
    await repo.dissolveFolder(id);
    if (ref.read(characterBrowseFolderIdProvider) == id) {
      ref.read(characterBrowseFolderIdProvider.notifier).state = parentId;
    }
    await refresh();
  }

  /// Deletes the folder tree and soft-deletes every character inside it.
  Future<void> deleteFolder(String id) async {
    final repo = ref.read(characterFolderRepositoryProvider);
    final characterRepo = ref.read(characterRepositoryProvider);
    final folder = await repo.getFolder(id);
    final parentId = folder?.parentId;
    final characterIds = await repo.deleteFolderTree(id);
    for (final characterId in characterIds) {
      await characterRepo.deleteCharacter(characterId);
    }
    final browseId = ref.read(characterBrowseFolderIdProvider);
    if (browseId != null) {
      final stillThere = await repo.getFolder(browseId);
      if (stillThere == null) {
        ref.read(characterBrowseFolderIdProvider.notifier).state = parentId;
      }
    }
    await refresh();
  }

  Future<void> moveCharacters(
    Iterable<String> characterIds, {
    String? folderId,
  }) async {
    await ref.read(characterFolderRepositoryProvider).moveCharactersToFolder(
          characterIds,
          folderId: folderId,
        );
    await refresh();
  }

  Future<void> reparentFolders(
    Iterable<String> folderIds, {
    String? parentId,
  }) async {
    final repo = ref.read(characterFolderRepositoryProvider);
    for (final id in folderIds) {
      if (id == parentId) continue;
      await repo.reparentFolder(id, parentId: parentId);
    }
    await refresh();
  }
}
