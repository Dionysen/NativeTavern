import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/regex_script.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/regex_providers.dart';
import 'package:native_tavern/presentation/widgets/regex/regex_script_widgets.dart';

/// Character-scoped regex scripts list for character detail.
class CharacterRegexSection extends ConsumerWidget {
  final String characterId;

  const CharacterRegexSection({
    super.key,
    required this.characterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final scripts = ref.watch(characterRegexScriptsProvider(characterId));

    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.find_replace, color: scheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.characterRegexScripts,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: scheme.tertiary,
                        ),
                      ),
                      Text(
                        l10n.characterRegexScriptsHint,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: l10n.addScript,
                  onPressed: () => _showEditor(context, ref, null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (scripts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    l10n.noCharacterRegexScripts,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: scripts.length,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  ref
                      .read(characterRegexScriptsProvider(characterId).notifier)
                      .reorderScripts(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final script = scripts[index];
                  return RegexScriptTile(
                    key: ValueKey(script.id),
                    script: script,
                    onTap: () => _showEditor(context, ref, script),
                    onToggle: () {
                      ref
                          .read(
                            characterRegexScriptsProvider(characterId).notifier,
                          )
                          .toggleScript(script.id);
                    },
                    onDelete: () => _confirmDelete(context, ref, script),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEditor(
    BuildContext context,
    WidgetRef ref,
    RegexScript? script,
  ) {
    showRegexScriptEditor(
      context,
      script: script,
      onSave: (newScript) {
        final notifier =
            ref.read(characterRegexScriptsProvider(characterId).notifier);
        if (script == null) {
          notifier.addScript(newScript);
        } else {
          notifier.updateScript(newScript);
        }
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    RegexScript script,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteScript),
        content: Text(l10n.deleteScriptQuestion(script.scriptName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(characterRegexScriptsProvider(characterId).notifier)
                  .removeScript(script.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
