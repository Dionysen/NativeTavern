import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/tag.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/character_providers.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';

Future<void> showCharacterTagFilterSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  ref.invalidate(characterLibraryTagLabelsProvider);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _CharacterTagFilterSheet(),
  );
}

class _CharacterTagFilterSheet extends ConsumerWidget {
  const _CharacterTagFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final labelsAsync = ref.watch(characterLibraryTagLabelsProvider);
    final selected = ref.watch(characterBrowseTagFilterProvider);

    final maxHeight = MediaQuery.sizeOf(context).height * 0.55;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: SizedBox(
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.filterByTags,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (selected.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref
                            .read(characterBrowseTagFilterProvider.notifier)
                            .state = {};
                      },
                      child: Text(l10n.clear),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: labelsAsync.when(
                  data: (labels) {
                    if (labels.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.noTagsAvailable,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textMuted,
                                  ),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final label in labels)
                            FilterChip(
                              label: Text(label),
                              selected: selected.contains(label),
                              showCheckmark: true,
                              selectedColor: TagColors.forLabel(label)
                                  .withValues(alpha: 0.22),
                              side: BorderSide(
                                color: TagColors.forLabel(label)
                                    .withValues(alpha: 0.55),
                              ),
                              onSelected: (value) {
                                final next = Set<String>.from(selected);
                                if (value) {
                                  next.add(label);
                                } else {
                                  next.remove(label);
                                }
                                ref
                                    .read(
                                        characterBrowseTagFilterProvider.notifier)
                                    .state = next;
                              },
                            ),
                        ],
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text('${l10n.error}: $error'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
