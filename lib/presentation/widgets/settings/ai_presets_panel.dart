import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/core/utils/share_utils.dart';
import 'package:native_tavern/data/models/ai_preset.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/ai_preset_providers.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_action_drawer.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// AI presets list + actions. Used by the full screen and AI Config expand.
class AIPresetsPanel extends ConsumerWidget {
  const AIPresetsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final allPresets = ref.watch(allAIPresetsProvider);
    final activePresetId = ref.watch(activeAIPresetIdProvider);
    final builtInPresets = allPresets.where((p) => p.isBuiltIn).toList();
    final customPresets = allPresets.where((p) => !p.isBuiltIn).toList();
    const headerPad = EdgeInsets.fromLTRB(16, 12, 16, 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _createNewPreset(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.newPreset),
              ),
              OutlinedButton.icon(
                onPressed: () => _importPreset(context, ref),
                icon: const Icon(Icons.file_download, size: 18),
                label: Text(l10n.import),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportCurrentSettings(context, ref),
                icon: const Icon(Icons.file_upload, size: 18),
                label: Text(l10n.export),
              ),
              FilledButton.icon(
                onPressed: () => _saveCurrentAsPreset(context, ref),
                icon: const Icon(Icons.save, size: 18),
                label: Text(l10n.saveAs),
              ),
            ],
          ),
        ),
        SettingsCategoryHeader(
          icon: Icons.auto_awesome,
          title: l10n.builtInPresets,
          padding: headerPad,
        ),
        for (var i = 0; i < builtInPresets.length; i++)
          _PresetTile(
            preset: builtInPresets[i],
            isActive: builtInPresets[i].id == activePresetId,
            showDivider: i != builtInPresets.length - 1 ||
                customPresets.isNotEmpty,
            onTap: () => _applyPreset(context, ref, builtInPresets[i]),
            onCopy: () => _copyPresetToCustom(context, ref, builtInPresets[i]),
          ),
        if (customPresets.isNotEmpty) ...[
          SettingsCategoryHeader(
            icon: Icons.bookmark_outline,
            title: l10n.customPresets,
            padding: headerPad,
          ),
          for (var i = 0; i < customPresets.length; i++)
            _PresetTile(
              preset: customPresets[i],
              isActive: customPresets[i].id == activePresetId,
              showDivider: i != customPresets.length - 1,
              onTap: () => _applyPreset(context, ref, customPresets[i]),
              onCopy: () =>
                  _copyPresetToCustom(context, ref, customPresets[i]),
              onRename: () => _renamePreset(context, ref, customPresets[i]),
              onExport: () => _exportPreset(context, customPresets[i]),
              onDelete: () => _deletePreset(context, ref, customPresets[i]),
            ),
        ],
      ],
    );
  }

  Future<void> _createNewPreset(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: l10n.newPreset);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.newPreset),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.presetName,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    try {
      final copy = await ref.read(aiPresetManagerProvider).copyPresetToCustom(
            BuiltInAIPresets.defaultPreset,
            name: name,
          );
      await ref.read(aiPresetManagerProvider).applyPreset(copy);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.savedPreset(copy.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _renamePreset(
    BuildContext context,
    WidgetRef ref,
    AIPreset preset,
  ) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: preset.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.rename),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.presetName,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == preset.name) return;

    await ref.read(aiCustomPresetsProvider.notifier).updatePreset(
          preset.copyWith(name: name, updatedAt: DateTime.now()),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.savedPreset(name))),
      );
    }
  }

  Future<void> _applyPreset(
    BuildContext context,
    WidgetRef ref,
    AIPreset preset,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(aiPresetManagerProvider).applyPreset(preset);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.appliedPreset(preset.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToApplyPreset(e.toString()))),
        );
      }
    }
  }

  Future<void> _copyPresetToCustom(
    BuildContext context,
    WidgetRef ref,
    AIPreset preset,
  ) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(
      text: l10n.copyNameOf(preset.name),
    );

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.copyToCustom),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.presetName,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(l10n.copyToCustom),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      final copy = await ref
          .read(aiPresetManagerProvider)
          .copyPresetToCustom(preset, name: name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.copiedPresetToCustom(copy.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _importPreset(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String jsonString;

      if (file.bytes != null) {
        jsonString = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonString = await File(file.path!).readAsString();
      } else {
        throw Exception('Could not read file');
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      if (!json.containsKey('temperature') &&
          !json.containsKey('generationSettings')) {
        throw Exception(l10n.invalidPresetFormat);
      }

      if (json['preset_name'] == null && json['name'] == null) {
        json['preset_name'] = file.name.replaceAll('.json', '');
      }

      final preset =
          await ref.read(aiCustomPresetsProvider.notifier).importPreset(json);
      await ref.read(aiPresetManagerProvider).applyPreset(preset);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importedAndApplied(preset.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _exportCurrentSettings(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: 'My AI Preset');

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.exportCurrentSettings),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.presetName,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(l10n.export),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !context.mounted) return;
    final shareOrigin = sharePositionOrigin(context);

    try {
      final json =
          await ref.read(aiPresetManagerProvider).exportCurrentSettings(name);
      final jsonString = const JsonEncoder.withIndent('  ').convert(json);

      final tempDir = await getTemporaryDirectory();
      final fileName = '${name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        subject: 'NativeTavern AI Preset: $name',
        sharePositionOrigin: shareOrigin,
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _saveCurrentAsPreset(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.saveAsPreset),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.presetName,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: l10n.descriptionOptional,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.pleaseEnterAName)),
                );
                return;
              }
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'description': descController.text.trim(),
              });
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      final preset =
          await ref.read(aiPresetManagerProvider).createFromCurrentSettings(
                name: result['name']!,
                description: result['description']!.isEmpty
                    ? null
                    : result['description'],
              );
      await ref.read(aiCustomPresetsProvider.notifier).addPreset(preset);
      await ref
          .read(activeAIPresetIdProvider.notifier)
          .setActivePreset(preset.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.savedPreset(preset.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _exportPreset(BuildContext context, AIPreset preset) async {
    final shareOrigin = sharePositionOrigin(context);
    try {
      final json = preset.toExportJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(json);

      final tempDir = await getTemporaryDirectory();
      final fileName =
          '${preset.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        subject: 'NativeTavern AI Preset: ${preset.name}',
        sharePositionOrigin: shareOrigin,
      ));
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _deletePreset(
    BuildContext context,
    WidgetRef ref,
    AIPreset preset,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePreset),
        content: Text(l10n.deletePresetConfirmation(preset.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final activeId = ref.read(activeAIPresetIdProvider);
    if (activeId == preset.id) {
      await ref.read(activeAIPresetIdProvider.notifier).setActivePreset(null);
    }
    await ref.read(aiCustomPresetsProvider.notifier).deletePreset(preset.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deletedPreset(preset.name))),
      );
    }
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.isActive,
    required this.onTap,
    this.showDivider = true,
    this.onCopy,
    this.onRename,
    this.onExport,
    this.onDelete,
  });

  final AIPreset preset;
  final bool isActive;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback? onCopy;
  final VoidCallback? onRename;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;

  bool get _hasMenu =>
      onCopy != null ||
      onRename != null ||
      onExport != null ||
      onDelete != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gs = preset.generationSettings;
    final detailParts = <String>[
      if (preset.description != null && preset.description!.isNotEmpty)
        preset.description!,
      if (preset.provider != null) preset.provider!,
      'T ${gs.temperature.toStringAsFixed(1)}',
      'P ${gs.topP.toStringAsFixed(2)}',
      'K ${gs.topK}',
      '${gs.maxTokens}',
    ];

    return SettingsControlTile(
      icon: _presetIcon(preset),
      title: preset.name,
      subtitle: detailParts.join(' · '),
      maxSubtitleLines: 2,
      showDivider: showDivider,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            Icon(Icons.check, color: scheme.primary, size: 20),
          if (isActive && _hasMenu) const SizedBox(width: 4),
          if (_hasMenu)
            AdaptiveActionMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'copy') onCopy?.call();
                if (value == 'rename') onRename?.call();
                if (value == 'export') onExport?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) {
                final l10n = AppLocalizations.of(context);
                return [
                  if (onCopy != null)
                    AdaptiveActionDrawerItem(
                      value: 'copy',
                      leading: const Icon(Icons.copy_all),
                      title: Text(l10n.copyToCustom),
                    ),
                  if (onRename != null)
                    AdaptiveActionDrawerItem(
                      value: 'rename',
                      leading: const Icon(Icons.drive_file_rename_outline),
                      title: Text(l10n.rename),
                    ),
                  if (onExport != null)
                    AdaptiveActionDrawerItem(
                      value: 'export',
                      leading: const Icon(Icons.file_upload),
                      title: Text(l10n.export),
                    ),
                  if (onDelete != null)
                    AdaptiveActionDrawerItem(
                      value: 'delete',
                      leading: const Icon(Icons.delete),
                      title: Text(l10n.delete),
                      destructive: true,
                    ),
                ];
              },
            ),
        ],
      ),
    );
  }

  IconData _presetIcon(AIPreset preset) {
    switch (preset.id) {
      case 'default':
        return Icons.tune;
      case 'creative':
        return Icons.auto_awesome;
      case 'precise':
        return Icons.precision_manufacturing;
      case 'deterministic':
        return Icons.lock;
      case 'longform':
        return Icons.article;
      case 'mirostat':
        return Icons.auto_graph;
      default:
        return Icons.settings;
    }
  }
}
