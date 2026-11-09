import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

String _packProgressLabel(
  AppLocalizations l10n,
  CharacterLibraryPackProgress value, {
  required bool exporting,
}) {
  switch (value.phase) {
    case 'preparing':
      return l10n.characterLibraryFastPackPreparing;
    case 'avatars':
      if (!exporting && value.total > 0) {
        return l10n.characterLibraryFastPackExtractProgress(
          value.processed,
          value.total,
        );
      }
      return exporting
          ? l10n.characterLibraryFastPackExportProgress(
              value.processed,
              value.total,
            )
          : l10n.characterLibraryFastPackImportProgress(
              value.processed,
              value.total,
            );
    default:
      return exporting
          ? l10n.characterLibraryFastPackExportProgress(
              value.processed,
              value.total,
            )
          : l10n.characterLibraryFastPackImportProgress(
              value.processed,
              value.total,
            );
  }
}

Future<void> _showPackProgressDialog(
  BuildContext context, {
  required String title,
  required ValueNotifier<CharacterLibraryPackProgress> progress,
  required String Function(CharacterLibraryPackProgress value) labelBuilder,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(title),
        content: ValueListenableBuilder<CharacterLibraryPackProgress>(
          valueListenable: progress,
          builder: (context, value, _) {
            final ratio = value.isIndeterminate
                ? null
                : (value.processed / value.total).clamp(0.0, 1.0);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: ratio),
                const SizedBox(height: 12),
                Text(labelBuilder(value)),
                if (value.currentName != null &&
                    value.phase != 'preparing') ...[
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
  // Let the dialog paint before heavy import/export work starts.
  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(Duration.zero);
  await WidgetsBinding.instance.endOfFrame;
}

bool _isStorageFullPickerError(Object error) {
  if (error is! PlatformException) return false;
  final haystack = '${error.code} ${error.message} ${error.details}'.toLowerCase();
  return haystack.contains('enospc') ||
      haystack.contains('no space') ||
      haystack.contains('unknown_path') ||
      haystack.contains('failed to retrieve path');
}

Future<void> importCharacterLibraryFastPack(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);
  final FilePickerResult? picked;
  try {
    picked = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.importCharacterLibraryFastPack,
      type: FileType.custom,
      allowedExtensions: [CharacterLibraryPackService.fileExtension],
    );
  } on PlatformException catch (e) {
    if (!context.mounted) return;
    final message = _isStorageFullPickerError(e)
        ? l10n.importCharacterLibraryStorageFull
        : '${l10n.error}: ${e.message ?? e.code}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return;
  }
  final path = picked?.files.single.path;
  if (path == null) return;
  if (!context.mounted) return;

  final confirmed = await _confirmFastPackOverwrite(context, l10n);
  if (!confirmed || !context.mounted) return;

  final progress = ValueNotifier<CharacterLibraryPackProgress>(
    const CharacterLibraryPackProgress(
      total: 0,
      processed: 0,
      phase: 'preparing',
    ),
  );
  await _showPackProgressDialog(
    context,
    title: l10n.importCharacterLibraryFastPack,
    progress: progress,
    labelBuilder: (value) => _packProgressLabel(l10n, value, exporting: false),
  );
  if (!context.mounted) {
    progress.dispose();
    return;
  }

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

  // Mobile needs a real filesystem path first; the system "Save as" dialog
  // (SAF / Files) only accepts bytes after the pack is built.
  // Desktop can pick the destination path up front.
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

  final progress = ValueNotifier<CharacterLibraryPackProgress>(
    const CharacterLibraryPackProgress(
      total: 0,
      processed: 0,
      phase: 'preparing',
    ),
  );
  await _showPackProgressDialog(
    context,
    title: l10n.exportCharacterLibraryFastPack,
    progress: progress,
    labelBuilder: (value) => _packProgressLabel(l10n, value, exporting: true),
  );
  if (!context.mounted) {
    progress.dispose();
    return;
  }

  try {
    final result = await _characterLibraryPackService(ref).exportToFile(
      outputPath,
      onProgress: (p) => progress.value = p,
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (isMobile) {
      final localSave = await _saveExportedPackLocally(
        context: context,
        l10n: l10n,
        sourcePath: result.path,
        fileName: fileName,
      );
      // Cancelled save dialog → still offer system share as a fallback.
      if (localSave == false && context.mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(result.path)],
            subject: l10n.exportCharacterLibraryFastPack,
          ),
        );
      }
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

/// Opens the system save dialog so the user can put the pack in Downloads /
/// Files / SD card.
///
/// Returns `true` when saved, `false` when the user cancelled (share fallback
/// is OK), and `null` when saving failed (already surfaced to the user).
Future<bool?> _saveExportedPackLocally({
  required BuildContext context,
  required AppLocalizations l10n,
  required String sourcePath,
  required String fileName,
}) async {
  try {
    final bytes = await File(sourcePath).readAsBytes();
    if (!context.mounted) return null;
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: l10n.exportCharacterLibraryFastPack,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [CharacterLibraryPackService.fileExtension],
      bytes: bytes,
    );
    return savedPath != null;
  } on PlatformException catch (e) {
    if (!context.mounted) return null;
    final message = _isStorageFullPickerError(e)
        ? l10n.importCharacterLibraryStorageFull
        : '${l10n.error}: ${e.message ?? e.code}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return null;
  } catch (e) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.error}: $e')),
    );
    return null;
  }
}
