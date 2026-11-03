import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/domain/services/tts_service.dart';
import 'package:native_tavern/presentation/providers/tts_providers.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';

/// Screen for TTS settings
class TTSSettingsScreen extends ConsumerWidget {
  const TTSSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(ttsSettingsProvider);
    final isSpeaking = ref.watch(ttsSpeakingProvider);
    final voicesAsync = ref.watch(availableVoicesProvider);
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.textToSpeech),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: l10n.resetToDefaults,
            onPressed: () {
              ref.read(ttsSettingsProvider.notifier).reset();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.settingsResetToDefaults)),
              );
            },
          ),
        ],
      ),
      body: SettingsPageBody(
        children: [
          SettingsSection(
            icon: Icons.toggle_on_outlined,
            title: l10n.general,
            children: [
              SettingsSwitchTile(
                icon: Icons.record_voice_over,
                title: l10n.enableTts,
                subtitle: l10n.readAiResponsesAloud,
                value: settings.enabled,
                onChanged: (value) {
                  ref.read(ttsSettingsProvider.notifier).setEnabled(value);
                },
              ),
              SettingsSwitchTile(
                icon: Icons.play_circle_outline,
                title: l10n.autoPlay,
                subtitle: l10n.automaticallyPlayResponses,
                value: settings.autoPlay,
                onChanged: settings.enabled
                    ? (value) {
                        ref
                            .read(ttsSettingsProvider.notifier)
                            .setAutoPlay(value);
                      }
                    : null,
              ),
              SettingsSwitchTile(
                icon: Icons.queue_music,
                title: l10n.queueMessages,
                subtitle: l10n.queueMessagesDescription,
                value: settings.queueMessages,
                showDivider: false,
                onChanged: settings.enabled
                    ? (value) {
                        ref
                            .read(ttsSettingsProvider.notifier)
                            .setQueueMessages(value);
                      }
                    : null,
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.cloud_outlined,
            title: l10n.provider,
            children: [
              SettingsChoiceTile<TTSProvider>(
                icon: Icons.speaker_group_outlined,
                title: l10n.ttsProvider,
                selected: settings.provider,
                enabled: settings.enabled,
                choices: [
                  for (final provider in TTSProvider.values)
                    SettingsChoice(
                      value: provider,
                      label: provider.displayName,
                    ),
                ],
                valueLabel: settings.provider.displayName,
                onSelected: (value) {
                  ref.read(ttsSettingsProvider.notifier).setProvider(value);
                },
                showDivider: settings.provider != TTSProvider.system,
              ),
              if (settings.provider != TTSProvider.system) ...[
                SettingsListTile(
                  icon: Icons.key_outlined,
                  title: l10n.apiKey,
                  subtitle: settings.apiKey?.isNotEmpty == true
                      ? '••••••••${settings.apiKey!.length > 4 ? settings.apiKey!.substring(settings.apiKey!.length - 4) : settings.apiKey}'
                      : l10n.notConfigured,
                  trailing: Icon(Icons.edit,
                      color: scheme.onSurfaceVariant, size: 20),
                  enabled: settings.enabled,
                  onTap: settings.enabled
                      ? () => _showApiKeyDialog(context, ref, settings)
                      : null,
                ),
                SettingsListTile(
                  icon: Icons.link,
                  title: l10n.apiEndpoint,
                  subtitle: _remoteEndpointSummary(settings),
                  showDivider: false,
                  trailing: Icon(Icons.edit,
                      color: scheme.onSurfaceVariant, size: 20),
                  enabled: settings.enabled,
                  onTap: settings.enabled
                      ? () => _showApiEndpointDialog(context, ref, settings)
                      : null,
                ),
              ],
            ],
          ),
          SettingsSection(
            icon: Icons.record_voice_over_outlined,
            title: l10n.voice,
            children: [
              voicesAsync.when(
                data: (voices) {
                  final selected = voices.firstWhere(
                    (v) => v.id == settings.voiceId,
                    orElse: () => voices.first,
                  );
                  return SettingsChoiceTile<String>(
                    icon: Icons.voice_chat_outlined,
                    title: l10n.voice,
                    selected: settings.voiceId ?? voices.first.id,
                    enabled: settings.enabled,
                    choices: [
                      for (final voice in voices)
                        SettingsChoice(value: voice.id, label: voice.name),
                    ],
                    valueLabel: selected.name,
                    showDivider: false,
                    onSelected: (value) {
                      ref.read(ttsSettingsProvider.notifier).setVoiceId(value);
                    },
                  );
                },
                loading: () => SettingsListTile(
                  icon: Icons.voice_chat_outlined,
                  title: l10n.voice,
                  subtitle: l10n.loadingVoices,
                  showDivider: false,
                  trailing: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, __) => SettingsListTile(
                  icon: Icons.voice_chat_outlined,
                  title: l10n.voice,
                  subtitle: l10n.failedToLoadVoices,
                  showDivider: false,
                  trailing: const Icon(Icons.error, color: Colors.red),
                ),
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.tune,
            title: l10n.voiceSettings,
            children: [
              SettingsSliderTile(
                icon: Icons.speed,
                title: l10n.speed,
                valueLabel: '${settings.rate.toStringAsFixed(1)}x',
                value: settings.rate,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                enabled: settings.enabled,
                onChanged: (value) {
                  ref.read(ttsSettingsProvider.notifier).setRate(value);
                },
              ),
              SettingsSliderTile(
                icon: Icons.graphic_eq,
                title: l10n.pitch,
                valueLabel: '${settings.pitch.toStringAsFixed(1)}x',
                value: settings.pitch,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                enabled: settings.enabled,
                onChanged: (value) {
                  ref.read(ttsSettingsProvider.notifier).setPitch(value);
                },
              ),
              SettingsSliderTile(
                icon: Icons.volume_up_outlined,
                title: l10n.volume,
                valueLabel: '${(settings.volume * 100).round()}%',
                value: settings.volume,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                showDivider: false,
                enabled: settings.enabled,
                onChanged: (value) {
                  ref.read(ttsSettingsProvider.notifier).setVolume(value);
                },
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.play_arrow_outlined,
            title: l10n.test,
            children: [
              SettingsListTile(
                icon: isSpeaking ? Icons.stop : Icons.play_arrow,
                title: isSpeaking ? l10n.stopListening : l10n.testVoice,
                subtitle: l10n.testVoice,
                showDivider: false,
                enabled: settings.enabled,
                onTap: settings.enabled
                    ? () async {
                        if (isSpeaking) {
                          await ref.read(ttsStopProvider)();
                        } else {
                          await ref.read(ttsSpeakProvider)(l10n.ttsTestPhrase);
                        }
                      }
                    : null,
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.info_outline,
            title: l10n.information,
            children: [
              SettingsListTile(
                icon: Icons.info_outline,
                title: l10n.aboutTts,
                subtitle: l10n.aboutTtsDescription,
                showDivider: settings.provider == TTSProvider.system ||
                    settings.provider == TTSProvider.elevenlabs,
              ),
              if (settings.provider == TTSProvider.system)
                SettingsListTile(
                  icon: Icons.phone_android,
                  title: l10n.systemTts,
                  subtitle: l10n.systemTtsDetails,
                  showDivider: false,
                ),
              if (settings.provider == TTSProvider.elevenlabs)
                SettingsListTile(
                  icon: Icons.cloud,
                  title: 'ElevenLabs',
                  subtitle: l10n.elevenLabsDescription,
                  showDivider: false,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showApiKeyDialog(
    BuildContext context,
    WidgetRef ref,
    TTSSettings settings,
  ) async {
    final controller = TextEditingController(text: settings.apiKey);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${settings.provider.displayName} ${AppLocalizations.of(context).apiKey}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).apiKey,
            hintText: AppLocalizations.of(context).enterApiKey,
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(ttsSettingsProvider.notifier).setApiKey(controller.text);
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  String _remoteEndpointSummary(TTSSettings settings) {
    final configured = settings.apiEndpoint?.trim();
    if (configured?.isNotEmpty == true) return configured!;
    return switch (settings.provider) {
      TTSProvider.elevenlabs => 'https://api.elevenlabs.io',
      TTSProvider.azure =>
        'https://${settings.providerOptions['region'] ?? 'eastus'}.tts.speech.microsoft.com',
      TTSProvider.volcengine => 'https://openspeech.bytedance.com/api/v1/tts',
      TTSProvider.gptSovits => 'http://127.0.0.1:9880',
      TTSProvider.openaiCompatible => 'https://api.openai.com/v1',
      TTSProvider.system => '',
    };
  }

  Future<void> _showApiEndpointDialog(
    BuildContext context,
    WidgetRef ref,
    TTSSettings settings,
  ) async {
    final controller = TextEditingController(text: settings.apiEndpoint);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '${settings.provider.displayName} ${AppLocalizations.of(context).apiEndpoint}',
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).apiEndpoint,
            hintText: _remoteEndpointSummary(settings),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(ttsSettingsProvider.notifier)
                  .setApiEndpoint(controller.text.trim());
              Navigator.pop(dialogContext);
            },
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

/// Widget for TTS button in chat messages
class TTSMessageButton extends ConsumerWidget {
  final String text;
  final String? characterId;
  final double size;

  const TTSMessageButton({
    super.key,
    required this.text,
    this.characterId,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(ttsSettingsProvider);
    final isSpeaking = ref.watch(ttsSpeakingProvider);

    if (!settings.enabled) return const SizedBox.shrink();

    return IconButton(
      icon: Icon(
        isSpeaking ? Icons.stop : Icons.volume_up,
        size: size,
      ),
      tooltip: isSpeaking
          ? AppLocalizations.of(context).stopSpeaking
          : AppLocalizations.of(context).readAloud,
      onPressed: () async {
        if (isSpeaking) {
          await ref.read(ttsStopProvider)();
        } else {
          await ref.read(ttsSpeakProvider)(text, characterId: characterId);
        }
      },
    );
  }
}

/// Compact TTS controls for chat
class TTSControls extends ConsumerWidget {
  const TTSControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(ttsSettingsProvider);
    final isSpeaking = ref.watch(ttsSpeakingProvider);

    if (!settings.enabled) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSpeaking)
          IconButton(
            icon: const Icon(Icons.stop, size: 20),
            tooltip: AppLocalizations.of(context).stopSpeaking,
            onPressed: () => ref.read(ttsStopProvider)(),
          ),
        Icon(
          Icons.volume_up,
          size: 16,
          color: settings.enabled ? AppTheme.accentColor : AppTheme.textMuted,
        ),
      ],
    );
  }
}
