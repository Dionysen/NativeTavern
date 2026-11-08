import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/status_block_config.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/status_block_providers.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';

class StatusBlockSettingsScreen extends ConsumerStatefulWidget {
  const StatusBlockSettingsScreen({super.key});

  @override
  ConsumerState<StatusBlockSettingsScreen> createState() =>
      _StatusBlockSettingsScreenState();
}

class _StatusBlockSettingsScreenState
    extends ConsumerState<StatusBlockSettingsScreen> {
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(
      text: ref.read(statusBlockConfigProvider).promptTemplate,
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(statusBlockConfigProvider);
    final fields = config.normalizedFields();
    final notifier = ref.read(statusBlockConfigProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.characterStatus),
        actions: [
          ChromeIconButton(
            icon: const Icon(Icons.restore),
            tooltip: l10n.resetToDefault,
            onPressed: () async {
              await notifier.resetToDefault();
              if (mounted) {
                _promptController.text =
                    ref.read(statusBlockConfigProvider).promptTemplate;
              }
            },
          ),
        ],
      ),
      body: SettingsPageBody(
        children: [
          SettingsSection(
            icon: Icons.badge_outlined,
            title: l10n.characterStatus,
            children: [
              SettingsSwitchTile(
                icon: Icons.toggle_on_outlined,
                title: l10n.enableCharacterStatus,
                subtitle: l10n.enableCharacterStatusHint,
                value: config.enabled,
                onChanged: notifier.setEnabled,
              ),
              SettingsSwitchTile(
                icon: Icons.input_outlined,
                title: l10n.characterStatusInjectContext,
                subtitle: l10n.characterStatusInjectContextHint,
                value: config.injectIntoContext,
                onChanged: notifier.setInjectIntoContext,
              ),
              SettingsSwitchTile(
                icon: Icons.badge_outlined,
                title: l10n.characterStatusAutoDisableCard,
                subtitle: l10n.characterStatusAutoDisableCardHint,
                value: config.autoDisableWhenCardHasStatus,
                showDivider: false,
                onChanged: notifier.setAutoDisableWhenCardHasStatus,
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.list_alt_outlined,
            title: l10n.characterStatusFields,
            children: [
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: fields.length,
                onReorder: notifier.reorderFields,
                itemBuilder: (context, index) {
                  final field = fields[index];
                  final fieldPrompt = field.prompt.trim();
                  return ListTile(
                    key: ValueKey('status-field-${field.id}-$index'),
                    leading: Icon(
                      field.locked ? Icons.lock_outline : Icons.drag_handle,
                    ),
                    title: Text(field.label),
                    subtitle: field.locked
                        ? Text(l10n.characterStatusFieldLocked)
                        : fieldPrompt.isEmpty
                            ? null
                            : Text(
                                fieldPrompt,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                    trailing: field.locked
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ChromeIconButton(
                                density: ChromeIconButtonDensity.compact,
                                tooltip: l10n.edit,
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _editField(context, index, field),
                              ),
                              ChromeIconButton(
                                density: ChromeIconButtonDensity.compact,
                                tooltip: l10n.deleteStatusField,
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () =>
                                    notifier.removeFieldAt(index),
                              ),
                            ],
                          ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: OutlinedButton.icon(
                  onPressed: fields.length >= StatusBlockConfig.maxFields
                      ? null
                      : () => _addField(context),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.characterStatusAddField),
                ),
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.code,
            title: l10n.characterStatusPromptTemplate,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  l10n.characterStatusPromptPlaceholders,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextField(
                  controller: _promptController,
                  maxLines: 12,
                  minLines: 6,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: StatusBlockConfig.defaultPromptTemplate,
                  ),
                  onChanged: notifier.setPromptTemplate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addField(BuildContext context) async {
    final result = await _showFieldEditorDialog(
      context,
      title: AppLocalizations.of(context).characterStatusAddField,
    );
    if (result == null || result.label.isEmpty) return;
    await ref.read(statusBlockConfigProvider.notifier).addField(
          result.label,
          prompt: result.prompt,
        );
  }

  Future<void> _editField(
    BuildContext context,
    int index,
    StatusFieldSlot field,
  ) async {
    final result = await _showFieldEditorDialog(
      context,
      title: AppLocalizations.of(context).edit,
      initialLabel: field.label,
      initialPrompt: field.prompt,
    );
    if (result == null || result.label.isEmpty) return;
    await ref.read(statusBlockConfigProvider.notifier).updateFieldAt(
          index,
          label: result.label,
          prompt: result.prompt,
        );
  }

  Future<({String label, String prompt})?> _showFieldEditorDialog(
    BuildContext context, {
    required String title,
    String initialLabel = '',
    String initialPrompt = '',
  }) async {
    final l10n = AppLocalizations.of(context);
    final labelController = TextEditingController(text: initialLabel);
    final promptController = TextEditingController(text: initialPrompt);
    final result = await showDialog<({String label, String prompt})>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.characterStatusFieldLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: promptController,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                labelText: l10n.characterStatusFieldPrompt,
                hintText: l10n.characterStatusFieldPromptHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              (
                label: labelController.text.trim(),
                prompt: promptController.text.trim(),
              ),
            ),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    labelController.dispose();
    promptController.dispose();
    return result;
  }
}
