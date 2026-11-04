import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_tavern/data/models/regex_script.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:uuid/uuid.dart';

/// Show the shared regex script editor as a modal bottom sheet.
Future<void> showRegexScriptEditor(
  BuildContext context, {
  RegexScript? script,
  required void Function(RegexScript) onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.darkCard,
    builder: (context) => RegexScriptEditor(
      script: script,
      onSave: (newScript) {
        onSave(newScript);
        Navigator.pop(context);
      },
    ),
  );
}

/// Tile for displaying a regex script in a list.
class RegexScriptTile extends StatelessWidget {
  final RegexScript script;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final bool showDragHandle;

  const RegexScriptTile({
    super.key,
    required this.script,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    this.showDragHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.find_replace,
        color: script.disabled ? AppTheme.textMuted : AppTheme.accentColor,
      ),
      title: Text(
        script.scriptName,
        style: TextStyle(
          color: script.disabled ? AppTheme.textMuted : null,
          decoration: script.disabled ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        script.findRegex,
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: AppTheme.textMuted,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              script.disabled ? Icons.toggle_off : Icons.toggle_on,
              color:
                  script.disabled ? AppTheme.textMuted : AppTheme.accentColor,
            ),
            onPressed: onToggle,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: onDelete,
          ),
          if (showDragHandle)
            const Icon(Icons.drag_handle, color: AppTheme.textMuted),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Editor for creating/editing regex scripts.
class RegexScriptEditor extends StatefulWidget {
  final RegexScript? script;
  final void Function(RegexScript) onSave;

  const RegexScriptEditor({
    super.key,
    this.script,
    required this.onSave,
  });

  @override
  State<RegexScriptEditor> createState() => _RegexScriptEditorState();
}

class _RegexScriptEditorState extends State<RegexScriptEditor> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _findController;
  late TextEditingController _replaceController;
  late TextEditingController _minDepthController;
  late TextEditingController _maxDepthController;
  late TextEditingController _trimStringsController;
  late List<RegexPlacement> _placement;
  late bool _markdownOnly;
  late bool _promptOnly;
  late bool _runOnEdit;
  late SubstituteRegex _substituteRegex;

  @override
  void initState() {
    super.initState();
    final script = widget.script;
    _nameController = TextEditingController(text: script?.scriptName ?? '');
    _descriptionController =
        TextEditingController(text: script?.description ?? '');
    _findController = TextEditingController(text: script?.findRegex ?? '');
    _replaceController =
        TextEditingController(text: script?.replaceString ?? '');
    _minDepthController = TextEditingController(
      text: script?.minDepth?.toString() ?? '',
    );
    _maxDepthController = TextEditingController(
      text: script?.maxDepth?.toString() ?? '',
    );
    _trimStringsController = TextEditingController(
      text: script?.trimStrings.join('\n') ?? '',
    );
    _placement = List<RegexPlacement>.from(
      script?.placement ?? [RegexPlacement.aiOutput],
    );
    _markdownOnly = script?.markdownOnly ?? false;
    _promptOnly = script?.promptOnly ?? false;
    _runOnEdit = script?.runOnEdit ?? false;
    _substituteRegex = script?.substituteRegex ?? SubstituteRegex.none;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _findController.dispose();
    _replaceController.dispose();
    _minDepthController.dispose();
    _maxDepthController.dispose();
    _trimStringsController.dispose();
    super.dispose();
  }

  int? _parseOptionalInt(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  List<String> _parseTrimStrings() {
    return _trimStringsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.script == null ? l10n.newScript : l10n.editScript,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _save,
                      child: Text(l10n.save),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.scriptName,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: l10n.descriptionOptional,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _findController,
                      decoration: InputDecoration(
                        labelText: l10n.findPattern,
                        hintText: l10n.patternOrPlainPattern,
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _replaceController,
                      decoration: InputDecoration(
                        labelText: l10n.replaceWith,
                        hintText: l10n.replacementHint,
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _trimStringsController,
                      decoration: InputDecoration(
                        labelText: l10n.trimStrings,
                        hintText: l10n.trimStringsHint,
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                      minLines: 2,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minDepthController,
                            decoration: InputDecoration(
                              labelText: l10n.minDepth,
                              hintText: l10n.depthUnlimitedHint,
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxDepthController,
                            decoration: InputDecoration(
                              labelText: l10n.maxDepth,
                              hintText: l10n.depthUnlimitedHint,
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.applyTo,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: RegexPlacement.values.map((p) {
                        final selected = _placement.contains(p);
                        return FilterChip(
                          label: Text(regexPlacementName(p, l10n)),
                          selected: selected,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _placement.add(p);
                              } else {
                                _placement.remove(p);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.options,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SwitchListTile(
                      title: Text(l10n.markdownOnly),
                      subtitle: Text(l10n.onlyApplyDuringMarkdown),
                      value: _markdownOnly,
                      onChanged: (value) =>
                          setState(() => _markdownOnly = value),
                    ),
                    SwitchListTile(
                      title: Text(l10n.promptOnly),
                      subtitle: Text(l10n.onlyApplyDuringPrompt),
                      value: _promptOnly,
                      onChanged: (value) => setState(() => _promptOnly = value),
                    ),
                    SwitchListTile(
                      title: Text(l10n.runOnEdit),
                      subtitle: Text(l10n.applyWhenEditingMessages),
                      value: _runOnEdit,
                      onChanged: (value) => setState(() => _runOnEdit = value),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<SubstituteRegex>(
                      value: _substituteRegex,
                      decoration: InputDecoration(
                        labelText: l10n.macroSubstitution,
                        border: const OutlineInputBorder(),
                      ),
                      items: SubstituteRegex.values.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _substituteRegex = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    if (_nameController.text.isEmpty || _findController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.nameAndPatternRequired)),
      );
      return;
    }

    final now = DateTime.now();
    final existing = widget.script;
    final script = RegexScript(
      id: existing?.id ?? const Uuid().v4(),
      scriptName: _nameController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      disabled: existing?.disabled ?? false,
      findRegex: _findController.text,
      replaceString: _replaceController.text,
      trimStrings: _parseTrimStrings(),
      placement: List<RegexPlacement>.from(_placement),
      scriptType: existing?.scriptType ?? RegexScriptType.global,
      markdownOnly: _markdownOnly,
      promptOnly: _promptOnly,
      runOnEdit: _runOnEdit,
      substituteRegex: _substituteRegex,
      minDepth: _parseOptionalInt(_minDepthController.text),
      maxDepth: _parseOptionalInt(_maxDepthController.text),
      order: existing?.order ?? 0,
      characterId: existing?.characterId,
      chatId: existing?.chatId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    widget.onSave(script);
  }
}

String regexPlacementName(
  RegexPlacement placement,
  AppLocalizations l10n,
) {
  return switch (placement) {
    RegexPlacement.userInput => l10n.userInput,
    RegexPlacement.aiOutput => l10n.aiOutput,
    RegexPlacement.slashCommand => l10n.slashCommandsLabel,
    RegexPlacement.worldInfo => l10n.worldInfoLabel,
    RegexPlacement.reasoning => l10n.reasoning,
  };
}
