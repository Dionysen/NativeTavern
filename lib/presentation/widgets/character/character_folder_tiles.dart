import 'package:flutter/material.dart';
import 'package:native_tavern/data/models/character_folder.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/screens/character/character_view_mode.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/widgets/common/character_avatar_image.dart';

class CharacterFolderPreviewMosaic extends StatelessWidget {
  const CharacterFolderPreviewMosaic({
    super.key,
    required this.previews,
    this.compact = false,
    this.borderRadius = 0,
  });

  final List<CharacterFolderPreview> previews;
  final bool compact;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final padding = compact ? 4.0 : 6.0;
    final gap = compact ? 2.0 : 3.0;
    final slots = List<CharacterFolderPreview?>.filled(4, null);
    for (var i = 0; i < previews.length && i < 4; i++) {
      slots[i] = previews[i];
    }

    Widget row(List<CharacterFolderPreview?> pair) {
      return Expanded(
        child: Row(
          children: [
            Expanded(child: _PreviewCell(preview: pair[0], compact: compact)),
            SizedBox(width: gap),
            Expanded(child: _PreviewCell(preview: pair[1], compact: compact)),
          ],
        ),
      );
    }

    final mosaic = Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        children: [
          row([slots[0], slots[1]]),
          SizedBox(height: gap),
          row([slots[2], slots[3]]),
        ],
      ),
    );

    if (borderRadius <= 0) {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: mosaic,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: mosaic,
      ),
    );
  }
}

class _PreviewCell extends StatelessWidget {
  const _PreviewCell({required this.preview, required this.compact});

  final CharacterFolderPreview? preview;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 3.0 : 4.0;
    if (preview == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    final color = _previewColor(preview!.id);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.expand(
        child: preview!.avatarPath != null
            ? CharacterAvatarImage(
                imagePath: preview!.avatarPath!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(color),
              )
            : _fallback(color),
      ),
    );
  }

  Widget _fallback(Color color) {
    return ColoredBox(
      color: color,
      child: Center(
        child: Icon(
          Icons.person,
          size: compact ? 16 : 22,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

Color _previewColor(String id) {
  switch (id) {
    case 'builtin_coding_assistant':
      return const Color(0xFF2196F3);
    case 'builtin_image_gen_assistant':
      return const Color(0xFFE91E63);
    case 'builtin_xiaohongshu_copywriter':
      return const Color(0xFFFF5722);
    default:
      return AppTheme.darkDivider;
  }
}

class CharacterFolderGridCard extends StatelessWidget {
  const CharacterFolderGridCard({
    super.key,
    required this.folder,
    required this.onTap,
    required this.onLongPress,
    this.onSecondaryTap,
    this.compact = false,
  });

  final CharacterFolder folder;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onSecondaryTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final coverFlex = compact ? 4 : 3;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: coverFlex,
              child: CharacterFolderPreviewMosaic(
                previews: folder.previewCharacters,
                compact: compact,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 4 : 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    folder.name,
                    style: compact
                        ? Theme.of(context).textTheme.bodySmall
                        : Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                  ),
                  if (!compact) ...[
                    Text(
                      l10n.characterFolderCount(folder.characterCount),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CharacterFolderListTile extends StatelessWidget {
  const CharacterFolderListTile({
    super.key,
    required this.folder,
    required this.avatarShape,
    required this.onTap,
    required this.onLongPress,
    this.onSecondaryTap,
  });

  final CharacterFolder folder;
  final CharacterAvatarShape avatarShape;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metaStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      height: 1.3,
      color: scheme.onSurfaceVariant,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _folderListAvatar(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      folder.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.characterFolderCount(folder.characterCount),
                      style: metaStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _folderListAvatar(BuildContext context) {
    const width = 56.0;
    final (height, radius) = switch (avatarShape) {
      CharacterAvatarShape.circle => (width, width / 2),
      CharacterAvatarShape.square => (width, 8.0),
      CharacterAvatarShape.rectangle => (width * 4 / 3, 8.0),
    };

    final mosaic = CharacterFolderPreviewMosaic(
      previews: folder.previewCharacters,
      compact: true,
      borderRadius: avatarShape == CharacterAvatarShape.circle ? 0 : radius,
    );

    return SizedBox(
      width: width,
      height: height,
      child: avatarShape == CharacterAvatarShape.circle
          ? ClipOval(child: mosaic)
          : ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: mosaic,
            ),
    );
  }
}
