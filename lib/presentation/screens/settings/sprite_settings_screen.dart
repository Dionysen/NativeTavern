import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_tavern/data/models/sprite.dart';
import 'package:native_tavern/presentation/providers/sprite_providers.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/widgets/chat/sprite_display.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';

/// Screen for managing sprite settings
class SpriteSettingsScreen extends ConsumerWidget {
  const SpriteSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(spriteSettingsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expressionSprites),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: l10n.resetToDefaults,
            onPressed: () {
              ref.read(spriteSettingsProvider.notifier).reset();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.settingsResetToDefaults)),
              );
            },
          ),
        ],
      ),
      body: SettingsPageBody(
        children: [
          SettingsSection(
            icon: Icons.toggle_on_outlined,
            title: l10n.general,
            children: [
              SettingsSwitchTile(
                icon: Icons.emoji_emotions,
                title: l10n.enableSprites,
                subtitle: l10n.showCharacterExpressions,
                value: settings.enabled,
                showDivider: false,
                onChanged: (value) {
                  ref.read(spriteSettingsProvider.notifier).setEnabled(value);
                },
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.display_settings,
            title: l10n.display,
            children: [
              SettingsSliderTile(
                icon: Icons.photo_size_select_large,
                title: l10n.spriteSize,
                value: settings.size,
                min: 50,
                max: 400,
                divisions: 35,
                valueLabel: '${settings.size.round()}px',
                enabled: settings.enabled,
                onChanged: (value) {
                  ref.read(spriteSettingsProvider.notifier).setSize(value);
                },
              ),
              SettingsChoiceTile<SpritePosition>(
                icon: Icons.picture_in_picture_alt,
                title: l10n.position,
                subtitle: l10n.whereToDisplaySprites,
                selected: settings.position,
                enabled: settings.enabled,
                choices: [
                  for (final pos in SpritePosition.values)
                    SettingsChoice(
                      value: pos,
                      label: _getPositionName(pos, l10n),
                    ),
                ],
                valueLabel: _getPositionName(settings.position, l10n),
                onSelected: (value) {
                  ref.read(spriteSettingsProvider.notifier).setPosition(value);
                },
              ),
              SettingsSliderTile(
                icon: Icons.opacity,
                title: l10n.opacity,
                value: settings.opacity,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                valueLabel: '${(settings.opacity * 100).round()}%',
                enabled: settings.enabled,
                showDivider: false,
                onChanged: (value) {
                  ref.read(spriteSettingsProvider.notifier).setOpacity(value);
                },
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.animation,
            title: l10n.animation,
            children: [
              SettingsSwitchTile(
                icon: Icons.animation,
                title: l10n.animateTransitions,
                subtitle: l10n.smoothFadeWhenSpriteChanges,
                value: settings.animateTransitions,
                onChanged: settings.enabled
                    ? (value) {
                        ref
                            .read(spriteSettingsProvider.notifier)
                            .setAnimateTransitions(value);
                      }
                    : null,
              ),
              SettingsSliderTile(
                icon: Icons.timer_outlined,
                title: l10n.transitionDuration,
                value: settings.transitionDurationMs.toDouble(),
                min: 0,
                max: 1000,
                divisions: 10,
                valueLabel: '${settings.transitionDurationMs}ms',
                enabled: settings.enabled && settings.animateTransitions,
                onChanged: (value) {
                  ref
                      .read(spriteSettingsProvider.notifier)
                      .setTransitionDuration(value.round());
                },
              ),
              SettingsSwitchTile(
                icon: Icons.stream,
                title: l10n.showDuringStreaming,
                subtitle: l10n.displaySpritesWhileGenerating,
                value: settings.showDuringStreaming,
                showDivider: false,
                onChanged: settings.enabled
                    ? (value) {
                        ref
                            .read(spriteSettingsProvider.notifier)
                            .setShowDuringStreaming(value);
                      }
                    : null,
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.psychology_outlined,
            title: l10n.emotionDetection,
            children: [
              SettingsListTile(
                icon: Icons.info_outline,
                title: l10n.howItWorks,
                subtitle: l10n.spriteEmotionDetectionDescription,
              ),
              ExpansionTile(
                leading: const Icon(Icons.emoji_emotions_outlined),
                title: Text(l10n.supportedEmotions),
                children: SpriteEmotion.values.map((emotion) {
                  return ListTile(
                    dense: true,
                    title: Text(_getEmotionName(emotion, l10n)),
                    subtitle: Text(
                      emotion.keywords.take(5).join(', ') +
                          (emotion.keywords.length > 5 ? '...' : ''),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPositionName(
    SpritePosition position,
    AppLocalizations l10n,
  ) {
    switch (position) {
      case SpritePosition.left:
        return l10n.left;
      case SpritePosition.right:
        return l10n.right;
      case SpritePosition.center:
        return l10n.center;
      case SpritePosition.floatingLeft:
        return l10n.floatingLeft;
      case SpritePosition.floatingRight:
        return l10n.floatingRight;
    }
  }

  String _getEmotionName(SpriteEmotion emotion, AppLocalizations l10n) =>
      _localizedEmotionName(emotion, l10n);
}

/// Screen for managing sprites for a specific character
class CharacterSpritesScreen extends ConsumerStatefulWidget {
  final String characterId;
  final String characterName;

  const CharacterSpritesScreen({
    super.key,
    required this.characterId,
    required this.characterName,
  });

  @override
  ConsumerState<CharacterSpritesScreen> createState() =>
      _CharacterSpritesScreenState();
}

class _CharacterSpritesScreenState
    extends ConsumerState<CharacterSpritesScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _selectedEmotion;

  @override
  Widget build(BuildContext context) {
    final packAsync = ref.watch(spritePackNotifierProvider(widget.characterId));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.characterSprites(widget.characterName)),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: l10n.importFromFolder,
            onPressed: _importFromFolder,
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete_all',
                child: ListTile(
                  leading: const Icon(Icons.delete_sweep, color: Colors.red),
                  title: Text(l10n.deleteAllSprites),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete_all') {
                _confirmDeleteAll();
              }
            },
          ),
        ],
      ),
      body: packAsync.when(
        data: (pack) => _buildContent(pack),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('${l10n.error}: $error',
              style: const TextStyle(color: Colors.red)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSprite,
        icon: const Icon(Icons.add_photo_alternate),
        label: Text(l10n.addSprite),
      ),
    );
  }

  Widget _buildContent(SpritePack pack) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats card
        Card(
          color: AppTheme.darkCard,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.image, color: AppTheme.accentColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.spritesCount(pack.sprites.length),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (pack.defaultEmotion != null)
                        Text(
                          l10n.defaultEmotion(pack.defaultEmotion!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Sprites grid
        if (pack.hasSprites) ...[
          Text(
            l10n.sprites,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SpriteGrid(
            characterId: widget.characterId,
            selectedEmotion: _selectedEmotion,
            onSelect: (sprite) {
              setState(() => _selectedEmotion = sprite.emotion);
              _showSpriteOptions(sprite);
            },
            onDelete: (sprite) => _confirmDeleteSprite(sprite),
          ),
        ] else ...[
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.add_photo_alternate,
                  size: 64,
                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noSpritesYet,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.addExpressionImages,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }

  Future<void> _addSprite() async {
    // First, select emotion
    final emotion = await _selectEmotion();
    if (emotion == null) return;

    // Then, pick image
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // Add sprite
    await ref
        .read(spritePackNotifierProvider(widget.characterId).notifier)
        .addSprite(emotion, File(image.path));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context).addedSpriteEmotion(emotion))),
      );
    }
  }

  Future<String?> _selectEmotion() async {
    final l10n = AppLocalizations.of(context);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectEmotion),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: SpriteEmotion.values.length,
            itemBuilder: (context, index) {
              final emotion = SpriteEmotion.values[index];
              return ListTile(
                title: Text(_localizedEmotionName(emotion, l10n)),
                subtitle: Text(
                  emotion.keywords.take(3).join(', '),
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                onTap: () => Navigator.pop(context, emotion.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  void _showSpriteOptions(Sprite sprite) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
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
                color: AppTheme.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Preview
            SpritePreview(
              sprite: sprite,
              size: 120,
              showLabel: true,
            ),

            const SizedBox(height: 16),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.star, color: AppTheme.accentColor),
              title: Text(l10n.setAsDefault),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(
                        spritePackNotifierProvider(widget.characterId).notifier)
                    .setDefaultEmotion(sprite.emotion);
              },
            ),

            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(l10n.changeEmotion),
              onTap: () async {
                Navigator.pop(context);
                final newEmotion = await _selectEmotion();
                if (newEmotion != null && newEmotion != sprite.emotion) {
                  // Remove old and add new
                  await ref
                      .read(spritePackNotifierProvider(widget.characterId)
                          .notifier)
                      .removeSprite(sprite.emotion);
                  await ref
                      .read(spritePackNotifierProvider(widget.characterId)
                          .notifier)
                      .addSprite(newEmotion, File(sprite.imagePath));
                }
              },
            ),

            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title:
                  Text(l10n.delete, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteSprite(sprite);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSprite(Sprite sprite) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteSprite),
        content: Text(l10n.deleteSpriteConfirmation(sprite.emotion)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(spritePackNotifierProvider(widget.characterId).notifier)
                  .removeSprite(sprite.emotion);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAllSprites),
        content: Text(l10n.deleteAllSpritesConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(spritePackNotifierProvider(widget.characterId).notifier)
                  .deleteAll();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.deleteAll),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromFolder() async {
    final l10n = AppLocalizations.of(context);
    // Show info dialog about import
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importSprites),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.importSpritesDescription),
            const SizedBox(height: 12),
            const Text('• happy.png, smile.jpg',
                style: TextStyle(fontSize: 12)),
            const Text('• sad.png, cry.jpg', style: TextStyle(fontSize: 12)),
            const Text('• angry.png, mad.jpg', style: TextStyle(fontSize: 12)),
            const Text('• neutral.png, default.jpg',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            Text(
              l10n.supportedFormatsSprites,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.selectFolder),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Note: Folder picking requires file_picker package
    // For now, show a message that this feature requires additional setup
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.folderImportRequiresPackage),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

String _localizedEmotionName(
  SpriteEmotion emotion,
  AppLocalizations l10n,
) {
  return switch (emotion) {
    SpriteEmotion.neutral => l10n.emotionNeutral,
    SpriteEmotion.happy => l10n.emotionHappy,
    SpriteEmotion.sad => l10n.emotionSad,
    SpriteEmotion.angry => l10n.emotionAngry,
    SpriteEmotion.surprised => l10n.emotionSurprised,
    SpriteEmotion.scared => l10n.emotionScared,
    SpriteEmotion.disgusted => l10n.emotionDisgusted,
    SpriteEmotion.confused => l10n.emotionConfused,
    SpriteEmotion.embarrassed => l10n.emotionEmbarrassed,
    SpriteEmotion.excited => l10n.emotionExcited,
    SpriteEmotion.loving => l10n.emotionLoving,
    SpriteEmotion.thinking => l10n.emotionThinking,
    SpriteEmotion.smug => l10n.emotionSmug,
    SpriteEmotion.tired => l10n.emotionTired,
    SpriteEmotion.bored => l10n.emotionBored,
  };
}
