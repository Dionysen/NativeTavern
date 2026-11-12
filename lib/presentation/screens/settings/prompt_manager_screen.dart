import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:native_tavern/core/utils/share_utils.dart';
import 'package:native_tavern/data/models/prompt_manager.dart';
import 'package:native_tavern/presentation/providers/prompt_manager_providers.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_action_drawer.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';

/// Screen / embeddable panel for prompt section order and visibility.
class PromptManagerScreen extends ConsumerWidget {
  const PromptManagerScreen({
    super.key,
    this.embedded = false,
  });

  /// When true, renders without Scaffold for AI Config expand blocks.
  final bool embedded;

  List<AdaptiveActionDrawerItem<String>> _menuItems(AppLocalizations l10n) {
    return [
      AdaptiveActionDrawerItem(
        value: 'presets',
        leading: const Icon(Icons.list),
        title: Text(l10n.loadPreset),
      ),
      AdaptiveActionDrawerItem(
        value: 'save',
        leading: const Icon(Icons.save),
        title: Text(l10n.saveAsPresetLabel),
      ),
      AdaptiveActionDrawerItem(
        value: 'import',
        leading: const Icon(Icons.file_download),
        title: Text(l10n.importPresetLabel),
        showDividerAbove: true,
      ),
      AdaptiveActionDrawerItem(
        value: 'export',
        leading: const Icon(Icons.file_upload),
        title: Text(l10n.exportPreset),
      ),
      AdaptiveActionDrawerItem(
        value: 'reset',
        leading: const Icon(Icons.restore),
        title: Text(l10n.resetToDefault),
        showDividerAbove: true,
      ),
      AdaptiveActionDrawerItem(
        value: 'help',
        leading: const Icon(Icons.help_outline),
        title: Text(l10n.help),
      ),
    ];
  }

  void _onMenuSelected(
    BuildContext context,
    WidgetRef ref,
    String value,
    List<PromptManagerPreset> allPresets,
  ) {
    switch (value) {
      case 'presets':
        _showPresetsDialog(context, ref, allPresets);
      case 'import':
        _importPreset(context, ref);
      case 'export':
        _exportPreset(context, ref);
      case 'save':
        _saveAsPreset(context, ref);
      case 'reset':
        _showResetConfirmation(context, ref);
      case 'help':
        _showHelpDialog(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(promptManagerProvider);
    final sortedSections = config.sortedSections;
    final allPresets = ref.watch(allPresetsProvider);

    final l10n = AppLocalizations.of(context);

    final list = ReorderableListView.builder(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: sortedSections.length,
      onReorder: (oldIndex, newIndex) {
        ref.read(promptManagerProvider.notifier).reorder(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final section = sortedSections[index];
        final key = section.identifier != null
            ? ValueKey('${section.identifier}_$index')
            : ValueKey('${section.type.name}_$index');

        return _PromptSectionTile(
          key: key,
          section: section,
          index: index,
          showDivider: index < sortedSections.length - 1,
          onToggle: () {
            if (section.isCustom) {
              ref
                  .read(promptManagerProvider.notifier)
                  .toggleSectionByIndex(index);
            } else {
              ref
                  .read(promptManagerProvider.notifier)
                  .toggleSection(section.type);
            }
          },
          onEdit: section.isEditable
              ? () => _showEditContentDialog(
                    context,
                    ref,
                    section,
                    index,
                  )
              : null,
          onDuplicate: () =>
              _duplicatePromptEntry(context, ref, index, section),
          onDelete: section.isCustom
              ? () => _deletePromptEntry(context, ref, index, section)
              : null,
        );
      },
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            embedded ? 8 : 16,
            embedded ? 8 : 12,
            embedded ? 8 : 16,
            embedded ? 4 : 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (embedded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.dragToReorder,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ),
                      ChromeIconButton(
                        density: ChromeIconButtonDensity.compact,
                        icon: const Icon(Icons.add),
                        tooltip: l10n.addPrompt,
                        onPressed: () => _showAddPromptDialog(context, ref),
                      ),
                      AdaptiveActionMenuButton<String>(
                        density: ChromeIconButtonDensity.compact,
                        icon: const Icon(Icons.more_vert),
                        tooltip: l10n.moreOptions,
                        onSelected: (value) =>
                            _onMenuSelected(context, ref, value, allPresets),
                        itemBuilder: (context) =>
                            _menuItems(AppLocalizations.of(context)),
                      ),
                    ],
                  ),
                ),
              if (!embedded) ...[
                SettingsCategoryHeader(
                  icon: Icons.reorder,
                  title: l10n.promptManager,
                ),
                Text(
                  l10n.dragToReorder,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ] else ...[
                SettingsCategoryHeader(
                  icon: Icons.reorder,
                  title: l10n.promptManager,
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                ),
              ],
            ],
          ),
        ),
        if (embedded)
          list
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SettingsGroupedPanel(
                padding: EdgeInsets.zero,
                child: list,
              ),
            ),
          ),
      ],
    );

    if (embedded) return content;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.promptManager),
        actions: [
          AdaptiveActionMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: l10n.moreOptions,
            onSelected: (value) =>
                _onMenuSelected(context, ref, value, allPresets),
            itemBuilder: (context) =>
                _menuItems(AppLocalizations.of(context)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPromptDialog(context, ref),
        tooltip: l10n.addPrompt,
        child: const Icon(Icons.add),
      ),
      body: content,
    );
  }

  void _showPresetsDialog(
      BuildContext context, WidgetRef ref, List<PromptManagerPreset> presets) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.list,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.loadPreset,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  ChromeIconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: presets.length,
                itemBuilder: (context, index) {
                  final preset = presets[index];
                  final scheme = Theme.of(context).colorScheme;
                  return ListTile(
                    leading: Icon(
                      preset.isBuiltIn ? Icons.lock : Icons.edit,
                      color: preset.isBuiltIn
                          ? scheme.onSurfaceVariant
                          : scheme.secondary,
                    ),
                    title: Text(preset.name),
                    subtitle: preset.description != null
                        ? Text(preset.description!,
                            maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: preset.isBuiltIn
                        ? null
                        : ChromeIconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () {
                              ref
                                  .read(customPresetsProvider.notifier)
                                  .deletePreset(preset.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(AppLocalizations.of(context)!
                                        .deleted(preset.name))),
                              );
                            },
                          ),
                    onTap: () {
                      ref
                          .read(promptManagerProvider.notifier)
                          .applyPreset(preset);
                      ref
                          .read(activePresetIdProvider.notifier)
                          .setActivePreset(preset.id);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(AppLocalizations.of(context)!
                                .applied(preset.name))),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
      final isSillyTavern = json.containsKey('prompts') ||
          json.containsKey('prompt_order');
      final isNative = json['sections'] != null ||
          json['format'] == 'native_tavern_prompt_preset';

      if (!isSillyTavern && !isNative) {
        throw Exception(l10n.invalidPresetFormatMessage);
      }

      // Prefer saving as a named custom preset when NT-shaped or named ST file
      if (isNative || json['name'] != null || json['preset_name'] != null) {
        final preset =
            await ref.read(customPresetsProvider.notifier).importPreset(json);
        await ref.read(promptManagerProvider.notifier).applyPreset(preset);
        await ref
            .read(activePresetIdProvider.notifier)
            .setActivePreset(preset.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.importedPromptSections(
                  preset.name,
                  preset.config.sections.length,
                ),
              ),
            ),
          );
        }
      } else {
        await ref.read(promptManagerProvider.notifier).loadFromJson(json);
        final count = ref.read(promptManagerProvider).sections.length;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.importedPromptCount(count))),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importPresetFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _showAddPromptDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: l10n.customPrompt);
    final contentController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addPrompt),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.promptName,
                    border: const OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: TextField(
                    controller: contentController,
                    maxLines: null,
                    minLines: 4,
                    decoration: InputDecoration(
                      labelText: l10n.promptContent,
                      border: const OutlineInputBorder(),
                      hintText: l10n.enterPromptContent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.pleaseEnterNameMessage)),
                );
                return;
              }
              Navigator.pop(context, {
                'name': name,
                'content': contentController.text,
              });
            },
            child: Text(l10n.add),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      final section =
          await ref.read(promptManagerProvider.notifier).addCustomSection(
                name: result['name']!,
                content: result['content'] ?? '',
              );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.promptEntryAdded(section.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveFailedMessage(e.toString()))),
        );
      }
    }
  }

  Future<void> _duplicatePromptEntry(
    BuildContext context,
    WidgetRef ref,
    int index,
    PromptSection section,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      final copy = await ref
          .read(promptManagerProvider.notifier)
          .duplicateSectionAt(index, copySuffix: l10n.copyNameSuffix);
      if (copy != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.promptEntryDuplicated(copy.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveFailedMessage(e.toString()))),
        );
      }
    }
  }

  Future<void> _deletePromptEntry(
    BuildContext context,
    WidgetRef ref,
    int index,
    PromptSection section,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePromptEntry),
        content: Text(l10n.deletePromptConfirmation(section.name)),
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

    final removed =
        await ref.read(promptManagerProvider.notifier).removeSectionAt(index);
    if (removed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.promptEntryDeleted(section.name))),
      );
    }
  }

  Future<void> _exportPreset(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController(text: 'My Prompt Preset');

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.exportPresetTitle),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.presetNameLabel,
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(AppLocalizations.of(context)!.export),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !context.mounted) return;
    final shareOrigin = sharePositionOrigin(context);

    try {
      final json = ref.read(promptManagerProvider.notifier).exportToJson(name);
      final jsonString = const JsonEncoder.withIndent('  ').convert(json);

      // Save to temp file and share
      final tempDir = await getTemporaryDirectory();
      final fileName = '${name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        subject: 'NativeTavern Prompt Preset: $name',
        sharePositionOrigin: shareOrigin,
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .exportPresetFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _saveAsPreset(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.saveAsPreset),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.presetName,
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.descriptionOptional,
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(AppLocalizations.of(context)!
                          .pleaseEnterNameMessage)),
                );
                return;
              }
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'description': descController.text.trim(),
              });
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      final config = ref.read(promptManagerProvider);
      final preset =
          await ref.read(customPresetsProvider.notifier).saveCurrentAsPreset(
                config,
                result['name']!,
                result['description']!.isEmpty ? null : result['description'],
              );
      ref.read(activePresetIdProvider.notifier).setActivePreset(preset.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.saved(preset.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .saveFailedMessage(e.toString()))),
        );
      }
    }
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.resetToDefault),
        content: Text(AppLocalizations.of(context)!.resetToDefaultQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              ref.read(promptManagerProvider.notifier).resetToDefault();
              ref.read(activePresetIdProvider.notifier).setActivePreset(null);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        AppLocalizations.of(context)!.resetToDefaultConfig)),
              );
            },
            child: Text(AppLocalizations.of(context)!.reset),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.help_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.promptManagerHelp),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.whatIsPromptManager,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(l10n.promptManagerHelpDescription),
              const SizedBox(height: 16),
              Text(
                l10n.promptSectionTypes,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(l10n.promptSectionTypesDescription),
              const SizedBox(height: 16),
              Text(
                l10n.tips,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(l10n.promptManagerTips),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  void _showEditContentDialog(
      BuildContext context, WidgetRef ref, PromptSection section, int index) {
    final l10n = AppLocalizations.of(context);
    final contentController = TextEditingController(
      text: section.content ?? PromptSection.getDefaultContent(section.type),
    );
    final nameController = TextEditingController(text: section.name);

    final displayName = section.isCustom
        ? section.name
        : _promptSectionName(section.type, l10n);
    final description = section.isCustom
        ? l10n.customImportedPrompt
        : _promptSectionDescription(section.type, l10n);

    showDialog(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final muted = scheme.onSurfaceVariant;
        return AlertDialog(
        title: Row(
          children: [
            Icon(
              section.isCustom ? Icons.code : Icons.edit,
              color: section.isCustom ? scheme.secondary : scheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.editPromptSection(displayName),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show name editor for custom prompts
                if (section.isCustom) ...[
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: l10n.promptName,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: muted,
                      ),
                ),
                if (section.identifier != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.identifierLabel(section.identifier!),
                    style: TextStyle(
                      color: muted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                if (section.role != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.roleLabel(section.role!),
                    style: TextStyle(
                      color: muted,
                      fontSize: 10,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  l10n.supportedPromptMacros(
                    '{{user}}',
                    '{{char}}',
                    '{{time}}',
                    '{{date}}',
                  ),
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: TextField(
                    controller: contentController,
                    maxLines: null,
                    minLines: 5,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: l10n.enterPromptContent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (!section.isCustom)
            TextButton(
              onPressed: () {
                // Reset to default
                contentController.text =
                    PromptSection.getDefaultContent(section.type);
              },
              child: Text(l10n.resetToDefault),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newContent = contentController.text.trim();
              final newName = nameController.text.trim();

              if (section.isCustom) {
                // Update custom prompt with new name and content
                ref.read(promptManagerProvider.notifier).updateSectionByIndex(
                      index,
                      section.copyWith(
                        name: newName.isNotEmpty ? newName : section.name,
                        content: newContent,
                      ),
                    );
              } else {
                // Update built-in prompt content
                ref.read(promptManagerProvider.notifier).updateSectionContent(
                      section.type,
                      newContent,
                    );
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.updated(
                    section.isCustom ? newName : displayName,
                  )),
                ),
              );
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      );
      },
    );
  }
}

class _PromptSectionTile extends StatelessWidget {
  final PromptSection section;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final bool showDivider;

  const _PromptSectionTile({
    super.key,
    required this.section,
    required this.index,
    required this.onToggle,
    this.onEdit,
    this.onDuplicate,
    this.onDelete,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final displayName = section.isCustom
        ? section.name
        : _promptSectionName(section.type, l10n);

    final String description;
    if (section.isCustom) {
      description = section.content?.isNotEmpty == true
          ? '${section.content!.substring(0, section.content!.length.clamp(0, 50))}...'
          : l10n.customPrompt;
    } else if (section.isCharacterOwned) {
      // Character-card fields are injected at chat time; no in-manager preview.
      description = l10n.promptOwnedByCharacter;
    } else {
      description = _promptSectionDescription(section.type, l10n);
    }

    final enabled = section.enabled;
    final muted = colorScheme.onSurfaceVariant;

    return SettingsControlTile(
      dragIndex: index,
      title: displayName,
      subtitle: description,
      maxSubtitleLines: 1,
      enabled: enabled,
      showDivider: showDivider,
      onTap: onEdit != null && enabled ? onEdit : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null || onDuplicate != null || onDelete != null)
            AdaptiveActionMenuButton<String>(
              density: ChromeIconButtonDensity.compact,
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: enabled ? muted : muted.withValues(alpha: 0.5),
              ),
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'duplicate') onDuplicate?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) {
                final menuL10n = AppLocalizations.of(context);
                return [
                  if (onEdit != null)
                    AdaptiveActionDrawerItem(
                      value: 'edit',
                      leading: const Icon(Icons.edit),
                      title: Text(menuL10n.edit),
                    ),
                  if (onDuplicate != null)
                    AdaptiveActionDrawerItem(
                      value: 'duplicate',
                      leading: const Icon(Icons.copy_all),
                      title: Text(menuL10n.duplicate),
                    ),
                  if (onDelete != null)
                    AdaptiveActionDrawerItem(
                      value: 'delete',
                      leading: const Icon(Icons.delete),
                      title: Text(menuL10n.delete),
                      destructive: true,
                    ),
                ];
              },
            ),
          ThemedSwitch(
            value: enabled,
            onChanged: (_) => onToggle(),
          ),
        ],
      ),
    );
  }
}

String _promptSectionName(
  PromptSectionType type,
  AppLocalizations l10n,
) {
  return switch (type) {
    PromptSectionType.systemPrompt => l10n.promptSectionSystemPrompt,
    PromptSectionType.persona => l10n.promptSectionPersona,
    PromptSectionType.characterDescription =>
      l10n.promptSectionCharacterDescription,
    PromptSectionType.characterPersonality =>
      l10n.promptSectionCharacterPersonality,
    PromptSectionType.characterScenario => l10n.promptSectionScenario,
    PromptSectionType.exampleMessages => l10n.promptSectionExampleMessages,
    PromptSectionType.worldInfo => l10n.promptSectionWorldInfoBefore,
    PromptSectionType.worldInfoAfter => l10n.promptSectionWorldInfoAfter,
    PromptSectionType.authorNote => l10n.promptSectionAuthorNote,
    PromptSectionType.postHistoryInstructions => l10n.promptSectionPostHistory,
    PromptSectionType.nsfw => l10n.promptSectionNsfw,
    PromptSectionType.chatHistory => l10n.promptSectionChatHistory,
    PromptSectionType.enhanceDefinitions =>
      l10n.promptSectionEnhanceDefinitions,
    PromptSectionType.custom => l10n.customPrompt,
  };
}

String _promptSectionDescription(
  PromptSectionType type,
  AppLocalizations l10n,
) {
  return switch (type) {
    PromptSectionType.systemPrompt => l10n.promptSectionSystemPromptDescription,
    PromptSectionType.persona => l10n.promptSectionPersonaDescription,
    PromptSectionType.characterDescription =>
      l10n.promptSectionCharacterDescriptionDescription,
    PromptSectionType.characterPersonality =>
      l10n.promptSectionCharacterPersonalityDescription,
    PromptSectionType.characterScenario =>
      l10n.promptSectionScenarioDescription,
    PromptSectionType.exampleMessages =>
      l10n.promptSectionExampleMessagesDescription,
    PromptSectionType.worldInfo => l10n.promptSectionWorldInfoBeforeDescription,
    PromptSectionType.worldInfoAfter =>
      l10n.promptSectionWorldInfoAfterDescription,
    PromptSectionType.authorNote => l10n.promptSectionAuthorNoteDescription,
    PromptSectionType.postHistoryInstructions =>
      l10n.promptSectionPostHistoryDescription,
    PromptSectionType.nsfw => l10n.promptSectionNsfwDescription,
    PromptSectionType.chatHistory => l10n.promptSectionChatHistoryDescription,
    PromptSectionType.enhanceDefinitions =>
      l10n.promptSectionEnhanceDefinitionsDescription,
    PromptSectionType.custom => l10n.promptSectionCustomDescription,
  };
}
