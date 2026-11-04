import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/cfg_scale.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/cfg_scale_providers.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';

/// Settings screen for CFG Scale configuration
class CFGScaleSettingsScreen extends ConsumerWidget {
  final String? characterId;
  final String? chatId;

  const CFGScaleSettingsScreen({
    super.key,
    this.characterId,
    this.chatId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(cfgScaleSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cfgScale),
        actions: spacedAppBarActions([
          ChromeIconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
            tooltip: l10n.help,
          ),
          ChromeIconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(cfgScaleSettingsProvider.notifier).resetToDefaults();
            },
            tooltip: l10n.resetToDefaults,
          ),
        ]),
      ),
      body: SettingsPageBody(
        children: [
          SettingsSection(
            icon: Icons.linear_scale,
            title: l10n.cfgScale,
            children: [
              SettingsSwitchTile(
                icon: Icons.tune,
                title: l10n.enableCfgScale,
                subtitle: l10n.cfgScaleDescription,
                value: settings.enabled,
                showDivider: false,
                onChanged: (value) {
                  ref.read(cfgScaleSettingsProvider.notifier).setEnabled(value);
                },
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.public,
            title: l10n.globalSettings,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _GuidanceScaleSlider(
                  value: settings.globalGuidanceScale,
                  onChanged: settings.enabled
                      ? (value) {
                          ref
                              .read(cfgScaleSettingsProvider.notifier)
                              .setGlobalGuidanceScale(value);
                        }
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _PromptTextField(
                  label: l10n.negativePrompt,
                  hint: l10n.textToSteerAwayFrom,
                  value: settings.globalNegativePrompt,
                  enabled: settings.enabled,
                  onChanged: (value) {
                    ref
                        .read(cfgScaleSettingsProvider.notifier)
                        .setGlobalNegativePrompt(value);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _PromptTextField(
                  label: l10n.positivePromptOptional,
                  hint: l10n.textToEnhanceInOutput,
                  value: settings.globalPositivePrompt,
                  enabled: settings.enabled,
                  onChanged: (value) {
                    ref
                        .read(cfgScaleSettingsProvider.notifier)
                        .setGlobalPositivePrompt(value);
                  },
                ),
              ),
            ],
          ),
          if (characterId != null)
            _CharacterCFGSection(
              characterId: characterId!,
              globalEnabled: settings.enabled,
            ),
          if (chatId != null)
            _ChatCFGSection(
              chatId: chatId!,
              globalEnabled: settings.enabled,
            ),
          SettingsSection(
            icon: Icons.info_outline,
            title: l10n.aboutCfgScale,
            children: [
              SettingsListTile(
                icon: Icons.info_outline,
                title: l10n.aboutCfgScale,
                subtitle: l10n.aboutCfgScaleDescription,
                showDivider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cfgScaleHelp),
        content: SingleChildScrollView(
          child: Text(l10n.cfgScaleHelpContent),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}

/// Slider widget for guidance scale
class _GuidanceScaleSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;

  const _GuidanceScaleSlider({
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context).guidanceScale,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value.toStringAsFixed(2),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('0.1'),
            Expanded(
              child: Slider(
                value: value,
                min: 0.1,
                max: 30.0,
                divisions: 299,
                onChanged: enabled ? onChanged : null,
              ),
            ),
            const Text('30.0'),
          ],
        ),
        // Quick presets
        Wrap(
          spacing: 8,
          children: [
            _PresetChip(label: '1.0', value: 1.0, currentValue: value, onTap: onChanged),
            _PresetChip(label: '1.5', value: 1.5, currentValue: value, onTap: onChanged),
            _PresetChip(label: '2.0', value: 2.0, currentValue: value, onTap: onChanged),
            _PresetChip(label: '3.0', value: 3.0, currentValue: value, onTap: onChanged),
            _PresetChip(label: '5.0', value: 5.0, currentValue: value, onTap: onChanged),
            _PresetChip(label: '7.0', value: 7.0, currentValue: value, onTap: onChanged),
          ],
        ),
      ],
    );
  }
}

/// Chip for quick preset selection
class _PresetChip extends StatelessWidget {
  final String label;
  final double value;
  final double currentValue;
  final ValueChanged<double>? onTap;

  const _PresetChip({
    required this.label,
    required this.value,
    required this.currentValue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = (currentValue - value).abs() < 0.01;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onTap != null ? (_) => onTap!(value) : null,
    );
  }
}

/// Text field for prompts
class _PromptTextField extends StatefulWidget {
  final String label;
  final String hint;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _PromptTextField({
    required this.label,
    required this.hint,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_PromptTextField> createState() => _PromptTextFieldState();
}

class _PromptTextFieldState extends State<_PromptTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_PromptTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        border: const OutlineInputBorder(),
        enabled: widget.enabled,
      ),
      maxLines: 3,
      onChanged: widget.onChanged,
    );
  }
}

/// Section for character-specific CFG settings
class _CharacterCFGSection extends ConsumerWidget {
  final String characterId;
  final bool globalEnabled;

  const _CharacterCFGSection({
    required this.characterId,
    required this.globalEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(cfgScaleSettingsProvider);
    final charSettings = settings.characterSettings.firstWhere(
      (s) => s.characterId == characterId,
      orElse: () => CharacterCFGSettings.empty(characterId),
    );

    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      icon: Icons.person_outline,
      title: l10n.characterSettings,
      children: [
        SettingsSwitchTile(
          icon: Icons.manage_accounts_outlined,
          title: l10n.useCharacterSpecificSettings,
          subtitle: l10n.overrideGlobalForCharacter,
          value: charSettings.useCharacterSettings,
          showDivider: charSettings.useCharacterSettings,
          onChanged: globalEnabled
              ? (value) {
                  ref
                      .read(cfgScaleSettingsProvider.notifier)
                      .updateCharacterSettings(
                        charSettings.copyWith(useCharacterSettings: value),
                      );
                }
              : null,
        ),
        if (charSettings.useCharacterSettings) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _GuidanceScaleSlider(
              value: charSettings.guidanceScale ?? 1.0,
              onChanged: globalEnabled
                  ? (value) {
                      ref
                          .read(cfgScaleSettingsProvider.notifier)
                          .updateCharacterSettings(
                            charSettings.copyWith(guidanceScale: value),
                          );
                    }
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _PromptTextField(
              label: l10n.characterNegativePrompt,
              hint: l10n.overrideGlobalNegativePrompt,
              value: charSettings.negativePrompt ?? '',
              enabled: globalEnabled,
              onChanged: (value) {
                ref
                    .read(cfgScaleSettingsProvider.notifier)
                    .updateCharacterSettings(
                      charSettings.copyWith(negativePrompt: value),
                    );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Section for chat-specific CFG settings
class _ChatCFGSection extends ConsumerWidget {
  final String chatId;
  final bool globalEnabled;

  const _ChatCFGSection({
    required this.chatId,
    required this.globalEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chatSettings = ref.watch(chatCFGSettingsProvider(chatId));

    return SettingsSection(
      icon: Icons.chat_bubble_outline,
      title: l10n.chatSettings,
      footer: l10n.chatSettingsDescription,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: globalEnabled
                ? () {
                    ref
                        .read(chatCFGSettingsProvider(chatId).notifier)
                        .clearSettings();
                  }
                : null,
            child: Text(l10n.clear),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _GuidanceScaleSlider(
            value: chatSettings.guidanceScale ?? 1.0,
            onChanged: globalEnabled
                ? (value) {
                    ref
                        .read(chatCFGSettingsProvider(chatId).notifier)
                        .setGuidanceScale(value);
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _PromptTextField(
            label: l10n.chatNegativePrompt,
            hint: l10n.overrideForThisChat,
            value: chatSettings.negativePrompt ?? '',
            enabled: globalEnabled,
            onChanged: (value) {
              ref
                  .read(chatCFGSettingsProvider(chatId).notifier)
                  .setNegativePrompt(value);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _PromptTextField(
            label: l10n.chatPositivePrompt,
            hint: l10n.enhancementForThisChat,
            value: chatSettings.positivePrompt ?? '',
            enabled: globalEnabled,
            onChanged: (value) {
              ref
                  .read(chatCFGSettingsProvider(chatId).notifier)
                  .setPositivePrompt(value);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SettingsChoiceTile<PromptCombineMode>(
            icon: Icons.merge_type,
            title: l10n.promptCombineMode,
            selected: chatSettings.promptCombineMode,
            enabled: globalEnabled,
            choices: [
              for (final mode in PromptCombineMode.values)
                SettingsChoice(
                  value: mode,
                  label: _getCombineModeLabel(context, mode),
                ),
            ],
            valueLabel: _getCombineModeLabel(context, chatSettings.promptCombineMode),
            showDivider: false,
            onSelected: (mode) {
              ref
                  .read(chatCFGSettingsProvider(chatId).notifier)
                  .setPromptCombineMode(mode);
            },
          ),
        ),
      ],
    );
  }

  String _getCombineModeLabel(BuildContext context, PromptCombineMode mode) {
    final l10n = AppLocalizations.of(context);
    switch (mode) {
      case PromptCombineMode.replace:
        return l10n.replaceChatPromptOnly;
      case PromptCombineMode.prepend:
        return l10n.prependChatPlusGlobal;
      case PromptCombineMode.append:
        return l10n.appendGlobalPlusChat;
    }
  }
}