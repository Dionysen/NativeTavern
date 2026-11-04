import 'dart:async';

import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/domain/services/stt_service.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/stt_providers.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';

class STTSettingsScreen extends ConsumerWidget {
  const STTSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(sttSettingsProvider);
    final session = ref.watch(sttSessionProvider);
    final available = ref.watch(sttAvailableProvider);
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.speechToText),
        actions: [
          ChromeIconButton(
            icon: const Icon(Icons.restore),
            tooltip: l10n.resetToDefaults,
            onPressed: () {
              ref.read(sttSettingsProvider.notifier).reset();
              ref.read(sttSessionProvider.notifier).clear();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.settingsResetToDefaults)),
              );
            },
          ),
        ],
      ),
      body: SettingsPageBody(
        children: [
          if (session.message != null && _isFailure(session.phase))
            _StatusPanel(
              message: session.message!,
              actionLabel:
                  session.phase == STTSessionPhase.permissionPermanentlyDenied
                      ? l10n.openSystemSettings
                      : null,
              onAction:
                  session.phase == STTSessionPhase.permissionPermanentlyDenied
                      ? () => unawaited(
                            ref
                                .read(sttSessionProvider.notifier)
                                .openPermissionSettings(),
                          )
                      : null,
            ),
          if (settings.provider.isRemote && !settings.isConfigured)
            _StatusPanel(message: l10n.sttConfigurationRequired),
          if (settings.provider == STTProvider.system)
            available.when(
              data: (value) => value
                  ? const SizedBox.shrink()
                  : _StatusPanel(message: l10n.speechRecognitionNotAvailable),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          SettingsSection(
            icon: Icons.toggle_on_outlined,
            title: l10n.general,
            children: [
              SettingsSwitchTile(
                icon: Icons.mic,
                title: l10n.enableStt,
                subtitle: l10n.useVoiceInputForMessages,
                value: settings.enabled,
                onChanged: ref.read(sttSettingsProvider.notifier).setEnabled,
              ),
              SettingsSwitchTile(
                icon: Icons.send_outlined,
                title: l10n.autoSendStt,
                subtitle: l10n.automaticallySendAfterSpeaking,
                value: settings.autoSend,
                onChanged: settings.enabled
                    ? ref.read(sttSettingsProvider.notifier).setAutoSend
                    : null,
              ),
              SettingsSwitchTile(
                icon: Icons.hearing,
                title: l10n.continuousListening,
                subtitle: l10n.keepListeningAfterPhrase,
                value: settings.continuousListening,
                onChanged:
                    settings.enabled && settings.provider == STTProvider.system
                        ? ref
                            .read(sttSettingsProvider.notifier)
                            .setContinuousListening
                        : null,
              ),
              SettingsSwitchTile(
                icon: Icons.text_fields,
                title: l10n.showPartialResults,
                subtitle: l10n.displayTextAsYouSpeak,
                value: settings.showPartialResults,
                showDivider: false,
                onChanged:
                    settings.enabled && settings.provider == STTProvider.system
                        ? ref
                            .read(sttSettingsProvider.notifier)
                            .setShowPartialResults
                        : null,
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.cloud_outlined,
            title: l10n.provider,
            children: [
              SettingsChoiceTile<STTProvider>(
                icon: Icons.mic_external_on,
                title: l10n.sttProvider,
                selected: settings.provider,
                enabled: settings.enabled,
                choices: [
                  for (final provider in STTProvider.values)
                    SettingsChoice(
                      value: provider,
                      label: provider.displayName,
                    ),
                ],
                valueLabel: settings.provider.displayName,
                showDivider: settings.provider.isRemote,
                onSelected: (provider) {
                  ref.read(sttSettingsProvider.notifier).setProvider(provider);
                },
              ),
              if (settings.provider.isRemote)
                SettingsListTile(
                  icon: Icons.tune,
                  title: l10n.apiEndpoint,
                  subtitle: _providerSummary(settings, l10n),
                  showDivider: false,
                  trailing: Icon(Icons.edit,
                      color: scheme.onSurfaceVariant, size: 20),
                  enabled: settings.enabled,
                  onTap: settings.enabled
                      ? () => _showProviderConfiguration(
                            context,
                            ref,
                            settings,
                          )
                      : null,
                ),
            ],
          ),
          SettingsSection(
            icon: Icons.language,
            title: l10n.language,
            children: [
              SettingsChoiceTile<String>(
                icon: Icons.translate,
                title: l10n.recognitionLanguage,
                selected: settings.language,
                enabled: settings.enabled,
                choices: [
                  for (final language in STTLanguage.supportedLanguages)
                    SettingsChoice(
                      value: language.code,
                      label: language.name,
                    ),
                ],
                valueLabel: STTLanguage.fromCode(settings.language)?.name ??
                    settings.language,
                showDivider: false,
                onSelected: (language) {
                  ref.read(sttSettingsProvider.notifier).setLanguage(language);
                },
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.play_arrow_outlined,
            title: l10n.test,
            children: [
              SettingsListTile(
                icon: session.isActive ? Icons.stop_circle : Icons.mic_none,
                title: session.isActive
                    ? l10n.stopListening
                    : l10n.testVoiceInput,
                subtitle: _sessionSubtitle(session, l10n),
                showDivider: session.result != null || session.isActive,
                enabled: settings.enabled &&
                    (!settings.provider.isRemote || settings.isConfigured),
                onTap: settings.enabled &&
                        (!settings.provider.isRemote || settings.isConfigured)
                    ? ref.read(sttSessionProvider.notifier).toggle
                    : null,
              ),
              if (session.result != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(session.result!.text),
                    ),
                  ),
                ),
              if (session.isActive)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: ref.read(sttSessionProvider.notifier).cancel,
                    icon: const Icon(Icons.close),
                    label: Text(l10n.cancelVoiceInput),
                  ),
                ),
            ],
          ),
          SettingsSection(
            icon: Icons.info_outline,
            title: l10n.information,
            children: [
              SettingsListTile(
                icon: Icons.info_outline,
                title: l10n.aboutStt,
                subtitle: l10n.aboutSttDescription,
                showDivider: settings.provider == STTProvider.system,
              ),
              if (settings.provider == STTProvider.system)
                SettingsListTile(
                  icon: Icons.offline_bolt_outlined,
                  title: l10n.systemStt,
                  subtitle:
                      '${l10n.systemSttDescription}\n${l10n.systemSttOfflineNote}',
                  showDivider: false,
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isFailure(STTSessionPhase phase) =>
      phase == STTSessionPhase.failed ||
      phase == STTSessionPhase.unavailable ||
      phase == STTSessionPhase.permissionDenied ||
      phase == STTSessionPhase.permissionPermanentlyDenied;

  String _providerSummary(STTSettings settings, AppLocalizations l10n) {
    final endpoint = settings.apiEndpoint?.trim();
    final key = settings.apiKey?.trim() ?? '';
    final keySuffix = key.isEmpty
        ? l10n.notConfigured
        : '...${key.substring(key.length > 4 ? key.length - 4 : 0)}';
    if (settings.provider == STTProvider.selfHosted) {
      return endpoint?.isNotEmpty == true ? endpoint! : l10n.notConfigured;
    }
    return '${endpoint?.isNotEmpty == true ? endpoint : settings.effectiveEndpoint} · $keySuffix';
  }

  String _sessionSubtitle(
    STTSessionState session,
    AppLocalizations l10n,
  ) {
    return switch (session.phase) {
      STTSessionPhase.requestingPermission => l10n.processing,
      STTSessionPhase.listening => l10n.listening,
      STTSessionPhase.processing => l10n.processing,
      _ => l10n.tapToTestSpeechRecognition,
    };
  }

  Future<void> _showProviderConfiguration(
    BuildContext context,
    WidgetRef ref,
    STTSettings settings,
  ) async {
    final endpointController = TextEditingController(
      text: settings.apiEndpoint,
    );
    final keyController = TextEditingController(text: settings.apiKey);
    final modelController = TextEditingController(text: settings.model);
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(settings.provider.displayName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: endpointController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l10n.apiEndpoint,
                  hintText: settings.effectiveEndpoint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyController,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.apiKey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelController,
                decoration: InputDecoration(labelText: l10n.model),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final notifier = ref.read(sttSettingsProvider.notifier);
              notifier.setApiEndpoint(endpointController.text);
              notifier.setApiKey(keyController.text);
              notifier.setModel(modelController.text);
              Navigator.pop(dialogContext);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    endpointController.dispose();
    keyController.dispose();
    modelController.dispose();
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({this.message = '', this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.orange.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
              if (onAction != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
        ),
      ),
    );
  }
}
