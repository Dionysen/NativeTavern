import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/character_folder.dart';
import 'package:native_tavern/data/repositories/character_folder_repository.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/presentation/providers/chat_providers.dart';

/// Folder browse path from library root (empty = root). Last id is current.
final characterBrowsePathProvider =
    StateNotifierProvider<CharacterBrowsePathNotifier, List<String>>((ref) {
  return CharacterBrowsePathNotifier(ref);
});

class CharacterBrowsePathNotifier extends StateNotifier<List<String>> {
  CharacterBrowsePathNotifier(this._ref) : super(const []);

  final Ref _ref;

  String? get currentFolderId => state.isEmpty ? null : state.last;

  void enterFolder(String folderId) {
    final id = folderId.trim();
    if (id.isEmpty) return;
    if (state.isNotEmpty && state.last == id) return;
    state = [...state, id];
  }

  /// Pop one level. No-op at root.
  void leaveFolder() {
    if (state.isEmpty) return;
    state = state.sublist(0, state.length - 1);
  }

  /// Jump to breadcrumb depth. [index] `-1` = root; `0` = first folder, etc.
  void jumpToDepth(int index) {
    if (index < -1) return;
    if (index < 0) {
      if (state.isEmpty) return;
      state = const [];
      return;
    }
    if (index >= state.length - 1) return;
    state = state.sublist(0, index + 1);
  }

  void replacePath(List<String> path) {
    state = List<String>.unmodifiable(path);
  }

  /// Drop any trailing segments whose folders no longer exist.
  Future<void> truncateToExistingAncestors() async {
    if (state.isEmpty) return;
    final repo = _ref.read(characterFolderRepositoryProvider);
    final kept = <String>[];
    for (final id in state) {
      final folder = await repo.getFolder(id);
      if (folder == null) break;
      kept.add(id);
    }
    if (kept.length != state.length) {
      state = List<String>.unmodifiable(kept);
    }
  }
}

/// null = library root; otherwise the open folder id (derived from path stack).
final characterBrowseFolderIdProvider = Provider<String?>((ref) {
  final path = ref.watch(characterBrowsePathProvider);
  return path.isEmpty ? null : path.last;
});

/// When true inside a folder, character search spans the whole library.
final characterSearchGlobalProvider = StateProvider<bool>((ref) => false);

/// Synced from the character library screen — used by [AppShell] so Android
/// back can unwind selection even though the screen sits under IndexedStack.
final characterLibrarySelectionActiveProvider =
    StateProvider<bool>((ref) => false);

/// Characters tab index in [StatefulNavigationShell] / bottom nav.
const characterLibraryShellBranchIndex = 1;

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

/// Breadcrumb folders for the current path (root → current), skipping missing.
final characterBrowseBreadcrumbProvider =
    FutureProvider<List<CharacterFolder>>((ref) async {
  final path = ref.watch(characterBrowsePathProvider);
  if (path.isEmpty) return const [];
  final repo = ref.read(characterFolderRepositoryProvider);
  final crumbs = <CharacterFolder>[];
  for (final id in path) {
    final folder = await repo.getFolder(id);
    if (folder == null) break;
    crumbs.add(folder);
  }
  return crumbs;
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
    ref.invalidate(characterBrowseBreadcrumbProvider);
    return folder;
  }

  Future<void> dissolveFolder(String id) async {
    final repo = ref.read(characterFolderRepositoryProvider);
    await repo.dissolveFolder(id);
    await ref
        .read(characterBrowsePathProvider.notifier)
        .truncateToExistingAncestors();
    ref.invalidate(characterBrowseBreadcrumbProvider);
    await refresh();
  }

  /// Deletes the folder tree and soft-deletes every character inside it.
  Future<void> deleteFolder(String id) async {
    final repo = ref.read(characterFolderRepositoryProvider);
    final characterRepo = ref.read(characterRepositoryProvider);
    final characterIds = await repo.deleteFolderTree(id);
    for (final characterId in characterIds) {
      await characterRepo.deleteCharacter(characterId);
    }
    await ref
        .read(characterBrowsePathProvider.notifier)
        .truncateToExistingAncestors();
    ref.invalidate(characterBrowseBreadcrumbProvider);
    // Solo chats for deleted characters are removed in deleteCharacter;
    // refresh chat lists so the home screen drops them immediately.
    ref.invalidate(pagedChatsProvider);
    ref.invalidate(allChatsProvider);
    ref.invalidate(recentChatsProvider);
    for (final characterId in characterIds) {
      ref.invalidate(characterChatsProvider(characterId));
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
    await ref
        .read(characterBrowsePathProvider.notifier)
        .truncateToExistingAncestors();
    ref.invalidate(characterBrowseBreadcrumbProvider);
    await refresh();
  }
}
