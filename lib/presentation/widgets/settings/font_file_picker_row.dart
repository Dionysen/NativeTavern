import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:native_tavern/data/models/theme/system_font.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';

/// Font picker with system/imported fonts and file import (Zephyr-style).
class FontFilePickerRow extends StatelessWidget {
  const FontFilePickerRow({
    super.key,
    required this.label,
    required this.description,
    required this.fonts,
    required this.selectedPath,
    this.fallbackFamilyLabel,
    required this.isLoading,
    required this.onSelected,
    required this.onImportPath,
    this.icon = Icons.text_fields,
    this.onDeleteFont,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String description;
  final List<SystemFont> fonts;
  final String? selectedPath;
  final String? fallbackFamilyLabel;
  final bool isLoading;
  final ValueChanged<SystemFont?> onSelected;
  final Future<bool> Function(String path) onImportPath;
  final Future<bool> Function(SystemFont font)? onDeleteFont;
  final bool showDivider;

  SystemFont? get _selectedFont {
    final path = selectedPath;
    if (path == null || path.isEmpty) return null;
    return fonts.where((font) => font.path == path).firstOrNull;
  }

  String _selectedLabel(AppLocalizations l10n) {
    final path = selectedPath ?? '';
    if (path.isEmpty) {
      final fallback = fallbackFamilyLabel;
      if (fallback != null && fallback.isNotEmpty) return fallback;
      return l10n.uiFontFamilySystem;
    }
    final font = _selectedFont;
    if (font != null) return font.family;
    return path.split(RegExp(r'[/\\]')).last;
  }

  Future<void> _import(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final file = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ttf', 'otf', 'ttc', 'otc'],
    );
    final path = file?.files.single.path;
    if (path == null || path.isEmpty) return;
    final ok = await onImportPath(path);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.fontImportSuccess : l10n.fontImportFailure),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final query = ValueNotifier('');
    try {
      await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: l10n.fontSearchHint,
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (value) => query.value = value.trim(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => _import(context),
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: Text(l10n.fontImportFromFile),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: query,
                      builder: (context, filter, _) {
                        final lower = filter.toLowerCase();
                        final filtered = filter.isEmpty
                            ? fonts
                            : fonts
                                .where(
                                  (f) =>
                                      f.family.toLowerCase().contains(lower),
                                )
                                .toList();
                        return ListView(
                          controller: scrollController,
                          children: [
                            ListTile(
                              title: Text(l10n.uiFontFamilySystem),
                              trailing: (selectedPath ?? '').isEmpty
                                  ? Icon(
                                      Icons.check,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    )
                                  : null,
                              onTap: () {
                                onSelected(null);
                                Navigator.pop(context);
                              },
                            ),
                            for (final font in filtered)
                              ListTile(
                                title: Text(font.family),
                                subtitle: font.imported
                                    ? Text(l10n.fontImportedBadge)
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (font.path == selectedPath)
                                      Icon(
                                        Icons.check,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    if (font.imported &&
                                        onDeleteFont != null)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                        ),
                                        tooltip: l10n.fontDeleteFromLibrary,
                                        onPressed: () async {
                                          final confirmed =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text(
                                                l10n.fontDeleteDialogTitle,
                                              ),
                                              content: Text(
                                                l10n.fontDeleteDialogBody(
                                                  font.family,
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: Text(l10n.cancel),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child: Text(l10n.delete),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed != true ||
                                              !context.mounted) {
                                            return;
                                          }
                                          final ok =
                                              await onDeleteFont!(font);
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                ok
                                                    ? l10n.fontDeleteSuccess
                                                    : l10n.fontDeleteFailure,
                                              ),
                                            ),
                                          );
                                          if (ok) {
                                            Navigator.pop(context);
                                          }
                                        },
                                      ),
                                  ],
                                ),
                                onTap: () {
                                  onSelected(font);
                                  Navigator.pop(context);
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    } finally {
      query.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return SettingsListTile(
      icon: icon,
      title: label,
      subtitle: description,
      showDivider: showDivider,
      onTap: () => _openPicker(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: muted.withValues(alpha: 0.7),
                ),
              ),
            ),
          Flexible(
            child: Text(
              _selectedLabel(l10n),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: muted,
                  ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: muted, size: 20),
        ],
      ),
    );
  }
}
