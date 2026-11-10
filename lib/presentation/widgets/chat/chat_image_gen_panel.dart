import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/domain/services/image_generation_service.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/image_gen_providers.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';

/// Composer-adjacent panel for quick image-gen controls.
class ChatImageGenPanel extends ConsumerWidget {
  const ChatImageGenPanel({
    super.key,
    required this.onOpenSettings,
    required this.onGenerateForCurrentReply,
    required this.isPinned,
    required this.onTogglePin,
    required this.isGenerating,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onGenerateForCurrentReply;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final bool isGenerating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(imageGenSettingsProvider);
    final scheme = Theme.of(context).colorScheme;

    Widget panelHeader() {
      return Row(
        children: [
          Expanded(
            child: Text(
              l10n.imageGenPanelTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ChromeIconButton(
            density: ChromeIconButtonDensity.compact,
            tooltip: isPinned ? l10n.unpinImageGenPanel : l10n.pinImageGenPanel,
            isSelected: isPinned,
            onPressed: onTogglePin,
            icon: Icon(
              isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 20,
            ),
          ),
          ChromeIconButton(
            density: ChromeIconButtonDensity.compact,
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: onOpenSettings,
          ),
        ],
      );
    }

    if (!settings.enabled) {
      return Padding(
        key: const ValueKey('chat-image-gen-panel-disabled'),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.imageGenDisabledTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ChromeIconButton(
                  density: ChromeIconButtonDensity.compact,
                  tooltip: l10n.settings,
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  onPressed: onOpenSettings,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.imageGenDisabledHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.enableImageGeneration),
              value: false,
              onChanged: (_) {
                ref.read(imageGenSettingsProvider.notifier).setEnabled(true);
              },
            ),
            const SizedBox(height: 4),
            OutlinedButton(
              onPressed: onOpenSettings,
              child: Text(l10n.openImageGenSettings),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      key: const ValueKey('chat-image-gen-panel'),
      constraints: const BoxConstraints(maxHeight: 360),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              panelHeader(),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.imageGenAutoOnReply),
                subtitle: Text(l10n.imageGenAutoOnReplyHint),
                value: settings.autoGenerateOnReply,
                onChanged: (value) {
                  ref
                      .read(imageGenSettingsProvider.notifier)
                      .setAutoGenerateOnReply(value);
                },
              ),
              const SizedBox(height: 4),
              Text(
                l10n.imageGenDisplayMode,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DisplayModeChip(
                    label: l10n.imageGenDisplayModeSeparate,
                    selected: settings.displayMode ==
                        ImageGenDisplayMode.separateBubble,
                    onTap: () {
                      ref
                          .read(imageGenSettingsProvider.notifier)
                          .setDisplayMode(ImageGenDisplayMode.separateBubble);
                    },
                  ),
                  _DisplayModeChip(
                    label: l10n.imageGenDisplayModeAttach,
                    selected:
                        settings.displayMode == ImageGenDisplayMode.attach,
                    onTap: () {
                      ref
                          .read(imageGenSettingsProvider.notifier)
                          .setDisplayMode(ImageGenDisplayMode.attach);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.imageSize),
                subtitle: Text(
                  '${settings.defaultWidth} × ${settings.defaultHeight}',
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () => showImageGenSizeDialog(context, ref),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.imageGenImagesPerReply,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.imageGenImagesPerReplyHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var count = 1; count <= 4; count++)
                    _DisplayModeChip(
                      label: '$count',
                      selected: settings.imagesPerReply == count,
                      onTap: () {
                        ref
                            .read(imageGenSettingsProvider.notifier)
                            .setImagesPerReply(count);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: isGenerating ? null : onGenerateForCurrentReply,
                icon: isGenerating
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(l10n.imagineFromLastReply),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisplayModeChip extends StatelessWidget {
  const _DisplayModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
      ),
    );
  }
}

/// Shared size picker used by the chat panel and settings screen.
Future<void> showImageGenSizeDialog(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  final settings = ref.read(imageGenSettingsProvider);
  final widthController =
      TextEditingController(text: '${settings.defaultWidth}');
  final heightController =
      TextEditingController(text: '${settings.defaultHeight}');
  String? errorText;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void applyPreset(ImageAspectRatio preset) {
            setDialogState(() {
              widthController.text = '${preset.width}';
              heightController.text = '${preset.height}';
              errorText = null;
            });
          }

          void save() {
            final width = int.tryParse(widthController.text.trim());
            final height = int.tryParse(heightController.text.trim());
            if (width == null ||
                height == null ||
                width < 256 ||
                width > 2048 ||
                height < 256 ||
                height > 2048) {
              setDialogState(() => errorText = l10n.imageSizeInvalid);
              return;
            }
            ref.read(imageGenSettingsProvider.notifier).setDefaultSize(
                  width: width,
                  height: height,
                );
            Navigator.pop(dialogContext);
          }

          return AlertDialog(
            title: Text(l10n.imageSize),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.imageSizeCustomHint,
                      style: Theme.of(dialogContext).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: widthController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.imageSizeWidth,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              if (errorText != null) {
                                setDialogState(() => errorText = null);
                              }
                            },
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('×'),
                        ),
                        Expanded(
                          child: TextField(
                            controller: heightController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.imageSizeHeight,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              if (errorText != null) {
                                setDialogState(() => errorText = null);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      l10n.imageSizeQuickPresets,
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in ImageAspectRatio.presets)
                          ActionChip(
                            label: Text('${preset.width}×${preset.height}'),
                            onPressed: () => applyPreset(preset),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: save,
                child: Text(l10n.save),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(() {
    widthController.dispose();
    heightController.dispose();
  });
}
