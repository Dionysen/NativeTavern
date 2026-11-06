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
import 'package:native_tavern/presentation/widgets/character/character_folder_tiles.dart';
import 'package:native_tavern/presentation/widgets/character/character_folder_ui.dart';
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
  bool _selectionMode = false;
  final Set<String> _selectedCharacterIds = {};
  bool _folderEnterForward = true;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedCharacterIds.clear();
    });
  }

  void _enterSelectionMode([String? characterId]) {
    setState(() {
      _selectionMode = true;
      _selectedCharacterIds.clear();
      if (characterId != null) {
        _selectedCharacterIds.add(characterId);
      }
    });
  }

  void _toggleCharacterSelection(String characterId) {
    setState(() {
      if (_selectedCharacterIds.contains(characterId)) {
        _selectedCharacterIds.remove(characterId);
        if (_selectedCharacterIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedCharacterIds.add(characterId);
      }
    });
  }

  void _openFolder(String folderId) {
    setState(() => _folderEnterForward = true);
    _exitSelectionMode();
    ref.read(characterBrowseFolderIdProvider.notifier).state = folderId;
  }

  void _leaveFolder() {
    setState(() => _folderEnterForward = false);
    _exitSelectionMode();
    ref.read(characterSearchGlobalProvider.notifier).state = false;
    ref.read(characterBrowseFolderIdProvider.notifier).state = null;
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
    await ref.read(characterFoldersProvider.notifier).createFolder(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.createCharacterFolder)),
    );
  }

  Future<void> _createFolderFromSelection() async {
    if (_selectedCharacterIds.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final name = await promptCharacterFolderName(
      context,
      title: l10n.createFolderFromSelection,
    );
    if (name == null || !mounted) return;
    final folder =
        await ref.read(characterFoldersProvider.notifier).createFolder(name);
    await ref.read(characterFoldersProvider.notifier).moveCharacters(
          _selectedCharacterIds,
          folderId: folder.id,
        );
    await ref.read(characterListProvider.notifier).refresh();
    _exitSelectionMode();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.charactersMovedToFolder)),
      );
    }
  }

  Future<void> _moveSelectedCharacters() async {
    if (_selectedCharacterIds.isEmpty) return;
    await showMoveCharactersToFolderSheet(
      context,
      ref,
      _selectedCharacterIds,
    );
    _exitSelectionMode();
  }

  Future<void> _deleteSelectedCharacters() async {
    if (_selectedCharacterIds.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final count = _selectedCharacterIds.length;
    final confirmed = await confirmDestructiveAction(
      context,
      ref,
      title: l10n.deleteSelectedCharacters,
      body: l10n.deleteSelectedCharactersConfirmation(count),
    );
    if (!confirmed || !mounted) return;

    final ids = List<String>.from(_selectedCharacterIds);
    await ref.read(characterListProvider.notifier).deleteCharacters(ids);
    _exitSelectionMode();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.charactersDeletedCount(count))),
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
    final folderTitle = browseFolderId == null
        ? null
        : foldersAsync.valueOrNull
            ?.where((folder) => folder.id == browseFolderId)
            .map((folder) => folder.name)
            .firstOrNull;

    ref.listen<String?>(characterBrowseFolderIdProvider, (previous, next) {
      if (previous == next) return;
      if (!mounted) return;
      if (previous == null && next != null) {
        setState(() => _folderEnterForward = true);
      } else if (previous != null && next == null) {
        setState(() => _folderEnterForward = false);
      }
    });

    return PopScope(
      // System/back: leave multi-select first; do not pop the shell/tab route.
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        leading: browseFolderId != null && !_selectionMode
            ? ChromeIconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.characterFolderRoot,
                onPressed: _leaveFolder,
              )
            : _selectionMode
                ? ChromeIconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.cancel,
                    onPressed: _exitSelectionMode,
                  )
                : null,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
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
              _selectionMode
                  ? 'select-${_selectedCharacterIds.length}'
                  : (browseFolderId ?? 'root-title'),
            ),
            _selectionMode
                ? l10n.charactersSelected(_selectedCharacterIds.length)
                : (folderTitle ?? l10n.characters),
          ),
        ),
        actions: spacedAppBarActions([
          if (_selectionMode) ...[
            if (_selectedCharacterIds.isNotEmpty)
              ChromeIconButton(
                icon: const Icon(Icons.drive_file_move_outline),
                tooltip: l10n.moveToFolder,
                onPressed: _moveSelectedCharacters,
              ),
            if (_selectedCharacterIds.isNotEmpty)
              ChromeIconButton(
                icon: const Icon(Icons.create_new_folder_outlined),
                tooltip: l10n.createFolderFromSelection,
                onPressed: _createFolderFromSelection,
              ),
            if (_selectedCharacterIds.isNotEmpty)
              ChromeIconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.delete,
                onPressed: _deleteSelectedCharacters,
              ),
            ChromeIconButton(
              icon: const Icon(Icons.check),
              tooltip: l10n.done,
              onPressed: _exitSelectionMode,
            ),
          ] else ...[
            if (browseFolderId == null && _searchQuery.isEmpty)
              ChromeIconButton(
                icon: const Icon(Icons.create_new_folder_outlined),
                tooltip: l10n.createCharacterFolder,
                onPressed: _createEmptyFolder,
              ),
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
              icon: const Icon(Icons.add),
              tooltip: l10n.createCharacter,
              onPressed: () => context.push(AppRoutes.characterCreate),
            ),
            ChromeIconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: l10n.import,
              onPressed: () => context.push(AppRoutes.import_),
            ),
          ],
        ]),
      ),
      body: Column(
        children: [
          _SearchBar(
            showFolderScopeToggle: browseFolderId != null,
            searchEntireLibrary: ref.watch(characterSearchGlobalProvider),
            tagFilterActive: tagFilter.isNotEmpty,
            onOpenTagFilter: () => showCharacterTagFilterSheet(context, ref),
            onToggleSearchScope: () {
              final enableGlobal =
                  !ref.read(characterSearchGlobalProvider);
              ref.read(characterSearchGlobalProvider.notifier).state =
                  enableGlobal;
            },
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 250), () {
                if (mounted) {
                  ref.read(characterListProvider.notifier).setQuery(value);
                }
              });
            },
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              transitionBuilder: (child, animation) =>
                  _characterFolderBrowseTransition(
                child: child,
                animation: animation,
                enterForward: _folderEnterForward,
              ),
              child: KeyedSubtree(
                key: ValueKey(browseFolderId ?? '__character_root__'),
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
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildBrowseContent({
    required AsyncValue<List<Character>> charactersAsync,
    required AppLocalizations l10n,
    required String? browseFolderId,
    required Set<String> tagFilter,
    required AsyncValue<List<CharacterFolder>> foldersAsync,
  }) {
    final cachedCharacters = charactersAsync.valueOrNull;
    if (charactersAsync.isLoading && cachedCharacters != null) {
      return _buildCharacterBrowseList(
        characters: cachedCharacters,
        l10n: l10n,
        browseFolderId: browseFolderId,
        tagFilter: tagFilter,
        foldersAsync: foldersAsync,
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
      loading: () => const Center(child: CircularProgressIndicator()),
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
    final showFolders = browseFolderId == null &&
        _searchQuery.isEmpty &&
        tagFilter.isEmpty &&
        !_selectionMode;
    final folders = foldersAsync.valueOrNull ?? const <CharacterFolder>[];

    if (characters.isEmpty && (!showFolders || folders.isEmpty)) {
      return const _EmptyState();
    }

    final interaction = _CharacterTileInteraction(
      selectionMode: _selectionMode,
      selectedIds: _selectedCharacterIds,
      onToggleSelect: _toggleCharacterSelection,
      onEnterSelection: _enterSelectionMode,
    );

    final visibleFolders = showFolders ? folders : const <CharacterFolder>[];
    void openFolderActions(CharacterFolder folder) {
      showCharacterFolderActions(context, ref, folder);
    }

    switch (viewMode) {
      case CharacterViewMode.list:
        return _CharacterListView(
          folders: visibleFolders,
          characters: characters,
          avatarShape: avatarShape,
          interaction: interaction,
          onOpenFolder: _openFolder,
          onFolderActions: openFolderActions,
        );
      case CharacterViewMode.simpleList:
        return _CharacterSimpleListView(
          folders: visibleFolders,
          characters: characters,
          interaction: interaction,
          onOpenFolder: _openFolder,
          onFolderActions: openFolderActions,
        );
      case CharacterViewMode.grid:
        return _CharacterGridView(
          folders: visibleFolders,
          characters: characters,
          interaction: interaction,
          onOpenFolder: _openFolder,
          onFolderActions: openFolderActions,
        );
      case CharacterViewMode.compactGrid:
        return _CharacterCompactGridView(
          folders: visibleFolders,
          characters: characters,
          interaction: interaction,
          onOpenFolder: _openFolder,
          onFolderActions: openFolderActions,
        );
    }
  }
}

Widget _characterFolderBrowseTransition({
  required Widget child,
  required Animation<double> animation,
  required bool enterForward,
}) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final horizontal = enterForward ? 0.22 : -0.22;
  return FadeTransition(
    opacity: Tween<double>(begin: 0, end: 1).animate(curved),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: Offset(horizontal, 0),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
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
  final ValueChanged<String> onOpenFolder;
  final ValueChanged<CharacterFolder> onFolderActions;

  const _CharacterGridView({
    required this.folders,
    required this.characters,
    required this.interaction,
    required this.onOpenFolder,
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
                  return CharacterFolderGridCard(
                    folder: folder,
                    onTap: () => onOpenFolder(folder.id),
                    onLongPress: () => onFolderActions(folder),
                    onSecondaryTap: () => onFolderActions(folder),
                  );
                }
                return _CharacterGridCard(
                  character: characters[index - folders.length],
                  interaction: interaction,
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
  final ValueChanged<String> onOpenFolder;
  final ValueChanged<CharacterFolder> onFolderActions;

  const _CharacterListView({
    required this.folders,
    required this.characters,
    required this.avatarShape,
    required this.interaction,
    required this.onOpenFolder,
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
          return CharacterFolderListTile(
            folder: folder,
            avatarShape: avatarShape,
            onTap: () => onOpenFolder(folder.id),
            onLongPress: () => onFolderActions(folder),
            onSecondaryTap: () => onFolderActions(folder),
          );
        }
        return _CharacterListTile(
          character: characters[index - folders.length],
          avatarShape: avatarShape,
          interaction: interaction,
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
  final ValueChanged<String> onOpenFolder;
  final ValueChanged<CharacterFolder> onFolderActions;

  const _CharacterSimpleListView({
    required this.folders,
    required this.characters,
    required this.interaction,
    required this.onOpenFolder,
    required this.onFolderActions,
  });

  static const double rowHeight = 60;
  static const double avatarSize = 40;

  int get _itemCount => folders.length + characters.length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _itemCount,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          final folder = folders[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: rowHeight,
              child: InkWell(
                onTap: () => onOpenFolder(folder.id),
                onLongPress: () => onFolderActions(folder),
                onSecondaryTap: () => onFolderActions(folder),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
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
                      Icon(
                        Icons.chevron_right,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return _CharacterSimpleListTile(
          character: characters[index - folders.length],
          interaction: interaction,
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
                _buildAvatar(),
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

  Widget _buildAvatar() {
    const size = _CharacterSimpleListView.avatarSize;
    return CharacterAvatarShaped(
      imagePath: character.assets?.avatarPath,
      width: size,
      height: size,
      shape: BoxShape.circle,
      borderRadius: size / 2,
      fallbackColor: _simpleListCharacterColor(character),
      fallbackIcon: _simpleListCharacterIcon(character),
    );
  }
}

IconData _simpleListCharacterIcon(Character character) {
  switch (character.id) {
    case 'builtin_coding_assistant':
      return Icons.code;
    case 'builtin_image_gen_assistant':
      return Icons.image;
    case 'builtin_xiaohongshu_copywriter':
      return Icons.edit_note;
    default:
      return Icons.person;
  }
}

Color _simpleListCharacterColor(Character character) {
  switch (character.id) {
    case 'builtin_coding_assistant':
      return const Color(0xFF2196F3);
    case 'builtin_image_gen_assistant':
      return const Color(0xFFE91E63);
    case 'builtin_xiaohongshu_copywriter':
      return const Color(0xFFFF5722);
    default:
      return AppTheme.primaryColor;
  }
}

class _CharacterCompactGridView extends StatelessWidget {
  final List<CharacterFolder> folders;
  final List<Character> characters;
  final _CharacterTileInteraction interaction;
  final ValueChanged<String> onOpenFolder;
  final ValueChanged<CharacterFolder> onFolderActions;

  const _CharacterCompactGridView({
    required this.folders,
    required this.characters,
    required this.interaction,
    required this.onOpenFolder,
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
                  return CharacterFolderGridCard(
                    folder: folder,
                    compact: true,
                    onTap: () => onOpenFolder(folder.id),
                    onLongPress: () => onFolderActions(folder),
                    onSecondaryTap: () => onFolderActions(folder),
                  );
                }
                return _CharacterCompactGridCard(
                  character: characters[index - folders.length],
                  interaction: interaction,
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
              child: _buildAvatar(),
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

  Widget _buildAvatar() {
    if (character.assets?.avatarPath != null) {
      return CharacterAvatarImage(
        imagePath: character.assets!.avatarPath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultAvatar(),
      );
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    final icon = _getCharacterIcon(character);
    final color = _getCharacterColor(character);

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
          icon,
          size: 60,
          color: Colors.white,
        ),
      ),
    );
  }

  IconData _getCharacterIcon(Character character) {
    // Check if it's a built-in character by ID
    switch (character.id) {
      case 'builtin_coding_assistant':
        return Icons.code;
      case 'builtin_image_gen_assistant':
        return Icons.image;
      case 'builtin_xiaohongshu_copywriter':
        return Icons.edit_note;
      default:
        return Icons.person;
    }
  }

  Color _getCharacterColor(Character character) {
    // Check if it's a built-in character by ID
    switch (character.id) {
      case 'builtin_coding_assistant':
        return const Color(0xFF2196F3); // Blue for coding
      case 'builtin_image_gen_assistant':
        return const Color(0xFFE91E63); // Pink for image generation
      case 'builtin_xiaohongshu_copywriter':
        return const Color(0xFFFF5722); // Orange/Red for social media
      default:
        return AppTheme.darkDivider;
    }
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
              child: _buildCompactAvatar(),
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

  Widget _buildCompactAvatar() {
    if (character.assets?.avatarPath != null) {
      return CharacterAvatarImage(
        imagePath: character.assets!.avatarPath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultCompactAvatar(),
      );
    }
    return _defaultCompactAvatar();
  }

  Widget _defaultCompactAvatar() {
    final icon = _getCharacterIcon(character);
    final color = _getCharacterColor(character);

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
          icon,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }

  IconData _getCharacterIcon(Character character) {
    switch (character.id) {
      case 'builtin_coding_assistant':
        return Icons.code;
      case 'builtin_image_gen_assistant':
        return Icons.image;
      case 'builtin_xiaohongshu_copywriter':
        return Icons.edit_note;
      default:
        return Icons.person;
    }
  }

  Color _getCharacterColor(Character character) {
    switch (character.id) {
      case 'builtin_coding_assistant':
        return const Color(0xFF2196F3);
      case 'builtin_image_gen_assistant':
        return const Color(0xFFE91E63);
      case 'builtin_xiaohongshu_copywriter':
        return const Color(0xFFFF5722);
      default:
        return AppTheme.darkDivider;
    }
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
              _buildListAvatar(),
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

  Widget _buildListAvatar() {
    // Keep a shared width so list rows align when switching shapes.
    const width = 56.0;
    final (height, shape, radius) = switch (avatarShape) {
      CharacterAvatarShape.circle => (width, BoxShape.circle, width / 2),
      CharacterAvatarShape.square => (width, BoxShape.rectangle, 8.0),
      CharacterAvatarShape.rectangle => (width * 4 / 3, BoxShape.rectangle, 8.0),
    };

    return CharacterAvatarShaped(
      imagePath: character.assets?.avatarPath,
      width: width,
      height: height,
      shape: shape,
      borderRadius: radius,
      fallbackColor: _getCharacterColor(character),
      fallbackIcon: _getCharacterIcon(character),
    );
  }

  IconData _getCharacterIcon(Character character) {
    switch (character.id) {
      case 'builtin_coding_assistant':
        return Icons.code;
      case 'builtin_image_gen_assistant':
        return Icons.image;
      case 'builtin_xiaohongshu_copywriter':
        return Icons.edit_note;
      default:
        return Icons.person;
    }
  }

  Color _getCharacterColor(Character character) {
    switch (character.id) {
      case 'builtin_coding_assistant':
        return const Color(0xFF2196F3);
      case 'builtin_image_gen_assistant':
        return const Color(0xFFE91E63);
      case 'builtin_xiaohongshu_copywriter':
        return const Color(0xFFFF5722);
      default:
        return AppTheme.primaryColor;
    }
  }
}
