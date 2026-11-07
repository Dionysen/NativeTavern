import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/world_info.dart';
import 'package:native_tavern/core/utils/share_utils.dart';
import 'package:native_tavern/domain/services/world_info_import.dart';
import 'package:native_tavern/presentation/providers/character_providers.dart';
import 'package:native_tavern/presentation/providers/world_info_providers.dart';
import 'package:native_tavern/presentation/screens/world_info/world_info_entry_editor_screen.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_action_drawer.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';

/// Log a message to the console
void _log(String message, {String? error, StackTrace? stackTrace}) {
  final timestamp = DateTime.now().toIso8601String();
  final logMessage = '[$timestamp] WorldInfoScreen: $message';

  if (kDebugMode) {
    debugPrint(logMessage);
    if (error != null) {
      debugPrint('  Error: $error');
    }
  }

  developer.log(
    message,
    name: 'WorldInfoScreen',
    error: error,
    stackTrace: stackTrace,
  );
}

enum _LorebookListScope { all, global, local }

/// Screen for managing World Info / Lorebooks
class WorldInfoScreen extends ConsumerStatefulWidget {
  const WorldInfoScreen({super.key});

  @override
  ConsumerState<WorldInfoScreen> createState() => _WorldInfoScreenState();
}

class _WorldInfoScreenState extends ConsumerState<WorldInfoScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _LorebookListScope _scopeFilter = _LorebookListScope.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final worldInfosAsync = ref.watch(worldInfoNotifierProvider);
    final entryCounts = ref.watch(worldInfoEntryCountsProvider).valueOrNull ??
        const <String, int>{};
    final characters =
        ref.watch(characterListProvider).valueOrNull ?? const [];
    final characterNames = {
      for (final c in characters) c.id: c.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.worldInfoLorebooks),
        actions: spacedAppBarActions([
          ChromeIconButton(
            icon: const Icon(Icons.file_download),
            tooltip: l10n.import,
            onPressed: () => _importWorldInfo(context),
          ),
          ChromeIconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.createLorebook,
            onPressed: _showCreateDialog,
          ),
        ]),
      ),
      body: worldInfosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('${l10n.error}: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(worldInfoNotifierProvider.notifier).refresh(),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (worldInfos) {
          if (worldInfos.isEmpty) {
            return _buildEmptyState();
          }

          final filtered = _filterWorldInfos(worldInfos);
          return Column(
            children: [
              _buildSearchField(l10n),
              _buildScopeFilter(l10n),
              Expanded(
                child: filtered.isEmpty
                    ? _buildNoMatchesState(l10n)
                    : _buildGroupedList(
                        filtered,
                        entryCounts,
                        characterNames,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<WorldInfo> _filterWorldInfos(List<WorldInfo> worldInfos) {
    final query = _searchQuery.trim().toLowerCase();
    return worldInfos.where((w) {
      final matchesScope = switch (_scopeFilter) {
        _LorebookListScope.all => true,
        _LorebookListScope.global => w.isGlobal,
        _LorebookListScope.local => !w.isGlobal,
      };
      if (!matchesScope) return false;
      if (query.isEmpty) return true;
      final name = w.name.toLowerCase();
      final description = (w.description ?? '').toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList();
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.searchLorebooks,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : ChromeIconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildScopeFilter(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<_LorebookListScope>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: _LorebookListScope.all,
              label: Text(l10n.allLabel),
              tooltip: l10n.allLabel,
            ),
            ButtonSegment(
              value: _LorebookListScope.global,
              label: Text(l10n.globalScope),
              tooltip: l10n.globalScope,
            ),
            ButtonSegment(
              value: _LorebookListScope.local,
              label: Text(l10n.localScope),
              tooltip: l10n.localScope,
            ),
          ],
          selected: {_scopeFilter},
          onSelectionChanged: (next) {
            if (next.isEmpty) return;
            setState(() => _scopeFilter = next.first);
          },
        ),
      ),
    );
  }

  Widget _buildGroupedList(
    List<WorldInfo> filtered,
    Map<String, int> entryCounts,
    Map<String, String> characterNames,
  ) {
    final showSections = _scopeFilter == _LorebookListScope.all;
    final global = filtered.where((w) => w.isGlobal).toList();
    final local = filtered.where((w) => !w.isGlobal).toList();

    final rows = <Widget>[];
    void addSection(String title, List<WorldInfo> books) {
      if (books.isEmpty) return;
      if (showSections) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(
              top: rows.isEmpty ? 0 : 8,
              bottom: 8,
            ),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        );
      }
      for (final worldInfo in books) {
        rows.add(
          _WorldInfoCard(
            worldInfo: worldInfo,
            entryCount: entryCounts[worldInfo.id] ?? worldInfo.entries.length,
            characterName: worldInfo.characterId == null
                ? null
                : characterNames[worldInfo.characterId!],
            onTap: () => _openWorldInfo(worldInfo),
            onEdit: () => _showEditDialog(worldInfo),
            onDelete: () => _showDeleteConfirmation(worldInfo),
            onToggle: (enabled) {
              ref.read(worldInfoNotifierProvider.notifier).updateWorldInfo(
                    worldInfo.copyWith(enabled: enabled),
                  );
            },
          ),
        );
      }
    }

    final l10n = AppLocalizations.of(context);
    if (showSections) {
      addSection(l10n.globalScope, global);
      addSection(l10n.localScope, local);
    } else if (_scopeFilter == _LorebookListScope.global) {
      addSection(l10n.globalScope, global);
    } else {
      addSection(l10n.localScope, local);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: rows,
    );
  }

  Widget _buildNoMatchesState(AppLocalizations l10n) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          l10n.noMatchingLorebooks,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: muted),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 64,
            color: muted,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noLorebooksYet,
            style: theme.textTheme.titleMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.lorebooksInjectContext,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add),
            label: Text(l10n.createLorebook),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    final preferGlobal = _scopeFilter != _LorebookListScope.local;
    showDialog(
      context: context,
      builder: (context) => _WorldInfoDialog(
        ref: ref,
        title: AppLocalizations.of(context).createLorebook,
        initialIsGlobal: preferGlobal,
        onSave: (name, description, isGlobal, characterId) async {
          _log(
              'Creating world info: name=$name, isGlobal=$isGlobal, characterId=$characterId');
          await ref.read(worldInfoNotifierProvider.notifier).createWorldInfo(
                name: name,
                description: description,
                isGlobal: isGlobal,
                characterId: characterId,
              );
        },
      ),
    );
  }

  void _showEditDialog(WorldInfo worldInfo) {
    showDialog(
      context: context,
      builder: (context) => _WorldInfoDialog(
        ref: ref,
        title: AppLocalizations.of(context).editGroup,
        initialName: worldInfo.name,
        initialDescription: worldInfo.description,
        initialIsGlobal: worldInfo.isGlobal,
        initialCharacterId: worldInfo.characterId,
        onSave: (name, description, isGlobal, characterId) async {
          _log(
              'Updating world info: name=$name, isGlobal=$isGlobal, characterId=$characterId');
          await ref.read(worldInfoNotifierProvider.notifier).updateWorldInfo(
                worldInfo.copyWith(
                  name: name,
                  description: description,
                  isGlobal: isGlobal,
                  characterId: characterId,
                ),
              );
        },
      ),
    );
  }

  void _showDeleteConfirmation(WorldInfo worldInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteGroup),
        content: Text(AppLocalizations.of(context)
            .deleteLorebookConfirmation(worldInfo.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(worldInfoNotifierProvider.notifier)
                  .deleteWorldInfo(worldInfo.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
  }

  void _openWorldInfo(WorldInfo worldInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorldInfoEntriesScreen(worldInfo: worldInfo),
      ),
    );
  }

  Future<void> _importWorldInfo(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      _log('Starting world info import...');

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        _log('No file selected');
        return;
      }

      final file = result.files.first;
      _log('Selected file: ${file.name}');
      String jsonString;

      if (file.bytes != null) {
        jsonString = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonString = await File(file.path!).readAsString();
      } else {
        throw Exception('Could not read file');
      }

      _log('File content length: ${jsonString.length} chars');

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _log('Parsed JSON keys: ${json.keys.toList()}');

      // Get world info name
      final name = json['name']?.toString() ??
          json['originalData']?['name']?.toString() ??
          file.name.replaceAll('.json', '');
      final description = json['description']?.toString();

      _log('Creating world info: $name');

      await ref.read(worldInfoNotifierProvider.notifier).createWorldInfo(
            name: name,
            description: description,
            isGlobal: json['isGlobal'] == true,
          );

      // Import entries with full ST field fidelity (position, constant,
      // order, probability, timed effects, recursion flags, role, ...)
      final createdWorldInfos =
          ref.read(worldInfoNotifierProvider).valueOrNull ?? [];
      final createdWorldInfo =
          createdWorldInfos.firstWhere((w) => w.name == name);

      final parsedEntries =
          WorldInfoImport.parseEntries(json, createdWorldInfo.id);
      _log(
          'Adding ${parsedEntries.length} entries to world info: ${createdWorldInfo.id}');

      for (final entry in parsedEntries) {
        try {
          final created =
              await ref.read(worldInfoNotifierProvider.notifier).addEntry(
                    worldInfoId: createdWorldInfo.id,
                    keys: entry.keys,
                    content: entry.content,
                    comment: entry.comment,
                    secondaryKeys: entry.secondaryKeys,
                    position: entry.position,
                    constant: entry.constant,
                    selective: entry.selective,
                    insertionOrder: entry.insertionOrder,
                  );
          // Apply the remaining behavioral fields the addEntry API
          // doesn't accept directly
          await ref.read(worldInfoNotifierProvider.notifier).updateEntry(
                entry.copyWith(id: created.id),
              );
        } catch (e, st) {
          _log('Failed to add entry: ${entry.keys}',
              error: e.toString(), stackTrace: st);
        }
      }

      _log('Import completed successfully');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n!.importedAndApplied(name))),
        );
      }
    } catch (e, st) {
      _log('Import failed', error: e.toString(), stackTrace: st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${AppLocalizations.of(context)!.importFailed(e.toString())}')),
        );
      }
    }
  }
}

/// Card widget for displaying a World Info
class _WorldInfoCard extends StatelessWidget {
  final WorldInfo worldInfo;
  final int entryCount;
  final String? characterName;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _WorldInfoCard({
    required this.worldInfo,
    required this.entryCount,
    this.characterName,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final accent = worldInfo.enabled ? scheme.primary : muted;
    final l10n = AppLocalizations.of(context);
    final scopeLabel =
        worldInfo.isGlobal ? l10n.globalScope : l10n.localScope;
    final scopeColor =
        worldInfo.isGlobal ? scheme.secondary : scheme.tertiary;
    final boundLabel = characterName?.trim().isNotEmpty == true
        ? characterName!
        : (worldInfo.characterId != null
            ? l10n.specificCharacter
            : l10n.allCharactersAvailable);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.auto_stories, color: accent),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            worldInfo.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scopeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            scopeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: scopeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      worldInfo.isGlobal
                          ? l10n.entriesCount(entryCount)
                          : '${l10n.entriesCount(entryCount)} · $boundLabel',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: muted,
                      ),
                    ),
                    if (worldInfo.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        worldInfo.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              ThemedSwitch(
                value: worldInfo.enabled,
                onChanged: onToggle,
              ),
              AdaptiveActionMenuButton<String>(
                icon: Icon(Icons.more_vert, color: muted),
                title: worldInfo.name,
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'export':
                      _exportWorldInfo(context, worldInfo);
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return [
                    AdaptiveActionDrawerItem(
                      value: 'edit',
                      leading: const Icon(Icons.edit),
                      title: Text(l10n.edit),
                    ),
                    AdaptiveActionDrawerItem(
                      value: 'export',
                      leading: const Icon(Icons.file_upload),
                      title: Text(l10n.export),
                    ),
                    AdaptiveActionDrawerItem(
                      value: 'delete',
                      leading: const Icon(Icons.delete),
                      title: Text(l10n.delete),
                      destructive: true,
                      showDividerAbove: true,
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _exportWorldInfo(
      BuildContext context, WorldInfo worldInfo) async {
    final shareOrigin = sharePositionOrigin(context);
    try {
      final json = worldInfo.toJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(json);

      final tempDir = await getTemporaryDirectory();
      final fileName =
          '${worldInfo.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        subject: 'NativeTavern World Info: ${worldInfo.name}',
        sharePositionOrigin: shareOrigin,
      ));
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n!.exportFailed(e.toString()))),
        );
      }
    }
  }
}

/// Dialog for creating/editing World Info
class _WorldInfoDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialDescription;
  final bool initialIsGlobal;
  final String? initialCharacterId;
  final WidgetRef ref;
  final Future<void> Function(
          String name, String? description, bool isGlobal, String? characterId)
      onSave;

  const _WorldInfoDialog({
    required this.ref,
    required this.title,
    this.initialName,
    this.initialDescription,
    this.initialIsGlobal = true,
    this.initialCharacterId,
    required this.onSave,
  });

  @override
  State<_WorldInfoDialog> createState() => _WorldInfoDialogState();
}

/// Scope type for World Info
enum _WorldInfoScope {
  global, // Apply to all characters universally
  allCharacters, // Available to all characters (characterId = null)
  specificCharacter, // Bound to a specific character
}

class _WorldInfoDialogState extends State<_WorldInfoDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late _WorldInfoScope _scope;
  String? _selectedCharacterId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialDescription ?? '');

    // Determine initial scope
    if (widget.initialIsGlobal) {
      _scope = _WorldInfoScope.global;
    } else if (widget.initialCharacterId != null) {
      _scope = _WorldInfoScope.specificCharacter;
      _selectedCharacterId = widget.initialCharacterId;
    } else {
      _scope = _WorldInfoScope.allCharacters;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Get character list from provider
    final charactersAsync = widget.ref.watch(characterListProvider);

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.name,
                hintText: l10n.enterLorebookName,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.description,
                hintText: l10n.optionalDescriptionHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Scope selection
            Text(
              l10n.scope,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),

            // Global scope option
            RadioListTile<_WorldInfoScope>(
              title: Text(l10n.globalScope),
              subtitle: Text(l10n.applyToAllChats),
              value: _WorldInfoScope.global,
              groupValue: _scope,
              onChanged: (value) => setState(() {
                _scope = value!;
                _selectedCharacterId = null;
              }),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),

            // All characters option
            RadioListTile<_WorldInfoScope>(
              title: Text(l10n.allCharactersAvailable),
              subtitle: Text(l10n.availableToAllCharactersNotGlobal),
              value: _WorldInfoScope.allCharacters,
              groupValue: _scope,
              onChanged: (value) => setState(() {
                _scope = value!;
                _selectedCharacterId = null;
              }),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),

            // Specific character option
            RadioListTile<_WorldInfoScope>(
              title: Text(l10n.specificCharacter),
              subtitle: Text(l10n.linkToSpecificCharacter),
              value: _WorldInfoScope.specificCharacter,
              groupValue: _scope,
              onChanged: (value) => setState(() {
                _scope = value!;
              }),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),

            // Character dropdown (when specific character is selected)
            if (_scope == _WorldInfoScope.specificCharacter)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: charactersAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stack) => Text('${l10n.error}: $error'),
                  data: (characters) {
                    if (characters.isEmpty) {
                      return Text(
                        l10n.noCharactersAvailable,
                        style: const TextStyle(color: Colors.grey),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedCharacterId,
                      decoration: InputDecoration(
                        labelText: l10n.selectCharacter,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      items: characters.map((char) {
                        return DropdownMenuItem(
                          value: char.id,
                          child: Text(char.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCharacterId = value);
                        _log('Selected character: $value');
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterName2)),
      );
      return;
    }

    // Validate character selection if specific character is chosen
    if (_scope == _WorldInfoScope.specificCharacter &&
        _selectedCharacterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectCharacter)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Determine values based on scope
      final isGlobal = _scope == _WorldInfoScope.global;
      final characterId = _scope == _WorldInfoScope.specificCharacter
          ? _selectedCharacterId
          : null;

      _log(
          'Saving world info: name=$name, scope=$_scope, isGlobal=$isGlobal, characterId=$characterId');

      await widget.onSave(
        name,
        _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isGlobal,
        characterId,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}

/// Screen for managing entries within a World Info
class WorldInfoEntriesScreen extends ConsumerStatefulWidget {
  final WorldInfo worldInfo;

  const WorldInfoEntriesScreen({super.key, required this.worldInfo});

  @override
  ConsumerState<WorldInfoEntriesScreen> createState() =>
      _WorldInfoEntriesScreenState();
}

class _WorldInfoEntriesScreenState
    extends ConsumerState<WorldInfoEntriesScreen> {
  late WorldInfo _worldInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _worldInfo = widget.worldInfo;
    _loadWorldInfo();
  }

  Future<void> _loadWorldInfo() async {
    final updated = await ref
        .read(worldInfoRepositoryProvider)
        .getWorldInfoById(widget.worldInfo.id);
    if (!mounted || updated == null) return;
    setState(() {
      _worldInfo = updated;
      _isLoading = false;
    });
  }

  void _refreshWorldInfo() => _loadWorldInfo();

  @override
  Widget build(BuildContext context) {
    // Listen to changes
    ref.listen(worldInfoNotifierProvider, (previous, next) {
      _refreshWorldInfo();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_worldInfo.name),
        actions: [
          ChromeIconButton(density: ChromeIconButtonDensity.compact, 
            icon: const Icon(Icons.add),
            tooltip: AppLocalizations.of(context)!.addEntry,
            onPressed: () => _showEntryDialog(context, ref, null),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _worldInfo.entries.isEmpty
          ? _buildEmptyState(context)
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              buildDefaultDragHandles: false,
              itemCount: _worldInfo.entries.length,
              onReorder: (oldIndex, newIndex) {
                // TODO: Implement reordering
              },
              itemBuilder: (context, index) {
                final entry = _worldInfo.entries[index];
                return _WorldInfoEntryCard(
                  key: ValueKey(entry.id),
                  entry: entry,
                  onTap: () => _showEntryDialog(context, ref, entry),
                  onDelete: () =>
                      _showDeleteEntryConfirmation(context, ref, entry),
                  onToggle: (enabled) {
                    ref.read(worldInfoNotifierProvider.notifier).updateEntry(
                          entry.copyWith(enabled: enabled),
                        );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 64,
            color: muted,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noEntriesYet,
            style: theme.textTheme.titleMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.addEntriesWithKeywords,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showEntryDialog(context, ref, null),
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.addEntry),
          ),
        ],
      ),
    );
  }

  void _showEntryDialog(
      BuildContext context, WidgetRef ref, WorldInfoEntry? entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorldInfoEntryEditorScreen(
          worldInfoId: _worldInfo.id,
          entry: entry,
        ),
      ),
    );
  }

  void _showDeleteEntryConfirmation(
      BuildContext context, WidgetRef ref, WorldInfoEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteEntry),
        content: Text(AppLocalizations.of(context)!
            .deleteEntryConfirmation(entry.keys.join(", "))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(worldInfoNotifierProvider.notifier)
                  .deleteEntry(entry.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }
}

/// Card widget for displaying a World Info Entry
class _WorldInfoEntryCard extends StatelessWidget {
  final WorldInfoEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _WorldInfoEntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
    required this.onToggle,
  });

  void _copyToClipboard(BuildContext context) {
    final text = 'Keys: ${entry.keys.join(", ")}\n'
        '${entry.comment.isNotEmpty ? "Comment: ${entry.comment}\n" : ""}'
        'Content: ${entry.content}';
    Clipboard.setData(ClipboardData(text: text));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l10n!.copiedToClipboard}: ${entry.keys.join(", ")}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _copyToClipboard(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: entry.keys
                          .map((key) => Chip(
                                label: Text(key,
                                    style: const TextStyle(fontSize: 12)),
                                backgroundColor:
                                    scheme.primary.withValues(alpha: 0.2),
                                side: BorderSide.none,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
                  ),
                  ChromeIconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => _copyToClipboard(context),
                    tooltip: l10n.copiedToClipboard,
                  ),
                  ThemedSwitch(
                    value: entry.enabled,
                    onChanged: onToggle,
                  ),
                  ChromeIconButton(
                    icon: Icon(Icons.delete_outline, color: scheme.error),
                    onPressed: onDelete,
                  ),
                ],
              ),
              if (entry.comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  entry.comment,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                entry.content,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (entry.constant || entry.selective) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (entry.constant)
                      _buildBadge(l10n.constant, scheme.tertiary),
                    if (entry.selective)
                      _buildBadge(l10n.selective, scheme.secondary),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Dialog for creating/editing World Info Entry
class _WorldInfoEntryDialog extends StatefulWidget {
  final String title;
  final WorldInfoEntry? entry;
  final Future<void> Function(
    List<String> keys,
    String content,
    String comment,
    List<String> secondaryKeys,
    WorldInfoPosition position,
    bool constant,
    bool selective,
    int insertionOrder,
  ) onSave;

  const _WorldInfoEntryDialog({
    required this.title,
    this.entry,
    required this.onSave,
  });

  @override
  State<_WorldInfoEntryDialog> createState() => _WorldInfoEntryDialogState();
}

class _WorldInfoEntryDialogState extends State<_WorldInfoEntryDialog> {
  late TextEditingController _keysController;
  late TextEditingController _secondaryKeysController;
  late TextEditingController _contentController;
  late TextEditingController _commentController;
  late TextEditingController _orderController;
  late WorldInfoPosition _position;
  late bool _constant;
  late bool _selective;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _keysController = TextEditingController(
      text: widget.entry?.keys.join(', ') ?? '',
    );
    _secondaryKeysController = TextEditingController(
      text: widget.entry?.secondaryKeys.join(', ') ?? '',
    );
    _contentController = TextEditingController(
      text: widget.entry?.content ?? '',
    );
    _commentController = TextEditingController(
      text: widget.entry?.comment ?? '',
    );
    _orderController = TextEditingController(
      text: widget.entry?.insertionOrder.toString() ?? '0',
    );
    _position = widget.entry?.position ?? WorldInfoPosition.before;
    // Default constant to true for new entries (entries without keys are always included)
    _constant = widget.entry?.constant ?? true;
    _selective = widget.entry?.selective ?? false;
  }

  @override
  void dispose() {
    _keysController.dispose();
    _secondaryKeysController.dispose();
    _contentController.dispose();
    _commentController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  String _getPositionLabel(BuildContext context, WorldInfoPosition position) {
    final l10n = AppLocalizations.of(context)!;
    switch (position) {
      case WorldInfoPosition.before:
        return l10n.beforeCharacterDefinition; // ↑Char
      case WorldInfoPosition.after:
        return l10n.afterCharacterDefinition; // ↓Char
      case WorldInfoPosition.ANTop:
        return l10n.beforeAuthorNote; // ↑AT
      case WorldInfoPosition.ANBottom:
        return l10n.afterAuthorNote; // ↓AT
      case WorldInfoPosition.atDepth:
        return l10n.atDepth; // @D
      case WorldInfoPosition.EMTop:
        return l10n.beforeExampleMessages; // ↑EM
      case WorldInfoPosition.EMBottom:
        return l10n.afterExampleMessages; // ↓EM
      case WorldInfoPosition.outlet:
        return 'Outlet'; // Named outlet
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _keysController,
                decoration: InputDecoration(
                  labelText: l10n.keywordsCommaSeparated,
                  hintText: l10n.keywordsHint,
                  border: const OutlineInputBorder(),
                  helperText: l10n.entryActivatesWhenKeywordFound,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _secondaryKeysController,
                decoration: InputDecoration(
                  labelText: l10n.secondaryKeysOptional,
                  hintText: l10n.secondaryKeysHint,
                  border: const OutlineInputBorder(),
                  helperText: l10n.bothPrimaryAndSecondaryMustMatch,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  labelText: l10n.commentOptional,
                  hintText: l10n.noteForThisEntry,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: l10n.contentLabel,
                  hintText: l10n.contextToInjectWhenMatches,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
              ),
              const SizedBox(height: 16),
              // Position dropdown
              DropdownButtonFormField<WorldInfoPosition>(
                value: _position,
                decoration: InputDecoration(
                  labelText: l10n.insertionPosition,
                  border: const OutlineInputBorder(),
                ),
                items: WorldInfoPosition.values.map((pos) {
                  return DropdownMenuItem(
                    value: pos,
                    child: Text(_getPositionLabel(context, pos)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _position = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              // Insertion order
              TextField(
                controller: _orderController,
                decoration: InputDecoration(
                  labelText: l10n.insertionOrder,
                  hintText: '0',
                  border: const OutlineInputBorder(),
                  helperText: l10n.lowerOrderInsertsFirst,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              // Constant switch
              SwitchListTile(
                title: Text(l10n.constant),
                subtitle: Text(l10n.alwaysIncludeInPrompt),
                value: _constant,
                onChanged: (value) => setState(() => _constant = value),
                contentPadding: EdgeInsets.zero,
              ),
              // Selective switch
              SwitchListTile(
                title: Text(l10n.selective),
                subtitle: Text(l10n.requiresSecondaryKey),
                value: _selective,
                onChanged: (value) => setState(() => _selective = value),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final keys = _keysController.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    // Keys are optional - entries without keys are treated as constant (always included)
    // No validation needed for keys

    final content = _contentController.text.trim();
    if (content.isEmpty) {
      final message = l10n.pleaseEnterContent;
      _log('Validation failed: $message');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    final secondaryKeys = _secondaryKeysController.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    final insertionOrder = int.tryParse(_orderController.text.trim()) ?? 0;

    // If no keys provided, force constant to true
    final actualConstant = keys.isEmpty ? true : _constant;

    setState(() => _isSaving = true);

    _log(
        'Saving entry: keys=$keys, constant=$actualConstant, selective=$_selective, position=$_position');

    try {
      await widget.onSave(
        keys,
        content,
        _commentController.text.trim(),
        secondaryKeys,
        _position,
        actualConstant,
        _selective,
        insertionOrder,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e, st) {
      _log('Failed to save entry', error: e.toString(), stackTrace: st);
      if (mounted) {
        final message = '${l10n.error}: $e';
        _log('Showing error: $message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
