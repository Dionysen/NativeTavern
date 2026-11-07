import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/models/tag.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/data/models/character_folder.dart';
import 'package:native_tavern/presentation/providers/character_folder_providers.dart';
import 'package:native_tavern/presentation/providers/character_providers.dart';
import 'package:native_tavern/data/repositories/character_folder_repository.dart';
import 'package:native_tavern/presentation/widgets/character/character_folder_tiles.dart';
import 'package:native_tavern/presentation/widgets/character/character_folder_ui.dart';
import 'package:native_tavern/presentation/widgets/character/character_library_ops.dart';
import 'package:native_tavern/presentation/widgets/character/character_tag_filter_sheet.dart';
import 'package:native_tavern/presentation/providers/chat_providers.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';
import 'package:native_tavern/presentation/theme/zephyr_chat_chrome.dart';
import 'package:native_tavern/presentation/widgets/common/character_avatar_image.dart';
import 'package:native_tavern/presentation/utils/destructive_confirm.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_action_drawer.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:native_tavern/presentation/widgets/common/intercept_pop_scope.dart';
import 'character_view_mode.dart';

/// Character list screen
class CharacterListScreen extends ConsumerStatefulWidget {
  const CharacterListScreen({super.key});

  @override
  ConsumerState<CharacterListScreen> createState() =>
      _CharacterListScreenState();
}

class _CharacterListScreenState extends ConsumerState<CharacterListScreen> {
  String _searchQuery = '';
  Timer? _searchDebounce;
  final _LibrarySelectionController _selection = _LibrarySelectionController();
  bool _folderEnterForward = true;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _selection.dispose();
    super.dispose();
  }

  void _exitSelectionMode() => _selection.exit();

  void _enterSelectionMode({String? characterId, String? folderId}) {
    _selection.enter(characterId: characterId, folderId: folderId);
  }

  void _toggleCharacterSelection(String characterId) {
    _selection.toggleCharacter(characterId);
  }

  void _toggleFolderSelection(String folderId) {
    _selection.toggleFolder(folderId);
  }

  Future<void> _toggleSelectAllLibraryItems() async {
    final characterIds =
        await ref.read(characterListProvider.notifier).listBrowseCharacterIds();
    final folderIds = (ref.read(characterFoldersProvider).valueOrNull ??
            const <CharacterFolder>[])
        .map((folder) => folder.id)
        .toList(growable: false);
    if (!mounted) return;
    _selection.toggleSelectAll(
      characterIds: characterIds,
      folderIds: folderIds,
    );
  }

  void _openFolder(String folderId) {
    setState(() => _folderEnterForward = true);
    _exitSelectionMode();
    ref.read(characterBrowseFolderIdProvider.notifier).state = folderId;
  }

  Future<void> _leaveFolder() async {
    setState(() => _folderEnterForward = false);
    _exitSelectionMode();
    ref.read(characterSearchGlobalProvider.notifier).state = false;
    final currentId = ref.read(characterBrowseFolderIdProvider);
    if (currentId == null) return;
    final parentId = await ref
        .read(characterFolderRepositoryProvider)
        .parentIdOfFolder(currentId);
    if (!mounted) return;
    ref.read(characterBrowseFolderIdProvider.notifier).state = parentId;
  }

  Future<void> _createEmptyFolder() async {
    final l10n = AppLocalizations.of(context);
    final name = await promptCharacterFolderName(
      context,
      title: l10n.createCharacterFolder,
    );
    if (name == null || !mounted) return;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    try {
      await ref.read(characterFoldersProvider.notifier).createFolder(name);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_folderActionErrorMessage(l10n, error))),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.createCharacterFolder)),
    );
  }

  Future<void> _onLibraryMoreSelected(String action) async {
    final browseFolderId = ref.read(characterBrowseFolderIdProvider);
    final currentFolder = browseFolderId == null
        ? null
        : await ref
            .read(characterFolderRepositoryProvider)
            .getFolder(browseFolderId);
    if (!mounted) return;

    switch (action) {
      case 'create_folder':
        await _createEmptyFolder();
      case 'import_folder':
        await importCharacterLibraryFromFolder(context, ref);
      case 'export_library':
        await exportCharacterLibraryToFolder(context, ref);
      case 'import_fast_pack':
        await importCharacterLibraryFastPack(context, ref);
      case 'export_fast_pack':
        await exportCharacterLibraryFastPack(context, ref);
      case 'rename_folder':
        if (currentFolder != null) {
          await renameCharacterFolder(context, ref, currentFolder);
        }
      case 'dissolve_folder':
        if (currentFolder != null) {
          await dissolveCharacterFolder(context, ref, currentFolder);
        }
      case 'delete_folder':
        if (currentFolder != null) {
          await deleteCharacterFolder(context, ref, currentFolder);
        }
    }
  }

  Future<void> _createFolderFromSelection() async {
    if (_selection.characterIds.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final name = await promptCharacterFolderName(
      context,
      title: l10n.createFolderFromSelection,
    );
    if (name == null || !mounted) return;
    try {
      final folder =
          await ref.read(characterFoldersProvider.notifier).createFolder(name);
      await ref.read(characterFoldersProvider.notifier).moveCharacters(
            _selection.characterIds,
            folderId: folder.id,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_folderActionErrorMessage(l10n, error))),
      );
      return;
    }
    await ref.read(characterListProvider.notifier).refresh();
    _exitSelectionMode();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.charactersMovedToFolder)),
      );
    }
  }

  Future<void> _moveSelectedItems() async {
    if (!_selection.hasSelection) return;
    final l10n = AppLocalizations.of(context);
    final selection = await showCharacterFolderPathPicker(
      context,
      title: l10n.moveToFolder,
      confirmLabel: l10n.moveToFolder,
    );
    if (selection == null || !mounted) return;

    // Don't move a folder into itself / its descendant (repo also guards).
    final folderIds = _selection.folderIds
        .where((id) => id != selection.folderId)
        .toList(growable: false);
    try {
      if (folderIds.isNotEmpty) {
        await ref.read(characterFoldersProvider.notifier).reparentFolders(
              folderIds,
              parentId: selection.folderId,
            );
      }
      if (_selection.characterIds.isNotEmpty) {
        await ref.read(characterFoldersProvider.notifier).moveCharacters(
              _selection.characterIds,
              folderId: selection.folderId,
            );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_folderActionErrorMessage(l10n, error))),
      );
      return;
    }
    await ref.read(characterListProvider.notifier).refresh();
    _exitSelectionMode();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.charactersMovedToFolder)),
      );
    }
  }

  String _folderActionErrorMessage(AppLocalizations l10n, Object error) {
    if (error.toString().contains('Folder depth limit')) {
      return l10n.characterFolderDepthLimit(
        CharacterFolderRepository.maxFolderDepth,
      );
    }
    return '${l10n.error}: $error';
  }

  Future<void> _copySelectedCharacters() async {
    if (_selection.characterIds.isEmpty) return;
    await showCopyCharactersToFolderSheet(
      context,
      ref,
      _selection.characterIds,
    );
    _exitSelectionMode();
  }

  Future<void> _deleteSelectedItems() async {
    if (!_selection.hasSelection) return;
    final l10n = AppLocalizations.of(context);
    final characterCount = _selection.characterIds.length;
    final folderCount = _selection.folderIds.length;
    final confirmed = await confirmDestructiveAction(
      context,
      ref,
      title: folderCount > 0
          ? l10n.deleteSelectedLibraryItems
          : l10n.deleteSelectedCharacters,
      body: folderCount > 0
          ? l10n.deleteSelectedLibraryItemsConfirmation(
              characterCount,
              folderCount,
            )
          : l10n.deleteSelectedCharactersConfirmation(characterCount),
    );
    if (!confirmed || !mounted) return;

    final characterIds = List<String>.from(_selection.characterIds);
    final folderIds = List<String>.from(_selection.folderIds);
    for (final folderId in folderIds) {
      await ref.read(characterFoldersProvider.notifier).deleteFolder(folderId);
    }
    if (characterIds.isNotEmpty) {
      await ref
          .read(characterListProvider.notifier)
          .deleteCharacters(characterIds);
    } else {
      await ref.read(characterListProvider.notifier).refresh();
    }
    _exitSelectionMode();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          folderCount > 0
              ? l10n.deleteSelectedLibraryItems
              : l10n.charactersDeletedCount(characterCount),
        ),
      ),
    );
  }

  Future<void> _showViewModePicker() async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final current = ref.read(characterBrowseDisplayPrefsProvider).viewMode;
    final selected = await showAdaptiveActionDrawer<CharacterViewMode>(
      context: context,
      title: l10n.characterDisplayMode,
      actions: [
        for (final mode in CharacterViewMode.values)
          AdaptiveActionDrawerItem(
            value: mode,
            leading: Icon(
              mode.icon,
              color: mode == current ? scheme.primary : null,
            ),
            title: Text(
              mode.getDisplayName(l10n),
              style: mode == current
                  ? TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    )
                  : null,
            ),
          ),
      ],
    );
    if (selected == null || !mounted) return;
    await ref
        .read(characterBrowseDisplayPrefsProvider.notifier)
        .setViewMode(selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final charactersAsync = ref.watch(characterListProvider);
    final browseFolderId = ref.watch(characterBrowseFolderIdProvider);
    final tagFilter = ref.watch(characterBrowseTagFilterProvider);
    final foldersAsync = ref.watch(characterFoldersProvider);
    final displayPrefs = ref.watch(characterBrowseDisplayPrefsProvider);
    final viewMode = displayPrefs.viewMode;
    final avatarShape = displayPrefs.avatarShape;
    final browseFolderAsync = ref.watch(characterBrowseFolderProvider);
    final folderTitle = browseFolderAsync.valueOrNull?.name;

    ref.listen<String?>(characterBrowseFolderIdProvider, (previous, next) {
      if (previous == next) return;
      if (!mounted) return;
      if (previous == null && next != null) {
        setState(() => _folderEnterForward = true);
      } else if (previous != null && next == null) {
        setState(() => _folderEnterForward = false);
      } else if (previous != null && next != null) {
        setState(() => _folderEnterForward = true);
      }
    });

    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) {
        final selectionMode = _selection.selectionMode;
        final hasSelection = _selection.hasSelection;
        final selectedItemCount = _selection.selectedItemCount;
        return InterceptPopScope(
          // System back / Esc: leave multi-select, then nested folder, before
          // the shell route would exit the app.
          canPop: !selectionMode && browseFolderId == null,
          onIntercept: () {
            if (selectionMode) {
              _exitSelectionMode();
              return;
            }
            if (browseFolderId != null) {
              _leaveFolder();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: browseFolderId != null && !selectionMode
                  ? ChromeIconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: l10n.characterFolderRoot,
                      onPressed: _leaveFolder,
                    )
                  : selectionMode
                      ? ChromeIconButton(
                          icon: const Icon(Icons.close),
                          tooltip: l10n.cancel,
                          onPressed: _exitSelectionMode,
                        )
                      : null,
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(_folderEnterForward ? 0.08 : -0.08, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  key: ValueKey(
                    selectionMode
                        ? 'select-$selectedItemCount'
                        : (browseFolderId ?? 'root-title'),
                  ),
                  selectionMode
                      ? l10n.libraryItemsSelected(selectedItemCount)
                      : (folderTitle ?? l10n.characters),
                ),
              ),
              actions: spacedAppBarActions([
                if (selectionMode) ...[
                  ChromeIconButton(
                    icon: Icon(
                      hasSelection ? Icons.deselect : Icons.select_all,
                    ),
                    tooltip: hasSelection
                        ? l10n.deselectAllCharacters
                        : l10n.selectAllCharacters,
                    onPressed: _toggleSelectAllLibraryItems,
                  ),
                  if (_selection.characterIds.isNotEmpty &&
                      _selection.folderIds.isEmpty)
                    ChromeIconButton(
                      icon: const Icon(Icons.copy_all_outlined),
                      tooltip: l10n.copyToFolder,
                      onPressed: _copySelectedCharacters,
                    ),
                  if (hasSelection)
                    ChromeIconButton(
                      icon: const Icon(Icons.drive_file_move_outline),
                      tooltip: l10n.moveToFolder,
                      onPressed: _moveSelectedItems,
                    ),
                  if (_selection.characterIds.isNotEmpty)
                    ChromeIconButton(
                      icon: const Icon(Icons.create_new_folder_outlined),
                      tooltip: l10n.createFolderFromSelection,
                      onPressed: _createFolderFromSelection,
                    ),
                  if (hasSelection)
                    ChromeIconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.delete,
                      onPressed: _deleteSelectedItems,
                    ),
                  ChromeIconButton(
                    icon: const Icon(Icons.check),
                    tooltip: l10n.done,
                    onPressed: _exitSelectionMode,
                  ),
                ] else ...[
                  if (viewMode == CharacterViewMode.list)
                    ChromeIconButton(
                      icon: Icon(avatarShape.icon),
                      onPressed: () => ref
                          .read(characterBrowseDisplayPrefsProvider.notifier)
                          .cycleAvatarShape(),
                      tooltip: avatarShape.getDisplayName(l10n),
                    ),
                  ChromeIconButton(
                    icon: Icon(viewMode.icon),
                    onPressed: _showViewModePicker,
                    tooltip: l10n.characterDisplayMode,
                  ),
                  ChromeIconButton(
                    icon: const Icon(Icons.file_download_outlined),
                    tooltip: l10n.import,
                    onPressed: () => context.push(AppRoutes.import_),
                  ),
                  ChromeIconButton(
                    icon: const Icon(Icons.add),
                    tooltip: l10n.createCharacter,
                    onPressed: () => context.push(AppRoutes.characterCreate),
                  ),
                  AdaptiveActionMenuButton<String>(
                    tooltip: l10n.moreOptions,
                    title: l10n.characterLibraryManage,
                    itemBuilder: (context) => [
                      AdaptiveActionDrawerItem(
                        value: 'create_folder',
                        leading: const Icon(Icons.create_new_folder_outlined),
                        title: Text(l10n.createCharacterFolder),
                      ),
                      AdaptiveActionDrawerItem(
                        value: 'import_folder',
                        leading: const Icon(Icons.folder_open_outlined),
                        title: Text(l10n.importCharactersFromFolder),
                      ),
                      AdaptiveActionDrawerItem(
                        value: 'export_library',
                        leading: const Icon(Icons.drive_folder_upload_outlined),
                        title: Text(l10n.exportCharacterLibrary),
                      ),
                      AdaptiveActionDrawerItem(
                        value: 'import_fast_pack',
                        leading: const Icon(Icons.unarchive_outlined),
                        title: Text(l10n.importCharacterLibraryFastPack),
                      ),
                      AdaptiveActionDrawerItem(
                        value: 'export_fast_pack',
                        leading: const Icon(Icons.archive_outlined),
                        title: Text(l10n.exportCharacterLibraryFastPack),
                      ),
                      if (browseFolderId != null) ...[
                        AdaptiveActionDrawerItem(
                          value: 'rename_folder',
                          leading: const Icon(Icons.drive_file_rename_outline),
                          title: Text(l10n.renameCharacterFolder),
                          showDividerAbove: true,
                        ),
                        AdaptiveActionDrawerItem(
                          value: 'dissolve_folder',
                          leading: const Icon(Icons.folder_off_outlined),
                          title: Text(l10n.dissolveCharacterFolder),
                        ),
                        AdaptiveActionDrawerItem(
                          value: 'delete_folder',
                          leading: const Icon(Icons.delete_outline),
                          title: Text(l10n.deleteCharacterFolder),
                          destructive: true,
                        ),
                      ],
                    ],
                    onSelected: _onLibraryMoreSelected,
                  ),
                ],
              ]),
            ),
            body: Column(
              children: [
                _SearchBar(
                  showFolderScopeToggle: browseFolderId != null,
                  searchEntireLibrary:
                      ref.watch(characterSearchGlobalProvider),
                  tagFilterActive: tagFilter.isNotEmpty,
                  onOpenTagFilter: () =>
                      showCharacterTagFilterSheet(context, ref),
                  onToggleSearchScope: () {
                    final enableGlobal =
                        !ref.read(characterSearchGlobalProvider);
                    ref.read(characterSearchGlobalProvider.notifier).state =
                        enableGlobal;
                  },
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _searchDebounce?.cancel();
                    _searchDebounce =
                        Timer(const Duration(milliseconds: 250), () {
                      if (mounted) {
                        ref
                            .read(characterListProvider.notifier)
                            .setQuery(value);
                      }
                    });
                  },
                ),
                Expanded(
                  // Avoid AnimatedSwitcher remounts: destroying the whole grid
                  // forces every visible avatar to re-decode on folder changes.
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.extentAfter < 600) {
                        ref.read(characterListProvider.notifier).loadMore();
                      }
                      return false;
                    },
                    child: _buildBrowseContent(
                      charactersAsync: charactersAsync,
                      l10n: l10n,
                      browseFolderId: browseFolderId,
                      tagFilter: tagFilter,
                      foldersAsync: foldersAsync,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBrowseContent({
    required AsyncValue<List<Character>> charactersAsync,
    required AppLocalizations l10n,
    required String? browseFolderId,
    required Set<String> tagFilter,
    required AsyncValue<List<CharacterFolder>> foldersAsync,
  }) {
    // Prefer a lightweight wait over painting the previous folder's tiles
    // (those remount and re-decode avatars). Folders load without mosaics
    // first, so this should stay short.
    final waitingForFreshPage = (charactersAsync.isLoading &&
            !charactersAsync.hasValue) ||
        (foldersAsync.isLoading && !foldersAsync.hasValue) ||
        charactersAsync.isRefreshing ||
        foldersAsync.isRefreshing;
    if (waitingForFreshPage) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return charactersAsync.when(
      data: (characters) {
        return _buildCharacterBrowseList(
          characters: characters,
          l10n: l10n,
          browseFolderId: browseFolderId,
          tagFilter: tagFilter,
          foldersAsync: foldersAsync,
        );
      },
      loading: () => const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('${l10n.error}: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(characterListProvider.notifier).refresh(),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterBrowseList({
    required List<Character> characters,
    required AppLocalizations l10n,
    required String? browseFolderId,
    required Set<String> tagFilter,
    required AsyncValue<List<CharacterFolder>> foldersAsync,
  }) {
    final displayPrefs = ref.watch(characterBrowseDisplayPrefsProvider);
    final viewMode = displayPrefs.viewMode;
    final avatarShape = displayPrefs.avatarShape;
    final showFolders = _searchQuery.isEmpty && tagFilter.isEmpty;
    final folders = foldersAsync.valueOrNull ?? const <CharacterFolder>[];

    if (characters.isEmpty && (!showFolders || folders.isEmpty)) {
      return const _EmptyState();
    }

    final interaction = _CharacterTileInteraction(
      selectionMode: _selection.selectionMode,
      selectedIds: _selection.characterIds,
      onToggleSelect: _toggleCharacterSelection,
      onEnterSelection: (id) => _enterSelectionMode(characterId: id),
    );

    final visibleFolders = showFolders ? folders : const <CharacterFolder>[];
    void openFolderActions(CharacterFolder folder) {
      showCharacterFolderActions(context, ref, folder);
    }

    void onFolderTap(CharacterFolder folder) {
      if (_selection.selectionMode) {
        _toggleFolderSelection(folder.id);
        return;
      }
      _openFolder(folder.id);
    }

    void longPressFolder(CharacterFolder folder) {
      if (_selection.selectionMode) {
        _toggleFolderSelection(folder.id);
      } else {
        _enterSelectionMode(folderId: folder.id);
      }
    }

    switch (viewMode) {
      case CharacterViewMode.list:
        return _CharacterListView(
          folders: visibleFolders,
          characters: characters,
          avatarShape: avatarShape,
          interaction: interaction,
          selectedFolderIds: _selection.folderIds,
          selectionMode: _selection.selectionMode,
          onFolderTap: onFolderTap,
          onFolderLongPress: longPressFolder,
          onFolderActions: openFolderActions,
        );
      case CharacterViewMode.simpleList:
        return _CharacterSimpleListView(
          folders: visibleFolders,
          characters: characters,
          interaction: interaction,
          selectedFolderIds: _selection.folderIds,
          selectionMode: _selection.selectionMode,
          onFolderTap: onFolderTap,
          onFolderLongPress: longPressFolder,
          onFolderActions: openFolderActions,
        );
      case CharacterViewMode.grid:
        return _CharacterGridView(
          folders: visibleFolders,
          characters: characters,
          interaction: interaction,
          selectedFolderIds: _selection.folderIds,
          selectionMode: _selection.selectionMode,
          onFolderTap: onFolderTap,
          onFolderLongPress: longPressFolder,
          onFolderActions: openFolderActions,
        );
      case CharacterViewMode.compactGrid:
        return _CharacterCompactGridView(
          folders: visibleFolders,
          characters: characters,
          interaction: interaction,
          selectedFolderIds: _selection.folderIds,
          selectionMode: _selection.selectionMode,
          onFolderTap: onFolderTap,
          onFolderLongPress: longPressFolder,
          onFolderActions: openFolderActions,
        );
    }
  }
}

class _LibrarySelectionController extends ChangeNotifier {
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
    if (!hasSelection) {
      selectionMode = false;
    }
    notifyListeners();
  }

  void toggleFolder(String folderId) {
    if (folderIds.contains(folderId)) {
      folderIds.remove(folderId);
    } else {
      folderIds.add(folderId);
    }
    if (!hasSelection) {
      selectionMode = false;
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
      exit();
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

class _CharacterTileInteraction {
  const _CharacterTileInteraction({
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onEnterSelection,
  });

  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<String> onEnterSelection;

  void handleLongPress(String characterId) {
    if (selectionMode) {
      onToggleSelect(characterId);
    } else {
      onEnterSelection(characterId);
    }
  }
}

Widget _selectionBadge(BuildContext context, bool selected) {
  return Positioned(
    top: 8,
    right: 8,
    child: CircleAvatar(
      radius: 14,
      backgroundColor: selected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
      child: Icon(
        selected ? Icons.check : Icons.circle_outlined,
        size: 18,
        color: selected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.onChanged,
    required this.showFolderScopeToggle,
    required this.searchEntireLibrary,
    required this.onToggleSearchScope,
    required this.tagFilterActive,
    required this.onOpenTagFilter,
  });

  final ValueChanged<String> onChanged;
  final bool showFolderScopeToggle;
  final bool searchEntireLibrary;
  final VoidCallback onToggleSearchScope;
  final bool tagFilterActive;
  final VoidCallback onOpenTagFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: l10n.searchCharacters,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showFolderScopeToggle)
                ChromeIconButton(
                  icon: Icon(
                    searchEntireLibrary
                        ? Icons.public
                        : Icons.folder_outlined,
                  ),
                  isSelected: searchEntireLibrary,
                  tooltip: searchEntireLibrary
                      ? l10n.characterSearchScopeGlobal
                      : l10n.characterSearchScopeFolder,
                  onPressed: onToggleSearchScope,
                ),
              ChromeIconButton(
                icon: const Icon(Icons.filter_list),
                isSelected: tagFilterActive,
                tooltip: l10n.filterByTags,
                onPressed: onOpenTagFilter,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharacterGridView extends StatelessWidget {
  final List<CharacterFolder> folders;
  final List<Character> characters;
  final _CharacterTileInteraction interaction;
  final Set<String> selectedFolderIds;
  final bool selectionMode;
  final ValueChanged<CharacterFolder> onFolderTap;
  final ValueChanged<CharacterFolder> onFolderLongPress;
  final ValueChanged<CharacterFolder> onFolderActions;

  const _CharacterGridView({
    required this.folders,
    required this.characters,
    required this.interaction,
    required this.selectedFolderIds,
    required this.selectionMode,
    required this.onFolderTap,
    required this.onFolderLongPress,
    required this.onFolderActions,
  });

  int get _itemCount => folders.length + characters.length;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridColumns(constraints.maxWidth, 160, 12),
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _itemCount,
              itemBuilder: (context, index) {
                if (index < folders.length) {
                  final folder = folders[index];
                  return RepaintBoundary(
                    key: ValueKey('folder-${folder.id}'),
                    child: CharacterFolderGridCard(
                      folder: folder,
                      selectionMode: selectionMode,
                      selected: selectedFolderIds.contains(folder.id),
                      onTap: () => onFolderTap(folder),
                      onLongPress: () => onFolderLongPress(folder),
                      onSecondaryTap: selectionMode
                          ? () => onFolderTap(folder)
                          : () => onFolderActions(folder),
                    ),
                  );
                }
                final character = characters[index - folders.length];
                return RepaintBoundary(
                  key: ValueKey('character-${character.id}'),
                  child: _CharacterGridCard(
                    character: character,
                    interaction: interaction,
                  ),
                );
              },
            ));
  }
}

class _CharacterListView extends StatelessWidget {
  final List<CharacterFolder> folders;
  final List<Character> characters;
  final CharacterAvatarShape avatarShape;
  final _CharacterTileInteraction interaction;
  final Set<String> selectedFolderIds;
  final bool selectionMode;
  final ValueChanged<CharacterFolder> onFolderTap;
  final ValueChanged<CharacterFolder> onFolderLongPress;
  final ValueChanged<CharacterFolder> onFolderActions;

  const _CharacterListView({
    required this.folders,
    required this.characters,
    required this.avatarShape,
    required this.interaction,
    required this.selectedFolderIds,
    required this.selectionMode,
    required this.onFolderTap,
    required this.onFolderLongPress,
    required this.onFolderActions,
  });

  int get _itemCount => folders.length + characters.length;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _itemCount,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          final folder = folders[index];
          return RepaintBoundary(
            key: ValueKey('folder-${folder.id}'),
            child: CharacterFolderListTile(
              folder: folder,
              avatarShape: avatarShape,
              selectionMode: selectionMode,
              selected: selectedFolderIds.contains(folder.id),
              onTap: () => onFolderTap(folder),
              onLongPress: () => onFolderLongPress(folder),
              onSecondaryTap: selectionMode
                  ? () => onFolderTap(folder)
                  : () => onFolderActions(folder),
            ),
          );
        }
        final character = characters[index - folders.length];
        return RepaintBoundary(
          key: ValueKey('character-${character.id}'),
          child: _CharacterListTile(
            character: character,
            avatarShape: avatarShape,
            interaction: interaction,
          ),
        );
      },
    );
  }
}

/// Compact list rows: avatar + left-aligned name, fixed height, no tags.
class _CharacterSimpleListView extends StatelessWidget {
  final List<CharacterFolder> folders;
  final List<Character> characters;
  final _CharacterTileInteraction interaction;
  final Set<String> selectedFolderIds;
  final bool selectionMode;
  final ValueChanged<CharacterFolder> onFolderTap;
  final ValueChanged<CharacterFolder> onFolderLongPress;
  final ValueChanged<CharacterFolder> onFolderActions;

  const _CharacterSimpleListView({
    required this.folders,
    required this.characters,
    required this.interaction,
    required this.selectedFolderIds,
    required this.selectionMode,
    required this.onFolderTap,
    required this.onFolderLongPress,
    required this.onFolderActions,
  });

  static const double rowHeight = 60;
  static const double rowGap = 8;
  static const double avatarSize = 40;
  static const double itemExtent = rowHeight + rowGap;

  int get _itemCount => folders.length + characters.length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _itemCount,
      itemExtent: itemExtent,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          final folder = folders[index];
          final selected = selectedFolderIds.contains(folder.id);
          return RepaintBoundary(
            key: ValueKey('folder-${folder.id}'),
            child: Card(
              margin: const EdgeInsets.only(bottom: rowGap),
              clipBehavior: Clip.antiAlias,
              color: selected
                  ? scheme.primaryContainer.withValues(alpha: 0.45)
                  : null,
              child: SizedBox(
                height: rowHeight,
                child: InkWell(
                  onTap: () => onFolderTap(folder),
                  onLongPress: () => onFolderLongPress(folder),
                  onSecondaryTap: selectionMode
                      ? () => onFolderTap(folder)
                      : () => onFolderActions(folder),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        if (selectionMode) ...[
                          Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: selected ? scheme.primary : scheme.outline,
                          ),
                          const SizedBox(width: 8),
                        ],
                        SizedBox(
                          width: avatarSize,
                          height: avatarSize,
                          child: ClipOval(
                            child: CharacterFolderPreviewMosaic(
                              previews: folder.previewCharacters,
                              compact: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (!selectionMode)
                          Icon(
                            Icons.chevron_right,
                            color: scheme.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        final character = characters[index - folders.length];
        return RepaintBoundary(
          key: ValueKey('character-${character.id}'),
          child: _CharacterSimpleListTile(
            character: character,
            interaction: interaction,
          ),
        );
      },
    );
  }
}

class _CharacterSimpleListTile extends ConsumerWidget {
  final Character character;
  final _CharacterTileInteraction interaction;

  const _CharacterSimpleListTile({
    required this.character,
    required this.interaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final selected = interaction.selectedIds.contains(character.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: _CharacterSimpleListView.rowHeight,
        child: InkWell(
          onTap: () {
            if (interaction.selectionMode) {
              interaction.onToggleSelect(character.id);
              return;
            }
            context.push('/characters/${character.id}');
          },
          onLongPress: () => interaction.handleLongPress(character.id),
          onSecondaryTap: interaction.selectionMode
              ? () => interaction.onToggleSelect(character.id)
              : () => _showCharacterActionMenu(context, ref, character),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
            child: Row(
              children: [
                if (interaction.selectionMode) ...[
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                  const SizedBox(width: 8),
                ],
                _buildAvatar(context),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    character.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (!interaction.selectionMode)
                  AdaptiveActionMenuButton<String>(
                    tooltip: l10n.moreOptions,
                    title: character.name,
                    density: ChromeIconButtonDensity.compact,
                    itemBuilder: _characterActionItems,
                    onSelected: (value) => _handleCharacterAction(
                      context,
                      ref,
                      character,
                      value,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    const size = _CharacterSimpleListView.avatarSize;
    final scheme = Theme.of(context).colorScheme;
    return CharacterAvatarShaped(
      imagePath: character.assets?.avatarPath,
      width: size,
      height: size,
      shape: BoxShape.circle,
      borderRadius: size / 2,
      fallbackColor: characterAvatarFallbackColor(scheme, character.id),
      fallbackIcon: characterAvatarFallbackIcon(character.id),
    );
  }
}

class _CharacterCompactGridView extends StatelessWidget {
  final List<CharacterFolder> folders;
  final List<Character> characters;
  final _CharacterTileInteraction interaction;
  final Set<String> selectedFolderIds;
  final bool selectionMode;
  final ValueChanged<CharacterFolder> onFolderTap;
  final ValueChanged<CharacterFolder> onFolderLongPress;
  final ValueChanged<CharacterFolder> onFolderActions;

  const _CharacterCompactGridView({
    required this.folders,
    required this.characters,
    required this.interaction,
    required this.selectedFolderIds,
    required this.selectionMode,
    required this.onFolderTap,
    required this.onFolderLongPress,
    required this.onFolderActions,
  });

  int get _itemCount => folders.length + characters.length;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridColumns(constraints.maxWidth, 110, 8),
                childAspectRatio: 0.65,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _itemCount,
              itemBuilder: (context, index) {
                if (index < folders.length) {
                  final folder = folders[index];
                  return RepaintBoundary(
                    key: ValueKey('folder-${folder.id}'),
                    child: CharacterFolderGridCard(
                      folder: folder,
                      compact: true,
                      selectionMode: selectionMode,
                      selected: selectedFolderIds.contains(folder.id),
                      onTap: () => onFolderTap(folder),
                      onLongPress: () => onFolderLongPress(folder),
                      onSecondaryTap: selectionMode
                          ? () => onFolderTap(folder)
                          : () => onFolderActions(folder),
                    ),
                  );
                }
                final character = characters[index - folders.length];
                return RepaintBoundary(
                  key: ValueKey('character-${character.id}'),
                  child: _CharacterCompactGridCard(
                    character: character,
                    interaction: interaction,
                  ),
                );
              },
            ));
  }
}

int _gridColumns(double width, double minimumTileWidth, double spacing) {
  var count = ((width - 32 + spacing) / (minimumTileWidth + spacing))
      .floor()
      .clamp(1, 12);
  // Wider containers use symmetric columns, without identifying a device.
  if (width >= 600 && count > 1 && count.isOdd) count--;
  return count;
}

String _creatorLabel(Character character) {
  final creator = character.creator.trim();
  return creator.isEmpty ? 'Unknown' : creator;
}

Future<void> _handleCharacterAction(
  BuildContext context,
  WidgetRef ref,
  Character character,
  String action,
) async {
  switch (action) {
    case 'chat':
      await _startCharacterChat(context, ref, character);
    case 'edit':
      if (context.mounted) {
        context.push('/characters/${character.id}/edit');
      }
    case 'move':
      if (context.mounted) {
        await showMoveCharactersToFolderSheet(context, ref, [character.id]);
      }
    case 'export':
      break;
    case 'delete':
      await _confirmDeleteCharacter(context, ref, character);
  }
}

List<AdaptiveActionDrawerItem<String>> _characterActionItems(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context);
  return [
    AdaptiveActionDrawerItem(
      value: 'chat',
      leading: const Icon(Icons.chat),
      title: Text(l10n.startChat),
    ),
    AdaptiveActionDrawerItem(
      value: 'edit',
      leading: const Icon(Icons.edit),
      title: Text(l10n.edit),
    ),
    AdaptiveActionDrawerItem(
      value: 'move',
      leading: const Icon(Icons.drive_file_move_outline),
      title: Text(l10n.moveToFolder),
    ),
    AdaptiveActionDrawerItem(
      value: 'export',
      leading: const Icon(Icons.file_upload),
      title: Text(l10n.exportChat),
    ),
    AdaptiveActionDrawerItem(
      value: 'delete',
      leading: const Icon(Icons.delete_outline),
      title: Text(l10n.delete),
      destructive: true,
    ),
  ];
}

Future<void> _showCharacterActionMenu(
  BuildContext context,
  WidgetRef ref,
  Character character,
) async {
  final selected = await showAdaptiveActionDrawer<String>(
    context: context,
    title: character.name,
    actions: _characterActionItems(context),
  );
  if (selected == null || !context.mounted) return;
  await _handleCharacterAction(context, ref, character, selected);
}

/// Top-right overflow control on grid/compact character cards.
Widget _characterCardMoreOverlay({
  required BuildContext context,
  required WidgetRef ref,
  required Character character,
}) {
  final l10n = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  return Positioned(
    top: 4,
    right: 4,
    child: Material(
      color: scheme.surface.withValues(alpha: 0.82),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: AdaptiveActionMenuButton<String>(
        density: ChromeIconButtonDensity.compact,
        tooltip: l10n.moreOptions,
        title: character.name,
        itemBuilder: _characterActionItems,
        onSelected: (value) => _handleCharacterAction(
          context,
          ref,
          character,
          value,
        ),
      ),
    ),
  );
}

Future<void> _startCharacterChat(
  BuildContext context,
  WidgetRef ref,
  Character character,
) async {
  final l10n = AppLocalizations.of(context);

  try {
    final chatId =
        await ref.read(activeChatProvider.notifier).createChat(character.id);
    if (chatId != null && context.mounted) {
      context.push('/chat/$chatId');
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.error)),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.error}: $e')),
      );
    }
  }
}

Future<void> _confirmDeleteCharacter(
  BuildContext context,
  WidgetRef ref,
  Character character,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await confirmDestructiveAction(
    context,
    ref,
    title: l10n.deleteCharacter,
    body: l10n.deleteCharacterConfirmation(character.name),
  );
  if (!confirmed) return;

  ref.read(characterListProvider.notifier).deleteCharacter(character.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.characterDeleted)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noCharactersYet,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.importCharacter,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ZephyrChatChrome.withComposerShadow(
                context: context,
                child: ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.characterCreate),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.createCharacter),
                ),
              ),
              const SizedBox(width: 16),
              ZephyrChatChrome.withComposerShadow(
                context: context,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.import_),
                  icon: const Icon(Icons.file_download),
                  label: Text(l10n.import),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterGridCard extends ConsumerWidget {
  final Character character;
  final _CharacterTileInteraction interaction;

  const _CharacterGridCard({
    required this.character,
    required this.interaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = interaction.selectedIds.contains(character.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (interaction.selectionMode) {
            interaction.onToggleSelect(character.id);
            return;
          }
          context.push('/characters/${character.id}');
        },
        onLongPress: () => interaction.handleLongPress(character.id),
        onSecondaryTap: interaction.selectionMode
            ? () => interaction.onToggleSelect(character.id)
            : () => _showCharacterActionMenu(context, ref, character),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: _buildAvatar(context),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    character.name,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'by ${_creatorLabel(character)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
            ),
            if (interaction.selectionMode)
              _selectionBadge(context, selected)
            else
              _characterCardMoreOverlay(
                context: context,
                ref: ref,
                character: character,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    if (character.assets?.avatarPath != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final cacheSide = constraints.biggest.longestSide;
          return CharacterAvatarImage(
            imagePath: character.assets!.avatarPath!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            cacheWidth: cacheSide,
            errorBuilder: (context, _, __) => _defaultAvatar(context),
          );
        },
      );
    }
    return _defaultAvatar(context);
  }

  Widget _defaultAvatar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = characterAvatarFallbackColor(scheme, character.id);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          characterAvatarFallbackIcon(character.id),
          size: 60,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}

class _CharacterCompactGridCard extends ConsumerWidget {
  final Character character;
  final _CharacterTileInteraction interaction;

  const _CharacterCompactGridCard({
    required this.character,
    required this.interaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = interaction.selectedIds.contains(character.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (interaction.selectionMode) {
            interaction.onToggleSelect(character.id);
            return;
          }
          context.push('/characters/${character.id}');
        },
        onLongPress: () => interaction.handleLongPress(character.id),
        onSecondaryTap: interaction.selectionMode
            ? () => interaction.onToggleSelect(character.id)
            : () => _showCharacterActionMenu(context, ref, character),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: _buildCompactAvatar(context),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'by ${_creatorLabel(character)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
            ),
            if (interaction.selectionMode)
              _selectionBadge(context, selected)
            else
              _characterCardMoreOverlay(
                context: context,
                ref: ref,
                character: character,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactAvatar(BuildContext context) {
    if (character.assets?.avatarPath != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final cacheSide = constraints.biggest.longestSide;
          return CharacterAvatarImage(
            imagePath: character.assets!.avatarPath!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            cacheWidth: cacheSide,
            errorBuilder: (context, _, __) => _defaultCompactAvatar(context),
          );
        },
      );
    }
    return _defaultCompactAvatar(context);
  }

  Widget _defaultCompactAvatar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = characterAvatarFallbackColor(scheme, character.id);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          characterAvatarFallbackIcon(character.id),
          size: 40,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}

class _CharacterListTile extends ConsumerWidget {
  final Character character;
  final CharacterAvatarShape avatarShape;
  final _CharacterTileInteraction interaction;

  const _CharacterListTile({
    required this.character,
    required this.avatarShape,
    required this.interaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metaStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      height: 1.3,
      color: scheme.onSurfaceVariant,
    );
    final description = character.description.isNotEmpty
        ? character.description
        : l10n.description;
    final selected = interaction.selectedIds.contains(character.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (interaction.selectionMode) {
            interaction.onToggleSelect(character.id);
            return;
          }
          context.push('/characters/${character.id}');
        },
        onLongPress: () => interaction.handleLongPress(character.id),
        onSecondaryTap: interaction.selectionMode
            ? () => interaction.onToggleSelect(character.id)
            : () => _showCharacterActionMenu(context, ref, character),
        child: Padding(
          // Matching vertical insets: title top == tags bottom.
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (interaction.selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                ),
              _buildListAvatar(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      character.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: metaStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (character.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: character.tags
                            .map((tag) {
                              final color = TagColors.forLabel(tag);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: metaStyle?.copyWith(
                                    color: color.withValues(alpha: 0.65),
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
              if (!interaction.selectionMode)
                AdaptiveActionMenuButton<String>(
                  tooltip: l10n.moreOptions,
                  title: character.name,
                  itemBuilder: _characterActionItems,
                  onSelected: (value) => _handleCharacterAction(
                    context,
                    ref,
                    character,
                    value,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListAvatar(BuildContext context) {
    // Keep a shared width so list rows align when switching shapes.
    const width = 56.0;
    final (height, shape, radius) = switch (avatarShape) {
      CharacterAvatarShape.circle => (width, BoxShape.circle, width / 2),
      CharacterAvatarShape.square => (width, BoxShape.rectangle, 8.0),
      CharacterAvatarShape.rectangle => (width * 4 / 3, BoxShape.rectangle, 8.0),
    };

    final scheme = Theme.of(context).colorScheme;
    return CharacterAvatarShaped(
      imagePath: character.assets?.avatarPath,
      width: width,
      height: height,
      shape: shape,
      borderRadius: radius,
      fallbackColor: characterAvatarFallbackColor(scheme, character.id),
      fallbackIcon: characterAvatarFallbackIcon(character.id),
    );
  }
}
