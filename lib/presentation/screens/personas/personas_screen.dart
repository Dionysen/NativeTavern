import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_tavern/data/models/persona.dart';
import 'package:native_tavern/data/models/tag.dart';
import 'package:native_tavern/presentation/providers/persona_providers.dart';
import 'package:native_tavern/presentation/screens/personas/persona_editor_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:native_tavern/presentation/theme/zephyr_chat_chrome.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/utils/destructive_confirm.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_action_drawer.dart';

/// Screen for managing user personas
class PersonasScreen extends ConsumerWidget {
  const PersonasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personasAsync = ref.watch(personaNotifierProvider);
    final activePersonaAsync = ref.watch(activePersonaProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.personas),
        actions: [
          ChromeIconButton(
            icon: const Icon(Icons.add),
            tooltip: AppLocalizations.of(context)!.createPersona,
            onPressed: () => _showCreatePersonaDialog(context, ref),
          ),
        ],
      ),
      body: personasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('${AppLocalizations.of(context).error}: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(personaNotifierProvider.notifier).refresh(),
                child: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        ),
        data: (personas) {
          if (personas.isEmpty) {
            return _buildEmptyState(context, ref);
          }

          final activePersona = activePersonaAsync.valueOrNull;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: personas.length,
            itemBuilder: (context, index) {
              final persona = personas[index];
              final isActive = activePersona?.id == persona.id;

              return _PersonaCard(
                persona: persona,
                isActive: isActive,
                onTap: () => _setActivePersona(ref, persona.id),
                onEdit: () => _showEditPersonaDialog(context, ref, persona),
                onDelete: persona.isDefault
                    ? null
                    : () => _showDeleteConfirmation(context, ref, persona),
                onSetDefault: persona.isDefault
                    ? null
                    : () => _setDefaultPersona(ref, persona.id),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 64,
            color: muted,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noPersonasYet,
            style: theme.textTheme.titleMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.createPersonaDescription,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 24),
          ZephyrChatChrome.withComposerShadow(
            context: context,
            child: ElevatedButton.icon(
              onPressed: () => _showCreatePersonaDialog(context, ref),
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context)!.createPersona),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePersonaDialog(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PersonaEditorScreen(),
      ),
    );
  }

  void _showEditPersonaDialog(
      BuildContext context, WidgetRef ref, Persona persona) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonaEditorScreen(persona: persona),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context, WidgetRef ref, Persona persona) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructiveAction(
      context,
      ref,
      title: l10n.deletePersona,
      body: l10n.deletePersonaConfirmation(persona.name),
    );
    if (!confirmed) return;

    ref.read(personaNotifierProvider.notifier).deletePersona(persona.id);
  }

  void _setActivePersona(WidgetRef ref, String id) {
    ref.read(personaNotifierProvider.notifier).setActivePersona(id);
  }

  void _setDefaultPersona(WidgetRef ref, String id) {
    ref.read(personaNotifierProvider.notifier).setDefaultPersona(id);
  }
}

/// Card widget for displaying a persona
class _PersonaCard extends StatelessWidget {
  final Persona persona;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSetDefault;

  const _PersonaCard({
    required this.persona,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
    this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final metaStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      height: 1.3,
      color: muted,
    );
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isActive
          ? scheme.primary.withValues(alpha: 0.15)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildAvatar(scheme),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            persona.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (persona.isDefault)
                          _statusBadge(
                            l10n.default_,
                            scheme.secondary,
                          ),
                        if (isActive && !persona.isDefault)
                          _statusBadge(
                            l10n.active,
                            scheme.primary,
                          ),
                      ],
                    ),
                    if (persona.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        persona.description,
                        style: metaStyle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (persona.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: persona.tags
                            .map((tag) {
                              final color = TagColors.forLabel(tag);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: metaStyle?.copyWith(
                                    color: color.withValues(alpha: 0.65),
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AdaptiveActionMenuButton<String>(
                icon: Icon(Icons.more_vert, color: muted),
                title: persona.name,
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'delete':
                      onDelete?.call();
                      break;
                    case 'default':
                      onSetDefault?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  AdaptiveActionDrawerItem(
                    value: 'edit',
                    leading: const Icon(Icons.edit),
                    title: Text(l10n.edit),
                  ),
                  if (onSetDefault != null)
                    AdaptiveActionDrawerItem(
                      value: 'default',
                      leading: const Icon(Icons.star),
                      title: Text(l10n.setAsDefault),
                    ),
                  if (onDelete != null)
                    AdaptiveActionDrawerItem(
                      value: 'delete',
                      leading: const Icon(Icons.delete),
                      title: Text(l10n.delete),
                      destructive: true,
                      showDividerAbove: onSetDefault != null,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAvatar(ColorScheme scheme) {
    if (persona.avatarPath != null) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: FileImage(File(persona.avatarPath!)),
      );
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: scheme.primary.withValues(alpha: 0.2),
      child: Text(
        persona.name.isNotEmpty ? persona.name[0].toUpperCase() : 'U',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: scheme.primary,
        ),
      ),
    );
  }
}

/// Dialog for creating/editing a persona
class _PersonaDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialDescription;
  final String? initialAvatarPath;
  final Future<void> Function(
      String name, String description, String? avatarPath) onSave;

  const _PersonaDialog({
    required this.title,
    this.initialName,
    this.initialDescription,
    this.initialAvatarPath,
    required this.onSave,
  });

  @override
  State<_PersonaDialog> createState() => _PersonaDialogState();
}

class _PersonaDialogState extends State<_PersonaDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  String? _avatarPath;
  bool _isSaving = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialDescription ?? '');
    _avatarPath = widget.initialAvatarPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Check if running on desktop platform
  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar picker
            _buildAvatarPicker(),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.name,
                hintText: AppLocalizations.of(context)!.enterPersonaName,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.description,
                hintText: AppLocalizations.of(context)!.describePersona,
                border: const OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.personaDescriptionHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context)!.save),
        ),
      ],
    );
  }

  Widget _buildAvatarPicker() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _showAvatarOptions,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: scheme.primary.withValues(alpha: 0.2),
              backgroundImage:
                  _avatarPath != null ? FileImage(File(_avatarPath!)) : null,
              child: _avatarPath == null
                  ? Icon(
                      Icons.person,
                      size: 50,
                      color: scheme.primary,
                    )
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _showAvatarOptions,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.surface,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: 18,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAvatarOptions() {
    // On desktop, directly open file picker
    if (_isDesktop) {
      _pickImageFromFiles();
      return;
    }

    // On mobile, show options sheet
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.photo_library, color: scheme.primary),
              title: Text(AppLocalizations.of(context)!.chooseFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: scheme.secondary),
              title: Text(AppLocalizations.of(context)!.takePhoto),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            if (_avatarPath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(AppLocalizations.of(context)!.removeAvatar,
                    style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _avatarPath = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Pick image from files using FilePicker (for desktop)
  Future<void> _pickImageFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        dialogTitle: 'Select Avatar Image',
      );

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null) {
        await _saveAvatarImage(result.files.first.path!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .failedToPickImage(e.toString()))),
        );
      }
    }
  }

  /// Pick image from gallery (for mobile)
  Future<void> _pickImageFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        await _saveAvatarImage(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .failedToPickImage(e.toString()))),
        );
      }
    }
  }

  /// Take photo with camera (for mobile)
  Future<void> _takePhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        await _saveAvatarImage(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .failedToTakePhoto(e.toString()))),
        );
      }
    }
  }

  /// Save avatar image to app's documents directory
  Future<void> _saveAvatarImage(String sourcePath) async {
    try {
      // Copy file to app's documents directory for persistence
      final appDir = await getApplicationDocumentsDirectory();
      final avatarsDir =
          Directory(p.join(appDir.path, 'NativeTavern', 'avatars', 'personas'));
      await avatarsDir.create(recursive: true);

      const uuid = Uuid();
      final extension = p.extension(sourcePath);
      final newFileName = '${uuid.v4()}$extension';
      final newPath = p.join(avatarsDir.path, newFileName);

      // Copy file
      final sourceFile = File(sourcePath);
      await sourceFile.copy(newPath);

      setState(() {
        _avatarPath = newPath;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .failedToSaveAvatar(e.toString()))),
        );
      }
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterName)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.onSave(
          name, _descriptionController.text.trim(), _avatarPath);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.error}: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
