import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/data/models/theme/ui_preferences.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/font_library_provider.dart';
import 'package:native_tavern/presentation/providers/theme_providers.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/screens/settings/theme_settings_screen.dart';
import 'package:native_tavern/presentation/widgets/settings/font_file_picker_row.dart';
import 'package:native_tavern/presentation/widgets/settings/language_settings_tile.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';

/// Hub for theme, language, backgrounds, and typography.
class AppearanceScreen extends ConsumerStatefulWidget {
  const AppearanceScreen({super.key});

  @override
  ConsumerState<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends ConsumerState<AppearanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fontLibraryProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final fontLibrary = ref.watch(fontLibraryProvider);
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
                icon: Icons.wallpaper,
                title: l10n.backgrounds,
                valueText: '',
                onTap: () => context.push(AppRoutes.backgroundSettings),
              ),
              FontFilePickerRow(
                icon: Icons.font_download_outlined,
                label: l10n.uiFontFamilyTitle,
                description: l10n.uiFontFamilyDescription,
                fonts: fontLibrary.fonts,
                selectedPath: themeState.ui.fontPath,
                fallbackFamilyLabel: themeState.ui.fontPath == null
                    ? themeState.ui.fontFamily
                    : null,
                isLoading: fontLibrary.isLoading,
                onSelected: themeNotifier.selectUiFont,
                onImportPath: themeNotifier.importUiFontFromPath,
                onDeleteFont: themeNotifier.deleteImportedFont,
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
                onChanged: themeNotifier.updateFontSize,
              ),
              SettingsNumberTile(
                icon: Icons.rounded_corner,
                title: l10n.cornerRadiusTitle,
                subtitle: l10n.cornerRadiusDescription,
                value: themeState.ui.cornerRadius,
                min: UiPreferences.minCornerRadius,
                max: UiPreferences.maxCornerRadius,
                defaultValue: defaults.cornerRadius,
                suffix: 'px',
                divisions: 20,
                defaultLabelBuilder: l10n.numberPickerDefaultLabel,
                onChanged: themeNotifier.updateCornerRadius,
              ),
              SettingsNumberTile(
                icon: Icons.crop_landscape,
                title: l10n.barCornerRadiusTitle,
                subtitle: l10n.barCornerRadiusDescription,
                value: themeState.ui.barCornerRadius,
                min: UiPreferences.minBarCornerRadius,
                max: UiPreferences.maxBarCornerRadius,
                defaultValue: defaults.barCornerRadius,
                suffix: 'px',
                divisions: 24,
                defaultLabelBuilder: l10n.numberPickerDefaultLabel,
                onChanged: themeNotifier.updateBarCornerRadius,
              ),
              SettingsNumberTile(
                icon: Icons.chat_bubble_outline,
                title: l10n.chatBubbleCornerRadiusTitle,
                subtitle: l10n.chatBubbleCornerRadiusDescription,
                value: themeState.ui.chatBubbleCornerRadius,
                min: UiPreferences.minChatBubbleCornerRadius,
                max: UiPreferences.maxChatBubbleCornerRadius,
                defaultValue: defaults.chatBubbleCornerRadius,
                suffix: 'px',
                divisions: 50,
                defaultLabelBuilder: l10n.numberPickerDefaultLabel,
                onChanged: themeNotifier.updateChatBubbleCornerRadius,
              ),
              SettingsSwitchTile(
                icon: Icons.border_style,
                title: l10n.showBordersTitle,
                subtitle: l10n.showBordersSubtitle,
                value: themeState.ui.showBorders,
                showDivider: false,
                onChanged: themeNotifier.updateShowBorders,
              ),
            ],
          ),
          const ThemeSettingsPanels(),
        ],
      ),
    );
  }
}
