import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/models/tag.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/character_providers.dart';
import 'package:native_tavern/presentation/providers/chat_providers.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';
import 'package:native_tavern/presentation/widgets/common/character_avatar_image.dart';
import 'package:native_tavern/presentation/utils/destructive_confirm.dart';
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
  CharacterViewMode _viewMode = CharacterViewMode.compactGrid;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final charactersAsync = ref.watch(characterListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.characters),
        actions: spacedAppBarActions([
          IconButton(
            icon: _getViewModeIcon(),
            onPressed: () => setState(() => _viewMode = _viewMode.next),
            tooltip: _viewMode.getDisplayName(l10n),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.createCharacter,
            onPressed: () => context.push(AppRoutes.characterCreate),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.retry,
            onPressed: () => ref.read(characterListProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: l10n.import,
            onPressed: () => context.push(AppRoutes.import_),
          ),
        ]),
      ),
      body: Column(
        children: [
          _SearchBar(
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
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 600) {
                  ref.read(characterListProvider.notifier).loadMore();
                }
                return false;
              },
              child: charactersAsync.when(
                data: (characters) {
                  final filtered = _searchQuery.isEmpty
                      ? characters
                      : characters
                          .where((c) =>
                              c.name
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase()) ||
                              c.description
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase()))
                          .toList();

                  if (filtered.isEmpty) {
                    return const _EmptyState();
                  }

                  switch (_viewMode) {
                    case CharacterViewMode.list:
                      return _CharacterListView(characters: filtered);
                    case CharacterViewMode.grid:
                      return _CharacterGridView(characters: filtered);
                    case CharacterViewMode.compactGrid:
                      return _CharacterCompactGridView(characters: filtered);
                  }
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Icon _getViewModeIcon() {
    switch (_viewMode) {
      case CharacterViewMode.list:
        return const Icon(Icons.list);
      case CharacterViewMode.grid:
        return const Icon(Icons.grid_view);
      case CharacterViewMode.compactGrid:
        return const Icon(Icons.view_compact);
    }
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.onChanged});

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
          suffixIcon: IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Show filter options
            },
          ),
        ),
      ),
    );
  }
}

class _CharacterGridView extends StatelessWidget {
  final List<Character> characters;

  const _CharacterGridView({required this.characters});

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
              itemCount: characters.length,
              itemBuilder: (context, index) {
                return _CharacterGridCard(character: characters[index]);
              },
            ));
  }
}

class _CharacterListView extends StatelessWidget {
  final List<Character> characters;

  const _CharacterListView({required this.characters});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        return _CharacterListTile(character: characters[index]);
      },
    );
  }
}

class _CharacterCompactGridView extends StatelessWidget {
  final List<Character> characters;

  const _CharacterCompactGridView({required this.characters});

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
              itemCount: characters.length,
              itemBuilder: (context, index) {
                return _CharacterCompactGridCard(character: characters[index]);
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
    case 'export':
      break;
    case 'delete':
      await _confirmDeleteCharacter(context, ref, character);
  }
}

Future<void> _showCharacterActionMenu(
  BuildContext context,
  WidgetRef ref,
  Character character,
) async {
  final l10n = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  final selected = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(context.appCornerRadius + 4),
      ),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  character.name,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.chat, color: scheme.onSurfaceVariant),
              title: Text(l10n.startChat),
              onTap: () => Navigator.pop(sheetContext, 'chat'),
            ),
            ListTile(
              leading: Icon(Icons.edit, color: scheme.onSurfaceVariant),
              title: Text(l10n.edit),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: Icon(Icons.file_upload, color: scheme.onSurfaceVariant),
              title: Text(l10n.exportChat),
              onTap: () => Navigator.pop(sheetContext, 'export'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: scheme.error),
              title: Text(l10n.delete),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      );
    },
  );
  if (selected == null || !context.mounted) return;
  await _handleCharacterAction(context, ref, character, selected);
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
              ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.characterCreate),
                icon: const Icon(Icons.add),
                label: Text(l10n.createCharacter),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.import_),
                icon: const Icon(Icons.file_download),
                label: Text(l10n.import),
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

  const _CharacterGridCard({required this.character});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/characters/${character.id}'),
        onLongPress: () => _showCharacterActionMenu(
          context,
          ref,
          character,
        ),
        onSecondaryTap: () => _showCharacterActionMenu(
          context,
          ref,
          character,
        ),
        child: Column(
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
                  if (character.creator.isNotEmpty)
                    Text(
                      'by ${character.creator}',
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

  const _CharacterCompactGridCard({required this.character});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/characters/${character.id}'),
        onLongPress: () => _showCharacterActionMenu(
          context,
          ref,
          character,
        ),
        onSecondaryTap: () => _showCharacterActionMenu(
          context,
          ref,
          character,
        ),
        child: Column(
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
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    character.name,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
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

  const _CharacterListTile({required this.character});

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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/characters/${character.id}'),
        onLongPress: () => _showCharacterActionMenu(
          context,
          ref,
          character,
        ),
        // Overflow sits on the title row (not vertically centered). ListTile's
        // trailing centering leaves large empty bands on multi-line cards.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildListAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            character.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.more_vert,
                            size: ChromeControls.menuIconSize,
                          ),
                          tooltip: l10n.moreOptions,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: ChromeControls.buttonSize,
                            minHeight: ChromeControls.buttonSize,
                          ),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _showCharacterActionMenu(
                            context,
                            ref,
                            character,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      description,
                      style: metaStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (character.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
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
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.55),
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: metaStyle?.copyWith(color: color),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListAvatar() {
    if (character.assets?.avatarPath != null) {
      return CharacterAvatarCircle(
        imagePath: character.assets!.avatarPath!,
        radius: 28,
      );
    }

    final icon = _getCharacterIcon(character);
    final color = _getCharacterColor(character);

    return CircleAvatar(
      radius: 28,
      backgroundColor: color,
      child: Icon(
        icon,
        color: Colors.white,
        size: 28,
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
        return AppTheme.primaryColor;
    }
  }
}
