import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/character_folder.dart';
import 'package:native_tavern/data/repositories/character_folder_repository.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';

/// null = library root; otherwise the open folder id.
final characterBrowseFolderIdProvider = StateProvider<String?>((ref) => null);

/// When true inside a folder, character search spans the whole library.
final characterSearchGlobalProvider = StateProvider<bool>((ref) => false);

/// One-shot: collapse folders deeper than [CharacterFolderRepository.maxFolderDepth].
final characterFolderDepthNormalizeProvider = FutureProvider<int>((ref) async {
  return ref
      .read(characterFolderRepositoryProvider)
      .enforceMaxFolderDepth();
});

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
  int _previewGeneration = 0;

  @override
  Future<List<CharacterFolder>> build() async {
    _previewGeneration++;
    // Ensure deep trees are flattened before the first browse paint.
    await ref.watch(characterFolderDepthNormalizeProvider.future);

    final parentId = ref.watch(characterBrowseFolderIdProvider);
    final repo = ref.read(characterFolderRepositoryProvider);
    // Metadata only — cover mosaics attach after first paint.
    final folders = await repo.listFolders(
      parentId: parentId,
      includePreviews: false,
    );
    _schedulePreviewAttach(parentId: parentId, folders: folders);
    return folders;
  }

  Future<void> refresh() async {
    final parentId = ref.read(characterBrowseFolderIdProvider);
    final repo = ref.read(characterFolderRepositoryProvider);
    state = await AsyncValue.guard(() async {
      final folders = await repo.listFolders(
        parentId: parentId,
        includePreviews: false,
      );
      _schedulePreviewAttach(parentId: parentId, folders: folders);
      return folders;
    });
  }

  void _schedulePreviewAttach({
    required String? parentId,
    required List<CharacterFolder> folders,
  }) {
    if (folders.isEmpty) return;
    final generation = ++_previewGeneration;
    final repo = ref.read(characterFolderRepositoryProvider);
    // Wait until after first character-grid paint, then hydrate mosaics so
    // cover-avatar decoding does not compete with the initial tile wave.
    Future<void>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (generation != _previewGeneration) return;
      final hydrated = await repo.attachPreviews(folders);
      if (generation != _previewGeneration) return;
      if (ref.read(characterBrowseFolderIdProvider) != parentId) return;
      state = AsyncData(hydrated);
    });
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
