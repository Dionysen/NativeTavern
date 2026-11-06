import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:native_tavern/data/models/regex_script.dart';
import 'package:native_tavern/domain/services/regex_service.dart';
import 'package:native_tavern/presentation/providers/regex_providers.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_action_drawer.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/widgets/regex/regex_script_widgets.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';

/// Screen for managing regex scripts
class RegexSettingsScreen extends ConsumerWidget {
  const RegexSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(regexSettingsProvider);
    final scripts = ref.watch(globalRegexScriptsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.regexScripts),
        actions: spacedAppBarActions([
          ChromeIconButton(
            icon: const Icon(Icons.add),
            tooltip: AppLocalizations.of(context)!.addScript,
            onPressed: () => _showScriptEditor(context, ref, null),
          ),
          AdaptiveActionMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, ref, value),
            itemBuilder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return [
                AdaptiveActionDrawerItem(
                  value: 'add_presets',
                  leading: const Icon(Icons.auto_awesome),
                  title: Text(l10n.addPresets),
                ),
                AdaptiveActionDrawerItem(
                  value: 'import',
                  leading: const Icon(Icons.file_download),
                  title: Text(l10n.import),
                ),
                AdaptiveActionDrawerItem(
                  value: 'export',
                  leading: const Icon(Icons.file_upload),
                  title: Text(l10n.export),
                ),
                AdaptiveActionDrawerItem(
                  value: 'clear_all',
                  leading: const Icon(Icons.delete_sweep),
                  title: Text(l10n.clearAll),
                  destructive: true,
                  showDividerAbove: true,
                ),
              ];
            },
          ),
        ]),
      ),
      body: SettingsPageBody(
        children: [
          SettingsSection(
            icon: Icons.toggle_on_outlined,
            title: AppLocalizations.of(context)!.general,
            children: [
              SettingsSwitchTile(
                icon: Icons.find_replace,
                title: AppLocalizations.of(context)!.enableRegexScripts,
                subtitle: AppLocalizations.of(context)!.applyFindReplacePatterns,
                value: settings.enabled,
                showDivider: false,
                onChanged: (value) {
                  ref.read(regexSettingsProvider.notifier).setEnabled(value);
                },
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.filter_alt_outlined,
            title: AppLocalizations.of(context)!.applyTo,
            children: [
              SettingsSwitchTile(
                icon: Icons.person_outline,
                title: AppLocalizations.of(context)!.userInput,
                subtitle: AppLocalizations.of(context)!.applyBeforeSending,
                value: settings.applyToUserInput,
                onChanged: settings.enabled
                    ? (value) {
                        ref
                            .read(regexSettingsProvider.notifier)
                            .setApplyToUserInput(value);
                      }
                    : null,
              ),
              SettingsSwitchTile(
                icon: Icons.smart_toy_outlined,
                title: AppLocalizations.of(context)!.aiOutput,
                subtitle: AppLocalizations.of(context)!.applyToAiResponses,
                value: settings.applyToAiOutput,
                onChanged: settings.enabled
                    ? (value) {
                        ref
                            .read(regexSettingsProvider.notifier)
                            .setApplyToAiOutput(value);
                      }
                    : null,
              ),
              SettingsSwitchTile(
                icon: Icons.terminal,
                title: AppLocalizations.of(context)!.slashCommandsLabel,
                subtitle: AppLocalizations.of(context)!.applyDuringCommandProcessing,
                value: settings.applyToSlashCommands,
                onChanged: settings.enabled
                    ? (value) {
                        ref
                            .read(regexSettingsProvider.notifier)
                            .setApplyToSlashCommands(value);
                      }
                    : null,
              ),
              SettingsSwitchTile(
                icon: Icons.public,
                title: AppLocalizations.of(context)!.worldInfoLabel,
                subtitle: AppLocalizations.of(context)!.applyToWorldInfoEntries,
                value: settings.applyToWorldInfo,
                showDivider: false,
                onChanged: settings.enabled
                    ? (value) {
                        ref
                            .read(regexSettingsProvider.notifier)
                            .setApplyToWorldInfo(value);
                      }
                    : null,
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.code,
            title: AppLocalizations.of(context)!.scriptsCount(scripts.length),
            children: [
              if (scripts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.find_replace,
                            size: 48, color: AppTheme.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.noRegexScripts,
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.tapToAddOrUseMenu,
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: scripts.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    ref
                        .read(globalRegexScriptsProvider.notifier)
                        .reorderScripts(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final script = scripts[index];
                    return RegexScriptTile(
                      key: ValueKey(script.id),
                      script: script,
                      dragIndex: index,
                      showDivider: index < scripts.length - 1,
                      onTap: () => _showScriptEditor(context, ref, script),
                      onToggle: () {
                        ref
                            .read(globalRegexScriptsProvider.notifier)
                            .toggleScript(script.id);
                      },
                      onDelete: () => _confirmDelete(context, ref, script),
                    );
                  },
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Test section
          SettingsSection(
            icon: Icons.settings_outlined,
            title: AppLocalizations.of(context)!.test,
            children: [
              const _RegexTestWidget(),
            ],
          ),

          const SizedBox(height: 16),

          SettingsSection(
            icon: Icons.info_outline,
            title: AppLocalizations.of(context).information,
            children: [
              SettingsListTile(
                icon: Icons.info_outline,
                title: AppLocalizations.of(context).aboutRegexScripts,
                subtitle:
                    AppLocalizations.of(context).aboutRegexScriptsDescription,
              ),
              SettingsListTile(
                icon: Icons.code,
                title: AppLocalizations.of(context).patternFormat,
                subtitle:
                    AppLocalizations.of(context).patternFormatDescription,
                showDivider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'add_presets':
        ref.read(globalRegexScriptsProvider.notifier).addPresets();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.presetScriptsAdded)),
        );
        break;
      case 'import':
        _showImportDialog(context, ref);
        break;
      case 'export':
        _showExportDialog(context, ref);
        break;
      case 'clear_all':
        _confirmClearAll(context, ref);
        break;
    }
  }

  void _showScriptEditor(
      BuildContext context, WidgetRef ref, RegexScript? script) {
    showRegexScriptEditor(
      context,
      script: script,
      onSave: (newScript) {
        if (script == null) {
          ref.read(globalRegexScriptsProvider.notifier).addScript(newScript);
        } else {
          ref.read(globalRegexScriptsProvider.notifier).updateScript(newScript);
        }
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, RegexScript script) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteScript),
        content: Text(AppLocalizations.of(context)!
            .deleteScriptQuestion(script.scriptName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(globalRegexScriptsProvider.notifier)
                  .removeScript(script.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.clearAllScripts),
        content: Text(AppLocalizations.of(context)!.clearAllScriptsQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(globalRegexScriptsProvider.notifier).clearAll();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.clearAll),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonContent = await file.readAsString();

        final count = await ref
            .read(globalRegexScriptsProvider.notifier)
            .importScripts(jsonContent);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(AppLocalizations.of(context)!.importedCount(count))),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).importFailed('$e')),
          ),
        );
      }
    }
  }

  void _showExportDialog(BuildContext context, WidgetRef ref) {
    final json = ref.read(globalRegexScriptsProvider.notifier).exportScripts();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.exportScripts),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                json,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.close),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text(AppLocalizations.of(context)!.copiedToClipboard)),
              );
            },
            icon: const Icon(Icons.copy),
            label: Text(AppLocalizations.of(context)!.copy),
          ),
        ],
      ),
    );
  }
}

/// Widget for testing regex patterns
class _RegexTestWidget extends ConsumerStatefulWidget {
  const _RegexTestWidget();

  @override
  ConsumerState<_RegexTestWidget> createState() => _RegexTestWidgetState();
}

class _RegexTestWidgetState extends ConsumerState<_RegexTestWidget> {
  final _patternController = TextEditingController();
  final _testController = TextEditingController();
  final _replaceController = TextEditingController();
  RegexTestResult? _result;

  @override
  void dispose() {
    _patternController.dispose();
    _testController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  void _test() {
    final service = ref.read(regexServiceProvider);
    setState(() {
      _result = service.testRegex(
        _patternController.text,
        _testController.text,
        _replaceController.text,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _patternController,
            decoration: InputDecoration(
              labelText: l10n.pattern,
              hintText: '/pattern/flags',
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _testController,
            decoration: InputDecoration(
              labelText: l10n.testString,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _replaceController,
            decoration: InputDecoration(
              labelText: l10n.replacement,
              hintText: r'$1, $2, {{match}}',
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _test,
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.test),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _result!.success
                    ? AppTheme.accentColor.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _result!.success ? AppTheme.accentColor : Colors.red,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _result!.success ? Icons.check : Icons.error,
                        size: 16,
                        color: _result!.success
                            ? AppTheme.accentColor
                            : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _result!.success
                            ? '${_result!.matches.length} match(es)'
                            : 'Error',
                        style: TextStyle(
                          color: _result!.success
                              ? AppTheme.accentColor
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (_result!.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _result!.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  if (_result!.success) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.result,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        _result!.result,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
