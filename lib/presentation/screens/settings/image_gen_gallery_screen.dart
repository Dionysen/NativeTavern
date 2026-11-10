import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/domain/services/image_gen_history_service.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/image_gen_providers.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';

/// Browse previously generated images and their prompt / params.
class ImageGenGalleryScreen extends ConsumerWidget {
  const ImageGenGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncEntries = ref.watch(imageGenHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.imageGenGallery),
        actions: [
          ChromeIconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
            onPressed: () => ref.invalidate(imageGenHistoryProvider),
          ),
        ],
      ),
      body: asyncEntries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.imageGenGalleryEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _GalleryThumb(
                entry: entry,
                onTap: () => _openDetail(context, ref, entry),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    ImageGenHistoryEntry entry,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ImageGenGalleryDetailScreen(entry: entry),
      ),
    );
    ref.invalidate(imageGenHistoryProvider);
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({required this.entry, required this.onTap});

  final ImageGenHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final file = File(entry.imagePath);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: file.existsSync()
            ? Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined),
                ),
              )
            : const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

class _ImageGenGalleryDetailScreen extends ConsumerStatefulWidget {
  const _ImageGenGalleryDetailScreen({required this.entry});

  final ImageGenHistoryEntry entry;

  @override
  ConsumerState<_ImageGenGalleryDetailScreen> createState() =>
      _ImageGenGalleryDetailScreenState();
}

class _ImageGenGalleryDetailScreenState
    extends ConsumerState<_ImageGenGalleryDetailScreen> {
  /// When true, show the upscaled gallery image; otherwise the original.
  bool _showUpscaled = true;

  ImageGenHistoryEntry get entry => widget.entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final canCompare = entry.upscaled && entry.hasComparableOriginal;
    final showingUpscaled = !canCompare || _showUpscaled;
    final imagePath = showingUpscaled
        ? entry.imagePath
        : (entry.originalImagePath ?? entry.imagePath);
    final file = File(imagePath);
    final displayWidth = showingUpscaled
        ? entry.width
        : (entry.originalWidth ?? entry.width);
    final displayHeight = showingUpscaled
        ? entry.height
        : (entry.originalHeight ?? entry.height);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.imageGenGalleryDetail),
        actions: [
          ChromeIconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.delete,
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: displayWidth > 0 && displayHeight > 0
                ? displayWidth / displayHeight
                : 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: file.existsSync()
                    ? InteractiveViewer(
                        child: Image.file(file, fit: BoxFit.contain),
                      )
                    : const Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
          if (canCompare) ...[
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: true,
                  label: Text(l10n.imageGenGalleryVersionUpscaled),
                  icon: const Icon(Icons.hd_outlined),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text(l10n.imageGenGalleryVersionOriginal),
                  icon: const Icon(Icons.image_outlined),
                ),
              ],
              selected: {_showUpscaled},
              onSelectionChanged: (next) {
                if (next.isEmpty) return;
                setState(() => _showUpscaled = next.first);
              },
            ),
          ],
          const SizedBox(height: 16),
          _InfoCard(
            title: l10n.imageGenGalleryInfo,
            rows: [
              _InfoRow(l10n.imageGenGalleryFileSize, entry.sizeLabel),
              _InfoRow(
                l10n.imageSize,
                '$displayWidth × $displayHeight',
              ),
              if (entry.provider != null && entry.provider!.isNotEmpty)
                _InfoRow(l10n.provider, entry.provider!),
              if (entry.model != null && entry.model!.isNotEmpty)
                _InfoRow(l10n.model, entry.model!),
              _InfoRow(l10n.steps, '${entry.steps}'),
              _InfoRow(l10n.cfgScale, entry.cfgScale.toStringAsFixed(1)),
              if (entry.sampler.isNotEmpty)
                _InfoRow(l10n.sampler, entry.sampler),
              if (entry.scheduler != null && entry.scheduler!.isNotEmpty)
                _InfoRow(l10n.imageGenGalleryScheduler, entry.scheduler!),
              if (entry.seed != null) _InfoRow(l10n.seed, '${entry.seed}'),
              if (entry.upscaled)
                _InfoRow(
                  l10n.imageUpscaleScale,
                  entry.upscaleScale != null
                      ? l10n.imageUpscaleScaleValue(entry.upscaleScale!)
                      : '—',
                ),
              _InfoRow(
                l10n.imageGenGalleryCreatedAt,
                _formatTime(entry.createdAt),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PromptBlock(
            title: l10n.imageGenGalleryPositivePrompt,
            text: entry.prompt,
          ),
          const SizedBox(height: 12),
          _PromptBlock(
            title: l10n.imageGenGalleryNegativePrompt,
            text: entry.negativePrompt.isEmpty ? '—' : entry.negativePrompt,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.imageGenGalleryDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(imageGenHistoryServiceProvider).delete(entry.id);
    if (!context.mounted) return;
    Navigator.pop(context);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final row in rows) row,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptBlock extends StatelessWidget {
  const _PromptBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
                ChromeIconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: l10n.copy,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.copiedToClipboard)),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
