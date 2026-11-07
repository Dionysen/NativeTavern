import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/character_folder.dart';
import 'package:native_tavern/data/repositories/character_folder_repository.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/character_folder_providers.dart';
import 'package:native_tavern/presentation/providers/character_providers.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_action_drawer.dart';

Future<String?> promptCharacterFolderName(
  BuildContext context, {
  required String title,
  String? initialName,
}) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: initialName ?? '');
  String? result;
  try {
    result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.characterFolderNameLabel,
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isEmpty) return;
              Navigator.pop(context, trimmed);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
  return result;
}

/// Result of the nested folder path picker.
///
/// [folderId] `null` means library root. Absent result means cancelled.
class CharacterFolderPathSelection {
  const CharacterFolderPathSelection({this.folderId});

  final String? folderId;
}

Future<CharacterFolderPathSelection?> showCharacterFolderPathPicker(
  BuildContext context, {
  required String title,
  String? confirmLabel,
}) {
  return showModalBottomSheet<CharacterFolderPathSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _CharacterFolderPathPickerSheet(
      title: title,
      confirmLabel: confirmLabel,
    ),
  );
}

class _CharacterFolderPathPickerSheet extends ConsumerStatefulWidget {
  const _CharacterFolderPathPickerSheet({
    required this.title,
    this.confirmLabel,
  });

  final String title;
  final String? confirmLabel;

  @override
  ConsumerState<_CharacterFolderPathPickerSheet> createState() =>
      _CharacterFolderPathPickerSheetState();
}

class _CharacterFolderPathPickerSheetState
    extends ConsumerState<_CharacterFolderPathPickerSheet> {
  String? _currentParentId;
  final List<CharacterFolder> _crumbs = [];
  List<CharacterFolder> _children = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => _loading = true);
    final children = await ref
        .read(characterFolderRepositoryProvider)
        .listFolders(parentId: _currentParentId);
    if (!mounted) return;
    setState(() {
      _children = children;
      _loading = false;
    });
  }

  Future<void> _enter(CharacterFolder folder) async {
    setState(() {
      _crumbs.add(folder);
      _currentParentId = folder.id;
    });
    await _loadChildren();
  }

  Future<void> _goToCrumb(int index) async {
    if (index < 0) {
      setState(() {
        _crumbs.clear();
        _currentParentId = null;
      });
    } else {
      setState(() {
        _crumbs.removeRange(index + 1, _crumbs.length);
        _currentParentId = _crumbs[index].id;
      });
    }
    await _loadChildren();
  }

  Future<void> _createChildFolder() async {
    final l10n = AppLocalizations.of(context);
    final name = await promptCharacterFolderName(
      context,
      title: l10n.createCharacterFolder,
    );
    if (name == null || !mounted) return;
    await ref.read(characterFolderRepositoryProvider).createFolder(
          name,
          parentId: _currentParentId,
        );
    await _loadChildren();
    ref.invalidate(characterFoldersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _crumbs.isEmpty ? null : () => _goToCrumb(-1),
                    child: Text(l10n.characterFolderRoot),
                  ),
                  for (var i = 0; i < _crumbs.length; i++) ...[
                    const Icon(Icons.chevron_right, size: 18),
                    TextButton(
                      onPressed: i == _crumbs.length - 1
                          ? null
                          : () => _goToCrumb(i),
                      child: Text(_crumbs[i].name),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        for (final folder in _children)
                          ListTile(
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(folder.name),
                            subtitle: Text(
                              l10n.characterFolderContentsSummary(
                                folder.characterCount,
                                folder.childFolderCount,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _enter(folder),
                          ),
                        if (_children.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l10n.characterFolderPathEmpty,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottom),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _createChildFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: Text(l10n.createCharacterFolder),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      CharacterFolderPathSelection(
                        folderId: _currentParentId,
                      ),
                    ),
                    child: Text(
                      widget.confirmLabel ?? l10n.characterFolderUseThisPath,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showMoveCharactersToFolderSheet(
  BuildContext context,
  WidgetRef ref,
  Iterable<String> characterIds,
) async {
  final l10n = AppLocalizations.of(context);
  final selection = await showCharacterFolderPathPicker(
    context,
    title: l10n.moveCharactersToFolder,
    confirmLabel: l10n.moveToFolder,
  );
  if (selection == null || !context.mounted) return;
  await ref.read(characterFoldersProvider.notifier).moveCharacters(
        characterIds,
        folderId: selection.folderId,
      );
  await ref.read(characterListProvider.notifier).refresh();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.charactersMovedToFolder)),
    );
  }
}

Future<void> showCopyCharactersToFolderSheet(
  BuildContext context,
  WidgetRef ref,
  Iterable<String> characterIds,
) async {
  final l10n = AppLocalizations.of(context);
  final selection = await showCharacterFolderPathPicker(
    context,
    title: l10n.copyCharactersToFolder,
    confirmLabel: l10n.copyToFolder,
  );
  if (selection == null || !context.mounted) return;

  final repo = ref.read(characterRepositoryProvider);
  final folderRepo = ref.read(characterFolderRepositoryProvider);
  final ids = characterIds.toList(growable: false);
  var copied = 0;
  for (final id in ids) {
    final source = await repo.getCharacter(id);
    if (source == null) continue;
    final duplicate = source.copyWith(
      id: '',
      name: '${source.name} (copy)',
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
    final created = await repo.createCharacter(duplicate);
    if (selection.folderId != null) {
      await folderRepo.moveCharactersToFolder(
        [created.id],
        folderId: selection.folderId,
      );
    }
    copied++;
  }

  ref.invalidate(characterFoldersProvider);
  await ref.read(characterListProvider.notifier).refresh();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.charactersCopiedToFolder(copied))),
    );
  }
}

Future<void> showCharacterFolderActions(
  BuildContext context,
  WidgetRef ref,
  CharacterFolder folder,
) async {
  final l10n = AppLocalizations.of(context);
  final action = await showAdaptiveActionDrawer<String>(
    context: context,
    title: folder.name,
    actions: [
      AdaptiveActionDrawerItem(
        value: 'rename',
        leading: const Icon(Icons.drive_file_rename_outline),
        title: Text(l10n.rename),
      ),
      AdaptiveActionDrawerItem(
        value: 'dissolve',
        leading: const Icon(Icons.folder_off_outlined),
        title: Text(l10n.dissolveCharacterFolder),
      ),
      AdaptiveActionDrawerItem(
        value: 'delete',
        leading: const Icon(Icons.delete_outline),
        title: Text(l10n.deleteCharacterFolder),
        destructive: true,
      ),
    ],
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case 'rename':
      await renameCharacterFolder(context, ref, folder);
    case 'dissolve':
      await dissolveCharacterFolder(context, ref, folder);
    case 'delete':
      await deleteCharacterFolder(context, ref, folder);
  }
}

Future<void> renameCharacterFolder(
  BuildContext context,
  WidgetRef ref,
  CharacterFolder folder,
) async {
  final l10n = AppLocalizations.of(context);
  final name = await promptCharacterFolderName(
    context,
    title: l10n.renameCharacterFolder,
    initialName: folder.name,
  );
  if (name == null || !context.mounted) return;
  await ref.read(characterFoldersProvider.notifier).renameFolder(
        folder.id,
        name,
      );
}

Future<void> dissolveCharacterFolder(
  BuildContext context,
  WidgetRef ref,
  CharacterFolder folder,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.dissolveCharacterFolder),
      content: Text(l10n.dissolveCharacterFolderBody(folder.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.dissolveCharacterFolder),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await ref.read(characterFoldersProvider.notifier).dissolveFolder(folder.id);
  await ref.read(characterListProvider.notifier).refresh();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.characterFolderDissolved)),
    );
  }
}

Future<void> deleteCharacterFolder(
  BuildContext context,
  WidgetRef ref,
  CharacterFolder folder,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteCharacterFolder),
      content: Text(l10n.deleteCharacterFolderBody(folder.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.deleteCharacterFolder),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await ref.read(characterFoldersProvider.notifier).deleteFolder(folder.id);
  ref.invalidate(characterLibraryTagLabelsProvider);
  await ref.read(characterListProvider.notifier).refresh();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.characterFolderDeleted)),
    );
  }
}
