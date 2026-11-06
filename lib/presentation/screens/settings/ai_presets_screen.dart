import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/widgets/settings/ai_presets_panel.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';

/// Full-screen AI presets manager (kept for deep links / AppBar import).
class AIPresetsScreen extends ConsumerWidget {
  const AIPresetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiPresets),
      ),
      body: SettingsPageBody(
        children: [
          SettingsSection(
            icon: Icons.info_outline,
            title: l10n.aiPresets,
            footer: l10n.aiPresetsDescription,
            children: const [
              AIPresetsPanel(),
            ],
          ),
        ],
      ),
    );
  }
}
