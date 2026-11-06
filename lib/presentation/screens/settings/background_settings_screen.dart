import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../data/models/chat_background.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/background_providers.dart';
import '../../providers/settings_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/native_tavern_theme.dart';
import '../../theme/zephyr_chat_chrome.dart';
import '../../widgets/chat/chat_background_widget.dart';
import '../../widgets/settings/theme_color_picker.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';

/// Screen for managing chat backgrounds
class BackgroundSettingsScreen extends ConsumerStatefulWidget {
  final String? characterId; // If set, editing character-specific background

  const BackgroundSettingsScreen({super.key, this.characterId});

  @override
  ConsumerState<BackgroundSettingsScreen> createState() =>
      _BackgroundSettingsScreenState();
}

class _BackgroundSettingsScreenState
    extends ConsumerState<BackgroundSettingsScreen> {
  late ChatBackground _currentBackground;
  bool _isLoading = false;

  /// Background gallery (ST 1.17 Background Folders)
  List<_GalleryImage> _galleryImages = [];
  String? _selectedFolder; // null = all folders
  List<String> _galleryFolders = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentBackground();
    _loadGallery();
  }

  Future<Directory> _backgroundsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final bgDir = Directory(p.join(appDir.path, 'NativeTavern', 'backgrounds'));
    await bgDir.create(recursive: true);
    return bgDir;
  }

  Future<void> _loadGallery() async {
    try {
      final bgDir = await _backgroundsDir();
      final images = <_GalleryImage>[];
      final folders = <String>{};

      await for (final entity in bgDir.list(recursive: true)) {
        if (entity is File && _isImageFile(entity.path)) {
          final relative = p.relative(entity.path, from: bgDir.path);
          final folder =
              p.dirname(relative) == '.' ? '' : p.split(relative).first;
          if (folder.isNotEmpty) folders.add(folder);
          images.add(_GalleryImage(
            path: entity.path,
            folder: folder,
            modified: (await entity.stat()).modified,
          ));
        }
      }

      // Newest first
      images.sort((a, b) => b.modified.compareTo(a.modified));

      if (mounted) {
        setState(() {
          _galleryImages = images;
          _galleryFolders = folders.toList()..sort();
        });
      }
    } catch (_) {
      // Gallery is best-effort; ignore scan errors
    }
  }

  bool _isImageFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return const ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp']
        .contains(ext);
  }

  void _loadCurrentBackground() {
    if (widget.characterId != null) {
      final charBg = ref.read(characterBackgroundProvider(widget.characterId!));
      _currentBackground = charBg ?? ChatBackground.none;
    } else {
      _currentBackground = ref.read(globalBackgroundProvider);
    }
  }

  Future<void> _saveBackground(ChatBackground background) async {
    // Color / gradient and image are mutually exclusive via [BackgroundType].
    setState(() => _currentBackground = background);

    if (widget.characterId != null) {
      await ref
          .read(characterBackgroundProvider(widget.characterId!).notifier)
          .setBackground(background);
    } else {
      await ref
          .read(globalBackgroundProvider.notifier)
          .setBackground(background);
      // Color/gradient should win over "character image as background".
      if (background.type == BackgroundType.color ||
          background.type == BackgroundType.gradient) {
        final useAvatar = ref.read(
          appSettingsProvider.select((s) => s.useCharacterAvatarAsBackground),
        );
        if (useAvatar) {
          ref
              .read(appSettingsProvider.notifier)
              .updateUseCharacterAvatarAsBackground(false);
        }
      }
    }
  }

  ChatBackground _withBubbleOpacity(ChatBackground bg) {
    return bg.copyWith(bubbleOpacity: _currentBackground.bubbleOpacity);
  }

  Future<void> _updateBubbleOpacity(double value) async {
    await _saveBackground(
      _currentBackground.copyWith(bubbleOpacity: value),
    );
  }

  Future<void> _pickCustomFill() async {
    final l10n = AppLocalizations.of(context);
    final next = await showDialog<ChatBackground>(
      context: context,
      builder: (context) => _CustomBackgroundFillDialog(
        initial: _currentBackground,
        title: l10n.customBackgroundFill,
        cancelLabel: l10n.cancel,
        doneLabel: l10n.done,
      ),
    );
    if (next == null || !mounted) return;
    await _saveBackground(_withBubbleOpacity(next));
  }

  static String _hexOf(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color _parseHexColor(String hexColor) {
    var hex = hexColor.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCharacterSpecific = widget.characterId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCharacterSpecific
            ? l10n.characterBackground
            : l10n.chatBackground),
        actions: [
          if (_currentBackground.type != BackgroundType.none)
            ChromeIconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.clearBackground,
              onPressed: () => _saveBackground(ChatBackground.none),
            ),
        ],
      ),
      body: SettingsPageBody(
        children: [
          // Character Avatar Background Setting (only for global settings)
          if (!isCharacterSpecific) ...[
            _buildCharacterAvatarSetting(),
            const SizedBox(height: 24),
          ],

          // Preview
          _buildPreviewSection(),
          const SizedBox(height: 24),

          // Color + gradient presets (one group) and custom fill
          _buildSectionHeader(l10n.colorAndGradientPresets),
          const SizedBox(height: 8),
          _buildFillPresets(),
          const SizedBox(height: 8),
          Text(
            l10n.backgroundColorImageMutexHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),

          // Custom image (mutually exclusive with color/gradient)
          _buildSectionHeader(l10n.customImage),
          const SizedBox(height: 8),
          _buildImageSection(),
          const SizedBox(height: 24),

          // Background gallery with virtual folders
          if (_galleryImages.isNotEmpty) ...[
            _buildSectionHeader(AppLocalizations.of(context).gallery),
            const SizedBox(height: 8),
            _buildGallerySection(),
            const SizedBox(height: 24),
          ],

          // Character-specific: bubble/input opacity lives here (global screen
          // already exposes it under image background settings).
          if (isCharacterSpecific &&
              _currentBackground.type != BackgroundType.none) ...[
            _buildSectionHeader(l10n.adjustments),
            const SizedBox(height: 8),
            _buildAdjustments(),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SettingsCategoryHeader(
      icon: Icons.palette_outlined,
      title: title,
    );
  }

  Widget _buildCharacterAvatarSetting() {
    final useCharacterAvatar = ref.watch(
        appSettingsProvider.select((s) => s.useCharacterAvatarAsBackground));
    final backgroundBlur =
        ref.watch(appSettingsProvider.select((s) => s.backgroundBlur));
    final bubbleBlur =
        ref.watch(appSettingsProvider.select((s) => s.bubbleBlur));
    final backgroundOpacity =
        ref.watch(appSettingsProvider.select((s) => s.backgroundOpacity));
    final l10n = AppLocalizations.of(context);

    return SettingsSection(
      icon: Icons.wallpaper,
      title: l10n.imageBackgroundSettings,
      footer: l10n.backgroundPriorityHint,
      children: [
        SettingsSwitchTile(
          icon: Icons.person_outline,
          title: l10n.useCharacterImageAsBackground,
          subtitle: l10n.useCharacterImageAsBackgroundHint,
          value: useCharacterAvatar,
          onChanged: (value) {
            ref
                .read(appSettingsProvider.notifier)
                .updateUseCharacterAvatarAsBackground(value);
          },
        ),
        SettingsSliderTile(
          icon: Icons.opacity,
          title: l10n.backgroundOpacity,
          subtitle: l10n.backgroundOpacityHint,
          value: backgroundOpacity,
          min: 0.1,
          max: 1.0,
          divisions: 18,
          valueLabel: '${(backgroundOpacity * 100).round()}%',
          onChanged: (value) {
            ref
                .read(appSettingsProvider.notifier)
                .updateBackgroundOpacity(value);
          },
        ),
        SettingsSliderTile(
          icon: Icons.chat_bubble_outline,
          title: l10n.bubbleOpacity,
          subtitle: l10n.bubbleOpacityHelp,
          value: _currentBackground.bubbleOpacity,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          valueLabel:
              '${(_currentBackground.bubbleOpacity * 100).round()}%',
          onChanged: _updateBubbleOpacity,
        ),
        SettingsSliderTile(
          icon: Icons.blur_circular,
          title: l10n.enableBubbleBlur,
          subtitle: l10n.enableBubbleBlurHint,
          value: bubbleBlur,
          min: 0,
          max: 100,
          divisions: 100,
          valueLabel: '${bubbleBlur.round()}',
          onChanged: (value) {
            ref.read(appSettingsProvider.notifier).updateBubbleBlur(value);
          },
        ),
        SettingsSliderTile(
          icon: Icons.blur_on,
          title: l10n.enableBackgroundBlur,
          subtitle: l10n.enableBackgroundBlurHint,
          value: backgroundBlur,
          min: 0,
          max: 100,
          divisions: 100,
          valueLabel: '${backgroundBlur.round()}',
          showDivider: false,
          onChanged: (value) {
            ref
                .read(appSettingsProvider.notifier)
                .updateBackgroundBlur(value);
          },
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    final scheme = Theme.of(context).colorScheme;
    final chatColors = context.appChatColors;
    final l10n = AppLocalizations.of(context);
    final hasBackground = _currentBackground.type != BackgroundType.none;
    final bubbleOpacity = _currentBackground.bubbleOpacity;

    Widget sampleBubble({required bool isUser, required String text}) {
      return Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: ZephyrChatChrome.messageBubbleDecoration(
            context,
            isUser: isUser,
            transparent: false,
            hasBackground: hasBackground,
            bubbleOpacity: bubbleOpacity,
            highlighted: false,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: ZephyrChatChrome.bubbleTextColor(context, isUser: isUser),
            ),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasBackground)
              _BackgroundPreviewFull(background: _currentBackground)
            else
              ColoredBox(
                color: chatColors.chatBackground,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wallpaper,
                          size: 48, color: scheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text(
                        l10n.noBackgroundSelected,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            // Sample bubbles use the same chrome as real chat.
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sampleBubble(isUser: false, text: l10n.sampleMessage1),
                  const SizedBox(height: 8),
                  sampleBubble(isUser: true, text: l10n.sampleMessage2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isCustomFillSelected {
    final bg = _currentBackground;
    if (bg.type == BackgroundType.color) {
      return !BackgroundPresets.isPresetColor(bg.color);
    }
    if (bg.type == BackgroundType.gradient) {
      // Presets are linear only; any radial or non-preset colors count as custom.
      if (bg.gradientStyle != BackgroundGradientStyle.linear) return true;
      return !BackgroundPresets.isPresetGradient(bg.gradientColors);
    }
    return false;
  }

  Widget _buildFillPresets() {
    final isCustomSelected = _isCustomFillSelected;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    const size = 60.0;
    const radius = 8.0;
    final borderWidth = isCustomSelected ? 3.0 : 1.0;

    Widget customTilePreview() {
      if (_currentBackground.type == BackgroundType.gradient &&
          isCustomSelected) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: backgroundFillGradient(_currentBackground),
          ),
          child: Icon(
            Icons.gradient,
            color: scheme.onSurface.withValues(alpha: 0.75),
          ),
        );
      }
      if (_currentBackground.type == BackgroundType.color &&
          isCustomSelected &&
          _currentBackground.color != null) {
        final color = _parseHexColor(_currentBackground.color!);
        return ColoredBox(
          color: color,
          child: Icon(
            Icons.colorize_outlined,
            color: _contrastIconColor(color),
          ),
        );
      }
      return ColoredBox(
        color: scheme.surfaceContainerHigh,
        child: Icon(
          Icons.colorize_outlined,
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        BackgroundPreview(
          background: ChatBackground.none,
          selected: _currentBackground.type == BackgroundType.none,
          onTap: () => _saveBackground(ChatBackground.none),
        ),
        ...BackgroundPresets.gradients.map((bg) => BackgroundPreview(
              background: bg,
              selected: _currentBackground.type == BackgroundType.gradient &&
                  _currentBackground.gradientStyle ==
                      BackgroundGradientStyle.linear &&
                  _currentBackground.gradientColors?.join(',') ==
                      bg.gradientColors?.join(','),
              onTap: () => _saveBackground(_withBubbleOpacity(bg)),
            )),
        ...BackgroundPresets.solidColors.map((bg) => BackgroundPreview(
              background: bg,
              selected: _currentBackground.type == BackgroundType.color &&
                  _currentBackground.color?.toUpperCase() ==
                      bg.color?.toUpperCase(),
              onTap: () => _saveBackground(_withBubbleOpacity(bg)),
            )),
        Tooltip(
          message: l10n.customBackgroundFill,
          child: GestureDetector(
            onTap: _pickCustomFill,
            child: SizedBox(
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: isCustomSelected
                        ? scheme.primary
                        : scheme.outline.withValues(alpha: 0.35),
                    width: borderWidth,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(borderWidth),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      (radius - borderWidth).clamp(0, radius),
                    ),
                    child: customTilePreview(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Color _contrastIconColor(Color bg) {
    return bg.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;
  }

  Widget _buildImageSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.image),
                label: Text(l10n.chooseImage),
                onPressed: _isLoading ? null : _pickImage,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.link),
                label: Text(l10n.fromUrl),
                onPressed: _isLoading ? null : _showUrlDialog,
              ),
            ),
          ],
        ),
        if (_currentBackground.type == BackgroundType.image) ...[
          const SizedBox(height: 12),
          Text(
            _currentBackground.imagePath != null
                ? l10n.localImage(p.basename(_currentBackground.imagePath!))
                : _currentBackground.imageUrl != null
                    ? l10n.urlLabel(_currentBackground.imageUrl!)
                    : l10n.noImage,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildAdjustments() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Bubble opacity slider
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline, size: 20),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context).bubbleOpacity),
                const SizedBox(width: 4),
                Tooltip(
                  message: AppLocalizations.of(context).bubbleOpacityHelp,
                  triggerMode: TooltipTriggerMode.tap,
                  child: const Icon(Icons.info_outline,
                      size: 16, color: AppTheme.textMuted),
                ),
                const Spacer(),
                Text('${(_currentBackground.bubbleOpacity * 100).round()}%'),
              ],
            ),
            Slider(
              value: _currentBackground.bubbleOpacity,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              onChanged: _updateBubbleOpacity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGallerySection() {
    final visibleImages = _selectedFolder == null
        ? _galleryImages
        : _galleryImages.where((i) => i.folder == _selectedFolder).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Folder filter chips
        if (_galleryFolders.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(AppLocalizations.of(context).allLabel),
                  selected: _selectedFolder == null,
                  onSelected: (_) => setState(() => _selectedFolder = null),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(AppLocalizations.of(context).ungrouped),
                  selected: _selectedFolder == '',
                  onSelected: (_) => setState(() => _selectedFolder = ''),
                ),
                for (final folder in _galleryFolders) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.folder, size: 16),
                    label: Text(folder),
                    selected: _selectedFolder == folder,
                    onSelected: (_) => setState(() => _selectedFolder = folder),
                  ),
                ],
              ],
            ),
          ),
        if (_galleryFolders.isNotEmpty) const SizedBox(height: 12),

        // Image grid with thumbnails
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.75,
          ),
          itemCount: visibleImages.length,
          itemBuilder: (context, index) {
            final image = visibleImages[index];
            final isActive = _currentBackground.imagePath == image.path;
            final borderWidth = isActive ? 2.0 : 0.0;
            return GestureDetector(
              onTap: () => _applyGalleryImage(image),
              onLongPress: () => _showGalleryImageOptions(image),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: isActive
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: borderWidth,
                        )
                      : null,
                ),
                child: Padding(
                  padding: EdgeInsets.all(borderWidth),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      (8 - borderWidth).clamp(0, 8),
                    ),
                    child: Image.file(
                      File(image.path),
                      fit: BoxFit.cover,
                      cacheWidth: 300,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.darkCard,
                        child: const Icon(Icons.broken_image,
                            color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _applyGalleryImage(_GalleryImage image) {
    final settings = ref.read(appSettingsProvider);
    final blurSigma = settings.backgroundBlurSigma;
    _saveBackground(ChatBackground.imagePath(
      image.path,
      opacity: settings.backgroundOpacity,
      blur: blurSigma > 0,
      blurAmount: blurSigma,
      bubbleOpacity: _currentBackground.bubbleOpacity,
    ));
  }

  void _showGalleryImageOptions(_GalleryImage image) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.wallpaper),
              title: Text(AppLocalizations.of(context).setAsBackground),
              onTap: () {
                Navigator.pop(context);
                _applyGalleryImage(image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: Text(AppLocalizations.of(context).moveToFolder),
              onTap: () {
                Navigator.pop(context);
                _showMoveToFolderDialog(image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(AppLocalizations.of(context).delete,
                  style: const TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _deleteGalleryImage(image);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMoveToFolderDialog(_GalleryImage image) async {
    final controller = TextEditingController(text: image.folder);
    final l10n = AppLocalizations.of(context);
    final folder = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.moveToFolder),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: l10n.folderName,
                hintText: l10n.folderNameHint,
              ),
              autofocus: true,
            ),
            if (_galleryFolders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _galleryFolders
                    .map((f) => ActionChip(
                          label: Text(f),
                          onPressed: () => Navigator.pop(context, f),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.move),
          ),
        ],
      ),
    );

    if (folder == null) return;

    try {
      final bgDir = await _backgroundsDir();
      final targetDir =
          folder.isEmpty ? bgDir : Directory(p.join(bgDir.path, folder));
      await targetDir.create(recursive: true);
      final newPath = p.join(targetDir.path, p.basename(image.path));
      if (newPath != image.path) {
        await File(image.path).rename(newPath);
        // Keep the active background pointing at the moved file
        if (_currentBackground.imagePath == image.path) {
          await _saveBackground(
              _currentBackground.copyWith(imagePath: newPath));
        }
      }
      await _loadGallery();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).moveFailed('$e'))));
      }
    }
  }

  Future<void> _deleteGalleryImage(_GalleryImage image) async {
    try {
      await File(image.path).delete();
      if (_currentBackground.imagePath == image.path) {
        await _saveBackground(ChatBackground.none);
      }
      await _loadGallery();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).deleteFailed('$e'))));
      }
    }
  }

  Future<void> _pickImage() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          // Copy to app directory (into the selected gallery folder, if any)
          final baseDir = await _backgroundsDir();
          final bgDir = (_selectedFolder == null || _selectedFolder!.isEmpty)
              ? baseDir
              : Directory(p.join(baseDir.path, _selectedFolder!));
          await bgDir.create(recursive: true);

          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          final destPath = p.join(bgDir.path, fileName);
          await File(file.path!).copy(destPath);
          await _loadGallery();

          final settings = ref.read(appSettingsProvider);
          final blurSigma = settings.backgroundBlurSigma;

          await _saveBackground(ChatBackground.imagePath(
            destPath,
            opacity: settings.backgroundOpacity,
            blur: blurSigma > 0,
            blurAmount: blurSigma,
            bubbleOpacity: _currentBackground.bubbleOpacity,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)
                  .failedToLoadImage(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showUrlDialog() {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.imageUrl),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.enterImageUrl,
            hintText: 'https://example.com/image.jpg',
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
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                final settings = ref.read(appSettingsProvider);
                final blurSigma = settings.backgroundBlurSigma;

                _saveBackground(ChatBackground.imageUrl(
                  url,
                  opacity: settings.backgroundOpacity,
                  blur: blurSigma > 0,
                  blurAmount: blurSigma,
                  bubbleOpacity: _currentBackground.bubbleOpacity,
                ));
                Navigator.pop(context);
              }
            },
            child: Text(l10n.apply),
          ),
        ],
      ),
    );
  }
}

/// A background image in the gallery
class _GalleryImage {
  final String path;
  final String folder; // '' = ungrouped (root directory)
  final DateTime modified;

  const _GalleryImage({
    required this.path,
    required this.folder,
    required this.modified,
  });
}

class _BackgroundPreviewFull extends StatelessWidget {
  final ChatBackground background;

  const _BackgroundPreviewFull({required this.background});

  @override
  Widget build(BuildContext context) {
    switch (background.type) {
      case BackgroundType.none:
        return ColoredBox(color: Theme.of(context).colorScheme.surface);

      case BackgroundType.color:
        return Container(color: _parseColor(background.color));

      case BackgroundType.gradient:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: backgroundFillGradient(background),
          ),
        );

      case BackgroundType.image:
        if (background.imagePath != null) {
          return Opacity(
            opacity: background.opacity,
            child: Image.file(
              File(background.imagePath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey[800]),
            ),
          );
        }
        if (background.imageUrl != null) {
          return Opacity(
            opacity: background.opacity,
            child: Image.network(
              background.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey[800]),
            ),
          );
        }
        return Container(color: Colors.grey[800]);
    }
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return Colors.transparent;
    }

    String hex = hexColor.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}

enum _FillMode { solid, gradient }

class _CustomBackgroundFillDialog extends StatefulWidget {
  const _CustomBackgroundFillDialog({
    required this.initial,
    required this.title,
    required this.cancelLabel,
    required this.doneLabel,
  });

  final ChatBackground initial;
  final String title;
  final String cancelLabel;
  final String doneLabel;

  @override
  State<_CustomBackgroundFillDialog> createState() =>
      _CustomBackgroundFillDialogState();
}

class _CustomBackgroundFillDialogState
    extends State<_CustomBackgroundFillDialog> {
  late _FillMode _mode;
  late BackgroundGradientStyle _style;
  late double _angle;
  late double _radius;
  late Color _solid;
  late Color _start;
  late Color _end;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial.type == BackgroundType.gradient &&
        (initial.gradientColors?.length ?? 0) >= 2) {
      _mode = _FillMode.gradient;
      _style = initial.gradientStyle;
      _angle = initial.gradientAngle ?? 180;
      _radius = initial.gradientRadius;
      _start = _parse(initial.gradientColors![0]);
      _end = _parse(initial.gradientColors![1]);
      _solid = _start;
    } else if (initial.type == BackgroundType.color && initial.color != null) {
      _mode = _FillMode.solid;
      _style = BackgroundGradientStyle.linear;
      _angle = 180;
      _radius = 1.05;
      _solid = _parse(initial.color!);
      _start = _solid;
      _end = Color.lerp(_solid, Colors.white, 0.35) ?? _solid;
    } else {
      _mode = _FillMode.solid;
      _style = BackgroundGradientStyle.linear;
      _angle = 180;
      _radius = 1.05;
      _solid = const Color(0xFF2A2A2A);
      _start = const Color(0xFF1A1A1A);
      _end = const Color(0xFF3A3A3A);
    }
  }

  static Color _parse(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  static String _hexOf(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  ChatBackground get _result {
    if (_mode == _FillMode.solid) {
      return ChatBackground.color(_hexOf(_solid));
    }
    return ChatBackground.gradient(
      [_hexOf(_start), _hexOf(_end)],
      angle: _angle,
      style: _style,
      radius: _radius,
    );
  }

  Future<void> _pickColor({
    required Color current,
    required ValueChanged<Color> onPicked,
  }) async {
    final l10n = AppLocalizations.of(context);
    final next = await showThemeColorPicker(
      context,
      initialColor: current,
      title: l10n.customBackgroundColor,
      cancelLabel: l10n.cancel,
      doneLabel: l10n.done,
    );
    if (next != null && mounted) onPicked(next);
  }

  Widget _colorChip({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = _result;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_FillMode>(
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                segments: [
                  ButtonSegment(
                    value: _FillMode.solid,
                    label: Text(l10n.solidFill),
                    icon: const Icon(Icons.square_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: _FillMode.gradient,
                    label: Text(l10n.gradientFill),
                    icon: const Icon(Icons.gradient, size: 16),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (next) {
                  if (next.isNotEmpty) setState(() => _mode = next.first);
                },
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 88,
                  child: preview.type == BackgroundType.gradient
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: backgroundFillGradient(preview),
                          ),
                        )
                      : ColoredBox(color: _solid),
                ),
              ),
              const SizedBox(height: 12),
              if (_mode == _FillMode.solid)
                _colorChip(
                  label: l10n.customBackgroundColor,
                  color: _solid,
                  onTap: () => _pickColor(
                    current: _solid,
                    onPicked: (c) => setState(() => _solid = c),
                  ),
                )
              else ...[
                SegmentedButton<BackgroundGradientStyle>(
                  showSelectedIcon: false,
                  expandedInsets: EdgeInsets.zero,
                  segments: [
                    ButtonSegment(
                      value: BackgroundGradientStyle.linear,
                      label: Text(l10n.linearGradient),
                    ),
                    ButtonSegment(
                      value: BackgroundGradientStyle.radial,
                      label: Text(l10n.radialGradient),
                    ),
                  ],
                  selected: {_style},
                  onSelectionChanged: (next) {
                    if (next.isNotEmpty) {
                      setState(() => _style = next.first);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (_style == BackgroundGradientStyle.linear) ...[
                  Text(
                    '${l10n.gradientDirection} · ${_angle.round()}°',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: _GradientAngleDial(
                      angle: _angle,
                      startColor: _start,
                      endColor: _end,
                      onChanged: (angle) => setState(() => _angle = angle),
                    ),
                  ),
                ] else ...[
                  Text(
                    '${l10n.gradientRadius} · ${_radius.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: _GradientRadiusDial(
                      radius: _radius,
                      startColor: _start,
                      endColor: _end,
                      onChanged: (radius) => setState(() => _radius = radius),
                    ),
                  ),
                  Slider(
                    value: _radius.clamp(0.2, 1.6),
                    min: 0.2,
                    max: 1.6,
                    divisions: 28,
                    label: _radius.toStringAsFixed(2),
                    onChanged: (value) => setState(() => _radius = value),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _colorChip(
                        label: l10n.gradientStartColor,
                        color: _start,
                        onTap: () => _pickColor(
                          current: _start,
                          onPicked: (c) => setState(() => _start = c),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _colorChip(
                        label: l10n.gradientEndColor,
                        color: _end,
                        onTap: () => _pickColor(
                          current: _end,
                          onPicked: (c) => setState(() => _end = c),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _result),
          child: Text(widget.doneLabel),
        ),
      ],
    );
  }
}

/// Drag the ring inward/outward (or use the slider) to set radial size.
class _GradientRadiusDial extends StatelessWidget {
  const _GradientRadiusDial({
    required this.radius,
    required this.startColor,
    required this.endColor,
    required this.onChanged,
  });

  final double radius;
  final Color startColor;
  final Color endColor;
  final ValueChanged<double> onChanged;

  static const double _size = 148;
  static const double _minRadius = 0.2;
  static const double _maxRadius = 1.6;

  void _updateFromLocal(Offset local) {
    final center = const Offset(_size / 2, _size / 2);
    final dist = (local - center).distance;
    // Map finger distance from center to gradient radius.
    final t = ((dist / (_size / 2)) * 1.15).clamp(0.0, 1.0);
    onChanged(_minRadius + t * (_maxRadius - _minRadius));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (d) => _updateFromLocal(d.localPosition),
      onPanUpdate: (d) => _updateFromLocal(d.localPosition),
      child: SizedBox(
        width: _size,
        height: _size,
        child: CustomPaint(
          painter: _GradientRadiusDialPainter(
            radius: radius.clamp(_minRadius, _maxRadius),
            startColor: startColor,
            endColor: endColor,
            trackColor: scheme.outlineVariant,
            ringColor: scheme.primary,
          ),
        ),
      ),
    );
  }
}

class _GradientRadiusDialPainter extends CustomPainter {
  _GradientRadiusDialPainter({
    required this.radius,
    required this.startColor,
    required this.endColor,
    required this.trackColor,
    required this.ringColor,
  });

  final double radius;
  final Color startColor;
  final Color endColor;
  final Color trackColor;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide / 2 - 4;
    final discRect = Rect.fromCircle(center: center, radius: maxR);

    canvas.drawCircle(
      center,
      maxR,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: radius,
          colors: [startColor, endColor],
        ).createShader(discRect),
    );
    canvas.drawCircle(
      center,
      maxR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = trackColor.withValues(alpha: 0.5),
    );

    // Guide for current radius (clamped to visible disc).
    final t = ((radius - 0.2) / (1.6 - 0.2)).clamp(0.0, 1.0);
    final guideR = (maxR * (0.2 + t * 0.8)).clamp(8.0, maxR - 2);
    canvas.drawCircle(
      center,
      guideR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = ringColor,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientRadiusDialPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.ringColor != ringColor;
  }
}

/// Rotary dial: 0° = top, clockwise. Drag around the ring to set angle.
class _GradientAngleDial extends StatelessWidget {
  const _GradientAngleDial({
    required this.angle,
    required this.startColor,
    required this.endColor,
    required this.onChanged,
  });

  final double angle;
  final Color startColor;
  final Color endColor;
  final ValueChanged<double> onChanged;

  static const double _size = 148;

  double _angleFromLocal(Offset local) {
    final center = const Offset(_size / 2, _size / 2);
    final delta = local - center;
    // atan2(x, -y): 0 at top, clockwise positive, matching backgroundAngleToAlignment.
    var deg = math.atan2(delta.dx, -delta.dy) * 180 / math.pi;
    if (deg < 0) deg += 360;
    return deg;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (details) => onChanged(_angleFromLocal(details.localPosition)),
      onPanUpdate: (details) =>
          onChanged(_angleFromLocal(details.localPosition)),
      child: SizedBox(
        width: _size,
        height: _size,
        child: CustomPaint(
          painter: _GradientAngleDialPainter(
            angle: angle,
            startColor: startColor,
            endColor: endColor,
            trackColor: scheme.outlineVariant,
            knobColor: scheme.primary,
            knobBorder: scheme.onPrimary,
          ),
        ),
      ),
    );
  }
}

class _GradientAngleDialPainter extends CustomPainter {
  _GradientAngleDialPainter({
    required this.angle,
    required this.startColor,
    required this.endColor,
    required this.trackColor,
    required this.knobColor,
    required this.knobBorder,
  });

  final double angle;
  final Color startColor;
  final Color endColor;
  final Color trackColor;
  final Color knobColor;
  final Color knobBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final ringRadius = radius - 10;
    final discRadius = radius - 22;

    // Soft disc showing current linear direction.
    final discRect = Rect.fromCircle(center: center, radius: discRadius);
    final rad = angle * math.pi / 180;
    final begin = Alignment(math.sin(rad), -math.cos(rad));
    final end = Alignment(math.sin(rad + math.pi), -math.cos(rad + math.pi));
    canvas.drawCircle(
      center,
      discRadius,
      Paint()
        ..shader = LinearGradient(
          begin: begin,
          end: end,
          colors: [startColor, endColor],
        ).createShader(discRect),
    );
    canvas.drawCircle(
      center,
      discRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = trackColor.withValues(alpha: 0.5),
    );

    // Outer track.
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = trackColor,
    );

    // Direction tick marks (every 45°).
    for (var i = 0; i < 8; i++) {
      final tickRad = i * 45 * math.pi / 180;
      final outer = Offset(
        center.dx + math.sin(tickRad) * (ringRadius + 4),
        center.dy - math.cos(tickRad) * (ringRadius + 4),
      );
      final inner = Offset(
        center.dx + math.sin(tickRad) * (ringRadius - 4),
        center.dy - math.cos(tickRad) * (ringRadius - 4),
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..strokeWidth = i % 2 == 0 ? 2 : 1.2
          ..strokeCap = StrokeCap.round
          ..color = trackColor,
      );
    }

    // Knob on the ring at current angle.
    final knob = Offset(
      center.dx + math.sin(rad) * ringRadius,
      center.dy - math.cos(rad) * ringRadius,
    );
    canvas.drawCircle(knob, 11, Paint()..color = knobColor);
    canvas.drawCircle(
      knob,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = knobBorder.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _GradientAngleDialPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.knobColor != knobColor ||
        oldDelegate.knobBorder != knobBorder;
  }
}
