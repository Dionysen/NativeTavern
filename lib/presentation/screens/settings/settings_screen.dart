import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/chat_providers.dart';
import 'package:native_tavern/presentation/providers/locale_provider.dart';
import 'package:native_tavern/presentation/providers/persona_providers.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:native_tavern/core/flags/rpg_product_ui.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/widgets/privacy/ai_data_sharing_consent_gate.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// Settings screen - App settings only (AI config is in separate tab)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final packageInfo = ref.watch(packageInfoProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: SettingsPageBody(
        children: [
          SettingsSection(
            icon: Icons.person_outline,
            title: l10n.user,
            children: [
              const _PersonaTile(showDivider: true),
              SettingsValueTile(
                icon: Icons.backup,
                title: l10n.cloudBackup,
                subtitle: l10n.cloudBackupSubtitle,
                valueText: '',
                showDivider: false,
                onTap: () => context.push(AppRoutes.cloudBackupSettings),
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.chat_bubble_outline,
            title: l10n.chats,
            children: [
              SettingsValueTile(
                icon: Icons.quickreply,
                title: l10n.quickReplies,
                valueText: '',
                onTap: () => context.push(AppRoutes.quickReplies),
              ),
              SettingsValueTile(
                icon: Icons.wallpaper,
                title: l10n.backgrounds,
                valueText: '',
                onTap: () => context.push(AppRoutes.backgroundSettings),
              ),
              SettingsValueTile(
                key: const Key('memory-inbox-settings-tile'),
                icon: Icons.memory,
                title: l10n.memoryInbox,
                subtitle: l10n.memoryInboxSubtitle,
                valueText: '',
                showDivider: false,
                onTap: () => context.push(AppRoutes.memoryInbox),
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.sports_esports_outlined,
            title: l10n.playHub,
            children: [
              const _MomentsEnabledTile(),
              const _StoryEnabledTile(),
              if (kRpgProductUiEnabled)
                SettingsValueTile(
                  key: const Key('rpg-scenario-editor-settings-tile'),
                  icon: Icons.casino_outlined,
                  title: l10n.rpgScenarioEditor,
                  subtitle: l10n.rpgScenarioEditorSubtitle,
                  valueText: '',
                  showDivider: false,
                  onTap: () => context.push(AppRoutes.rpgScenarioEditor),
                ),
            ],
          ),
          SettingsSection(
            icon: Icons.perm_media_outlined,
            title: l10n.multimedia,
            children: [
              SettingsValueTile(
                icon: Icons.record_voice_over,
                title: l10n.tts,
                valueText: '',
                onTap: () => context.push(AppRoutes.ttsSettings),
              ),
              SettingsValueTile(
                icon: Icons.mic,
                title: l10n.stt,
                valueText: '',
                onTap: () => context.push(AppRoutes.sttSettings),
              ),
              SettingsValueTile(
                icon: Icons.translate,
                title: l10n.translation,
                valueText: '',
                onTap: () => context.push(AppRoutes.translationSettings),
              ),
              SettingsValueTile(
                icon: Icons.image,
                title: l10n.imageGeneration,
                valueText: '',
                onTap: () => context.push(AppRoutes.imageGenSettings),
              ),
              SettingsValueTile(
                icon: Icons.emoji_emotions,
                title: l10n.sprites,
                valueText: '',
                showDivider: false,
                onTap: () => context.push(AppRoutes.spriteSettings),
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.tune,
            title: l10n.advanced,
            children: [
              SettingsValueTile(
                key: const Key('capability-diagnostics-settings-tile'),
                icon: Icons.health_and_safety_outlined,
                title: l10n.capabilityCheck,
                subtitle: l10n.capabilityCheckSubtitle,
                valueText: '',
                onTap: () => context.push(AppRoutes.capabilityDiagnostics),
              ),
              SettingsValueTile(
                key: const Key('mcp-settings-tile'),
                icon: Icons.extension_outlined,
                title: l10n.mcpServers,
                subtitle: l10n.mcpServersSubtitle,
                valueText: '',
                onTap: () => context.push(AppRoutes.mcpSettings),
              ),
              SettingsValueTile(
                key: const Key('tool-calling-settings-tile'),
                icon: Icons.build_outlined,
                title: l10n.toolCalling,
                subtitle: l10n.toolCallingSubtitle,
                valueText: '',
                onTap: () => context.push(AppRoutes.toolCallingSettings),
              ),
              SettingsValueTile(
                key: const Key('storage-management-settings-tile'),
                icon: Icons.storage_outlined,
                title: l10n.storageManagement,
                subtitle: l10n.storageManagementSubtitle,
                valueText: '',
                onTap: () => context.push(AppRoutes.storageManagement),
              ),
              SettingsValueTile(
                icon: Icons.find_replace,
                title: l10n.regex,
                valueText: '',
                onTap: () => context.push(AppRoutes.regexSettings),
              ),
              SettingsValueTile(
                icon: Icons.data_object,
                title: l10n.variables,
                valueText: '',
                onTap: () => context.push(AppRoutes.variablesSettings),
              ),
              SettingsValueTile(
                icon: Icons.tune,
                title: l10n.logitBias,
                valueText: '',
                onTap: () => context.push(AppRoutes.logitBiasSettings),
              ),
              SettingsValueTile(
                icon: Icons.linear_scale,
                title: l10n.cfgScale,
                valueText: '',
                onTap: () => context.push(AppRoutes.cfgScaleSettings),
              ),
              SettingsValueTile(
                icon: Icons.token,
                title: l10n.tokenizer,
                valueText: '',
                onTap: () => context.push(AppRoutes.tokenizerSettings),
              ),
              SettingsValueTile(
                icon: Icons.storage,
                title: l10n.vectorStorage,
                valueText: '',
                showDivider: false,
                onTap: () => context.push(AppRoutes.vectorStorageSettings),
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.settings_outlined,
            title: l10n.settings,
            children: [
              const _LanguageTile(),
              SettingsValueTile(
                icon: Icons.palette,
                title: l10n.theme,
                valueText: '',
                onTap: () => context.push(AppRoutes.themeSettings),
              ),
              const _ConfirmDeleteTile(),
              const _AutoSaveTile(),
              const AiDataSharingSettingsTile(),
              const _DebugLogTile(),
              SettingsValueTile(
                icon: Icons.analytics,
                title: l10n.statistics,
                valueText: '',
                showDivider: false,
                onTap: () => context.push(AppRoutes.statistics),
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.info_outline,
            title: l10n.about,
            children: [
              SettingsListTile(
                icon: Icons.info_outline,
                title: l10n.version,
                subtitle: packageInfo.when(
                  data: (info) => '${info.version}+${info.buildNumber}',
                  loading: () => l10n.loading,
                  error: (_, __) => l10n.error,
                ),
                onLongPress: () {
                  final info = packageInfo.valueOrNull;
                  if (info == null) return;
                  final version = '${info.version}+${info.buildNumber}';
                  Clipboard.setData(ClipboardData(text: version));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${l10n.copiedToClipboard}: $version'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              SettingsValueTile(
                icon: Icons.language,
                title: l10n.officialWebsite,
                valueText: '',
                onTap: () => launchUrl(
                  Uri.parse('https://nativetavern.com'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              SettingsValueTile(
                icon: Icons.forum,
                title: 'Discord',
                valueText: '',
                onTap: () => launchUrl(
                  Uri.parse('https://discord.com/invite/URQvW2FvZa'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              SettingsListTile(
                icon: Icons.description,
                title: l10n.licenses,
                trailing: Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant,
                  size: 20,
                ),
                onTap: () {
                  showLicensePage(context: context);
                },
              ),
              const PrivacyPolicyTile(showDivider: false),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonaTile extends ConsumerWidget {
  const _PersonaTile({this.showDivider = true});

  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final activePersonaAsync = ref.watch(activePersonaProvider);
    final personaName = activePersonaAsync.when(
      loading: () => l10n.loading,
      error: (_, __) => l10n.error,
      data: (persona) => persona?.name ?? l10n.default_,
    );

    return SettingsValueTile(
      icon: Icons.person,
      title: l10n.personas,
      valueText: personaName,
      showDivider: showDivider,
      onTap: () => context.push(AppRoutes.personas),
      onLongPress: () {
        final name = activePersonaAsync.valueOrNull?.name ?? l10n.default_;
        Clipboard.setData(ClipboardData(text: name));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.copiedToClipboard}: $name'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}

class _ConfirmDeleteTile extends ConsumerWidget {
  const _ConfirmDeleteTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);

    return SettingsSwitchTile(
      icon: Icons.delete_forever,
      title: l10n.confirmBeforeDeleteTitle,
      subtitle: l10n.confirmBeforeDeleteSubtitle,
      value: settings.confirmBeforeDelete,
      onChanged: (value) {
        ref.read(appSettingsProvider.notifier).updateConfirmBeforeDelete(value);
      },
    );
  }
}

class _MomentsEnabledTile extends ConsumerWidget {
  const _MomentsEnabledTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    return SettingsSwitchTile(
      key: const Key('moments-enabled-switch'),
      icon: Icons.dynamic_feed_outlined,
      title: l10n.moments,
      subtitle: l10n.momentsEnabledSubtitle,
      value: settings.momentsEnabled,
      onChanged: (value) {
        ref.read(appSettingsProvider.notifier).updateMomentsEnabled(value);
      },
    );
  }
}

class _StoryEnabledTile extends ConsumerWidget {
  const _StoryEnabledTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    const showDivider = kRpgProductUiEnabled;
    return SettingsSwitchTile(
      key: const Key('story-enabled-switch'),
      icon: Icons.menu_book_outlined,
      title: l10n.story,
      subtitle: l10n.storyEnabledSubtitle,
      value: settings.storyEnabled,
      showDivider: showDivider,
      onChanged: (value) {
        ref.read(appSettingsProvider.notifier).updateStoryEnabled(value);
      },
    );
  }
}

class _AutoSaveTile extends ConsumerWidget {
  const _AutoSaveTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);

    return SettingsSwitchTile(
      icon: Icons.save_outlined,
      title: l10n.autoSaveChatsTitle,
      subtitle: l10n.autoSaveChatsSubtitle,
      value: settings.autoSaveChats,
      onChanged: (value) async {
        ref.read(appSettingsProvider.notifier).updateAutoSaveChats(value);
        // Turning auto-save on should immediately flush any pending edits.
        if (value && ref.read(activeChatProvider).hasUnsavedChanges) {
          await ref.read(activeChatProvider.notifier).saveChatNow();
        }
      },
    );
  }
}

class _DebugLogTile extends ConsumerWidget {
  const _DebugLogTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);

    return SettingsSwitchTile(
      icon: Icons.bug_report,
      title: l10n.debugLog,
      subtitle: l10n.debugLogDescription,
      value: settings.enableDebugLog,
      onChanged: (value) {
        ref.read(appSettingsProvider.notifier).updateDebugLog(value);
      },
    );
  }
}

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);

    // Find the current locale's display name
    String currentLanguage = l10n.systemTheme;
    if (currentLocale != null) {
      final supportedLocale = supportedLocales.where((sl) {
        if (currentLocale.countryCode != null) {
          return sl.locale.languageCode == currentLocale.languageCode &&
              sl.locale.countryCode == currentLocale.countryCode;
        }
        return sl.locale.languageCode == currentLocale.languageCode &&
            sl.locale.countryCode == null;
      }).firstOrNull;
      if (supportedLocale != null) {
        currentLanguage =
            '${supportedLocale.nativeName} (${supportedLocale.displayName})';
      }
    }

    return SettingsValueTile(
      icon: Icons.language,
      title: l10n.language,
      valueText: currentLanguage,
      onTap: () => _showLanguageSelector(context, ref),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: currentLanguage));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.copiedToClipboard}: $currentLanguage'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _showLanguageSelector(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.read(localeProvider);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    l10n.selectLanguage,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  ChromeIconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  // System default option
                  ListTile(
                    leading: const Icon(Icons.phone_android),
                    title: Text(l10n.systemTheme),
                    trailing: currentLocale == null
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () {
                      ref.read(localeProvider.notifier).resetToSystem();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.languageChanged),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  // All supported locales
                  ...supportedLocales.map((sl) {
                    final isSelected = currentLocale != null &&
                        currentLocale.languageCode == sl.locale.languageCode &&
                        currentLocale.countryCode == sl.locale.countryCode;

                    return ListTile(
                      title: Text(sl.nativeName),
                      subtitle: Text(sl.displayName),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () {
                        ref.read(localeProvider.notifier).setLocale(sl.locale);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.languageChanged),
                          ),
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
