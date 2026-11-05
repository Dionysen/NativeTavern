import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/data/models/theme/app_font_family.dart';
import 'package:native_tavern/data/models/theme/ui_preferences.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/theme_providers.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/widgets/settings/language_settings_tile.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';

/// Hub for theme, language, backgrounds, and typography.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeState = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    const defaults = UiPreferences.defaults;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appearanceSectionTitle),
      ),
      body: SettingsPageBody(
        children: [
          SettingsSection(
            icon: Icons.palette_outlined,
            title: l10n.appearanceSectionTitle,
            children: [
              const LanguageSettingsTile(),
              SettingsValueTile(
                icon: Icons.palette,
                title: l10n.theme,
                valueText: '',
                onTap: () => context.push(AppRoutes.themeSettings),
              ),
              SettingsValueTile(
                icon: Icons.wallpaper,
                title: l10n.backgrounds,
                valueText: '',
                onTap: () => context.push(AppRoutes.backgroundSettings),
              ),
              SettingsValueTile(
                icon: Icons.font_download_outlined,
                title: l10n.uiFontFamilyTitle,
                subtitle: l10n.uiFontFamilyDescription,
                valueText: _fontFamilyLabel(l10n, themeState.ui.fontFamilyId),
                onTap: () => _showFontFamilyPicker(context, ref),
              ),
              SettingsNumberTile(
                icon: Icons.format_size,
                title: l10n.uiFontSizeTitle,
                subtitle: l10n.uiFontSizeDescription,
                value: themeState.ui.fontSize,
                min: UiPreferences.minFontSize,
                max: UiPreferences.maxFontSize,
                defaultValue: defaults.fontSize,
                suffix: 'px',
                divisions: 7,
                defaultLabelBuilder: l10n.numberPickerDefaultLabel,
                onChanged: notifier.updateFontSize,
                showDivider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fontFamilyLabel(AppLocalizations l10n, String id) =>
      switch (id) {
        AppFontFamily.serif => l10n.uiFontFamilySerif,
        AppFontFamily.monospace => l10n.uiFontFamilyMonospace,
        _ => l10n.uiFontFamilySystem,
      };

  void _showFontFamilyPicker(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(themeProvider).ui.fontFamilyId;
    final notifier = ref.read(themeProvider.notifier);

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.uiFontFamilyTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            for (final id in AppFontFamily.ids)
              ListTile(
                title: Text(_fontFamilyLabel(l10n, id)),
                trailing: current == id
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  notifier.updateFontFamilyId(id);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}
