import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/character_folder.dart';
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

Future<void> showMoveCharactersToFolderSheet(
  BuildContext context,
  WidgetRef ref,
  Iterable<String> characterIds,
) async {
  final l10n = AppLocalizations.of(context);
  final folders = ref.read(characterFoldersProvider).valueOrNull ?? [];
  final destination = await showModalBottomSheet<String?>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              l10n.moveCharactersToFolder,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: Text(l10n.characterFolderRoot),
            onTap: () => Navigator.pop(context, ''),
          ),
          for (final folder in folders)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(folder.name),
              subtitle: Text(l10n.characterFolderCount(folder.characterCount)),
              onTap: () => Navigator.pop(context, folder.id),
            ),
        ],
      ),
    ),
  );
  if (destination == null || !context.mounted) return;
  await ref.read(characterFoldersProvider.notifier).moveCharacters(
        characterIds,
        folderId: destination.isEmpty ? null : destination,
      );
  await ref.read(characterListProvider.notifier).refresh();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.charactersMovedToFolder)),
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
        destructive: true,
      ),
    ],
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case 'rename':
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
    case 'dissolve':
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
  }
}
