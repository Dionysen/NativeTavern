import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/router/shell_navigation.dart';
import 'package:native_tavern/presentation/widgets/play/ai_play_feature_gate.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';

/// Play tab hub: four names only. No timeline, switches, or status.
///
/// Same chrome as Settings / AI Config on every platform — a single card of
/// disclosure rows, not oversized ListTiles that stretch differently on desktop.
class PlayHubScreen extends ConsumerWidget {
  const PlayHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.playHub)),
      body: SettingsPageBody(
        children: [
          SettingsSection(
            children: [
              SettingsValueTile(
                key: const Key('play-hub-moments'),
                icon: Icons.dynamic_feed_outlined,
                title: l10n.moments,
                valueText: '',
                onTap: () async {
                  final enabled = await ensureAiPlayFeatureEnabled(
                    context,
                    ref,
                    AiPlayFeature.moments,
                  );
                  if (enabled && context.mounted) {
                    context.openShell(AppRoutes.playMoments);
                  }
                },
              ),
              SettingsValueTile(
                key: const Key('play-hub-story'),
                icon: Icons.menu_book_outlined,
                title: l10n.story,
                valueText: '',
                onTap: () async {
                  final enabled = await ensureAiPlayFeatureEnabled(
                    context,
                    ref,
                    AiPlayFeature.story,
                  );
                  if (enabled && context.mounted) {
                    context.openShell(AppRoutes.playStory);
                  }
                },
              ),
              SettingsValueTile(
                key: const Key('play-hub-world-info'),
                icon: Icons.public_outlined,
                title: l10n.worldInfo,
                valueText: '',
                onTap: () => context.openShell(AppRoutes.worldInfo),
                              ),
              SettingsValueTile(
                key: const Key('play-hub-data-bank'),
                icon: Icons.library_books_outlined,
                title: l10n.dataBank,
                valueText: '',
                showDivider: false,
                onTap: () => context.openShell(AppRoutes.dataBank),
                              ),
            ],
          ),
        ],
      ),
    );
  }
}
