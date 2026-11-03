import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/domain/services/translation_service.dart';
import 'package:native_tavern/presentation/providers/translation_providers.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';

/// Screen for translation settings
class TranslationSettingsScreen extends ConsumerWidget {
  const TranslationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(translationSettingsProvider);
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translationSettings),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: l10n.resetToDefaults,
            onPressed: () {
              ref.read(translationSettingsProvider.notifier).reset();
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
                icon: Icons.translate,
                title: l10n.enableTranslation,
                subtitle: l10n.translateMessagesAutomatically,
                value: settings.enabled,
                onChanged: (value) {
                  ref
                      .read(translationSettingsProvider.notifier)
                      .setEnabled(value);
                },
              ),
              SettingsSwitchTile(
                icon: Icons.smart_toy_outlined,
                title: l10n.translateAiResponses,
                subtitle: l10n.translateAiResponses,
                value: settings.autoTranslateIncoming,
                onChanged: settings.enabled
                    ? (value) {
                        ref
                            .read(translationSettingsProvider.notifier)
                            .setAutoTranslateIncoming(value);
                      }
                    : null,
              ),
              SettingsSwitchTile(
                icon: Icons.person_outline,
                title: l10n.translateUserMessages,
                subtitle: l10n.translateUserMessages,
                value: settings.autoTranslateOutgoing,
                onChanged: settings.enabled
                    ? (value) {
                        ref
                            .read(translationSettingsProvider.notifier)
                            .setAutoTranslateOutgoing(value);
                      }
                    : null,
              ),
              SettingsSwitchTile(
                icon: Icons.visibility_outlined,
                title: l10n.showOriginal,
                subtitle: l10n.showOriginalDescription,
                value: settings.showOriginal,
                showDivider: false,
                onChanged: settings.enabled
                    ? (value) {
                        ref
                            .read(translationSettingsProvider.notifier)
                            .setShowOriginal(value);
                      }
                    : null,
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.cloud_outlined,
            title: l10n.provider,
            children: [
              SettingsChoiceTile<TranslationProvider>(
                icon: Icons.translate,
                title: l10n.translationProvider,
                selected: settings.provider,
                enabled: settings.enabled,
                choices: [
                  for (final provider in TranslationProvider.values)
                    SettingsChoice(
                      value: provider,
                      label: provider.displayName,
                    ),
                ],
                valueLabel: settings.provider.displayName,
                showDivider: settings.provider != TranslationProvider.libre,
                onSelected: (value) {
                  ref
                      .read(translationSettingsProvider.notifier)
                      .setProvider(value);
                },
              ),
              if (settings.provider != TranslationProvider.libre)
                SettingsListTile(
                  icon: Icons.key_outlined,
                  title: l10n.apiKey,
                  subtitle: settings.apiKey?.isNotEmpty == true
                      ? '••••••••${settings.apiKey!.substring(settings.apiKey!.length - 4)}'
                      : l10n.notConfigured,
                  showDivider: false,
                  trailing: Icon(Icons.edit,
                      color: scheme.onSurfaceVariant, size: 20),
                  enabled: settings.enabled,
                  onTap: settings.enabled
                      ? () => _showApiKeyDialog(context, ref, settings)
                      : null,
                ),
            ],
          ),
          SettingsSection(
            icon: Icons.language,
            title: l10n.language,
            children: [
              SettingsChoiceTile<String>(
                icon: Icons.input,
                title: l10n.sourceLanguage,
                selected: settings.sourceLanguage,
                enabled: settings.enabled,
                choices: [
                  for (final lang in TranslationLanguage.supportedLanguages)
                    SettingsChoice(
                      value: lang.code,
                      label: _translationLanguageName(lang.code, l10n),
                    ),
                ],
                valueLabel:
                    _translationLanguageName(settings.sourceLanguage, l10n),
                onSelected: (value) {
                  ref
                      .read(translationSettingsProvider.notifier)
                      .setSourceLanguage(value);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.swap_vert),
                    tooltip: l10n.swapLanguages,
                    onPressed:
                        settings.enabled && settings.sourceLanguage != 'auto'
                            ? () {
                                ref
                                    .read(translationSettingsProvider.notifier)
                                    .swapLanguages();
                              }
                            : null,
                  ),
                ),
              ),
              SettingsChoiceTile<String>(
                icon: Icons.output,
                title: l10n.targetLanguage,
                selected: settings.targetLanguage,
                enabled: settings.enabled,
                choices: [
                  for (final lang in TranslationLanguage.targetLanguages)
                    SettingsChoice(
                      value: lang.code,
                      label: _translationLanguageName(lang.code, l10n),
                    ),
                ],
                valueLabel:
                    _translationLanguageName(settings.targetLanguage, l10n),
                showDivider: false,
                onSelected: (value) {
                  ref
                      .read(translationSettingsProvider.notifier)
                      .setTargetLanguage(value);
                },
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.play_arrow_outlined,
            title: l10n.test,
            children: [
              _TranslationTestWidget(enabled: settings.enabled),
            ],
          ),
          SettingsSection(
            icon: Icons.info_outline,
            title: l10n.information,
            children: [
              SettingsListTile(
                icon: Icons.info_outline,
                title: l10n.aboutTranslation,
                subtitle: l10n.aboutTranslationDescription,
                showDivider: settings.provider == TranslationProvider.google ||
                    settings.provider == TranslationProvider.deepl ||
                    settings.provider == TranslationProvider.libre,
              ),
              if (settings.provider == TranslationProvider.google)
                SettingsListTile(
                  icon: Icons.cloud,
                  title: l10n.googleTranslate,
                  subtitle: l10n.googleTranslateDescription,
                  showDivider: false,
                ),
              if (settings.provider == TranslationProvider.deepl)
                SettingsListTile(
                  icon: Icons.cloud,
                  title: l10n.deepL,
                  subtitle: l10n.deepLDescription,
                  showDivider: false,
                ),
              if (settings.provider == TranslationProvider.libre)
                SettingsListTile(
                  icon: Icons.public,
                  title: l10n.libreTranslate,
                  subtitle: l10n.libreTranslateDescription,
                  showDivider: false,
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(
      BuildContext context, WidgetRef ref, TranslationSettings settings) {
    final controller = TextEditingController(text: settings.apiKey);

    showDialog(
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
              ref
                  .read(translationSettingsProvider.notifier)
                  .setApiKey(controller.text);
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
  }
}

/// Widget for testing translation
class _TranslationTestWidget extends ConsumerStatefulWidget {
  final bool enabled;

  const _TranslationTestWidget({required this.enabled});

  @override
  ConsumerState<_TranslationTestWidget> createState() =>
      _TranslationTestWidgetState();
}

class _TranslationTestWidgetState
    extends ConsumerState<_TranslationTestWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final translationState = ref.watch(translationStateProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).enterTextToTokenize,
              hintText: AppLocalizations.of(context).enterTextToTokenize,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
            enabled: widget.enabled,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: widget.enabled && _controller.text.isNotEmpty
                ? () {
                    ref
                        .read(translationStateProvider.notifier)
                        .translate(_controller.text);
                  }
                : null,
            icon: translationState.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.translate),
            label: Text(AppLocalizations.of(context).translation),
          ),
          if (translationState.result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check,
                          size: 16, color: AppTheme.accentColor),
                      const SizedBox(width: 8),
                      Text(
                        '${translationState.result!.sourceLanguage} → ${translationState.result!.targetLanguage}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    translationState.result!.translatedText,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
          if (translationState.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      translationState.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Translate button widget for messages
class TranslateButton extends ConsumerWidget {
  final String text;
  final void Function(TranslationResult)? onTranslated;
  final double size;

  const TranslateButton({
    super.key,
    required this.text,
    this.onTranslated,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(translationSettingsProvider);

    if (!settings.enabled) return const SizedBox.shrink();

    return IconButton(
      icon: Icon(Icons.translate, size: size),
      tooltip: AppLocalizations.of(context).translate,
      onPressed: () async {
        final result = await ref.read(translateProvider)(text);
        if (result != null && onTranslated != null) {
          onTranslated!(result);
        }
      },
    );
  }
}

/// Inline translation display widget
class TranslationDisplay extends StatelessWidget {
  final TranslationResult result;
  final bool showOriginal;

  const TranslationDisplay({
    super.key,
    required this.result,
    this.showOriginal = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.translate,
                  size: 14, color: AppTheme.accentColor),
              const SizedBox(width: 4),
              Text(
                l10n.translatedFromLanguage(
                  _getLanguageName(result.sourceLanguage),
                ),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(result.translatedText),
          if (showOriginal) ...[
            const SizedBox(height: 8),
            Text(
              l10n.originalText(result.originalText),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    return TranslationLanguage.fromCode(code)?.name ?? code;
  }
}

String _translationLanguageName(
  String code,
  AppLocalizations l10n,
) {
  if (code == 'auto') return l10n.autoDetect;
  return TranslationLanguage.fromCode(code)?.nativeName ?? code;
}
