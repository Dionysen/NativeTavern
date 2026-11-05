import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/character_folder.dart';
import 'package:native_tavern/data/repositories/character_folder_repository.dart';

/// null = library root; otherwise the open folder id.
final characterBrowseFolderIdProvider = StateProvider<String?>((ref) => null);

/// When true inside a folder, character search spans the whole library.
final characterSearchGlobalProvider = StateProvider<bool>((ref) => false);

final characterFoldersProvider =
    AsyncNotifierProvider<CharacterFoldersNotifier, List<CharacterFolder>>(
  CharacterFoldersNotifier.new,
);

class CharacterFoldersNotifier extends AsyncNotifier<List<CharacterFolder>> {
  @override
  Future<List<CharacterFolder>> build() async {
    return ref.read(characterFolderRepositoryProvider).listFolders();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(characterFolderRepositoryProvider).listFolders(),
    );
  }

  Future<CharacterFolder> createFolder(String name) async {
    final folder =
        await ref.read(characterFolderRepositoryProvider).createFolder(name);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData([...current, folder]);
    }
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
    await ref.read(characterFolderRepositoryProvider).dissolveFolder(id);
    if (ref.read(characterBrowseFolderIdProvider) == id) {
      ref.read(characterBrowseFolderIdProvider.notifier).state = null;
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
