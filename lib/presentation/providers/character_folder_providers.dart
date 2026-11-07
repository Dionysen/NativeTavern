import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/character_folder.dart';
import 'package:native_tavern/data/repositories/character_folder_repository.dart';

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
    await repo.dissolveFolder(id);
    final browseId = ref.read(characterBrowseFolderIdProvider);
    if (browseId == id) {
      ref.read(characterBrowseFolderIdProvider.notifier).state =
          folder?.parentId;
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
}
