import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/domain/services/character_card_export_service.dart';
import 'package:native_tavern/domain/services/character_library_export_service.dart';
import 'package:native_tavern/domain/services/character_library_import_service.dart';
import 'package:native_tavern/domain/services/character_library_pack_service.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/data/repositories/character_folder_repository.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/presentation/providers/character_folder_providers.dart';
import 'package:native_tavern/presentation/providers/character_providers.dart';
import 'package:native_tavern/presentation/providers/regex_providers.dart';
import 'package:native_tavern/core/services/initialization_service.dart';
import 'package:native_tavern/presentation/providers/world_info_providers.dart';
import 'package:native_tavern/presentation/screens/import/import_screen.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> importCharacterLibraryFromFolder(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);
  final path = await FilePicker.platform.getDirectoryPath(
    dialogTitle: l10n.importCharactersFromFolder,
  );
  if (path == null) return;
  if (!context.mounted) return;

  final progress = ValueNotifier<CharacterLibraryImportProgress?>(null);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.importCharactersFromFolder),
        content: ValueListenableBuilder<CharacterLibraryImportProgress?>(
          valueListenable: progress,
          builder: (context, value, _) {
            if (value == null) {
              return const SizedBox(
                height: 72,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final ratio =
                value.total == 0 ? null : value.processed / value.total;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: ratio),
                const SizedBox(height: 12),
                Text(
                  l10n.characterLibraryImportProgress(
                    value.processed,
                    value.total,
                  ),
                ),
                if (value.currentFile != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    value.currentFile!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );

  try {
    final service = CharacterLibraryImportService(
      importService: ref.read(importServiceProvider),
      characterRepository: ref.read(characterRepositoryProvider),
      folderRepository: ref.read(characterFolderRepositoryProvider),
      worldInfoRepository: ref.read(worldInfoRepositoryProvider),
      importEmbeddedRegex: (characterId, scripts) async {
        await ref
            .read(characterRegexScriptsProvider(characterId).notifier)
            .importEmbeddedScripts(scripts);
      },
    );
    final result = await service.importFromDirectory(
      path,
      onProgress: (p) => progress.value = p,
    );
    ref.invalidate(characterFoldersProvider);
    ref.invalidate(worldInfoNotifierProvider);
    await ref.read(characterListProvider.notifier).refresh();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.characterLibraryImportSummary(
            result.succeeded,
            result.failed,
            result.skipped,
          ),
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.error}: $e')),
    );
  } finally {
    progress.dispose();
  }
}

Future<void> exportCharacterLibraryToFolder(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);
  final path = await FilePicker.platform.getDirectoryPath(
    dialogTitle: l10n.exportCharacterLibrary,
  );
  if (path == null) return;
  if (!context.mounted) return;

  final progress = ValueNotifier<CharacterLibraryExportProgress?>(null);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.exportCharacterLibrary),
        content: ValueListenableBuilder<CharacterLibraryExportProgress?>(
          valueListenable: progress,
          builder: (context, value, _) {
            if (value == null) {
              return const SizedBox(
                height: 72,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final ratio =
                value.total == 0 ? null : value.processed / value.total;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: ratio),
                const SizedBox(height: 12),
                Text(
                  l10n.characterLibraryExportProgress(
                    value.processed,
                    value.total,
                  ),
                ),
                if (value.currentName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    value.currentName!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );

  try {
    final importService = ref.read(importServiceProvider);
    final service = CharacterLibraryExportService(
      characterRepository: ref.read(characterRepositoryProvider),
      folderRepository: ref.read(characterFolderRepositoryProvider),
      exportService: CharacterCardExportService(importService),
    );
    final result = await service.exportToDirectory(
      path,
      onProgress: (p) => progress.value = p,
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.characterLibraryExportSummary(result.succeeded, result.failed),
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.error}: $e')),
    );
  } finally {
    progress.dispose();
  }
}

CharacterLibraryPackService _characterLibraryPackService(WidgetRef ref) {
  return CharacterLibraryPackService(
    characterRepository: ref.read(characterRepositoryProvider),
    folderRepository: ref.read(characterFolderRepositoryProvider),
    dataPath: ref.read(dataPathProvider),
  );
}

Future<bool> _confirmFastPackOverwrite(
  BuildContext context,
  AppLocalizations l10n,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.characterLibraryFastPackOverwriteTitle),
      content: Text(l10n.characterLibraryFastPackOverwriteBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.importCharacterLibraryFastPack),
        ),
      ],
    ),
  );
  return confirmed == true;
}

void _showPackProgressDialog(
  BuildContext context, {
  required String title,
  required ValueNotifier<CharacterLibraryPackProgress?> progress,
  required String Function(CharacterLibraryPackProgress value) labelBuilder,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(title),
        content: ValueListenableBuilder<CharacterLibraryPackProgress?>(
          valueListenable: progress,
          builder: (context, value, _) {
            if (value == null) {
              return const SizedBox(
                height: 72,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final ratio =
                value.total == 0 ? null : value.processed / value.total;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: ratio),
                const SizedBox(height: 12),
                Text(labelBuilder(value)),
                if (value.currentName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    value.currentName!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );
}

Future<void> importCharacterLibraryFastPack(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);
  final picked = await FilePicker.platform.pickFiles(
    dialogTitle: l10n.importCharacterLibraryFastPack,
    type: FileType.custom,
    allowedExtensions: [CharacterLibraryPackService.fileExtension],
  );
  final path = picked?.files.single.path;
  if (path == null) return;
  if (!context.mounted) return;

  final confirmed = await _confirmFastPackOverwrite(context, l10n);
  if (!confirmed || !context.mounted) return;

  final progress = ValueNotifier<CharacterLibraryPackProgress?>(null);
  _showPackProgressDialog(
    context,
    title: l10n.importCharacterLibraryFastPack,
    progress: progress,
    labelBuilder: (value) => l10n.characterLibraryFastPackImportProgress(
      value.processed,
      value.total,
    ),
  );

  try {
    final result = await _characterLibraryPackService(ref).importFromFile(
      path,
      onProgress: (p) => progress.value = p,
    );
    ref.invalidate(characterFoldersProvider);
    await ref.read(characterListProvider.notifier).refresh();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.characterLibraryFastPackImportSummary(
            result.created,
            result.updated,
            result.failed,
          ),
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.error}: $e')),
    );
  } finally {
    progress.dispose();
  }
}

Future<void> exportCharacterLibraryFastPack(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);
  final fileName = CharacterLibraryPackService.suggestedFileName();
  final isMobile = Platform.isAndroid || Platform.isIOS;

  String? outputPath;
  if (isMobile) {
    final tempDir = await getTemporaryDirectory();
    outputPath = p.join(tempDir.path, fileName);
  } else {
    outputPath = await FilePicker.platform.saveFile(
      dialogTitle: l10n.exportCharacterLibraryFastPack,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [CharacterLibraryPackService.fileExtension],
    );
  }
  if (outputPath == null) return;
  if (!outputPath.toLowerCase().endsWith(
        '.${CharacterLibraryPackService.fileExtension}',
      )) {
    outputPath = '$outputPath.${CharacterLibraryPackService.fileExtension}';
  }
  if (!context.mounted) return;

  final progress = ValueNotifier<CharacterLibraryPackProgress?>(null);
  _showPackProgressDialog(
    context,
    title: l10n.exportCharacterLibraryFastPack,
    progress: progress,
    labelBuilder: (value) => l10n.characterLibraryFastPackExportProgress(
      value.processed,
      value.total,
    ),
  );

  try {
    final result = await _characterLibraryPackService(ref).exportToFile(
      outputPath,
      onProgress: (p) => progress.value = p,
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (isMobile) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(result.path)],
          subject: l10n.exportCharacterLibraryFastPack,
        ),
      );
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.characterLibraryFastPackExportSummary(
            result.characterCount,
            result.folderCount,
          ),
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.error}: $e')),
    );
  } finally {
    progress.dispose();
  }
}
